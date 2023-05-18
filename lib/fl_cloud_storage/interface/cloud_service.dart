import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_file.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_folder.dart';

abstract class ICloudService<FILE extends CloudFile<dynamic>,
    FOLDER extends CloudFolder<dynamic>> extends Type {
  /// Used to initialize this service asynchronously.
  static Future<void> initialize() {
    throw UnimplementedError();
  }

  // AUTH

  /// Whether the client has an active session running with this service.
  bool get isSignedIn;

  /// Authenticates the client and establishes a session to securely exchange
  /// files.
  Future<bool> authenticate();

  /// Logs the client out and ends the session.
  Future<bool> logout();

  /// Requests permissions/scopes
  /// This method is invoked whenever there is insufficient permission and
  /// should
  Future<bool> authorize();

  // HOOKS
  // None yet...

  // FILES

  /// List all files or those of a folder if not null
  Future<List<FILE>> getAllFiles({FOLDER? folder});

  /// Create or update a file
  /// This method is meant to be idempotent but must not lead to data loss when
  /// [overwrite] is false.
  Future<FILE> uploadFile({
    required FILE file,
    bool overwrite = false,
    FOLDER? parent,
  });

  /// Delete a file
  Future<bool> deleteFile({required FILE file});

  /// Download a file
  Future<FILE> downloadFile({required FILE file});

  // FOLDERS

  /// List all folders in the storage vendor.
  /// If optionally a folder is passed as parameter, then all folders in that
  /// folder will be returned.
  Future<List<FOLDER>> getAllFolders({FOLDER? folder});

  /// Get a [CloudFolder] by name.
  Future<FOLDER?> getFolderByName(String name);

  /// Create or update a folder
  /// This method is meant to be idempotent.
  Future<FOLDER> uploadFolder({required String name, FOLDER? parent});

  /// Delete a folder
  Future<bool> deleteFolder({required FOLDER folder});

  /// Download the contents of a folder
  Future<List<FILE>> downloadFolder({required FOLDER folder});
}
