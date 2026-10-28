// Masar design system (v5.17, Phase 1 — "فضاء مسار" space + glass).
//
// ONE place for the shared visual tokens the instruction asks to keep out of
// individual screens: spacing scale, corner radii, semantic status colors and
// the single selective glass recipe (BackdropFilter).
//
// HONEST SCOPE:
//  - Colors themselves stay in theme.dart (AppColors) — the single source of
//    truth the whole app already resolves through the ambient ColorScheme.
//  - The glass effect is intentionally SELECTIVE: modal sheets and dialogs
//    (the surfaces that genuinely float over dimmed content). Not every
//    widget gets a blur — readability and mid-range device performance come
//    first, and reduce-motion collapses the effect to a solid surface.
//  - Status feedback never relies on color alone: success/warning/error are
//    always paired with an icon + text (check_circle / error / warning) —
//    see the lesson feedback bar and settings snackbars.
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Layout tokens. Screens reference these instead of scattering literals;
/// existing call sites migrate opportunistically (no big-bang rewrite).
abstract final class MasarDS {
  // ---- spacing scale (logical px) ----
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 24;

  // ---- corner radii ----
  static const double radiusSm = 12;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // ---- control heights (>=48dp touch targets, a11y floor) ----
  static const double tapMin = 48;
  static const double buttonHeight = 52;
  static const double buttonHeightCompact = 46;

  // ---- semantic status (color + icon, never color alone) ----
  static const Color success = AppColors.green;
  static const Color successOnLight = AppColors.greenText;
  static const Color warning = AppColors.yellow;
  static const Color warningOnLight = AppColors.yellowDark;
  static const Color danger = AppColors.red;
  static const IconData successIcon = Icons.check_circle;
  static const IconData warningIcon = Icons.warning_amber_rounded;
  static const IconData dangerIcon = Icons.error;
}

/// The ONE glass recipe (Phase 1): a frosted panel over whatever scrolls or
/// dims behind it. Used selectively — modal sheets and dialogs — never as
/// per-widget decoration.
///
/// Accessibility contract: when [frosted] is false (reduce-motion preference
/// or any "less effects" path) it renders a SOLID surface — same geometry,
/// zero backdrop cost. Text always sits on >= the base surface alpha, so the
/// WCAG pairs pinned in contrast_test.dart keep holding over either variant.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  /// false -> solid surface (reduce-motion / low-end fallback).
  final bool frosted;
  final Color? fallbackColor;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.frosted = true,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        fallbackColor ?? (context.isDark ? AppColors.darkCard : AppColors.bg);
    if (!frosted) {
      return Material(
        color: base,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        // A single low-radius blur: readable, cheap enough for mid-range
        // devices, and only on modal surfaces (never per list item).
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: context.isDark
              ? AppColors.darkCard.withValues(alpha: 0.88)
              : AppColors.bg.withValues(alpha: 0.90),
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
