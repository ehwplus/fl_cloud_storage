import 'dart:convert';
import 'dart:io';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/cloud_storage_service.dart' show CloudStorageServiceListener, log;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show
        GoogleSignIn,
        GoogleSignInAccount,
        GoogleSignInAuthentication,
        GoogleSignInClientAuthorization,
        GoogleSignInException,
        GoogleSignInAuthenticationEventSignIn,
        GoogleSignInAuthenticationEventSignOut;
import 'package:googleapis/drive/v3.dart' as v3;
import 'package:http/http.dart' as http;

const _googleDriveSingleUserScope = [
  'https://www.googleapis.com/auth/contacts.readonly',
  v3.DriveApi.driveAppdataScope,
  v3.DriveApi.driveFileScope,
];

/// Scope for sharing json with other Google users
const _googleDriveFullScope = [
  'https://www.googleapis.com/auth/contacts.readonly',
  v3.DriveApi.driveAppdataScope,
  v3.DriveApi.driveFileScope,
  v3.DriveApi.driveScope,
];

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this.accessToken);

  final String accessToken;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll({'Authorization': 'Bearer $accessToken'}));
  }
}

class GoogleDriveClientIdentifiers {
  const GoogleDriveClientIdentifiers({
    this.clientIdAndroid,
    this.clientIdIOS,
    this.clientIdMacOS,
    this.clientIdWeb,
    this.serverClientId,
  });

  final String? clientIdAndroid;
  final String? clientIdIOS;
  final String? clientIdMacOS;
  final String? clientIdWeb;
  final String? serverClientId;
}

class GoogleDriveService implements ICloudService<GoogleDriveFile, GoogleDriveFolder> {
  /// This class cannot be instantiated synchronously.
  /// Use `await GoogleDriveService.initialize()`.
  GoogleDriveService._(
    this.driveScope, {
    CloudStorageServiceListener<v3.DriveApi>? listener,
    GoogleDriveClientIdentifiers? identifiers,
  })  : _listener = listener,
        _clientIdAndroid = identifiers?.clientIdAndroid,
        _clientIdIOS = identifiers?.clientIdIOS,
        _clientIdMacOS = identifiers?.clientIdMacOS,
        _clientIdWeb = identifiers?.clientIdWeb,
        _serverClientId = identifiers?.serverClientId;

  /// Google drive service is supported on all platforms.
  ///
  static List<PlatformSupportEnum> get supportedPlatforms => [];

  /// Whether to do the google login silently or interactively.
  /// A previously authenticated google user can be logged in silently.
  /// FIXME this variable is not configurable as of now 1/20/23
  final bool interactiveLogin = false;

  /// The [v3.DriveApi] which is used to communicate with the google drive
  /// service.
  v3.DriveApi? _driveApi;

  bool _isAuthenticated = false;
  bool _isAuthorized = false;

  String? _email;
  String? _displayName;
  String? _photoUrl;

  CloudStorageServiceListener<v3.DriveApi>? _listener;

  final String? _clientIdAndroid;
  final String? _clientIdWeb;
  final String? _clientIdIOS;
  final String? _clientIdMacOS;
  final String? _serverClientId;

  final GoogleDriveScope driveScope;

  AuthenticationTokens? _authenticationTokens;

  @override
  AuthenticationTokens? get authenticationTokens => _authenticationTokens;

  @override
  bool get isSignedIn => _isAuthenticated;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  @override
  String? get photoUrl => _photoUrl;

  static Future<GoogleDriveService> initialize({
    GoogleDriveScope? driveScope,
    CloudStorageServiceListener<v3.DriveApi>? listener,
    GoogleDriveClientIdentifiers? identifiers,
  }) async {
    final instance = GoogleDriveService._(
      driveScope ?? GoogleDriveScope.appData,
      listener: listener,
      identifiers: identifiers,
    );
    await instance.authenticate();
    await instance._initializeApi();
    return instance;
  }

  Future<void> _initializeApi() async {
    final accessToken = _authenticationTokens?.accessToken;
    if (_isAuthenticated && _isAuthorized && accessToken != null) {
      final http.Client client = _GoogleAuthClient(accessToken);
      _driveApi = v3.DriveApi(client);
    }
    if (_driveApi == null) {
      throw Exception('Failed to initialize Google drive API!');
    }
    _listener?.onApiIsReady(_driveApi!);
  }

  // AUTH

