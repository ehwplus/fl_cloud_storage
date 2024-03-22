import 'package:fl_cloud_storage/fl_cloud_storage/interface/cloud_file.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveFile implements CloudFile<drive.File> {
  GoogleDriveFile({
    required this.fileId,
    required this.fileName,
    this.parents,
    required this.bytes,
    this.description,
    drive.Media? media,
    this.fileContent,
    this.mimeType,
    this.trashed = false,
  })  : _media = media,
        super();

  @override
  final String? fileId;

  @override
  final String fileName;

  final List<String>? parents;

  final List<int>? bytes;

  final drive.Media? _media;

  final String? fileContent;

  @override
  final String? mimeType;

  /// Optional value. Some text that is stored in the metadata of the file.
  final String? description;

  @override
  final bool trashed;

  @override
  drive.File get file {
    return drive.File()
      ..id = fileId
      ..name = fileName
      ..description = description
      ..mimeType = mimeType
      ..trashed = trashed
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
    String? fileId,
    String? fileName,
    String? description,
    List<String>? parents,
    String? mimeType,
    bool? trashed,
    List<int>? bytes,
    drive.Media? media,
    String? fileContent,
  }) {
    return GoogleDriveFile(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      description: description ?? this.description,
      parents: parents ?? this.parents,
      bytes: bytes ?? this.bytes,
      media: media ?? this.media,
      mimeType: mimeType ?? this.mimeType,
      fileContent: fileContent ?? this.fileContent,
      trashed: trashed ?? this.trashed,
    );
  }

  @override
  String get content => media?.stream.toString() ?? fileContent ?? '';
}
