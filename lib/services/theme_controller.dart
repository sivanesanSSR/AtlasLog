import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_storage_service.dart';
import 'providers.dart';

/// Persists and provides the user's chosen theme (dark, matching the
/// app's orange-gradient brand identity, or a light variant using the
/// same accent colors on light surfaces).
class ThemeModeController extends StateNotifier<bool> {
  final LocalStorageService _storage;
  static const _fileName = 'theme_preference.txt';

  ThemeModeController(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.readFile(_fileName, defaultContent: 'dark');
    state = saved.trim() != 'light';
  }

  Future<void> setDark(bool isDark) async {
    state = isDark;
    await _storage.writeFile(_fileName, isDark ? 'dark' : 'light');
  }
}

final isDarkThemeProvider = StateNotifierProvider<ThemeModeController, bool>((ref) {
  return ThemeModeController(ref.watch(localStorageServiceProvider));
});
