// Rafiq & Friends — living human companions (v4.9, v4.10).
//
// v4.9: the cast is now drawn as HUMAN characters (a coach, classmates,
// mentors) instead of animals — and everything LIVES:
//   * idle breathing/bobbing + a natural blink cycle
//   * celebration hop with raised arms when a milestone lands
//   * a talking mouth synced to the speech-bubble typewriter
//   * tap any companion → it waves at you
// v4.10: the companions speak on their OWN, all the time:
//   * a fresh spoken line triggers a body gesture automatically — no tap
//     needed (encouragement and motivation visibly move the character)
//   * LiveCompanion wraps the bubble with an ambient chatter timer (a new
//     line every 24–36 s), greets on open, replies on every tap, pauses
//     in the background and greets again on resume
// Art is still layered vector paths on a normalized 100x100 canvas — no
// images, no emoji glyphs, no new dependencies, identical on every device.
// Motion respects MediaQuery.disableAnimations (reduce motion) and the
// [Mascot.animated] flag; widget tests pump fixed durations instead of
// pumpAndSettle because idle motion intentionally never settles.
//
// Personality data comes from lib/mascot.dart (engine: cast, unlocks,
// lines, typewriter math). This file only renders:
//   * Mascot         — an animated human body reacting to mood/talking/taps
//   * MascotBubble   — companion + speech bubble with a typewriter reveal
//   * LiveCompanion  — the always-talking wrapper (greeting → ambient loop)
//
// Back-compat: `MascotMood` is re-exported from the engine, and Mascot
// defaults to `rafiq`, so every pre-4.5 call site keeps compiling.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../mascot.dart' show MascotEngine, MascotFacts, MascotMood;
import '../theme.dart';

export '../mascot.dart' show MascotMood;

// ---------------- per-character looks (v4.9 human crew) ----------------

class _Look {
  final Color skin;
  final Color hair; // males only (females wear a hijab)
  final Color top; // shirt / tee
  final Color topDark; // hem, collar, sleeve shade
  final Color pants;
  final Color? hijab; // null → male hairstyle
  final bool glasses;
  final bool blush;

  const _Look({
    required this.skin,
    required this.hair,
    required this.top,
    required this.topDark,
    required this.pants,
    this.hijab,
    this.glasses = false,
    this.blush = false,
  });
}

const _hairBlack = Color(0xFF2B2B33);
const _denim = Color(0xFF4E6372);
const _purpleDeep = Color(0xFF9C4DCC);

_Look _lookFor(String id) {
  switch (id) {
    case 'farah':
      // Farah — cheerful classmate, orange hijab, blue top.
      return const _Look(
        skin: Color(0xFFF4C79B),
        hair: _hairBlack,
        top: AppColors.blue,
        topDark: AppColors.blueDark,
        pants: AppColors.ink,
        hijab: AppColors.orange,
        blush: true,
      );
    case 'nur':
      // Nur — calm night friend, blue hijab, deep teal top.
      return const _Look(
        skin: Color(0xFFE3AC7E),
        hair: _hairBlack,
        top: AppColors.blueDark,
        topDark: Color(0xFF1479A8),
        pants: AppColors.ink,
        hijab: AppColors.blue,
        blush: true,
      );
    case 'zayd':
      // Zayd — the path expert, yellow tee, curly black hair.
      return const _Look(
        skin: Color(0xFFD9A06B),
        hair: _hairBlack,
        top: AppColors.yellow,
        topDark: AppColors.yellowDark,
        pants: _denim,
      );
    case 'salma':
      // Salma — patient mentor, purple hijab, deep purple top.
      return const _Look(
        skin: Color(0xFFC98F5D),
        hair: _hairBlack,
        top: _purpleDeep,
        topDark: Color(0xFF7E3AA6),
        pants: AppColors.ink,
        hijab: AppColors.purple,
        blush: true,
      );
    default:
      // Rafiq — your personal coach, green polo, glasses.
      return const _Look(
        skin: Color(0xFFEAB98C),
        hair: _hairBlack,
        top: AppColors.green,
        topDark: AppColors.greenDark,
        pants: _denim,
        glasses: true,
      );
  }
}

