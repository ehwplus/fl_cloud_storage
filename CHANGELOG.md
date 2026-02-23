## 0.3.6

* Fix: A fresh login was no longer possible with version 0.3.5.

## 0.3.5

* Fix: CloudStorageService.authenticate should be async

## 0.3.4

* Fix: Cannot Download Binary Files (Incomplete Bytes Issue)

## 0.3.3

* Fix: Authentication should renew the driveApi as well

## 0.3.2

* Try to authenticate again instead of returning always a TooManyRequestsError

## 0.3.1

* Return TooManyRequestsError instead of DetailedApiRequestError

## 0.3.0

* Use latest libraries of google_sign_in and googleapis for new Google sign-in

## 0.2.0

* getFolderByName refactored into getFoldersByName

## 0.1.5

* getFolderByName should not return trashed folders by default

## 0.1.4

* Feature: Expose email, displayName and photoUrl (if given)

## 0.1.2

* Fix: Logout should delete remembered user inside cache

## 0.1.0

* Fix: Upload a new file on Google Drive

## 0.0.16

* Improvement: There should be a simple function to check if a file exists in the cloud.
* Fix: Function getAllFiles for Google Drive should return more than 100 files
* Refactor: Update libraries google_sign_in and googleapis

## 0.0.15

* Fix: Login at web should work

## 0.0.13

* Improvement: CloudFile with getters fileId, fileName and mimeType
* Improvement: Do not return trashed files or folders
* Fix: GoogleDriveFile.copyWith should use media
* Fix: getFolderByName should return at least one folder
* Fix: uploadFolder should set parent folder of folder
* Fix: Downloading images from Google Drive should work

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