import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/gym_repository.dart';
import '../models/member.dart';
import '../widgets/member_photo_picker.dart';
import '../utils/responsive.dart';
import '../utils/validators.dart';

class EditMemberScreen extends ConsumerStatefulWidget {
  final Member member;
  const EditMemberScreen({super.key, required this.member});

  @override
  ConsumerState<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends ConsumerState<EditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late DateTime _startDate;

  File? _existingPhoto;
  File? _newPhotoFile;
  bool _photoRemoved = false;
  bool _loadingPhoto = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member.name);
    _mobileCtrl = TextEditingController(text: widget.member.mobile);
    _startDate = widget.member.startDate;
    _loadExistingPhoto();
  }

  Future<void> _loadExistingPhoto() async {
    final storage = ref.read(localStorageServiceProvider);
    final file = await storage.resolvePhoto(widget.member.photoPath);
    if (!mounted) return;
    setState(() {
      _existingPhoto = file;
      _loadingPhoto = false;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: 'Join / Payment Date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(gymRepositoryProvider).updateMemberDetails(
            memberId: widget.member.id,
            name: _nameCtrl.text.trim(),
            mobile: _mobileCtrl.text.trim(),
            startDate: _startDate,
            newPhotoFile: _newPhotoFile,
            removePhoto: _photoRemoved,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is DuplicateMemberException ? e.message : 'Failed to save changes: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: e is DuplicateMemberException ? Colors.orange[800] : null),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Member')),
      body: _loadingPhoto
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: Responsive.formPadding(context),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: MemberPhotoPicker(
                        existingPhoto: _existingPhoto,
                        onChanged: (file, removed) {
                          setState(() {
                            _newPhotoFile = file;
                            _photoRemoved = removed;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile Number'),
                      validator: validateMobileNumber,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Join / Payment Date'),
                        child: Row(
                          children: [
                            Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                            const Spacer(),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan, expiry date, and payment details are changed via Renew Plan, not here.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
