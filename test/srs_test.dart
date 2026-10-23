// SRS engine tests (v4.0): interval math, learning steps, lapses, clamps.
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/srs.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);

  CardData fresh() => CardData();

  test('first "good" schedules for tomorrow and moves to review', () {
    final c = fresh();
    Srs.rate(c, Srs.good, now: t0);
    expect(c.intervalDays, 1);
    expect(c.state, 'review');
    expect(c.dueEpochMs, t0.millisecondsSinceEpoch + 1 * Srs.dayMs);
    expect(c.reps, 1);
  });

  test('"again" puts the card in learning with a 10-minute step', () {
    final c = fresh();
    Srs.rate(c, Srs.again, now: t0);
    expect(c.state, 'learning');
    expect(c.intervalDays, 0);
    expect(c.dueEpochMs - t0.millisecondsSinceEpoch, Srs.tenMinMs);
    expect(c.lapses, 1);
  });

  test('"hard" on a new card also uses the 10-minute learning step', () {
    final c = fresh();
    Srs.rate(c, Srs.hard, now: t0);
    expect(c.state, 'learning');
    expect(c.dueEpochMs - t0.millisecondsSinceEpoch, Srs.tenMinMs);
  });

  test('"good" grows intervals by ease', () {
    final c = fresh();
    Srs.rate(c, Srs.good, now: t0); // 1d
    Srs.rate(c, Srs.good, now: t0); // 1 * 2.5 = 3 (rounded)
    expect(c.intervalDays, 3);
    Srs.rate(c, Srs.good, now: t0); // 3 * 2.5 = 8 (rounded)
    expect(c.intervalDays, 8);
  });

  test('"easy" accelerates and raises ease, "hard" lowers it', () {
    final c = fresh();
    Srs.rate(c, Srs.easy, now: t0);
    expect(c.intervalDays, 3);
    expect(c.ease, closeTo(2.55, 1e-9));

    final d = fresh();
    Srs.rate(d, Srs.good, now: t0);
    Srs.rate(d, Srs.hard, now: t0);
    expect(d.ease, closeTo(2.45, 1e-9));
    // 1d * 1.2 = 1 (rounds to 1, min clamp)
    expect(d.intervalDays, greaterThanOrEqualTo(1));
  });

  test('ease is clamped to [1.3, 3.0] under repeated lapses', () {
    final c = fresh();
    for (var i = 0; i < 20; i++) {
      Srs.rate(c, Srs.again, now: t0);
    }
    expect(c.ease, 1.3);
    expect(c.lapses, 20);
  });

  test('a reviewed card lapses back to learning on "again"', () {
    final c = fresh();
    Srs.rate(c, Srs.good, now: t0);
    Srs.rate(c, Srs.good, now: t0);
    expect(c.state, 'review');
    Srs.rate(c, Srs.again, now: t0);
    expect(c.state, 'learning');
    expect(c.intervalDays, 0);
    expect(c.lapses, 1);
  });

  test('intervals are capped at 365 days', () {
    final c = fresh();
    c.ease = 3.0;
    c.intervalDays = 300;
    Srs.rate(c, Srs.good, now: t0);
    expect(c.intervalDays, 365);
  });

  test('hintFor matches what rate would schedule', () {
    for (final ivl in [0, 1, 3, 10]) {
      for (final q in [Srs.again, Srs.hard, Srs.good, Srs.easy]) {
        final a = fresh()..intervalDays = ivl;
        final b = fresh()..intervalDays = ivl;
        Srs.rate(a, q, now: t0);
        final hint = Srs.hintFor(b, q);
        if (a.intervalDays == 0) {
          expect(hint, '10m');
        } else if (a.intervalDays == 1) {
          expect(hint, anyOf('1d', '10m'));
        } else {
          expect(hint, '${a.intervalDays}d');
        }
      }
    }
  });

  test('round-trips through JSON without loss', () {
    final c = fresh();
    Srs.rate(c, Srs.good, now: t0);
    Srs.rate(c, Srs.good, now: t0);
    final j = c.toJson();
    final d = CardData.fromJson(j);
    expect(d.ease, c.ease);
    expect(d.intervalDays, c.intervalDays);
    expect(d.dueEpochMs, c.dueEpochMs);
    expect(d.reps, c.reps);
    expect(d.lapses, c.lapses);
    expect(d.state, c.state);
  });
}
