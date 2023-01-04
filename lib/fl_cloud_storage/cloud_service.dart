import 'dart:html';

import 'cloud_file.dart';

abstract class CloudService {

  CloudService();

  /// List all files or those of a folder
  Future<FileList> files({String pathToFile});

  /// Create or update a file
  Future<bool> uploadFile(CloudFile file);

  /// Delete a file
  Future<bool> deleteFile(CloudFile file);

  /// Download a file
  Future<bool> downloadFile(CloudFile file);

  /// Request permissions/scopes
  Future<bool> authorize();

}