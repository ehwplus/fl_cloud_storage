import 'package:fl_cloud_storage/fl_cloud_storage/util/platform_support_enum.dart';

/// The available delegates for the [CloudStorageService].
enum StorageType {
  GOOGLE_DRIVE(name: 'Google Drive', supportedPlatforms: {
    PlatformSupportEnum.ANDROID,
    PlatformSupportEnum.IOS,
    PlatformSupportEnum.WEB,
  });

  // add your cloud provider enum here, e.g. Dropbox

  const StorageType({required this.name, required this.supportedPlatforms});
  final String name;
  final Set<PlatformSupportEnum> supportedPlatforms;
}