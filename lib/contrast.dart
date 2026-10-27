// WCAG contrast math for Masar Al-Lugha (v5.15, plan feature F3.3).
//
// The automated accessibility pass measures every (text color, background
// color) pair in the theme catalog against WCAG 2.1 AA:
//   - 4.5:1 minimum for normal text,
//   - 3.0:1 minimum for large text (>= 18pt regular or >= 14pt bold).
//
// The formula is the standard relative-luminance one from the WCAG spec
// (sRGB linearization + 0.2126/0.7152/0.0722 weights + (L1+0.05)/(L2+0.05)).
// Pure Dart (no Flutter imports) so the theme test runs it directly; the UI
// uses the same values through theme.dart, so a fix in the catalog reaches
// every screen at once.

import 'dart:math' as math;

class Contrast {
  Contrast._();

  static const double aaNormal = 4.5;
  static const double aaLarge = 3.0;

  /// Linearizes one sRGB channel (0..1) per the WCAG definition.
  static double _channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  /// Relative luminance of an sRGB color's channels (all 0..1).
  static double lum(double r, double g, double b) =>
      0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b);

  /// Relative luminance from packed 0xRRGGBB.
  static double lumArgb(int rgb) => lum(((rgb >> 16) & 0xFF) / 255,
      ((rgb >> 8) & 0xFF) / 255, (rgb & 0xFF) / 255);

  /// Contrast ratio between two packed 0xRRGGBB colors (>= 1.0).
  static double ratio(int a, int b) {
    final la = lumArgb(a);
    final lb = lumArgb(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// True when the pair passes AA for the given text size class.
  static bool passesAA(int text, int background, {required bool large}) =>
      ratio(text, background) >= (large ? aaLarge : aaNormal);
}
