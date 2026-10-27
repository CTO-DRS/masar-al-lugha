// FSRS calibration tests (v5.12, plan feature F2.2).
//
// The report must measure prediction quality honestly: strict sample
// shapes, bounded log, drift verdicts only when the evidence allows.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/calibration.dart';
import 'package:masar_al_lugha/models.dart';

void main() {
  group('recording', () {
    test('addSample stores milli-precision pairs, newest last', () {
      final log = <List<int>>[];
      Calibration.addSample(log, 0.847, true);
      Calibration.addSample(log, 0.212, false);
      expect(log.length, 2);
      expect(log[0], [847, 1]);
      expect(log[1], [212, 0]);
    });

    test('addSample clamps insane inputs instead of storing them raw', () {
      final log = <List<int>>[];
      Calibration.addSample(log, 1.7, true);
      Calibration.addSample(log, -0.3, false);
      Calibration.addSample(log, double.nan, true);
      expect(log, [
        [1000, 1],
        [0, 0],
        [0, 1],
      ]);
    });

    test('the rolling log never exceeds maxSamples', () {
      final log = <List<int>>[];
      for (var i = 0; i < Calibration.maxSamples + 50; i++) {
        Calibration.addSample(log, i % 1000 / 1000, i % 2 == 0);
      }
      expect(log.length, Calibration.maxSamples);
      // Oldest trimmed from the FRONT.
      expect(log.first, [50, 1]); // i=50 was the 51st sample
    });

    test('isPredictable excludes brand-new and legacy cards', () {
      expect(Calibration.isPredictable(CardData()), isFalse, // unseen
          reason: 'no prediction exists before the first rating');
      expect(
          Calibration.isPredictable(CardData(
            reps: 3,
            stability: 4,
            difficulty: 5,
            lastReviewEpochMs: 1,
          )),
          isTrue);
      expect(
          Calibration.isPredictable(CardData(reps: 2)), // legacy, no FSRS
          isFalse);
    });
  });

  group('reporting', () {
    List<List<int>> samples(List<(double, bool)> pairs) =>
        pairs.map((p) => [(p.$1 * 1000).round(), p.$2 ? 1 : 0]).toList();

    test('empty log → need-data verdict and null Brier', () {
      final r = Calibration.report([]);
      expect(r.total, 0);
      expect(r.brier, isNull);
      expect(r.verdictKey, 'calibrationNeedData');
      expect(r.buckets.length, 4);
    });

    test('bucket boundaries: 0-50, 50-70, 70-90, 90-100', () {
      final r = Calibration.report(samples([
        (0.10, true),
        (0.49, false),
        (0.50, true),
        (0.69, false),
        (0.70, true),
        (0.89, true),
        (0.90, false),
        (1.00, true),
      ]));
      expect(r.buckets[0].samples, 2);
      expect(r.buckets[1].samples, 2);
      expect(r.buckets[2].samples, 2);
      expect(r.buckets[3].samples, 2);
      expect(r.total, 8);
    });

    test('actual recall is the honest per-bucket ratio', () {
      final r = Calibration.report(samples([
        (0.2, true),
        (0.3, true),
        (0.4, false),
        (0.1, false),
      ]));
      expect(r.buckets[0].samples, 4);
      expect(r.buckets[0].actualRecall, closeTo(0.5, 0.001));
    });

    test('Brier score is the mean squared error against outcomes', () {
      // r=0.8 recalled → (0.2)² = 0.04; r=0.2 lapsed → (0.2)² = 0.04.
      final r = Calibration.report(samples([
        (0.8, true),
        (0.2, false),
      ]));
      expect(r.brier, closeTo(0.04, 0.0001));
    });

    test('below minVerdictSamples the verdict stays need-data', () {
      final log = samples(
          List.generate(Calibration.minVerdictSamples - 1, (i) => (0.8, true)));
      expect(Calibration.report(log).verdictKey, 'calibrationNeedData');
    });

    test('well-fitting buckets produce the good verdict', () {
      // 30 samples at r≈0.8 with 80% recalled → drift ≈ 0 for that bucket.
      final log = <List<int>>[];
      for (var i = 0; i < 24; i++) {
        log.add([800, i % 5 == 0 ? 0 : 1]); // 80% recalled
      }
      for (var i = 0; i < 6; i++) {
        log.add([950, 1]); // small extra bucket, under minBucketSamples
      }
      final r = Calibration.report(log);
      expect(r.total, 30);
      expect(r.verdictKey, 'calibrationGood');
    });

    test('a measurable bucket off by >10 points flips the verdict to off', () {
      final log = <List<int>>[];
      // Predicted 0.8 but only 50% recalled → drift ≈ -30 points.
      for (var i = 0; i < 20; i++) {
        log.add([800, i % 2 == 0 ? 1 : 0]);
      }
      for (var i = 0; i < 10; i++) {
        log.add([950, 1]);
      }
      expect(Calibration.report(log).verdictKey, 'calibrationOff');
    });

    test('buckets under minBucketSamples never trigger the off verdict', () {
      final log = <List<int>>[];
      // Predicted 0.8, recalled 0% — but only 5 samples in the bucket.
      for (var i = 0; i < 5; i++) {
        log.add([800, 0]);
      }
      // ...plus a healthy, well-fitting volume in a DIFFERENT bucket
      // (predicted 0.95, always recalled → drift +5) to pass the gate.
      for (var i = 0; i < 30; i++) {
        log.add([950, 1]);
      }
      expect(Calibration.report(log).verdictKey, 'calibrationGood');
    });
  });
}