// ---------------- pose (what the animator feeds the painter) ----------------

class _Pose {
  final double bobY; // vertical offset of the whole figure
  final bool blink; // true → eyes closed this frame
  final double mouth; // 0..1 talk openness
  final double armL; // radians, 0 = hanging down, + raises outward
  final double armR; // radians (negative raises the right arm outward)

  const _Pose({
    this.bobY = 0,
    this.blink = false,
    this.mouth = 0,
    this.armL = 0,
    this.armR = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is _Pose &&
      other.bobY == bobY &&
      other.blink == blink &&
      other.mouth == mouth &&
      other.armL == armL &&
      other.armR == armR;

  @override
  int get hashCode => Object.hash(bobY, blink, mouth, armL, armR);
}

// ---------------- the widget ----------------

class Mascot extends StatefulWidget {
  final double size;
  final MascotMood mood;
  final String characterId;

  /// v4.9: set false to freeze all motion (static vector art). Motion is
  /// additionally disabled automatically under reduce-motion settings.
  final bool animated;

  /// v4.9: while true the mouth opens/closes ("talking"). The bubble drives
  /// this while its typewriter is revealing the line.
  final ValueListenable<bool>? talking;

  /// v4.9: extra tap handler. Tapping ALWAYS plays a wave animation.
  final VoidCallback? onTap;

  const Mascot({
    super.key,
    this.size = 120,
    this.mood = MascotMood.happy,
    this.characterId = 'rafiq',
    this.animated = true,
    this.talking,
    this.onTap,
  });

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  );

  late final AnimationController _talk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  late final AnimationController _action = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _live = false;

  /// Starts/stops the ambient controllers to match [live]. Controllers that
  /// never run also keep pumpAndSettle terminating (tests, reduce motion).
  void _setLive(bool live) {
    _live = live;
    void run(AnimationController c) {
      if (live && !c.isAnimating) {
        c.repeat();
      } else if (!live && c.isAnimating) {
        c.stop();
      }
    }

    run(_bob);
    run(_blink);
    run(_talk);
    if (!live && _action.isAnimating) _action.stop();
  }

  @override
  void initState() {
    super.initState();
    // v4.10: a fresh spoken line moves the body automatically — the
    // character gestures while it talks, no tap required.
    widget.talking?.addListener(_onTalking);
    if (widget.animated && widget.mood == MascotMood.celebrate) {
      _action.forward();
    }
  }

  /// v4.10: edge-triggered on false→true (a new line starts typing).
  void _onTalking() {
    if (widget.talking?.value != true) return;
    if (!_live) return;
    if (widget.mood == MascotMood.celebrate) {
      return; // celebration owns the arms
    }
    _action.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant Mascot old) {
    super.didUpdateWidget(old);
    if (old.talking != widget.talking) {
      old.talking?.removeListener(_onTalking);
      widget.talking?.addListener(_onTalking);
    }
    if (old.mood != widget.mood) {
      if (widget.mood == MascotMood.celebrate && _live) {
        _action.forward(from: 0);
      } else if (_action.isAnimating) {
        _action.stop();
      }
    }
  }

  void _poke() {
    if (_live && widget.mood != MascotMood.celebrate) {
      _action.forward(from: 0);
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    widget.talking?.removeListener(_onTalking);
    for (final c in [_bob, _blink, _talk, _action]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.animated && !MediaQuery.of(context).disableAnimations;
    _setLive(live);
    return GestureDetector(
      onTap: _poke,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _blink, _talk, _action]),
        builder: (context, _) {
          final bob = live ? math.sin(_bob.value * 2 * math.pi) * 1.2 : 0.0;
          final phase = _blink.value;
          final blink = live && phase > 0.90 && phase < 0.945;
          final speaking = widget.talking?.value ?? false;
          final mouth = live && speaking
              ? math.sin(_talk.value * 2 * math.pi) * 0.5 + 0.5
              : 0.0;
          var armL = 0.0;
          var armR = 0.0;
          var hop = 0.0;
          if (widget.mood == MascotMood.celebrate) {
            // Arms stay up while celebrating; the one-shot action adds a
            // springy raise + a little hop.
            final a = _action.isAnimating
                ? Curves.easeOutBack.transform(_action.value)
                : 1.0;
            final lift = a.clamp(0.0, 1.35);
            armL = 2.2 * lift;
            armR = -2.2 * lift;
            hop = _action.isAnimating
                ? -math.sin(_action.value * math.pi) * 4.5
                : 0.0;
          } else if (live && _action.isAnimating) {
            // Wave: the right arm swings while the action plays.
            final w = _action.value;
            armR = -2.0 + 0.55 * math.sin(w * math.pi * 3);
          }
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _HumanPainter(
              widget.characterId,
              widget.mood,
              _Pose(
                bobY: bob + hop,
                blink: blink,
                mouth: mouth,
                armL: armL,
                armR: armR,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- painter ----------------

class _HumanPainter extends CustomPainter {
  final String characterId;
  final MascotMood mood;
  final _Pose pose;

  _HumanPainter(this.characterId, this.mood, this.pose);

  @override
  void paint(Canvas canvas, Size size) {
    final lk = _lookFor(characterId);
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    _groundShadow(canvas);
    canvas.translate(0, pose.bobY);

    _legsAndShoes(canvas, lk);
    _arm(canvas, lk, const Offset(32.5, 63), pose.armL);
    _arm(canvas, lk, const Offset(67.5, 63), pose.armR);
    _torso(canvas, lk);
    _head(canvas, lk);

    if (mood == MascotMood.celebrate) _celebration(canvas);

    canvas.restore();
  }

  // ---------------- body parts ----------------

  void _groundShadow(Canvas c) {
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 96.5), width: 44, height: 6),
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

  Paint _stroke(Color color, double w) => Paint()
    ..color = color
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _legsAndShoes(Canvas c, _Look lk) {
    final legs = RRect.fromRectAndRadius(
      const Rect.fromLTWH(36.5, 74, 11.5, 16),
      const Radius.circular(4),
    );
    final legs2 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(52, 74, 11.5, 16),
      const Radius.circular(4),
    );
    c.drawRRect(legs, Paint()..color = lk.pants);
    c.drawRRect(legs2, Paint()..color = lk.pants);
    _ellipse(c, 42, 91.5, 6.2, 2.8, AppColors.ink);
    _ellipse(c, 58, 91.5, 6.2, 2.8, AppColors.ink);
  }

  void _torso(Canvas c, _Look lk) {
    final torso = RRect.fromRectAndCorners(
      const Rect.fromLTWH(31, 55, 38, 29),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: const Radius.circular(7),
      bottomRight: const Radius.circular(7),
    );
    c.drawRRect(torso, Paint()..color = lk.top);
    // hem band
    c.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(31, 79, 38, 5),
        bottomLeft: const Radius.circular(7),
        bottomRight: const Radius.circular(7),
      ),
      Paint()..color = lk.topDark,
    );
    // collar notch
    final collar = Path()
      ..moveTo(45.5, 55)
      ..lineTo(50, 60.5)
      ..lineTo(54.5, 55);
    c.drawPath(collar, _stroke(lk.topDark, 2));
  }

  /// Arm capsule pivoting at the shoulder. angle 0 hangs down; positive
  /// raises the LEFT arm outward-up, negative raises the RIGHT one.
  void _arm(Canvas c, _Look lk, Offset shoulder, double angle) {
    c.save();
    c.translate(shoulder.dx, shoulder.dy);
    c.rotate(angle);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.4, -2, 6.8, 20),
        const Radius.circular(3.4),
      ),
      Paint()..color = lk.top,
    );
    c.drawCircle(const Offset(0, 18), 3.1, Paint()..color = lk.skin);
    c.restore();
  }

