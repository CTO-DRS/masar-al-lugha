# PROJECT AUDIT — Masar Al-Lugha v3.3 → v4.0

**Date:** 2026-10-24 · **Baseline commit:** `6553971` (v3.3.0+6) · **Auditor:** engineering pass (Wave 1)

## 1. Scope & Method

Full read of all 19 Dart source files (5,532 lines), Android manifest + Gradle config, CI
workflow, tests, and all three course JSONs (2986 vocab entries). Baseline gates were actually
executed on this machine:

| Gate | Result |
|---|---|
| `flutter pub get` | OK (Flutter 3.47.7 / Dart 3.13.5) |
| `flutter analyze` | 0 errors, 0 warnings, **38 info lints** |
| `flutter test` | **6/6 passed** |
| Content validator (Python) | 0 duplicate IDs, **24 emoji conflicts**, 1 ID-format note |

## 2. Findings (severity · location · impact · fix)

### HIGH

| # | Finding | Location | Impact | Fix |
|---|---|---|---|---|
| H1 | `both_courses` badge can never be earned: condition requires `courses.length == 2`, but 3 courses always load | `lib/app_state.dart:330` | Dead badge shown as forever-locked | Base condition on EN+UR completion, independent of course count |
| H2 | Corrupt progress JSON is silently discarded → all user progress lost with no trace | `lib/app_state.dart:143-145` | Unrecoverable data loss on any decode error | Snapshot corrupt payload into a backup key before reset; surface a non-fatal note |
| H3 | All 2016 EN words are "due" on day 1 (new cards always due, no limit) | `lib/screens/flashcards.dart:37-44` | First-run card tab is an unusable flood of unseen words | Only introduce cards from lessons the learner finished + daily new-card cap |
| H4 | Lesson completion seeds every word as "good" regardless of actual answers | `lib/app_state.dart:269-279`, `lesson_screen.dart:971` | SRS schedule ignores mistakes; weak words look strong | Track per-word correctness during the lesson and feed real results into SRS |

### MEDIUM

| # | Finding | Location | Impact | Fix |
|---|---|---|---|---|
| M1 | No dark mode (single light `ThemeData`) | `lib/main.dart:69`, `theme.dart` | MASTER PROMPT requirement | Light+dark palettes, `themeMode` setting |
| M2 | TTS enabled/rate are in-memory only — reset on every app start | `lib/services/tts.dart`, `settings.dart:56,86` | Settings silently lost | Persist in prefs via AppState |
| M3 | `save()` re-encodes the full progress JSON (up to ~3,000 cards) on **every** answer | `app_state.dart:152-173` | UI-isolate jank grows with progress | Debounced save (≤1 flush / 2s) + flush on lifecycle pause |
| M4 | `home` tab is a statistics-less path list; no "continue where you left off" | `learn_path.dart` | 188 EN lessons → endless scrolling to find next node | Home hero card: next lesson + due-count CTA |
| M5 | `use_build_context_synchronously` + deprecated `activeColor` | `settings.dart:203,54` | Lint noise, async-gap crash risk | Guarded context use, `activeThumbColor` |
| M6 | Stale version string "2.0.0" shown in Settings | `lib/l10n.dart:82,209` | Users see wrong version | Update to 4.0.0 (single source note in pubspec) |
| M7 | Winding-path node side depends on `lessonStars.length`, so nodes jump sides after each lesson | `learn_path.dart:177` | Visual instability | Base parity on flat lesson index |
| M8 | No progress backup/export/import | app-wide | Data trapped on device | Export/import JSON in Settings with validation |
| M9 | No onboarding placement test | onboarding | Re-learners start at lesson 1 | Optional quick placement quiz per course |
| M10 | 24 lessons contain duplicate emojis within the same lesson pool | see CONTENT_AUDIT.md | `picToWord` options visually ambiguous | Generator skips shared-emoji words for picture rounds |

### LOW (polish)

