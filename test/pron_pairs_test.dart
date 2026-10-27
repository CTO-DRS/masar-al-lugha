// v5.16 (Q4/F4.4): confusable sound pairs — every pair must reference two
// REAL, distinct single-word targets of its own course, so a pronunciation
// chip can never open nothing. Also pins per-course floor (>= 6 pairs) and
// bilingual hints.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/pronunciation_pairs.dart';

const _courses = {'en', 'ur', 'fr', 'de'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pronunciation pairs (F4.4)', () {
    test('every pair resolves to two real distinct single-word targets',
        () async {
      for (final lang in _courses) {
        final raw =
            await rootBundle.loadString('assets/data/course_$lang.json');
        final course = jsonDecode(raw) as Map<String, dynamic>;
        final single = <String>{};
        for (final u in (course['units'] as List)) {
          for (final l in (u as Map<String, dynamic>)['lessons'] as List) {
            for (final w in (l as Map<String, dynamic>)['vocab'] as List) {
              final t = ((w as Map<String, dynamic>)['target'] as String)
                  .trim()
                  .toLowerCase();
              if (!t.contains(' ')) single.add(t);
            }
          }
        }
        final pairs = PronPairCatalog.forCourse(lang);
        expect(pairs.length, greaterThanOrEqualTo(6),
            reason: '$lang has too few confusable pairs');
        for (final p in pairs) {
          expect(p.courseId, lang, reason: '${p.id} has a foreign courseId');
          expect(single.contains(p.a.toLowerCase()), isTrue,
              reason: '${p.id}: "${p.a}" is not a single word in $lang');
          expect(single.contains(p.b.toLowerCase()), isTrue,
              reason: '${p.id}: "${p.b}" is not a single word in $lang');
          expect(p.a.toLowerCase() == p.b.toLowerCase(), isFalse,
              reason: '${p.id} pairs a word with itself');
          expect(p.hintAr.trim(), isNotEmpty,
              reason: '${p.id} has no Arabic hint');
        }
      }
    });

    test('catalog ids are unique and course ids are real', () {
      final seen = <String>{};
      for (final p in PronPairCatalog.pairs) {
        expect(seen.add(p.id), isTrue, reason: 'duplicate pair id ${p.id}');
        expect(_courses.contains(p.courseId), isTrue,
            reason: '${p.id} has unknown course ${p.courseId}');
      }
    });
  });
}
