import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/reminder_service.dart';
import '../services/message_template_service.dart';
import '../models/member.dart';
import '../models/gym_profile.dart';
import '../models/plan.dart';
import '../utils/status_colors.dart';
import '../utils/responsive.dart';
import 'edit_message_template_screen.dart';

enum ReminderChannel { whatsapp, sms }

class SendRemindersScreen extends ConsumerStatefulWidget {
  const SendRemindersScreen({super.key});

  @override
  ConsumerState<SendRemindersScreen> createState() => _SendRemindersScreenState();
}

class _SendRemindersScreenState extends ConsumerState<SendRemindersScreen> {
  final _reminderService = ReminderService();
  List<Member> _candidates = []; // expiring soon or expired
  Map<String, Plan> _plansById = {};
  GymProfile? _gymProfile;
  String _template = defaultReminderTemplate;
  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(gymRepositoryProvider);
    final members = await repo.getMembers();
    final profile = await repo.getGymProfile();
    final plans = await repo.getPlans();
    final template = await ref.read(messageTemplateServiceProvider).getTemplate();

    final candidates = members
        .where((m) => m.status == MemberStatus.expiringSoon || m.status == MemberStatus.expired)
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _gymProfile = profile;
      _plansById = {for (final p in plans) p.id: p};
      _template = template;
      _selected
        ..clear()
        ..addAll(candidates.map((m) => m.id)); // pre-select all by default
      _loading = false;
    });
  }

  Future<void> _editTemplate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditMessageTemplateScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _sendIndividual(Member member, ReminderChannel channel) async {
    final plan = _plansById[member.planId];
    final ok = channel == ReminderChannel.whatsapp
        ? await _reminderService.sendViaWhatsApp(member: member, gymProfile: _gymProfile, plan: plan, template: _template)
        : await _reminderService.sendViaSms(member: member, gymProfile: _gymProfile, plan: plan, template: _template);

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          channel == ReminderChannel.whatsapp
              ? 'Could not open WhatsApp — check the number or that WhatsApp is installed.'
              : 'Could not open the SMS app.',
        )),
      );
    }
  }

  Future<void> _startBulkSend(ReminderChannel channel) async {
    final selectedMembers = _candidates.where((m) => _selected.contains(m.id)).toList();
    if (selectedMembers.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BulkSendQueueScreen(
          members: selectedMembers,
          gymProfile: _gymProfile,
          plansById: _plansById,
          template: _template,
          channel: channel,
          reminderService: _reminderService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Reminders'),
        actions: [
          IconButton(
            tooltip: 'Edit message',
            icon: const Icon(Icons.edit_note),
            onPressed: _editTemplate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _candidates.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No members are expiring soon or expired right now — nothing to remind.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
                  child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.orange.withOpacity(0.08),
                      child: const Text(
                        'This opens WhatsApp or SMS with the message pre-filled — you tap Send yourself for each one. '
                        'There\'s no automatic sending without a paid messaging service.',
                        style: TextStyle(fontSize: 12.5, color: Colors.black87),
                      ),
                    ),
                    Expanded(
                      child: Responsive.isPhone(context)
                          ? ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _candidates.length,
                        itemBuilder: (context, i) => _reminderCard(_candidates[i]),
                      )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _candidates.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Responsive.gridColumns(context, tablet: 2, desktop: 3),
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.4,
                              ),
                              itemBuilder: (context, i) => _reminderCard(_candidates[i]),
                            ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selected.isEmpty ? null : () => _startBulkSend(ReminderChannel.sms),
                                icon: const Icon(Icons.sms_outlined),
                                label: Text('SMS (${_selected.length})'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _selected.isEmpty ? null : () => _startBulkSend(ReminderChannel.whatsapp),
                                icon: const Icon(Icons.chat),
                                label: Text('WhatsApp (${_selected.length})'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
                ),
    );
  }

  Widget _reminderCard(Member m) {
    final color = statusColor(m.status);
    return Card(
      child: CheckboxListTile(
        value: _selected.contains(m.id),
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selected.add(m.id);
            } else {
              _selected.remove(m.id);
            }
          });
        },
        title: Text(m.name),
        subtitle: Text(
          '${m.mobile} · ${statusLabel(m.status)} · Ends ${m.endDate.toLocal().toString().split(' ')[0]}',
          style: TextStyle(color: color),
        ),
        secondary: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Send via WhatsApp',
              icon: const Icon(Icons.chat, color: Colors.green),
              onPressed: () => _sendIndividual(m, ReminderChannel.whatsapp),
            ),
            IconButton(
              tooltip: 'Send via SMS',
              icon: const Icon(Icons.sms_outlined),
              onPressed: () => _sendIndividual(m, ReminderChannel.sms),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp/SMS can only send to one recipient per app-open — this screen
/// walks through the selected members one at a time so "bulk" sending is
/// at least a fast queue rather than repeating the whole flow manually.
class _BulkSendQueueScreen extends StatefulWidget {
  final List<Member> members;
  final GymProfile? gymProfile;
  final Map<String, Plan> plansById;
  final String template;
  final ReminderChannel channel;
  final ReminderService reminderService;

  const _BulkSendQueueScreen({
    required this.members,
    required this.gymProfile,
    required this.plansById,
    required this.template,
    required this.channel,
    required this.reminderService,
  });

  @override
  State<_BulkSendQueueScreen> createState() => _BulkSendQueueScreenState();
}

class _BulkSendQueueScreenState extends State<_BulkSendQueueScreen> {
  int _index = 0;
  final Set<String> _sent = {};

  Member get _current => widget.members[_index];
  Plan? get _currentPlan => widget.plansById[_current.planId];

  Future<void> _sendCurrent() async {
    final ok = widget.channel == ReminderChannel.whatsapp
        ? await widget.reminderService.sendViaWhatsApp(
            member: _current, gymProfile: widget.gymProfile, plan: _currentPlan, template: widget.template)
        : await widget.reminderService.sendViaSms(
            member: _current, gymProfile: widget.gymProfile, plan: _currentPlan, template: widget.template);

    if (ok) {
      setState(() => _sent.add(_current.id));
    }
  }

  void _next() {
    if (_index < widget.members.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _current;
    final channelLabel = widget.channel == ReminderChannel.whatsapp ? 'WhatsApp' : 'SMS';

    return Scaffold(
      appBar: AppBar(title: Text('Sending via $channelLabel (${_index + 1}/${widget.members.length})')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: (_index + 1) / widget.members.length),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(m.mobile, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    Text(
                      widget.reminderService.renderTemplate(
                        template: widget.template,
                        member: m,
                        gymProfile: widget.gymProfile,
                        plan: _currentPlan,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_sent.contains(m.id))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Opened — tap Next once sent', style: TextStyle(color: Colors.green)),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _sendCurrent,
                icon: Icon(widget.channel == ReminderChannel.whatsapp ? Icons.chat : Icons.sms_outlined),
                label: Text('Open $channelLabel for ${m.name}'),
              ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _next,
                    child: Text(_index < widget.members.length - 1 ? 'Skip' : 'Finish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sent.contains(m.id) ? _next : null,
                    child: Text(_index < widget.members.length - 1 ? 'Next' : 'Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