| # | Finding | Location | Impact | Fix |
|---|---|---|---|---|
| L1 | Dead code: `tr2` holder field, unused `correct` param in `_finishExercise` | `lesson_screen.dart:798,954` | Readability | Remove |
| L2 | `android namespace` still `com.example.masar_al_lugha` (applicationId is correct: `com.masar.allugha`) | `build.gradle.kts:8` | Store-hygiene mismatch | Move MainActivity package + namespace to `com.masar.allugha` |
| L3 | 38 info lints: `withOpacity` deprecations (Flutter 3.31+), function-declaration style | various | Noise; future breakage | Migrate to `withValues(alpha:)` etc. |
| L4 | `_distractors` fallback pads options with literal `'___'` underscores when pool < 4 | `exercise_gen.dart:355` | Looks broken in tiny lessons | Pad from a global real-word reserve |
| L5 | `recordAnswer` stats not persisted until next XP event | `app_state.dart:245` | Minor loss on hard kill | Covered by M3 debounce flush |
| L6 | Urdu lesson IDs contain raw Urdu text + `؟` character | `course_ur.json` | Cosmetic; IDs are user-progress keys → **must not be renamed** (append-only rule) | Document only |
| L7 | Tests cover l10n/exercises only; no SRS / AppState / model / content tests | `test/` | Regression risk | Add unit tests (Wave 7) |

## 3. Baseline Verification Commands

```bash
flutter analyze   # 0 errors / 0 warnings / 38 info
flutter test      # 6/6 pass
python3 scripts/validate_content.py   # 2986 ids, 0 fatal, notices only
```

## 4. Wave Plan

1. ✅ Audit (this document)
2. Critical fixes: H1, H2, M5, M6, M7, L1, L4 (+ L2 namespace)
3. Data integrity: M3 (debounced save + backup), M8 (export/import), schema versioning
4. Learning engine: H3, H4, M9, honest-SRS docs, error analysis (weak-words list)
5. Curriculum: M10 generator guard, CI content validation
6. UI/UX: M1 dark mode, M4 home hero, a11y (touch targets, semantics, reduce motion)
7. QA & release: format/analyze clean, expanded tests, release build, CI artifact
8. Advanced: weak-words practice mode, ROADMAP.md

## 5. Resolution status (end of v4.0 upgrade — every claim verified by grep or test)

| # | Status | Evidence |
|---|---|---|
| H1 | ✅ fixed | `app_state.dart:505` — `award('both_courses', courseDone('en') && courseDone('ur'))`; new `polyglot` badge covers all three courses |
| H2 | ✅ fixed | `app_state.dart` load() catch → corrupt payload snapshotted to `progress_backup_v1`; covered by `test/app_state_test.dart` (corrupt-JSON case) |
| H3 | ✅ fixed | `app_state.dart:249` `newCardsRemainingToday` (cap = 10, `dailyNewCardLimit`); flashcards draw new cards **only from completed lessons**; covered by analyzer + manual verification |
| H4 | ✅ fixed | `lesson_screen.dart:990` passes real `mistakes:` count; `completeLesson` + `wordMistakes` lifetime tracking in `app_state.dart:404` |
| M1 | ✅ fixed | `main.dart:93-94` `darkTheme: buildMasarTheme(dark: true)` + `themeMode` from persisted state |
| M2 | ✅ fixed | `ttsEnabled`/`ttsRate` persisted in settings blob (`app_state.dart:176-177,221-222`) |
| M3 | ✅ fixed | `scheduleSave()` debounce (2s) + `flush()` on `AppLifecycleListener.onPause/onInactive` (`main.dart:66`); covered by `test/app_state_test.dart` + `test/storage_test.dart` |
| M4 | ✅ fixed | `learn_path.dart` hero card: next lesson + due-count review CTA (`continueLearning`) |
| M5 | ✅ fixed | `flutter analyze` = **No issues found** (0 errors / 0 warnings / 0 infos) |
| M6 | ✅ fixed | `l10n.dart:132,286` — "الإصدار 4.0.0" / "Version 4.0.0" |
| M7 | ✅ fixed | node side from `flatIndex.isEven` (`learn_path.dart:342`) — stable across completions |
| M8 | ✅ fixed | Settings → export/import profile JSON with validation (`settings.dart:118-131`) |
| M9 | ✅ fixed | `lib/placement.dart` + `screens/placement_screen.dart` + onboarding entry; 5 engine tests |
| M10 | ✅ fixed | `exercise_gen.dart:37-47` skips shared-emoji words in picture rounds; validator demotes to notice |
| L1 | ✅ fixed | `tr2` and unused param removed (grep-clean) |
| L2 | ✅ fixed | namespace + MainActivity package = `com.masar.allugha` (`build.gradle.kts:8`, `kotlin/com/masar/allugha/`) |
| L3 | ✅ fixed | `dart format --set-exit-if-changed` clean; analyze 0 infos |
| L4 | ✅ fixed | `exercise_gen.dart:365` pads from real global words, never `'___'` |
| L5 | ✅ fixed | covered by M3 debounce + lifecycle flush |
| L6 | ✅ documented | validator accepts legacy `ur_*` ids as notice; append-only rule enforced (341 ids) |
| L7 | ✅ fixed | test suite grew 6 → **27** (placement 5, app_state 4, storage 2, plus expanded generator/l10n suites) |

