import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_file.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveFile implements CloudFile<drive.File> {
  GoogleDriveFile({
    required this.fileName,
    this.parents,
    required this.bytes,
    drive.Media? media,
  })  : _media = media,
        super();

  final String fileName;

  final List<String>? parents;

  final List<int>? bytes;

  final drive.Media? _media;

  @override
  drive.File get file {
    return drive.File()
      ..name = fileName
      ..parents = parents;
  }

  /// The payload of this Google Drive file.
  drive.Media? get media {
    if (_media != null) {
      return _media;
    }

    if (bytes == null) {
      return null;
    }

    final Stream<List<int>> mediaStream = Stream.value(bytes!);
    return drive.Media(
      mediaStream,
      bytes!.length,
    );
  }

  GoogleDriveFile copyWith({
    String? fileName,
    List<String>? parents,
    List<int>? bytes,
    drive.Media? media,
  }) {
    return GoogleDriveFile(
      fileName: fileName ?? this.fileName,
      parents: parents ?? this.parents,
      bytes: bytes ?? this.bytes,
    );
  }

  @override
  String get content => media?.stream.toString() ?? 'No content';
}
