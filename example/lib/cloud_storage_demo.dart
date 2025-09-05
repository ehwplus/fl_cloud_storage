import 'dart:async';
import 'dart:convert';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/cloud_storage_service.dart';
import 'package:fl_cloud_storage/fl_cloud_storage/vendor/google_drive/google_drive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as v3;

class GoogleDriveDemo extends StatefulWidget {
  const GoogleDriveDemo({
    super.key,
    required this.delegateKey,
    required this.driveScope,
  });

  final StorageType delegateKey;

  final GoogleDriveScope driveScope;

  @override
  State<GoogleDriveDemo> createState() => _GoogleDriveDemoState();
}

class _GoogleDriveDemoState extends State<GoogleDriveDemo> implements CloudStorageServiceListener<v3.DriveApi> {
  late Future<CloudStorageService> future;

  CloudStorageService? service;

  bool? isSignedIn;

  @override
  void initState() {
    super.initState();
    future = Future.value(CloudStorageService.initialize<GoogleDriveScope, v3.DriveApi>(
      widget.delegateKey,
      cloudStorageConfig: widget.driveScope,
      listener: this,
      googleDriveClientIdentifiers: const GoogleDriveClientIdentifiers(
        clientIdAndroid: String.fromEnvironment('CLIENT_ID_ANDROID'),
        clientIdIOS: String.fromEnvironment('CLIENT_ID_IOS'),
        clientIdMacOS: String.fromEnvironment('CLIENT_ID_MACOS'),
        clientIdWeb: String.fromEnvironment('CLIENT_ID_WEB'),
        serverClientId: String.fromEnvironment('CLIENT_ID_WEB'),
      ),
    ));
    future.then((CloudStorageService value) {
      service = value;
      isSignedIn = value.isSignedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: kIsWeb && isSignedIn == null
          ? const SignInWithGoogleButtonForWeb()
          : kIsWeb && isSignedIn == true && service != null
              ? _userIsSignedInWidget(service!)
              : FutureBuilder(
                  future: future,
                  builder: (context, AsyncSnapshot<CloudStorageService> snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return const Center(child: CircularProgressIndicator());
                      case ConnectionState.active:
                      case ConnectionState.done:
                        if (!snapshot.hasData) {
                          return Center(
                            child: Text(
                              'hasData: ${snapshot.hasData}\n\nhasError: ${snapshot.hasError}\n\nerror: ${snapshot.error}',
                            ),
                          );
                        }
                        final cloudStorageService = snapshot.data!;
                        if (!cloudStorageService.isSignedIn) {
                          return Center(
                            child: OutlinedButton(
                              onPressed: () async {
                                await cloudStorageService.authenticate();
                                setState(() {});
                              },
                              child: const Text('Authenticate'),
                            ),
                          );
                        }
                        return _userIsSignedInWidget(cloudStorageService);
                    }
                  },
                ),
    );
  }

  Widget _userIsSignedInWidget(CloudStorageService cloudStorageService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() {});
              },
              child: const Text('Force refresh view'),
            ),
            const SizedBox(
              width: 25,
            ),
            if (isSignedIn == true)
              OutlinedButton(
                onPressed: () async {
                  await cloudStorageService.logout();
                  setState(() {}); // refresh view
                },
                child: const Text('Logout'),
              ),
          ],
        ),
        FutureBuilder(
          future: Future.value(cloudStorageService.getAllFiles(
            ignoreTrashedFiles: false,
          )),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List files = snapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Text('Seeing ${files.length} files'),
                    Wrap(
                      runSpacing: 16,
                      spacing: 16,
                      alignment: WrapAlignment.center,
                      children: files
                          .map((e) => Card(
                                downloadFn: ({required file}) => onDownloadFile(
                                  cloudStorageService: cloudStorageService,
                                  file: file,
                                ),
                                deleteFn: ({required CloudFile<dynamic> file}) => onDelete(
                                  cloudStorageService: cloudStorageService,
                                  file: file,
                                ),
                                checkIfExistsFn: ({required file}) => checkIfExists(
                                  cloudStorageService: cloudStorageService,
                                  file: file,
                                ),
                                file: e,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              );
            }
            return const CircularProgressIndicator();
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: OutlinedButton(
            onPressed: () async {
              final List<int> bytes = utf8.encode('Das Wandern ist des Müllers Lust.');
              final file = GoogleDriveFile(
                fileId: null,
                fileName: 'wandern.txt',
                description: 'Über das Wandern',
                parents: [],
                bytes: bytes,
              );
              await cloudStorageService.uploadFile(file: file);
              setState(() {}); // refresh view
            },
            child: const Text('Upload a random.txt file'),
          ),
        ),
      ],
    );
  }

  Future<void> onDownloadFile({
    required CloudStorageService cloudStorageService,
    required CloudFile<dynamic> file,
  }) async {
    final newFile = await cloudStorageService.downloadFile(file: file);
    if (mounted) {
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Downloaded content'),
            content: Text(newFile?.content ?? 'Unable to download file'),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> checkIfExists({
    required CloudStorageService cloudStorageService,
    required CloudFile<dynamic> file,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final doesFileExist = await cloudStorageService.doesFileExist(file: file);
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Text('doesFileExist: $doesFileExist'),
    ));
  }

  Future<void> onDelete({
    required CloudStorageService cloudStorageService,
    required CloudFile<dynamic> file,
  }) async {
    await cloudStorageService.deleteFile(file: file);
    setState(() {});
  }

  @override
  void onAuthorized() {
    print('onAuthorized');
    setState(() {});
  }

  @override
  void onSignIn() {
    print('onSignIn');
    setState(() {
      isSignedIn = true;
    });
  }

  @override
  void onSignInFailed() {
    print('onSignInFailed');
    setState(() {});
  }

  @override
  void onSignOut() {
    print('onSignOut');
    setState(() {});
  }

  @override
  void onApiIsReady(v3.DriveApi api) {
    print('onApiIsReady');
    setState(() {});
  }
}

class Card extends StatelessWidget {
  final CloudFile<dynamic> file;

  final Future<void> Function({
    required CloudFile<dynamic> file,
  }) downloadFn;

  final Future<void> Function({
    required CloudFile<dynamic> file,
  }) deleteFn;

  final Future<void> Function({
    required CloudFile<dynamic> file,
  }) checkIfExistsFn;

  const Card({
    Key? key,
    required this.file,
    required this.downloadFn,
    required this.deleteFn,
    required this.checkIfExistsFn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(file.file.name),
          if (file.trashed) Text('Trashed', style: Theme.of(context).textTheme.bodySmall),
          OutlinedButton(
            onPressed: () async {
              await downloadFn(file: file);
            },
            child: const Text('Download'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await deleteFn(file: file);
            },
            child: const Text('Delete'),
          ),
          OutlinedButton(
            onPressed: () async {
              await checkIfExistsFn(file: file);
            },
            child: const Text('Check if a file exists in the cloud'),
          ),
        ],
      ),
    );
  }
}