**Storage decision (Wave 3):** SharedPreferences retained (single ~350 KB document
at max scale; measured in `test/storage_test.dart`), hardened with schema v2 +
migration, corrupt-backup, debounced writes, export/import. SQLite/Drift not
warranted — full rationale in docs/ARCHITECTURE.md §2.

## 6. v4.1 increment (architecture & engine polish — ROADMAP items 1–4)

Scope: no new defects were found in v4.0.1; this increment delivers the four
v4.1 roadmap items and keeps every existing test green.

| Item | What changed | Files | Verification |
|---|---|---|---|
| 1. ProfileStore extraction | All persistence (keys, schema-v2 migration, corrupt-backup, debounced writes) moved out of `AppState` into a standalone class. `AppState.load/save/scheduleSave/flush/dirty` are thin delegation; `ensureDaily` became public because the store calls it after restore. Zero behavior change — same keys, same payload, same debounce. | `lib/profile_store.dart` (new), `lib/app_state.dart` | New round-trip test "AppState delegates persistence to ProfileStore" + all pre-existing load/save/migration/corrupt tests untouched and passing through the same public API |
| 2. Tough-words practice | New offline practice lane over `AppState.weakestVocab(course)` (course-filtered, most-missed first, session cap 20). Ratings reuse `rateCard`/`addXp`/`recordAnswer` so practice feeds the real SRS schedule. Practice self-ratings deliberately do not inflate `wordMistakes`. | `lib/screens/weak_words_screen.dart` (new), `lib/app_state.dart` (`weakestVocab`), entry from Profile weak-words card | `test/weak_words_test.dart`: ordering, cross-course filtering, ghost-id filtering, empty queue, SRS/stats integration, `wordMistakes` untouched |
| 3. Error-analysis screen | Full screen from the Profile weak-words card: overall accuracy ring (`correctAnswers/totalAnswers`) + top-20 most-missed words per course with tap-to-speak + practice CTA. | `lib/screens/error_analysis_screen.dart` (new), `lib/screens/profile.dart` | Numbers come only from persisted counters; disabled CTA when queue is empty |
| 4. Placement re-test | Returning users with `placementDone[courseId] == true` get a re-test row in the learn-path hero; confirming overwrites `placementSkip`, stars are preserved. | `lib/screens/learn_path.dart` | Same `PlacementScreen` + engine tests as initial placement; entry condition covered by state, not new logic |

Also in v4.1: l10n keys for all new surfaces (ar+en), version strings bumped to
4.1.0 (`pubspec.yaml` → `4.1.0+9`), test count 30 → 34 (grep-counted:
widget 6, weak_words 3, srs 10, app_state 8, placement 5, storage 2). No new
permissions, no network calls, no dependencies added; dark mode + RTL respected
by the new screens (theme-context colors only).

## 7. v4.2 increment (curriculum depth + CEFR ladder — ROADMAP v4.2 items 1+2)

Scope: content expansion of all three courses plus a formal (self-referenced)
CEFR ladder. No engine or storage changes; existing behavior untouched.

