import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../models/plan.dart';
import '../utils/responsive.dart';
import 'home_shell_screen.dart';

class PlanManagementScreen extends ConsumerStatefulWidget {
  /// When true, this is part of first-run setup — the app bar shows a
  /// "Finish" action that navigates to the Dashboard once at least one
  /// plan exists.
  final bool isFirstRun;

  const PlanManagementScreen({super.key, this.isFirstRun = false});

  @override
  ConsumerState<PlanManagementScreen> createState() => _PlanManagementScreenState();
}

class _PlanManagementScreenState extends ConsumerState<PlanManagementScreen> {
  List<Plan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plans = await ref.read(gymRepositoryProvider).getPlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _openPlanForm({Plan? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanFormSheet(existing: existing),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Delete "${plan.name}"? Members already on this plan keep their current subscription, but you won\'t be able to select it for new members or renewals.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gymRepositoryProvider).deletePlan(plan.id);
      _load();
    }
  }

  void _finishSetup() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShellScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        automaticallyImplyLeading: !widget.isFirstRun,
        actions: [
          TextButton.icon(
            onPressed: widget.isFirstRun ? (_plans.isNotEmpty ? _finishSetup : null) : _finishSetup,
            icon: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 18),
            label: Text(
              widget.isFirstRun ? 'Finish' : 'Dashboard',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_membership, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No plans yet. Add your first plan\n(e.g. "1 Month", "Personal Training").',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Responsive.centered(
                  _buildPlansList(context),
                  maxWidth: Responsive.maxContentWidth,
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlanForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Plan'),
      ),
    );
  }

  Widget _planCard(Plan plan) {
    return Card(
      child: ListTile(
        title: Text(plan.name),
        subtitle: Text(
          plan.durationMonths > 0
              ? '${plan.durationMonths} month(s) · ₹${plan.price.toStringAsFixed(0)}'
              : '₹${plan.price.toStringAsFixed(0)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _openPlanForm(existing: plan),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _confirmDelete(plan),
            ),
          ],
        ),
      ),
    );
  }

  /// Phones: single-column list. Tablets/desktop: grid of plan cards.
  Widget _buildPlansList(BuildContext context) {
    if (Responsive.isPhone(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        itemBuilder: (context, i) => _planCard(_plans[i]),
      );
    }
    final columns = Responsive.gridColumns(context, tablet: 2, desktop: 3);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, i) => _planCard(_plans[i]),
    );
  }
}

class _PlanFormSheet extends ConsumerStatefulWidget {
  final Plan? existing;
  const _PlanFormSheet({this.existing});

  @override
  ConsumerState<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends ConsumerState<_PlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _priceCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _durationCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.durationMonths.toString() : '',
    );
    _priceCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.price.toStringAsFixed(0) : '',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(gymRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final duration = int.parse(_durationCtrl.text.trim());
      final price = double.parse(_priceCtrl.text.trim());

      if (widget.existing != null) {
        await repo.updatePlan(widget.existing!.copyWith(
          name: name,
          durationMonths: duration,
          price: price,
        ));
      } else {
        await repo.addPlan(name: name, durationMonths: duration, price: price);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing != null ? 'Edit Plan' : 'Add Plan',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Plan Name',
                hintText: 'e.g. 1 Month, 3 Month, Personal Training',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (months)',
                hintText: 'e.g. 1, 3, 6, 12',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.existing != null ? 'Save Changes' : 'Add Plan'),
            ),
          ],
        ),
      ),
    );
  }
}