  void _head(Canvas c, _Look lk) {
    final female = lk.hijab != null;

    // ears stick out from behind the head (males only)
    if (!female) {
      _circle(c, 28.8, 37, 3.4, lk.skin);
      _circle(c, 71.2, 37, 3.4, lk.skin);
    }

    _circle(c, 50, 35, 21, lk.skin);

    if (female) {
      // hijab: outer shell behind the face + drape under the chin.
      _circle(c, 50, 33.5, 23, lk.hijab!);
      _ellipse(c, 50, 58.5, 20, 8, lk.hijab!);
      _circle(c, 50, 39.5, 16.8, lk.skin);
      // fold hint
      final fold = Path()
        ..moveTo(33.5, 30)
        ..quadraticBezierTo(50, 20.5, 66.5, 30);
      c.drawPath(fold, _stroke(Colors.white.withValues(alpha: .25), 2.2));
    } else {
      // hair cap via the two-circle trick, then character fringe details.
      _circle(c, 50, 30.5, 20.5, lk.hair);
      _circle(c, 50, 38.5, 17.6, lk.skin);
      if (characterId == 'zayd') {
        _circle(c, 36, 18, 8.2, lk.hair);
        _circle(c, 50, 13.5, 9.4, lk.hair);
        _circle(c, 64, 18, 8.2, lk.hair);
      }
    }

    _face(c, lk);
  }

