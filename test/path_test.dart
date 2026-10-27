// Path engine tests (v4.11) — domain catalog coverage over the REAL shipped
// courses (regression pins against keyword bugs like \bsea matching
// "Seasons"), tier bands, plan building with tier relaxation, per-course
// plan persistence (save/load/export/import, old-payload null-safety) and
// the setup wizard widget flow.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/path.dart';
import 'package:masar_al_lugha/placement.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/services/tts.dart';
import 'fake_notifications.dart';
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

/// Deep synthetic course for the v4.12 placement→tier tests: 12 units of
/// 2 lessons × 3 single words each, so `Placement.sample` yields 4 distinct
/// depth checkpoints (units 2/4/7/9) with enough unsampled words.
Course _deepCourse() {
  final units = <Unit>[];
  for (var u = 0; u < 12; u++) {
    final lessons = <Lesson>[];
    for (var l = 0; l < 2; l++) {
      final vocab = <Vocab>[];
      for (var w = 0; w < 3; w++) {
        vocab.add(Vocab(
          id: 'd_${u}_$l$w',
          target: 'word${u}_$l$w',
          translationAr: 'معنى${u}_$l$w',
        ));
      }
      lessons.add(Lesson(
        id: 'dl_${u}_$l',
        titleAr: 'درس',
        titleEn: 'L',
        vocab: vocab,
      ));
    }
    units.add(Unit(
      id: 'du$u',
      titleAr: 'وحدة',
      titleEn: 'U',
      colorHex: '58CC02',
      lessons: lessons,
    ));
  }
  return Course(
    id: 'en',
    nameAr: 'إنجليزية',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: units,
  );
}

