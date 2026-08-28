import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../models/member.dart';
import '../utils/status_colors.dart';
import '../utils/responsive.dart';
import '../widgets/gradient_border_box.dart';
import 'member_detail_screen.dart';

enum _SortOption { nameAsc, expiryDate, dueHighToLow, joinDateNewest }

class MembersTabScreen extends ConsumerStatefulWidget {
  const MembersTabScreen({super.key});

  @override
  ConsumerState<MembersTabScreen> createState() => MembersTabScreenState();
}

class MembersTabScreenState extends ConsumerState<MembersTabScreen> {
  final _searchCtrl = TextEditingController();
  List<Member> _all = [];
  List<Member> _filtered = [];
  bool _loading = true;
  _SortOption _sortOption = _SortOption.nameAsc;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    load();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    final repo = ref.read(gymRepositoryProvider);
    final members = await repo.getMembers();
    members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _all = members;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? List.of(_all)
          : _all.where((m) =>
              m.name.toLowerCase().contains(query) ||
              m.mobile.contains(query) ||
              m.memberCode.toLowerCase().contains(query)).toList();
      _sortFiltered();
    });
  }

  void _sortFiltered() {
    switch (_sortOption) {
      case _SortOption.nameAsc:
        _filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.expiryDate:
        _filtered.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case _SortOption.dueHighToLow:
        _filtered.sort((a, b) => b.amountDue.compareTo(a.amountDue));
        break;
      case _SortOption.joinDateNewest:
        _filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
    }
  }

  void _setSortOption(_SortOption option) {
    setState(() => _sortOption = option);
    _applyFilter();
  }

  String _sortOptionLabel(_SortOption option) {
    switch (option) {
      case _SortOption.nameAsc:
        return 'Name (A-Z)';
      case _SortOption.expiryDate:
        return 'Expiry Date';
      case _SortOption.dueHighToLow:
        return 'Due Amount (High-Low)';
      case _SortOption.joinDateNewest:
        return 'Join Date (Newest)';
    }
  }

  void _enterSelectionMode(String memberId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(memberId);
    });
  }

  void _toggleSelection(String memberId) {
    setState(() {
      if (_selectedIds.contains(memberId)) {
        _selectedIds.remove(memberId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(memberId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Members'),
        content: Text('Delete $count member${count == 1 ? '' : 's'}? This removes their profile, photo, and payment history permanently.'),
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

    final repo = ref.read(gymRepositoryProvider);
    for (final id in _selectedIds.toList()) {
      await repo.deleteMember(id);
    }
    _clearSelection();
    load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isTablet = Responsive.isTablet(context);

  return _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 16),
            children: [
              Responsive.centered(
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
                maxWidth: Responsive.maxContentWidth,
              ),
              const SizedBox(height: 16),
              if (_selectionMode)
                Responsive.centered(
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                      ),
                      const Spacer(),
                      Text('${_selectedIds.length} selected', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  maxWidth: Responsive.maxContentWidth,
                )
              else
                Responsive.centered(
                Row(
                  children: [
                    Text(
                      '${_filtered.length} member${_filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    ),
                    const Spacer(),
                    PopupMenuButton<_SortOption>(
                      tooltip: 'Sort by',
                      icon: Icon(Icons.sort, size: 20, color: theme.hintColor),
                      onSelected: _setSortOption,
                      itemBuilder: (ctx) => _SortOption.values
                          .map((o) => PopupMenuItem(
                                value: o,
                                child: Row(
                                  children: [
                                    if (o == _sortOption) Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                                    if (o == _sortOption) const SizedBox(width: 6),
                                    Text(_sortOptionLabel(o)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                maxWidth: Responsive.maxContentWidth,
              ),
              const SizedBox(height: 8),
              if (_filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No members found.',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ),
                )
              else
                Responsive.centered(_buildMembersGrid(context), maxWidth: Responsive.maxContentWidth),
              const SizedBox(height: 80),
            ],
          ),
        );
  }

  /// Phones: single-column list of `ListTile` rows (unchanged).
  /// Tablets/desktop: grid of member cards, 2-3 columns per your choice,
  /// so the wider screen shows more members at once instead of one long
  /// stretched-out column.
  Widget _buildMembersGrid(BuildContext context) {
    if (Responsive.isPhone(context)) {
      return Column(children: _filtered.map(_buildTile).toList());
    }
    final columns = Responsive.gridColumns(context, tablet: 2, desktop: 3);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filtered.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, i) => _buildTile(_filtered[i]),
    );
  }

  Widget _buildTile(Member m) {
    final color = statusColor(m.status);
    final isSelected = _selectedIds.contains(m.id);
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
      child: ListTile(
        leading: _selectionMode
            ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(m.id))
            : _buildAvatar(m, color),
        title: Text(m.name),
        subtitle: Text('${m.memberCode} · ${m.mobile}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(statusLabel(m.status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text('Ends ${m.endDate.toLocal().toString().split(' ')[0]}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        onTap: () async {
          if (_selectionMode) {
            _toggleSelection(m.id);
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id)),
          );
          load();
        },
        onLongPress: _selectionMode ? null : () => _enterSelectionMode(m.id),
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
