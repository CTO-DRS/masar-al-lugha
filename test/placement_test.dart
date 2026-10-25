// Placement engine tests (v4.0, audit M9).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/path.dart';
import 'package:masar_al_lugha/placement.dart';

Course _course({int unitCount = 8, int lessonsPerUnit = 4}) {
  const ladder = ['A1', 'A1', 'A2', 'A2', 'B1', 'B1', 'B2', 'C1'];
  final units = <Unit>[];
  for (var u = 0; u < unitCount; u++) {
    final lessons = <Lesson>[];
    for (var l = 0; l < lessonsPerUnit; l++) {
      final vocab = <Vocab>[];
      for (var w = 0; w < 4; w++) {
        vocab.add(Vocab(
          id: 'w_${u}_$l$w',
          target: 'word${u}l$l$w',
          translationAr: 'معنى${u}l$l$w',
        ));
      }
      lessons.add(Lesson(
        id: 'l_${u}_$l',
        titleAr: 'درس',
        titleEn: 'L',
        vocab: vocab,
      ));
    }
    units.add(Unit(
      id: 'u$u',
      titleAr: 'وحدة',
      titleEn: 'U',
      colorHex: '58CC02',
      lessons: lessons,
      cefr: ladder[u % ladder.length],
    ));
  }
  return Course(
    id: 'en',
    nameAr: 'إنجليزي',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: units,
  );
}

