import 'package:flutter/material.dart';

/// Central breakpoint definitions and small helpers used across the app
/// to adapt layouts for phones, tablets, and (rarely) desktop windows.
///
/// Breakpoints follow Material 3 window size classes, simplified to the
/// three buckets this app actually needs:
///   - phone:   width <  600
///   - tablet:  600 <= width < 1024
///   - desktop: width >= 1024 (mostly relevant if the app is ever run
///     on a Chromebook / windowed Android tablet in split view)
class Responsive {
  Responsive._();

  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;

  /// Max content width used to keep single-column forms/detail screens
  /// from stretching edge-to-edge on wide screens.
  static const double maxFormWidth = 640;

  /// Max width for the overall app "canvas" on very wide screens.
  static const double maxContentWidth = 1200;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static bool isPhone(BuildContext context) => !isTablet(context);

  /// Number of grid columns for card/member grids, scaled by width.
  static int gridColumns(BuildContext context, {int phone = 1, int tablet = 2, int desktop = 3}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) return desktop;
    if (width >= tabletBreakpoint) return tablet;
    return phone;
  }

  /// Dashboard status-card grid: 3 across on phones, more on wider screens.
  static int dashboardGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) return 6;
    if (width >= tabletBreakpoint) return 4;
    return 3;
  }

  /// Symmetric page padding that widens the side gutters on tablets so a
  /// single-column form settles around [maxFormWidth] instead of
  /// stretching edge-to-edge, without having to restructure the form's
  /// widget tree. Drop-in replacement for `EdgeInsets.all(16)`.
  static EdgeInsets formPadding(BuildContext context, {double maxWidth = maxFormWidth, double vertical = 16}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) return EdgeInsets.symmetric(horizontal: 16, vertical: vertical);
    final horizontal = (width - maxWidth) / 2;
    return EdgeInsets.symmetric(horizontal: horizontal.clamp(16, width / 2 - 40), vertical: vertical);
  }

  /// Wraps [child] so it never exceeds [maxWidth] and stays centered,
  /// used for forms/detail screens so text fields don't stretch full
  /// width on a tablet.
  static Widget centered(Widget child, {double maxWidth = maxFormWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
