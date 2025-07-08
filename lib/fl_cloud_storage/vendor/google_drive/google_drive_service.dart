import 'dart:convert';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/cloud_storage_service.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/too_many_requests_error.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignIn, GoogleSignInAccount, GoogleSignInAuthentication;
import 'package:googleapis/drive/v3.dart' as v3;
import 'package:http/http.dart' as http;

const googleDriveSingleUserScope = [v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope];

/// Scope for sharing json with other Google users
const googleDriveFullScope = [v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope, v3.DriveApi.driveScope];

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService implements ICloudService<GoogleDriveFile, GoogleDriveFolder> {
  /// This class cannot be instantiated synchronously.
  /// Use `await GoogleDriveService.initialize()`.
  GoogleDriveService._(this.driveScope);

  /// Whether to do the google login silently or interactively.
  /// A previously authenticated google user can be logged in silently.
  /// FIXME this variable is not configurable as of now 1/20/23
  final bool interactiveLogin = false;

  /// The [v3.DriveApi] which is used to communicate with the google drive
  /// service.
  v3.DriveApi? _driveApi;

  late _GoogleAuthClient _authenticateClient;

  bool _isSignedIn = false;

  String? _email;
  String? _displayName;
  String? _photoUrl;

  final GoogleDriveScope driveScope;

  AuthenticationTokens? _authenticationTokens;

  @override
  AuthenticationTokens? get authenticationTokens => _authenticationTokens;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  @override
  String? get photoUrl => _photoUrl;

  /// Google drive service is supported on all platforms.
  ///
  static List<PlatformSupportEnum> get supportedPlatforms => [];

  static Future<GoogleDriveService> initialize({
    GoogleDriveScope? driveScope,
  }) async {
    final instance = GoogleDriveService._(
      driveScope ?? GoogleDriveScope.appData,
    );
    await instance.initializeApi();
    return instance;
  }

  Future<void> initializeApi() async {
    final isAuthenticated = await authenticate();
    if (isAuthenticated) {
      _driveApi = v3.DriveApi(_authenticateClient);
    }
    if (_driveApi == null) {
      throw Exception('Failed to initialize Google drive API!');
    }
  }

  // AUTH

  /// This method does a google login with scopes for google drive.
  ///
  /// The authentication headers of the google user are used to initialize the
  /// Google drive API later on.
  @override
  Future<bool> authenticate() async {
    final googleSignIn = GoogleSignIn(
      scopes: driveScope == GoogleDriveScope.appData ? googleDriveSingleUserScope : googleDriveFullScope,
    );

    // In the web, _googleSignIn.signInSilently() triggers the One Tap UX.
    //
    // It is recommended by Google Identity Services to render both the One Tap UX
    // and the Google Sign In button together to "reduce friction and improve
    // sign-in rates" ([docs](https://developers.google.com/identity/gsi/web/guides/display-button#html)).
    final GoogleSignInAccount? account = await _getGoogleUser(googleSignIn);

    final isAuthorizedForMobile = !kIsWeb && account != null;
    final isAuthorizedForWeb = kIsWeb && account != null && await googleSignIn.canAccessScopes(googleSignIn.scopes);
    if (!isAuthorizedForMobile && !isAuthorizedForWeb) {
      throw Exception('User is not authorized!');
    }

    final GoogleSignInAuthentication googleAuth = await account.authentication;
    _authenticationTokens = AuthenticationTokens(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    _email = account.email;
    _displayName = account.displayName;
    _photoUrl = account.photoUrl;

    // set auth headers for the drive api
    final Map<String, String> authHeaders = await account.authHeaders;
    _authenticateClient = _GoogleAuthClient(authHeaders);
    _driveApi = v3.DriveApi(_authenticateClient);

    return _isSignedIn = await googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> _getGoogleUser(GoogleSignIn googleSignIn) async {
    try {
      if (kIsWeb && !isSignedIn) {
        return await googleSignIn.signIn();
      }
      return (await googleSignIn.signInSilently(suppressErrors: false)) ??
          (interactiveLogin ? await googleSignIn.signIn() : null);
    } catch (e) {
      if (!interactiveLogin) {
        return googleSignIn.signIn();
      }
      log.e(e);
    }
    return null;
  }

  @override
  Future<bool> logout() async {
    final googleSignIn = GoogleSignIn();
    try {
      await googleSignIn.disconnect();
    } on PlatformException catch (_) {
      await googleSignIn.signOut();
    }
    _email = null;
    _displayName = null;
    _photoUrl = null;

    return _isSignedIn = await googleSignIn.isSignedIn();
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
        final bool authenticated = await authenticate();
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
        final bool authenticated = !retry && await authenticate();
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
        final bool authenticated = !retry && await authenticate();
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
        final bool authenticated = !retry && await authenticate();
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
        final bool authenticated = !retry && await authenticate();
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
        final bool authenticated = await authenticate();
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
        final bool authenticated = !retry && await authenticate();
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
        final bool authenticated = !retry && await authenticate();
        if (authenticated) {
          return getFoldersByName(name, ignoreTrashedFiles: ignoreTrashedFiles, retry: true);
        }
        throw TooManyRequestsError();
      }
      throw Exception('Unable to get Google Drive folders with name $name');
    }
  }
}
