import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/member.dart';
import '../models/plan.dart';

/// Exports the current member list as a CSV file for accounting / sharing
/// with an accountant — previously the only export was the full JSON
/// backup (BackupService), which isn't usable outside the app itself.
class CsvExportService {
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _buildCsv(List<Member> members, List<Plan> plans) {
    final planNameById = {for (final p in plans) p.id: p.name};

    final rows = <List<String>>[
      ['Member Code', 'Name', 'Mobile', 'Plan', 'Start Date', 'Expiry Date', 'Amount Paid', 'Amount Due', 'Status'],
      for (final m in members)
        [
          m.memberCode,
          m.name,
          m.mobile,
          planNameById[m.planId] ?? 'Unknown',
          '${m.startDate.day}/${m.startDate.month}/${m.startDate.year}',
          '${m.endDate.day}/${m.endDate.month}/${m.endDate.year}',
          m.amountPaid.toStringAsFixed(0),
          m.amountDue.toStringAsFixed(0),
          m.status.name,
        ],
    ];

    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n');
  }

  /// Writes the CSV to a temp file and opens the native share sheet.
  Future<void> shareMembersCsv({required List<Member> members, required List<Plan> plans}) async {
    final csv = _buildCsv(members, plans);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${tempDir.path}/members_$timestamp.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Member list export — $timestamp',
    );
  }
}
