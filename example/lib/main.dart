import 'package:example/cloud_storage_demo.dart';
import 'package:fl_cloud_storage/fl_cloud_storage.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const title = 'fl_cloud_storage';
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: title),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final CloudStorageService cloudStorageService;

  StorageType? selection = StorageType.GOOGLE_DRIVE;

  GoogleDriveScope? driveScope;

  @override
  Widget build(BuildContext context) {
    final storageTypeOptions = StorageType.values
        .map<DropdownMenuItem<StorageType>>(
          (StorageType storageType) => DropdownMenuItem(
            key: Key(storageType.name),
            value: storageType,
            child: Text(storageType.name),
          ),
        )
        .toList();
    return Scaffold(
        appBar: AppBar(
          title: Text('${widget.title} - Login'),
        ),
        body: Column(
          children: [
            const SizedBox(height: 50),
            const Center(
              child: Text('1. Select your vendor'),
            ),
            DropdownButton<StorageType>(
              value: selection,
              items: storageTypeOptions,
              onChanged: (StorageType? value) {
                setState(() {
                  selection = value;
                });
              },
            ),
            const Center(
              child: Text('2. Select the scope'),
            ),
            if (selection == StorageType.GOOGLE_DRIVE)
              DropdownButton<GoogleDriveScope>(
                value: driveScope,
                items: GoogleDriveScope.values
                    .map<DropdownMenuItem<GoogleDriveScope>>(
                      (GoogleDriveScope e) => DropdownMenuItem(
                        key: Key(e.name),
                        value: e,
                        child: Text(e.name),
                      ),
                    )
                    .toList(),
                onChanged: (GoogleDriveScope? value) {
                  setState(() {
                    driveScope = value;
                  });
                },
              ),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: driveScope == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GoogleDriveDemo(
                            delegateKey: selection!,
                            driveScope: driveScope!,
                          ),
                        ),
                      );
                    },
              child: const Text('Start demo'),
            )
          ],
        ));
  }
}
