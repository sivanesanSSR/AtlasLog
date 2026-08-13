import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/backup_service.dart';
import '../services/theme_controller.dart';
import 'plan_management_screen.dart';
import 'gym_profile_screen.dart';
import 'send_reminders_screen.dart';
import 'edit_message_template_screen.dart';

class SettingsTabScreen extends ConsumerWidget {
  const SettingsTabScreen({super.key});

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backupServiceProvider).exportBackup();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'This will overwrite all current gym data (profile, plans, members, payments) with the contents of the backup file. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(backupServiceProvider).importBackup();
    if (!context.mounted) return;

    switch (result) {
      case ImportResult.success:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup imported successfully')));
        break;
      case ImportResult.invalidFormat:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file doesn\'t look like a valid Gym Manager backup')),
        );
        break;
      case ImportResult.cancelled:
        break;
      case ImportResult.error:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read the backup file')));
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkThemeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
            title: const Text('Dark Theme'),
            subtitle: Text(isDark ? 'Black & orange gradient' : 'Light & orange gradient'),
            value: isDark,
            onChanged: (v) => ref.read(isDarkThemeProvider.notifier).setDark(v),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Gym Setup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: const Text('Gym Profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GymProfileScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.card_membership_outlined),
                title: const Text('Manage Plans'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanManagementScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Reminders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Send Reminders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SendRemindersScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Reminder Message'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditMessageTemplateScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Export Backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportBackup(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import Backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importBackup(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
