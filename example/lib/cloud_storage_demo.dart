import 'dart:async';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:flutter/material.dart';

class CloudStorageDemo extends StatefulWidget {
  const CloudStorageDemo({Key? key, required this.delegateKey})
      : super(key: key);

  final StorageType delegateKey;

  @override
  State<CloudStorageDemo> createState() => _CloudStorageDemoState();
}

class _CloudStorageDemoState extends State<CloudStorageDemo> {
  late Future<CloudStorageService> service;

  @override
  void initState() {
    super.initState();
    service = Future.value(CloudStorageService.initialize(widget.delegateKey));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: FutureBuilder(
        future: service,
        builder: (context, AsyncSnapshot<CloudStorageService> snapshot) {
          // FIXME google_sign_in_web
          // if (snapshot.hasError) {
          //   return OutlinedButton(
          //     onPressed: () async {
          //       await (await CloudStorageService.initialize(widget.delegateKey))
          //           .authenticate();
          //     },
          //     child: const Text('login'),
          //   );
          // }
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return const Center(child: CircularProgressIndicator());
            case ConnectionState.active:
            case ConnectionState.done:
              // print(snapshot.data);
              // print(snapshot.error);
              // return OutlinedButton(
              //   onPressed: () {
              //     final s = snapshot.data!;
              //     s.listAllFiles();
              //   },
              //   child: const Text('test'),
              // );
              return Text(
                'hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}',
              );
          }
        },
      ),
    );
  }
}
