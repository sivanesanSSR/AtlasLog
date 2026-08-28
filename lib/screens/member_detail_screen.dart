import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../services/providers.dart';
import '../services/reminder_service.dart';
import '../models/member.dart';
import '../models/plan.dart';
import '../models/payment.dart';
import '../utils/status_colors.dart';
import 'edit_member_screen.dart';
import 'renew_member_screen.dart';
import '../utils/responsive.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  Member? _member;
  Plan? _plan;
  File? _photo;
  List<Payment> _payments = [];
  bool _loading = true;
  bool _wasChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(gymRepositoryProvider);
    final storage = ref.read(localStorageServiceProvider);

    final members = await repo.getMembers();
    Member? member;
    for (final m in members) {
      if (m.id == widget.memberId) {
        member = m;
        break;
      }
    }

    if (member == null) {
      if (!mounted) return;
      Navigator.of(context).pop(_wasChanged);
      return;
    }

    final plans = await repo.getPlans();
    Plan? plan;
    for (final p in plans) {
      if (p.id == member.planId) {
        plan = p;
        break;
      }
    }

    final payments = await repo.getPayments(memberId: member.id);
    payments.sort((a, b) => b.date.compareTo(a.date));
    final photo = await storage.resolvePhoto(member.photoPath);

    if (!mounted) return;
    setState(() {
      _member = member;
      _plan = plan;
      _payments = payments;
      _photo = photo;
      _loading = false;
    });
  }

  void _showImagePreview() {
    if (_photo == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _photo!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMember() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditMemberScreen(member: _member!)),
    );
    if (result == true) {
      _wasChanged = true;
      _load();
    }
  }

  Future<void> _renewMember() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RenewMemberScreen(member: _member!)),
    );
    _wasChanged = true;
    _load();
  }

  Future<void> _toggleFreeze() async {
    final m = _member!;
    final repo = ref.read(gymRepositoryProvider);
    try {
      if (m.isFrozen) {
        await repo.unfreezeMember(m.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership resumed — expiry date shifted forward by the frozen days.')),
        );
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Freeze Membership'),
            content: const Text('This pauses the expiry countdown until you unfreeze. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Freeze')),
            ],
          ),
        );
        if (confirmed != true) return;

        await repo.freezeMember(m.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membership frozen.')));
      }
      _wasChanged = true;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Delete ${_member!.name}? This removes their profile, photo, and payment history permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(gymRepositoryProvider).deleteMember(_member!.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _sendReminder(bool viaWhatsApp) async {
    final gymProfile = await ref.read(gymRepositoryProvider).getGymProfile();
    final template = await ref.read(messageTemplateServiceProvider).getTemplate();
    final reminderService = ReminderService();
    final ok = viaWhatsApp
        ? await reminderService.sendViaWhatsApp(member: _member!, gymProfile: gymProfile, plan: _plan, template: template)
        : await reminderService.sendViaSms(member: _member!, gymProfile: gymProfile, plan: _plan, template: template);

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viaWhatsApp ? 'Could not open WhatsApp.' : 'Could not open SMS app.')),
      );
    }
  }

  Future<void> _payDue() async {
    final member = _member!;
    final amountCtrl = TextEditingController(text: member.amountDue.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    PaymentMode selectedMode = PaymentMode.cash;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pay Due Amount'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding due: ₹${member.amountDue.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount Received',
                    prefixText: '₹',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final amount = double.tryParse((v ?? '').trim());
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    if (amount > member.amountDue) return 'Cannot exceed ₹${member.amountDue.toStringAsFixed(0)}';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PaymentMode.values.map((mode) {
                    return ChoiceChip(
                      label: Text(_modeLabel(mode)),
                      selected: selectedMode == mode,
                      onSelected: (_) => setDialogState(() => selectedMode = mode),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await ref.read(gymRepositoryProvider).recordDuePayment(
            memberId: member.id,
            amount: amount,
            mode: selectedMode,
          );
      _wasChanged = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('₹${amount.toStringAsFixed(0)} payment recorded.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record payment: $e')),
      );
    }
  }

  Future<void> _shareReceipt(Payment payment) async {
    final gymProfile = await ref.read(gymRepositoryProvider).getGymProfile();
    final gymName = gymProfile?.name.isNotEmpty == true ? gymProfile!.name : 'Gym';
    final member = _member!;
    final dateStr = '${payment.date.day}/${payment.date.month}/${payment.date.year}';

    final receipt = '''
$gymName — Payment Receipt

Member: ${member.name} (${member.memberCode})
Amount: ₹${payment.amount.toStringAsFixed(0)}
Date: $dateStr
Mode: ${_modeLabel(payment.mode)}
''';

    await Share.share(receipt.trim());
  }

  Future<void> _editPayment(Payment payment) async {
    final amountCtrl = TextEditingController(text: payment.amount.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    PaymentMode selectedMode = payment.mode;
    DateTime selectedDate = payment.date;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Payment'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final amount = double.tryParse((v ?? '').trim());
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                    child: Row(
                      children: [
                        Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                        const Spacer(),
                        const Icon(Icons.calendar_today, size: 18),
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
                      label: Text(_modeLabel(mode)),
                      selected: selectedMode == mode,
                      onSelected: (_) => setDialogState(() => selectedMode = mode),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await ref.read(gymRepositoryProvider).updatePayment(
            paymentId: payment.id,
            amount: amount,
            mode: selectedMode,
            date: selectedDate,
          );
      _wasChanged = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment updated.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update payment: $e')),
      );
    }
  }

  Future<void> _deletePayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete this ₹${payment.amount.toStringAsFixed(0)} payment record? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(gymRepositoryProvider).deletePayment(payment.id);
      _wasChanged = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment deleted.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete payment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_wasChanged);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_member?.name ?? 'Member'),
          actions: _member == null
              ? null
              : [
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editMember),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteMember),
                ],
        ),
        body: _loading || _member == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: Responsive.formPadding(context, maxWidth: Responsive.maxContentWidth),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildActionRow(),
                    const SizedBox(height: 24),
                    Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No payments recorded yet.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._payments.map((p) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: Text('₹${p.amount.toStringAsFixed(0)}'),
                              subtitle: Text('${p.date.toLocal().toString().split(' ')[0]} · ${_modeLabel(p.mode)}'),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _editPayment(p);
                                  } else if (action == 'delete') {
                                    _deletePayment(p);
                                  } else if (action == 'share') {
                                    _shareReceipt(p);
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(value: 'share', child: Text('Share Receipt')),
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final m = _member!;
    final color = statusColor(m.status);
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _photo != null ? _showImagePreview : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _photo != null ? FileImage(_photo!) : null,
                  child: _photo == null ? const Icon(Icons.person, size: 44, color: Colors.grey) : null,
                ),
                if (_photo != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fullscreen, size: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(m.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(m.memberCode, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(statusLabel(m.status), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final m = _member!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.phone_outlined, m.mobile),
            _infoRow(Icons.card_membership_outlined, _plan?.name ?? 'Unknown plan'),
            _infoRow(Icons.event_outlined, 'Joined ${m.startDate.toLocal().toString().split(' ')[0]}'),
            _infoRow(
              Icons.event_busy_outlined,
              m.isFrozen ? 'Frozen since ${m.frozenSince!.toLocal().toString().split(' ')[0]}' : 'Expires ${m.endDate.toLocal().toString().split(' ')[0]}',
              color: m.isFrozen ? Colors.blueAccent : null,
            ),
            if (m.creditBalance > 0)
              _infoRow(Icons.savings_outlined, 'Credit: ₹${m.creditBalance.toStringAsFixed(0)} (applied at next renewal)', color: Colors.blueAccent),
            if (!m.isPaid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _infoRow(Icons.currency_rupee, 'Due: ₹${m.amountDue.toStringAsFixed(0)}', color: Colors.red),
                    ),
                    TextButton.icon(
                      onPressed: _payDue,
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Pay Due'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontWeight: color != null ? FontWeight.w600 : null)),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    final m = _member!;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: m.isFrozen ? null : _renewMember,
            icon: const Icon(Icons.autorenew),
            label: const Text('Renew Plan'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _toggleFreeze,
            icon: Icon(m.isFrozen ? Icons.play_arrow : Icons.pause, size: 18),
            label: Text(m.isFrozen ? 'Unfreeze Membership' : 'Freeze Membership'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendReminder(false),
                icon: const Icon(Icons.sms_outlined, size: 18),
                label: const Text('SMS'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendReminder(true),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        ),
      ],
    );
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
}