| Item | What changed | Files | Verification |
|---|---|---|---|
| Corpus expansion | EN 48→52 units (+4×4 lessons×12 words: Phrasal Verbs, Idioms & Sayings, Business & Money, Academic & Exams), FR 15→21 (+6×3×12), UR 17→21 (+4×3×12). Total 2986→**3538** words, 80→94 units, 288→334 lessons. Every new word ships `exampleTarget`/`exampleAr`. | `assets/data/course_en.json`, `course_fr.json`, `course_ur.json` (append-only: new ids `en_u49…52`, `fr_u16…21`, `ur_u18…21`; zero renames of shipped ids) | `python3 scripts/validate_content.py` → PASS, 0 fatal, 3538 unique ids; generator asserts no id/target collisions before writing (`scripts/expand_curriculum_v42.py`) |
| CEFR ladder | Every unit (old + new) now carries a `cefr` field; monotonic non-decreasing A1→C1 in path order. `Unit` model gained `cefr` (defaults `A1` for any JSON without the tag — no migration needed). | `lib/models.dart`, all 3 course JSONs, `scripts/validate_content.py` (REQ_UNIT + monotonic rule) | Validator fails on invalid values or any decrease; `test/content_test.dart` asserts ladder validity on the real assets |
| Unit banner pill | CEFR tag rendered as a pill next to the lesson counter on every unit banner. | `lib/screens/learn_path.dart` | White-on-unit-color pill, same pattern as the progress pill; dark mode unaffected (banner is color-owned surface) |
| Content asset tests | New test group loading the three real assets via `rootBundle`: corpus shape (52/204/2208 · 21/63/711 · 21/67/619 = 3538), CEFR validity + monotonicity, global vocab-id uniqueness, required-field completeness, per-lesson emoji uniqueness for the new units, append-only id endpoints (`en_u52`/`fr_u21`/`ur_u21`). | `test/content_test.dart` (new) | Fails `flutter test` if a shipped content file drifts — mirrors the Python gate inside the Dart test suite |

Also in v4.2: `pubspec.yaml` → `4.2.0+10`; validator stats line now prints the
CEFR span per course. No new permissions, no network calls, no dependencies
added. Known limitations remain documented in CONTENT_AUDIT.md (self-referenced
labels need human translation review; legacy emoji-ambiguity notices unchanged).

## 8. v4.3 increment (lesson styles — ROADMAP v4.3 items 1–3)

Scope: two new lesson styles over the unchanged v4.2 corpus plus the entry
point to choose between them. No storage, schema, or content-file changes;
classic lesson behavior is byte-for-byte the same plan (`_classicPlan` is the
moved, not edited, v2.0 body).

| Item | What changed | Files | Verification |
|---|---|---|---|
| Sentence-mining style | `LessonMode.sentences` plan: up to 6 cloze rounds (keyword hidden in real example sentences), up to 4 sentence-arrange builds (3–8 word tiles reconstruct `audioText`), up to 4 listen-and-pick-the-sentence rounds (needs ≥2 distinct sentences), top-up classic drills when material is thin (<5 exercises), words-only match boss (sentence chips would overflow). | `lib/exercise_gen.dart` (`_sentencePlan`), `lib/models.dart` (`LessonMode`) | `test/lesson_modes_test.dart`: cloze-first ordering (`firstBlank` ≤ index 5), blank validity (`______` present, answer absent, answer in options), tiles.join == answer, sentence-only listen options, bare-lesson fallback (4 top-up drills + valid options) |
| Audio-first style | `LessonMode.audio` plan: ears-first pass over the whole lesson (hear→pick word / hear→pick Arabic meaning, alternating), up to 3 audio sentence builds, a whole-sentence listen round, tap-to-hear match boss. Every exercise except the boss carries non-empty `audioText`. | `lib/exercise_gen.dart` (`_audioPlan`) | Same test file: first exercise is `listen` for rich AND bare lessons, ≥4 listens with both answer variants, `audioText` non-empty per exercise, audio build `audioText == tiles.join(' ')` |
| Style chooser | Bottom sheet on lesson tap in the learn path (3 tiles: Full / Sentence mining / Listening). Hero quick-start keeps the classic one-tap flow; lesson retry (`LessonFailedScreen`) preserves the active style. Long options (sentences) render as full-width rows (1-col grid, aspect 3.2) instead of the 2-col word grid; build body gains a replay speaker button and an audio-specific prompt in audio mode; listen captions are now variant-accurate (`listenMeaning` / `listenSentence` / `listenAndChoose`). | `lib/screens/learn_path.dart` (`_openLesson`, `_pushLesson`, `_modeTile`), `lib/screens/lesson_screen.dart` (`mode` param, `_speakIfNeeded` build case, `_buildBody` replay, `_listenTitle`, `_mcqBody` adaptive grid), `lib/l10n.dart` (12 new ar/en keys) | Analyze clean; classic listen captions unchanged (`answer == vocab.target` falls through to `listenAndChoose`) |
| Version & docs | `pubspec.yaml` → `4.3.0+11`; l10n `version` strings → 4.3.0 (replaced, not duplicated — v4.1 CI lesson); ROADMAP v4.3 marked SHIPPED; ARCHITECTURE §3.1 lesson-styles; CONTENT_AUDIT sentence-material coverage section. | `pubspec.yaml`, `lib/l10n.dart`, `docs/*.md` | `grep version` single key per locale |

