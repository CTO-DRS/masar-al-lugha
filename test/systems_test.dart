// Systems wave tests (v5.10): local multi-profile slots, opt-in analytics
// (retention metric), and the honest OFF-by-default contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/profile_store.dart';
import 'package:masar_al_lugha/insights.dart';
import 'package:masar_al_lugha/srs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal injected course — unit tests run without main.dart, so AppState
/// starts with an empty course registry (same fixture pattern as
/// weak_words_test.dart). Real-shaped ids keep the import id-guard happy.
Course _course(String id, List<String> words) {
  return Course(
    id: id,
    nameAr: 'دورة $id',
    nameEn: 'Course $id',
    flag: '🌍',
    ttsLang: 'en-US',
    units: [
      Unit(
        id: '${id}_u_1',
        titleAr: 'وحدة 1',
        titleEn: 'Unit 1',
        colorHex: '#58CC02',
        lessons: [
          Lesson(
            id: '${id}_l_1',
            titleAr: 'درس 1',
            titleEn: 'Lesson 1',
            vocab: words
                .map((w) => Vocab(id: w, target: w, translationAr: 'معنى $w'))
                .toList(),
          ),
        ],
      ),
    ],
  );
}

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

  // ================= v5.11: cross-slot backup restore =====================
  group('v5.11 cross-slot backup restore', () {
    test('restoring into another slot leaves the current slot untouched',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      st.courses['en'] = _course('en', ['apple', 'banana']);

      // REAL vocab ids — the import drops unknown ids by design (the
      // foreign-profile guard), so fixtures must use course ids.
      final vidA = st.course.allVocab.first.id;
      final vidB = st.course.allVocab[1].id;

      // Slot 1: some progress, then take the backup snapshot.
      st.rateCard(vidA, Srs.good);
      st.addXp(30);
      await st.save();
      final backup = st.exportProfileJson();

      // MORE progress lands in slot 1 AFTER the snapshot — the restore
      // must not merge it into slot 2, and must not disturb slot 1.
      st.rateCard(vidB, Srs.good);
      st.addXp(5);
      await st.save();

      final err = await st.importProfileJson(backup, targetSlot: 2);
      expect(err, isNull);

      // Still the current slot, still the CURRENT data.
      expect(st.profileSlot, 1);
      expect(st.cards.containsKey(vidA), isTrue);
      expect(st.cards.containsKey(vidB), isTrue);
      expect(st.xp, 35);

      // The snapshot landed in slot 2 — vidA + xp 30, never vidB.
      await st.switchProfile(2);
      expect(st.profileSlot, 2);
      expect(st.cards.containsKey(vidA), isTrue);
      expect(st.cards.containsKey(vidB), isFalse);
      expect(st.xp, 30);
    });

    test('invalid payload fails without touching either slot', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      st.courses['en'] = _course('en', ['apple', 'banana']);
      st.rateCard(st.course.allVocab.first.id, Srs.good);
      await st.save();

      final err = await st.importProfileJson('not json at all', targetSlot: 3);
      expect(err, 'importInvalid');
      expect(st.profileSlot, 1);
      expect(st.cards, isNotEmpty);

      // Slot 3 stayed fresh — the failure path wrote nothing there.
      await st.switchProfile(3);
      expect(st.cards, isEmpty);
      expect(st.xp, 0);
    });
  });
}
