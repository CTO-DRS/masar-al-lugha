// Storage-layer tests (v4.0, Wave 3): prove the SharedPreferences JSON
// profile scales to the heaviest plausible profile (~3,000 SRS cards) with
// correct round-trip fidelity — the measurement cited in docs/ARCHITECTURE.md §2.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/models.dart';

CardData _card(int i) => CardData(
      ease: 2.3 + (i % 10) / 20,
      intervalDays: i % 90,
      dueEpochMs: 1700000000000 + i * 60000,
      reps: i % 30,
      lapses: i % 4,
      state: i % 3 == 0 ? 'review' : 'learning',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('3,000-card profile round-trips losslessly', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    for (var i = 0; i < 3000; i++) {
      st.cards['stress_w$i'] = _card(i);
      if (i % 5 == 0) st.wordMistakes['stress_w$i'] = i % 7;
      if (i % 11 == 0) st.lessonStars['stress_l$i'] = (i % 3) + 1;
    }

    final sw = Stopwatch()..start();
    await st.save();
    final encodeMs = sw.elapsedMilliseconds;

    final st2 = AppState();
    sw
      ..reset()
      ..start();
    await st2.load();
    final decodeMs = sw.elapsedMilliseconds;

    // Fidelity: every card survives with identical fields.
    expect(st2.cards.length, 3000);
    for (var i = 0; i < 3000; i++) {
      final a = st.cards['stress_w$i']!;
      final b = st2.cards['stress_w$i']!;
      expect(b.ease, a.ease, reason: 'ease mismatch at $i');
      expect(b.intervalDays, a.intervalDays, reason: 'interval mismatch at $i');
      expect(b.dueEpochMs, a.dueEpochMs, reason: 'due mismatch at $i');
      expect(b.reps, a.reps, reason: 'reps mismatch at $i');
      expect(b.lapses, a.lapses, reason: 'lapses mismatch at $i');
      expect(b.state, a.state, reason: 'state mismatch at $i');
    }
    expect(st2.lessonStars.length, st.lessonStars.length);
    expect(st2.wordMistakes.length, st.wordMistakes.length);

    // Budget: encode+decode of the heaviest profile stays far below a frame
    // budget on the order of tens of milliseconds — the claim made in
    // ARCHITECTURE.md §2 ("single-digit to low-tens of milliseconds").
    // Generous CI headroom: 150 ms per direction.
    expect(encodeMs, lessThan(150), reason: 'save() too slow for 3000 cards');
    expect(decodeMs, lessThan(150), reason: 'load() too slow for 3000 cards');
  });

  test('profile JSON size stays in the hundreds-of-KB range at 3,000 cards',
      () async {
    final st = AppState();
    for (var i = 0; i < 3000; i++) {
      st.cards['stress_w$i'] = _card(i);
    }
    final encoded = jsonEncode(st.cards.map((k, v) => MapEntry(k, v.toJson())));
    // ARCHITECTURE.md §2 claims ~350 KB — assert well under 1 MB (the
    // documented re-evaluation threshold for switching to SQLite).
    expect(encoded.length, lessThan(1 << 20));
    expect(
        encoded.length, greaterThan(100 << 10)); // sanity: really ~3000 cards
  });
}