Also in v4.3: test count 39 → **49** (10 new in `test/lesson_modes_test.dart`:
classic regression 1, sentence-mining 4, audio-first 4, modes-differ 1).
Sentence-material coverage on the shipped corpus: **en 881/2208, fr 264/711,
ur 350/619** vocab items qualify as sentence-plan candidates (example sentence
or multi-word item). No new permissions, no network calls, no dependencies
added; dark mode uses theme-context colors only; RTL unaffected (new strings
are Arabic-first, sheet layout uses stretch + Expanded rows).

## 9. v4.4 increment (local intelligence + favorites — ROADMAP v4.4)

Scope: a fully on-device intelligence layer plus the favorites feature and a
new launcher icon. No content-file changes, no new dependencies, no network,
no permissions. Storage stays schema-v2 — the new fields are additive
null-safe keys (`insights`, `favorites`), so v4.3 payloads load unchanged and
old app versions simply ignore the extra keys (forward-compatible).

| Item | What changed | Files | Verification |
|---|---|---|---|
| Insights engine | New Flutter-free engine: `bestStudyHour` (hour buckets, min 8 samples, tie→busier), `accuracyTrend` (per-day pct, oldest first), `trendDelta` (last-3 vs previous-3 active days, ≥20 answers per half), `goalSuggestion` (raise +5 when met ≥6/7 with avg ≥ goal+15, cap 60; lower −5 when 4+ missed full days, floor 10; derived from `xpLog` — no new state), `topConfusions` + `confusionKey` (lexically-normalized pairs), `dueWithinDays` forecast, `tutorTips` (≤4 prioritized, evidence-gated: confusion ≥3, best hour, streak-at-risk, review wave ≥8, trend ±8). | `lib/insights.dart` (new) | `test/insights_test.dart`: 16 engine tests incl. thresholds, caps, floors, tie-breaks, evidence gating |
| Capture layer | `recordAnswer` now also fills 24 hour buckets (`hourTotal`/`hourCorrect`) + a 30-day `answerLog` (day→[total, correct]); new `recordConfusion` records normalized bounded pairs (60→top 40); favorites API (`isFavorite`/`toggleFavorite`/`favoriteVocab` per course, stale ids dropped). | `lib/app_state.dart`, `lib/profile_store.dart` (load/save/export/import, additive) | AppState tests: buckets + answerLog growth, direction-independent pairs, bounded map, per-course favorites, save/load round-trip, export/import carry, legacy v4.3 import without insights keys |
| Confusion capture in lessons | Wrong option answers (mcq/reverse/listen/picToWord/fillblank) map the chosen text to a real vocab id via a course-wide text→id map (targets + Arabic meanings) and record the pair; wrong match pairs record (left word ↔ right text id). true/false and emoji options never map (skipped implicitly). | `lib/screens/lesson_screen.dart` (`_idByText`, `_check`, `_onMatchTap`) | Covered via AppState pair tests + analyze; capture point shares the existing wrong-answer branch |
| Insights screen | New dashboard: privacy banner, 7-day accuracy bars (localized weekday labels, today marked), best-hour card, smart-goal card with one-tap apply + snackbar, confusion pairs with per-pair practice CTA, review forecast (due now / due tomorrow), tutor tips list. Entry: insights button on the Profile weak-words card. | `lib/screens/insights_screen.dart` (new), `lib/screens/profile.dart`, `lib/scope.dart` (`trF` param substitution) | Analyze clean; dark-mode via theme-context colors; RTL-safe (Arabic-first strings) |
| Pair practice | `WeakWordsScreen` gained optional `fixedPool` + `titleKey` — the insights screen opens a specific pair through the same SRS-rating flow. | `lib/screens/weak_words_screen.dart` | Same mechanics as the v4.1 lane (already tested); pool path exercised by fixedPool param |
| Favorites UI | Star toggle on every dictionary word tile (yellow, filled/border); Cards tab gains a favorites-deck toggle chip: deck stat + queue switch, hand-picked words bypass the daily new-card budget by design (user choice), ratings still flow through `rateCard`. | `lib/screens/dictionary.dart`, `lib/screens/flashcards.dart` | Analyze clean; empty-state handled (`favoritesEmpty`/`favoritesHint`) |
| l10n & version | 38 new ar/en keys (insights, tips, goal, pairs, favorites) — 207 keys per locale, no duplicates; `version` strings → 4.4.0 (replaced in place). | `lib/l10n.dart` | Duplicate-key scan clean |
| Launcher icon | New brand icon (winding path → star, A/ع speech bubbles on the green gradient): baked white corners replaced by seamless per-row gradient fill → full-bleed square + circular variant, all 5 densities (48/72/96/144/192). | `android/app/src/main/res/mipmap-*/ic_launcher{,_round}.png`, `scripts/apply_app_icon.py` | Pixel-verified corners (no white ring); previews in `download/icon/` |

