import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';

Lesson _lesson() {
  const vocab = [
    Vocab(
        id: 'w1',
        target: 'Cat',
        translationAr: 'قط',
        emoji: '🐱',
        exampleTarget: 'The cat is small',
        exampleAr: 'القط صغير'),
    Vocab(id: 'w2', target: 'Dog', translationAr: 'كلب', emoji: '🐶'),
    Vocab(id: 'w3', target: 'Bird', translationAr: 'طائر', emoji: '🐦'),
    Vocab(id: 'w4', target: 'Fish', translationAr: 'سمكة', emoji: '🐟'),
    Vocab(id: 'w5', target: 'Bread', translationAr: 'خبز', emoji: '🍞'),
    Vocab(id: 'w6', target: 'I love my cat', translationAr: 'أحب قطتي'),
  ];
  return const Lesson(
      id: 'l1', titleAr: 'ح', titleEn: 'L', vocab: vocab);
}

void main() {
  test('localization falls back to Arabic', () {
    expect(L.t('ar', 'appName'), 'مسار اللغة');
    expect(L.t('en', 'appName'), 'Language Path');
    expect(L.t('xx', 'appName'), 'مسار اللغة');
  });

  test('v2.0 localization keys exist', () {
    expect(L.t('ar', 'dictionary'), 'القاموس');
    expect(L.t('en', 'whichPicture'), isNot('whichPicture'));
    expect(L.t('ar', 'badge_both_courses'), contains('ثنائي'));
  });

  test('v3.0 localization keys exist', () {
    expect(L.t('ar', 'badge_polyglot'), contains('متعدد'));
    expect(L.t('ar', 'badge_all_fr_units'), contains('الفرنسية'));
    expect(L.t('ar', 'lessons'), 'دروس');
    expect(L.t('en', 'lessons'), 'lessons');
    expect(L.t('en', 'badge_polyglot'), contains('Polyglot'));
  });

  test('exercise generator produces all new v2.0 types', () {
    final ex = ExerciseGen.forLesson(_lesson());
    expect(ex, isNotEmpty);

    final types = ex.map((e) => e.type).toSet();
    // Core types still present.
    expect(types.contains(ExerciseType.mcq), isTrue);
    // New interactive types present.
    expect(types.contains(ExerciseType.wordToPic), isTrue);
    expect(types.contains(ExerciseType.picToWord), isTrue);
    expect(types.contains(ExerciseType.fillblank), isTrue);
    expect(types.contains(ExerciseType.truefalse), isTrue);
    expect(types.contains(ExerciseType.match), isTrue);

    for (final e in ex) {
      switch (e.type) {
        case ExerciseType.mcq:
        case ExerciseType.reverse:
        case ExerciseType.listen:
        case ExerciseType.picToWord:
        case ExerciseType.wordToPic:
        case ExerciseType.fillblank:
          expect(e.options.length, 4,
              reason: '4 options for ${e.type} (${e.prompt})');
          expect(e.options.toSet().length, 4,
              reason: 'options must be distinct');
          expect(e.options.contains(e.answer), isTrue,
              reason: 'answer must be among options');
          break;
        case ExerciseType.truefalse:
          expect(e.options, ['true', 'false']);
          expect(['true', 'false'].contains(e.answer), isTrue);
          break;
        case ExerciseType.build:
          expect(e.tiles, isNotEmpty);
          break;
        case ExerciseType.match:
          expect(e.matchLeft.length, greaterThanOrEqualTo(4));
          expect(e.matchRight.length, e.matchLeft.length);
          break;
      }
    }
  });

  test('word-to-picture options use distinct emojis', () {
    final ex = ExerciseGen.forLesson(_lesson());
    final pics = ex
        .where((e) => e.type == ExerciseType.wordToPic)
        .expand((e) => e.options);
    expect(pics.toSet().length, pics.length); // distinct per exercise
  });

  test('fillblank blanks the keyword correctly', () {
    final ex = ExerciseGen.forLesson(_lesson());
    final blanks =
        ex.where((e) => e.type == ExerciseType.fillblank).toList();
    expect(blanks, isNotEmpty);
    for (final b in blanks) {
      expect(b.prompt.contains('______'), isTrue);
      expect(b.prompt, isNot(contains(b.answer)));
    }
  });
}
