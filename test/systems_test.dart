// Systems wave tests (v5.10): local multi-profile slots, opt-in analytics
// (retention metric), and the honest OFF-by-default contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/profile_store.dart';
import 'package:masar_al_lugha/insights.dart';
import 'package:masar_al_lugha/srs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('profiles: slots are isolated and switching preserves each one',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();
    expect(st.profileSlot, 1);

    // slot 1: some real progress
    st.rateCard('word_a', Srs.good);
    await st.save();
    final slot1Xp = st.cards['word_a']!.intervalDays;

    // switch to slot 2 — a fresh learner
    await st.switchProfile(2);
    expect(st.profileSlot, 2);
    expect(st.cards, isEmpty);

    st.rateCard('word_b', Srs.hard);
    await st.save();

    // switch back — slot 1 data intact, slot 2 data gone
    await st.switchProfile(1);
    expect(st.cards.containsKey('word_a'), isTrue);
    expect(st.cards.containsKey('word_b'), isFalse);
    expect(st.cards['word_a']!.intervalDays, slot1Xp);

    // and slot 2 still holds its own card
    await st.switchProfile(2);
    expect(st.cards.containsKey('word_b'), isTrue);
    expect(st.cards.containsKey('word_a'), isFalse);
  });

  test('switchProfile clamps and ignores same-slot switches', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();
    await st.switchProfile(99);
    expect(st.profileSlot, ProfileStore.maxProfiles);
    await st.switchProfile(0);
    expect(st.profileSlot, 1);
    await st.switchProfile(1);
    expect(st.profileSlot, 1);
  });

  test('profile names persist across a fresh load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();
    await st.renameProfile(2, 'سارة');
    await st.renameProfile(1, ''); // empty clears
    expect(st.profileNames[2], 'سارة');
    expect(st.profileNames.containsKey(1), isFalse);

    final st2 = AppState();
    await st2.load();
    expect(st2.profileNames[2], 'سارة');
    expect(st2.profileNames.containsKey(1), isFalse);
  });

  test('renameProfile trims and caps the name length', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();
    await st.renameProfile(3, '  أحمد محمد عبدالرحمن الشمري الطويل جدا  ');
    expect(st.profileNames[3]!.length, lessThanOrEqualTo(24));
    expect(st.profileNames[3], startsWith('أحمد'));
  });

  test('analytics opt-in is OFF by default and rides export/import', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();
    expect(st.analyticsOptIn, isFalse); // honest default

    st.setAnalyticsOptIn(true);
    final st2 = AppState();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await st2.load();
    final err = await st2.importProfileJson(st.exportProfileJson());
    expect(err, isNull);
    expect(st2.analyticsOptIn, isTrue);
  });

  group('RetentionStats.dayReturnRate (local, opt-in-gated upstream)', () {
    String d(int offset) {
      final day = DateTime(2026, 1, 1).add(Duration(days: offset));
      return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    }

    test('returns null without evidence (0 or 1 active day)', () {
      expect(RetentionStats.dayReturnRate({}, DateTime(2026, 1, 20)), isNull);
      expect(RetentionStats.dayReturnRate({d(1): 30}, DateTime(2026, 1, 20)),
          isNull);
    });

    test('a perfect daily streak returns 1.0', () {
      final log = {d(0): 20, d(1): 20, d(2): 20, d(3): 20};
      expect(RetentionStats.dayReturnRate(log, DateTime(2026, 1, 20)), 1.0);
    });

    test('gaps count against the rate', () {
      // 4 active days, 2 of them followed by a next active day → 2/3
      final log = {d(0): 20, d(1): 20, d(3): 20, d(4): 20};
      expect(RetentionStats.dayReturnRate(log, DateTime(2026, 1, 20)),
          closeTo(2 / 3, 1e-9));
    });

    test('zero-xp days are not active days', () {
      final log = {d(0): 20, d(1): 0, d(2): 20};
      // active days: 0 and 2 → not consecutive → 0/1
      expect(RetentionStats.dayReturnRate(log, DateTime(2026, 1, 20)), 0.0);
    });

    test('window caps at the last 14 active days', () {
      final log = <String, int>{};
      for (var i = 0; i < 30; i++) {
        log[d(i)] = 20;
      }
      // all consecutive → 1.0 regardless of the window
      expect(RetentionStats.dayReturnRate(log, DateTime(2026, 2, 20)), 1.0);
    });
  });
}
