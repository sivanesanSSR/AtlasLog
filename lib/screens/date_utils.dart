/// Adds [months] calendar months to [date], clamping the resulting day to
/// the last valid day of the target month when the original day doesn't
/// exist there.
///
/// Plain `DateTime(date.year, date.month + months, date.day)` silently
/// overflows in that case — Dart's DateTime constructor rolls excess days
/// into the *following* month rather than clamping. e.g. Jan 31 + 1 month
/// becomes March 3 instead of Feb 28. That's wrong for plan expiry math:
/// members who join or renew on the 29th/30th/31st would silently get a
/// few extra free days every cycle, compounding on each renewal.
///
/// This clamps instead, matching how billing systems normally handle
/// month-end anchoring: Jan 31 + 1 month -> Feb 28 (or Feb 29 in a leap
/// year), Mar 31 + 1 month -> Apr 30, etc.
DateTime addMonthsClamped(DateTime date, int months) {
  final totalMonths = date.month - 1 + months;
  final year = date.year + totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  // Day 0 of the month after [month] is the last day of [month] itself.
  final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
  return DateTime(year, month, day);
}
