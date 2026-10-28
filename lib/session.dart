// Session orchestrator for Masar Al-Lugha (v5.12, plan feature F2.3;
// v5.18 Phase-2 Batch B3 refines the WEAK segment).
//
// One place that answers the daily question "what should this session
// contain, in which order, and why?" — composed from data the app already
// tracks (FSRS due dates, mistake counts, the daily new-card budget).
//
// Design rules (explainable by design, deterministic — no shuffle):
//   1. REVIEWS first: cards the schedule says are due now, most overdue
//      first; ties break by lowest stability (shakiest memory first).
//   2. WEAK second: seen-but-not-due words the learner has missed before
//      (wordMistakes > 0) AND whose memory is still genuinely weak —
//      v5.18: a live remediation target OR a mastery score under 60.
//      A single mistake from weeks ago on an otherwise-healthy card no
//      longer pollutes the segment (it was never "weak" since).
//      Most-missed first — extra contact without disturbing the schedule.
//   3. NEW last: unseen words from completed lessons, capped by the
//      remaining daily new-card budget (audit H3 keeps its teeth).
// Each segment is capped so a session stays finishable. The caller gets
// labeled segments, so the UI can show WHY each part of the queue exists.
//
// The engine is Flutter-free and unit-tested (test/session_test.dart).
import 'dart:math' as math;

import 'mastery.dart';
import 'models.dart';

/// One labeled slice of a session plan.
class SessionSegment {
  /// Stable l10n key: 'segReview' | 'segWeak' | 'segNew'.
  final String key;

  /// Ordered words of this segment (never empty — empty segments are
  /// dropped by the planner).
  final List<Vocab> vocab;

  const SessionSegment(this.key, this.vocab);
}

class SessionPlan {
  final List<SessionSegment> segments;

  const SessionPlan(this.segments);

  /// Flat queue in planned order: reviews → weak → new.
  List<Vocab> get queue =>
      segments.expand((s) => s.vocab).toList(growable: false);

  int countOf(String key) =>
      segments.where((s) => s.key == key).fold(0, (n, s) => n + s.vocab.length);

  int get reviewCount => countOf('segReview');
  int get weakCount => countOf('segWeak');
  int get newCount => countOf('segNew');

  bool get isEmpty => segments.isEmpty;
}

class SessionPlanner {
  SessionPlanner._();

  /// Default segment caps — a "smart session" fits in a few minutes.
  static const int reviewCap = 30;
  static const int weakCap = 8;
  static const int newCap = 10;

  /// Builds a session plan from [pool] (the vocab of lessons the learner
  /// already completed — the same "earned" pool the Cards tab uses).
  ///
  /// [newBudget] is the caller's remaining daily new-card allowance
  /// (AppState.newCardsRemainingToday); the planner never exceeds it.
  /// [remediationIds] is the live 7-day remediation window (vocab ids) —
  /// v5.18 (Batch B3): its members stay in the weak segment even when
  /// their mastery score has already recovered.
  /// [random] is accepted for interface parity but UNUSED: the plan is
  /// deterministic so tests and learners can always explain the order.
  static SessionPlan plan({
    required List<Vocab> pool,
    required Map<String, CardData> cards,
    required Map<String, int> wordMistakes,
    required int newBudget,
    Set<String> remediationIds = const {},
    int reviewCap = reviewCap,
    int weakCap = weakCap,
    int newCap = newCap,
    DateTime? now,
    math.Random? random,
  }) {
    final n = now ?? DateTime.now();
    final nowMs = n.millisecondsSinceEpoch;

    final due = <Vocab>[];
    final weak = <Vocab>[];
    final fresh = <Vocab>[];

    for (final v in pool) {
      final c = cards[v.id];
      if (c == null || c.reps == 0) {
        fresh.add(v); // unseen but earned — course order preserved
      } else if (c.dueEpochMs <= nowMs) {
        due.add(v);
      } else if ((wordMistakes[v.id] ?? 0) > 0 &&
          _isWeak(v.id, c, remediationIds, n)) {
        weak.add(v);
      }
    }

    // Reviews: most overdue first; ties → lowest stability first.
    due.sort((a, b) {
      final ca = cards[a.id]!, cb = cards[b.id]!;
      final byDue = ca.dueEpochMs.compareTo(cb.dueEpochMs);
      if (byDue != 0) return byDue;
      return ca.stability.compareTo(cb.stability);
    });

    // Weak: most-missed first; ties → lowest stability first.
    weak.sort((a, b) {
      final ma = wordMistakes[a.id] ?? 0, mb = wordMistakes[b.id] ?? 0;
      final byMisses = mb.compareTo(ma); // descending
      if (byMisses != 0) return byMisses;
      return (cards[a.id]!.stability).compareTo(cards[b.id]!.stability);
    });

    final segments = <SessionSegment>[];
    final cappedDue = due.take(reviewCap.clamp(0, 50)).toList();
    if (cappedDue.isNotEmpty) {
      segments.add(SessionSegment('segReview', cappedDue));
    }

    final cappedWeak = weak.take(weakCap.clamp(0, 20)).toList();
    if (cappedWeak.isNotEmpty) {
      segments.add(SessionSegment('segWeak', cappedWeak));
    }

    final budget = newBudget.clamp(0, newCap.clamp(0, 50));
    final cappedNew = fresh.take(budget).toList();
    if (cappedNew.isNotEmpty) segments.add(SessionSegment('segNew', cappedNew));

    return SessionPlan(segments);
  }

  /// v5.18 (Batch B3): the weakness test for a missed, not-due card — a
  /// live remediation target, or a mastery score still under 60. Both
  /// signals come from data the app already tracks; a card that recovered
  /// (score >= 60, not lapsing anymore) leaves the segment on its own.
  static bool _isWeak(
      String vocabId, CardData c, Set<String> remediationIds, DateTime n) {
    if (remediationIds.contains(vocabId)) return true;
    return Mastery.wordScore(c, now: n) < 60;
  }
}
