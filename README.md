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
| Authorize       |     (✓*1)    |         |
| Upload files    |       ✓      |         |
| Download files  |       ✓      |         |
| Delete files    |       ✓      |         |
| iOS support     |       ✓      |         |
| Android support |       ✓      |         |
| Web support     |       ✓      |         |
| MacOS support   |       ?      |         |
| Windows support |       ?      |         |
| Linux support   |       ?      |         |

*1 Requesting full scopes right now, so full read and write access.
```
[v3.DriveApi.driveAppdataScope, v3.DriveApi.driveFileScope, v3.DriveApi.driveScope]
```

## Usage

Import the package:
```dart
import 'package:fl_cloud_storage/fl_cloud_storage.dart';
```

Initialize the service you want to use:
```
final driveService = await CloudStorageService.initialize(StorageType.GOOGLE_DRIVE);
```

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