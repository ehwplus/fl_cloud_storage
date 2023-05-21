# fl_cloud_storage

## Features a cloud service can provide

1. Authenticate (login)
2. Authorize
3. Upload files to a cloud
4. Download files from a cloud
5. Delete files from cloud
6. Supported operating systems: iOS, Android, Web, MacOS, Windows, Linux (or subset)

## Supported clouds

|                 | Google Drive | Dropbox |
|-----------------|--------------|---------|
| Authenticate    |       ✓      |         |
| Authorize       |       ✓      |         |
| Upload files    |       ✓      |         |
| Download files  |       ✓      |         |
| Delete files    |       ✓      |         |
| iOS support     |       ✓      |         |
| Android support |       ✓      |         |
| Web support     |       ✓      |         |
| MacOS support   |       ?      |         |
| Windows support |       ?      |         |
| Linux support   |       ?      |         |

## Usage

Import the package:
```dart
import 'package:fl_cloud_storage/fl_cloud_storage.dart';
```

Initialize the service you want to use:
```
final driveService = await CloudStorageService.initialize(
  StorageType.GOOGLE_DRIVE,
  cloudStorageConfig: null, // optional parameter, vendor specific implementation
);
```

If you need special scopes, read the section for each cloud storage vendor.

1.a) Login:
```
cloudStorageService.authenticate();
```

1.b) Ask if the user is logged in:
```
cloudStorageService.isSignedIn;
```

1.c) Logout:
```
cloudStorageService.logout();
```

4.a) List files on cloud storage:
```
cloudStorageService.getAllFiles()
```

## Google Drive Cloud Storage

2.) Authorization

By default the app scope is used for Google Drive:
```
[v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope]
```

If you need full read and write access, add a cloudStorageConfig:
```
final driveService = await CloudStorageService.initialize<GoogleDriveScope>(
  StorageType.GOOGLE_DRIVE,
  cloudStorageConfig: GoogleDriveScope.full,
);
```

Behind the scens this scope is asked for:
```
[v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope, v3.DriveApi.driveScope]
```