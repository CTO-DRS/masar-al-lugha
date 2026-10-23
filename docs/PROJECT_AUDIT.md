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
