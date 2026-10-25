// Pronunciation scoring engine tests (v5.6). The STT service itself needs
// real hardware and is deliberately NOT unit-tested — the UI treats a
// missing platform channel as "unavailable" (honest degradation).
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/pronunciation.dart';

void main() {
  group('normalize', () {
    test('lowercases and strips punctuation', () {
      expect(PronScorer.normalize('Hallo, Welt!'), 'hallo welt');
    });

    test('strips Arabic tashkeel and tatweel', () {
      expect(PronScorer.normalize('مُحَمَّـد'), 'محمد');
    });

    test('keeps German umlauts and eszett', () {
      expect(PronScorer.normalize('Grüße'), 'grüße');
    });

    test('collapses whitespace', () {
      expect(PronScorer.normalize('  a   b  '), 'a b');
    });
  });

  group('editDistance', () {
    test('identical strings are zero', () {
      expect(PronScorer.editDistance('hallo', 'hallo'), 0);
    });

    test('counts substitutions and insertions', () {
      expect(PronScorer.editDistance('hallo', 'halla'), 1);
      expect(PronScorer.editDistance('cat', 'cats'), 1);
      expect(PronScorer.editDistance('kitten', 'sitting'), 3);
    });

    test('empty side counts as full length', () {
      expect(PronScorer.editDistance('', 'abc'), 3);
    });
  });

  group('score', () {
    test('exact match (ignoring case/punct/diacritics) is 100', () {
      expect(PronScorer.score('Hallo!', 'hallo'), 100);
      expect(PronScorer.score('مُحَمَّد', 'محمد'), 100);
    });

    test('empty transcript scores zero', () {
      expect(PronScorer.score('Hallo', ''), 0);
      expect(PronScorer.score('Hallo', '   '), 0);
    });

    test('one-letter slip lands in the close band', () {
      final s = PronScorer.score('Hallo', 'Halle');
      expect(s, greaterThanOrEqualTo(60));
      expect(s, lessThan(85));
    });

    test('a completely different word scores low', () {
      expect(PronScorer.score('Hallo', 'Tschüss'), lessThan(60));
    });

    test('extra filler words lower but do not zero the score', () {
      final s = PronScorer.score('Guten Morgen', 'ja guten morgen');
      expect(s, greaterThan(0));
      expect(s, lessThan(100));
    });
  });

  group('verdictKey', () {
    test('thresholds: >=85 great, >=60 close, >0 partial, 0 miss', () {
      expect(PronScorer.verdictKey(100), 'pronGreat');
      expect(PronScorer.verdictKey(85), 'pronGreat');
      expect(PronScorer.verdictKey(84), 'pronClose');
      expect(PronScorer.verdictKey(60), 'pronClose');
      expect(PronScorer.verdictKey(59), 'pronPartial');
      expect(PronScorer.verdictKey(1), 'pronPartial');
      expect(PronScorer.verdictKey(0), 'pronMiss');
    });
  });
}
