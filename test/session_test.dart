// Session orchestrator tests (v5.12, plan feature F2.3).
//
// The plan must be deterministic and explainable: due reviews first (most
// overdue, then weakest), weak words second, new words last within budget.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/session.dart';
import 'package:masar_al_lugha/srs.dart';

CardData _card({
  required int dueInDays,
  double stability = 5,
  int reps = 3,
  DateTime? now,
}) {
  final n = now ?? DateTime(2026, 3, 15, 12);
  return CardData(
    state: 'review',
    reps: reps,
    stability: stability,
    difficulty: 5,
    intervalDays: 3,
    dueEpochMs: n.add(Duration(days: dueInDays)).millisecondsSinceEpoch,
    lastReviewEpochMs:
        n.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
  );
}

Vocab _v(String id) => Vocab(id: id, target: id, translationAr: 'معنى $id');

void main() {
  final now = DateTime(2026, 3, 15, 12);

  test('session: empty pool produces an empty plan', () {
    final plan = SessionPlanner.plan(
        pool: [], cards: {}, wordMistakes: {}, newBudget: 10, now: now);
    expect(plan.isEmpty, isTrue);
    expect(plan.queue, isEmpty);
  });

  test('session: due cards come first, most overdue first', () {
    final pool = [_v('a'), _v('b'), _v('c')];
    final cards = {
      'a': _card(dueInDays: -1, now: now), // overdue by 1
      'b': _card(dueInDays: -5, now: now), // overdue by 5
      'c': _card(dueInDays: 2, now: now), // not due
    };
    final plan = SessionPlanner.plan(
        pool: pool, cards: cards, wordMistakes: {}, newBudget: 5, now: now);
    expect(plan.segments.single.key, 'segReview');
    expect(plan.queue.map((v) => v.id).toList(), ['b', 'a']);
  });

  test('session: overdue ties break by lowest stability', () {
    final pool = [_v('a'), _v('b')];
    final cards = {
      'a': _card(dueInDays: -2, stability: 9, now: now),
      'b': _card(dueInDays: -2, stability: 1, now: now),
    };
    final plan = SessionPlanner.plan(
        pool: pool, cards: cards, wordMistakes: {}, newBudget: 0, now: now);
    expect(plan.queue.map((v) => v.id).toList(), ['b', 'a']);
  });

  test('session: weak words (missed, not due) fill the second segment', () {
    final pool = [_v('w1'), _v('w2'), _v('d')];
    final cards = {
      // v5.18 (Batch B3): weak-segment cards must be genuinely weak —
      // low stability + heavy difficulty keeps the mastery score under 60.
      'w1': _card(dueInDays: 3, stability: 1, now: now),
      'w2': _card(dueInDays: 6, stability: 1, now: now),
      'd': _card(dueInDays: -1, now: now),
    };
    final plan = SessionPlanner.plan(
      pool: pool,
      cards: cards,
      wordMistakes: {'w2': 5, 'w1': 2},
      newBudget: 5,
      now: now,
    );
    expect(plan.segments.map((s) => s.key).toList(), ['segReview', 'segWeak']);
    expect(plan.reviewCount, 1);
    expect(plan.weakCount, 2);
    expect(plan.queue.map((v) => v.id).toList(), ['d', 'w2', 'w1'],
        reason: 'most-missed weak word first');
  });

  test('session: unseen words form the new segment in course order', () {
    final pool = [_v('n1'), _v('n2'), _v('n3')];
    final plan = SessionPlanner.plan(
        pool: pool, cards: {}, wordMistakes: {}, newBudget: 2, now: now);
    expect(plan.segments.single.key, 'segNew');
    expect(plan.queue.map((v) => v.id).toList(), ['n1', 'n2'],
        reason: 'budget of 2 caps the course order');
  });

  test('session: the daily new-card budget has teeth', () {
    final pool = [_v('n1'), _v('n2'), _v('n3')];
    final plan = SessionPlanner.plan(
        pool: pool, cards: {}, wordMistakes: {}, newBudget: 0, now: now);
    expect(plan.newCount, 0);
    expect(plan.isEmpty, isTrue);
  });

  test('session: segment caps are respected', () {
    final pool = List.generate(40, (i) => _v('d$i'));
    final cards = {
      for (final v in pool) v.id: _card(dueInDays: -1, now: now),
    };
    final plan = SessionPlanner.plan(
        pool: pool,
        cards: cards,
        wordMistakes: {},
        newBudget: 10,
        reviewCap: 12,
        now: now);
    expect(plan.reviewCount, 12);
    expect(plan.queue.length, 12);
  });

  test('session: full plan keeps the reviews → weak → new order', () {
    final pool = [_v('n1'), _v('w1'), _v('d1'), _v('n2'), _v('w2'), _v('d2')];
    final cards = {
      'd1': _card(dueInDays: -3, now: now),
      'd2': _card(dueInDays: -1, now: now),
      // v5.18 (Batch B3): weak members are genuinely weak (low stability).
      'w1': _card(dueInDays: 4, stability: 1, now: now),
      'w2': _card(dueInDays: 9, stability: 1, now: now),
    };
    final plan = SessionPlanner.plan(
      pool: pool,
      cards: cards,
      wordMistakes: {'w1': 1, 'w2': 4},
      newBudget: 10,
      now: now,
    );
    expect(plan.queue.map((v) => v.id).toList(),
        ['d1', 'd2', 'w2', 'w1', 'n1', 'n2']);
    expect(plan.reviewCount, 2);
    expect(plan.weakCount, 2);
    expect(plan.newCount, 2);
  });

  test(
      'session: a recovered word (old mistake, healthy memory) leaves the weak segment',
      () {
    // v5.18 (Batch B3): one mistake weeks ago on a card that has since
    // grown a long stability no longer counts as weak — the score gate.
    final pool = [_v('ok'), _v('w')];
    final cards = {
      'ok': _card(dueInDays: 3, stability: 40, reps: 12, now: now),
      'w': _card(dueInDays: 5, stability: 1, now: now),
    };
    final plan = SessionPlanner.plan(
      pool: pool,
      cards: cards,
      wordMistakes: {'ok': 1, 'w': 3},
      newBudget: 5,
      now: now,
    );
    expect(plan.weakCount, 1, reason: 'only the genuinely weak card stays');
    expect(plan.queue.map((v) => v.id).toList(), ['w']);
  });

  test(
      'session: a live remediation target stays weak even with a recovered score',
      () {
    // v5.18 (Batch B3): the 7-day window outranks the score — a word still
    // lapsing on distinct days is a live trap regardless of its states.
    final pool = [_v('trap')];
    final cards = {
      'trap': _card(dueInDays: 3, stability: 40, reps: 12, now: now)
    };
    final plan = SessionPlanner.plan(
      pool: pool,
      cards: cards,
      wordMistakes: {'trap': 2},
      remediationIds: {'trap'},
      newBudget: 5,
      now: now,
    );
    expect(plan.weakCount, 1);
    expect(plan.queue.single.id, 'trap');
  });

  test('session: zero-mistake seen words land in no segment unless due', () {
    final pool = [_v('ok')];
    final cards = {'ok': _card(dueInDays: 3, now: now)};
    final plan = SessionPlanner.plan(
        pool: pool, cards: cards, wordMistakes: {}, newBudget: 5, now: now);
    expect(plan.isEmpty, isTrue,
        reason: 'healthy, not-due words must NOT be re-drilled');
  });

  test('session: reps==0 cards count as new even when a card object exists',
      () {
    final pool = [_v('fresh')];
    final cards = {'fresh': CardData()}; // created but never rated
    final plan = SessionPlanner.plan(
        pool: pool, cards: cards, wordMistakes: {}, newBudget: 5, now: now);
    expect(plan.newCount, 1);
  });

  test('session: the plan is fully deterministic (no shuffle anywhere)', () {
    final pool = [_v('a'), _v('b'), _v('c')];
    final cards = {
      'a': _card(dueInDays: -1, stability: 2, now: now),
      'b': _card(dueInDays: -1, stability: 8, now: now),
      'c': _card(dueInDays: -4, stability: 3, now: now),
    };
    List<String> ids() => SessionPlanner.plan(
            pool: pool, cards: cards, wordMistakes: {}, newBudget: 1, now: now)
        .queue
        .map((v) => v.id)
        .toList();
    expect(ids(), ids(), reason: 'two runs must agree exactly');
    expect(ids(), ['c', 'a', 'b']);
  });

  test('session: ratings through the plan feed the scheduler normally', () {
    // Contract check with the SRS layer: rating a planned card moves it
    // out of the due set (integration seam with rateCard).
    final pool = [_v('a')];
    final cards = {'a': _card(dueInDays: -1, now: now)};
    Srs.rate(cards['a']!, Srs.good, now: now.add(const Duration(days: 1)));
    final plan = SessionPlanner.plan(
        pool: pool,
        cards: cards,
        wordMistakes: {},
        newBudget: 5,
        now: now.add(const Duration(days: 1)));
    expect(plan.reviewCount, 0,
        reason: 'the fresh interval pushed the card out of the due window');
  });
}