Test count 49 → **72** (23 new in `test/insights_test.dart`: 16 engine-rule tests + 7 AppState capture tests). Known
limitations: hour-bucket accuracy needs ≥8 answers per hour before a
best-time tip appears; goal derivation uses the *current* goal against
historical XP (documented approximation); confusion capture is lesson-only
(flashcard self-ratings deliberately excluded to keep the signal honest).

## 10. v4.5 increment (companion wave — ROADMAP v4.5)

Scope: the interactive character system ("Rafiq & Friends") plus +180 CEFR
words. No new dependencies, no network, no permissions; storage stays
schema-v2 with one additive null-safe key (`mascot`), so v4.4 payloads load
unchanged and old builds ignore the key (forward-compatible both ways).

| Item | What changed | Files | Verification |
|---|---|---|---|
| Companion engine | 5 characters with evidence-based unlocks (Rafiq default; Farah 500 XP; Nur 7-day streak; Zayd 50 lessons; Salma 1500 XP) — `missingRequirement` reports the strictest remaining gate; 9 event types × 6 bilingual lines (54 lines, 108 strings); `MascotEngine.lessonEvent` (perfect ≥100 / great ≥80 / good ≥50 / struggled), `resultEvent` (fresh streak milestone > level-up > lesson quality), `isMilestone` = {3,7,14,30,60,100}, `lineFor` deterministic salt rotation, `fill` with closed placeholder set {s},{lvl},{p},{m}. | `lib/mascot.dart` (new) | `test/mascot_test.dart`: 18 engine/cast/catalog tests incl. parity, placeholder whitelist, {m}-only-comeback, rotation cycling, locale switch, priority rules |
| Companion widgets | Per-character palettes + ear accessories (owl tufts / crest / cat / fox / bunny) behind the unchanged `Mascot` API (default `rafiq`, `MascotMood` re-exported — zero pre-4.5 call-site churn); new `MascotBubble` with reduce-motion-aware entrance + `showAvatar:false` variant. Fixed a real bug pre-commit: `RotationTransition(turns: Offset(...))` misuse → `Transform.rotate`. | `lib/widgets/mascot.dart` | Widget tests: every character × every mood renders exception-free; bubble with/without avatar |
| State & persistence | `mascotId` field + `mascotMissedDays` (date-parse safe) + `mascotFacts` + `isMascotUnlocked` + `selectMascot` (no-op on locked/unknown); ProfileStore load/save carry `mascot` additively; import validates against the cast (tampered ids dropped); export carries it; `resetAll` restores rafiq. | `lib/app_state.dart`, `lib/profile_store.dart` | AppState tests: locked-selection no-op, unlock at gate, persistence round-trip, missed-days math, facts mirroring, export/import carry, tampered-id drop |
| Lesson surfaces | `_showComplete` now captures pre-lesson level/streak and passes the computed `MascotEvent` to the result screen (streak-milestone/level-up/perfect/great/good/struggled moments); failed screen gets the comfort moment. Both render the chosen companion + its line. | `lib/screens/lesson_screen.dart` | 104/104 suite; result screen default param keeps old constructor calls compiling |
| Profile companion card | Comeback bubble after ≥3 fully-missed days (evidence-gated), tap-to-rotate idle tips, full cast picker: selected state, lock badges, localized unlock hints via `trF` (`unlockXp`/`unlockStreak`/`unlockLessons`). | `lib/screens/profile.dart` | Analyze clean; RTL-safe; dark-mode via theme-context colors |
| l10n & version | 11 new ar/en keys (companion card, choose, locked, unlock hints, selected) — 218 keys per locale, no duplicates; `version` strings → 4.5.0; pubspec `4.5.0+13`. | `lib/l10n.dart`, `pubspec.yaml` | Duplicate-key scan clean (analyzer) |
| Content +180 | EN u53–u54 (C1): Idioms & Expressions (pre-checked against the v4.2 idiom set — 14 target/id collisions caught and replaced pre-flight), Nuance & Register. FR u22–u23: Médias & Débats (B2), Littérature & Nuances (C1) — 11 collisions replaced. UR u22–u23: شاعری اور محاورے (B2), زبانِ ادب (C1) — 4 collisions replaced pre-run. Generators persisted (`scripts/content_v45_{en,fr,ur}.py`), UR legacy id shapes untouched. | `assets/data/course_{en,fr,ur}.json`, `scripts/content_v45_*.py` | `validate_content.py` PASS (0 fatal); `test/content_test.dart` updated: 100 units / 352 lessons / 3718 words, tail ids u53–u54 / u22–u23, all ladders reach C1 |

