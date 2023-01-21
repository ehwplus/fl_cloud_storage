import 'dart:async';

import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:flutter/material.dart';

class CloudStorageDemo extends StatefulWidget {
  const CloudStorageDemo({Key? key, required this.delegateKey})
      : super(key: key);

  final CloudStorageServiceEnum delegateKey;

  @override
  State<CloudStorageDemo> createState() => _CloudStorageDemoState();
}

class _CloudStorageDemoState extends State<CloudStorageDemo> {
  late Future<CloudStorageService> service;

  @override
  void initState() {
    service = Future.value(CloudStorageService.initialize(widget.delegateKey));
    super.initState();
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
              return const Text('has data');
          }
        },
      ),
    );
  }
}