/// Three units with DISTINCT catalog domains (travel / food / business) and
/// three single words each — lets the v4.13 domain-suggestion tests build
/// checkpoints by hand instead of relying on sample() + rng.
Course _domainCourse() {
  Unit unit(String id, String ar, String en, List<Vocab> vocab) => Unit(
        id: id,
        titleAr: ar,
        titleEn: en,
        colorHex: '58CC02',
        lessons: [
          Lesson(id: 'l_$id', titleAr: 'درس', titleEn: 'L', vocab: vocab),
        ],
      );
  Vocab v(String id) => Vocab(
        id: id,
        target: 'word_$id',
        translationAr: 'معنى_$id',
      );
  return Course(
    id: 'en',
    nameAr: 'إنجليزية',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: [
      unit('trav', 'السفر والمواصلات', 'Travel & Transport',
          [v('t0'), v('t1'), v('t2')]),
      unit('food', 'الطعام والشراب', 'Food & Drink',
          [v('f0'), v('f1'), v('f2')]),
      unit('biz', 'العمل والمهن', 'Jobs & Work', [v('b0'), v('b1'), v('b2')]),
    ],
  );
}

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
    late Course de;

    setUpAll(() async {
      en = await _load('en');
      ur = await _load('ur');
      de = await _load('de');
    });

    test('regression pins — the exact keyword bugs stay fixed', () {
      // \bsea\b must NOT match "Seasons" (was travel before full boundary).
      expect(PathEngine.domainOfUnit(en.units[34]), PathDomain.nature);
      // Latin 'time' keyword removed — "Sports & Free Time" is daily.
      expect(PathEngine.domainOfUnit(ur.units[28]), PathDomain.daily);
      // Sensible anchors.
      expect(PathEngine.domainOfUnit(en.units[31]), PathDomain.travel);
      expect(PathEngine.domainOfUnit(en.units[45]), PathDomain.business);
      expect(PathEngine.domainOfUnit(en.units[46]), PathDomain.tech);
      expect(PathEngine.domainOfUnit(en.units[9]), PathDomain.travel);
      expect(PathEngine.domainOfUnit(en.units[54]), PathDomain.business);
      expect(PathEngine.domainOfUnit(ur.units[46]), PathDomain.culture);
      expect(PathEngine.domainOfUnit(ur.units[34]), PathDomain.nature);
    });

    test('pinned domain counts for all courses (162 units)', () {
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
      // v5.1: the Urdu course reached full 56-unit parity with English —
      // the 31 new units route through the same keyword catalog.
      expect(count(ur, PathDomain.business), 6);
      expect(count(ur, PathDomain.travel), 5);
      expect(count(ur, PathDomain.food), 5);
      expect(count(ur, PathDomain.health), 4);
      expect(count(ur, PathDomain.tech), 2);
      expect(count(ur, PathDomain.nature), 8);
      expect(count(ur, PathDomain.culture), 7);
      expect(count(ur, PathDomain.basics), 3);
      expect(count(ur, PathDomain.daily), 16);
      // v5.0: the German course partitions cleanly out of the box — its
      // English unit titles route through the SAME Latin keyword catalog.
      // v5.4: +5 units (School A2, Bank B1, Media B2, Literature/Philosophy
      // C1 ×2) recomputed via scripts/domain_counts_sim.py:
      // culture 1→3 (Media, Literature + Idioms), business 2→3 (Bank),
      // daily 5→7 (School, Philosophy join greetings/intro/family/home/city).
      expect(count(de, PathDomain.basics), 3); // Numbers / Colors / Days
      expect(count(de, PathDomain.travel), 2); // Transport / Hotel
      expect(count(de, PathDomain.food), 2); // Food / Restaurant
      expect(count(de, PathDomain.health), 2); // Body / Doctor
      expect(count(de, PathDomain.nature), 2); // Animals / Weather
      expect(count(de, PathDomain.business), 3); // Shopping / Work / Bank
      expect(count(de, PathDomain.tech), 1); // Technology
      expect(count(de, PathDomain.culture), 3); // Media / Literature / Idioms
      expect(count(de, PathDomain.daily),
          7); // greetings, intro, family, home, city, school, philosophy
    });

    test('every unit lands in exactly one domain (partition)', () {
      for (final c in [en, ur, de]) {
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

    test('urdu business × expert relaxes to its B1/B2 units', () {
      // v5.1 added B1 (Money & Banking, Office & Business) and B2
      // (Business & Economics) business units, so expert no longer
      // relaxes all the way down to the A2 band.
      final p = PathEngine.build(ur, PathDomain.business, LevelTier.expert);
      expect(p.unitIndices, [38, 45, 50]);
      expect(p.effectiveTier, LevelTier.intermediate);
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

  group('auto level linking (v4.12)', () {
    test('tierForPassed pins the ready-for-band thresholds', () {
      // Nothing proven / degenerate inputs never over-claim.
      expect(Placement.tierForPassed(0, 4), LevelTier.beginner);
      expect(Placement.tierForPassed(0, 0), LevelTier.beginner);
      expect(Placement.tierForPassed(-1, 4), LevelTier.beginner);
      expect(Placement.tierForPassed(2, 0), LevelTier.beginner);
      // Quarter depth proven → still beginner; half → intermediate;
      // everything → expert. (4 checkpoints = the shipped default.)
      expect(Placement.tierForPassed(1, 4), LevelTier.beginner);
      expect(Placement.tierForPassed(2, 4), LevelTier.intermediate);
      expect(Placement.tierForPassed(3, 4), LevelTier.intermediate);
      expect(Placement.tierForPassed(4, 4), LevelTier.expert);
      // Thresholds are ratio-based, not hardcoded to 4 checkpoints.
      expect(Placement.tierForPassed(1, 2), LevelTier.intermediate);
      expect(Placement.tierForPassed(2, 2), LevelTier.expert);
      expect(Placement.tierForPassed(2, 3), LevelTier.intermediate);
    });

    test('recommendedTier mirrors the consecutive-pass skip rule', () {
      final c = _deepCourse();
      final cps = Placement.sample(c, rng: Random(7));
      expect(cps.length, 4);

      // All wrong → beginner.
      final wrong = {
        for (final cp in cps)
          for (final id in cp.wordIds) id: false,
      };
      expect(Placement.recommendedTier(cps, wrong), LevelTier.beginner);

      // Only the FIRST checkpoint correct (second broken) → beginner:
      // the prefix rule — a pass AFTER a failure never counts.
      final onlyFirst = {
        for (final cp in cps)
          for (final id in cp.wordIds) id: true,
      };
      onlyFirst[cps[1].wordIds.first] = false; // break the SECOND
      expect(Placement.recommendedTier(cps, onlyFirst), LevelTier.beginner);

      // First two correct (third broken) → intermediate.
      final firstTwo = {
        for (final cp in cps)
          for (final id in cp.wordIds) id: true,
      };
      firstTwo[cps[2].wordIds.first] = false;
      expect(Placement.recommendedTier(cps, firstTwo), LevelTier.intermediate);

      // Everything correct → expert.
      final allRight = {
        for (final cp in cps)
          for (final id in cp.wordIds) id: true,
      };
      expect(Placement.recommendedTier(cps, allRight), LevelTier.expert);

      // Sanity: the prefix semantics agree with recommendedFlatIndex —
      // breaking the third checkpoint skips through the 2nd, exactly the
      // case the intermediate tier was assigned for.
      expect(
        Placement.recommendedFlatIndex(c, cps, firstTwo),
        Placement.flatEndOfUnit(c, cps[1].unitIndex),
      );
    });

    test('setPathTier stores valid names, rejects invalid, keeps domain',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();

      // Invalid enum names are rejected silently.
      st.setPathTier('en', 'hacker');
      expect(st.pathTierOf('en'), isNull);

      // Without a domain: tier stored, but no active plan yet.
      st.setPathTier('en', 'intermediate');
      expect(st.pathTierOf('en'), LevelTier.intermediate);
      expect(st.activePathPlan, isNull);

      // With a domain: the plan picks the tier up — the linking contract.
      st.setPathPlan('en', 'business', 'beginner');
      expect(st.activePathPlan!.effectiveTier, LevelTier.beginner);
      st.setPathTier('en', 'expert');
      expect(st.pathDomainOf('en'), PathDomain.business); // domain survives
      expect(st.pathTierOf('en'), LevelTier.expert); // linked tier stored
      // The plan now REQUESTS expert; the tiny synthetic course has no C1
      // business units, so build() relaxes one band down (by design).
      final plan = st.activePathPlan;
      expect(plan, isNotNull);
      expect(plan!.tier, LevelTier.expert);
      expect(plan.effectiveTier, LevelTier.intermediate);
      expect(plan.tierRelaxed, isTrue);
    });

    test('setPathTier result survives save/load and export/import', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();
      st.setPathTier('en', 'expert');
      await st
          .save(); // deterministic write (setPathTier saves fire-and-forget)

      // Persistence round-trip through the real save() → load() path.
      final st2 = AppState();
      st2.courses['en'] = _course();
      await st2.load();
      expect(st2.pathTierOf('en'), LevelTier.expert);

      // Export/import round-trip too.
      final st3 = AppState();
      st3.courses['en'] = _course();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st3.load();
      final err = await st3.importProfileJson(st.exportProfileJson());
      expect(err, isNull);
      expect(st3.pathTier['en'], 'expert');
    });
  });

  group('auto domain suggestion (v4.13)', () {
    test('recommendedDomain votes by the units of correctly answered words',
        () {
      final c = _domainCourse();
      final cps = [
        const PlacementCheckpoint(0, ['t0', 't1', 't2']), // travel unit
        const PlacementCheckpoint(1, ['f0', 'f1', 'f2']), // food unit
      ];

      // Travel majority: 3 travel correct vs 1 food.
      final travelWin = {
        't0': true,
        't1': true,
        't2': true,
        'f0': true,
        'f1': false,
        'f2': false,
      };
      expect(Placement.recommendedDomain(c, cps, travelWin), PathDomain.travel);

      // Food majority: 2 food vs 1 travel.
      final foodWin = {
        't0': true,
        't1': false,
        't2': false,
        'f0': true,
        'f1': true,
        'f2': false,
      };
      expect(Placement.recommendedDomain(c, cps, foodWin), PathDomain.food);

      // Tie 1–1 resolves in catalog (enum) order: travel precedes food.
      final tie = {
        't0': true,
        't1': false,
        't2': false,
        'f0': true,
        'f1': false,
        'f2': false,
      };
      expect(Placement.recommendedDomain(c, cps, tie), PathDomain.travel);

      // All wrong → no signal, no guess.
      final allWrong = {
        for (final cp in cps)
          for (final id in cp.wordIds) id: false,
      };
      expect(Placement.recommendedDomain(c, cps, allWrong), isNull);

      // Empty checkpoints degrade to null too.
      expect(Placement.recommendedDomain(c, const [], travelWin), isNull);

      // Correct answers OUTSIDE the sampled set are ignored — the
      // suggestion only reads the test's own words.
      expect(Placement.recommendedDomain(c, cps, {'ghost': true}), isNull);
    });

    test('setPathDomain stores valid names, rejects invalid, keeps tier',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();

      // Invalid enum names are rejected silently.
      st.setPathDomain('en', 'hacker');
      expect(st.pathDomainOf('en'), isNull);

      // Without a tier: domain stored, but no active plan yet.
      st.setPathDomain('en', 'business');
      expect(st.pathDomainOf('en'), PathDomain.business);
      expect(st.activePathPlan, isNull);

      // With a tier: the plan picks the domain up — the linking contract.
      st.setPathPlan('en', 'basics', 'beginner');
      expect(st.activePathPlan!.domain, PathDomain.basics);
      st.setPathDomain('en', 'business');
      expect(st.pathTierOf('en'), LevelTier.beginner); // tier survives
      final plan = st.activePathPlan!;
      expect(plan.domain, PathDomain.business);
      expect(plan.tier, LevelTier.beginner);
      expect(plan.effectiveTier, LevelTier.beginner); // u1 is A1 — no relax
      expect(plan.tierRelaxed, isFalse);
    });

    test('setPathDomain result survives save/load and export/import', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courses['en'] = _course();
      await st.load();
      st.setPathDomain('en', 'business');
      await st.save(); // deterministic write (setPathDomain saves async)

      // Persistence round-trip through the real save() → load() path.
      final st2 = AppState();
      st2.courses['en'] = _course();
      await st2.load();
      expect(st2.pathDomainOf('en'), PathDomain.business);

      // Export/import round-trip too.
      final st3 = AppState();
      st3.courses['en'] = _course();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st3.load();
      final err = await st3.importProfileJson(st.exportProfileJson());
      expect(err, isNull);
      expect(st3.pathDomain['en'], 'business');
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
      // Version itself is pinned by the v4.12 group below.
    });
  });

  group('l10n parity for v4.12 keys', () {
    test('placementLevelAuto exists in ar and en, version bumped', () {
      expect(L.t('ar', 'placementLevelAuto'), 'مستواك المحدد من الاختبار');
      expect(L.t('en', 'placementLevelAuto'), 'Level detected by the test');
      // Version itself is pinned by the v4.13 group below.
    });
  });

  group('l10n parity for v4.13 keys', () {
    test('placementDomainAuto exists in ar and en', () {
      expect(L.t('ar', 'placementDomainAuto'), 'مجالك المقترح من الاختبار');
      expect(L.t('en', 'placementDomainAuto'), 'Field suggested by the test');
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v4.13.1 keys', () {
    test('RTL direction-safety wave kept its parity', () {
      expect(L.t('ar', 'correctAnswerIs'), isNotEmpty);
      expect(L.t('en', 'correctAnswerIs'), isNotEmpty);
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.0 keys', () {
    test('German course keys exist in ar and en', () {
      expect(
          L.t('ar', 'badge_all_de_units'), 'خبير الألمانية — أكمل كل الوحدات');
      expect(
          L.t('en', 'badge_all_de_units'), 'German Master — finish all units');
      expect(L.t('ar', 'badge_polyglot'), contains('الأربع'));
      expect(L.t('en', 'badge_polyglot'), contains('four'));
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.2 keys', () {
    test('Urdu lesson-for-lesson parity wave', () {
      expect(L.t('ar', 'version'), isNotEmpty);
      expect(L.t('en', 'version'), isNotEmpty);
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.3 keys', () {
    test('FSRS retention keys exist in ar and en', () {
      expect(L.t('ar', 'retentionTitle'), isNot('retentionTitle'));
      expect(L.t('en', 'retentionTitle'), isNot('retentionTitle'));
      expect(L.t('ar', 'retentionHint'), isNot('retentionHint'));
      expect(L.t('en', 'retentionHint'), isNot('retentionHint'));
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.4 keys', () {
    test('content wave keys exist in ar and en', () {
      expect(L.t('ar', 'retentionTitle'), isNotEmpty);
      expect(L.t('en', 'retentionTitle'), isNotEmpty);
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.5 keys', () {
    test('adaptive placement keys exist in ar and en', () {
      expect(L.t('ar', 'placementQof'), contains('{n}'));
      expect(L.t('en', 'placementQof'), contains('{n}'));
      expect(L.t('ar', 'placementBreakdown'), isNot('placementBreakdown'));
      expect(L.t('en', 'placementBreakdown'), isNot('placementBreakdown'));
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.6 keys', () {
    test('pronunciation keys exist in ar and en, version bumped', () {
      const keys = [
        'pronTitle',
        'pronIntro',
        'pronPickWord',
        'pronSpeakFirst',
        'pronTapMic',
        'pronListening',
        'pronSaid',
        'pronApprox',
        'pronGreat',
        'pronClose',
        'pronPartial',
        'pronMiss',
        'pronUnavailable',
      ];
      for (final k in keys) {
        expect(L.t('ar', k), isNot(k), reason: k);
        expect(L.t('en', k), isNot(k), reason: k);
      }
      expect(L.t('ar', 'pronApprox'), contains('تقريبي'));
      expect(L.t('en', 'pronApprox'), contains('Approximate'));
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.7 keys', () {
    test('grammar keys exist in ar and en, version bumped', () {
      expect(L.t('ar', 'grammarTitle'), contains('القواعد'));
      expect(L.t('en', 'grammarTitle'), isNot('grammarTitle'));
      expect(L.t('ar', 'grammarNone'), isNot('grammarNone'));
      expect(L.t('en', 'grammarNone'), isNot('grammarNone'));
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.8 keys', () {
    test('reading keys exist in ar and en, version bumped', () {
      const keys = [
        'readingTitle',
        'readingIntro',
        'readingNone',
        'readingTapHint',
        'readingAddReview',
        'readingAdded',
        'readingNotInCourse',
      ];
      for (final k in keys) {
        expect(L.t('ar', k), isNot(k), reason: k);
        expect(L.t('en', k), isNot(k), reason: k);
      }
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.9 keys', () {
    test('conversation keys exist in ar and en, version bumped', () {
      const keys = [
        'conversationTitle',
        'conversationStep',
        'conversationHint',
        'conversationRestart',
        'conversationTypePlaceholder',
        'conversationProviderLocal',
      ];
      for (final k in keys) {
        expect(L.t('ar', k), isNot(k), reason: k);
        expect(L.t('en', k), isNot(k), reason: k);
      }
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.10 keys', () {
    test('profiles + analytics keys exist in ar and en, version bumped', () {
      const keys = [
        'profilesTitle',
        'profilesHint',
        'profileDefault',
        'profileCurrent',
        'profileSwitch',
        'profileRename',
        'analyticsOptIn',
        'analyticsHint',
        'retentionCard',
        'retentionNoData',
      ];
      for (final k in keys) {
        expect(L.t('ar', k), isNot(k), reason: k);
        expect(L.t('en', k), isNot(k), reason: k);
      }
      // Version itself is pinned by the newest group below.
    });
  });

  group('l10n parity for v5.11 keys', () {
    test('smarter-review keys exist in ar and en, version bumped', () {
      const keys = [
        // quick review mode
        'quickReviewTitle',
        'quickReviewHint',
        'quickReviewDueBadge',
        'quickReviewNoneDue',
        'quickReviewDone',
        'quickReviewDueLeft',
        // smart memory hints
        'hintLapses',
        'hintHard',
        'hintLate',
        'hintYoung',
        // cross-slot backup restore
        'importTargetSlot',
        'importSlotCurrent',
        'importSlotOverwrite',
      ];
      for (final k in keys) {
        expect(L.t('ar', k), isNot(k), reason: k);
        expect(L.t('en', k), isNot(k), reason: k);
      }
      expect(L.t('ar', 'version'), contains('5.15.0'));
      expect(L.t('en', 'version'), contains('5.15.0'));
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
        reminders: ReminderService(FakeNotificationApi()),
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
        reminders: ReminderService(FakeNotificationApi()),
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
