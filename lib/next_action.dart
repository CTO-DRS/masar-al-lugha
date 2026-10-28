// Next-best-action selector for Masar Al-Lugha (v5.15, plan feature F3.2).
//
// The learn path grew rich: today's lesson, quick review, grammar/reading/
// conversation skills, remediation rounds, path setup. A rich path risks
// becoming a DASHBOARD — the learner's first question ("what do I do
// now?") deserves ONE answered card, not five competing banners.
//
// This engine answers that question exactly once, with an EXPLAINED,
// rule-based priority ladder over data the app already tracks. No ML, no
// shuffle, no hidden scoring: each rule names its reason, and the card
// shows that reason to the learner.
//
// Priority ladder (documented in the plan §F3.2, adapted honestly; v5.18
// Phase-2 Batch B2 adds the weak-words lane between review and momentum):
//   1. REMEDIATION  — words forgotten on 2+ distinct days this week wait
//      for nobody; repairing a live trap beats adding new load.
//   2. REVIEW       — when the due backlog is REAL (>= threshold), FSRS
//      health comes before new content.
//   3. WEAK WORDS   — no live traps and no real backlog, but a CLUSTER of
//      seen words sits in the low-mastery band (v5.18): consolidation
//      beats new load once the cluster is big enough to matter. Counted
//      from Mastery.weakestSeen — the same data the Cards tab shows.
//   4. UNIT FINISH  — momentum: exactly one lesson left in the current
//      unit. (The plan's original 3rd lane was "unit story"; micro-
//      stories are plan-Q1 F1.5 and are NOT shipped yet, so this wave
//      substitutes the same "close the loop" energy with a unit-
//      completion nudge. Honest adaptation, recorded in ROADMAP.)
//   5. LESSON       — the default lane: the next unlocked, incomplete
//      lesson. Always available, so the card can never dead-end
//      (safe fallback: if even this is impossible, the caller shows the
//      all-done state — the engine still returns 'lesson' and lets the
//      caller resolve the empty case).
//
// The engine is Flutter-free and unit-tested (test/next_action_test.dart).

/// One recommended next step, with the WHY attached.
class NextAction {
  /// Stable machine key: 'remediation' | 'review' | 'unitFinish' |
  /// 'lesson'. l10n keys derive from it ('nba<Kind>Title' / 'nba<Kind>Why').
  final String kind;

  /// Title placeholder values, e.g. {'n': '12'} for the review count.
  final Map<String, String> params;

  /// Flat index into course.allLessons for lesson/unitFinish actions.
  final int? lessonFlat;

  const NextAction(this.kind, {this.params = const {}, this.lessonFlat});

  String get titleKey => 'nba${kind[0].toUpperCase()}${kind.substring(1)}Title';
  String get whyKey => 'nba${kind[0].toUpperCase()}${kind.substring(1)}Why';
}

class NextBestAction {
  NextBestAction._();

  /// The due backlog only hijacks the card when it is REAL. Below this,
  /// reviews stay available through their own banner/quick lane and the
  /// card keeps pointing forward.
  static const int reviewDueThreshold = 8;

  /// v5.18 (Batch B2): the weak-words lane fires when at least this many
  /// SEEN words sit in the low-mastery band. Below it the cluster is one
  /// bad day, not a pattern — the default lesson lane keeps pointing
  /// forward instead of nagging.
  static const int weakWordsThreshold = 4;

  /// Plain-data snapshot the picker reasons over. Built by [inputs] from
  /// real app state; kept as a record so every rule is unit-testable
  /// without pumping a single widget.
  static NextAction pick({
    required int dueCount,
    required int remediationCount,
    required int remainingInCurrentUnit,
    required bool hasNextLesson,
    int? nextLessonFlat,
    int weakCount = 0,
  }) {
    // 1. A live trap is repaired first.
    if (remediationCount > 0) {
      return NextAction('remediation', params: {'n': '$remediationCount'});
    }
    // 2. A real due backlog protects memory health.
    if (dueCount >= reviewDueThreshold) {
      return NextAction('review', params: {'n': '$dueCount'});
    }
    // 3. A real cluster of low-mastery words earns a consolidation lane.
    if (weakCount >= weakWordsThreshold) {
      return NextAction('weakWords', params: {'n': '$weakCount'});
    }
    // 4. Momentum: the current unit is one lesson from done.
    if (remainingInCurrentUnit == 1 &&
        hasNextLesson &&
        nextLessonFlat != null) {
      return NextAction('unitFinish', lessonFlat: nextLessonFlat);
    }
    // 5. The always-available default (also the safe fallback).
    return NextAction('lesson',
        lessonFlat: nextLessonFlat, params: {'n': '$dueCount'});
  }

  /// Snapshot from real state. All arguments are plain data so this stays
  /// Flutter-free: [dueCount] from Insights.dueWithinDays(cards, 0),
  /// [remediationCount] = st.remediationVocab(course).length,
  /// [weakCount] = seen words in the low-mastery band (Mastery.weakestSeen
  /// below the emerging band), [remainingInCurrentUnit] = lessons left in
  /// the unit of the next incomplete lesson (0 when there is no next
  /// lesson), [nextLessonFlat] = flat index of the first unlocked
  /// incomplete lesson (null when none).
  static NextAction fromCounts({
    required int dueCount,
    required int remediationCount,
    required int remainingInCurrentUnit,
    int? nextLessonFlat,
    int weakCount = 0,
  }) {
    return pick(
      dueCount: dueCount,
      remediationCount: remediationCount,
      remainingInCurrentUnit: remainingInCurrentUnit,
      hasNextLesson: nextLessonFlat != null,
      nextLessonFlat: nextLessonFlat,
      weakCount: weakCount,
    );
  }
}
