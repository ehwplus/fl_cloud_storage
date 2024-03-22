import 'dart:async';
import 'dart:convert';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:flutter/material.dart';

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

class _GoogleDriveDemoState extends State<GoogleDriveDemo> {
  late Future<CloudStorageService> service;

  late bool isSignedIn;

  @override
  void initState() {
    super.initState();
    service = Future.value(CloudStorageService.initialize<GoogleDriveScope>(
      widget.delegateKey,
      cloudStorageConfig: widget.driveScope,
    ));
    service.then((value) => isSignedIn = value.isSignedIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: FutureBuilder(
        future: service,
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
              final svc = snapshot.data!;
              if (!svc.isSignedIn) {
                return Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      await svc.authenticate();
                      setState(() {});
                    },
                    child: const Text('Authenticate'),
                  ),
                );
              }
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
                      if (isSignedIn)
                        OutlinedButton(
                          onPressed: () async {
                            await svc.logout();
                            setState(() {}); // refresh view
                          },
                          child: const Text('Logout'),
                        ),
                    ],
                  ),
                  FutureBuilder(
                    future: Future.value(svc.getAllFiles(
                      ignoreTrashedFiles: false,
                    )),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        List files = snapshot.data!;
                        return Column(
                          children: [
                            Text('Amount of files: ${files.length}'),
                            Wrap(
                              runSpacing: 16,
                              spacing: 16,
                              children: files
                                  .map((e) => Card(
                                        downloadFn: ({required file}) =>
                                            onDownloadFile(
                                          cloudStorageService: svc,
                                          file: file,
                                        ),
                                        deleteFn: (
                                                {required CloudFile<dynamic>
                                                    file}) =>
                                            onDelete(
                                          cloudStorageService: svc,
                                          file: file,
                                        ),
                                        checkIfExistsFn: ({required file}) =>
                                            checkIfExists(
                                          cloudStorageService: svc,
                                          file: file,
                                        ),
                                        file: e,
                                      ))
                                  .toList(),
                            ),
                          ],
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                  const Expanded(child: SizedBox.shrink()),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: OutlinedButton(
                      onPressed: () async {
                        final List<int> bytes =
                            utf8.encode('Das Wandern ist des Müllers Lust.');
                        final file = GoogleDriveFile(
                          fileId: null,
                          fileName: 'wandern.txt',
                          description: 'Über das Wandern',
                          parents: [],
                          bytes: bytes,
                        );
                        await svc.uploadFile(file: file);
                        setState(() {}); // refresh view
                      },
                      child: const Text('Upload a random.txt file'),
                    ),
                  ),
                ],
              );
          }
        },
      ),
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
    // fixme refresh view!
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
          if (file.trashed)
            Text('Trashed', style: Theme.of(context).textTheme.bodySmall),
          OutlinedButton(
            onPressed: () async {
              await downloadFn(file: file);
            },
            child: const Text('Download'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
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
