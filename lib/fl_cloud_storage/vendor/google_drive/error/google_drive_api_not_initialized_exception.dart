/// Google Drive API not initialized. _driveApi inside google_drive_service.dart is null.
class GoogleDriveApiNotInitializedException extends Error {
  GoogleDriveApiNotInitializedException();

  @override
  String toString() {
    return 'Google Drive API not initialized. _driveApi inside google_drive_service.dart is null.';
  }
}
