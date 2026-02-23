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
  static const _googleDriveFolderMimeType =
      'application/vnd.google-apps.folder';
  static const _imageExtensions = <String>[
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.heic',
    '.heif',
    '.bmp',
  ];

  late final Future<CloudStorageService> _serviceFuture;
  Future<List<CloudFile<dynamic>>>? _filesFuture;
  CloudFile<dynamic>? _selectedFile;

  @override
  void initState() {
    super.initState();
    _serviceFuture = Future<CloudStorageService>.sync(
      () => CloudStorageService.initialize<GoogleDriveScope>(
        widget.delegateKey,
        cloudStorageConfig: widget.driveScope,
      ),
    );
  }

  Future<List<CloudFile<dynamic>>> _loadFiles(
      CloudStorageService cloudStorageService) {
    return Future<List<CloudFile<dynamic>>>.sync(
      () => cloudStorageService.getAllFiles(ignoreTrashedFiles: false),
    );
  }

  void _refreshFiles(CloudStorageService cloudStorageService,
      {bool clearSelection = false}) {
    setState(() {
      if (clearSelection) {
        _selectedFile = null;
      }
      _filesFuture = _loadFiles(cloudStorageService);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: FutureBuilder<CloudStorageService>(
        future: _serviceFuture,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return const Center(child: CircularProgressIndicator());
            case ConnectionState.active:
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to initialize cloud storage service.\n\n${snapshot.error}',
                  ),
                );
              }
              final cloudStorageService = snapshot.data;
              if (cloudStorageService == null) {
                return const Center(
                    child: Text('Unable to initialize cloud storage service.'));
              }
              if (!cloudStorageService.isSignedIn) {
                return Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      await cloudStorageService.authenticate();
                      if (!mounted) {
                        return;
                      }
                      _refreshFiles(cloudStorageService, clearSelection: true);
                    },
                    child: const Text('Authenticate'),
                  ),
                );
              }
              _filesFuture ??= _loadFiles(cloudStorageService);
              final isWideLayout = MediaQuery.sizeOf(context).width > 600;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _clearSelectionIfWide(isWideLayout),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () => _refreshFiles(cloudStorageService),
                            child: const Text('Force refresh view'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              await cloudStorageService.logout();
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _filesFuture = null;
                                _selectedFile = null;
                              });
                            },
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<List<CloudFile<dynamic>>>(
                          future: _filesFuture,
                          builder: (context, filesSnapshot) {
                            switch (filesSnapshot.connectionState) {
                              case ConnectionState.none:
                              case ConnectionState.waiting:
                                return const Center(
                                    child: CircularProgressIndicator());
                              case ConnectionState.active:
                              case ConnectionState.done:
                                if (filesSnapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Unable to load files.\n\n${filesSnapshot.error}',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                final files = filesSnapshot.data ??
                                    <CloudFile<dynamic>>[];
                                return _buildFilesAndDetailsView(
                                  cloudStorageService: cloudStorageService,
                                  files: files,
                                  isWideLayout: isWideLayout,
                                );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
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
                          await cloudStorageService.uploadFile(file: file);
                          if (!mounted) {
                            return;
                          }
                          _refreshFiles(cloudStorageService);
                        },
                        child: const Text('Upload a random.txt file'),
                      ),
                    ],
                  ),
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildFilesAndDetailsView({
    required CloudStorageService cloudStorageService,
    required List<CloudFile<dynamic>> files,
    required bool isWideLayout,
  }) {
    final selectedFile = _findCurrentSelectedFile(files);
    if (!isWideLayout) {
      return _buildFilesList(
        cloudStorageService: cloudStorageService,
        files: files,
        isWideLayout: isWideLayout,
        selectedFile: null,
      );
    }
    if (selectedFile == null) {
      return _buildFilesList(
        cloudStorageService: cloudStorageService,
        files: files,
        isWideLayout: isWideLayout,
        selectedFile: null,
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildFilesList(
            cloudStorageService: cloudStorageService,
            files: files,
            isWideLayout: isWideLayout,
            selectedFile: selectedFile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildFileDetailsContent(
              selectedFile,
              showCloseButton: true,
              onClose: _clearSelection,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilesList({
    required CloudStorageService cloudStorageService,
    required List<CloudFile<dynamic>> files,
    required bool isWideLayout,
    required CloudFile<dynamic>? selectedFile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amount of files: ${files.length}'),
        const SizedBox(height: 8),
        Expanded(
          child: files.isEmpty
              ? const Center(
                  child: Text('No files found in Google Drive.'),
                )
              : ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isSelected =
                        isWideLayout && _isSameFile(file, selectedFile);
                    return ListTile(
                      onTap: () => _onFileTileTap(
                        file,
                        isWideLayout: isWideLayout,
                      ),
                      selected: isSelected,
                      leading: Icon(_iconForFile(file)),
                      title: Text(file.fileName),
                      subtitle: Text(
                        _subtitleForFile(file),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<_FileAction>(
                        tooltip: 'More actions',
                        onSelected: (action) => _handleFileAction(
                          action: action,
                          cloudStorageService: cloudStorageService,
                          file: file,
                          isWideLayout: isWideLayout,
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem<_FileAction>(
                            value: _FileAction.details,
                            child: Text('Details'),
                          ),
                          PopupMenuItem<_FileAction>(
                            value: _FileAction.download,
                            child: Text('Download'),
                          ),
                          PopupMenuItem<_FileAction>(
                            value: _FileAction.delete,
                            child: Text('Delete'),
                          ),
                          PopupMenuItem<_FileAction>(
                            value: _FileAction.checkIfExists,
                            child: Text('Check if file exists in the cloud'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _subtitleForFile(CloudFile<dynamic> file) {
    final typeLabel = _typeLabelForFile(file);
    final mimeType = file.mimeType ?? 'unknown MIME type';
    final lastModified = _lastModifiedLabel(file);
    final trashedSuffix = file.trashed ? ' • Trashed' : '';
    return '$typeLabel • $mimeType • Zuletzt geändert: $lastModified$trashedSuffix';
  }

  String _lastModifiedLabel(CloudFile<dynamic> file) {
    if (file is! GoogleDriveFile || file.modifiedTime == null) {
      return 'unbekannt';
    }
    final modifiedTime = file.modifiedTime!.toLocal();
    final day = modifiedTime.day.toString().padLeft(2, '0');
    final month = modifiedTime.month.toString().padLeft(2, '0');
    final year = modifiedTime.year.toString();
    final hour = modifiedTime.hour.toString().padLeft(2, '0');
    final minute = modifiedTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  IconData _iconForFile(CloudFile<dynamic> file) {
    if (_isFolder(file)) {
      return Icons.folder_outlined;
    }
    final mimeType = file.mimeType?.toLowerCase() ?? '';
    final fileName = file.fileName.toLowerCase();
    final isJsonFile = mimeType.contains('json') || fileName.endsWith('.json');
    if (isJsonFile) {
      return Icons.data_object_outlined;
    }
    final isImageFile = mimeType.startsWith('image/') ||
        _imageExtensions.any((extension) => fileName.endsWith(extension));
    if (isImageFile) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _typeLabelForFile(CloudFile<dynamic> file) {
    if (_isFolder(file)) {
      return 'Ordner';
    }
    final icon = _iconForFile(file);
    if (icon == Icons.data_object_outlined) {
      return 'JSON file';
    }
    if (icon == Icons.image_outlined) {
      return 'Image file';
    }
    return 'Other file';
  }

  bool _isFolder(CloudFile<dynamic> file) {
    return file.mimeType?.toLowerCase() == _googleDriveFolderMimeType;
  }

  CloudFile<dynamic>? _findCurrentSelectedFile(List<CloudFile<dynamic>> files) {
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      return null;
    }
    for (final file in files) {
      if (_isSameFile(file, selectedFile)) {
        return file;
      }
    }
    return null;
  }

  bool _isSameFile(CloudFile<dynamic> a, CloudFile<dynamic>? b) {
    if (b == null) {
      return false;
    }
    if (a.fileId != null && b.fileId != null) {
      return a.fileId == b.fileId;
    }
    return a.fileName == b.fileName && a.mimeType == b.mimeType;
  }

  Future<void> _handleFileAction({
    required _FileAction action,
    required CloudStorageService cloudStorageService,
    required CloudFile<dynamic> file,
    required bool isWideLayout,
  }) async {
    switch (action) {
      case _FileAction.details:
        await _openFileDetails(file, isWideLayout: isWideLayout);
        return;
      case _FileAction.download:
        await onDownloadFile(
          cloudStorageService: cloudStorageService,
          file: file,
        );
        return;
      case _FileAction.delete:
        await onDelete(
          cloudStorageService: cloudStorageService,
          file: file,
        );
        return;
      case _FileAction.checkIfExists:
        await checkIfExists(
          cloudStorageService: cloudStorageService,
          file: file,
        );
        return;
    }
  }

  Future<void> _openFileDetails(
    CloudFile<dynamic> file, {
    required bool isWideLayout,
  }) async {
    if (isWideLayout) {
      setState(() {
        _selectedFile = file;
      });
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height,
          child: _buildFileDetailsContent(
            file,
            showCloseButton: true,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _onFileTileTap(
    CloudFile<dynamic> file, {
    required bool isWideLayout,
  }) async {
    if (isWideLayout && _isSameFile(file, _selectedFile)) {
      _clearSelection();
      return;
    }
    await _openFileDetails(file, isWideLayout: isWideLayout);
  }

  void _clearSelectionIfWide(bool isWideLayout) {
    if (!isWideLayout) {
      return;
    }
    _clearSelection();
  }

  void _clearSelection() {
    if (_selectedFile == null) {
      return;
    }
    setState(() {
      _selectedFile = null;
    });
  }

  Widget _buildFileDetailsContent(
    CloudFile<dynamic>? file, {
    required bool showCloseButton,
    VoidCallback? onClose,
  }) {
    if (file == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tap on a file to see details.'),
        ),
      );
    }
    final details = _buildDetails(file);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: details.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final detail = details[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(detail.value),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<_DetailEntry> _buildDetails(CloudFile<dynamic> file) {
    final details = <_DetailEntry>[
      _DetailEntry(label: 'Name', value: file.fileName),
      _DetailEntry(label: 'File ID', value: file.fileId ?? '-'),
      _DetailEntry(label: 'Type', value: _typeLabelForFile(file)),
      _DetailEntry(label: 'MIME type', value: file.mimeType ?? '-'),
      _DetailEntry(label: 'Trashed', value: file.trashed ? 'Yes' : 'No'),
      _DetailEntry(label: 'Class', value: file.runtimeType.toString()),
    ];
    if (file is GoogleDriveFile) {
      details.addAll([
        _DetailEntry(
          label: 'Description',
          value: file.description == null || file.description!.isEmpty
              ? '-'
              : file.description!,
        ),
        _DetailEntry(
          label: 'Parents',
          value: file.parents == null || file.parents!.isEmpty
              ? '-'
              : file.parents!.join(', '),
        ),
        _DetailEntry(
          label: 'Local bytes',
          value: file.bytes?.length.toString() ?? '-',
        ),
        _DetailEntry(
          label: 'Modified time',
          value: _lastModifiedLabel(file),
        ),
      ]);
      if (file.fileContent != null && file.fileContent!.isNotEmpty) {
        details.add(_DetailEntry(label: 'Content', value: file.fileContent!));
      }
    }
    return details;
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
    final deleted = await cloudStorageService.deleteFile(file: file);
    if (!mounted) {
      return;
    }
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Text(deleted ? 'File deleted.' : 'Unable to delete file.'),
    ));
    if (deleted) {
      _refreshFiles(
        cloudStorageService,
        clearSelection: _isSameFile(file, _selectedFile),
      );
    }
  }
}

enum _FileAction {
  details,
  download,
  delete,
  checkIfExists,
}

class _DetailEntry {
  const _DetailEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
