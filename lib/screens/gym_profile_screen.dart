import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../models/gym_profile.dart';
import '../widgets/member_photo_picker.dart';
import 'plan_management_screen.dart';

/// Shown once after first sign-in (if no gym profile exists yet), or
/// reachable later from settings to edit gym details.
class GymProfileScreen extends ConsumerStatefulWidget {
  /// When true, this is the first-run setup flow — saving navigates
  /// forward to Plan setup instead of just popping back.
  final bool isFirstRun;

  const GymProfileScreen({super.key, this.isFirstRun = false});

  @override
  ConsumerState<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends ConsumerState<GymProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  GymProfile? _existingProfile;
  File? _existingLogo;
  File? _newLogoFile;
  bool _logoRemoved = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(gymRepositoryProvider);
    final profile = await repo.getGymProfile();
    if (!mounted) return;
    if (profile != null) {
      _nameCtrl.text = profile.name;
      _addressCtrl.text = profile.address;
      _contactCtrl.text = profile.contact;
      final logo = await ref.read(localStorageServiceProvider).resolvePhoto(profile.logoPath);
      if (!mounted) return;
      setState(() {
        _existingProfile = profile;
        _existingLogo = logo;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final profile = GymProfile(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        logoPath: _existingProfile?.logoPath,
      );
      await ref.read(gymRepositoryProvider).saveGymProfile(
            profile,
            logoFile: _newLogoFile,
            removeLogo: _logoRemoved,
          );
      if (!mounted) return;

      if (widget.isFirstRun) {
        // Continue the setup flow into Plan creation.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlanManagementScreen(isFirstRun: true)),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save gym profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstRun ? 'Set Up Your Gym' : 'Gym Profile'),
        automaticallyImplyLeading: !widget.isFirstRun,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (widget.isFirstRun) ...[
                      const Text(
                        'Let\'s set up your gym details first.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: MemberPhotoPicker(
                        existingPhoto: _existingLogo,
                        onChanged: (file, removed) {
                          setState(() {
                            _newLogoFile = file;
                            _logoRemoved = removed;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Gym Logo', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Gym Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact Number'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(widget.isFirstRun ? 'Continue' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
