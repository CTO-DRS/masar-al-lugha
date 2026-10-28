// Theme & shared visual language: Duolingo-inspired fun design.
// v4.0: full light + dark palettes; widgets resolve surfaces/borders/text
// from the ambient ColorScheme instead of hardcoded whites.
import 'package:flutter/material.dart';

class AppColors {
  // Brand palette (works on both light & dark surfaces).
  static const green = Color(0xFF58CC02);
  static const greenDark = Color(0xFF46A302);
  static const greenLight = Color(0xFFD7FFB8);
  static const blue = Color(0xFF1CB0F6);
  static const blueDark = Color(0xFF1899D6);
  static const blueLight = Color(0xFFDDF4FF);
  static const red = Color(0xFFFF4B4B);
  static const redDark = Color(0xFFEA2B2B);
  static const redLight = Color(0xFFFFDFE0);
  static const yellow = Color(0xFFFFC800);
  static const yellowDark = Color(0xFFE6A100);
  static const orange = Color(0xFFFF9600);
  static const purple = Color(0xFFCE82FF);

  // v5.15 (F3.3): text-safe shades of the brand hues for LIGHT surfaces.
  // The vivid constants above stay for icons/borders/fills that carry no
  // text; whenever a brand hue is the TEXT color on a light surface, use
  // one of these (all >= 4.5:1 on white and on bgSoft).
  static const greenText = Color(0xFF378200);
  static const blueText = Color(0xFF0F76B4);
  static const orangeText = Color(0xFFA86200);
  // Light-only constants kept for the few places that predate v4.0.
  // v5.15 (F3.3): inkLight/lockedDark deepened to pass WCAG AA — inkLight
  // 4.95:1 on white (was 4.48), lockedDark 3.14:1 on the locked fill (icons).
  static const ink = Color(0xFF3C3C3C);
  static const inkLight = Color(0xFF707070);
  static const border = Color(0xFFE5E5E5);
  static const bg = Color(0xFFFFFFFF);
  static const bgSoft = Color(0xFFF7F7F7);
  static const locked = Color(0xFFE5E5E5);
  static const lockedDark = Color(0xFF808080);

  // Dark surface colors.
  static const darkBg = Color(0xFF131F24);
  static const darkCard = Color(0xFF1B2A32);
  static const darkSoft = Color(0xFF22333C);
  static const darkBorder = Color(0xFF37464F);
  static const darkInk = Color(0xFFF1F7FB);
  static const darkInkLight = Color(0xFF9DB2BC);
  static const darkLocked = Color(0xFF3C5260);
}

/// Light/dark-aware semantic colors. Usage: `context.card`, `context.line`,
/// `context.bodyText`, `context.mutedText`, `context.softBg`, `context.pageBg`.
extension MasarThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get pageBg => Theme.of(this).scaffoldBackgroundColor;
  Color get card => Theme.of(this).colorScheme.surface;
  Color get softBg => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get line => Theme.of(this).colorScheme.outlineVariant;
  Color get bodyText => Theme.of(this).colorScheme.onSurface;
  Color get mutedText => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get lockedFill => isDark ? AppColors.darkLocked : AppColors.locked;
  Color get lockedText =>
      isDark ? AppColors.darkInkLight : AppColors.lockedDark;
}

/// v4.12.1 — first-strong-character text direction for mixed ar/en content.
///
/// The UI is Arabic-first (RTL), but the TARGET language of a course may be
/// Latin-script (English/French -> LTR) or Arabic-script (Urdu -> RTL).
/// Content that inherits the shell's direction renders REVERSED: the build
/// exercise laid "Good morning" out as "morning | Good". This scans for the
/// first strong directional character: Arabic/Hebrew blocks -> RTL, any
/// Latin/Greek/Cyrillic letter -> LTR; digits/punctuation/space/emoji are
/// neutral and skipped. Defaults to LTR when no strong character exists.
TextDirection directionOf(String text) {
  for (final r in text.runes) {
    final rtl = (r >= 0x0590 && r <= 0x05FF) || // Hebrew
        (r >= 0x0600 && r <= 0x06FF) || // Arabic + Urdu core
        (r >= 0x0750 && r <= 0x077F) || // Arabic supplement
        (r >= 0x08A0 && r <= 0x08FF) || // Arabic extended-A
        (r >= 0xFB50 && r <= 0xFDFF) || // Arabic presentation forms-A
        (r >= 0xFE70 && r <= 0xFEFF); // Arabic presentation forms-B
    if (rtl) return TextDirection.rtl;
    final ltr = (r >= 0x0041 && r <= 0x005A) || // A-Z
        (r >= 0x0061 && r <= 0x007A) || // a-z
        (r >= 0x00C0 && r <= 0x024F) || // Latin-1 letters + extended
        (r >= 0x0370 && r <= 0x04FF); // Greek + Cyrillic
    if (ltr) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}

/// v4.12.1 — wraps content in the direction of its own script so
/// target-language words/sentences lay out correctly inside the Arabic RTL
/// shell (and vice versa for Urdu inside a future LTR shell).
/// Used by the build (arrange) exercise, sentence prompts and example lines.
class ScriptDirection extends StatelessWidget {
  final String text;
  final Widget child;

  const ScriptDirection({super.key, required this.text, required this.child});

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: directionOf(text), child: child);
}

