// Next-lesson warmup for Masar Al-Lugha (v5.15, plan feature F3.4).
//
// Before this wave the lesson plan (its exercises) was assembled inside
// the first build of LessonScreen — the learner TAPPED and then WAITED
// while the generator ran. The generator is pure Dart, but on low-end
// devices the wait was perceptible exactly at the moment of highest
// intent (the tap on "start").
//
// Now the learn path WARMS UP the next lesson's plan in the background
// (via compute() — a real background isolate) as soon as the path screen
// opens. By the time the learner taps, the plan is already in the cache
// and the first round renders immediately.
//
// Honesty rules:
//   - the cache is keyed by (lessonId, mode, cefr, confusion-pairs
//     fingerprint); ANY input mismatch -> recompute synchronously. A warm
//     plan is only ever used when it is provably the same plan.
//   - the isolate seam is injectable ([computeFn]) so widget tests run
//     the same code synchronously and deterministically.
//   - failures are silent by design: warmup is an optimization. If the
//     isolate throws, the lesson screen builds the plan the old way.

import 'package:flutter/foundation.dart';

import 'exercise_gen.dart';
import 'models.dart';

/// Immutable warmup request — everything ExerciseGen.forLesson needs,
/// captured as plain data so it can cross an isolate boundary.
class WarmupRequest {
  final String lessonId;
  final Lesson lesson;
  final LessonMode mode;
  final String cefr;
  final Map<String, int> confusions;

  const WarmupRequest({
    required this.lessonId,
    required this.lesson,
    required this.mode,
    required this.cefr,
    required this.confusions,
  });

  /// A stable fingerprint of ALL inputs: if ANY of these changed since the
  /// warmup, the cached plan is stale and is never used.
  String get fingerprint {
    final pairs = confusions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$lessonId|${mode.name}|$cefr|'
        '${pairs.map((e) => '${e.key}>${e.value}').join(',')}';
  }
}

class LessonWarmup {
  LessonWarmup._();

  /// The plan builder that runs INSIDE the isolate (top-level-like static
  /// — required shape for compute()).
  static List<Exercise> buildPlan(WarmupRequest req) {
    return ExerciseGen.forLesson(
      req.lesson,
      mode: req.mode,
      confusions: req.confusions,
      cefr: req.cefr,
    );
  }

  /// Test seam: defaults to [compute] (a real background isolate). Widget
  /// tests inject a synchronous function so the same code path runs
  /// deterministically under FakeAsync.
  static Future<List<Exercise>> Function(WarmupRequest req) computeFn =
      (req) => compute(buildPlan, req);

  static final Map<String, List<Exercise>> _cache = {};
  static final Set<String> _inflight = {};

  /// Fires and forgets: warms the plan for [req] if not already cached or
  /// already in flight (double-builds are exactly what warmup exists to
  /// prevent). Never throws (warmup failures are silently ignored).
  static void warm(WarmupRequest req) {
    if (_cache.containsKey(req.fingerprint) ||
        _inflight.contains(req.fingerprint)) {
      return;
    }
    // Keep at most one plan per lesson id (plans are big).
    _cache.removeWhere((k, _) => k.startsWith('${req.lessonId}|'));
    _inflight.add(req.fingerprint);
    computeFn(req).then((plan) {
      _inflight.remove(req.fingerprint);
      _cache[req.fingerprint] = plan;
    }).catchError((_) {
      _inflight.remove(req.fingerprint);
      // Warmup is best-effort; the lesson screen recomputes on miss.
    });
  }

  /// Returns the cached plan when the fingerprint matches exactly,
  /// otherwise null (caller builds synchronously).
  static List<Exercise>? take(WarmupRequest req) {
    final plan = _cache[req.fingerprint];
    if (plan != null) _cache.remove(req.fingerprint);
    return plan;
  }

  /// Test hook.
  static void clear() {
    _cache.clear();
    _inflight.clear();
  }

  static bool get hasCachedEntry => _cache.isNotEmpty;
}
