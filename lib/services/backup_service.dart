import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'local_storage_service.dart';

enum ImportResult { success, invalidFormat, cancelled, error }

/// Exports all app data to a single JSON backup file the user can share
/// (save to Downloads, send via WhatsApp/email, etc.), and imports it
/// back in — used for moving to a new phone or manual backups, since
/// there's no cloud sync in this version of the app.
class BackupService {
  final LocalStorageService _storage;

  BackupService(this._storage);

  /// Writes a backup JSON file to a temp location and opens the native
  /// share sheet so the user can save/send it wherever they like.
  Future<void> exportBackup() async {
    final data = await _storage.readAllForExport();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${tempDir.path}/gym_manager_backup_$timestamp.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Gym Manager backup — $timestamp',
    );
  }

  /// Opens a file picker for the user to select a previously exported
  /// backup JSON file, validates its shape, and restores it, overwriting
  /// all current local data.
  Future<ImportResult> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return ImportResult.cancelled;
    }

    try {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic> ||
          !decoded.containsKey('plans') ||
          !decoded.containsKey('members')) {
        return ImportResult.invalidFormat;
      }

      await _storage.restoreFromImport(decoded);
      return ImportResult.success;
    } catch (_) {
      return ImportResult.error;
    }
  }
}
