// Placement quiz (v4.0, audit M9): lets returning learners skip what they
// already know. Domain logic is Flutter-free and unit-testable; the UI
// screen lives in screens/placement_screen.dart.
// v4.12: the result is also linked to the learner's LevelTier automatically
// (recommendedTier → AppState.setPathTier), so the learn-path plan adapts
// without the learner re-picking their level by hand.
import 'dart:math';

import 'models.dart';
import 'path.dart';

class PlacementCheckpoint {
  final int unitIndex;
  final List<String> wordIds;
  const PlacementCheckpoint(this.unitIndex, this.wordIds);
}

class Placement {
  /// Samples quiz words across the course depth: [checkpoints] evenly-spaced
  /// units (skipping unit 0 — too easy), [perCheckpoint] distinct single
  /// words each. Checkpoints are returned in depth order so the UI can stop
  /// at the first failed depth.
  static List<PlacementCheckpoint> sample(Course course,
      {int checkpoints = 4, int perCheckpoint = 3, Random? rng}) {
    final units = course.units;
    if (units.isEmpty) return const [];
    final rand = rng ?? Random();
    final out = <PlacementCheckpoint>[];
    for (var c = 0; c < checkpoints; c++) {
      final idx = ((c + 1) * units.length / (checkpoints + 1)).floor();
      final unit = units[idx.clamp(0, units.length - 1)];
      final words = unit.lessons
          .expand((l) => l.vocab)
          .where((v) => !v.isSentence)
          .toList();
      if (words.isEmpty) continue;
      words.shuffle(rand);
      final ids = <String>[];
      for (final w in words) {
        if (ids.length >= perCheckpoint) break;
        if (!ids.contains(w.id)) ids.add(w.id);
      }
      if (ids.isNotEmpty) out.add(PlacementCheckpoint(idx, ids));
    }
    return out;
  }

  /// Maps sampled word ids to their correct translations (options builder).
  static Map<String, String> answerKey(Course course, Iterable<String> ids) {
    final byId = {
      for (final v in course.allVocab) v.id: v.translationAr,
    };
    return {
      for (final id in ids)
        if (byId[id] != null) id: byId[id]!,
    };
  }

  /// Flat index of the LAST lesson of unit [unitIndex].
  static int flatEndOfUnit(Course course, int unitIndex) {
    var n = 0;
    for (var u = 0; u <= unitIndex.clamp(0, course.units.length - 1); u++) {
      n += course.units[u].lessons.length;
    }
    return n - 1;
  }

  /// Given checkpoints and per-word correctness, recommends the flat lesson
  /// index the learner may start from:
  ///  - keep advancing while a checkpoint's words are ALL correct;
  ///  - each passed checkpoint unlocks through the END of its unit
  ///    (conservative: never skips into untested territory);
  ///  - the first failing checkpoint stops the skip.
  static int recommendedFlatIndex(Course course,
      List<PlacementCheckpoint> checkpoints, Map<String, bool> results) {
    var skipTo = 0;
    for (final cp in checkpoints) {
      final allCorrect = cp.wordIds.isNotEmpty &&
          cp.wordIds.every((id) => results[id] == true);
      if (!allCorrect) break;
      skipTo = flatEndOfUnit(course, cp.unitIndex);
    }
    return skipTo.clamp(0, course.allLessons.length - 1);
  }

  /// v4.12: maps the placement outcome to a learner [LevelTier] using the
  /// SAME consecutive-pass semantics as [recommendedFlatIndex] — the count
  /// of leading checkpoints whose words were ALL correct decides the tier:
  ///
  ///  - nothing proven (or the first checkpoint failed) → beginner;
  ///  - at least half the checkpoints passed → intermediate;
  ///  - every checkpoint passed → expert.
  ///
  /// This is a "ready-for band" rule: the tier describes the material the
  /// learner is ready to study next, matching how the checkpoints sample
  /// the course depth evenly (unit 0 is never sampled). An empty checkpoint
  /// list degrades safely to beginner instead of over-claiming.
  static LevelTier recommendedTier(
      List<PlacementCheckpoint> checkpoints, Map<String, bool> results) {
    var passed = 0;
    for (final cp in checkpoints) {
      final allCorrect = cp.wordIds.isNotEmpty &&
          cp.wordIds.every((id) => results[id] == true);
      if (!allCorrect) break;
      passed++;
    }
    return tierForPassed(passed, checkpoints.length);
  }

  /// Pure count rule behind [recommendedTier], split out so tests can pin
  /// the thresholds without building checkpoints. A non-positive [total]
  /// (or [passed]) never claims anything above beginner.
  static LevelTier tierForPassed(int passed, int total) {
    if (total <= 0 || passed <= 0) return LevelTier.beginner;
    final frac = passed / total;
    if (frac >= 1.0) return LevelTier.expert;
    if (frac >= 0.5) return LevelTier.intermediate;
    return LevelTier.beginner;
  }
}
