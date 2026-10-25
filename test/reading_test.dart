// Reading catalog tests (v5.8): integrity, per-course coverage, corpus
// lookup semantics (exact + plural fallback + honest null).
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/reading.dart';

Course _miniCourse() {
  Vocab v(String id, String t, String ar) =>
      Vocab(id: id, target: t, translationAr: ar);
  return Course(
    id: 'en',
    nameAr: 'إنجليزي',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: [
      Unit(
        id: 'u0',
        titleAr: 'وحدة',
        titleEn: 'U',
        colorHex: '58CC02',
        lessons: [
          Lesson(
            id: 'l0',
            titleAr: 'درس',
            titleEn: 'L',
            vocab: [
              v('en_apple', 'apple', 'تفاحة'),
              v('en_cat', 'cat', 'قطّة'),
              v('en_school', 'school', 'مدرسة'),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('catalog verifies: unique ids, real courses, aligned glosses', () {
    expect(ReadingCatalog.verify(), isTrue);
  });

  test('every course has at least two starter texts', () {
    for (final c in ['en', 'de', 'fr', 'ur']) {
      final t = ReadingCatalog.forCourse(c);
      expect(t.length, greaterThanOrEqualTo(2), reason: c);
      expect(t.every((x) => x.courseId == c), isTrue, reason: c);
    }
  });

  test('texts split into 3+ sentences with Arabic glosses', () {
    for (final t in ReadingCatalog.texts) {
      final s = t.sentences();
      expect(s.length, greaterThanOrEqualTo(3), reason: t.id);
      expect(t.sentencesAr.length, greaterThanOrEqualTo(2), reason: t.id);
    }
  });

  test('lookup finds course words case-insensitively', () {
    final c = _miniCourse();
    expect(ReadingCatalog.lookup(c, 'Apple')?.id, 'en_apple');
    expect(ReadingCatalog.lookup(c, 'apple.')?.id, 'en_apple');
    expect(ReadingCatalog.lookup(c, 'school')?.id, 'en_school');
  });

  test('lookup strips punctuation and falls back to singular', () {
    final c = _miniCourse();
    expect(ReadingCatalog.lookup(c, 'cats')?.id, 'en_cat');
    expect(ReadingCatalog.lookup(c, 'horses,'), isNull,
        reason: 'outside the corpus → honest null');
  });

  test('text ids are namespaced and byId is null-safe', () {
    for (final t in ReadingCatalog.texts) {
      expect(t.id.startsWith('rd_'), isTrue, reason: t.id);
    }
    expect(ReadingCatalog.byId('rd_en_morning'), isNotNull);
    expect(ReadingCatalog.byId('en_apple'), isNull);
  });
}
