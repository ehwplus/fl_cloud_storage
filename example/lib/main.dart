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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Column(
          children: [
            const SizedBox(height: 50),
            const Center(
              child: Text('fl_cloud_storage'),
            ),
            const SizedBox(height: 25),
            DropdownButton<StorageType>(
              value: selection,
              items: StorageType.values
                  .map<DropdownMenuItem<StorageType>>(
                    (StorageType e) => DropdownMenuItem(
                      key: Key(e.name),
                      value: e,
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              onChanged: (StorageType? value) {
                setState(() {
                  selection = value;
                });
              },
            ),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CloudStorageDemo(delegateKey: selection!),
                  ),
                );
              },
              child: const Text('Start demo'),
            )
          ],
        ));
  }
}