Test count 72 → **104** (+32: 18 engine + 6 AppState integration + 8 widget).
Gates at commit time: `validate_content.py` PASS 0 fatal · `dart format`
clean (Flutter 3.47.7 = CI pin) · `flutter analyze` No issues ·
`flutter test` 104/104. Known limits: lines are in-code (not assets) by
design — tests compile-check them; mascot widget smoke tests cover
rendering, not full-screen flows (existing screens already covered); UR
phonetics are approximations for Arabic readers (noted in CONTENT_AUDIT).

## 11. v4.6 increment (mastery wave — ROADMAP v4.6)

Scope: two new exercise types (dictation + listening comprehension) and
+180 CEFR words. No new dependencies, no network, no permissions, no
schema change (exercise types live in the generator, not storage).

| Item | What changed | Files | Verification |
|---|---|---|---|
| Tolerant grading | `ExerciseGen.normalizeTyped`: lowercase, unicode-aware `\p{P}\p{S}` stripping, whitespace collapse, Arabic tashkeel (U+064B–U+065F) + superscript alef + tatweel stripping. Flutter-free single source of truth for typed answers. | `lib/exercise_gen.dart` | 5 normalizer tests incl. idempotence and Arabic-diacritics parity |
| Dictation type | `ExerciseType.dictation` — audioText == answer, options/tiles empty, Arabic meaning in `hint`; sentences 2–8 words via sentence/example targets, bare words 3–12 chars as fallback (so every lesson gets a typing round). Classic 1, audio-first up to 2, sentence-mining 1. `_make` degrades to mcq if ever dispatched directly. | `lib/models.dart`, `lib/exercise_gen.dart` | Dictation tests: per-mode counts, bare-lesson fallback, tolerant-variant round-trip grades equal |
| Listening comprehension | `ExerciseType.listenComp` — hear the target-language sentence, pick the Arabic meaning among exactly 4 unique real lesson meanings; answer never equals audioText; skipped entirely when the lesson cannot supply 3 distinct distractor meanings (graceful degradation). Sentence-mining up to 2, audio-first 1. | `lib/exercise_gen.dart` | listenComp tests: option count/uniqueness/containment, Arabic-script option check, bare-lesson absence |
| Lesson UI | `_dictationBody`: replay speaker (auto-speaks on entry), meaning hint, TextField with `onChanged`-gated check button, disabled after answering, cleared on advance; `listenComp` reuses the listen grid with its own caption; `_speakIfNeeded`/`_canCheck`/`_check` extended; confusion capture for typed answers via whole-course normalized target map (`_idByNormTarget`). | `lib/screens/lesson_screen.dart` | Analyzer clean; full suite green; widget_test switch grew dictation/listenComp cases |
| l10n & version | +3 keys/locale (`typeWhatYouHear`, `typeHere`, `listenUnderstand`) → 221 per locale; `version` strings → 4.6.0; pubspec `4.6.0+14`. | `lib/l10n.dart`, `pubspec.yaml` | No duplicate keys (analyzer) |
| Content +180 | EN u55–u56 (C1 business/economics + argument/persuasion), FR u24–u25 (argumentation/médias + monde professionnel), UR u24–u25 (صحافت/میڈیا + رسمی خطابت/دفاتر/قانون/فکر). Corpus 100→**106 units**, 352→**370 lessons**, 3718→**3898 words**; all ladders reach C1. Generators persisted with hard pre-flight id-collision abort (13 EN / 7 FR / 2 UR caught pre-write). | `assets/data/course_{en,fr,ur}.json`, `scripts/content_v46_*.py` | `validate_content.py` PASS 0 fatal; content_test counts + append-only tail re-pinned (v4.5 tail intact) |

