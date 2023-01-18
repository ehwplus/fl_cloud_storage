import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_service.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/util/platform_support_enum.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/google_drive_file.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/google_drive_folder.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

const googleDriveSingleUserScope = [
  drive.DriveApi.driveAppdataScope,
  drive.DriveApi.driveFileScope
];

/// Scope for sharing json with other Google users
const googleDriveFullScope = [
  drive.DriveApi.driveAppdataScope,
  drive.DriveApi.driveFileScope,
  drive.DriveApi.driveScope
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

  late drive.DriveApi _driveApi;

  static String get serviceDisplayName => 'Google Drive';

  /// Google drive service is supported on all platforms.
  static List<PlatformSupportEnum> get supportedPlatforms =>
      PlatformSupportEnum.values;

  static Future<GoogleDriveService> initialize() async {
    final instance = GoogleDriveService._();

    // TODO move the bottom stuff into authenticate?
    const onlySilent = false;
    final googleSignIn = GoogleSignIn(
      scopes: googleDriveSingleUserScope,
    );
    final isSignedIn = await googleSignIn.isSignedIn();
    GoogleSignInAccount? googleUser = googleSignIn.currentUser;

    if (instance._driveApi == null) {
      if (!isSignedIn || googleUser == null) {
        final Future<GoogleSignInAccount?> Function({bool onlySilent})
            getGoogleUser = ({bool onlySilent = false}) async {
          try {
            return (await googleSignIn.signInSilently(suppressErrors: false)) ??
                (onlySilent ? null : await googleSignIn.signIn());
          } catch (e) {
            if (!onlySilent) {
              return googleSignIn.signIn();
            }
          }
          return null;
        };
        googleUser = await getGoogleUser(onlySilent: onlySilent);
      }

      if (googleUser != null) {
        final Map<String, String> authHeaders = await googleUser.authHeaders;
        final authenticateClient = _GoogleAuthClient(authHeaders);
        instance._driveApi = drive.DriveApi(authenticateClient);
      } else {
        // THROW!!!
      }
    }
    return instance;
  }

  // AUTH

  @override
  Future<bool> authenticate() {
    // TODO: implement authenticate
    throw UnimplementedError();
  }

  @override
  Future<bool> authorize() {
    // TODO: implement authorize
    throw UnimplementedError();
  }

  // FILES

  @override
  Future<bool> deleteFile(GoogleDriveFile file) {
    // TODO: implement deleteFile
    throw UnimplementedError();
  }

  @override
  Future<GoogleDriveFile> downloadFile(GoogleDriveFile file) async {
    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    if (file.file.id == null) {
      // log.e this
      throw Exception(
        'Must provide a file id of the file which shall be downloaded',
      );
    }
    final drive.Media media = await _driveApi.files.get(
      file.file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    return Future.value(file.copyWith(media: media));
  }

  @override
  Future<GoogleDriveFile> uploadFile(GoogleDriveFile file) async {
    return file.copyWith(
      file: await _driveApi.files.create(file.file, uploadMedia: file.media),
    );
  }

  @override
  Future<List<GoogleDriveFile>> listAllFiles(GoogleDriveFolder folder) async {
    // Completes with a commons.ApiRequestError if the API endpoint returned an error
    final drive.FileList res = await _driveApi.files.list(
      $fields: 'files/*',
      q: "'${folder.folder.id}' in parents",
    );
    if (res.nextPageToken != null) {
      // complete the files list
    }
    if (res.files == null) {
      // wtf/e log here
      throw Exception('Unable to fetch files!');
    }
    return res.files!
        .map((e) => GoogleDriveFile(file: e, media: null))
        .toList();
  }

  // FOLDERS

  @override
  Future<bool> uploadFolder(GoogleDriveFolder folder) {
    //   var _drive = v3.DriveApi(http_client);
    //   var _createFolder = await _drive.files.create(
    //     v3.File()
    //       ..name = 'FileName'
    //       ..parents = [
    //         '1f4tjhpBJwF5t6FpYvufTljk8Gapbwajc'
    //       ] // Optional if you want to create subfolder
    //       ..mimeType =
    //           'application/vnd.google-apps.folder', // this defines its folder
    //   );
    // });
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteFolder(GoogleDriveFolder folder) {
    // TODO: implement deleteFolder
    throw UnimplementedError();
  }

  @override
  Future<bool> downloadFolder(GoogleDriveFolder folder) {
    // TODO: implement downloadFolder
    throw UnimplementedError();
  }
}
