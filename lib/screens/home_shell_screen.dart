import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/gradient_border_box.dart';
import '../widgets/gradient_button.dart';
import 'dashboard_screen.dart';
import 'members_tab_screen.dart';
import 'analytics_screen.dart';
import 'settings_tab_screen.dart';
import 'add_member_screen.dart';
import 'plan_management_screen.dart';
import 'gym_profile_screen.dart';
import 'send_reminders_screen.dart';

/// Owns the app's primary navigation chrome: a bottom nav bar for the
/// four main sections (Dashboard/Members/Reports/Settings), plus a
/// drawer (opened via the hamburger icon) for secondary actions and
/// quick links — mirroring the reference design's dual navigation.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;
  int _dashboardRefreshToken = 0;
  final _membersTabKey = GlobalKey<MembersTabScreenState>();

  String _gymName = 'Gym Manager';
  File? _gymLogo;

  static const _titles = ['Dashboard', 'Members', 'Reports', 'Settings'];

  @override
  void initState() {
    super.initState();
    _loadGymHeader();
  }

  Future<void> _loadGymHeader() async {
    final repo = ref.read(gymRepositoryProvider);
    final profile = await repo.getGymProfile();
    final logo = await ref.read(localStorageServiceProvider).resolvePhoto(profile?.logoPath);
    if (!mounted) return;
    setState(() {
      _gymName = profile?.name.isNotEmpty == true ? profile!.name : 'Gym Manager';
      _gymLogo = logo;
    });
  }

  Future<void> _handleAddMember() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMemberScreen()),
    );
    // Remounting the Dashboard tab (via a changing key) re-triggers its
    // initState/_load, which is simpler and more robust than exposing
    // private state for a manual refresh call.
    setState(() => _dashboardRefreshToken++);
    _membersTabKey.currentState?.load();
  }

  static const _navItems = [
    (Icons.home_outlined, Icons.home, 'Dashboard'),
    (Icons.groups_outlined, Icons.groups, 'Members'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(key: ValueKey('dash_$_dashboardRefreshToken'), embedded: true),
      MembersTabScreen(key: _membersTabKey),
      const AnalyticsScreen(embedded: true),
      const SettingsTabScreen(),
    ];

    final isTablet = Responsive.isTablet(context);
    final fab = (_index == 0 || _index == 1)
        ? GradientButton(
            onPressed: _handleAddMember,
            icon: Icons.person_add,
            child: const Text('Add Member'),
          )
        : null;

    final appBar = AppBar(
      title: Text(_titles[_index]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4.0),
        child: Container(
          height: 4.0,
          color: AppTheme.primary, // Simple solid orange border line
        ),
      ),
    );

    final body = IndexedStack(index: _index, children: tabs);

    if (isTablet) {
      // Wide layout: persistent side NavigationRail replaces the bottom
      // nav bar. The drawer is kept (openable via the appbar icon) since
      // it still holds secondary destinations (Send Reminders, Manage
      // Plans, Gym Profile) that don't fit in the rail.
      return Scaffold(
        appBar: appBar,
        drawer: _buildDrawer(),
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              selectedIconTheme: const IconThemeData(color: AppTheme.primary),
              selectedLabelTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
              destinations: _navItems
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.$1),
                        selectedIcon: Icon(item.$2),
                        label: Text(item.$3),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1, color: Color(0x33FF8C00)),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: _buildDrawer(),
      body: body,
      floatingActionButton: fab,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = _navItems;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: const Border(top: BorderSide(color: Color(0x33FF8C00), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = _index == i;
              final (outlineIcon, filledIcon, label) = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selected ? filledIcon : outlineIcon, color: selected ? AppTheme.primary : Colors.grey, size: 24),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? AppTheme.primary : Colors.grey,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

Widget _buildDrawer() {
  return Drawer(
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.secondary,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x33FF8C00), Color(0x33FF8C00)],
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
                    style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Main Tabs with Dynamic Selection
          _buildDrawerItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            title: 'Dashboard',
            tabIndex: 0,
          ),
          _buildDrawerItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            title: 'Analytics & Reports',
            tabIndex: 2,
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
              if (mounted) setState(() => _dashboardRefreshToken++);
            },
          ),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Gym Profile'),
            onTap: () async {
              Navigator.of(context).pop();
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GymProfileScreen()));
              _loadGymHeader();
              if (mounted) setState(() => _dashboardRefreshToken++);
            },
          ),
          const Divider(),

          _buildDrawerItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            title: 'Settings',
            tabIndex: 3,
          ),
        ],
      ),
    ),
  );
}

/// Helper method to build drawer items that properly highlight based on current [_index]
Widget _buildDrawerItem({
  required IconData icon,
  required IconData activeIcon,
  required String title,
  required int tabIndex,
}) {
  final isSelected = _index == tabIndex;

  if (isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GradientBorderBox(
        borderRadius: 14,
        borderWidth: 1.5,
        fillColor: AppTheme.primary.withOpacity(0.12),
        child: ListTile(
          leading: Icon(activeIcon, color: AppTheme.textPrimary),
          title: Text(
            title,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
          onTap: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  return ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      setState(() => _index = tabIndex);
      Navigator.of(context).pop();
    },
  );
}
}