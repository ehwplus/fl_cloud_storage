/// Representation of a single file. The implementation is platform-specific.
abstract class CloudFile<FILE> {
  CloudFile(this.file);

  final FILE file;

  String get content;
}