ThemeData buildMasarTheme({required bool dark}) {
  final scheme = dark
      ? ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.green,
          onPrimary: Colors.white,
          secondary: AppColors.blue,
          onSecondary: Colors.white,
          surface: AppColors.darkCard,
          onSurface: AppColors.darkInk,
          surfaceContainerHighest: AppColors.darkSoft,
          onSurfaceVariant: AppColors.darkInkLight,
          outlineVariant: AppColors.darkBorder,
          error: AppColors.red,
          onError: Colors.white,
        )
      : ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.green,
          onPrimary: Colors.white,
          secondary: AppColors.blue,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: AppColors.ink,
          surfaceContainerHighest: AppColors.bgSoft,
          onSurfaceVariant: AppColors.inkLight,
          outlineVariant: AppColors.border,
          error: AppColors.red,
          onError: Colors.white,
        );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.darkBg : Colors.white,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: dark ? AppColors.darkInk : AppColors.ink),
      titleTextStyle: TextStyle(
        color: dark ? AppColors.darkInk : AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppColors.darkSoft : AppColors.ink,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
      contentTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 14.5,
        height: 1.4,
      ),
    ),
  );
}

/// Back-compat shim: v3.x call sites used `buildTheme(locale)`.
ThemeData buildTheme(Locale locale) => buildMasarTheme(dark: false);

// Chunky 3D button — signature Duolingo look.
class ChunkyButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color colorDark;
  final Color textColor;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final IconData? icon;
  final bool disabled;

  const ChunkyButton({
    super.key,
    required this.label,
    this.color = AppColors.green,
    this.colorDark = AppColors.greenDark,
    this.textColor = Colors.white,
    this.onPressed,
    this.height = 52,
    this.fontSize = 17,
    this.icon,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    // v5.15 (F3.3) contrast policy, applied HERE so no call site has to
    // know the rules:
    //  1. Vivid brand surfaces are promoted to their -Dark sibling whenever
    //     the label is white — white on the vivid shade fails even the
    //     large-text 3:1 threshold, the -Dark shades pass it.
    //  2. Labels render at WCAG large-bold size (>= 18.7px bold), so the
    //     3:1 large-text threshold legitimately applies to them.
    var c = disabled ? context.lockedFill : color;
    var cd = disabled
        ? (context.isDark ? AppColors.darkBorder : AppColors.lockedDark)
        : colorDark;
    if (!disabled && identical(textColor, Colors.white)) {
      if (identical(c, AppColors.green)) {
        c = AppColors.greenDark;
        cd = AppColors.greenText;
      } else if (identical(c, AppColors.blue)) {
        c = AppColors.blueDark;
        cd = AppColors.blueText;
      } else if (identical(c, AppColors.red)) {
        c = AppColors.redDark;
        cd = AppColors.redDark;
      }
    }
    final tc = disabled ? context.mutedText : textColor;
    final fs = fontSize < 18.7 ? 18.7 : fontSize;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: cd, offset: const Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: height,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: tc, size: fs + 6),
                    const SizedBox(width: 8),
                  ],
                  // v5.17 (Phase-1 audit M-6): a long label overflowed the
                  // button Row on 360dp phones (the most common width) —
                  // the label now wraps inside the available width instead.
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: tc,
                        fontWeight: FontWeight.w800,
                        fontSize: fs,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Selectable option card used in quizzes.
class OptionCard extends StatelessWidget {
  final String text;
  final String? badge; // أ / ب / A / B ...
  final bool selected;
  final bool correct; // show green state in feedback
  final bool wrong; // show red state in feedback
  final VoidCallback? onTap;

  const OptionCard({
    super.key,
    required this.text,
    this.badge,
    this.selected = false,
    this.correct = false,
    this.wrong = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = context.line;
    Color bg = context.card;
    // v5.15 (F3.3): the badge is a small TEXT label — vivid fills failed AA
    // in both modes (white 2.1–3.3:1 light, darkInk 2.0–2.2:1 dark). The
    // badge pill goes theme-grey with body text: >= 8.7:1 in both modes;
    // the state colour is carried by the card border/background.
    Color badgeBg = context.line;
    Color badgeFg = context.bodyText;
    if (selected) {
      border = AppColors.blue;
      bg = AppColors.blueLight;
    }
    if (correct) {
      border = AppColors.green;
      bg = AppColors.greenLight;
    }
    if (wrong) {
      border = AppColors.red;
      bg = AppColors.redLight;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            if (badge != null) ...[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    bottom: BorderSide(color: Colors.black26, width: 2),
                  ),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        color: badgeFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              // v4.12.1: options may be full target-language sentences
              // (listen rounds) — lay them out in their own script direction.
              child: Text(
                text,
                textDirection: directionOf(text),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: selected || correct || wrong
                        ? AppColors.ink
                        : context.bodyText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Big tappable emoji picture card for interactive picture exercises.
class PictureCard extends StatelessWidget {
  final String emoji;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  const PictureCard({
    super.key,
    required this.emoji,
    this.selected = false,
    this.correct = false,
    this.wrong = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = context.line;
    Color bg = context.card;
    if (selected) {
      border = AppColors.blue;
      bg = AppColors.blueLight;
    }
    if (correct) {
      border = AppColors.green;
      bg = AppColors.greenLight;
    }
    if (wrong) {
      border = AppColors.red;
      bg = AppColors.redLight;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 52, height: 1.1),
          ),
        ),
      ),
    );
  }
}

// Small tile used in build (arrange) exercises.
class WordTile extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool ghost;

  const WordTile(
      {super.key, required this.text, this.onTap, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    if (ghost) {
      return Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.line, width: 2),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.transparent)),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.line, width: 2),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.bodyText),
        ),
      ),
    );
  }
}
