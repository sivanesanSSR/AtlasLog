import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/app_init_screen.dart';
import 'theme/app_theme.dart';
import 'services/theme_controller.dart';

void main() {
  runApp(const ProviderScope(child: GymManagerApp()));
}

class GymManagerApp extends ConsumerWidget {
  const GymManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkThemeProvider);
    return MaterialApp(
      title: 'Gym Manager',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: const AppInitScreen(),
    );
  }
}
