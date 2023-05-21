import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_folder.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Technically the Google drive folder is also a Drive file.
/// The children inside a folder contains the folder id.
/// Hence, a file can be part of more than just one folder.
class GoogleDriveFolder implements CloudFolder<drive.File> {
  GoogleDriveFolder({required this.folder}) : super();

  @override
  final drive.File folder;

  GoogleDriveFolder copyWith({
    drive.File? folder,
  }) {
    return GoogleDriveFolder(
      folder: folder ?? this.folder,
    );
  }
}
