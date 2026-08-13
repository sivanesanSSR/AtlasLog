import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/reminder_service.dart';
import '../models/member.dart';
import '../models/plan.dart';
import '../models/payment.dart';
import '../utils/status_colors.dart';
import 'edit_member_screen.dart';
import 'renew_member_screen.dart';

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
                  padding: const EdgeInsets.all(16),
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
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _photo != null ? FileImage(_photo!) : null,
            child: _photo == null ? const Icon(Icons.person, size: 44, color: Colors.grey) : null,
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
            _infoRow(Icons.event_busy_outlined, 'Expires ${m.endDate.toLocal().toString().split(' ')[0]}'),
            if (!m.isPaid)
              _infoRow(Icons.currency_rupee, 'Due: ₹${m.amountDue.toStringAsFixed(0)}', color: Colors.red),
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
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _renewMember,
            icon: const Icon(Icons.autorenew),
            label: const Text('Renew Plan'),
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
