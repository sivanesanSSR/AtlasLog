import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../services/providers.dart';
import '../services/backup_service.dart';
import '../models/member.dart';
import '../utils/status_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_border_box.dart';
import '../widgets/gradient_button.dart';
import 'add_member_screen.dart';
import 'plan_management_screen.dart';
import 'gym_profile_screen.dart';
import 'send_reminders_screen.dart';
import 'analytics_screen.dart';
import 'member_detail_screen.dart';

/// Which quick-filter card is currently active on the Dashboard, if any.
enum _CardFilter { none, paid, unpaid, active, expiringSoon, expired }

class DashboardScreen extends ConsumerStatefulWidget {
  /// When true, this widget renders only its body content (no Scaffold/
  /// AppBar/Drawer/FAB) — used when hosted as a tab inside HomeShellScreen,
  /// which owns the surrounding chrome. Defaults to false for standalone use.
  final bool embedded;

  const DashboardScreen({super.key, this.embedded = false});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, int>? _counts;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  bool _loading = true;
  String _gymName = 'Gym Manager';
  File? _gymLogo;

  final _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;
  _CardFilter _cardFilter = _CardFilter.none;

  @override
  void initState() {
    super.initState();
    _dateRange = _defaultThisMonthRange();
    _searchCtrl.addListener(_applyFilters);
    _load();
  }

  DateTimeRange _defaultThisMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(gymRepositoryProvider);
    final counts = await repo.getDashboardCounts();
    final members = await repo.getMembers();
    final profile = await repo.getGymProfile();
    final logo = await ref.read(localStorageServiceProvider).resolvePhoto(profile?.logoPath);
    members.sort((a, b) => a.endDate.compareTo(b.endDate));
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _allMembers = members;
      _gymName = profile?.name.isNotEmpty == true ? profile!.name : 'Gym Manager';
      _gymLogo = logo;
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final range = _dateRange;
    final hasCardFilter = _cardFilter != _CardFilter.none;

    setState(() {
      _filteredMembers = _allMembers.where((m) {
        final matchesQuery = query.isEmpty ||
            m.name.toLowerCase().contains(query) ||
            m.mobile.contains(query) ||
            m.memberCode.toLowerCase().contains(query);

        // Date range is a "browse by join/renewal month" filter — it
        // only makes sense when the person isn't already narrowing by
        // status. A member expiring soon may well have joined months
        // ago, so ANDing both would hide them entirely (this was a bug:
        // tapping "Expiring Soon" showed 0 results because everyone got
        // excluded by the default "this month" date range).
        final matchesDate = hasCardFilter || range == null ||
            (!m.startDate.isBefore(range.start) &&
                !m.startDate.isAfter(range.end.add(const Duration(days: 1))));

        final matchesCard = switch (_cardFilter) {
          _CardFilter.none => true,
          _CardFilter.paid => m.isPaid,
          _CardFilter.unpaid => !m.isPaid,
          _CardFilter.active => m.status == MemberStatus.active,
          _CardFilter.expiringSoon => m.status == MemberStatus.expiringSoon,
          _CardFilter.expired => m.status == MemberStatus.expired,
        };

        return matchesQuery && matchesDate && matchesCard;
      }).toList();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() => _dateRange = null);
    _applyFilters();
  }

  Future<void> _exportBackup() async {
    Navigator.of(context).pop(); // close drawer
    try {
      await ref.read(backupServiceProvider).exportBackup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup() async {
    Navigator.of(context).pop(); // close drawer
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
    if (!mounted) return;

    switch (result) {
      case ImportResult.success:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup imported successfully')));
        _load();
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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCountsGrid(),
                const SizedBox(height: 20),
                _buildSearchAndFilterRow(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Members', style: Theme.of(context).textTheme.titleMedium),
                    if (_cardFilter != _CardFilter.none) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_cardFilterLabel(_cardFilter), style: const TextStyle(fontSize: 11)),
                        onDeleted: () => _toggleCardFilter(_cardFilter),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                    const Spacer(),
                    Text('${_filteredMembers.length} shown', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_filteredMembers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        _allMembers.isEmpty ? 'No members yet — tap + to add one.' : 'No members match your search/filter.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._filteredMembers.map(_buildMemberTile),
                if (widget.embedded) const SizedBox(height: 80), // clearance for shell's bottom nav + FAB
              ],
            ),
          );

    if (widget.embedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_gymName)),
      drawer: _buildDrawer(),
      body: bodyContent,
      floatingActionButton: GradientButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddMemberScreen()),
          );
          _load();
        },
        icon: Icons.person_add,
        child: const Text('Add Member'),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.secondary,
                border: Border(bottom: BorderSide(color: Colors.transparent)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x33FF8C00), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  GradientBorderBox(
                    borderRadius: 30,
                    borderWidth: 2,
                    fillColor: AppTheme.secondary,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primary,
                      backgroundImage: _gymLogo != null ? FileImage(_gymLogo!) : null,
                      child: _gymLogo == null ? const Icon(Icons.fitness_center, color: Colors.white) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _gymName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GradientBorderBox(
                borderRadius: 14,
                borderWidth: 1.5,
                fillColor: AppTheme.primary.withOpacity(0.12),
                child: ListTile(
                  leading: const Icon(Icons.dashboard_outlined, color: AppTheme.primary),
                  title: const Text('Dashboard', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Analytics & Reports'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send Reminders'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SendRemindersScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.card_membership_outlined),
              title: const Text('Manage Plans'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanManagementScreen()));
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Gym Profile'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GymProfileScreen()));
                _load();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Export Backup'),
              onTap: _exportBackup,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Import Backup'),
              onTap: _importBackup,
            ),
          ],
        ),
      ),
    );
  }

