import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:flutter/foundation.dart';
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

  final GoogleDriveScope driveScope;

  AuthenticationTokens? _authenticationTokens;

  @override
  AuthenticationTokens? get authenticationTokens => _authenticationTokens;

  @override
  bool get isSignedIn => _isSignedIn;

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
    final GoogleSignInAccount? googleUser = googleSignIn.currentUser ?? await _getGoogleUser(googleSignIn);

    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      _authenticationTokens = AuthenticationTokens(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final Map<String, String> authHeaders = await googleUser.authHeaders;
      _authenticateClient = _GoogleAuthClient(authHeaders);
    } else {
      throw Exception('Failed to obtain google user which shall be authenticated!');
    }
    return _isSignedIn = await googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> _getGoogleUser(GoogleSignIn googleSignIn) async {
    try {
      if (kIsWeb) {
        return await googleSignIn.signIn();
      }
      return (await googleSignIn.signInSilently(suppressErrors: false)) ??
          (interactiveLogin ? await googleSignIn.signIn() : null);
    } catch (e) {
      if (!interactiveLogin) {
        return googleSignIn.signIn();
      }
    }
    return null;
  }

  @override
  Future<bool> logout() async {
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
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
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<GoogleDriveFile> downloadFile({
    required GoogleDriveFile file,
    void Function(Uint8List bytes)? onBytesDownloaded,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to download file ${file.fileName}.');
    }

    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    if (file.file.id == null) {
      throw Exception('Must provide a file id of the file which shall be downloaded!');
    }
    final v3.Media media = await _driveApi!.files.get(
      file.file.id!,
      downloadOptions: v3.DownloadOptions.fullMedia,
    ) as v3.Media;

    final List<int> bytes = [];
    media.stream.listen((List<int> data) {
      bytes.insertAll(bytes.length, data);
    }, onDone: () async {
      if (onBytesDownloaded != null) {
        onBytesDownloaded(Uint8List.fromList(bytes));
      }
    }, onError: (dynamic error) {
      debugPrint('[sync] Unable to store downloaded photo ${file.fileName}: $error');
    });

    return Future.value(file.copyWith(media: media));
  }

  @override
  Future<GoogleDriveFile> uploadFile({
    required GoogleDriveFile file,
    GoogleDriveFolder? parent,
    bool overwrite = true,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to upload file.');
    }

    if (parent != null && parent.folder.id != null) {
      if (!(file.file.parents?.contains(parent.folder.id) ?? true)) {
        file.file.parents = [...?file.file.parents, parent.folder.id!];
      }
    }
    final uploadedFile = await _driveApi!.files.create(file.file, uploadMedia: file.media);
    return file.copyWith(
      fileName: uploadedFile.name,
      parents: uploadedFile.parents,
    );
  }

  @override
  Future<List<GoogleDriveFile>> getAllFiles({GoogleDriveFolder? folder}) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to get all files.');
    }

    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    final v3.FileList res;
    if (folder == null) {
      res = await _driveApi!.files.list(
        $fields: 'files/*',
      );
    } else {
      res = await _driveApi!.files.list(
        $fields: 'files/*',
        q: "'${folder.folder.id}' in parents",
      );
    }
    if (res.nextPageToken != null) {
      // TODO complete the files list
    }
    if (res.files == null) {
      throw Exception('Unable to list all files!');
    }
    return res.files!
        .map(
          (file) => GoogleDriveFile(
            fileName: file.name!,
            parents: file.parents,
            description: file.description,
            bytes: null,
          ),
        )
        .toList();
  }

  // FOLDERS

  @override
  Future<GoogleDriveFolder> uploadFolder({
    required String name,
    GoogleDriveFolder? parent,
  }) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to upload folder $name.');
    }

    final folder = v3.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parent != null) {
      folder.parents = [];
    }
    return GoogleDriveFolder(folder: await _driveApi!.files.create(folder));
  }

  @override
  Future<bool> deleteFolder({
    required GoogleDriveFolder folder,
  }) {
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
      _driveApi!.files.delete(folder.folder.id!);
      return Future.value(true);
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
  Future<List<GoogleDriveFolder>> getAllFolders({GoogleDriveFolder? folder}) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to get all folders.');
    }

    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    final v3.FileList res;
    if (folder == null) {
      res = await _driveApi!.files.list(q: "mimeType = 'application/vnd.google-apps.folder'");
    } else {
      res = await _driveApi!.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and '${folder.folder.id}' in parents",
      );
    }
    if (res.nextPageToken != null) {
      // TODO complete the files list
    }
    if (res.files == null) {
      throw Exception('Unable to list all files!');
    }
    return res.files!.map((folder) => GoogleDriveFolder(folder: folder)).toList();
  }

  @override
  Future<GoogleDriveFolder?> getFolderByName(String name) async {
    if (_driveApi == null) {
      throw Exception('DriveApi is null, unable to get folder $name.');
    }

    final v3.FileList res = await _driveApi!.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$name'",
    );
    return res.files?.length == 1 ? GoogleDriveFolder(folder: res.files![0]) : null;
  }
}