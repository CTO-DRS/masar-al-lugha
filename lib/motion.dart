// Motion catalog for Masar Al-Lugha (v5.15, plan feature F3.4).
//
// ONE place for every animated transition in the app: fixed durations and
// curves, each with a name that says when to use it. Screens stopped
// inventing their own timings (they had — a dozen scattered Duration
// literals before this catalog) and pick from here instead.
//
// Reduce-motion contract: every catalog entry resolves to ZERO duration
// when the learner's reduce-motion preference is on, so callers never
// branch on the preference themselves — they ask the catalog. That keeps
// the "animations collapse to instant" invariant in exactly one file.
//
// The catalog is a thin Flutter dependency (Curves only) and greppable:
// the quarterly review asserts no custom transition Durations outside this
// file.

import 'package:flutter/animation.dart';

class MotionDurations {
  final Duration fast;
  final Duration standard;
  final Duration celebratory;

  const MotionDurations._({
    required this.fast,
    required this.standard,
    required this.celebratory,
  });

  /// Full-motion profile.
  static const MotionDurations full = MotionDurations._(
    fast: Duration(milliseconds: 120),
    standard: Duration(milliseconds: 200),
    celebratory: Duration(milliseconds: 350),
  );

  /// Reduce-motion profile: everything collapses to instant.
  static const MotionDurations instant = MotionDurations._(
    fast: Duration.zero,
    standard: Duration.zero,
    celebratory: Duration.zero,
  );
}

class MotionCurves {
  static const Curve out = Curves.easeOutCubic;
  static const Curve inOut = Curves.easeInOut;
  static const Curve spring = Curves.easeOutBack;
  const MotionCurves._();
}

/// The single entry point screens use:
///   Motion.durations(st.reduceMotion).standard — zero under reduce-motion.
///   Motion.curveOut                            — the one standard curve.
///
/// (Import-free of Flutter beyond Curves; the bool parameter keeps the
/// catalog trivially unit-testable.)
class Motion {
  Motion._();

  static MotionDurations durations(bool reduceMotion) =>
      reduceMotion ? MotionDurations.instant : MotionDurations.full;

  static const Curve curveOut = MotionCurves.out;
  static const Curve curveInOut = MotionCurves.inOut;
  static const Curve curveSpring = MotionCurves.spring;
}
