import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'local_storage_service.dart';

enum ImportResult { success, invalidFormat, cancelled, error }

class BackupService {
  final LocalStorageService _storage;

  BackupService(this._storage);

  /// Helper to generate the .zip backup archive in the temp directory
  Future<File> _generateZipBackup() async {
    final encoder = ZipFileEncoder();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final zipPath = '${tempDir.path}/gym_manager_backup_$timestamp.zip';

    // 1. Create temporary JSON data file
    final data = await _storage.readAllForExport();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final tempJsonFile = File('${tempDir.path}/backup_data.json');
    await tempJsonFile.writeAsString(jsonString);

    // 2. Initialize ZIP
    encoder.create(zipPath);

    // 3. Add JSON file to root of ZIP
    encoder.addFile(tempJsonFile, 'backup_data.json');

    // 4. Add images directory (member photos and gym logo) if it exists
    final appDir = await _getAppDirectory();
    if (await appDir.exists()) {
      final entities = appDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (entity.path.contains('member_photos') || fileName.startsWith('gym_logo')) {
            final relativePath = p.relative(entity.path, from: appDir.path);
            encoder.addFile(entity, relativePath);
          }
        }
      }
    }

    // 5. Close ZIP encoder & clean temp JSON
    encoder.close();
    if (await tempJsonFile.exists()) {
      await tempJsonFile.delete();
    }

    return File(zipPath);
  }

  /// Default export method (calls share sheet)
  Future<void> exportBackup() async {
    await shareBackup();
  }

  /// Option A: Opens native Share Sheet (WhatsApp, Google Drive, Email, etc.)
  Future<void> shareBackup() async {
    final zipFile = await _generateZipBackup();
    final timestamp = DateTime.now().toIso8601String().split('T').first;

    await Share.shareXFiles(
      [XFile(zipFile.path, mimeType: 'application/zip')],
      text: 'Gym Manager backup — $timestamp',
    );
  }

  /// Option B: Download / Save file directly to device storage
  Future<bool> saveBackupToDevice() async {
    final zipFile = await _generateZipBackup();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final defaultFileName = 'gym_manager_backup_$timestamp.zip';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup File to Device',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: await zipFile.readAsBytes(),
    );

    if (savePath == null) return false;

    final destinationFile = File(savePath);
    if (!await destinationFile.exists()) {
      await zipFile.copy(savePath);
    }
    return true;
  }

  /// Import: Works for Google Drive, Local Storage, Downloads, WhatsApp (.zip or .json)
  Future<ImportResult> importBackup() async {
    // Using FileType.any so Google Drive and cloud files are NOT greyed out
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true, // Loads bytes into memory for cloud/drive files
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelled;
    }

    final platformFile = result.files.first;
    final fileName = platformFile.name.toLowerCase();

    // Verify it is a zip or json file
    if (!fileName.endsWith('.zip') && !fileName.endsWith('.json')) {
      return ImportResult.invalidFormat;
    }

    try {
      // If the file is on Google Drive, platformFile.path might be null, but platformFile.bytes will exist
      List<int> fileBytes;
      if (platformFile.bytes != null) {
        fileBytes = platformFile.bytes!;
      } else if (platformFile.path != null) {
        fileBytes = await File(platformFile.path!).readAsBytes();
      } else {
        return ImportResult.error;
      }

      if (fileName.endsWith('.zip')) {
        return await _importZipFromBytes(fileBytes);
      } else {
        return await _importJsonFromBytes(fileBytes);
      }
    } catch (_) {
      return ImportResult.error;
    }
  }

  /// Extracts .zip bytes into app storage and restores JSON records
  Future<ImportResult> _importZipFromBytes(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? jsonArchiveFile;
    for (final file in archive) {
      if (file.name == 'backup_data.json') {
        jsonArchiveFile = file;
        break;
      }
    }

    if (jsonArchiveFile == null) return ImportResult.invalidFormat;

    final jsonContent = utf8.decode(jsonArchiveFile.content as List<int>);
    final decoded = jsonDecode(jsonContent);

    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('plans') ||
        !decoded.containsKey('members')) {
      return ImportResult.invalidFormat;
    }

    // Unpack photos into app directory
    final appDir = await _getAppDirectory();
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    for (final file in archive) {
      if (file.isFile && file.name != 'backup_data.json') {
        final outFile = File(p.join(appDir.path, file.name));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    await _storage.restoreFromImport(decoded);
    return ImportResult.success;
  }

  /// Restores legacy JSON backup from bytes
  Future<ImportResult> _importJsonFromBytes(List<int> bytes) async {
    final content = utf8.decode(bytes);
    final decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('plans') ||
        !decoded.containsKey('members')) {
      return ImportResult.invalidFormat;
    }

    await _storage.restoreFromImport(decoded);
    return ImportResult.success;
  }

  Future<Directory> _getAppDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDir.path, 'GymManagerApp'));
  }
}