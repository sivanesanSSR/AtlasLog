import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/responsive.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String policyUrl = 'https://atlas-log-policy.vercel.app/'; // Replace with your live Vercel URL

  Future<void> _openExternalPolicy(BuildContext context) async {
    final uri = Uri.parse(policyUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open external browser')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            tooltip: 'Open in Browser',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () => _openExternalPolicy(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Responsive.centered(
          Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gym Manager Privacy Policy',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Effective Date: August 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Divider(height: 28),

            _buildSection(
              theme,
              title: '1. Overview',
              content:
                  'Gym Manager is designed as a standalone, offline-first management tool for single-gym operations. Your privacy is paramount: the app does not operate a central backend server, does not maintain remote user accounts, and does not sell or distribute your data to third parties.',
            ),

            _buildSection(
              theme,
              title: '2. Information Stored Locally',
              content:
                  'All data you record—including gym profiles, membership plans, member records, payment logs, member photos, and gym logos—is stored strictly on your device\'s local storage.',
            ),

            _buildSection(
              theme,
              title: '3. Device Permissions & Usage',
              content:
                  '• Camera & Gallery: Used solely when you capture or choose a member photo or gym logo.\n'
                  '• Storage / File System: Used to export and import manual .zip backup archives that you manage.\n'
                  '• Notifications: Used to schedule on-device local alerts 3 days prior to a member plan\'s expiry.\n'
                  '• External Apps (WhatsApp / SMS): Used only to pre-fill renewal messages upon your manual confirmation.',
            ),

            _buildSection(
              theme,
              title: '4. Data Sharing & Backups',
              content:
                  'We do not collect or share personal data automatically. When you create an Export Backup, a compressed .zip file is generated locally for you to save or share via your device\'s native share tools. You maintain full ownership and custody over these backup files.',
            ),

            _buildSection(
              theme,
              title: '5. Children\'s Privacy',
              content:
                  'This application is an administrative tool intended for gym owners and managers and is not directed at children under the age of 13.',
            ),

            _buildSection(
              theme,
              title: '6. Policy Changes',
              content:
                  'Any future changes to this Privacy Policy will be reflected within app updates and on the hosted policy page.',
            ),

            _buildSection(
              theme,
              title: '7. Contact Us',
              content:
                  'If you have questions regarding this policy or the app\'s data handling, please contact support via the developer email listed on the Google Play Store page.',
            ),

            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _openExternalPolicy(context),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View Hosted Online Version'),
              ),
            ),
            const SizedBox(height: 30),
          ],
          ),
          maxWidth: 680,
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}