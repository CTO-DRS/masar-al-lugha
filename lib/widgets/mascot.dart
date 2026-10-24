// Rafiq & Friends — companion widgets (v4.5, rich art v4.8.1).
//
// The companions are drawn as layered vector art on a normalized 100x100
// canvas by [_CompanionPainter] — flat "Duolingo-style" shapes with soft
// shading, distinct silhouettes per character (owl tufts, chick crest,
// cat whiskers + tail, fox muzzle, bunny ears) and per-mood facial
// expressions (happy / celebrate / sad / neutral). No emoji glyphs, no
// images, no new dependencies — everything is CustomPainter paths, so it
// renders identically on every device and in widget tests.
//
// Personality data comes from lib/mascot.dart (engine: cast, unlocks,
// lines). This file only renders:
//   * Mascot        — a character body reacting to a mood
//   * MascotBubble  — companion + speech bubble for engine lines
//
// Back-compat: `MascotMood` is re-exported from the engine, and Mascot
// defaults to `rafiq`, so every pre-4.5 call site keeps compiling.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mascot.dart' show MascotMood, mascotById;
import '../theme.dart';

export '../mascot.dart' show MascotMood;

// ---------------- per-character palettes ----------------

class _Palette {
  final Color body;
  final Color dark; // shading: wings, ears, brows, strokes
  final Color light; // belly / inner ears / muzzle
  final Color accent; // beak / nose
  final bool bird; // birds get a beak + feet, furry get a muzzle

  const _Palette({
    required this.body,
    required this.dark,
    required this.light,
    required this.accent,
    required this.bird,
  });
}

const _purpleDark = Color(0xFFB05EE0);
const _purpleLight = Color(0xFFF1E4FF);
const _orangeDark = Color(0xFFE07C00);

_Palette _paletteFor(String id) {
  switch (id) {
    case 'farah':
      return const _Palette(
        body: AppColors.orange,
        dark: _orangeDark,
        light: AppColors.yellow,
        accent: AppColors.yellowDark,
        bird: true,
      );
    case 'nur':
      return const _Palette(
        body: AppColors.blue,
        dark: AppColors.blueDark,
        light: AppColors.blueLight,
        accent: AppColors.ink,
        bird: false,
      );
    case 'zayd':
      return const _Palette(
        body: AppColors.yellow,
        dark: AppColors.yellowDark,
        light: AppColors.bg,
        accent: AppColors.ink,
        bird: false,
      );
    case 'salma':
      return const _Palette(
        body: AppColors.purple,
        dark: _purpleDark,
        light: _purpleLight,
        accent: AppColors.ink,
        bird: false,
      );
    default: // rafiq
      return const _Palette(
        body: AppColors.green,
        dark: AppColors.greenDark,
        light: AppColors.greenLight,
        accent: AppColors.orange,
        bird: true,
      );
  }
}

// ---------------- the widget ----------------

class Mascot extends StatelessWidget {
  final double size;
  final MascotMood mood;
  final String characterId;

  const Mascot({
    super.key,
    this.size = 120,
    this.mood = MascotMood.happy,
    this.characterId = 'rafiq',
  });

  @override
  Widget build(BuildContext context) {
    final id = mascotById(characterId).id;
    return CustomPaint(
      size: Size.square(size),
      painter: _CompanionPainter(id, mood),
    );
  }
}

// ---------------- painter ----------------

class _CompanionPainter extends CustomPainter {
  final String characterId;
  final MascotMood mood;

  _CompanionPainter(this.characterId, this.mood);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _paletteFor(characterId);
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    _groundShadow(canvas);
    switch (characterId) {
      case 'farah':
        _paintChick(canvas, p);
        break;
      case 'nur':
        _paintCat(canvas, p);
        break;
      case 'zayd':
        _paintFox(canvas, p);
        break;
      case 'salma':
        _paintBunny(canvas, p);
        break;
      default:
        _paintOwl(canvas, p);
    }
    if (mood == MascotMood.celebrate) _celebration(canvas);

