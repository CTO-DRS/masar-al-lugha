// FSRS calibration report for Masar Al-Lugha (v5.12, plan feature F2.2).
//
// The scheduler in lib/srs.dart predicts, for every seen card, the
// probability R that the learner still recalls it. This engine closes the
// loop HONESTLY: whenever a real review happens, it stores the prediction
// and the actual outcome, then reports how well prediction matched reality.
//
// What this is NOT: a parameter optimizer. The 17 FSRS weights stay the
// published defaults — this report only MEASURES how they fit this learner,
// bucket by bucket, with sample counts shown so small numbers never
// masquerade as conclusions. Nothing ever leaves the device.
//
// The engine is Flutter-free and unit-tested (test/calibration_test.dart).
import 'models.dart';

/// One calibration sample, encoded for persistence as `[rMilli, recalled]`:
///   rMilli  — predicted retrievability at review time, 0..1000 (‰ precision)
///   recalled — 1 when the learner actually recalled, 0 when they lapsed
typedef CalibrationSample = List<int>;

/// Bucket boundaries by predicted retrievability (fractions 0..1):
/// [0,50%), [50%,70%), [70%,90%), [90%,100%].
class CalibrationBuckets {
  CalibrationBuckets._();

  static const int count = 4;

  /// Upper bounds (exclusive, last inclusive) of each bucket, in ‰.
  static const List<int> edgesMilli = [500, 700, 900, 1000];
}

/// One report row: predicted range vs what actually happened.
class CalibrationBucket {
  final double predictedFrom; // 0..1
  final double predictedTo; // 0..1
  final int samples;
  final double actualRecall; // 0..1

  const CalibrationBucket({
    required this.predictedFrom,
    required this.predictedTo,
    required this.samples,
    required this.actualRecall,
  });

  /// Difference between what the range promised (its midpoint) and what the
  /// learner actually did, in percentage points. Signed.
  double get driftPct =>
      (actualRecall - (predictedFrom + predictedTo) / 2) * 100;
}

class CalibrationReport {
  final List<CalibrationBucket> buckets;

  /// Brier score over all samples: mean (prediction − outcome)². 0 = perfect,
  /// 1 = worst; 0.25 = always guessing 50/50. Null when no samples exist.
  final double? brier;

  final int total;

  /// Stable l10n key for the verdict line. Rules:
  ///  - fewer than [minVerdictSamples] samples → 'calibrationNeedData'
  ///  - every bucket with >= [minBucketSamples] samples inside ±10 points
  ///    of its promise → 'calibrationGood'
  ///  - otherwise → 'calibrationOff'
  final String verdictKey;

  const CalibrationReport({
    required this.buckets,
    required this.brier,
    required this.total,
    required this.verdictKey,
  });
}

class Calibration {
  Calibration._();

  /// Rolling window size. Bounded by design: 400 samples ≈ 3-4 weeks of
  /// active reviewing, keeps the payload small, and only recent behaviour
  /// is relevant to how the curve fits NOW.
  static const int maxSamples = 400;

  /// A bucket needs this many samples before its drift is meaningful.
  static const int minBucketSamples = 20;

  /// The verdict stays silent (need-data) below this total.
  static const int minVerdictSamples = 30;

  /// Absolute drift (percentage points) a measurable bucket may show before
  /// the verdict flips to 'calibrationOff'.
  static const double toleratedDriftPct = 10;

  // ================= recording =================

  /// Appends one sample to the rolling log, newest LAST (append-only,
  /// front-trimmed to [maxSamples]). Pure list mutation on the caller's
  /// log; validation is deliberately strict — out-of-range predictions are
  /// clamped, never stored raw.
  static void addSample(
    List<CalibrationSample> log,
    double predictedR,
    bool recalled,
  ) {
    final r = (predictedR.isFinite ? predictedR : 0.0).clamp(0.0, 1.0);
    log.add([(r * 1000).round(), recalled ? 1 : 0]);
    if (log.length > maxSamples) {
      log.removeRange(0, log.length - maxSamples);
    }
  }

  /// Whether a sample should be recorded for [card]: only cards that
  /// already carry FSRS memory states AND have been reviewed before have a
  /// meaningful prediction. Brand-new cards are excluded so the report is
  /// never polluted by first-encounter guesses (which are not scheduled
  /// reviews at all).
  static bool isPredictable(CardData card) {
    return card.hasFsrsState && card.reps > 0;
  }

  // ================= reporting =================

  static CalibrationReport report(List<CalibrationSample> log) {
    final counts = List<int>.filled(CalibrationBuckets.count, 0);
    final recalls = List<int>.filled(CalibrationBuckets.count, 0);
    var brierSum = 0.0;
    var total = 0;

    for (final s in log) {
      if (s.length < 2) continue;
      final rMilli = s[0].clamp(0, 1000);
      final recalled = s[1] != 0;
      final b = _bucketIndex(rMilli);
      counts[b] += 1;
      if (recalled) recalls[b] += 1;
      brierSum += _brier(rMilli / 1000, recalled);
      total += 1;
    }

    final buckets = <CalibrationBucket>[];
    var from = 0.0;
    for (var i = 0; i < CalibrationBuckets.count; i++) {
      final to = CalibrationBuckets.edgesMilli[i] / 1000.0;
      final n = counts[i];
      buckets.add(CalibrationBucket(
        predictedFrom: from,
        predictedTo: to,
        samples: n,
        actualRecall: n == 0 ? 0 : recalls[i] / n,
      ));
      from = to;
    }

    var verdict = 'calibrationNeedData';
    if (total >= minVerdictSamples) {
      var off = false;
      for (final b in buckets) {
        if (b.samples < minBucketSamples) continue;
        if (b.driftPct.abs() > toleratedDriftPct) off = true;
      }
      verdict = off ? 'calibrationOff' : 'calibrationGood';
    }

    return CalibrationReport(
      buckets: buckets,
      brier: total == 0 ? null : brierSum / total,
      total: total,
      verdictKey: verdict,
    );
  }

  static int _bucketIndex(int rMilli) {
    for (var i = 0; i < CalibrationBuckets.edgesMilli.length; i++) {
      if (rMilli < CalibrationBuckets.edgesMilli[i] ||
          i == CalibrationBuckets.edgesMilli.length - 1) {
        return i;
      }
    }
    return 0; // unreachable
  }

  static double _brier(double r, bool recalled) {
    final outcome = recalled ? 1.0 : 0.0;
    final d = r - outcome;
    return d * d;
  }
}
