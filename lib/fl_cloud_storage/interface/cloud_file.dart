abstract class CloudFile<FILE> {
  CloudFile(this.file);

  final FILE file;

  String get content;
}
