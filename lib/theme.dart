// Theme & shared visual language: Duolingo-inspired fun design.
import 'package:flutter/material.dart';

class AppColors {
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
  static const ink = Color(0xFF3C3C3C);
  static const inkLight = Color(0xFF777777);
  static const border = Color(0xFFE5E5E5);
  static const bg = Color(0xFFFFFFFF);
  static const bgSoft = Color(0xFFF7F7F7);
  static const locked = Color(0xFFE5E5E5);
  static const lockedDark = Color(0xFFCFCFCF);
}

ThemeData buildTheme(Locale locale) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      secondary: AppColors.blue,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.ink),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
    ),
  );
}

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
    final c = disabled ? AppColors.locked : color;
    final cd = disabled ? AppColors.lockedDark : colorDark;
    final tc = disabled ? AppColors.inkLight : textColor;
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
                    Icon(icon, color: tc, size: fontSize + 6),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: tc,
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                      letterSpacing: 0.2,
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
    Color border = AppColors.border;
    Color bg = Colors.white;
    Color badgeBg = AppColors.border;
    Color badgeFg = AppColors.inkLight;
    if (selected) {
      border = AppColors.blue;
      bg = AppColors.blueLight;
      badgeBg = AppColors.blue;
      badgeFg = Colors.white;
    }
    if (correct) {
      border = AppColors.green;
      bg = AppColors.greenLight;
      badgeBg = AppColors.green;
      badgeFg = Colors.white;
    }
    if (wrong) {
      border = AppColors.red;
      bg = AppColors.redLight;
      badgeBg = AppColors.red;
      badgeFg = Colors.white;
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
          boxShadow: const [
            BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 3),
                blurRadius: 0),
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
                  border: Border(
                    bottom: BorderSide(
                        color: badgeFg == Colors.white
                            ? Colors.black26
                            : AppColors.border,
                        width: 2),
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
              child: Text(
                text,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
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
    Color border = AppColors.border;
    Color bg = Colors.white;
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
          boxShadow: const [
            BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 4),
                blurRadius: 0),
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

  const WordTile({super.key, required this.text, this.onTap, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    if (ghost) {
      return Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 2),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: const [
            BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 3),
                blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
