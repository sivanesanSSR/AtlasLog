import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../models/member.dart';
import '../models/plan.dart';
import '../models/payment.dart';
import '../utils/status_colors.dart';
import '../utils/responsive.dart';

class RenewMemberScreen extends ConsumerStatefulWidget {
  final Member member;

  const RenewMemberScreen({super.key, required this.member});

  @override
  ConsumerState<RenewMemberScreen> createState() => _RenewMemberScreenState();
}

class _RenewMemberScreenState extends ConsumerState<RenewMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountPaidCtrl = TextEditingController();

  List<Plan> _plans = [];
  Plan? _currentPlan;
  Plan? _selectedPlan;
  PaymentMode _selectedMode = PaymentMode.cash;
  DateTime _renewalDate = DateTime.now();
  DateTime? _customExpiryDate; // Manual optional override date
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(gymRepositoryProvider);
    final plans = await repo.getPlans();
    if (!mounted) return;

    Plan? current;
    for (final p in plans) {
      if (p.id == widget.member.planId) current = p;
    }

    setState(() {
      _plans = plans;
      _currentPlan = current;
      _selectedPlan = current ?? (plans.isNotEmpty ? plans.first : null);
      _loading = false;
    });
  }

  Future<void> _pickRenewalDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewalDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: 'Renewal Start Date',
    );
    if (picked != null) setState(() => _renewalDate = picked);
  }

  Future<void> _pickCustomExpiryDate() async {
    final defaultExpiry = _computeAutoExpiry();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customExpiryDate ?? defaultExpiry,
      firstDate: _renewalDate,
      lastDate: DateTime(2100),
      helpText: 'Select Custom Expiry Date',
    );
    if (picked != null) {
      setState(() => _customExpiryDate = picked);
    }
  }

  DateTime _computeAutoExpiry() {
    final base = widget.member.endDate.isAfter(_renewalDate) 
        ? widget.member.endDate 
        : _renewalDate;
    final months = _selectedPlan?.durationMonths ?? 1;
    return DateTime(base.year, base.month + months, base.day);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedPlan == null) return;
    setState(() => _saving = true);

    // Final Expiry Date (Custom value if provided, else auto calculated)
    final finalExpiry = _customExpiryDate ?? _computeAutoExpiry();

    try {
      await ref.read(gymRepositoryProvider).renewMember(
            memberId: widget.member.id,
            plan: _selectedPlan!,
            amountPaid: double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
            mode: _selectedMode,
            renewalDate: _renewalDate,
            customEndDate: finalExpiry, // Ensure your repo handles customEndDate if applicable
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to renew: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.member;
    final color = statusColor(m.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Renew Plan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No plans available. Add a plan first from Manage Plans.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Padding(
                  padding: Responsive.formPadding(context),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        _buildCurrentStatusCard(m, color),
                        const SizedBox(height: 20),
                        const Text('New Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Plan>(
                          value: _selectedPlan,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: _plans
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text('${p.name} — ₹${p.price.toStringAsFixed(0)}'),
                                  ))
                              .toList(),
                          onChanged: (p) => setState(() {
                            _selectedPlan = p;
                            // Reset custom date on plan change so it recalculates automatically
                            _customExpiryDate = null; 
                          }),
                          validator: (v) => v == null ? 'Select a plan' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountPaidCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount Paid Now',
                            hintText: _selectedPlan != null
                                ? 'Plan price: ₹${_selectedPlan!.price.toStringAsFixed(0)}'
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Renewal Date picker
                        InkWell(
                          onTap: _pickRenewalDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Renewal Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              children: [
                                Text('${_renewalDate.day}/${_renewalDate.month}/${_renewalDate.year}'),
                                const Spacer(),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Manual Custom Expiry Date (Optional)
                        InkWell(
                          onTap: _pickCustomExpiryDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Custom Expiry Date (Optional)',
                              border: const OutlineInputBorder(),
                              suffixIcon: _customExpiryDate != null
                                  ? IconButton(
                                      tooltip: 'Reset to Auto Calculation',
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _customExpiryDate = null),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _customExpiryDate != null
                                      ? '${_customExpiryDate!.day}/${_customExpiryDate!.month}/${_customExpiryDate!.year}'
                                      : 'Auto calculated from plan duration',
                                  style: TextStyle(
                                    color: _customExpiryDate != null
                                        ? theme.textTheme.bodyLarge?.color
                                        : theme.hintColor,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.edit_calendar, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: PaymentMode.values.map((mode) {
                            return ChoiceChip(
                              label: Text(_paymentModeLabel(mode)),
                              selected: _selectedMode == mode,
                              onSelected: (_) => setState(() => _selectedMode = mode),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        if (_selectedPlan != null) _buildNewExpiryPreview(m, _selectedPlan!),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: _saving
                              ? const SizedBox(
                                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Confirm Renewal'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCurrentStatusCard(Member m, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(m.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusLabel(m.status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${m.memberCode} · ${m.mobile}', style: TextStyle(color: Colors.grey[600])),
            const Divider(height: 20),
            Text('Current plan: ${_currentPlan?.name ?? "Unknown"}'),
            Text('Expires: ${m.endDate.toLocal().toString().split(' ')[0]}'),
            if (!m.isPaid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Outstanding due: ₹${m.amountDue.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewExpiryPreview(Member m, Plan plan) {
    final newEnd = _customExpiryDate ?? _computeAutoExpiry();
    final isCustom = _customExpiryDate != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'New expiry date: ${newEnd.day}/${newEnd.month}/${newEnd.year}${isCustom ? " (Custom)" : ""}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentModeLabel(PaymentMode mode) {
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
}