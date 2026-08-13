import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Handles all local data persistence: reads/writes JSON files in the
/// app's private documents directory under a GymManagerApp subfolder.
/// No network, no auth — data lives entirely on this device unless
/// exported via BackupService.
class LocalStorageService {
  static const _folderName = 'GymManagerApp';

  Directory? _appFolder;

  /// Ensures the GymManagerApp folder exists inside the app's documents
  /// directory, creating it on first run.
  Future<Directory> _getOrCreateAppFolder() async {
    if (_appFolder != null) return _appFolder!;

    final docsDir = await getApplicationDocumentsDirectory();
    final folder = Directory('${docsDir.path}/$_folderName');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    _appFolder = folder;
    return folder;
  }

  /// Must be called once at app startup before any read/write.
  Future<void> init() async {
    await _getOrCreateAppFolder();
  }

  Future<File> _getOrCreateFile(String fileName, String defaultContent) async {
    final folder = await _getOrCreateAppFolder();
    final file = File('${folder.path}/$fileName');

    if (!await file.exists()) {
      await file.writeAsString(defaultContent);
    }

    return file;
  }

  /// Reads a JSON file's content as a String, creating it with
  /// [defaultContent] if it doesn't exist yet.
  Future<String> readFile(String fileName, {String defaultContent = '[]'}) async {
    final file = await _getOrCreateFile(fileName, defaultContent);
    return file.readAsString();
  }

  /// Overwrites a file's content.
  Future<void> writeFile(String fileName, String content) async {
    final folder = await _getOrCreateAppFolder();
    final file = File('${folder.path}/$fileName');
    await file.writeAsString(content);
  }

  /// Returns the full path to the app's data folder — used by
  /// BackupService to enumerate files for export.
  Future<String> getAppFolderPath() async {
    final folder = await _getOrCreateAppFolder();
    return folder.path;
  }

  /// Reads all known data files as a combined map, for export.
  Future<Map<String, dynamic>> readAllForExport() async {
    final gymProfile = await readFile('gym_profile.json', defaultContent: '{}');
    final plans = await readFile('plans.json', defaultContent: '[]');
    final members = await readFile('members.json', defaultContent: '[]');
    final payments = await readFile('payments.json', defaultContent: '[]');

    return {
      'gym_profile': jsonDecode(gymProfile),
      'plans': jsonDecode(plans),
      'members': jsonDecode(members),
      'payments': jsonDecode(payments),
      'exported_at': DateTime.now().toIso8601String(),
      'format_version': 1,
    };
  }

  /// Overwrites all data files from an imported backup map. Caller is
  /// responsible for validating the map shape before calling this.
  Future<void> restoreFromImport(Map<String, dynamic> data) async {
    await writeFile('gym_profile.json', jsonEncode(data['gym_profile'] ?? {}));
    await writeFile('plans.json', jsonEncode(data['plans'] ?? []));
    await writeFile('members.json', jsonEncode(data['members'] ?? []));
    await writeFile('payments.json', jsonEncode(data['payments'] ?? []));
  }

  // ---------- Member photos ----------

  Future<Directory> _getOrCreatePhotosFolder() async {
    final appFolder = await _getOrCreateAppFolder();
    final photosDir = Directory('${appFolder.path}/member_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Copies a picked image file into the app's private photos folder
  /// and returns the relative path to store on the Member record
  /// (e.g. "member_photos/<uuid>.jpg").
  Future<String> savePhoto(File sourceFile, String memberId) async {
    final photosDir = await _getOrCreatePhotosFolder();
    final extension = sourceFile.path.split('.').last;
    final destFile = File('${photosDir.path}/$memberId.$extension');
    await sourceFile.copy(destFile.path);
    return 'member_photos/${destFile.path.split('/').last}';
  }

  /// Resolves a relative photoPath (as stored on Member) to an absolute
  /// File for display. Returns null if the path is null or the file no
  /// longer exists.
  Future<File?> resolvePhoto(String? relativePath) async {
    if (relativePath == null) return null;
    final appFolder = await _getOrCreateAppFolder();
    final file = File('${appFolder.path}/$relativePath');
    return await file.exists() ? file : null;
  }

  Future<void> deletePhoto(String? relativePath) async {
    if (relativePath == null) return;
    final appFolder = await _getOrCreateAppFolder();
    final file = File('${appFolder.path}/$relativePath');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ---------- Gym logo ----------
  // Reuses the same resolvePhoto/deletePhoto helpers above since a gym
  // logo is just another image file stored by relative path.

  /// Saves the gym's logo image, overwriting any previous one, and
  /// returns the relative path to store on GymProfile.
  Future<String> saveGymLogo(File sourceFile) async {
    final appFolder = await _getOrCreateAppFolder();
    final extension = sourceFile.path.split('.').last;
    final destFile = File('${appFolder.path}/gym_logo.$extension');
    await sourceFile.copy(destFile.path);
    return destFile.path.split('/').last;
  }
}
