import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Replicates the CSS technique from the design reference:
///   background: <fill> padding-box, <gradient> border-box;
///   border: Npx solid transparent;
/// In Flutter this is a Container with a gradient background, holding
/// an inner Container inset by the border width with the actual fill
/// color — the visible gradient ring is whatever peeks out around the
/// inner box.
class GradientBorderBox extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final Color fillColor;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;

  const GradientBorderBox({
    super.key,
    required this.child,
    this.borderWidth = 1.5,
    this.borderRadius = 14,
    this.fillColor = AppTheme.surface,
    this.gradient,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient ?? AppTheme.borderGradient,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
          color: fillColor,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