  void _face(Canvas c, _Look lk) {
    const eyeL = Offset(42.5, 38.5);
    const eyeR = Offset(57.5, 38.5);
    final sad = mood == MascotMood.sad;

    // eyes
    if (pose.blink) {
      c.drawLine(eyeL.translate(-2.6, 0), eyeL.translate(2.6, 0),
          _stroke(AppColors.ink, 2));
      c.drawLine(eyeR.translate(-2.6, 0), eyeR.translate(2.6, 0),
          _stroke(AppColors.ink, 2));
    } else {
      final dy = sad ? 1.1 : 0.0;
      _circle(c, eyeL.dx, eyeL.dy + dy, 3.1, AppColors.ink);
      _circle(c, eyeR.dx, eyeR.dy + dy, 3.1, AppColors.ink);
      _circle(c, eyeL.dx - 1.0, eyeL.dy + dy - 1.0, 1.0, Colors.white);
      _circle(c, eyeR.dx - 1.0, eyeR.dy + dy - 1.0, 1.0, Colors.white);
    }

    // brows: worried when sad, raised when celebrating
    final browPaint = _stroke(lk.hijab != null ? lk.topDark : lk.hair, 2.2);
    final raise = mood == MascotMood.celebrate ? 2.4 : 0.0;
    final tilt = sad ? 2.0 : 0.0;
    c.drawLine(Offset(eyeL.dx - 3.4, 32.6 - raise),
        Offset(eyeL.dx + 3.2, 31.6 - raise + tilt), browPaint);
    c.drawLine(Offset(eyeR.dx - 3.2, 31.6 - raise - tilt),
        Offset(eyeR.dx + 3.4, 32.6 - raise), browPaint);

    // glasses (Rafiq)
    if (lk.glasses) {
      final gp = _stroke(AppColors.ink.withValues(alpha: .8), 1.5);
      c.drawCircle(eyeL, 5.4, gp);
      c.drawCircle(eyeR, 5.4, gp);
      c.drawLine(
          Offset(eyeL.dx + 5.4, eyeL.dy), Offset(eyeR.dx - 5.4, eyeR.dy), gp);
    }

    // blush
    if (lk.blush) {
      _circle(c, 35.2, 44.5, 2.8, AppColors.red.withValues(alpha: .22));
      _circle(c, 64.8, 44.5, 2.8, AppColors.red.withValues(alpha: .22));
    }

    _mouth(c);
  }

