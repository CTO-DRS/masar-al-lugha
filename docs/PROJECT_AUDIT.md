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
