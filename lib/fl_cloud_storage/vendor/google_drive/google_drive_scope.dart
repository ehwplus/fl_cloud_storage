/// Google Drive offers authorization via scopes.
enum GoogleDriveScope {
  /// See, edit, create, and delete only the specific Google Drive files you use with this app.
  /// [v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope]
  appData,

  /// See, edit, create, and delete all of your Google Drive files.
  /// [v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope, v3.DriveApi.driveScope]
  full;
}