  void _mouth(Canvas c) {
    const mx = 50.0;
    const my = 46.0;
    // Talking overrides the mood mouth: an open, animating mouth.
    if (pose.mouth > 0.08) {
      _ellipse(c, mx, my, 3.0 + pose.mouth * 1.9, 0.9 + pose.mouth * 3.4,
          AppColors.ink);
      return;
    }
    final p = _stroke(AppColors.ink, 2.2);
    switch (mood) {
      case MascotMood.sad:
        final mouth = Path()
          ..moveTo(mx - 5, my + 3.5)
          ..quadraticBezierTo(mx, my - 1, mx + 5, my + 3.5);
        c.drawPath(mouth, p);
        break;
      case MascotMood.celebrate:
        final mouth = Path()
          ..moveTo(mx - 5.5, my - 0.5)
          ..quadraticBezierTo(mx, my + 6.5, mx + 5.5, my - 0.5)
          ..close();
        c.drawPath(mouth, Paint()..color = AppColors.ink);
        break;
      case MascotMood.neutral:
        c.drawLine(Offset(mx - 3.5, my + 2), Offset(mx + 3.5, my + 2), p);
        break;
      case MascotMood.happy:
        final mouth = Path()
          ..moveTo(mx - 5, my)
          ..quadraticBezierTo(mx, my + 5, mx + 5, my);
        c.drawPath(mouth, p);
        break;
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

  @override
  bool shouldRepaint(covariant _HumanPainter old) =>
      old.characterId != characterId || old.mood != mood || old.pose != pose;
}

/// Companion + speech bubble with a typewriter reveal (v4.9).
///
/// While the text is being revealed the mouth of the companion animates:
/// when [showAvatar] is true the built-in avatar is synced automatically;
/// otherwise pass the same [talking] notifier to the nearby [Mascot].
/// Tapping the bubble reveals the whole line at once. The entrance
/// scale+fade is skipped when [animate] is false (reduce motion) — which
/// also prints the full text instantly.
class MascotBubble extends StatefulWidget {
  final String characterId;
  final MascotMood mood;
  final String text;
  final double size;
  final bool animate;
  final bool showAvatar;
  final ValueNotifier<bool>? talking;
  final VoidCallback? onTap;

  const MascotBubble({
    super.key,
    required this.characterId,
    required this.mood,
    required this.text,
    this.size = 96,
    this.animate = true,
    this.showAvatar = true,
    this.talking,
    this.onTap,
  });

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _type = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )
    ..addListener(_tick)
    ..addStatusListener(_onStatus);

  late String _shown = _reveal(0);

  bool get _typing => _shown.length < widget.text.length;

  void _pushTalking(bool v) => widget.talking?.value = v;

  String _reveal(int elapsedMs) => widget.text.substring(
      0, MascotEngine.revealedChars(widget.text, elapsedMs: elapsedMs));

  void _tick() {
    final dur = _type.duration ?? Duration.zero;
    final elapsed = (_type.value * dur.inMilliseconds).round();
    final next = _reveal(elapsed);
    if (next != _shown) setState(() => _shown = next);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      setState(() => _shown = widget.text);
      _pushTalking(false);
    }
  }

  void _configure() {
    _type.stop();
    if (!widget.animate || widget.text.isEmpty) {
      _shown = widget.text;
      _pushTalking(false);
      return;
    }
    _type.duration = MascotEngine.revealDuration(widget.text);
    _shown = _reveal(0);
    _pushTalking(true);
    _type.forward();
  }

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant MascotBubble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.animate != widget.animate) {
      _configure();
    }
  }

  void _tap() {
    if (_typing) {
      _type.stop();
      setState(() => _shown = widget.text);
      _pushTalking(false);
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _type.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showAvatar) ...[
          Mascot(
            size: widget.size,
            mood: widget.mood,
            characterId: widget.characterId,
            talking: widget.talking,
            // v4.10: tapping the avatar also speaks a fresh line, so the
            // whole companion (not just the text) answers interaction.
            onTap: widget.onTap,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
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
                    _shown,
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
        ),
      ],
    );
    if (!widget.animate) return body;
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

