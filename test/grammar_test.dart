// Grammar catalog tests (v5.7): catalog integrity, per-course coverage and
// drill well-formedness. The screen is a plain reader over this data.
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/grammar.dart';

void main() {
  test('catalog verifies: unique ids, real courses, well-formed drills', () {
    expect(GrammarCatalog.verify(), isTrue);
  });

  test('every course has at least two starter lessons', () {
    for (final c in ['en', 'de', 'fr', 'ur']) {
      final l = GrammarCatalog.forCourse(c);
      expect(l.length, greaterThanOrEqualTo(2), reason: c);
      expect(l.every((x) => x.courseId == c), isTrue, reason: c);
    }
  });

  test('every lesson carries Arabic contrastive points and explanations', () {
    for (final l in GrammarCatalog.lessons) {
      expect(l.pointsAr.length, greaterThanOrEqualTo(2), reason: l.id);
      expect(l.pointsAr.every((p) => p.trim().isNotEmpty), isTrue,
          reason: l.id);
      for (final d in l.drills) {
        expect(d.explainAr.trim().isNotEmpty, isTrue, reason: l.id);
      }
    }
  });

  test('drills have 3-4 options and a valid correct index', () {
    for (final l in GrammarCatalog.lessons) {
      for (final d in l.drills) {
        expect(d.options.length, inInclusiveRange(3, 4), reason: d.prompt);
        expect(d.correct, inInclusiveRange(0, d.options.length - 1),
            reason: d.prompt);
        expect(d.options.toSet().length, d.options.length,
            reason: 'duplicate options: ${d.prompt}');
      }
    }
  });

  test('lesson ids are namespaced and cannot collide with vocab ids', () {
    for (final l in GrammarCatalog.lessons) {
      expect(l.id.startsWith('gr_'), isTrue, reason: l.id);
    }
    expect(GrammarCatalog.byId('gr_en_articles'), isNotNull);
    expect(GrammarCatalog.byId('en_hello'), isNull);
    expect(GrammarCatalog.byId('missing'), isNull);
  });

  test('levels use the self-referenced band tags only', () {
    const bands = {'A1', 'A2', 'B1', 'B2', 'C1'};
    for (final l in GrammarCatalog.lessons) {
      expect(bands.contains(l.level), isTrue, reason: l.id);
    }
  });
}