  Future<bool> authenticateAgain() async {
    final result = await authenticate();
    await _initializeApi();
    return result;
  }

  /// This method does a google login with scopes for google drive.
  ///
  /// The authentication headers of the google user are used to initialize the
  /// Google drive API later on.
  @override
  Future<bool> authenticate() async {
    // #docregion Setup
    final GoogleSignIn signIn = GoogleSignIn.instance;

    GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final account = event.user;
        final idToken = account.authentication.idToken;
        debugPrint('Signed in as ${account.email}, idToken len: ${idToken?.length}');

        _isAuthorized = true;

        _authenticationTokens = AuthenticationTokens(idToken: idToken, accessToken: null);
        _email = account.email;
        _displayName = account.displayName;
        _photoUrl = account.photoUrl;
        _listener?.onSignIn();

        final isAuthorized = await _authorize(account: account);
        if (isAuthorized) {
          await _initializeApi();
        }
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        await logout();
        _listener?.onSignOut();
      } else {
        log.e('Listener received unhandled event of type ${event.toString()}');
      }
    }, onError: (dynamic error, st) {
      log.e('Auth error: $error');
    }).onError((dynamic error) {
      log.e('Auth error: $error');
    });

    String? clientId() {
      if (kIsWeb) {
        return _clientIdWeb;
      } else if (Platform.isAndroid) {
        return _clientIdAndroid;
      } else if (Platform.isIOS) {
        return _clientIdIOS;
      } else if (Platform.isMacOS) {
        return _clientIdMacOS;
      }
      throw UnsupportedError('Unsupported platform');
    }

    await signIn.initialize(clientId: clientId(), serverClientId: kIsWeb ? null : _serverClientId);

    //signIn.authenticationEvents.listen(_handleAuthenticationEvent).onError(_handleAuthenticationError);

    GoogleSignInAccount? account = await signIn.attemptLightweightAuthentication();
    final GoogleSignInAuthentication? authentication = account?.authentication;

    if (authentication == null && kIsWeb) {
      return false;
    }

    if (authentication == null) {
      if (kDebugMode) {
        log.e('attemptLightweightAuthentication failed, will try to authenticate in a different way now.');
      }
      account = await signIn.authenticate();
    }

    final idToken = authentication?.idToken;
    if (account == null || idToken == null) {
      if (kDebugMode) {
        debugPrint('authentication failed');
      }
      _listener?.onSignInFailed();
      _isAuthenticated = false;
      return false;
    }
    _listener?.onSignIn();
    _isAuthenticated = true;

    return _authorize(account: account);
  }

  Future<bool> _authorize({required GoogleSignInAccount account}) async {
    final idToken = account.authentication.idToken;
    try {
      final GoogleSignInClientAuthorization authorization = await account.authorizationClient.authorizeScopes(
        driveScope == GoogleDriveScope.full ? _googleDriveFullScope : _googleDriveSingleUserScope,
      );
      final accessToken = authorization.accessToken;

      _authenticationTokens = AuthenticationTokens(idToken: idToken, accessToken: accessToken);
      _email = account.email;
      _displayName = account.displayName;
      _photoUrl = account.photoUrl;

      _listener?.onAuthorized();
      _isAuthorized = true;
      return true;
    } on GoogleSignInException catch (e) {
      log.e('authorizeScopes failed: ${e.toString()}');
      _isAuthorized = false;
      return false;
    }
  }

  @override
  Future<bool> logout() async {
    final googleSignIn = GoogleSignIn.instance;
    try {
      await googleSignIn.signOut();
    } on PlatformException catch (_) {
      await googleSignIn.disconnect();
    }
    _email = null;
    _displayName = null;
    _photoUrl = null;

    _listener?.onSignOut();
    return _isAuthenticated = false;
  }

  @override
  Future<bool> authorize() {
    // Authentication and authorization is done in the same step.
    // So do the same.
    return authenticate();
  }

  // FILES

  @override
  Future<bool> doesFileExist({required GoogleDriveFile file, bool ignoreTrashedFiles = true}) async {
    if (_driveApi == null) {
      return false;
    }

    try {
      final v3.File? cloudFile = await _driveApi!.files.get(file.file.id!) as v3.File?;
      return cloudFile != null && (!ignoreTrashedFiles || !(cloudFile.trashed == true));
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = await authenticateAgain();
        if (authenticated) {
          final v3.File? cloudFile = await _driveApi!.files.get(file.file.id!) as v3.File?;
          return cloudFile != null && (!ignoreTrashedFiles || !(cloudFile.trashed == true));
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to make lookup for Google Drive file');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteFile({required GoogleDriveFile file}) async {
    if (_driveApi == null) {
      return false;
    }

    if (file.file.id == null) {
      throw Exception('Must provide a file id of the file which shall be downloaded!');
    }
    // If the used http.Client completes with an error when making a REST call,
    // this method will complete with the same error.
    try {
      await _driveApi!.files.delete(file.file.id!);
      return true;
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = await authenticate();
        if (authenticated) {
          await _driveApi!.files.delete(file.file.id!);
          return true;
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to delete Google Drive file');
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<GoogleDriveFile> downloadFile({
    required GoogleDriveFile file,
    void Function(Uint8List bytes)? onBytesDownloaded,
    bool retry = false,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to download file ${file.fileName}.');
    }

    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    if (file.file.id == null) {
      throw Exception('Must provide a file id of the file which shall be downloaded!');
    }

    bool isTextFile(String contentType) {
      final mimeTypeParts = contentType.split('/');
      if (mimeTypeParts.isNotEmpty) {
        final prefix = mimeTypeParts.first;
        return {'application', 'message', 'model', 'text'}.contains(prefix);
      }
      return false;
    }

    try {
      final v3.Media media = await _driveApi!.files.get(
        file.file.id!,
        downloadOptions: v3.DownloadOptions.fullMedia,
      ) as v3.Media;
      final contentType = file.mimeType ?? media.contentType;

      if (isTextFile(contentType)) {
        try {
          final String fileContent = await utf8.decodeStream(media.stream);
          return file.copyWith(
            fileContent: fileContent,
          );
        } catch (e) {
          debugPrint('Failed to download file content: $e');
        }
      }

      Future<v3.Media?> getMedia(v3.Media media) async {
        try {
          final List<int> bytes = [];
          media.stream.listen((List<int> data) {
            bytes.insertAll(bytes.length, data);
          }, onDone: () async {
            onBytesDownloaded?.call(Uint8List.fromList(bytes));
          }, onError: (dynamic error) {
            debugPrint('[sync] Unable to store downloaded photo ${file.fileName}: $error');
          });
          return media;
        } catch (e) {
          return null;
        }
      }

      return Future.value(file.copyWith(media: await getMedia(media)));
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = !retry && await authenticateAgain();
        if (authenticated) {
          return downloadFile(file: file, onBytesDownloaded: onBytesDownloaded, retry: true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to download Google Drive file');
    }
  }

  @override
  Future<GoogleDriveFile> uploadFile({
    required GoogleDriveFile file,
    GoogleDriveFolder? parent,
    bool overwrite = true,
    bool retry = false,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to upload file.');
    }

    try {
      if (parent != null && parent.folder.id != null) {
        if (!(file.file.parents?.contains(parent.folder.id) ?? true)) {
          file.file.parents = [...?file.file.parents, parent.folder.id!];
        }
      }
      if (file.fileId != null) {
        final v3.File driveFile = v3.File()
          ..description = file.description
          ..name = file.fileName;
        final updatedFile = await _driveApi!.files.update(driveFile, file.fileId!, uploadMedia: file.media);
        return file.copyWith(
          fileId: updatedFile.id,
          fileName: updatedFile.name,
          parents: updatedFile.parents,
        );
      }
      final cratedFile = await _driveApi!.files.create(file.file, uploadMedia: file.media);
      return file.copyWith(
        fileId: cratedFile.id,
        fileName: cratedFile.name,
        parents: cratedFile.parents,
      );
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = !retry && await authenticateAgain();
        if (authenticated) {
          return uploadFile(file: file, parent: parent, overwrite: overwrite, retry: true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to upload Google Drive file');
    }
  }

  @override
  Future<List<GoogleDriveFile>> getAllFiles({
    GoogleDriveFolder? folder,
    bool ignoreTrashedFiles = true,
    bool retry = false,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to get all files.');
    }

    final List<GoogleDriveFile> result = [];

    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    v3.FileList? res;
    try {
      do {
        // Complete the files list, otherwise maximum 100 files are returned
        if (folder == null) {
          res = await _driveApi!.files.list(
            $fields: 'files/*',
            q: 'trashed=${!ignoreTrashedFiles}',
          );
        } else {
          res = await _driveApi!.files.list(
            $fields: 'files/*',
            q: "'${folder.folder.id}' in parents and trashed=${!ignoreTrashedFiles}",
          );
        }

        for (final v3.File file in res.files!) {
          final driveFile = GoogleDriveFile(
            fileId: file.id,
            fileName: file.name!,
            parents: file.parents,
            description: file.description,
            mimeType: file.mimeType,
            trashed: (file.trashed ?? false) || (file.explicitlyTrashed ?? false),
            bytes: null,
          );
          result.add(driveFile);
        }
      } while (res.nextPageToken != null);

      if (res.files == null) {
        throw Exception('Unable to list all files!');
      }
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = !retry && await authenticateAgain();
        if (authenticated) {
          return getAllFiles(folder: folder, ignoreTrashedFiles: ignoreTrashedFiles, retry: true);
        }
        throw TooManyRequestsError();
      }
    }

    return result;
  }

  bool _shouldMapToTooManyRequestsError(String? errorMessage) {
    return errorMessage?.contains('Request had invalid authentication credentials.') == true;
  }

  // FOLDERS

  @override
  Future<GoogleDriveFolder> uploadFolder({
    required String name,
    GoogleDriveFolder? parent,
    bool retry = false,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to upload folder $name.');
    }

    final folder = v3.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parent != null && parent.folder.id != null) {
      folder.parents = [parent.folder.id!];
    }
    try {
      return GoogleDriveFolder(folder: await _driveApi!.files.create(folder));
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = !retry && await authenticateAgain();
        if (authenticated) {
          return uploadFolder(name: name, parent: parent, retry: true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to upload Google Drive folder');
    }
  }

  @override
  Future<bool> deleteFolder({
    required GoogleDriveFolder folder,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to delete folder.');
    }

    if (folder.folder.id == null) {
      // log.e this
      throw Exception(
        'Must provide a folder id of the folder which shall be deleted!',
      );
    }
    // If the used http.Client completes with an error when making a REST call,
    // this method will complete with the same error.
    try {
      await _driveApi!.files.delete(folder.folder.id!);
      return Future.value(true);
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = await authenticateAgain();
        if (authenticated) {
          await _driveApi!.files.delete(folder.folder.id!);
          return Future.value(true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to delete Google Drive folder');
    } catch (ex) {
      return Future.value(false);
    }
  }

  @override
  Future<List<GoogleDriveFile>> downloadFolder({
    required GoogleDriveFolder folder,
  }) async {
    final files = await getAllFiles(folder: folder);
    return Future.wait(files.map((file) => downloadFile(file: file)).toList());
  }

  @override
  Future<List<GoogleDriveFolder>> getAllFolders({
    GoogleDriveFolder? folder,
    bool ignoreTrashedFiles = true,
    bool retry = false,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to get all folders.');
    }

    try {
      // Completes with a commons.ApiRequestError if the API endpoint returned an error
      final v3.FileList res;
      if (folder == null) {
        res = await _driveApi!.files
            .list(q: "mimeType = 'application/vnd.google-apps.folder' and trashed=${!ignoreTrashedFiles}");
      } else {
        res = await _driveApi!.files.list(
          q: "mimeType = 'application/vnd.google-apps.folder' and '${folder.folder.id}' in parents and trashed=${!ignoreTrashedFiles}",
        );
      }
      if (res.nextPageToken != null) {
        // TODO complete the files list
      }
      if (res.files == null) {
        throw Exception('Unable to list all files!');
      }
      return res.files!.map((folder) => GoogleDriveFolder(folder: folder)).toList();
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = !retry && await authenticateAgain();
        if (authenticated) {
          return getAllFolders(folder: folder, ignoreTrashedFiles: ignoreTrashedFiles, retry: true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to get all Google Drive folders');
    }
  }

  @override
  Future<List<GoogleDriveFolder>> getFoldersByName(String name,
      {bool ignoreTrashedFiles = true, bool retry = false}) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to get folder $name.');
    }

    try {
      final v3.FileList res = await _driveApi!.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed=${!ignoreTrashedFiles}",
      );
      return res.files?.map((element) => GoogleDriveFolder(folder: element)).toList(growable: false) ?? [];
    } on v3.DetailedApiRequestError catch (e) {
      if (_shouldMapToTooManyRequestsError(e.message)) {
        final bool authenticated = !retry && await authenticateAgain();
        if (authenticated) {
          return getFoldersByName(name, ignoreTrashedFiles: ignoreTrashedFiles, retry: true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to get Google Drive folders with name $name');
    }
  }
}
