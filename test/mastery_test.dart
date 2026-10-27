// Mastery model tests (v5.12, plan feature F2.1).
//
// The score must be honest: unseen = 0, learning capped, stability and
// retrievability dominate, lapses cost, and everything is deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/mastery.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/srs.dart';

CardData _seen({
  double stability = 10,
  double difficulty = 5,
  int reps = 4,
  int lapses = 0,
  String state = 'review',
  int lastDaysAgo = 1,
  DateTime? at,
}) {
  final n = at ?? _fixedNow;
  final c = CardData(
    state: state,
    reps: reps,
    lapses: lapses,
    stability: stability,
    difficulty: difficulty,
    lastReviewEpochMs:
        n.subtract(Duration(days: lastDaysAgo)).millisecondsSinceEpoch,
  );
  return c;
}

/// Fixed clock so every fixture and every assertion share one timeline.
final DateTime _fixedNow = DateTime(2026, 3, 15, 12);
DateTime n() => _fixedNow;

void main() {
  test('mastery: unseen and null cards score 0', () {
    expect(Mastery.wordScore(null, now: n()), 0);
    expect(Mastery.wordScore(CardData(), now: n()), 0);
  });

  test('mastery: a fresh graduate lands mid-band, never at 100', () {
    // A card rated good 3 times with ~3-day stability, reviewed yesterday.
    final c = _seen(stability: 3, reps: 3);
    final s = Mastery.wordScore(c, now: n());
    expect(s, greaterThan(20));
    expect(s, lessThan(60));
  });

  test('mastery: stability drives the score up on a log scale', () {
    final s1 = Mastery.wordScore(_seen(stability: 1), now: n());
    final s6 = Mastery.wordScore(_seen(stability: 6), now: n());
    final s60 = Mastery.wordScore(_seen(stability: 60), now: n());
    expect(s6, greaterThan(s1));
    expect(s60, greaterThan(s6));
    // The 60-day saturating point fills the whole stability term.
    expect(s60, greaterThanOrEqualTo(Mastery.stabilityWeight));
  });

  test('mastery: time decay lowers the retention term', () {
    final fresh = Mastery.wordScore(_seen(lastDaysAgo: 0), now: n());
    final stale =
        Mastery.wordScore(_seen(stability: 4, lastDaysAgo: 7), now: n());
    expect(stale, lessThan(fresh));
  });

  test('mastery: lapses cut the performance term', () {
    final clean = Mastery.wordScore(_seen(reps: 4, lapses: 0), now: n());
    final shaky = Mastery.wordScore(_seen(reps: 4, lapses: 2), now: n());
    expect(shaky, lessThan(clean));
    // The exact performance delta: 15 · (2/4) = 7.5 points (same states).
    expect(clean - shaky, closeTo(7.5, 0.01));
  });

  test('mastery: learning-state cards are capped at 55', () {
    final c = _seen(stability: 40, reps: 2, lapses: 0, state: 'learning');
    expect(Mastery.wordScore(c, now: n()), lessThanOrEqualTo(55.0001));
  });

  test('mastery: bands split at the documented thresholds', () {
    expect(Mastery.bandKey(0), 'masteryNew');
    expect(Mastery.bandKey(24.9), 'masteryNew');
    expect(Mastery.bandKey(25), 'masteryEmerging');
    expect(Mastery.bandKey(49.9), 'masteryEmerging');
    expect(Mastery.bandKey(50), 'masteryStrong');
    expect(Mastery.bandKey(74.9), 'masteryStrong');
    expect(Mastery.bandKey(75), 'masteryMastered');
    expect(Mastery.bandKey(100), 'masteryMastered');
  });

  test('mastery: score is reproducible via the real scheduler', () {
    // Rate a card through Srs.rate and let time pass; the mastery score
    // must agree with the card's own memory states (no divergence).
    final c = CardData();
    Srs.rate(c, Srs.good, now: n(), requestRetention: 0.9);
    final s1 = Mastery.wordScore(c, now: n());
    expect(s1, greaterThan(0));
    Srs.rate(c, Srs.good,
        now: n().add(const Duration(days: 4)), requestRetention: 0.9);
    final s2 = Mastery.wordScore(c, now: n().add(const Duration(days: 4)));
    expect(s2, greaterThan(s1)); // stability grew
  });

  test('mastery: average counts unseen words as zero', () {
    final vocab = [
      const Vocab(id: 'a', target: 'a', translationAr: 'أ'),
      const Vocab(id: 'b', target: 'b', translationAr: 'ب'),
    ];
    final cards = {'a': _seen(stability: 60)};
    // 'a' saturates most of its score; 'b' is unseen → 0. The average must
    // reflect BOTH words, not just the seen one.
    final avg = Mastery.averageScore(vocab, cards, now: n());
    expect(avg, closeTo(Mastery.wordScore(cards['a'], now: n()) / 2, 0.01));
  });

  test('mastery: summary counts mastered words at the 75 threshold', () {
    final vocab = [
      const Vocab(id: 'a', target: 'a', translationAr: 'أ'),
      const Vocab(id: 'b', target: 'b', translationAr: 'ب'),
      const Vocab(id: 'c', target: 'c', translationAr: 'ج'),
    ];
    final cards = {
      // Long-lived review card → mastered band.
      'a': _seen(stability: 60, reps: 10, lastDaysAgo: 0),
      // Learning card → capped.
      'b': _seen(stability: 2, reps: 1, state: 'learning'),
    };
    final sum = Mastery.summary(vocab, cards, now: n());
    expect(sum.total, 3);
    expect(sum.mastered, 1);
    expect(
        sum.averagePct,
        ((Mastery.wordScore(cards['a'], now: n()) +
                    Mastery.wordScore(cards['b'], now: n()) +
                    0) /
                3)
            .round());
  });

  test('mastery: weakestSeen returns seen words worst-first, deterministic',
      () {
    final vocab = [
      const Vocab(id: 'w1', target: 'w1', translationAr: '١'),
      const Vocab(id: 'w2', target: 'w2', translationAr: '٢'),
      const Vocab(id: 'w3', target: 'w3', translationAr: '٣'),
      const Vocab(id: 'w4', target: 'w4', translationAr: '٤'),
    ];
    final cards = {
      'w1': _seen(stability: 1), // weak
      'w2': _seen(stability: 30), // strong
      'w3': _seen(stability: 2), // weak
      // w4 unseen → excluded
    };
    final weakest = Mastery.weakestSeen(vocab, cards, 2, now: n());
    expect(weakest.length, 2);
    expect(weakest[0].$1, 'w1');
    expect(weakest[1].$1, 'w3');
    // Deterministic on re-run.
    expect(Mastery.weakestSeen(vocab, cards, 2, now: n()), weakest);
  });

  test('mastery: empty course averages 0 and never divides by zero', () {
    expect(Mastery.averageScore([], {}, now: n()), 0);
    final sum = Mastery.summary([], {}, now: n());
    expect(sum.total, 0);
    expect(sum.mastered, 0);
    expect(sum.averagePct, 0);
  });
}
