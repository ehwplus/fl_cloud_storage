import 'package:fl_cloud_storage/fl_cloud_storage/cloud_storage_service.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_file.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_folder.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/util/platform_support_enum.dart';

abstract class ICloudService<FILE extends CloudFile<dynamic>,
    FOLDER extends CloudFolder<dynamic>> {
  static String get serviceDisplayName => throw UnimplementedError();

  static CloudStorageServiceEnum get serviceKey => throw UnimplementedError();

  static List<PlatformSupportEnum> get supportedPlatforms =>
      throw UnimplementedError();

  // AUTH

  /// Authenticates the client and establishes a session to securely exchange
  /// files.
  Future<bool> authenticate();

  /// Requests permissions/scopes
  /// This method is invoked whenever there is insufficient permission and
  /// should
  Future<bool> authorize();

  // HOOKS

  /// Used to initialize this service asynchronously.
  static Future<void> initialize() {
    throw UnimplementedError();
  }

  // FILES

  /// List all files or those of a folder
  Future<List<FILE>> listAllFiles(FOLDER folder);

  /// Create or update a file
  /// This method is meant to be idempotent but must not lead to data loss.
  Future<FILE> uploadFile(FILE file);

  /// Delete a file
  Future<bool> deleteFile(FILE file);

  /// Download a file
  Future<FILE> downloadFile(FILE file);

  /// Convenience method to replace a file at the same location.
  /// /!\ Warning: This method may ultimately lead to data loss.
  // Future<bool> replaceFile(FILE file) async {
  //   final deleteResult = await deleteFile(file);
  //   final uploadResult = await uploadFile(file);
  //   return deleteResult && uploadResult;
  // }

  /// Create or update a folder
  /// This method is meant to be idempotent.
  Future<bool> uploadFolder(FOLDER folder);

  /// Delete a folder
  Future<bool> deleteFolder(FOLDER folder);

  /// Download a folder
  Future<bool> downloadFolder(FOLDER folder);
}