Widget _buildSearchAndFilterRow() {
  final theme = Theme.of(context);
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Border overlapping fixed via clipBehavior & zero padding on outer wrapper
      ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: GradientBorderBox(
          borderRadius: 28,
          borderWidth: 1.2,
          fillColor: theme.cardColor,
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: 'Search by name, mobile, or member ID',
              hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
              prefixIcon: Icon(Icons.search, size: 20, color: theme.hintColor),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: theme.hintColor),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GradientBorderBox(
                borderRadius: 14,
                borderWidth: 1.2,
                fillColor: theme.cardColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: _pickDateRange,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateRange == null
                                ? 'All dates'
                                : _cardFilter != _CardFilter.none
                                    ? '${_dateRange!.start.day}/${_dateRange!.start.month} – ${_dateRange!.end.day}/${_dateRange!.end.month} (paused while filtering)'
                                    : '${_dateRange!.start.day}/${_dateRange!.start.month} – ${_dateRange!.end.day}/${_dateRange!.end.month}',
                            style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_dateRange != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GradientBorderBox(
                borderRadius: 14,
                borderWidth: 1.2,
                fillColor: theme.cardColor,
                child: IconButton(
                  tooltip: 'Clear date filter',
                  icon: const Icon(Icons.filter_alt_off, size: 20, color: AppTheme.primary),
                  onPressed: _clearDateFilter,
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

void _toggleCardFilter(_CardFilter filter) {
  setState(() {
    _cardFilter = _cardFilter == filter ? _CardFilter.none : filter;
  });
  _applyFilters();
}

String _cardFilterLabel(_CardFilter filter) {
  switch (filter) {
    case _CardFilter.paid:
      return 'Paid';
    case _CardFilter.unpaid:
      return 'Unpaid';
    case _CardFilter.active:
      return 'Active';
    case _CardFilter.expiringSoon:
      return 'Expiring Soon';
    case _CardFilter.expired:
      return 'Expired';
    case _CardFilter.none:
      return '';
  }
}

Widget _buildCountsGrid() {
  final c = _counts!;
  final items = [
    ('Total', c['total']!, Colors.blueGrey, _CardFilter.none),
    ('Paid', c['paid']!, AppTheme.success, _CardFilter.paid),
    ('Unpaid', c['unpaid']!, AppTheme.danger, _CardFilter.unpaid),
    ('Active', c['active']!, AppTheme.success, _CardFilter.active),
    ('Expiring Soon', c['expiringSoon']!, AppTheme.warning, _CardFilter.expiringSoon),
    ('Expired', c['expired']!, AppTheme.danger, _CardFilter.expired),
  ];
  return GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.3,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    children: items.map((i) => _countCard(i.$1, i.$2, i.$3, i.$4)).toList(),
  );
}

  Widget _countCard(String label, int value, Color color, _CardFilter filter) {
  final theme = Theme.of(context);
  final isTotal = filter == _CardFilter.none;
  final isActive = _cardFilter == filter && !isTotal;

  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isTotal
          ? (_cardFilter != _CardFilter.none
              ? () => setState(() {
                    _cardFilter = _CardFilter.none;
                    _applyFilters();
                  })
              : null)
          : () => _toggleCardFilter(filter),
      child: GradientBorderBox(
        borderRadius: 16,
        // Double border thickness when highlighted (e.g., 3.0 vs 1.0)
        borderWidth: isActive ? 3.0 : 1.0, 
        // Keep the fill transparent or same as cardColor (no solid background highlight)
        fillColor: theme.cardColor,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isActive ? AppTheme.primary : color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive 
                    ? AppTheme.primary 
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
  
  Widget _buildMemberTile(Member m) {
    final color = statusColor(m.status);
    return Card(
      child: ListTile(
        leading: _buildAvatar(m, color),
        title: Text(m.name),
        subtitle: Text('${m.memberCode} · ${m.mobile}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(statusLabel(m.status), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text('Ends ${m.endDate.toLocal().toString().split(' ')[0]}', style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id)),
          );
          _load();
        },
      ),
    );
  }

  Widget _buildAvatar(Member m, Color statusColorValue) {
    if (m.photoPath == null) {
      return CircleAvatar(backgroundColor: statusColorValue, radius: 8);
    }
    return FutureBuilder<File?>(
      future: ref.read(localStorageServiceProvider).resolvePhoto(m.photoPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: file != null ? FileImage(file) : null,
          child: file == null ? Icon(Icons.person, size: 18, color: statusColorValue) : null,
        );
      },
    );
  }
}
