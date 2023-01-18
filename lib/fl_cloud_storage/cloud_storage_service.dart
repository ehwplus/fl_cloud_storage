import 'dart:async';

import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_file.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_folder.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_service.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/util/logger.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/google_drive_service.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Root logger.
final Logger log = Logger(printer: MyPrinter('FL_CLOUD_STORAGE'));

/// The available delegates for the [CloudStorageService].
enum CloudStorageServiceEnum { GOOGLE_DRIVE }

/// TODO
class CloudStorageService {
  /// This class cannot be instantiated synchronously.
  /// Use `await CloudStorageService.initialize()`.
  CloudStorageService._(this.delegate);

  /// Maybe-async initialization of the cloud storage service.
  static FutureOr<CloudStorageService> initialize(
    CloudStorageServiceEnum delegate,
  ) async {
    final instance = CloudStorageService._(delegate);
    switch (delegate) {
      case CloudStorageServiceEnum.GOOGLE_DRIVE:
        instance._delegate = await GoogleDriveService.initialize();
        instance.delegateName = GoogleDriveService.serviceDisplayName;
        break;

      default:
        throw Exception('Incompatible delegate!');
    }
    instance.delegateName = 'Google Drive';
    log.d('Initialized and ready.');
    return instance;
  }

  /// The
  static List<Type> get availableServices => [GoogleDriveService];

  late ICloudService _delegate;

  /// Symbol of the currently active delegate for unambiguous identification.
  CloudStorageServiceEnum delegate;

  /// Display name of the currently active delegate.
  late String delegateName;

  Future<bool> authenticate() => _delegate.authenticate();

  Future<bool> authorize() => _delegate.authorize();

  Future<bool> deleteFile(CloudFile<dynamic> file) async {
    try {
      return _delegate.deleteFile(file);
    } on PlatformException catch (ex) {
      // GoogleDriveService specific error handling
      log.w(ex.message);
      await authorize();
      return deleteFile(file);
    } catch (ex) {
      // catch all
      log.e(ex);
    }
    return Future.value(false);
  }

  Future<bool> deleteFolder(CloudFolder<dynamic> folder) async {
    try {
      return _delegate.deleteFolder(folder);
    } on PlatformException catch (ex) {
      // GoogleDriveService specific error handling
      log.w(ex.message);
      await authorize();
      return deleteFolder(folder);
    } catch (ex) {
      // catch all
      log.e(ex);
    }
    return Future.value(false);
  }

  Future<bool> downloadFile(CloudFile<dynamic> file) {
    // TODO: implement downloadFile
    throw UnimplementedError();
  }

  Future<bool> downloadFolder(CloudFolder<dynamic> folder) {
    // TODO: implement downloadFolder
    throw UnimplementedError();
  }

  Future<List<CloudFile>> listAllFiles(CloudFolder folder) {
    // TODO: implement listAllFiles
    throw UnimplementedError();
  }

  Future<bool> replaceFile(CloudFile file) {
    // TODO: implement replaceFile
    throw UnimplementedError();
  }

  Future<bool> uploadFile(CloudFile file) {
    // TODO: implement uploadFile
    throw UnimplementedError();
  }

  Future<bool> uploadFolder(CloudFolder folder) {
    // TODO: implement uploadFolder
    throw UnimplementedError();
  }

  // TODO add all methods to invoke on the delegate
}
