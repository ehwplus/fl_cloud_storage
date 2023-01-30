import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_folder.dart';
import 'package:googleapis/drive/v3.dart' as drive;

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