    canvas.restore();
  }

  // ---------------- shared helpers ----------------

  void _groundShadow(Canvas c) {
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 96.5), width: 46, height: 6),
      Paint()..color = const Color(0x1A3C3C3C),
    );
  }

  void _ellipse(
          Canvas c, double cx, double cy, double rx, double ry, Color color) =>
      c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        Paint()..color = color,
      );

  void _circle(Canvas c, double cx, double cy, double r, Color color) =>
      _ellipse(c, cx, cy, r, r, color);

  void _triangle(Canvas c, Offset a, Offset b, Offset d, Color color,
      {bool rounded = false}) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeJoin = rounded ? StrokeJoin.round : StrokeJoin.miter
        ..style = PaintingStyle.fill,
    );
  }

  /// Eye: white sclera + pupil + highlight. Sad looks down a little.
  void _eye(Canvas c, double cx, double cy, double r, MascotMood mood) {
    _circle(c, cx, cy, r, Colors.white);
    final dy = mood == MascotMood.sad ? r * 0.28 : 0.0;
    _circle(c, cx, cy + dy, r * 0.46, AppColors.ink);
    _circle(c, cx - r * 0.16, cy + dy - r * 0.18, r * 0.14, Colors.white);
  }

  /// Brows above the eyes: worried (inner ends up) when sad, raised and
  /// excited when celebrating. Hidden for happy/neutral.
  void _brows(Canvas c, MascotMood mood, Color color,
      {required Offset left, required Offset right, double w = 5}) {
    if (mood != MascotMood.sad && mood != MascotMood.celebrate) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final raise = mood == MascotMood.celebrate ? 3.0 : 0.0;
    final innerLift = mood == MascotMood.sad ? 6.0 : 3.0;
    // left brow: outer -> inner (inner end lifted)
    c.drawLine(Offset(left.dx - 7, left.dy - raise),
        Offset(left.dx, left.dy - raise - innerLift), paint);
    // right brow: inner -> outer (mirrored)
    c.drawLine(Offset(right.dx, right.dy - raise - innerLift),
        Offset(right.dx + 7, right.dy - raise), paint);
  }

  /// Furry mouth: nose + smile / frown / open smile per mood.
  void _muzzle(Canvas c, MascotMood mood, Offset nose, Color noseColor,
      {double w = 12}) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawCircle(nose, w * 0.18, Paint()..color = noseColor);
    final mouth = Path();
    switch (mood) {
      case MascotMood.sad:
        mouth
          ..moveTo(nose.dx - 5, nose.dy + 9)
          ..quadraticBezierTo(nose.dx, nose.dy + 4.5, nose.dx + 5, nose.dy + 9);
        break;
      case MascotMood.celebrate:
        mouth
          ..moveTo(nose.dx - 5, nose.dy + 6)
          ..quadraticBezierTo(nose.dx, nose.dy + 13, nose.dx + 5, nose.dy + 6)
          ..close();
        c.drawPath(mouth, Paint()..color = AppColors.ink);
        return;
      case MascotMood.neutral:
        mouth
          ..moveTo(nose.dx - 3.5, nose.dy + 8)
          ..lineTo(nose.dx + 3.5, nose.dy + 8);
        break;
      case MascotMood.happy:
        mouth
          ..moveTo(nose.dx - 5, nose.dy + 6)
          ..quadraticBezierTo(nose.dx, nose.dy + 11, nose.dx + 5, nose.dy + 6);
        break;
    }
    c.drawPath(mouth, paint);
  }

  /// Bird beak per mood: open diamond when celebrating, droopy when sad.
  void _beak(Canvas c, MascotMood mood, double cx, double cy, Color accent) {
    switch (mood) {
      case MascotMood.celebrate:
        _triangle(c, Offset(cx - 6, cy), Offset(cx + 6, cy), Offset(cx, cy + 9),
            accent,
            rounded: true);
        _triangle(c, Offset(cx - 4.5, cy + 1), Offset(cx + 4.5, cy + 1),
            Offset(cx, cy + 6.5), AppColors.ink.withValues(alpha: .55));
        break;
      case MascotMood.sad:
        _triangle(c, Offset(cx - 4, cy + 1), Offset(cx + 4, cy + 1),
            Offset(cx, cy + 6), accent,
            rounded: true);
        break;
      default:
        _triangle(c, Offset(cx - 5, cy - 1), Offset(cx + 5, cy - 1),
            Offset(cx, cy + 8), accent,
            rounded: true);
    }
  }

  void _celebration(Canvas c) {
    // star top-right
    final star = Path();
    const center = Offset(84, 12);
    const outer = 8.0;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : outer * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt =
          Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    c.drawPath(star, Paint()..color = AppColors.yellow);
    c.drawPath(
      star,
      Paint()
        ..color = AppColors.yellowDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    // confetti
    _circle(c, 14, 16, 2.6, AppColors.blue);
    _circle(c, 22, 6, 2.0, AppColors.red);
    _circle(c, 70, 5, 2.0, AppColors.purple);
    c.save();
    c.translate(10, 28);
    c.rotate(0.5);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -1.5, 6, 3), const Radius.circular(1.5)),
      Paint()..color = AppColors.orange,
    );
    c.restore();
  }

  // ---------------- characters ----------------

  /// Rafiq — the wise owl: tufts, big eye discs, wings, little feet.
  void _paintOwl(Canvas c, _Palette p) {
    // ear tufts (behind body)
    _triangle(c, const Offset(28, 20), const Offset(40, 22),
        const Offset(33, 6), p.dark,
        rounded: true);
    _triangle(c, const Offset(60, 22), const Offset(72, 20),
        const Offset(67, 6), p.dark,
        rounded: true);
    // body
    _ellipse(c, 50, 56, 37, 38, p.body);
    // wings
    _ellipse(c, 17, 60, 9, 16, p.dark);
    _ellipse(c, 83, 60, 9, 16, p.dark);
    // belly
    _ellipse(c, 50, 73, 21, 17, p.light);
    // big owl eye discs
    _circle(c, 38, 45, 13.5, Colors.white);
    _circle(c, 62, 45, 13.5, Colors.white);
    _eye(c, 38, 45, 9, mood);
    _eye(c, 62, 45, 9, mood);
    _brows(c, mood, p.dark,
        left: const Offset(35, 27.5), right: const Offset(65, 27.5));
    _beak(c, mood, 50, 56, p.accent);
    // feet
    _ellipse(c, 42, 93.5, 4.5, 3, p.accent);
    _ellipse(c, 58, 93.5, 4.5, 3, p.accent);
  }

  /// Farah — the chirpy chick: single crest feather, round body.
  void _paintChick(Canvas c, _Palette p) {
    // crest feather
    final crest = Path()
      ..moveTo(50, 22)
      ..quadraticBezierTo(46, 6, 58, 4)
      ..quadraticBezierTo(55, 12, 56, 22)
      ..close();
    c.drawPath(
      crest,
      Paint()
        ..color = p.dark
        ..strokeJoin = StrokeJoin.round,
    );
    // body
    _circle(c, 50, 58, 36, p.body);
    // wings
    _ellipse(c, 16, 62, 8, 13, p.dark);
    _ellipse(c, 84, 62, 8, 13, p.dark);
    // belly
    _ellipse(c, 50, 73, 18, 14, p.light);
    // face
    _circle(c, 39, 48, 11, Colors.white);
    _circle(c, 61, 48, 11, Colors.white);
    _eye(c, 39, 48, 7.5, mood);
    _eye(c, 61, 48, 7.5, mood);
    _brows(c, mood, p.dark,
        left: const Offset(36, 33), right: const Offset(64, 33));
    _beak(c, mood, 50, 57, p.accent);
    // feet
    _ellipse(c, 42, 93.5, 4, 2.8, p.dark);
    _ellipse(c, 58, 93.5, 4, 2.8, p.dark);
  }

  /// Nur — the night cat: pointed ears, whiskers, curling tail.
  void _paintCat(Canvas c, _Palette p) {
    // tail (behind body)
    final tail = Path()
      ..moveTo(80, 78)
      ..quadraticBezierTo(97, 72, 93, 52);
    c.drawPath(
      tail,
      Paint()
        ..color = p.dark
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // ears with inner triangles
    _triangle(c, const Offset(24, 26), const Offset(44, 26),
        const Offset(29, 8), p.body,
        rounded: true);
    _triangle(c, const Offset(56, 26), const Offset(76, 26),
        const Offset(71, 8), p.body,
        rounded: true);
    _triangle(c, const Offset(30, 22), const Offset(40, 22),
        const Offset(32, 13), p.light);
    _triangle(c, const Offset(60, 22), const Offset(70, 22),
        const Offset(68, 13), p.light);
    // body
    _ellipse(c, 50, 58, 34, 35, p.body);
    // belly + muzzle patch
    _ellipse(c, 50, 75, 18, 12, p.light);
    _ellipse(c, 50, 63, 15, 10.5, p.light);
    // face
    _circle(c, 38, 47, 10, Colors.white);
    _circle(c, 62, 47, 10, Colors.white);
    _eye(c, 38, 47, 6.8, mood);
    _eye(c, 62, 47, 6.8, mood);
    _brows(c, mood, p.dark,
        left: const Offset(35, 33), right: const Offset(65, 33));
    _muzzle(c, mood, const Offset(50, 59), p.accent);
    // whiskers
    final whisker = Paint()
      ..color = p.dark
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final dy in [-2.5, 0.0, 2.5]) {
      c.drawLine(Offset(30, 60 + dy), Offset(19, 57 + dy * 1.6), whisker);
      c.drawLine(Offset(70, 60 + dy), Offset(81, 57 + dy * 1.6), whisker);
    }
  }

  /// Zayd — the path fox: big ears, white muzzle, sly default brows.
  void _paintFox(Canvas c, _Palette p) {
    // tail with light tip (behind body)
    final tail = Path()
      ..moveTo(80, 80)
      ..quadraticBezierTo(98, 70, 92, 50);
    c.drawPath(
      tail,
      Paint()
        ..color = p.dark
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    _circle(c, 92, 50, 4.5, p.light);
    // big ears with dark inner
    _triangle(c, const Offset(20, 30), const Offset(44, 28),
        const Offset(26, 6), p.body,
        rounded: true);
    _triangle(c, const Offset(56, 28), const Offset(80, 30),
        const Offset(74, 6), p.body,
        rounded: true);
    _triangle(c, const Offset(27, 25), const Offset(39, 24),
        const Offset(29, 13), p.dark);
    _triangle(c, const Offset(61, 24), const Offset(73, 25),
        const Offset(71, 13), p.dark);
    // body
    _ellipse(c, 50, 58, 34, 35, p.body);
    // belly + white muzzle
    _ellipse(c, 50, 76, 16, 12, p.light);
    final muzzle = Path()
      ..moveTo(37, 58)
      ..quadraticBezierTo(50, 54, 63, 58)
      ..quadraticBezierTo(60, 72, 50, 73)
      ..quadraticBezierTo(40, 72, 37, 58)
      ..close();
    c.drawPath(muzzle, Paint()..color = p.light);
    // face
    _circle(c, 38, 46, 10, Colors.white);
    _circle(c, 62, 46, 10, Colors.white);
    _eye(c, 38, 46, 6.8, mood);
    _eye(c, 62, 46, 6.8, mood);
    _brows(c, mood, p.dark,
        left: const Offset(35, 32.5), right: const Offset(65, 32.5));
    _muzzle(c, mood, const Offset(50, 60), p.accent, w: 11);
  }

  /// Salma — the calm bunny: long ears with light inner, blush cheeks.
  void _paintBunny(Canvas c, _Palette p) {
    // long ears with inner
    for (final dx in [-11.0, 11.0]) {
      final ear = RRect.fromRectAndCorners(
        Rect.fromLTWH(50 + dx - 5.5, 2, 11, 32),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      c.drawRRect(ear, Paint()..color = p.body);
      c.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(50 + dx - 2.8, 6, 5.6, 22),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
          bottomLeft: const Radius.circular(2),
          bottomRight: const Radius.circular(2),
        ),
        Paint()..color = p.light,
      );
    }
    // body
    _ellipse(c, 50, 60, 33, 34, p.body);
    // belly
    _ellipse(c, 50, 76, 17, 13, p.light);
    // face
    _circle(c, 39, 50, 10, Colors.white);
    _circle(c, 61, 50, 10, Colors.white);
    _eye(c, 39, 50, 6.8, mood);
    _eye(c, 61, 50, 6.8, mood);
    _brows(c, mood, p.dark,
        left: const Offset(36, 36.5), right: const Offset(64, 36.5));
    // blush
    _circle(c, 29, 60, 3.2, Colors.white.withValues(alpha: .35));
    _circle(c, 71, 60, 3.2, Colors.white.withValues(alpha: .35));
    _muzzle(c, mood, const Offset(50, 62), p.accent, w: 11);
  }

  @override
  bool shouldRepaint(covariant _CompanionPainter old) =>
      old.characterId != characterId || old.mood != mood;
}

/// Companion + speech bubble. The text comes from MascotEngine lines.
/// Entrance: gentle scale+fade (skipped when [animate] is false so
/// reduce-motion settings can disable it).
class MascotBubble extends StatelessWidget {
  final String characterId;
  final MascotMood mood;
  final String text;
  final double size;
  final bool animate;

  /// v4.5: set false when a large companion is already visible next to the
  /// bubble (result screens) — renders the bubble text only.
  final bool showAvatar;

  const MascotBubble({
    super.key,
    required this.characterId,
    required this.mood,
    required this.text,
    this.size = 96,
    this.animate = true,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar) ...[
          Mascot(size: size, mood: mood, characterId: characterId),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border.all(color: context.line, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: context.line,
                        offset: const Offset(0, 3),
                        blurRadius: 0),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: context.bodyText,
                  ),
                ),
              ),
              // bubble tail pointing at the companion
              Positioned(
                top: 2,
                left: -5,
                child: Transform.rotate(
                  angle: 3.14159 / 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: context.card,
                      border: Border(
                        left: BorderSide(color: context.line, width: 2),
                        top: BorderSide(color: context.line, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!animate) return body;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child)),
      child: body,
    );
  }
}
