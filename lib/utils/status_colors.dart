import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';

/// Green = active (>3 days left), Yellow = expiring soon (<=3 days),
/// Red = expired, Blue = frozen (paused, countdown on hold). Computed
/// live from Member.status, never stored.
Color statusColor(MemberStatus status) {
  switch (status) {
    case MemberStatus.active:
      return AppTheme.success;
    case MemberStatus.expiringSoon:
      return AppTheme.warning;
    case MemberStatus.expired:
      return AppTheme.danger;
    case MemberStatus.frozen:
      return Colors.blueAccent;
  }
}

String statusLabel(MemberStatus status) {
  switch (status) {
    case MemberStatus.active:
      return 'Active';
    case MemberStatus.expiringSoon:
      return 'Expiring Soon';
    case MemberStatus.expired:
      return 'Expired';
    case MemberStatus.frozen:
      return 'Frozen';
  }
}
