// Spaced-repetition scheduler for Masar Al-Lugha.
//
// HONEST DESCRIPTION (v5.3): this is a **real FSRS-4.5 scheduler** — per-card
// difficulty (D) and stability (S) memory states, the power-law forgetting
// curve R(t,S) = (1 + FACTOR·t/S)^DECAY, the standard stability update rules
// (recall / forget) with the official default weights, and a **target
// retention dial** (default 90%) that turns stability into scheduled
// intervals. What it does NOT include: a per-user parameter optimizer — the
// 17 weights below are the published FSRS-4.5 defaults, not trained on this
// learner's log. UI copy and docs therefore say "FSRS" for scheduling and
// stay silent about optimization.
//
// Migration: cards saved by v5.2 and earlier carry only the SM-2-lite fields
// (ease/ivl/due/reps/lapses/state). [m[Srs.migrateLegacy] derives FSRS states from
// them once, without moving `due`, `reps`, `lapses`, `state`, `ease` or the
// interval — zero progress loss. The old fields stay in the payload forever
// (older app versions simply ignore the new additive keys `d`, `s`, `last`).
//
// The engine is Flutter-free and unit-tested (see test/srs_test.dart).
import 'dart:math' as math;

import 'models.dart';

class Srs {
  static const int again = 0;
  static const int hard = 1;
  static const int good = 2;
  static const int easy = 3;

  static const int dayMs = 86400000;
  static const int tenMinMs = 10 * 60 * 1000;

  // ---- FSRS-4.5 constants ----
  /// Target retrievability when a card's interval equals its stability.
  static const double defaultRetention = 0.90;
  static const double minRetention = 0.70;
  static const double maxRetention = 0.98;
  static const int minIntervalDays = 1;
  static const int maxIntervalDays = 365;

  /// DECAY = -0.5, FACTOR = 0.9^(1/DECAY) - 1 = 19/81, so that R(t=S) = 0.9.
  static const double _decay = -0.5;
  static const double _factor = 19.0 / 81.0;

  /// Official FSRS-4.5 default weights (no per-user optimizer shipped).
  static const List<double> w = [
    0.4872, 1.4003, 3.7145, 13.8206, // w0..w3  initial stability per rating
    5.1618, 1.2298, //                 w4..w5  initial difficulty
    0.8975, //                        w6      difficulty delta
    0.031, //                         w7      difficulty mean reversion
    1.6474, 0.1367, 1.0461, //        w8..w10 recall stability
    2.1072, 0.0793, 0.3246, 1.587, // w11..w14 post-lapse stability
    0.2272, //                        w15     hard penalty
    2.8755, //                        w16     easy bonus
  ];

  // ================= forgetting curve =================

  /// Probability the learner still recalls the card, given its stability and
  /// the epoch-ms timestamp of its last review. New/unseen state → 0.
  static double retrievability(
      double stability, int lastEpochMs, DateTime now) {
    if (stability <= 0 || lastEpochMs <= 0) return 0;
    final elapsedDays = (now.millisecondsSinceEpoch - lastEpochMs) / dayMs;
    if (elapsedDays <= 0) return 1;
    final r =
        math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();
    return r.clamp(0.0, 1.0);
  }

  /// Interval in days that decays retrievability from 1 to [retention].
  static int nextInterval(double stability, double retention) {
    final ivl = stability / _factor * (math.pow(retention, 1 / _decay) - 1.0);
    return ivl.round().clamp(minIntervalDays, maxIntervalDays);
  }

  // ================= memory-state transitions =================

  /// Initial stability for a rating (our 0..3 → FSRS 1..4).
  static double _initStability(int q4) =>
      (w[q4 - 1]).clamp(0.1, 36500.0).toDouble();

  /// Initial difficulty for a rating, clamped to [1,10].
  static double _initDifficulty(int q4) =>
      (w[4] - (q4 - 3) * w[5]).clamp(1.0, 10.0).toDouble();

  /// Mean reversion of difficulty toward the easy-init anchor (FSRS-4.5).
  static double _nextDifficulty(double d, int q4) {
    final drifted = d - w[6] * (q4 - 3);
    final reverted = w[7] * _initDifficulty(4) + (1 - w[7]) * drifted;
    return reverted.clamp(1.0, 10.0).toDouble();
  }

  /// Stability growth after a successful recall (hard/easy multiply in the
  /// w15 penalty / w16 bonus). At R=1 (same-day) the growth term is 0 —
  /// FSRS-4.5 deliberately grants no same-day stability.
  static double _nextRecallStability(double d, double s, double r, int q4) {
    final hardPenalty = q4 == 2 ? w[15] : 1.0;
    final easyBonus = q4 == 4 ? w[16] : 1.0;
    final growth = math.exp(w[8]) *
        (11 - d) *
        math.pow(s, -w[9]) *
        (math.exp((1 - r) * w[10]) - 1) *
        hardPenalty *
        easyBonus;
    return s * (1 + growth);
  }