// ---------------------------------------------------------------------------
// v4.10 — LiveCompanion: the companion that never goes quiet.
//
// Wraps [MascotBubble] with an autonomous conversation loop:
//   * opening line — the time-of-day greeting, or [openingText] provided
//     by the caller (e.g. the profile card's comeback moment);
//   * ambient chatter — every 24–36 s (MascotEngine.ambientIntervalMs,
//     deterministic per turn) a fresh motivation line is spoken WITHOUT
//     any user action — the "talks all the time" contract;
//   * interaction — every tap (avatar or bubble) replies with a fresh
//     encouragement line and restarts the quiet window;
//   * lifecycle-aware — chatter pauses while the app is backgrounded and
//     the companion speaks a welcome-back line on resume.
// Reduce motion only disables the typewriter/entrance animation; the
// companion still talks, because rotating text is content, not motion.
// The timer is cancelled on dispose, so widget tests can unmount the
// tree to avoid pending-timer failures.
// ---------------------------------------------------------------------------
class LiveCompanion extends StatefulWidget {
  final String characterId;
  final MascotMood mood;
  final double size;
  final MascotFacts facts;
  final String locale;
  final bool reduceMotion;

  /// Stable per-session salt (e.g. DateTime.now().day) mixed into line
  /// rotation so different screens and days differ.
  final int salt;

  /// Overrides the time-of-day greeting as the first spoken line.
  final String? openingText;

  const LiveCompanion({
    super.key,
    required this.characterId,
    required this.facts,
    required this.locale,
    this.mood = MascotMood.happy,
    this.size = 56,
    this.reduceMotion = false,
    this.salt = 0,
    this.openingText,
  });

  @override
  State<LiveCompanion> createState() => _LiveCompanionState();
}

enum _SpeakKind { opening, ambient, tap }

class _LiveCompanionState extends State<LiveCompanion>
    with WidgetsBindingObserver {
  final ValueNotifier<bool> _talking = ValueNotifier(false);
  Timer? _chatter;
  _SpeakKind _kind = _SpeakKind.opening;
  int _turns = 0;

  String get _line {
    final w = widget;
    switch (_kind) {
      case _SpeakKind.opening:
        return w.openingText ??
            MascotEngine.greetingLine(
              hour: DateTime.now().hour,
              locale: w.locale,
              salt: w.salt,
            );
      case _SpeakKind.ambient:
        return MascotEngine.ambientLine(w.facts, w.locale,
            salt: _turns + w.salt);
      case _SpeakKind.tap:
        return MascotEngine.tapLine(w.facts, w.locale, salt: _turns + w.salt);
    }
  }

  /// (Re)arms the ambient timer. Each turn uses a different interval so
  /// several live companions on screen never speak in unison.
  void _arm() {
    _chatter?.cancel();
    _chatter = Timer(
      Duration(
          milliseconds: MascotEngine.ambientIntervalMs(_turns + widget.salt)),
      _speakAmbient,
    );
  }

  void _speakAmbient() {
    if (!mounted) return;
    setState(() {
      _turns++;
      _kind = _SpeakKind.ambient;
    });
    _arm();
  }

  void _speakTap() {
    if (!mounted) return;
    setState(() {
      _turns++;
      _kind = _SpeakKind.tap;
    });
    _arm(); // a tap restarts the quiet window
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  @override
  void didUpdateWidget(covariant LiveCompanion old) {
    super.didUpdateWidget(old);
    // A locale/facts/opening change re-renders the CURRENT kind in the
    // new context instead of waiting for the next tick.
    if (old.locale != widget.locale ||
        old.facts != widget.facts ||
        old.openingText != widget.openingText) {
      setState(() {}); // recompute _line
    }
    _arm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Background pauses the timer; returning deserves a fresh line.
      _speakAmbient();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _chatter?.cancel();
    }
  }

  @override
  void dispose() {
    _chatter?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _talking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MascotBubble(
      characterId: widget.characterId,
      mood: widget.mood,
      text: _line,
      size: widget.size,
      animate: !widget.reduceMotion,
      talking: _talking,
      onTap: _speakTap,
    );
  }
}
