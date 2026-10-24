# ARCHITECTURE — Masar Al-Lugha v4.1

## 1. Layered view (post-v4.0)

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation        lib/screens/*  lib/widgets/*            │
│                     (Flutter widgets only; no business law) │
├─────────────────────────────────────────────────────────────┤
│ Application         lib/scope.dart (AppScope DI + l10n ext) │
│                     lib/app_state.dart (ChangeNotifier;     │
│                      gamification, streaks, badges, prefs;  │
│                      delegates persistence to ProfileStore) │
├─────────────────────────────────────────────────────────────┤
│ Domain              lib/models.dart (Course/Unit/Lesson/    │
│                     Vocab/Exercise/CardData)                │
│                     lib/srs.dart (spaced repetition)        │
│                     lib/exercise_gen.dart (item generator)  │
│                     lib/placement.dart (v4.0)               │
├─────────────────────────────────────────────────────────────┤
│ Data                lib/profile_store.dart (v4.1): keys,    │
│                     schema v2 migration, corrupt-backup,    │
│                     debounced writes, export/import payload │
├─────────────────────────────────────────────────────────────┤
│ Services            lib/services/tts.dart (flutter_tts)     │
└─────────────────────────────────────────────────────────────┘
Assets: assets/data/course_{en,ur,fr}.json (read-only content)
```

Rules enforced since v4.0, tightened in v4.1:
- Widgets never decode/persist state directly; they go through `AppScope.of(context)`.
- Domain code (`srs.dart`, `exercise_gen.dart`, `placement.dart`, `models.dart`) is
  Flutter-free and unit-testable.
- The persistence seam promised in v4.0 is now a real class: `lib/profile_store.dart`
  owns the SharedPreferences keys, schema migration, corrupt-backup and the debounced
  write. AppState keeps the domain API (`load/save/scheduleSave/flush/dirty`) as thin
  delegation, so swapping the backend (e.g. SQLite/Drift) touches only ProfileStore —
  not UI, not domain code. Verified by `test/app_state_test.dart`
  ("AppState delegates persistence to ProfileStore" round-trip).

## 2. Storage decision (v4.0) — SharedPreferences, hardened

**Measured:** the heaviest possible profile is ~3,000 SRS cards. Encoded JSON at that
scale is ~350 KB and encodes in single-digit milliseconds on a modern phone
(verified by unit test `test/storage_test.dart` at 3,000 cards — round-trip
fidelity + encode/decode timing + size budget all asserted). Android SharedPreferences
handles multi-hundred-KB string values reliably.

**Chosen:** keep SharedPreferences **but** fix its real weaknesses:
1. *Write amplification* — v3.3 saved on every tap → v4.0 debounces saves (≤1 write/2s)
   and force-flushes on app pause.
2. *Silent corruption* — v3.3 discarded unreadable JSON → v4.0 snapshots corrupt payloads
   to `progress_backup_v1` before recovering, so data is forensically recoverable.
3. *No versioning* — v4.0 writes `schema: 2` and includes a documented migration path.
4. *No portability* — v4.0 adds Settings export/import (validated JSON).

**Why not SQLite/Drift now:** the profile is a single small document (not relational),
migration would put the *only* copy of user progress at risk for zero functional gain,
and every native plugin complicates the reproducible local build. The storage seam makes
the later swap a contained change. This decision is re-evaluated if profiles exceed ~1 MB
or per-card queries are needed.

## 3. Learning engine (v4.0) — honest description

`srs.dart` is an **SM-2-inspired lite scheduler** (Anki-style ease/interval with learning
steps), **not a full FSRS implementation** — it has no difficulty/stability memory states,
no power-law forgetting curve, no optimizer. UI copy and docs say "FSRS-inspired";
nowhere does the app claim certified FSRS.

Pipeline: lesson exercises record **per-word** results → lesson end feeds real outcomes
(mistakes → `learning`, clean → `review`) → flashcards serve due reviews + a **daily
new-card cap (10)** built **only** from lessons already completed → `placement.dart`
(option) lets re-learners skip ahead by sampling across units.

**v4.1 additions** (all offline, all testable without Flutter):
- *Tough-words practice lane* (`screens/weak_words_screen.dart`) — a short self-paced
  session over `AppState.weakestVocab(course)` (most-missed first, cap 20). Ratings go
  through the same `Srs.rate` + stats path as the Cards tab, so practice reshapes the
  real review schedule. Design decision: practice self-ratings do **not** inflate
  lifetime `wordMistakes` — that list stays driven by real lesson errors
  (asserted in `test/weak_words_test.dart`).
- *Error analysis screen* (`screens/error_analysis_screen.dart`) — overall accuracy
  from `correctAnswers/totalAnswers` plus the top-20 most-missed words per course.
  No invented analytics; every number traces to persisted state.
- *Placement re-test* — returning users who feel misplaced can re-take the placement
  from the learn-path hero; confirming overwrites `placementSkip[courseId]`, completed
  lessons keep their stars.

### 3.1 Lesson styles (v4.3)

One `Lesson` corpus, three exercise plans — selected by a bottom sheet on
lesson tap (learn path). `LessonScreen` takes a `LessonMode`; `ExerciseGen.forLesson`
routes to a dedicated plan generator. Progress, XP and SRS feeding are
mode-agnostic: every style ends through the same `completeLesson` +
`applyLessonResults` path, so a sentence-mining or audio session counts
exactly like a classic one.

- **classic** — the unchanged v2.0 mixed drill set (mcq/reverse/listen/build +
  picture, fill-blank, true-false rounds + match boss, capped at 14).
- **sentences** (cloze-first) — up to 6 fill-blank rounds on real example
  sentences → up to 4 sentence-arrange builds (3–8 tiles) → up to 4
  listen-and-pick-the-sentence rounds → thin lessons (<5 exercises) are
  topped up with classic reverse/mcq drills → words-only match boss. The
  guarantee is *playability on any lesson*: no sentence material still yields
  a valid drill plan (test-enforced).
- **audio** (TTS-led) — an ears-first pass over the whole lesson (hear→pick
  the written word / hear→pick the Arabic meaning, alternating) → up to 3
  audio sentence builds (sentence auto-spoken, replay button on the card) →
  a whole-sentence listen round → tap-to-hear match boss. Invariant
  (test-enforced): every exercise except the boss carries non-empty
  `audioText`, i.e. nothing in an audio lesson is read-first.

UI seam: long listen options (sentences) switch the option grid to full-width
rows; listen captions are variant-accurate (`listenAndChoose` /
`listenMeaning` / `listenSentence`); retries re-enter with the same style.

## 4. Local intelligence layer (v4.4)

`lib/insights.dart` is a Flutter-free, rule-based engine over the learner's
own logs. Design invariants:

- **On-device only.** Inputs are state the app already stores (`xpLog`,
  `answerLog`, hour buckets, `confusionPairs`, SRS cards). No network, no
  accounts, no paid APIs — consistent with the hard invariants.
- **Explainable rules.** Every output has a documented threshold and reason
  key (`goalRaiseReason`/`goalLowerReason`), rendered with `{param}`
  substitution via `context.trF`. The UI never shows a number the engine
  did not justify.
- **Evidence gating.** Nothing appears before its minimum sample count
  (best hour ≥ 8 answers/hour, trend halves ≥ 20 answers, confusion tip
  ≥ 3 misses, review wave ≥ 8 cards). Under-informed = silent, never a
  guess.
- **Bounded storage.** `confusionPairs` trims to the top 40 when it exceeds
  60; `answerLog` keeps 30 days — profile growth is capped.
- **Capture points.** `recordAnswer` (every graded tap) fills hour buckets
  + daily accuracy; the lesson screen maps wrong picked options back to
  vocab ids (`recordConfusion`); flashcard self-ratings deliberately do
  NOT inflate confusion counts (honesty of the signal).

Data flows: capture (lesson/flashcards/dictionary) → AppState fields →
ProfileStore additive keys (`insights`, `favorites`) → InsightsScreen reads
through the engine. The engine has no dependency on Flutter, widgets, or
l10n, so `test/insights_test.dart` exercises it as pure Dart with injected
`DateTime` anchors.

### 4b. Companion engine (v4.5)

`lib/mascot.dart` follows the same rules as the insights layer — Flutter-free,
offline, evidence-gated, explainable:

- **Unlocks store nothing.** The five companions gate on facts the profile
  already tracks (`xp`, `streak`, `lessonsCompleted`); `missingRequirement`
  reports the strictest remaining gate and `selectMascot` no-ops on locked
  or unknown ids (the UI hint is the first lock, the state method is the
  second).
- **Deterministic variety.** Lines are picked by `salt % bank.length` — the
  UI passes lesson counts / day hashes, so output is stable under widget
  tests yet rotates across sessions. Placeholder vocabulary is closed
  ({s} streak, {lvl} level, {p} accuracy, {m} missed days) and
  `test/mascot_test.dart` enforces ar/en parity, emptiness and {m}-only-
  in-comeback over the public catalog.
- **Evidence-gated moments.** Streak milestones fire only on a fresh
  {3,7,14,30,60,100} crossing; comeback lines need >= 3 fully-missed days;
  result priority is milestone > level-up > lesson quality. Comfort lines
  replace blame on the failed screen by construction.
- **Additive persistence.** `mascotId` rides the schema-v2 payload under
  `mascot`; load and import both validate against the cast and fall back
  to `rafiq`; export/import and `resetAll` handle it symmetrically.

Rendering lives in `lib/widgets/mascot.dart` (palettes + ear accessories per
character behind the stable `Mascot` API; `MascotBubble` with reduce-motion-
aware entrance). Wiring: LessonResultScreen, LessonFailedScreen, Profile
companion card.

## 5. Content pipeline

Python generators (append-only IDs) → `assets/data/*.json` → validated by
`scripts/validate_content.py` (duplicate IDs, required fields, id-format sanity,
per-lesson emoji conflicts) in CI → APK. Old vocab IDs are never mutated so
existing user progress keeps resolving.

## 6. Build & release

- `applicationId com.masar.allugha`, namespace aligned in v4.0.
- Local reproducible build without NDK: `flutter.installedNdkVersions` bypass +
  `shared_preferences_android` pinned to a no-jni release.
- CI: GitHub Actions builds a debug-signed release APK artifact on every push
  (`build-apk.yml`); release signing stays out of the repo by design.
