<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

fl_cloud_storage

## Features a cloud service can provide

1. Authenticate (login)
2. Authorize
3. Upload files to a cloud
4. Download files from a cloud
5. Delete files from cloud
6. Supported operating systems: iOS, Android, Web, MacOS, Windows, Linux (or subset)

## Supported clouds

|                 | Google Drive | iCloud |
|-----------------|--------------|--------|
| Authenticate    |              |        |
| Authorize       |              |        |
| Upload files    |              |        |
| Download files  |              |        |
| Delete files    |              |        |
| iOS support     |              |        |
| Android support |              |        |
| Web support     |              |        |
| MacOS support   |              |        |
| Windows support |              |        |
| Linux support   |              |        |

## Usage

```dart
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
            ),
            body: const Center(
              child: Text('fl_cloud_storage'),
            )
    );
  }
}
```
