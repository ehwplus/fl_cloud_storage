## 0.0.9

* Fix: GoogleDriveFile.copyWith should use media
* Fix: getFolderByName should return at least one folder

## 0.0.8

* Updating Drive files should work with GoogleDriveService.uploadFile function
* GoogleDriveService is making it easier to get the file content
* GoogleDriveFile meta data can contain a description
* Fix: GoogleDriveFile should return file.id (otherwise there is to reference to the cloud file)

## 0.0.4

Expose idToken/accessToken

## 0.0.2

Add void Function(Uint8List bytes)? onBytesDownloaded to CloudStorageService.downloadFile. This is required for
displaying images on Flutter web applications.

## 0.0.1

Inital release