Test count 104 → **118** (+14: `test/exercise_v46_test.dart` — 5 normalizer,
4 dictation, 3 comprehension, 2 corpus-wide sweep across first/middle/last
lessons of all three courses × all three modes).
Gates at commit time: `validate_content.py` PASS 0 fatal · `dart format`
clean · `flutter analyze` No issues · `flutter test` 118/118.

## 12. v4.7 increment (custom word lists — ROADMAP v5.0 item 3 pulled forward)

Scope: user-authored word lists ("قوائمي") with flip-card practice. No new
dependencies, no network, no permissions, no schema bump (additive
null-safe `decks` key on the existing schema-v2 payload).

| Item | What changed | Files | Verification |
|---|---|---|---|
| Deck engine | `CustomDeck`/`CustomWord` strict parse: deck ids `^cd[0-9]+$` (cannot collide with course ids), word ids must belong to their deck, duplicate ids rejected, malformed entries silently dropped, parse-time bounds (12 decks × 200 words), per-deck monotonic `next` counter keeps word ids stable across deletions; `dupKey` folds case+punctuation only (diacritics are content). `toVocab` seam lets decks feed future exercise flows. | `lib/decks.dart` (new) | 4 engine tests: bounds, dupKey semantics, tampered shapes (incl. `en_u1` collision attempt), lossless round-trip |
| State & persistence | AppState CRUD with l10n error keys (`invalidWord`/`dupWord`/`listFull`); `rebaseDeckCounter()` public seam so ProfileStore never touches private state; additive `decks` key on load/save/export/import; `resetAll` clears; payload ids never drive the counter. | `lib/app_state.dart`, `lib/profile_store.dart` | 6 state tests: CRUD + id stability across removals, both budgets, reset counter restart, save→load survival, export/import carry, tampered import drop |
| UI | Cards-tab entry button → deck list (per current course, create dialog, companion empty state) → deck detail (add-word form with inline errors, tap-to-hear rows, delete confirm, guarded practice) → flip-card practice (prev/next/shuffle/progress, TTS in course language). Theme-context colors only (dark-mode safe), RTL-safe icons with explicit LTR text direction. | `lib/screens/custom_decks_screen.dart` (new), `lib/screens/flashcards.dart` | Analyzer clean; widget flows behind the same AppScope pattern as shipped screens |
| l10n & version | +21 keys/locale (`myLists`…`invalidWord`) → 242 per locale; `version` → 4.7.0; pubspec `4.7.0+15`. | `lib/l10n.dart`, `pubspec.yaml` | No duplicate keys (analyzer) |

Test count 118 → **128** (+10 in `test/custom_decks_test.dart`).
Gates at commit time: `dart format` clean · `flutter analyze` No issues ·
`flutter test` 128/128. Known limits: decks are per-course (created under
the active course and listed there); practice is honest self-rating flip
cards — deck words intentionally do NOT enter the course SRS (no fake
mastery claims); examples are accepted from imports but the add-word form
keeps to word+meaning for speed.
