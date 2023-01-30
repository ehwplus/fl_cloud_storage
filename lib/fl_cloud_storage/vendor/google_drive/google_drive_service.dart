import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_service.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/util/platform_support_enum.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/google_drive_file.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/google_drive_folder.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignIn, GoogleSignInAccount;
import 'package:googleapis/drive/v3.dart' as v3;
import 'package:http/http.dart' as http;

const googleDriveSingleUserScope = [
  v3.DriveApi.driveAppdataScope,
  v3.DriveApi.driveFileScope
];

/// Scope for sharing json with other Google users
const googleDriveFullScope = [
  v3.DriveApi.driveAppdataScope,
  v3.DriveApi.driveFileScope,
  v3.DriveApi.driveScope
];

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService
    implements ICloudService<GoogleDriveFile, GoogleDriveFolder> {
  /// This class cannot be instantiated synchronously.
  /// Use `await GoogleDriveService.initialize()`.
  GoogleDriveService._();

  /// Whether to do the google login silently or interactively.
  /// A previously authenticated google user can be logged in silently.
  /// FIXME this variable is not configurable as of now 1/20/23
  final bool interactiveLogin = false;

  /// The [v3.DriveApi] which is used to communicate with the google drive
  /// service.
  late v3.DriveApi _driveApi;

  late _GoogleAuthClient _authenticateClient;

  late bool _isSignedIn = false;

  @override
  bool get isSignedIn => _isSignedIn;

  /// Google drive service is supported on all platforms.
  ///
  static List<PlatformSupportEnum> get supportedPlatforms => [];

  static Future<GoogleDriveService> initialize() async {
    final instance = GoogleDriveService._();
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
      scopes: googleDriveFullScope,
    );
    // final _isSignedIn = await googleSignIn.isSignedIn();
    final GoogleSignInAccount? googleUser =
        googleSignIn.currentUser ?? await _getGoogleUser(googleSignIn);

    if (googleUser != null) {
      final Map<String, String> authHeaders = await googleUser.authHeaders;
      _authenticateClient = _GoogleAuthClient(authHeaders);
    } else {
      throw Exception(
        'Failed to obtain google user which shall be authenticated!',
      );
    }
    return _isSignedIn = await googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> _getGoogleUser(GoogleSignIn googleSignIn) async {
    try {
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
    throw UnimplementedError();
  }

  // FILES

  @override
  Future<bool> deleteFile({required GoogleDriveFile file}) {
    if (file.file.id == null) {
      throw Exception(
        'Must provide a file id of the file which shall be downloaded!',
      );
    }
    // If the used http.Client completes with an error when making a REST call,
    // this method will complete with the same error.
    try {
      _driveApi.files.delete(file.file.id!);
      return Future.value(true);
    } catch (ex) {
      return Future.value(false);
    }
  }

  @override
  Future<GoogleDriveFile> downloadFile({required GoogleDriveFile file}) async {
    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    if (file.file.id == null) {
      throw Exception(
        'Must provide a file id of the file which shall be deleted!',
      );
    }
    final v3.Media media = await _driveApi.files.get(
      file.file.id!,
      downloadOptions: v3.DownloadOptions.fullMedia,
    ) as v3.Media;
    return Future.value(file.copyWith(media: media));
  }

  @override
  Future<GoogleDriveFile> uploadFile({
    required GoogleDriveFile file,
    GoogleDriveFolder? parent,
    bool overwrite = false,
  }) async {
    if (parent != null && parent.folder.id != null) {
      if (!(file.file.parents?.contains(parent.folder.id) ?? true)) {
        file.file.parents = [...?file.file.parents, parent.folder.id!];
      }
    }
    return file.copyWith(
      file: await _driveApi.files.create(file.file, uploadMedia: file.media),
    );
  }

  @override
  Future<List<GoogleDriveFile>> listAllFiles(
      {GoogleDriveFolder? folder}) async {
    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    final v3.FileList res;
    if (folder == null) {
      res = await _driveApi.files.list(
        $fields: 'files/*',
      );
    } else {
      res = await _driveApi.files.list(
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
        .map((file) => GoogleDriveFile(file: file, media: null))
        .toList();
  }

  // FOLDERS

  @override
  Future<GoogleDriveFolder> uploadFolder({
    required String name,
    GoogleDriveFolder? parent,
  }) async {
    final folder = v3.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parent != null) {
      folder.parents = [];
    }
    return GoogleDriveFolder(folder: await _driveApi.files.create(folder));
  }

  @override
  Future<bool> deleteFolder({
    required GoogleDriveFolder folder,
  }) {
    if (folder.folder.id == null) {
      // log.e this
      throw Exception(
        'Must provide a folder id of the folder which shall be deleted!',
      );
    }
    // If the used http.Client completes with an error when making a REST call,
    // this method will complete with the same error.
    try {
      _driveApi.files.delete(folder.folder.id!);
      return Future.value(true);
    } catch (ex) {
      return Future.value(false);
    }
  }

  @override
  Future<List<GoogleDriveFile>> downloadFolder({
    required GoogleDriveFolder folder,
  }) async {
    final files = await listAllFiles(folder: folder);
    return Future.wait(files.map((file) => downloadFile(file: file)).toList());
  }
}
