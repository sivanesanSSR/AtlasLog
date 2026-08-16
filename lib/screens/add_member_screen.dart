import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/gym_repository.dart';
import '../models/plan.dart';
import '../models/payment.dart';
import '../widgets/member_photo_picker.dart';
import 'plan_management_screen.dart';
import '../utils/responsive.dart';

class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key});

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _amountPaidCtrl = TextEditingController();
  final _memberIdCtrl = TextEditingController();

  List<Plan> _plans = [];
  Plan? _selectedPlan;
  File? _photoFile;
  DateTime _paidOnDate = DateTime.now();
  PaymentMode _selectedMode = PaymentMode.cash;
  bool _loadingPlans = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await ref.read(gymRepositoryProvider).getPlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _selectedPlan = plans.isNotEmpty ? plans.first : null;
      _loadingPlans = false;
    });
  }

  Future<void> _pickPaidOnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidOnDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: 'Payment / Join Date',
    );
    if (picked != null) setState(() => _paidOnDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlan == null) {
      if (_plans.isEmpty) {
        final shouldCreatePlan = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('No Plans Yet'),
            content: const Text(
              'You need at least one plan before adding a member. Create one now?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Plan')),
            ],
          ),
        );
        if (shouldCreatePlan == true && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlanManagementScreen()),
          );
          await _loadPlans();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a plan before saving.')),
        );
      }
      return;
    }
    setState(() => _saving = true);

    try {
      await ref.read(gymRepositoryProvider).addMember(
            name: _nameCtrl.text.trim(),
            mobile: _mobileCtrl.text.trim(),
            plan: _selectedPlan!,
            amountPaid: double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
            photoFile: _photoFile,
            customMemberCode: _memberIdCtrl.text.trim().isEmpty ? null : _memberIdCtrl.text.trim(),
            paidOnDate: _paidOnDate,
            paymentMode: _selectedMode,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (e is DuplicateMemberException) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Save Member'),
            content: Text(e.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add member: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _amountPaidCtrl.dispose();
    _memberIdCtrl.dispose();
    super.dispose();
  }

  String _modeLabel(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.card:
        return 'Card';
      case PaymentMode.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Member')),
      body: _loadingPlans
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: Responsive.formPadding(context),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: MemberPhotoPicker(
                        onChanged: (file, removed) {
                          setState(() => _photoFile = removed ? null : file);
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
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _memberIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Member ID (optional)',
                        hintText: 'Leave blank to auto-generate (e.g. GM0001)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Plan>(
                      value: _selectedPlan,
                      decoration: InputDecoration(
                        labelText: 'Plan',
                        errorText: _plans.isEmpty ? 'No plans yet — tap below to add one' : null,
                      ),
                      items: _plans
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.name} — ₹${p.price.toStringAsFixed(0)}'),
                              ))
                          .toList(),
                      onChanged: (p) => setState(() => _selectedPlan = p),
                    ),
                    if (_plans.isEmpty) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PlanManagementScreen()),
                          );
                          await _loadPlans();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add a Plan'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickPaidOnDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Join / Payment Date'),
                        child: Row(
                          children: [
                            Text('${_paidOnDate.day}/${_paidOnDate.month}/${_paidOnDate.year}'),
                            const Spacer(),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountPaidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid Now',
                        hintText: 'Leave blank if unpaid',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: PaymentMode.values.map((mode) {
                        return ChoiceChip(
                          label: Text(_modeLabel(mode)),
                          selected: _selectedMode == mode,
                          onSelected: (_) => setState(() => _selectedMode = mode),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Add Member'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
