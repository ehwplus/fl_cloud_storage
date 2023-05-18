import 'dart:async';
import 'dart:convert';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as v3;

class CloudStorageDemo extends StatefulWidget {
  const CloudStorageDemo({Key? key, required this.delegateKey})
      : super(key: key);

  final StorageType delegateKey;

  @override
  State<CloudStorageDemo> createState() => _CloudStorageDemoState();
}

class _CloudStorageDemoState extends State<CloudStorageDemo> {
  late Future<CloudStorageService> service;

  late bool isSignedIn;

  @override
  void initState() {
    super.initState();
    service = Future.value(CloudStorageService.initialize(widget.delegateKey));
    service.then((value) => isSignedIn = value.isSignedIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: FutureBuilder(
        future: service,
        builder: (context, AsyncSnapshot<CloudStorageService> snapshot) {
          // FIXME google_sign_in_web
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
                mainAxisSize: MainAxisSize.min,
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
                    future: Future.value(svc.getAllFiles()),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        List files = snapshot.data!;
                        return Column(
                          children: [
                            Text('Amount of files: ${files.length}'),
                            Container(
                              height: 500,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                children: files
                                    .map((e) => Card(
                                          downloadFn: ({required file}) async {
                                            final newfile = await svc
                                                .downloadFile(file: file);
                                            showDialog<void>(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      'Downloaded content'),
                                                  content: Text(newfile
                                                          ?.content ??
                                                      'Unable to download file'),
                                                  actions: <Widget>[
                                                    TextButton(
                                                      style:
                                                          TextButton.styleFrom(
                                                        textStyle:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .labelLarge,
                                                      ),
                                                      child: const Text('Ok'),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          deleteFn: ({required file}) async {
                                            await svc.deleteFile(file: file);
                                            // fixme refresh view!
                                            setState(() {});
                                          },
                                          file: e,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final List<int> bytes = utf8.encode('erjkngekrngerkjngf');
                      final Stream<List<int>> mediaStream = Stream.value(bytes);
                      final file = GoogleDriveFile(
                        file: v3.File()
                          ..name = 'random.txt'
                          ..parents = [],
                        media: v3.Media(
                          mediaStream,
                          bytes.length,
                        ),
                      );
                      await svc.uploadFile(file: file);
                      setState(() {}); // refresh view
                    },
                    child: const Text('Upload a random.txt file'),
                  ),
                ],
              );
          }
        },
      ),
    );
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

  const Card({
    Key? key,
    required this.file,
    required this.downloadFn,
    required this.deleteFn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 75,
      height: 75,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(file.file.name),
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
        ],
      ),
    );
  }
}
