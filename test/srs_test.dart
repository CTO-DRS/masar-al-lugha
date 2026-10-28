// SRS engine tests — v5.3 rewrote the scheduler from SM-2-lite to a real
// FSRS-4.5 implementation: memory states (difficulty/stability), the
// power-law forgetting curve, a target-retention dial, and a one-time
// migration of pre-v5.3 cards. The old SM-2 interval-math tests were
// replaced because the algorithm itself was replaced (that is the point of
// this wave); interface-level guarantees (hint == rate outcome, 10-minute
// learning steps, no progress loss on migration) are pinned here.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/srs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);

  CardData fresh() => CardData();

  CardData legacyReview() => CardData(
        ease: 2.5,
        intervalDays: 10,
        dueEpochMs: t0.add(const Duration(days: 10)).millisecondsSinceEpoch,
        reps: 5,
        lapses: 1,
        state: 'review',
      );

  group('forgetting curve', () {
    test('R at t = stability is exactly the default target (0.9)', () {
      expect(
          Srs.retrievability(
              10, t0.millisecondsSinceEpoch - 10 * Srs.dayMs, t0),
          closeTo(0.90, 1e-9));
    });

    test('R decreases monotonically with elapsed time', () {
      final last = t0.millisecondsSinceEpoch;
      double r(num days) =>
          Srs.retrievability(10, last - (days * Srs.dayMs).round(), t0);
      expect(r(0), 1.0);
      expect(r(1), greaterThan(r(5)));
      expect(r(5), greaterThan(r(30)));
      expect(r(30), greaterThan(r(365)));
      expect(r(365), lessThan(0.35));
    });

    test('unseen state has no retrievability', () {
      expect(Srs.retrievability(0, t0.millisecondsSinceEpoch, t0), 0);
      expect(Srs.retrievability(10, 0, t0), 0);
    });

    test('interval math: ivl(S, 0.9) == round(S); dial moves it', () {
      expect(Srs.nextInterval(10, 0.90), 10);
      expect(Srs.nextInterval(3.7145, 0.90), 4);
      // lower target retention -> longer intervals, higher -> shorter
      expect(
          Srs.nextInterval(10, 0.80), greaterThan(Srs.nextInterval(10, 0.90)));
      expect(
          Srs.nextInterval(10, 0.90), greaterThan(Srs.nextInterval(10, 0.95)));
      // clamps
      expect(Srs.nextInterval(0.05, 0.90), 1);
      expect(Srs.nextInterval(99999, 0.90), Srs.maxIntervalDays);
    });
  });

  group('first rating initializes FSRS memory states', () {
    test('first "good" graduates to review with FSRS interval', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      expect(c.state, 'review');
      expect(c.intervalDays, 4); // round(w[2]) — honest FSRS-4.5 default
      expect(c.dueEpochMs, t0.millisecondsSinceEpoch + 4 * Srs.dayMs);
      expect(c.stability, closeTo(Srs.w[2], 1e-9));
      expect(c.difficulty, closeTo(Srs.w[4], 1e-9));
      expect(c.reps, 1);
      expect(c.lapses, 0);
      expect(c.lastReviewEpochMs, t0.millisecondsSinceEpoch);
      expect(c.hasFsrsState, isTrue);
    });

    test('first "easy" jumps much further than "good"', () {
      final c = fresh();
      Srs.rate(c, Srs.easy, now: t0);
      expect(c.state, 'review');
      expect(c.intervalDays, 14); // round(w[3] = 13.8206)
      expect(c.stability, closeTo(Srs.w[3], 1e-9));
    });

    test('first "again"/"hard" keep the 10-minute learning step', () {
      final a = fresh();
      Srs.rate(a, Srs.again, now: t0);
      expect(a.state, 'learning');
      expect(a.intervalDays, 0);
      expect(a.dueEpochMs - t0.millisecondsSinceEpoch, Srs.tenMinMs);
      expect(a.lapses, 1);
      expect(a.stability, closeTo(Srs.w[0], 1e-9));
      expect(a.difficulty, closeTo(Srs.w[4] + 2 * Srs.w[5], 1e-9)); // D0(again)

      final h = fresh();
      Srs.rate(h, Srs.hard, now: t0);
      expect(h.state, 'learning');
      expect(h.dueEpochMs - t0.millisecondsSinceEpoch, Srs.tenMinMs);
      expect(h.stability, closeTo(Srs.w[1], 1e-9));
    });

    test('initial stability orders again < hard < good < easy', () {
      final cards = [Srs.again, Srs.hard, Srs.good, Srs.easy].map((q) {
        final c = fresh();
        Srs.rate(c, q, now: t0);
        return c;
      }).toList()
        ..sort((a, b) => a.stability.compareTo(b.stability));
      // sort ascending → order must be again, hard, good, easy
      expect(cards[0].stability, closeTo(Srs.w[0], 1e-9));
      expect(cards[3].stability, closeTo(Srs.w[3], 1e-9));
      expect(cards[0].stability, lessThan(cards[1].stability));
      expect(cards[1].stability, lessThan(cards[2].stability));
      expect(cards[2].stability, lessThan(cards[3].stability));
    });
  });

  group('review-state dynamics', () {
    test('on-time "good" grows stability and the interval', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      final s1 = c.stability;
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 4)));
      expect(c.stability, greaterThan(s1 * 2)); // FSRS-4.5 default growth
      expect(c.state, 'review');
      expect(c.intervalDays, greaterThan(4));
    });

    test('"again" lapses a review card back to learning with 10m step', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 4)));
      final sBefore = c.stability;
      final dBefore = c.difficulty;
      Srs.rate(c, Srs.again, now: t0.add(const Duration(days: 18)));
      expect(c.state, 'learning');
      expect(c.intervalDays, 0);
      expect(
          c.dueEpochMs -
              t0.add(const Duration(days: 18)).millisecondsSinceEpoch,
          Srs.tenMinMs);
      expect(c.lapses, 1);
      expect(c.stability, lessThan(sBefore)); // post-lapse stability shrinks
      expect(c.difficulty, greaterThan(dBefore)); // again raises difficulty
    });

    test('post-lapse stability is far below recall stability', () {
      final good = fresh();
      Srs.rate(good, Srs.good, now: t0);
      Srs.rate(good, Srs.good, now: t0.add(const Duration(days: 4)));
      final sRecall = good.stability;

      final lapsed = fresh();
      Srs.rate(lapsed, Srs.good, now: t0);
      Srs.rate(lapsed, Srs.good, now: t0.add(const Duration(days: 4)));
      Srs.rate(lapsed, Srs.again, now: t0.add(const Duration(days: 18)));
      expect(lapsed.stability, lessThan(sRecall / 2));
    });

    test('a lapsed card graduates again after the re-show', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 4)));
      Srs.rate(c, Srs.again, now: t0.add(const Duration(days: 18)));
      expect(c.state, 'learning');
      final sAfterLapse = c.stability;
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 18, minutes: 5)));
      expect(c.state, 'review');
      expect(
          c.intervalDays, Srs.nextInterval(sAfterLapse, Srs.defaultRetention));
      expect(c.intervalDays, greaterThanOrEqualTo(1));
    });

    test('difficulty stays inside [1, 10] under abuse', () {
      final c = fresh();
      for (var i = 0; i < 20; i++) {
        Srs.rate(c, Srs.again, now: t0.add(Duration(minutes: 10 * i)));
      }
      expect(c.difficulty, lessThanOrEqualTo(10.0));
      expect(c.difficulty, greaterThanOrEqualTo(1.0));
      expect(c.difficulty, 10.0); // repeated again pushes it to the ceiling
      expect(c.stability, greaterThanOrEqualTo(0.1));
      expect(c.lapses, 20);
    });

    test('hard rates harder than good on identical cards', () {
      final a = fresh();
      Srs.rate(a, Srs.good, now: t0);
      Srs.rate(a, Srs.good, now: t0.add(const Duration(days: 4)));
      final b = fresh();
      Srs.rate(b, Srs.good, now: t0);
      Srs.rate(b, Srs.hard,
          now: b.stability > 0
              ? t0.add(const Duration(days: 4))
              : t0.add(const Duration(days: 4)));
      expect(b.difficulty, greaterThan(a.difficulty));
      expect(b.stability, lessThan(a.stability));
    });

    test('late review sees lower retrievability and adjusts stability', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      // give it real stability first
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 4)));
      final sOnTime = c.stability;
      // simulate the same card reviewed very late next round
      final lateCard = fresh();
      Srs.rate(lateCard, Srs.good, now: t0);
      Srs.rate(lateCard, Srs.good, now: t0.add(const Duration(days: 4)));
      lateCard.lastReviewEpochMs -= 30 * Srs.dayMs; // 30 days overdue anchor
      final rLate = Srs.retrievability(lateCard.stability,
          lateCard.lastReviewEpochMs, t0.add(const Duration(days: 34)));
      expect(rLate, lessThan(0.9));
      Srs.rate(lateCard, Srs.good, now: t0.add(const Duration(days: 34)));
      // successful retrieval at low R earns a large stability jump
      expect(lateCard.stability, greaterThan(sOnTime));
    });
  });

  group('target-retention dial', () {
    test('rate() honors the requested retention', () {
      final a = fresh();
      Srs.rate(a, Srs.good, now: t0, requestRetention: 0.80);
      expect(a.intervalDays, 9); // round(3.7145 / factor * (0.8^-2 - 1))
      final b = fresh();
      Srs.rate(b, Srs.good, now: t0, requestRetention: 0.95);
      expect(b.intervalDays, 2); // round(3.7145 / factor * (0.95^-2 - 1))
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      expect(c.intervalDays, 4);
    });

    test('out-of-range retention is clamped', () {
      final a = fresh();
      Srs.rate(a, Srs.good, now: t0, requestRetention: 0.10);
      expect(a.intervalDays, Srs.nextInterval(a.stability, Srs.minRetention));
      final b = fresh();
      Srs.rate(b, Srs.good, now: t0, requestRetention: 1.0);
      expect(b.intervalDays, Srs.nextInterval(b.stability, Srs.maxRetention));
    });
  });

  group('migration of pre-v5.3 cards', () {
    CardData legacyReviewCard() => CardData(
          ease: 2.5,
          intervalDays: 10,
          dueEpochMs: t0.add(const Duration(days: 10)).millisecondsSinceEpoch,
          reps: 5,
          lapses: 1,
          state: 'review',
        );

    test('review card: stability from ivl, difficulty from ease, due intact',
        () {
      final c = legacyReviewCard();
      Srs.migrateLegacy(c, now: t0);
      expect(c.stability, 10.0);
      expect(c.difficulty, closeTo(Srs.w[4], 1e-9)); // ease 2.5 → D0(good)
      expect(c.lastReviewEpochMs,
          t0.millisecondsSinceEpoch); // due(10d) - ivl(10d)
      // nothing else moves — zero progress loss
      expect(c.ease, 2.5);
      expect(c.intervalDays, 10);
      expect(c.dueEpochMs,
          t0.add(const Duration(days: 10)).millisecondsSinceEpoch);
      expect(c.reps, 5);
      expect(c.lapses, 1);
      expect(c.state, 'review');
      expect(c.hasFsrsState, isTrue);
    });

    test('learning card anchors on the good-init stability', () {
      final c = CardData(
        intervalDays: 0,
        dueEpochMs: t0.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        reps: 1,
        lapses: 1,
        state: 'learning',
      );
      Srs.migrateLegacy(c, now: t0);
      expect(c.stability, closeTo(Srs.w[2], 1e-9));
      expect(c.lastReviewEpochMs, t0.millisecondsSinceEpoch);
      expect(c.intervalDays, 0);
      expect(c.dueEpochMs,
          t0.add(const Duration(minutes: 10)).millisecondsSinceEpoch);
    });

    test('late card keeps a genuinely lower retrievability', () {
      final c = legacyReviewCard();
      // due was 3 days ago → the assumed last review is 13 days back
      final due = t0.subtract(const Duration(days: 3));
      c.dueEpochMs = due.millisecondsSinceEpoch;
      Srs.migrateLegacy(c, now: t0);
      expect(c.lastReviewEpochMs,
          due.subtract(const Duration(days: 10)).millisecondsSinceEpoch);
      final r = Srs.retrievability(c.stability, c.lastReviewEpochMs, t0);
      expect(r, lessThan(0.9));
    });

    test('future assumed last review is clamped to now', () {
      final c = legacyReviewCard();
      // due far in the future → due - ivl would land after "now"
      c.dueEpochMs = t0.add(const Duration(days: 40)).millisecondsSinceEpoch;
      Srs.migrateLegacy(c, now: t0);
      expect(c.lastReviewEpochMs, t0.millisecondsSinceEpoch);
    });

    test('migration is idempotent', () {
      final c = legacyReviewCard();
      Srs.migrateLegacy(c, now: t0);
      final s = c.stability;
      final d = c.difficulty;
      final last = c.lastReviewEpochMs;
      Srs.migrateLegacy(c, now: t0.add(const Duration(days: 1)));
      expect(c.stability, s);
      expect(c.difficulty, d);
      expect(c.lastReviewEpochMs, last);
    });

    test('an unstudied card stays untouched', () {
      final c = fresh();
      Srs.migrateLegacy(c, now: t0);
      expect(c.stability, 0);
      expect(c.difficulty, 0);
      expect(c.lastReviewEpochMs, 0);
      expect(c.hasFsrsState, isFalse);
    });

    test('rate() migrates automatically on the first post-update rating', () {
      final c = legacyReviewCard();
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 10)));
      expect(c.reps, 6);
      // S went 10 → 10·(1 + growth at R=0.9) ≈ 34.4 → interval 34
      expect(c.stability, closeTo(34.4, 0.15));
      expect(c.intervalDays, 34);
      expect(c.state, 'review');
      expect(
          c.dueEpochMs,
          t0.add(const Duration(days: 10)).millisecondsSinceEpoch +
              34 * Srs.dayMs);
    });
  });

  group('hintFor', () {
    CardData clone(CardData t) => CardData(
          ease: t.ease,
          intervalDays: t.intervalDays,
          dueEpochMs: t.dueEpochMs,
          reps: t.reps,
          lapses: t.lapses,
          state: t.state,
          difficulty: t.difficulty,
          stability: t.stability,
          lastReviewEpochMs: t.lastReviewEpochMs,
        );

    CardData rated(int q, {int? days}) {
      final c = fresh();
      Srs.rate(c, q, now: t0);
      if (days != null) {
        Srs.rate(c, q, now: t0.add(Duration(days: days)));
      }
      return c;
    }

    test('hintFor equals what rate would schedule (no mutation)', () {
      final templates = [
        fresh(),
        rated(Srs.again),
        rated(Srs.hard),
        rated(Srs.good),
        rated(Srs.easy),
        rated(Srs.good, days: 4),
        rated(Srs.good, days: 4),
        legacyReview(),
      ];
      for (final q in [Srs.again, Srs.hard, Srs.good, Srs.easy]) {
        for (final template in templates) {
          final a = clone(template);
          final b = clone(template);
          Srs.rate(a, q, now: t0);
          final hint = Srs.hintFor(b, q, now: t0);
          if (a.intervalDays <= 0) {
            expect(hint, '10m');
          } else {
            expect(hint, '${a.intervalDays}d');
          }
        }
      }
    });

    test('hintFor never mutates the card', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      final before = c.toJson().toString();
      Srs.hintFor(c, Srs.easy, now: t0);
      expect(c.toJson().toString(), before);
    });

    // v5.18 (Phase-2 Batch H): the brief pins "يحافظ على ترتيب الاستحقاق" —
    // a lapse re-shows its card FIRST (the 10-minute step) and never moves
    // ANY other card's due date. (Graduated intervals legitimately differ
    // per rating — "easy" jumps further — so rating order is not due order;
    // the pinned invariant is isolation, not monotonicity.)
    test('a lapse re-queues only its own card first, touching nobody else',
        () {
      final cards = [fresh(), fresh(), fresh(), fresh()];
      Srs.rate(cards[0], Srs.good, now: t0);
      Srs.rate(cards[1], Srs.good, now: t0.add(const Duration(days: 1)));
      Srs.rate(cards[2], Srs.easy, now: t0.add(const Duration(days: 2)));
      Srs.rate(cards[3], Srs.good, now: t0.add(const Duration(days: 3)));
      final duesBefore = cards.map((c) => c.dueEpochMs).toList();
      // A lapse on the FIRST card pulls only THAT card back to now+10min;
      // the others keep their due dates untouched.
      Srs.rate(cards[0], Srs.again, now: t0.add(const Duration(days: 4)));
      expect(cards[0].state, 'learning');
      expect(cards[0].dueEpochMs, lessThan(cards[1].dueEpochMs),
          reason: 'the lapsed card is due FIRST (10-minute step)');
      expect(cards[1].dueEpochMs, duesBefore[1]);
      expect(cards[2].dueEpochMs, duesBefore[2]);
      expect(cards[3].dueEpochMs, duesBefore[3]);
    });
  });

  group('JSON compatibility', () {
    test('round-trips the FSRS fields without loss', () {
      final c = fresh();
      Srs.rate(c, Srs.good, now: t0);
      Srs.rate(c, Srs.good, now: t0.add(const Duration(days: 4)));
      final d = CardData.fromJson(c.toJson());
      expect(d.ease, c.ease);
      expect(d.intervalDays, c.intervalDays);
      expect(d.dueEpochMs, c.dueEpochMs);
      expect(d.reps, c.reps);
      expect(d.lapses, c.lapses);
      expect(d.state, c.state);
      expect(d.difficulty, c.difficulty);
      expect(d.stability, c.stability);
      expect(d.lastReviewEpochMs, c.lastReviewEpochMs);
    });

    test('legacy payload without d/s/last loads as a migratable card', () {
      final d = CardData.fromJson({
        'ease': 2.6,
        'ivl': 3,
        'due': t0.millisecondsSinceEpoch,
        'reps': 2,
        'lapses': 0,
        'state': 'review',
      });
      expect(d.stability, 0);
      expect(d.difficulty, 0);
      expect(d.lastReviewEpochMs, 0);
      expect(d.hasFsrsState, isFalse);
      // and still schedules correctly through the migration path
      Srs.rate(d, Srs.good, now: t0);
      expect(d.state, 'review');
      expect(d.intervalDays, greaterThanOrEqualTo(1));
    });
  });

  group('AppState wiring', () {
    test('rateCard honors the retention target', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      st.setRetentionTarget(0.80);
      st.rateCard('w1', Srs.good);
      expect(st.cards['w1']!.intervalDays, 9);
      st.setRetentionTarget(Srs.defaultRetention);
      st.rateCard('w2', Srs.good); // back at the 0.90 default
      expect(st.cards['w2']!.intervalDays, 4);
    });

    test('setRetentionTarget clamps and rounds', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      st.setRetentionTarget(1.5);
      expect(st.retentionTarget, Srs.maxRetention);
      st.setRetentionTarget(0.1);
      expect(st.retentionTarget, Srs.minRetention);
      st.setRetentionTarget(0.876);
      expect(st.retentionTarget, 0.88);
    });

    test('retention target rides export/import', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      st.setRetentionTarget(0.85);
      final st2 = AppState();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st2.load();
      final err = await st2.importProfileJson(st.exportProfileJson());
      expect(err, isNull);
      expect(st2.retentionTarget, 0.85);
    });
  });
}
