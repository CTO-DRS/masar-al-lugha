// v5.18 (Phase-2 Batch C): error-kind classifier tests.
//
// The classifier records ONLY real scored mistakes, bounded both per word
// (kinds) and per profile (words), is per-profile (no bleed on switch), is
// wiped by resetAll, and the course-scoped aggregate never mixes courses.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/remediation.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final st = AppState();
  st.courses['en'] = Course(
    id: 'en',
    nameAr: 'إنجليزي',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: [
      Unit(
        id: 'u1',
        titleAr: 'وحدة',
        titleEn: 'Unit',
        colorHex: '#58CC02',
        cefr: 'A1',
        lessons: [
          Lesson(
            id: 'u1_l1',
            titleAr: 'درس',
            titleEn: 'Lesson',
            vocab: List.generate(
              3,
              (i) => Vocab(
                  id: 'en_h_w$i', target: 'word$i', translationAr: 'معنى $i'),
            ),
          ),
        ],
      ),
    ],
  );
  st.courseId = 'en';
  return st;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('error-kind classifier (v5.18 Batch C)', () {
    test('aggregates totals per kind, most-missed first', () async {
      final st = await _state();
      st.recordErrorKind('en_h_w0', 'mcq');
      st.recordErrorKind('en_h_w0', 'mcq');
      st.recordErrorKind('en_h_w0', 'dictation');
      final rows = st.errorKindTotals();
      expect(rows.first.key, 'mcq');
      expect(rows.first.value, 2);
      expect(rows.any((r) => r.key == 'dictation'), isTrue);
    });

    test('foreign-course vocab never pollutes the current course view',
        () async {
      final st = await _state();
      st.recordErrorKind('fr_u1_w1', 'mcq');
      st.recordErrorKind('de_u1_w1', 'listen');
      // The active course is en — foreign rows are filtered out.
      expect(st.errorKindTotals(), isEmpty);
    });

    test('per-word kind cap keeps the most-missed kinds deterministically',
        () async {
      final st = await _state();
      // Seven distinct kinds on one word — the cap keeps six.
      for (final k in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        st.recordErrorKind('en_h_w0', k);
      }
      expect(st.errorKinds['en_h_w0']!.length, 6);
      // All counts tie at 1 — lexicographic tiebreak drops the last key.
      expect(st.errorKinds['en_h_w0']!.containsKey('g'), isFalse);
    });

    test('the word budget evicts and never exceeds the cap', () async {
      final st = await _state();
      // The first word carries a small total, so it loses its slot first.
      st.recordErrorKind('en_h_w0', 'mcq');
      for (var i = 0; i < AppState.maxErrorKindWords + 5; i++) {
        st.recordErrorKind('zz_w$i', 'listen');
      }
      expect(st.errorKinds.length,
          lessThanOrEqualTo(AppState.maxErrorKindWords + 1));
      expect(st.errorKinds.containsKey('en_h_w0'), isFalse,
          reason: 'the 1-mistake tracker is evicted by heavier ones');
    });

    test('resetAll wipes the classifier (H-2 lesson)', () async {
      final st = await _state();
      st.recordErrorKind('en_h_w0', 'mcq');
      st.resetAll();
      expect(st.errorKinds, isEmpty);
    });

    test('switchProfile does not bleed error kinds into the new slot',
        () async {
      final st = await _state();
      st.recordErrorKind('en_h_w0', 'mcq');
      await st.save();
      await st.switchProfile(2);
      expect(st.errorKinds, isEmpty,
          reason: 'slot 2 starts clean — no bleed from slot 1');
      st.recordErrorKind('en_h_w0', 'listen');
      expect(st.errorKinds['en_h_w0']!['listen'], 1);
      await st.save();
      await st.switchProfile(1);
      expect(st.errorKinds['en_h_w0']!['mcq'], 1,
          reason: 'slot 1 still carries its own classifier data');
    });

    test('kindLabelKey covers every kind with a stable l10n key', () {
      for (final k in [
        'mcq',
        'reverse',
        'listen',
        'build',
        'match',
        'picToWord',
        'wordToPic',
        'fillblank',
        'truefalse',
        'dictation',
        'listenComp',
        'grammar',
      ]) {
        final key = kindLabelKey(k);
        expect(key, startsWith('kind'));
        // Both locales resolve the key (never falls back to the raw key).
        expect(L.t('ar', key), isNot(key));
        expect(L.t('en', key), isNot(key));
      }
      expect(kindLabelKey('mystery'), 'kindOther');
      expect(L.t('ar', 'kindOther'), isNot('kindOther'));
    });

    test('a live remediation target marks its pattern recurring', () async {
      final st = await _state();
      final now = DateTime.now();
      Remediation.recordLapse(
          st.lapseLog, 'en_h_w0', now.subtract(const Duration(days: 2)));
      Remediation.recordLapse(st.lapseLog, 'en_h_w0', now);
      st.recordErrorKind('en_h_w0', 'mcq');
      expect(Remediation.isTarget(st.lapseLog, 'en_h_w0'), isTrue);
      expect(st.errorKindTotals().first.key, 'mcq');
    });
  });
}
