import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_file.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveFile implements CloudFile<drive.File> {
  GoogleDriveFile({
    required this.file,
    required this.media,
  }) : super();

  @override
  final drive.File file;

  /// The payload of this Google Drive file.
  final drive.Media? media;

  GoogleDriveFile copyWith({
    drive.File? file,
    drive.Media? media,
  }) {
    return GoogleDriveFile(
      file: file ?? this.file,
      media: media ?? this.media,
    );
  }
}
