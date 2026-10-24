// Path engine tests (v4.11) — domain catalog coverage over the REAL shipped
// courses (regression pins against keyword bugs like \bsea matching
// "Seasons"), tier bands, plan building with tier relaxation, per-course
// plan persistence (save/load/export/import, old-payload null-safety) and
// the setup wizard widget flow.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/path.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/services/tts.dart';
import 'package:masar_al_lugha/theme.dart';
import 'package:masar_al_lugha/screens/path_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Course> _load(String lang) async {
  final raw = await rootBundle.loadString('assets/data/course_$lang.json');
  return Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

// Synthetic course for state + widget tests (deterministic, no assets).
Course _course() => Course(
      id: 'en',
      nameAr: 'إنجليزية',
      nameEn: 'English',
      flag: '🇬🇧',
      ttsLang: 'en-US',
      units: [
        const Unit(
          id: 'u1',
          titleAr: 'العمل والمهن',
          titleEn: 'Jobs & Work',
          colorHex: '#4CAF50',
          cefr: 'A1',
          lessons: [
            Lesson(id: 'l1', titleAr: 'أ', titleEn: 'a', vocab: [
              Vocab(id: 'w1', target: 'work', translationAr: 'عمل'),
              Vocab(id: 'w2', target: 'job', translationAr: 'مهنة'),
            ]),
          ],
        ),
        const Unit(
          id: 'u2',
          titleAr: 'المال والبنك',
          titleEn: 'Money & Banking',
          colorHex: '#2196F3',
          cefr: 'B1',
          lessons: [
            Lesson(
                id: 'l2',
                titleAr: 'ب',
                titleEn: 'b',
                vocab: [Vocab(id: 'w3', target: 'bank', translationAr: 'بنك')]),
          ],
        ),
        const Unit(
          id: 'u3',
          titleAr: 'الأساسيات',
          titleEn: 'Basics',
          colorHex: '#FF9800',
          cefr: 'A1',
          lessons: [
            Lesson(id: 'l3', titleAr: 'ج', titleEn: 'c', vocab: [
              Vocab(id: 'w4', target: 'hello', translationAr: 'مرحبا'),
            ]),
          ],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cefr tiers', () {
    test('ranks are monotonic A1..C2, unknown ranks 0', () {
      expect(PathEngine.cefrRank('A1'), 0);
      expect(PathEngine.cefrRank('A2'), 1);
      expect(PathEngine.cefrRank('B1'), 2);
      expect(PathEngine.cefrRank('B2'), 3);
      expect(PathEngine.cefrRank('C1'), 4);
      expect(PathEngine.cefrRank('C2'), 5);
      expect(PathEngine.cefrRank('X9'), 0);
      expect(PathEngine.cefrRank(''), 0);
    });

    test('bands map to the three tiers', () {
      expect(PathEngine.tierOfCefr('A1'), LevelTier.beginner);
      expect(PathEngine.tierOfCefr('A2'), LevelTier.beginner);
      expect(PathEngine.tierOfCefr('B1'), LevelTier.intermediate);
      expect(PathEngine.tierOfCefr('B2'), LevelTier.intermediate);
      expect(PathEngine.tierOfCefr('C1'), LevelTier.expert);
      expect(PathEngine.tierOfCefr('C2'), LevelTier.expert);
      expect(PathEngine.cefrInTier('A2', LevelTier.beginner), isTrue);
      expect(PathEngine.cefrInTier('B1', LevelTier.beginner), isFalse);
    });

    test('name parsing degrades to null, never throws', () {
      expect(PathEngine.tierByName('intermediate'), LevelTier.intermediate);
      expect(PathEngine.tierByName('hacker'), isNull);
      expect(PathEngine.tierByName(null), isNull);
      expect(PathEngine.domainByName('business'), PathDomain.business);
      expect(PathEngine.domainByName('hacker'), isNull);
    });
  });

  group('domain catalog over the real courses', () {
    late Course en;
    late Course ur;

    setUpAll(() async {
      en = await _load('en');
      ur = await _load('ur');
    });

    test('regression pins — the exact keyword bugs stay fixed', () {
      // \bsea\b must NOT match "Seasons" (was travel before full boundary).
      expect(PathEngine.domainOfUnit(en.units[34]), PathDomain.nature);
      // Latin 'time' keyword removed — "Sports & Free Time" is daily.
      expect(PathEngine.domainOfUnit(ur.units[12]), PathDomain.daily);
      // Sensible anchors.
      expect(PathEngine.domainOfUnit(en.units[31]), PathDomain.travel);
      expect(PathEngine.domainOfUnit(en.units[45]), PathDomain.business);
      expect(PathEngine.domainOfUnit(en.units[46]), PathDomain.tech);
      expect(PathEngine.domainOfUnit(en.units[9]), PathDomain.travel);
      expect(PathEngine.domainOfUnit(en.units[54]), PathDomain.business);
      expect(PathEngine.domainOfUnit(ur.units[22]), PathDomain.culture);
      expect(PathEngine.domainOfUnit(ur.units[18]), PathDomain.nature);
    });

    test('pinned domain counts for both courses (81 units)', () {
      int count(Course c, PathDomain d) => PathEngine.domainUnits(c, d).length;
      expect(count(en, PathDomain.business), 7);
      expect(count(en, PathDomain.travel), 5);
      expect(count(en, PathDomain.food), 4);
      expect(count(en, PathDomain.health), 4);
      expect(count(en, PathDomain.tech), 2);
      expect(count(en, PathDomain.nature), 8);
      expect(count(en, PathDomain.culture), 4);
      expect(count(en, PathDomain.basics), 4);
      expect(count(en, PathDomain.daily), 18);
      expect(count(ur, PathDomain.business), 2);
      expect(count(ur, PathDomain.travel), 1);
      expect(count(ur, PathDomain.food), 3);
      expect(count(ur, PathDomain.health), 1);
      expect(count(ur, PathDomain.tech), 1);
      expect(count(ur, PathDomain.nature), 2);
      expect(count(ur, PathDomain.culture), 6);
      expect(count(ur, PathDomain.basics), 3);
      expect(count(ur, PathDomain.daily), 6);
    });

    test('every unit lands in exactly one domain (partition)', () {
      for (final c in [en, ur]) {
        final seen = <int, PathDomain>{};
        for (final d in PathDomain.values) {
          for (final i in PathEngine.domainUnits(c, d)) {
            expect(seen.containsKey(i), isFalse,
                reason: 'unit $i matched twice in ${c.id}');
            seen[i] = d;
          }
        }
        expect(seen.length, c.units.length, reason: c.id);
      }
    });
  });

  group('plan building', () {
    late Course en;
    late Course ur;

    setUpAll(() async {
      en = await _load('en');
      ur = await _load('ur');
    });

    test('business × intermediate picks B1/B2 units, ordered by CEFR', () {
      final p =
          PathEngine.build(en, PathDomain.business, LevelTier.intermediate);
      // B1: money&banking(32), office(44), law(45) + B2: business(50).
      expect(p.unitIndices, [32, 44, 45, 50]);
      expect(p.tier, LevelTier.intermediate);
      expect(p.effectiveTier, LevelTier.intermediate);
      expect(p.tierRelaxed, isFalse);
      expect(p.unitIndices, equals(p.unitIndices.toList()..sort()));
    });

    test('beginner keeps A1 business units', () {
      final p = PathEngine.build(en, PathDomain.business, LevelTier.beginner);
      expect(p.unitIndices, [12, 13]);
      expect(p.tierRelaxed, isFalse);
    });

    test('empty band relaxes downward — basics × expert', () {
      // Basics holds A1 units plus B1 'Calendar & Time' — expert relaxes
      // exactly ONE band down to intermediate and picks only that unit.
      final p = PathEngine.build(en, PathDomain.basics, LevelTier.expert);
      expect(p.unitIndices, [43]);
      expect(p.effectiveTier, LevelTier.intermediate);
      expect(p.tierRelaxed, isTrue);
    });

    test('urdu business × expert relaxes to its A2 units', () {
      final p = PathEngine.build(ur, PathDomain.business, LevelTier.expert);
      expect(p.unitIndices, [8, 11]); // A2 work units
      expect(p.effectiveTier, LevelTier.beginner);
      expect(p.tierRelaxed, isTrue);
    });

    test('counts match the picked units', () {
      final p =
          PathEngine.build(en, PathDomain.business, LevelTier.intermediate);
      var lessons = 0;
      var words = 0;
      for (final i in p.unitIndices) {
        for (final l in en.units[i].lessons) {
          lessons++;
          words += l.vocab.length;
        }
      }
      expect(p.lessonCount, lessons);
      expect(p.wordCount, words);
      expect(p.lessonCount, greaterThan(0));
    });
  });

  group('state persistence', () {
    test('setPathPlan stores valid names, rejects invalid ones', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();

      st.setPathPlan('en', 'hacker', 'beginner');
      expect(st.pathDomainOf('en'), isNull);
      st.setPathPlan('en', 'business', 'hacker');
      expect(st.pathTierOf('en'), isNull);

      st.setPathPlan('en', 'business', 'intermediate');
      expect(st.pathDomainOf('en'), PathDomain.business);
      expect(st.pathTierOf('en'), LevelTier.intermediate);
      expect(st.activePathPlan, isNotNull);
    });

    test('activePathPlan is course-scoped and null when unset', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();
      expect(st.activePathPlan, isNull);

      st.setPathPlan('en', 'business', 'intermediate');
      expect(st.activePathPlan!.domain, PathDomain.business);

      st.clearPathPlan('en');
      expect(st.activePathPlan, isNull);
      // Clearing again is a no-op.
      st.clearPathPlan('en');
      expect(st.activePathPlan, isNull);
    });

    test('export/import round trip restores the plan', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();
      st.setPathPlan('en', 'business', 'intermediate');

      final st2 = AppState();
      st2.courses['en'] = _course();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st2.load();
      final err = await st2.importProfileJson(st.exportProfileJson());
      expect(err, isNull);
      expect(st2.pathDomain['en'], 'business');
      expect(st2.pathTier['en'], 'intermediate');
      expect(st2.activePathPlan, isNotNull);
    });

    test('tampered tier names are dropped on import', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();
      st.setPathPlan('en', 'business', 'intermediate');
      final tampered =
          st.exportProfileJson().replaceFirst('intermediate', 'hacker');

      final st2 = AppState();
      st2.courses['en'] = _course();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st2.load();
      final err = await st2.importProfileJson(tampered);
      expect(err, isNull);
      expect(st2.pathDomain['en'], 'business'); // domain survives
      expect(st2.pathTier['en'], isNull); // bad tier dropped
      expect(st2.activePathPlan, isNull);
    });

    test('old payloads without path keys import cleanly', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();
      final payload = jsonEncode({
        'app': 'masar-al-lugha',
        'progress': {'xp': 5},
      });
      final err = await st.importProfileJson(payload);
      expect(err, isNull);
      expect(st.activePathPlan, isNull);
    });
  });

  group('l10n parity for v4.11 keys', () {
    test('every new key exists in ar and en, version bumped', () {
      const keys = [
        'pathSetupTitle', 'pathSetupIntro', 'pathDomainStep', //
        'pathLevelStep', 'pathDomainCount', 'pathPlanStats',
        'domainBasics', 'domainTravel', 'domainFood', 'domainHealth',
        'domainTech', 'domainNature', 'domainCulture', 'domainBusiness',
        'domainDaily', 'tierBeginner', 'tierIntermediate', 'tierExpert',
        'tierBeginnerSub', 'tierIntermediateSub', 'tierExpertSub',
        'tierRelaxedNote', 'pathPlacementHint', 'pathStartPlan',
        'pathPlanBanner', 'pathEditPlan', 'pathClearPlan', 'pathOtherUnits',
        'pathSetupBtn',
      ];
      for (final k in keys) {
        expect(L.t('ar', k), isNot(k), reason: k);
        expect(L.t('en', k), isNot(k), reason: k);
      }
      expect(L.t('ar', 'version'), contains('4.11.0'));
      expect(L.t('en', 'version'), contains('4.11.0'));
    });
  });

  group('path setup wizard widget', () {
    testWidgets('domain → tier → start stores the plan', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();

      await tester.pumpWidget(AppScope(
        state: st,
        tts: TtsService(),
        child: MaterialApp(
          theme: buildMasarTheme(dark: false),
          home: const Scaffold(body: PathSetupScreen()),
        ),
      ));
      // Mascot idles forever — pump fixed frames, never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 1: pick the business field (row 3 of the grid — ensure it is
      // scrolled into view before tapping).
      final domainCard = find.text(L.t('ar', 'domainBusiness'));
      await tester.ensureVisible(domainCard);
      await tester.pump();
      await tester.tap(domainCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 2: pick the intermediate level. Tier cards live below the
      // fold in a lazy ListView — drag until the element is built+visible.
      final tierCard = find.text(L.t('ar', 'tierIntermediate'));
      await tester.dragUntilVisible(
        tierCard,
        find.byType(ListView).first,
        const Offset(0, -140),
      );
      await tester.pump();
      await tester.tap(tierCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Start the plan.
      await tester.tap(find.text(L.t('ar', 'pathStartPlan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(st.pathDomain['en'], 'business');
      expect(st.pathTier['en'], 'intermediate');
    });

    testWidgets('start stays disabled until both steps are done',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();

      await tester.pumpWidget(AppScope(
        state: st,
        tts: TtsService(),
        child: MaterialApp(
          theme: buildMasarTheme(dark: false),
          home: const Scaffold(body: PathSetupScreen()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No domain yet → tapping start must be a no-op (disabled).
      await tester.tap(find.text(L.t('ar', 'pathStartPlan')),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(st.pathDomain['en'], isNull);
    });
  });
}