  /// Stability after a lapse, from the difficulty and pre-lapse retrievability.
  static double _nextForgetStability(double d, double s, double r) {
    return w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1, w[13]) - 1) *
        math.exp((1 - r) * w[14]);
  }

  // ================= migration =================

  /// Derives FSRS states from a v5.2-or-earlier card **once**. Documented
  /// approximations (the lite scheduler kept no memory of review times):
  ///  - stability ≈ the interval the old scheduler committed to (a review
  ///    card's `ivl` IS its stability at the default 90% target by
  ///    construction); learning/short cards default to the "good" anchor;
  ///  - difficulty ≈ D0(good) shifted by how far ease sits from its 2.5
  ///    default (0.1 ease ≈ 0.2 D);
  ///  - last review ≈ scheduling time (`due - interval`), so late cards keep
  ///    a genuinely lower retrievability at their next rating.
  /// Nothing else moves: `due`, `ivl`, `reps`, `lapses`, `state`, `ease` are
  /// preserved byte-for-byte, so no due review is lost or reshuffled.
  static void migrateLegacy(CardData c, {DateTime? now}) {
    if (c.stability > 0 || c.reps <= 0) return; // nothing to migrate
    final n = now ?? DateTime.now();
    final double s;
    if (c.state == 'review' && c.intervalDays >= 1) {
      s = c.intervalDays.toDouble();
    } else {
      s = w[2]; // learning / interval-less review → "good" anchor
    }
    c.stability = s.clamp(0.1, 36500.0).toDouble();
    c.difficulty =
        (_initDifficulty(3) + (2.5 - c.ease) * 2.0).clamp(1.0, 10.0).toDouble();
    var last = c.dueEpochMs -
        (c.intervalDays >= 1 ? c.intervalDays * dayMs : tenMinMs);
    if (last > n.millisecondsSinceEpoch) last = n.millisecondsSinceEpoch;
    c.lastReviewEpochMs = last;
  }

  // ================= rating =================

  /// Apply a review rating [q] (0..3) to a card, mutating it in place.
  /// [requestRetention] is the learner's target retention (0.70..0.98);
  /// lower targets schedule longer intervals.
  static void rate(CardData c, int q,
      {DateTime? now, double requestRetention = defaultRetention}) {
    final n = now ?? DateTime.now();
    final target =
        requestRetention.clamp(minRetention, maxRetention).toDouble();
    final q4 = q + 1; // FSRS rating 1..4

    // One-time migration of pre-FSRS cards, then fall through.
    if (c.stability <= 0) migrateLegacy(c, now: n);

    c.reps += 1;
    if (q == again) c.lapses += 1;

    // Brand-new card: initialize the memory states from this first rating.
    if (c.stability <= 0) {
      c.stability = _initStability(q4);
      c.difficulty = _initDifficulty(q4);
      c.lastReviewEpochMs = n.millisecondsSinceEpoch;
      if (q == again || q == hard) {
        // keep the familiar 10-minute first-show step
        c.state = 'learning';
        c.intervalDays = 0;
        c.dueEpochMs = n.millisecondsSinceEpoch + tenMinMs;
      } else {
        _graduate(c, n, target);
      }
      return;
    }

    // Card already carries FSRS state (rated before, or just migrated).
    final d0 = c.difficulty;
    final s0 = c.stability;
    final r = retrievability(s0, c.lastReviewEpochMs, n);
    c.difficulty = _nextDifficulty(d0, q4);
    c.stability = (q == again
            ? _nextForgetStability(d0, s0, r)
            : _nextRecallStability(d0, s0, r, q4))
        .clamp(0.1, 36500.0)
        .toDouble();
    c.lastReviewEpochMs = n.millisecondsSinceEpoch;
    if (q == again) {
      c.state = 'learning';
      c.intervalDays = 0;
      c.dueEpochMs = n.millisecondsSinceEpoch + tenMinMs;
    } else {
      _graduate(c, n, target);
    }
  }

  /// Moves a card with fresh memory states into the review schedule at the
  /// requested retention.
  static void _graduate(CardData c, DateTime n, double target) {
    final ivl = nextInterval(c.stability, target);
    c.intervalDays = ivl;
    c.state = 'review';
    c.dueEpochMs = n.millisecondsSinceEpoch + ivl * dayMs;
  }

  /// Human friendly hint for the next interval of a card given a rating.
  /// Computed on a scratch copy so the card is never mutated, which makes
  /// the hint provably identical to what [rate] would schedule.
  static String hintFor(CardData c, int q,
      {DateTime? now, double requestRetention = defaultRetention}) {
    final scratch = CardData(
      ease: c.ease,
      intervalDays: c.intervalDays,
      dueEpochMs: c.dueEpochMs,
      reps: c.reps,
      lapses: c.lapses,
      state: c.state,
      difficulty: c.difficulty,
      stability: c.stability,
      lastReviewEpochMs: c.lastReviewEpochMs,
    );
    rate(scratch, q, now: now, requestRetention: requestRetention);
    if (scratch.intervalDays <= 0) return '10m';
    return '${scratch.intervalDays}d';
  }
}
