// Placement engine tests (v4.0, audit M9).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/placement.dart';

Course _course({int unitCount = 8, int lessonsPerUnit = 4}) {
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
}
