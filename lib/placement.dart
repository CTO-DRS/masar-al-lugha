// Placement quiz (v4.0, audit M9): lets returning learners skip what they
// already know. Domain logic is Flutter-free and unit-testable; the UI
// screen lives in screens/placement_screen.dart.
// v4.12: the result is also linked to the learner's LevelTier automatically
// (recommendedTier → AppState.setPathTier), so the learn-path plan adapts
// without the learner re-picking their level by hand.
// v5.5: PlacementProber turns the fixed 4×3 probe into a true ADAPTIVE
// staircase — the probe depth rises after correct answers and falls after
// wrong ones (18 questions instead of 12), and the result gains a
// per-CEFR-level breakdown. The old fixed-probe API below stays untouched
// (sample/answerKey/recommendedFlatIndex/recommendedTier/recommendedDomain)
// and the prober FEEDS it: checkpoints built from the asked items keep the
// same consecutive-pass semantics where they still apply.
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

  /// v5.5: skip position for ADAPTIVE probe order. Walks checkpoints by
  /// depth and keeps the END of the last SOLID one — a checkpoint whose
  /// words were ALL correct (the same per-checkpoint bar the fixed probe
  /// applied via the consecutive-prefix rule). Unlike the prefix walk,
  /// a later failure does not erase an earlier solid band: the staircase
  /// may sample a hard unit between easy ones, and the skip should still
  /// honor what was proven. Nothing proven → 0 (start from the beginning).
  static int recommendedFlatIndexSolid(Course course,
      List<PlacementCheckpoint> checkpoints, Map<String, bool> results) {
    var skipTo = 0;
    for (final cp in checkpoints) {
      final allCorrect = cp.wordIds.isNotEmpty &&
          cp.wordIds.every((id) => results[id] == true);
      if (allCorrect) skipTo = flatEndOfUnit(course, cp.unitIndex);
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

  /// v4.13: suggests a [PathDomain] from the words the learner answered
  /// CORRECTLY — every correct word votes for the domain of the unit its
  /// checkpoint sampled ([PathEngine.domainOfUnit] over the unit title);
  /// the majority wins and ties break in catalog (enum) order, so the
  /// result is fully deterministic.
  ///
  /// Unlike [recommendedTier] (a prefix rule for the skip), this reads ALL
  /// correct answers — including partial ones inside a failed checkpoint —
  /// because the suggestion describes demonstrated strengths, not a skip
  /// position. Returns null when nothing was answered correctly or the
  /// answers fall outside the sampled set: no signal, no guess.
  static PathDomain? recommendedDomain(Course course,
      List<PlacementCheckpoint> checkpoints, Map<String, bool> results) {
    // word id -> sampled unit index (last write wins on the degenerate
    // small-course case where two checkpoints hit the same unit).
    final unitOf = <String, int>{};
    for (final cp in checkpoints) {
      for (final id in cp.wordIds) {
        unitOf[id] = cp.unitIndex;
      }
    }
    final votes = <PathDomain, int>{};
    for (final entry in results.entries) {
      if (entry.value != true) continue;
      final unit = unitOf[entry.key];
      if (unit == null || unit < 0 || unit >= course.units.length) continue;
      final d = PathEngine.domainOfUnit(course.units[unit]);
      votes[d] = (votes[d] ?? 0) + 1;
    }
    PathDomain? best;
    var bestCount = 0;
    // Iterating the enum in order makes ties resolve to the earliest
    // catalog domain — deterministic without extra tiebreak state.
    for (final d in PathDomain.values) {
      final c = votes[d] ?? 0;
      if (c > bestCount) {
        best = d;
        bestCount = c;
      }
    }
    return best;
  }
}

// ================= v5.5: adaptive placement prober =================

/// One adaptive probe question: a word sampled at the prober's current
/// depth, prebuilt with its correct Arabic meaning and 3 unique distractor
/// meanings from the same course.
class PlacementItem {
  final int unitIndex;
  final String wordId;
  final String target;
  final String answer;
  final List<String> options;
  final String cefr;
  const PlacementItem(this.unitIndex, this.wordId, this.target, this.answer,
      this.options, this.cefr);
}

/// Per-CEFR-level outcome of an adaptive session.
class PlacementLevelStat {
  final String cefr;
  final int asked;
  final int correct;
  const PlacementLevelStat(this.cefr, this.asked, this.correct);
  double get ratio => asked == 0 ? 0 : correct / asked;
}

/// A true adaptive placement probe (v5.5).
///
/// Mechanics (documented, deterministic given the same rng seed):
///  - the probe tracks a fractional DEPTH BAND into the course
///    (0.0 = first unit … 1.0 = last unit) and starts at 0.30 — past the
///    trivially-easy start, before the mid-course wall;
///  - every item is a single (non-sentence) word sampled from the nearest
///    unit at/around the band that still has unused candidates;
///  - a CORRECT answer raises the band by [_step], a WRONG one lowers it
///    by [_step] — the staircase converges on the learner's ceiling and
///    spends its questions where they are informative (the old fixed
///    probe spent 3 questions per band no matter what);
///  - exactly [questions] items are asked (default 18), never repeating a
///    word id.
///
/// The result feeds the EXISTING v4.12/v4.13 link: [checkpoints] keeps
/// asked items grouped by unit in depth order so [Placement.recommendedDomain]
/// works unchanged, [flatSkip] walks those checkpoints with a "solid band"
/// rule suited to adaptive order, and [tier] maps the final band onto the
/// LevelTier bands the path planner understands.
class PlacementProber {
  /// Band step per answer (12% of course depth).
  static const double _step = 0.12;
  static const double _minBand = 0.02;
  static const double _maxBand = 0.98;
  static const int defaultQuestions = 18;

  final Course course;
  final int questions;
  final Random _rng;

  final List<PlacementItem> asked = [];
  final Map<String, bool> results = {};

  // unit index -> unused candidate words (id/target/translation)
  late final Map<int, List<_ProbeWord>> _pool;
  late final List<int> _unitOrder; // ascending unit indices with candidates
  double _band = 0.30;
  bool _finished = false;

  PlacementProber._(this.course, this.questions, this._rng);

  static PlacementProber create(Course course,
      {int questions = defaultQuestions, Random? rng}) {
    final p =
        PlacementProber._(course, questions.clamp(4, 40), rng ?? Random());
    p._init();
    return p;
  }

  void _init() {
    _pool = {};
    for (var i = 0; i < course.units.length; i++) {
      final words = course.units[i].lessons
          .expand((l) => l.vocab)
          .where((v) => !v.isSentence)
          .map((v) => _ProbeWord(v.id, v.target, v.translationAr))
          .toList();
      if (words.isNotEmpty) _pool[i] = words;
    }
    _unitOrder = _pool.keys.toList()..sort();
  }

  /// Fractional depth of the last asked item (0..1). Drives [tier].
  double get finalBand => _band.clamp(0.0, 1.0);

  bool get isFinished => _finished || asked.length >= questions;

  /// Number of items still to be asked.
  int get remaining => questions - asked.length;

  /// The next adaptive question, or null when the probe is complete.
  PlacementItem? next() {
    if (isFinished) {
      _finished = true;
      return null;
    }
    final unitIdx = _pickUnit();
    if (unitIdx == null) {
      _finished = true;
      return null;
    }
    final words = _pool[unitIdx]!;
    final w = words.removeLast();
    if (words.isEmpty) _pool.remove(unitIdx);
    // 4 options: correct meaning + 3 unique distractors course-wide.
    final distractors = <String>{};
    final all = course.allVocab.map((v) => v.translationAr).toList()
      ..shuffle(_rng);
    for (final t in all) {
      if (t == w.ar || distractors.contains(t)) continue;
      distractors.add(t);
      if (distractors.length == 3) break;
    }
    final options = [w.ar, ...distractors]..shuffle(_rng);
    final item = PlacementItem(
        unitIdx, w.id, w.target, w.ar, options, course.units[unitIdx].cefr);
    asked.add(item);
    return item;
  }

  /// Records the answer to the last [next] item and moves the staircase.
  void answer(bool correct) {
    final item = asked.last;
    results[item.wordId] = correct;
    _band += correct ? _step : -_step;
    _band = _band.clamp(_minBand, _maxBand);
  }

  int? _pickUnit() {
    if (_unitOrder.isEmpty) return null;
    final target = _band * (course.units.length - 1);
    // nearest unit (with remaining candidates) to the target depth
    int best = _unitOrder.first;
    var bestDist = double.infinity;
    for (final i in _unitOrder) {
      final d = (i - target).abs();
      if (d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    return best;
  }

  /// Asked items grouped by unit, ascending — feeds the unchanged
  /// v4.12/v4.13 helpers (domain votes, flat-index walks).
  List<PlacementCheckpoint> get checkpoints {
    final byUnit = <int, List<String>>{};
    for (final item in asked) {
      byUnit.putIfAbsent(item.unitIndex, () => []).add(item.wordId);
    }
    final units = byUnit.keys.toList()..sort();
    return [for (final u in units) PlacementCheckpoint(u, byUnit[u]!)];
  }

  /// Skip position for adaptive order: walk checkpoints by depth and keep
  /// the END of the last SOLID one (all its words correct — the same
  /// per-checkpoint rule the fixed probe used). Nothing proven → 0.
  int flatSkip() =>
      Placement.recommendedFlatIndexSolid(course, checkpoints, results);

  /// Tier from the final staircase band: ready-for band, not a certificate.
  /// ≤0.33 → beginner, ≤0.70 → intermediate, above → expert.
  LevelTier get tier {
    final b = finalBand;
    if (b <= 0.33) return LevelTier.beginner;
    if (b <= 0.70) return LevelTier.intermediate;
    return LevelTier.expert;
  }

  /// v4.13 domain suggestion over the SAME asked set (unchanged rule).
  PathDomain? recommendedDomain() =>
      Placement.recommendedDomain(course, checkpoints, results);

  /// Detailed outcome per CEFR level of the sampled units, in course order.
  List<PlacementLevelStat> levelBreakdown() {
    final askedBy = <String, List<bool>>{};
    for (final item in asked) {
      askedBy
          .putIfAbsent(item.cefr, () => [])
          .add(results[item.wordId] ?? false);
    }
    final order = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final out = <PlacementLevelStat>[];
    for (final lvl in order) {
      final marks = askedBy[lvl];
      if (marks == null || marks.isEmpty) continue;
      out.add(
          PlacementLevelStat(lvl, marks.length, marks.where((m) => m).length));
    }
    return out;
  }
}

class _ProbeWord {
  final String id;
  final String target;
  final String ar;
  const _ProbeWord(this.id, this.target, this.ar);
}
