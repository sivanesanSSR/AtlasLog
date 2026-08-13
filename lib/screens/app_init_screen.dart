import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import 'home_shell_screen.dart';
import 'gym_profile_screen.dart';

/// First screen shown on launch. Initializes local storage + notifications,
/// then routes to Gym Profile setup (first run) or straight to Dashboard.
class AppInitScreen extends ConsumerStatefulWidget {
  const AppInitScreen({super.key});

  @override
  ConsumerState<AppInitScreen> createState() => _AppInitScreenState();
}

class _AppInitScreenState extends ConsumerState<AppInitScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await ref.read(localStorageServiceProvider).init();
      await ref.read(notificationServiceProvider).init();

      final profile = await ref.read(gymRepositoryProvider).getGymProfile();
      if (!mounted) return;

      if (profile == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GymProfileScreen(isFirstRun: true)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShellScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to start app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fitness_center, size: 72),
              const SizedBox(height: 16),
              const Text('Gym Manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _init, child: const Text('Retry')),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
