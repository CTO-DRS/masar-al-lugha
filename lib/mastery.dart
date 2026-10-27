// Mastery model for Masar Al-Lugha (v5.12, plan feature F2.1).
//
// One explainable 0..100 mastery score per word, derived ONLY from the
// FSRS memory states the scheduler already maintains — the same philosophy
// as lib/insights.dart and lib/records.dart: every number comes from data
// that is already tracked, with the rule documented next to it. No network,
// no accounts, no black boxes.
//
// The score answers one question honestly: "how likely is this word to be
// part of long-term memory today?" It is an ESTIMATE, never a certificate —
// the UI copy says so.
//
// The engine is Flutter-free and unit-tested (test/mastery_test.dart).
import 'dart:math' as math;

import 'models.dart';
import 'srs.dart';

class Mastery {
  Mastery._();

  // ---- score weights (sum to 100) ----
  /// Long-term memory strength: FSRS stability on a log scale. A card that
  /// survives 60 days without lapsing fills this term completely.
  static const double stabilityWeight = 60;

  /// Short-term readiness: the current retrievability R(t, S) from the
  /// forgetting curve — how much of the memory is available right now.
  static const double retentionWeight = 25;

  /// Track record: the fraction of past reviews that were recalls
  /// (not lapses). 15 points of earned trust.
  static const double performanceWeight = 15;

  /// Stability (days) that saturates the stability term.
  static const double stabilitySaturatingDays = 60;

  /// A card still in the `learning` state has not graduated to the review
  /// schedule — it is by definition not long-term memory yet, so the score
  /// is capped here (also matches the band threshold story below).
  static const double learningCap = 55;

  /// Score at or above this = mastered band.
  static const double masteredThreshold = 75;

  // ================= per-word score =================

  /// Mastery score for one card, 0..100. A null card (never seen) scores 0.
  ///
  /// Rule (explainable by design):
  ///   score = 60 · ln(1+S) / ln(1+60)   stability term, clamped 0..1
  ///         + 25 · R(t, S)              current retrievability
  ///         + 15 · (reps − lapses)/reps recall track record
  ///   learning-state cards are capped at 55; unseen cards score 0.
  static double wordScore(CardData? card, {DateTime? now}) {
    if (card == null || card.reps <= 0) return 0;
    final n = now ?? DateTime.now();

    // Stability term: log scale so early growth is visible (S=1d → ~0.15,
    // S=6d → ~0.46, S=21d → ~0.71, S=60d → 1.0 of the 60 points).
    final s = card.stability > 0 ? card.stability : 0.1;
    final stabilityTerm = stabilityWeight *
        (math.log(1 + s) / math.log(1 + stabilitySaturatingDays))
            .clamp(0.0, 1.0);

    // Retention term: the scheduler's own forgetting curve (pure static
    // read — Srs.retrievability never mutates the card).
    final r = Srs.retrievability(card.stability, card.lastReviewEpochMs, n);
    final retentionTerm = retentionWeight * r.clamp(0.0, 1.0);

    // Performance term: lifetime recall ratio for this word.
    final trackRecord = ((card.reps - card.lapses) / card.reps).clamp(0.0, 1.0);
    final performanceTerm = performanceWeight * trackRecord;

    var score = stabilityTerm + retentionTerm + performanceTerm;
    if (card.state == 'learning') score = math.min(score, learningCap);
    return score.clamp(0.0, 100.0).toDouble();
  }

  // ================= bands =================

  /// Four honest bands. The engine returns a stable [key]; the UI maps
  /// key -> localized label + color (same pattern as lib/records.dart).
  static String bandKey(double score) {
    if (score < 25) return 'masteryNew';
    if (score < 50) return 'masteryEmerging';
    if (score < masteredThreshold) return 'masteryStrong';
    return 'masteryMastered';
  }

  // ================= aggregates =================

  /// Average mastery across a vocab list (unseen words count as 0, so a
  /// half-learned course never shows 100%).
  static double averageScore(List<Vocab> vocab, Map<String, CardData> cards,
      {DateTime? now}) {
    if (vocab.isEmpty) return 0;
    var sum = 0.0;
    for (final v in vocab) {
      sum += wordScore(cards[v.id], now: now);
    }
    return (sum / vocab.length).clamp(0.0, 100.0);
  }

  /// One-row summary for dashboards: average, mastered count, total.
  static MasterySummary summary(List<Vocab> vocab, Map<String, CardData> cards,
      {DateTime? now}) {
    var mastered = 0;
    var sum = 0.0;
    for (final v in vocab) {
      final s = wordScore(cards[v.id], now: now);
      sum += s;
      if (s >= masteredThreshold) mastered++;
    }
    final avg = vocab.isEmpty ? 0.0 : (sum / vocab.length).clamp(0.0, 100.0);
    return MasterySummary(
      average: avg,
      mastered: mastered,
      total: vocab.length,
    );
  }

  /// The [limit] lowest-mastery SEEN words (score > 0 required — a word the
  /// learner never met is the lessons' job, not a practice target), worst
  /// first. Ties break by vocab id so the output is deterministic.
  static List<(String, double)> weakestSeen(
    List<Vocab> vocab,
    Map<String, CardData> cards,
    int limit, {
    DateTime? now,
  }) {
    final scored = <(String, double)>[];
    for (final v in vocab) {
      final s = wordScore(cards[v.id], now: now);
      if (s <= 0) continue;
      scored.add((v.id, s));
    }
    scored.sort((a, b) {
      final byScore = a.$2.compareTo(b.$2);
      if (byScore != 0) return byScore;
      return a.$1.compareTo(b.$1);
    });
    return scored.take(limit).toList();
  }
}

/// Mastery summary row for dashboards.
class MasterySummary {
  final double average;
  final int mastered;
  final int total;

  const MasterySummary({
    required this.average,
    required this.mastered,
    required this.total,
  });

  int get averagePct => average.round();
}
