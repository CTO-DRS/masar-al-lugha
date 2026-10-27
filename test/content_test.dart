// v4.2 content tests: the shipped course assets must satisfy the same
// invariants that scripts/validate_content.py enforces in CI. These tests
// load the real assets (declared in pubspec.yaml) so a broken content file
// fails BOTH the Python gate and `flutter test`.
//
// What is verified (docs/CONTENT_AUDIT.md v4.2):
// - all four courses parse and keep the shipped shape (56/56/25/20 units)
// - every unit carries a valid, monotonic (non-decreasing) CEFR tag
// - vocab ids stay globally unique across en/fr/ur/de (append-only progress keys)
// - every vocab has a non-empty target + Arabic translation
// - every v4.2 unit keeps per-lesson emoji uniqueness (picture rounds)
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/conversation.dart';
import 'package:masar_al_lugha/grammar.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/reading.dart';

const _expected = <String, List<int>>{
  'en': [56, 220, 2368],
  'fr': [25, 75, 831],
  'ur': [56, 220, 2368],
  'de': [25, 75, 779],
};

// v5.4: minimum example-sentence coverage per course — the validator
// (scripts/validate_content.py) mirrors this so content can never silently
// regress. v5.16 (Q4/F4.1): the backfill is COMPLETE — every course at 100%.
const _minExampleCoverage = <String, double>{
  'en': 1.0,
  'fr': 1.0,
  'ur': 1.0,
  'de': 1.0,
};

// v5.16 (Q4/F4.5): verbatim containment floors for single-word rows
// (fill-blank's _canBlank gate). Legacy conjugated examples (FR/DE verbs)
// are tolerated at the locked ratios; anything WORSE fails.
const _minContainment = <String, double>{
  'en': 0.99,
  'ur': 0.99,
  'fr': 0.85,
  'de': 0.80,
};

const _cefr = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

Future<Course> _load(String lang) async {
  final raw = await rootBundle.loadString('assets/data/course_$lang.json');
  return Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('course assets (v4.2)', () {
    test('four courses parse with the expected unit/lesson/word shape',
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
      expect(totalWords, 6346);
    });

    test('example-sentence coverage meets the enforced floor', () async {
      for (final lang in _expected.keys) {
        final course = await _load(lang);
        final words = course.allVocab;
        final withExample = words
            .where((v) =>
                (v.exampleTarget ?? '').trim().isNotEmpty &&
                (v.exampleAr ?? '').trim().isNotEmpty)
            .length;
        final ratio = withExample / words.length;
        expect(ratio, greaterThanOrEqualTo(_minExampleCoverage[lang]!),
            reason: '$lang example coverage $withExample/${words.length} '
                'fell below the ${_minExampleCoverage[lang]} floor');
      }
    });

    test(
        'v5.16: single-word rows keep verbatim containment at the locked '
        'floor (fill-blank gate)', () async {
      for (final lang in _expected.keys) {
        final course = await _load(lang);
        final single = course.allVocab
            .where((v) => !v.target.trim().contains(' '))
            .toList();
        final contained = single
            .where((v) => (v.exampleTarget ?? '')
                .trim()
                .toLowerCase()
                .contains(v.target.trim().toLowerCase()))
            .length;
        final ratio = contained / single.length;
        expect(ratio, greaterThanOrEqualTo(_minContainment[lang]!),
            reason: '$lang containment $contained/${single.length} fell '
                'below the ${_minContainment[lang]} floor');
      }
    });

    test(
        'v5.16: skill corpora keep at least 4 items per course '
        '(reading / conversation / grammar)', () async {
      expect(ReadingCatalog.texts.length, 16);
      expect(ConversationCatalog.scenarios.length, 16);
      expect(GrammarCatalog.lessons.length, 16);
      for (final lang in _expected.keys) {
        expect(ReadingCatalog.forCourse(lang).length, greaterThanOrEqualTo(4),
            reason: '$lang reading corpus below floor');
        expect(
            ConversationCatalog.forCourse(lang).length, greaterThanOrEqualTo(4),
            reason: '$lang conversation corpus below floor');
        expect(GrammarCatalog.forCourse(lang).length, greaterThanOrEqualTo(4),
            reason: '$lang grammar corpus below floor');
      }
    });

    test('v5.16: flagship courses keep lesson parity (en == ur)', () async {
      final en = await _load('en');
      final ur = await _load('ur');
      expect(en.allLessons.length, ur.allLessons.length,
          reason: 'en/ur lesson parity broken');
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
      expect(seen.length, 6346);
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
        'v4.6 units are appended at the end with ids in the u55-u56 '
        '(en) / v5.1 tail range (ur) — append-only invariant', () async {
      final en = await _load('en');
      expect(en.units.last.id, 'en_u56');
      expect(en.units[54].id, 'en_u55');
      expect(en.units[53].id, 'en_u54'); // v4.5 tail still intact
      final fr = await _load('fr');
      expect(fr.units.last.id, 'fr_u25');
      expect(fr.units[22].id, 'fr_u23'); // v4.5 tail still intact
      final ur = await _load('ur');
      expect(ur.units.last.id, 'ur_u56'); // v5.1 tail
      expect(ur.units[54].id, 'ur_u55'); // v5.1 tail
      expect(ur.units[51].id, 'ur_u23'); // v4.5 tail still intact
      // v4.6 unit cefr endpoints match the ROADMAP ladder.
      expect(en.units.last.cefr, 'C1');
      expect(fr.units.last.cefr, 'C1');
      expect(ur.units.last.cefr, 'C1');
    });
  });
}
