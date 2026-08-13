import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../models/member.dart';
import '../utils/status_colors.dart';
import '../widgets/gradient_border_box.dart';
import 'member_detail_screen.dart';

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
          ? _all
          : _all.where((m) =>
              m.name.toLowerCase().contains(query) ||
              m.mobile.contains(query) ||
              m.memberCode.toLowerCase().contains(query)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final theme = Theme.of(context);

  return _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              const SizedBox(height: 16),
              Text(
                '${_filtered.length} member${_filtered.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
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
                ..._filtered.map(_buildTile),
              const SizedBox(height: 80),
            ],
          ),
        );
  }
  Widget _buildTile(Member m) {
    final color = statusColor(m.status);
    return Card(
      child: ListTile(
        leading: _buildAvatar(m, color),
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
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id)),
          );
          load();
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
