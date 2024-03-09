/// Representation of a single file. The implementation is platform-specific.
abstract class CloudFile<FILE> {
  CloudFile(this.file);

  final FILE file;

  String get content;

  /// Example 1: 'application/json'
  /// Example 2: 'image/jpeg'
  /// MIME = Multipurpose Internet Mail Extensions
  /// https://wiki.selfhtml.org/wiki/MIME-Type/%C3%9Cbersicht
  String? get mimeType;

  /// The non-unique name of the file.
  String get fileName;

  /// Unique id of this file. Can be null if the file is not uploaded yet.
  /// Be aware, that a file without [fileId] cannot be used to download it from cloud.
  String? get fileId;
}