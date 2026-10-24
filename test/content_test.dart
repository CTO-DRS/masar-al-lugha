// v4.2 content tests: the shipped course assets must satisfy the same
// invariants that scripts/validate_content.py enforces in CI. These tests
// load the real assets (declared in pubspec.yaml) so a broken content file
// fails BOTH the Python gate and `flutter test`.
//
// What is verified (docs/CONTENT_AUDIT.md v4.2):
// - all three courses parse and keep the v4.2 shape (52/21/21 units)
// - every unit carries a valid, monotonic (non-decreasing) CEFR tag
// - vocab ids stay globally unique across en/fr/ur (append-only progress keys)
// - every vocab has a non-empty target + Arabic translation
// - every v4.2 unit keeps per-lesson emoji uniqueness (picture rounds)
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/models.dart';

const _expected = <String, List<int>>{
  'en': [54, 210, 2268],
  'fr': [23, 69, 771],
  'ur': [23, 73, 679],
};

const _cefr = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

Future<Course> _load(String lang) async {
  final raw = await rootBundle.loadString('assets/data/course_$lang.json');
  return Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('course assets (v4.2)', () {
    test('three courses parse with the expected unit/lesson/word shape',
        () async {
      var totalWords = 0;
      for (final lang in _expected.keys) {
        final course = await _load(lang);
        final units = course.units.length;
        final lessons = course.allLessons.length;
        final words = course.allVocab.length;
        totalWords += words;
        expect(units, _expected[lang]![0], reason: '$lang unit count drifted');
        expect(lessons, _expected[lang]![1],
            reason: '$lang lesson count drifted');
        expect(words, _expected[lang]![2], reason: '$lang word count drifted');
      }
      expect(totalWords, 3718);
    });

    test('every unit has a valid monotonic CEFR tag', () async {
      for (final lang in _expected.keys) {
        final course = await _load(lang);
        var prev = 0;
        for (final unit in course.units) {
          expect(_cefr.contains(unit.cefr), isTrue,
              reason: '${unit.id} has bad cefr "${unit.cefr}"');
          final idx = _cefr.indexOf(unit.cefr);
          expect(idx, greaterThanOrEqualTo(prev),
              reason: '${unit.id} cefr ${unit.cefr} breaks the '
                  'non-decreasing path order');
          prev = idx;
        }
      }
    });

    test('vocab ids stay globally unique and required fields are filled',
        () async {
      final seen = <String>{};
      for (final lang in _expected.keys) {
        final course = await _load(lang);
        for (final v in course.allVocab) {
          expect(seen.add(v.id), isTrue,
              reason: 'duplicate vocab id across courses: ${v.id}');
          expect(v.target.trim(), isNotEmpty,
              reason: '${v.id} has empty target');
          expect(v.translationAr.trim(), isNotEmpty,
              reason: '${v.id} has empty translationAr');
        }
      }
      expect(seen.length, 3718);
    });

    test('new v4.2 units keep per-lesson emoji uniqueness', () async {
      final newUnits = {'en': 6, 'fr': 6, 'ur': 6};
      for (final lang in newUnits.keys) {
        final course = await _load(lang);
        final units = course.units;
        for (final unit in units.skip(units.length - newUnits[lang]!)) {
          for (final lesson in unit.lessons) {
            final emojis =
                lesson.vocab.map((v) => v.emoji).whereType<String>().toList();
            expect(emojis.toSet().length, emojis.length,
                reason: '${lesson.id} repeats an emoji '
                    '(picture rounds would skip words)');
          }
        }
      }
    });

    test(
        'v4.5 units are appended at the end with ids in the u53-u54 '
        '(en) / u22-u23 (fr, ur) range — append-only invariant', () async {
      final en = await _load('en');
      expect(en.units.last.id, 'en_u54');
      expect(en.units[52].id, 'en_u53');
      expect(en.units[51].id, 'en_u52'); // v4.2 tail still intact
      final fr = await _load('fr');
      expect(fr.units.last.id, 'fr_u23');
      expect(fr.units[20].id, 'fr_u21'); // v4.2 tail still intact
      final ur = await _load('ur');
      expect(ur.units.last.id, 'ur_u23');
      expect(ur.units[20].id, 'ur_u21'); // v4.2 tail still intact
      // v4.5 unit cefr endpoints match the ROADMAP ladder.
      expect(en.units.last.cefr, 'C1');
      expect(fr.units.last.cefr, 'C1');
      expect(ur.units.last.cefr, 'C1');
    });
  });
}
