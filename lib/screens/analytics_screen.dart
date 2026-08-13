import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/providers.dart';
import '../models/member.dart';
import '../models/plan.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  /// When true, renders only the body content, no Scaffold/AppBar —
  /// used when hosted as a tab inside HomeShellScreen.
  final bool embedded;

  const AnalyticsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _loading = true;
  List<Member> _members = [];
  List<Plan> _plans = [];
  List<Payment> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(gymRepositoryProvider);
    final members = await repo.getMembers();
    final plans = await repo.getPlans();
    final payments = await repo.getPayments();
    if (!mounted) return;
    setState(() {
      _members = members;
      _plans = plans;
      _payments = payments;
      _loading = false;
    });
  }

  double get _totalRevenue => _payments.fold(0.0, (sum, p) => sum + p.amount);

  double get _outstandingDue => _members.fold(0.0, (sum, m) => sum + m.amountDue);

  double _revenueInLast(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _payments.where((p) => p.date.isAfter(cutoff)).fold(0.0, (sum, p) => sum + p.amount);
  }

  Map<String, int> get _planDistribution {
    final map = <String, int>{};
    for (final m in _members) {
      final plan = _plans.where((p) => p.id == m.planId).firstOrNull;
      final name = plan?.name ?? 'Unknown';
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }

  Map<PaymentMode, double> get _paymentModeBreakdown {
    final map = <PaymentMode, double>{};
    for (final p in _payments) {
      map[p.mode] = (map[p.mode] ?? 0) + p.amount;
    }
    return map;
  }

  /// Monthly revenue for the last 6 months (oldest to newest).
  List<MapEntry<String, double>> get _monthlyRevenueTrend {
    final now = DateTime.now();
    final result = <MapEntry<String, double>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final total = _payments
          .where((p) => !p.date.isBefore(month) && p.date.isBefore(nextMonth))
          .fold(0.0, (sum, p) => sum + p.amount);
      final label = _monthLabel(month);
      result.add(MapEntry(label, total));
    }
    return result;
  }

  String _monthLabel(DateTime d) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[d.month - 1];
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
                _buildRevenueSummaryRow(),
                const SizedBox(height: 24),
                _sectionTitle('Monthly Revenue (Last 6 Months)'),
                const SizedBox(height: 12),
                _buildRevenueTrendChart(),
                const SizedBox(height: 24),
                _sectionTitle('Plan Distribution'),
                const SizedBox(height: 12),
                _buildPlanDistributionChart(),
                const SizedBox(height: 24),
                _sectionTitle('Payment Mode Breakdown'),
                const SizedBox(height: 12),
                _buildPaymentModeList(),
                const SizedBox(height: 24),
                _sectionTitle('Membership Status'),
                const SizedBox(height: 12),
                _buildStatusBreakdown(),
                if (widget.embedded) const SizedBox(height: 80),
              ],
            ),
          );

    if (widget.embedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & Reports')),
      body: bodyContent,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildRevenueSummaryRow() {
    final items = [
      ('Total Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', AppTheme.success),
      ('This Month', '₹${_revenueInLast(30).toStringAsFixed(0)}', AppTheme.primary),
      ('Outstanding Due', '₹${_outstandingDue.toStringAsFixed(0)}', AppTheme.danger),
    ];
    return Row(
      children: items
          .map((item) => Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Column(
                      children: [
                        Text(item.$2,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.$3)),
                        const SizedBox(height: 4),
                        Text(item.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRevenueTrendChart() {
    final data = _monthlyRevenueTrend;
    final maxY = data.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);
    final safeMaxY = maxY == 0 ? 100.0 : maxY * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: safeMaxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(data[i].key, style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(data.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].value,
                      color: AppTheme.primary,
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanDistributionChart() {
    final dist = _planDistribution;
    if (dist.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(20), child: Text('No members yet.')),
      );
    }

    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.success,
      AppTheme.warning,
      Colors.blueGrey,
      Colors.purple,
    ];
    final entries = dist.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: PieChart(
                PieChartData(
                  sections: List.generate(entries.length, (i) {
                    final color = colors[i % colors.length];
                    return PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: color,
                      title: '${entries[i].value}',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(entries.length, (i) {
                  final color = colors[i % colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entries[i].key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeList() {
    final breakdown = _paymentModeBreakdown;
    if (breakdown.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(20), child: Text('No payments recorded yet.')),
      );
    }
    return Card(
      child: Column(
        children: breakdown.entries.map((e) {
          return ListTile(
            leading: Icon(_iconForMode(e.key)),
            title: Text(_labelForMode(e.key)),
            trailing: Text('₹${e.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    int active = 0, expiringSoon = 0, expired = 0;
    for (final m in _members) {
      switch (m.status) {
        case MemberStatus.active:
          active++;
          break;
        case MemberStatus.expiringSoon:
          expiringSoon++;
          break;
        case MemberStatus.expired:
          expired++;
          break;
      }
    }
    final total = _members.length == 0 ? 1 : _members.length;

    Widget bar(String label, int count, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: count / total,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            bar('Active', active, AppTheme.success),
            bar('Expiring Soon', expiringSoon, AppTheme.warning),
            bar('Expired', expired, AppTheme.danger),
          ],
        ),
      ),
    );
  }

  IconData _iconForMode(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash:
        return Icons.payments_outlined;
      case PaymentMode.upi:
        return Icons.qr_code;
      case PaymentMode.card:
        return Icons.credit_card;
      case PaymentMode.other:
        return Icons.more_horiz;
    }
  }

  String _labelForMode(PaymentMode mode) {
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
