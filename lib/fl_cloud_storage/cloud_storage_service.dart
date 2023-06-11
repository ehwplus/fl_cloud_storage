import 'dart:async';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/util/logger.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Root logger.
final Logger log = Logger(
  printer: MyPrinter('FL_CLOUD_STORAGE'),
  level: Level.verbose,
);

/// This class is the entrypoint for the fl_cloud_storage package. It is a
/// factory that - given the [delegateKey] generates the according delegate
/// instance.
class CloudStorageService {
  /// This class cannot be instantiated synchronously.
  /// Use `await CloudStorageService.initialize()`.
  CloudStorageService._(this.delegateKey);

  /// Maybe-async initialization of the cloud storage service.
  static FutureOr<CloudStorageService> initialize<CloudStorageConfig>(
    StorageType delegate, {
    CloudStorageConfig? cloudStorageConfig,
  }) async {
    final instance = CloudStorageService._(delegate);
    switch (delegate) {
      case StorageType.GOOGLE_DRIVE:
        instance._delegate = await GoogleDriveService.initialize(
          driveScope: cloudStorageConfig as GoogleDriveScope,
        );
        break;

      // add your cloud providers here
    }
    log.d('Initialized and ready.');
    return instance;
  }

  /// Symbol of the currently active delegate for unambiguous identification.
  StorageType delegateKey;

  /// Display name of the currently active delegate.
  late String delegateDisplayName;

  late ICloudService _delegate;

  /// Whether the client is signed in or not.
  bool get isSignedIn => _delegate.isSignedIn;

  /// Invokes the [authenticate] method of the delegate instance.
  FutureOr<bool> authenticate() {
    try {
      return _delegate.authenticate();
    } catch (ex) {
      log.e(ex);
    }
    return false;
  }

  /// Invokes the [logout] method of the delegate instance.
  FutureOr<bool> logout() {
    try {
      return _delegate.logout();
    } catch (ex) {
      log.e(ex);
    }
    return false;
  }

  /// Invokes the [authorize] method of the delegate instance.
  FutureOr<bool> authorize() => _delegate.authorize();

  /// Invokes the [deleteFile] method of the delegate instance.
  FutureOr<bool> deleteFile({
    required CloudFile<dynamic> file,
  }) async {
    try {
      return _delegate.deleteFile(file: file);
    } on PlatformException catch (ex) {
      // GoogleDriveService specific error handling
      log.w(ex.message);
      await authorize();
      return deleteFile(file: file);
    } catch (ex) {
      // catch all
      log.e(ex);
    }
    return Future.value(false);
  }

  /// Invokes the [deleteFolder] method of the delegate instance.
  FutureOr<bool> deleteFolder({
    required CloudFolder<dynamic> folder,
  }) async {
    try {
      return _delegate.deleteFolder(folder: folder);
    } on PlatformException catch (ex) {
      // GoogleDriveService specific error handling
      log.w(ex.message);
      await authorize();
      return deleteFolder(folder: folder);
    } catch (ex) {
      // catch all
      log.e(ex);
    }
    return Future.value(false);
  }

  /// Invokes the [downloadFile] method of the delegate instance.
  FutureOr<CloudFile<dynamic>?> downloadFile({
    required CloudFile<dynamic> file,
    void Function(Uint8List bytes)? onBytesDownloaded,
  }) async {
    try {
      return _delegate.downloadFile(file: file, onBytesDownloaded: onBytesDownloaded);
    } catch (ex) {
      log.e(ex);
    }
    return null;
  }

  /// Invokes the [downloadFolder] method of the delegate instance.
  FutureOr<List<CloudFile<dynamic>>> downloadFolder({
    required CloudFolder<dynamic> folder,
  }) {
    try {
      return _delegate.downloadFolder(folder: folder);
    } catch (ex) {
      log.e(ex);
    }
    return [];
  }

  /// Invokes the [getAllFiles] method of the delegate instance.
  FutureOr<List<CloudFile<dynamic>>> getAllFiles({
    CloudFolder<dynamic>? folder,
  }) {
    try {
      return _delegate.getAllFiles(folder: folder);
    } catch (ex) {
      log.e(ex);
    }
    return [];
  }

  /// Invokes the [getFolderByName] method of the delegate instance.
  FutureOr<CloudFolder<dynamic>?> getFolderByName(String name) {
    try {
      return _delegate.getFolderByName(name);
    } catch (ex) {
      log.e(ex);
    }
    return null;
  }

  /// Invokes the [getAllFolders] method of the delegate instance.
  FutureOr<List<CloudFolder<dynamic>>> getAllFolders({
    CloudFolder<dynamic>? folder,
  }) {
    try {
      return _delegate.getAllFolders(folder: folder);
    } catch (ex) {
      log.e(ex);
    }
    return [];
  }

  /// Invokes the [uploadFile] method of the delegate instance.
  FutureOr<CloudFile<dynamic>?> uploadFile({
    required CloudFile<dynamic> file,
    CloudFolder<dynamic>? parent,
    bool overwrite = false,
  }) async {
    try {
      return await _delegate.uploadFile(
        file: file,
        parent: parent,
        overwrite: overwrite,
      );
    } catch (ex) {
      log.e(ex);
    }
    return null;
  }

  /// Invokes the [uploadFile] method of the delegate instance.
  FutureOr<CloudFolder<dynamic>?> uploadFolder({
    required String name,
    CloudFolder<dynamic>? parent,
  }) {
    try {
      return _delegate.uploadFolder(name: name, parent: parent);
    } catch (ex) {
      log.e(ex);
    }
    return null;
  }
}
