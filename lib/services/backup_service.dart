import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'local_storage_service.dart';

enum ImportResult { success, invalidFormat, cancelled, error }

/// Exports all app data (JSONs + Photos) to a single .zip backup file and
/// imports it back in, restoring records and image assets.
class BackupService {
  final LocalStorageService _storage;

  BackupService(this._storage);

  /// Bundles JSON data + member/gym photos into a .zip archive
  /// and opens the native share sheet.
  Future<void> exportBackup() async {
    final encoder = ZipFileEncoder();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final zipPath = '${tempDir.path}/gym_manager_backup_$timestamp.zip';

    // 1. Create the backup JSON file
    final data = await _storage.readAllForExport();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final tempJsonFile = File('${tempDir.path}/backup_data.json');
    await tempJsonFile.writeAsString(jsonString);

    // 2. Initialize ZIP
    encoder.create(zipPath);

    // 3. Add JSON file to root of ZIP
    encoder.addFile(tempJsonFile, 'backup_data.json');

    // 4. Add images directory if it exists
    final appDir = await _getAppDirectory();
    if (await appDir.exists()) {
      final entities = appDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          // Include member photos folder and gym logo files
          if (entity.path.contains('member_photos') || fileName.startsWith('gym_logo')) {
            final relativePath = p.relative(entity.path, from: appDir.path);
            encoder.addFile(entity, relativePath);
          }
        }
      }
    }

    // 5. Close ZIP encoder
    encoder.close();

    // Clean up temporary JSON file
    if (await tempJsonFile.exists()) {
      await tempJsonFile.delete();
    }

    // 6. Share ZIP file
    await Share.shareXFiles(
      [XFile(zipPath, mimeType: 'application/zip')],
      text: 'Gym Manager backup — $timestamp',
    );
  }

  /// Opens a file picker for .zip (or legacy .json) backup files,
  /// extracts images into the app storage directory, and restores JSON records.
  Future<ImportResult> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      return ImportResult.cancelled;
    }

    final selectedFile = File(result.files.single.path!);
    final extension = p.extension(selectedFile.path).toLowerCase();

    try {
      if (extension == '.zip') {
        return await _importZipBackup(selectedFile);
      } else if (extension == '.json') {
        return await _importJsonBackup(selectedFile);
      } else {
        return ImportResult.invalidFormat;
      }
    } catch (_) {
      return ImportResult.error;
    }
  }

  /// Handles ZIP archive extraction and data restoration
  Future<ImportResult> _importZipBackup(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Locate backup_data.json inside archive
    ArchiveFile? jsonArchiveFile;
    for (final file in archive) {
      if (file.name == 'backup_data.json') {
        jsonArchiveFile = file;
        break;
      }
    }

    if (jsonArchiveFile == null) {
      return ImportResult.invalidFormat;
    }

    // 2. Decode and validate JSON
    final jsonContent = utf8.decode(jsonArchiveFile.content as List<int>);
    final decoded = jsonDecode(jsonContent);

    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('plans') ||
        !decoded.containsKey('members')) {
      return ImportResult.invalidFormat;
    }

    // 3. Extract photos into app directory
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

    // 4. Restore database records
    await _storage.restoreFromImport(decoded);
    return ImportResult.success;
  }

  /// Backward compatibility for legacy .json backup files
  Future<ImportResult> _importJsonBackup(File jsonFile) async {
    final content = await jsonFile.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('plans') ||
        !decoded.containsKey('members')) {
      return ImportResult.invalidFormat;
    }

    await _storage.restoreFromImport(decoded);
    return ImportResult.success;
  }

  /// Helper to get the base app directory where GymManagerApp files live
  Future<Directory> _getAppDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDir.path, 'GymManagerApp'));
  }
}