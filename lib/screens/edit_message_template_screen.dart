import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/message_template_service.dart';
import '../services/reminder_service.dart';
import '../models/gym_profile.dart';
import '../models/plan.dart';
import '../models/member.dart';
import '../utils/responsive.dart';

class EditMessageTemplateScreen extends ConsumerStatefulWidget {
  const EditMessageTemplateScreen({super.key});

  @override
  ConsumerState<EditMessageTemplateScreen> createState() => _EditMessageTemplateScreenState();
}

class _EditMessageTemplateScreenState extends ConsumerState<EditMessageTemplateScreen> {
  final _controller = TextEditingController();
  final _reminderService = ReminderService();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final template = await ref.read(messageTemplateServiceProvider).getTemplate();
    if (!mounted) return;
    setState(() {
      _controller.text = template;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(messageTemplateServiceProvider).saveTemplate(_controller.text);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _resetToDefault() async {
    setState(() => _controller.text = defaultReminderTemplate);
  }

  void _insertPlaceholder(String token) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursor = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(cursor, cursor, token);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + token.length),
    );
  }

  String get _previewText {
    // Build a realistic sample using placeholder demo data.
    final sampleMember = Member(
      id: 'preview',
      memberCode: 'GM0001',
      name: 'Rahul',
      mobile: '9876543210',
      planId: 'preview',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 3)),
      amountPaid: 0,
      amountDue: 0,
      updatedAt: DateTime.now(),
    );
    final sampleGym = GymProfile(name: 'PowerFit Gym', address: '', contact: '');
    final samplePlan = Plan(id: 'preview', name: '3 Month', durationMonths: 3, price: 3000);

    return _reminderService.renderTemplate(
      template: _controller.text,
      member: sampleMember,
      gymProfile: sampleGym,
      plan: samplePlan,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Message'),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: Responsive.formPadding(context),
              child: ListView(
                children: [
                  const Text('Available placeholders — tap to insert:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: reminderTemplatePlaceholders.map((token) {
                      return ActionChip(
                        label: Text(token, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _insertPlaceholder(token),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 8,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write your reminder message here…',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Preview (sample data)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Text(_previewText, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Message'),
                  ),
                ],
              ),
            ),
    );
  }
}