void main() {
  test('sample produces 4 checkpoints with 3 words each, skipping unit 0', () {
    final c = _course();
    final cps = Placement.sample(c, rng: Random(7));
    expect(cps.length, 4);
    for (final cp in cps) {
      expect(cp.wordIds.length, 3);
      expect(cp.unitIndex, greaterThan(0));
      expect(cp.unitIndex, lessThan(8));
    }
    // Checkpoints advance in depth.
    for (var i = 1; i < cps.length; i++) {
      expect(cps[i].unitIndex, greaterThan(cps[i - 1].unitIndex));
    }
    // All ids unique.
    final all = cps.expand((e) => e.wordIds).toSet();
    expect(all.length, 12);
  });

  test('all-correct unlocks through the deepest passed checkpoint unit', () {
    final c = _course();
    final cps = Placement.sample(c, rng: Random(7));
    final results = {
      for (final cp in cps)
        for (final id in cp.wordIds) id: true,
    };
    final flat = Placement.recommendedFlatIndex(c, cps, results);
    // Deepest checkpoint = unit index of cps.last; flat end = last lesson of it.
    expect(flat, Placement.flatEndOfUnit(c, cps.last.unitIndex));
    // With 4 lessons/unit that must equal unitIndex*4 + 3.
    expect(flat, cps.last.unitIndex * 4 + 3);
  });

  test('a failing checkpoint stops the skip conservatively', () {
    final c = _course();
    final cps = Placement.sample(c, rng: Random(7));
    final results = <String, bool>{
      for (final cp in cps)
        for (final id in cp.wordIds) id: true,
    };
    // Break ONE word of the SECOND checkpoint -> skip only through first.
    results[cps[1].wordIds.first] = false;
    final flat = Placement.recommendedFlatIndex(c, cps, results);
    expect(flat, Placement.flatEndOfUnit(c, cps[0].unitIndex));
  });

  test('everything wrong starts from zero', () {
    final c = _course();
    final cps = Placement.sample(c, rng: Random(7));
    final results = {
      for (final cp in cps)
        for (final id in cp.wordIds) id: false,
    };
    expect(Placement.recommendedFlatIndex(c, cps, results), 0);
  });

  test('answerKey maps every sampled id to a translation', () {
    final c = _course();
    final cps = Placement.sample(c, rng: Random(7));
    final key = Placement.answerKey(c, cps.expand((e) => e.wordIds));
    expect(key.length, 12);
    expect(key.values.every((t) => t.isNotEmpty), isTrue);
  });

  group('v5.5 adaptive prober', () {
    test('asks exactly N unique questions, then finishes', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 18, rng: Random(3));
      final ids = <String>{};
      while (true) {
        final item = p.next();
        if (item == null) break;
        expect(ids.add(item.wordId), isTrue, reason: 'repeat: ${item.wordId}');
        expect(item.options.length, 4);
        expect(item.options.toSet().length, 4, reason: 'duplicate options');
        expect(item.options.contains(item.answer), isTrue);
        p.answer(true);
      }
      expect(ids.length, 18);
      expect(p.isFinished, isTrue);
      expect(p.next(), isNull);
      expect(p.remaining, 0);
    });

    test('staircase rises on correct answers and converges at the top', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 18, rng: Random(5));
      while (p.next() != null) {
        p.answer(true);
      }
      expect(p.finalBand, greaterThan(0.9)); // 0.30 + 18×0.12 clamps at 0.98
      expect(p.tier, LevelTier.expert);
    });

    test('staircase falls on wrong answers and stays above its floor', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 18, rng: Random(5));
      while (p.next() != null) {
        p.answer(false);
      }
      expect(p.finalBand, lessThan(0.05)); // clamps at 0.02
      expect(p.tier, LevelTier.beginner);
    });

    test('mixed session maps the final band to the middle tier', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 18, rng: Random(5));
      // (T,T,F,F)×3 nets 0, then (T,T,F)×2 nets +2 — the running band never
      // reaches the clamp, so the final depth is 0.30 + 2×0.12 = 0.54.
      const script = [
        true,
        true,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
      ];
      var i = 0;
      while (p.next() != null) {
        p.answer(script[i++]);
      }
      expect(p.finalBand, closeTo(0.54, 0.001));
      expect(p.tier, LevelTier.intermediate);
    });

    test('checkpoints group asked items by unit in depth order', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 18, rng: Random(9));
      while (p.next() != null) {
        p.answer(true);
      }
      final cps = p.checkpoints;
      expect(cps.isNotEmpty, isTrue);
      for (var i = 1; i < cps.length; i++) {
        expect(cps[i].unitIndex, greaterThan(cps[i - 1].unitIndex));
      }
      expect(cps.expand((e) => e.wordIds).toSet().length, 18);
      expect(p.results.length, 18);
      // domain suggestion flows through the same v4.13 rule
      expect(p.recommendedDomain(), isNotNull);
    });

    test('levelBreakdown sums to the question count in course order', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 18, rng: Random(9));
      var n = 0;
      while (p.next() != null) {
        p.answer(n++ % 3 != 0); // every 3rd wrong
      }
      final rows = p.levelBreakdown();
      expect(rows.map((r) => r.asked).reduce((a, b) => a + b), 18);
      expect(rows.map((r) => r.correct).reduce((a, b) => a + b),
          p.results.values.where((v) => v).length);
      final order = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
      final idxs = rows.map((r) => order.indexOf(r.cefr)).toList();
      expect(idxs, equals(idxs.toList()..sort()), reason: 'course order');
    });

    test('flatSkip keeps a later solid band past a failed middle one', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 12, rng: Random(9));
      while (p.next() != null) {
        p.answer(true);
      }
      final cps = p.checkpoints;
      expect(cps.length, greaterThanOrEqualTo(3),
          reason: 'a 12-question run should span several units');
      // sabotage ONE word of a MIDDLE checkpoint: the legacy prefix walk
      // stops there, while the solid walk still honors the deeper bands.
      final middle = cps[cps.length ~/ 2];
      p.results[middle.wordIds.first] = false;
      expect(Placement.recommendedFlatIndex(c, cps, p.results),
          Placement.flatEndOfUnit(c, cps[cps.length ~/ 2 - 1].unitIndex));
      expect(p.flatSkip(), Placement.flatEndOfUnit(c, cps.last.unitIndex));
      expect(p.flatSkip(),
          greaterThan(Placement.recommendedFlatIndex(c, cps, p.results)));
    });

    test('flatSkip returns zero when nothing was proven', () {
      final c = _course();
      final p = PlacementProber.create(c, questions: 6, rng: Random(9));
      while (p.next() != null) {
        p.answer(false);
      }
      expect(p.flatSkip(), 0);
    });

    test('recommendedFlatIndexSolid is checked per checkpoint (unit test)', () {
      final c = _course();
      // A FAILED checkpoint sits BETWEEN two solid ones — the legacy prefix
      // walk stops at the failure, the solid walk honors the later band.
      final cps = [
        PlacementCheckpoint(1, ['w_1_l0', 'w_1_l1']),
        PlacementCheckpoint(2, ['w_2_l0']),
        PlacementCheckpoint(6, ['w_6_l0']),
      ];
      final results = <String, bool>{
        'w_1_l0': true,
        'w_1_l1': true,
        'w_2_l0': false, // middle checkpoint fails
        'w_6_l0': true, // later solid band
      };
      // solid walk keeps the C1 band; the legacy prefix walk stops earlier.
      expect(Placement.recommendedFlatIndexSolid(c, cps, results),
          Placement.flatEndOfUnit(c, 6));
      expect(Placement.recommendedFlatIndex(c, cps, results),
          Placement.flatEndOfUnit(c, 1));
    });
  });
}
