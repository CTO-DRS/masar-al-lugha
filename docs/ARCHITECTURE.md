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

- **classic** — the mixed v2.0 drill set (mcq/reverse/listen/build +
  picture, fill-blank, true-false rounds, one v4.6 dictation round + match
  boss, capped at 14).
- **sentences** (cloze-first) — up to 6 fill-blank rounds on real example
  sentences → up to 4 sentence-arrange builds (3–8 tiles) → up to 4
  listen-and-pick-the-sentence rounds → one v4.6 dictation (type the
  sentence you just mined) → up to 2 v4.6 listening-comprehension rounds
  (hear the sentence → pick its Arabic meaning) → thin lessons (<5
  exercises) are topped up with classic reverse/mcq drills → words-only
  match boss. The guarantee is *playability on any lesson*: no sentence
  material still yields a valid drill plan (test-enforced).
- **audio** (TTS-led) — an ears-first pass over the whole lesson (hear→pick
  the written word / hear→pick the Arabic meaning, alternating) → up to 3
  audio sentence builds (sentence auto-spoken, replay button on the card)
  → up to 2 v4.6 dictations (hear → type) → a whole-sentence listen round
  → one v4.6 listening-comprehension round → tap-to-hear match boss.
  Invariant (test-enforced): every exercise except the boss carries
  non-empty `audioText`, i.e. nothing in an audio lesson is read-first.

v4.6 typed-answer contract: `ExerciseGen.normalizeTyped` is the single
grading gate for dictation — case-insensitive, unicode-aware
punctuation/symbol stripping, whitespace collapsing, Arabic tashkeel +
tatweel stripping. The Arabic meaning rides in `hint`; a wrong attempt
that exactly spells another known word (normalized) feeds the confusion
engine. `listenComp` offers exactly 4 unique real meanings, and lessons
too poor to supply them silently skip the type (graceful degradation).

UI seam: long listen options (sentences) switch the option grid to full-width
rows; listen captions are variant-accurate (`listenAndChoose` /
`listenMeaning` / `listenSentence` / `listenUnderstand`); retries re-enter
with the same style.

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

Since v4.9 the cast is human (coach + classmates + mentors, same ids and
gates) and the render layer (`lib/widgets/mascot.dart`) is a motion
contract, not just art:

- **Motion is gated, never accidental.** Breathing/blink/talk controllers
  run only when `animated == true` and `MediaQuery.disableAnimations` is
  false; `_setLive` keeps them stopped otherwise, so reduce-motion users
  get static art and `pumpAndSettle` still terminates in widget tests.
- **Speech is a producer/consumer pair.** The bubble owns the typewriter
  (Flutter-free reveal math in the engine) and pushes `talking` on a
  shared `ValueNotifier<bool>`; the nearby `Mascot` consumes it to open
  and close the mouth. When the bubble renders its own avatar the sync
  is automatic; split layouts wire the notifier explicitly.
- **Interaction is deterministic.** Tapping a companion plays a wave and
  may re-roll a line: tap lines and time-of-day greetings live in the
  engine catalog next to the event lines and obey the same parity,
  placeholder-free and salt-rotation rules (`test/mascot_test.dart`
  enforces all three).

Since v4.10 the speech contract is AUTONOMOUS — the companion speaks and
moves on its own, without any user action:

- **Speech moves the body.** A false→true edge on the shared `talking`
  notifier auto-plays a gesture burst on the speaker (`Mascot` listens
  to the notifier, not to taps); suppressed while a celebration owns the
  arms or motion is disabled.
- **Every answer is a spoken moment.** The lesson feedback bar renders a
  compact bubble that praises (`mascotPraiseLines`) or nudges
  (`mascotNudgeLines`) automatically — deterministic salts
  (`correctCount` / `mistakes`), comfort never shame, the in-prompt
  mascots react in kind (celebrate hop / worried face) via `_headerMood`.
- **Ambient chatter is lifecycle-aware.** `LiveCompanion` (widget layer)
  runs a deterministic timer — `MascotEngine.ambientIntervalMs`, 24–36 s
  per turn so several companions never sync — speaking from the
  `{s}`/`{lvl}`-personalized ambient bank; every tap replies instantly
  and restarts the window; the timer cancels in background and re-fires
  a fresh line on resume; dispose always cancels (widget tests unmount
  to avoid pending timers). Reduce-motion keeps the chatter (content)
  and only drops the typewriter/entrance animation (motion).
- **No mid-question interruptions.** Ambient chatter deliberately does
  not run inside an open exercise; automatic speech lands at natural
  moments (per answer, result/failed, home/profile rotation).

## 4c. Custom word lists (v4.7)

`lib/decks.dart` is a Flutter-free engine for user-authored decks, stored
in the schema-v2 profile under the additive `decks` key. Invariants:

- **Tamper-proof parse.** Deck ids must match `^cd[0-9]+$` — they can
  never collide with `en_`/`fr_`/`ur_` course vocab ids; word ids must
  belong to their own deck (`<deckId>_w<n>`) and duplicates are dropped;
  malformed entries are silently skipped; bounds (12 decks, 200 words per
  deck) are enforced at parse time, not just at write time.
- **Stable ids.** A per-deck monotonic `next` counter survives load and
  deletions, so word ids are never reused — future per-word progress can
  safely key on them. Payload ids never drive the counter; the store
  re-derives it via `AppState.rebaseDeckCounter()`.
- **Honest practice.** Deck practice is explicit flip-card self-review —
  deck words deliberately do NOT enter the course SRS, so no fake mastery
  signal is recorded. `CustomWord.toVocab()` is the seam for feeding
  future exercise flows if that ever changes.
- **CRUD guards.** `addCustomWord` returns l10n error keys
  (`invalidWord` / `dupWord` / `listFull`); duplicates fold case and
  punctuation (diacritics are content).

## 4d. Records engine (v4.8)

`lib/records.dart` is a Flutter-free engine that derives the all-time
personal-best board ("السجلات") from state the profile already tracks —
same contract as the insights layer: thresholds and derivations, never
estimates, zero network.

- **Zero-cost counters.** `bestStreak` / `bestDayXp` / `activeDays` are
  three additive ints maintained inside hooks that already run:
  `_bumpStreak` fires exactly once per active day (so it counts the day
  and stamps the streak record) and `addXp` stamps the day-XP record.
  No extra write path, no new stored state beyond the three ints.
- **Day-key convention.** `Records.dayKey` reproduces the exact
  `AppState.todayKey` format (local, zero-padded yyyy-MM-dd) so the
  engine reads the same `xpLog` buckets the app writes.
- **Weekly momentum.** `weeklyXp` compares the 7-day window ending
  today with the 7 days before it; `xpLog` keeps 30 days, which
  comfortably covers both windows.
- **Flutter-free by design.** The engine emits stable string keys; the
  records screen owns the key→label and key→icon maps, so the engine
  stays unit-testable without any Flutter dependency.

### 4d. Learning path engine (v4.11)

`lib/path.dart` is a Flutter-free planner over the CEFR-tagged units — the
third engine following the insights/records contract:

- **Catalog, not guesses.** `PathDomain` (9 fields, `daily` = catch-all)
  is assigned per unit by a frozen keyword catalog mirroring
  `scripts/domain_mapping_sim.py`; Latin keywords match whole words only
  (`\b..\b`), Arabic keywords by substring, first match wins. The
  simulation ran BEFORE the Dart existed and caught two keyword bugs
  (`\bsea` matching "Seasons", Latin `time` matching "Free Time"); the
  81 shipped units partition exactly (pinned counts in
  `test/path_test.dart`).
- **Tiers are bands, plans relax.** `LevelTier` maps to CEFR bands
  (A1–A2 / B1–B2 / C1+). `PathEngine.build` keeps units inside the band;
  when a band is empty in the chosen field it relaxes ONE band at a time
  toward beginner, then falls back to the field's full list — `build`
  never returns an empty plan for a non-empty field, and the UI surfaces
  the relaxation (`tierRelaxed` → banner note).
- **Order is pedagogy.** Picked units sort by CEFR rank (course order as
  tiebreak): a "business × beginner" path teaches A1 jobs vocabulary
  before anything harder, regardless of where the units sit in the
  course.
- **Re-order, never lock.** The learn path lists plan units first, a
  divider, then the rest of the course; unlock chains, stars and
  placement skips are untouched. The plan is two per-course string maps
  (`pathDomain`/`pathTier`) in the schema-v2 payload — additive,
  null-safe on old backups, unknown names dropped on import; the derived
  `PathPlan` is never persisted, so a content update instantly reshapes
  an old plan without migration.

### 4e. Placement → level & domain auto-link (v4.12 + v4.13)

The placement quiz no longer only picks a starting lesson — it now sets the
learner's `LevelTier` automatically (v4.12) AND suggests their
`PathDomain` (v4.13), closing the loop between "what you demonstrated"
and "what your path plan targets":

- **One rule, two outputs.** `Placement.recommendedTier` reuses the exact
  consecutive-pass prefix semantics of `recommendedFlatIndex`: the count of
  leading fully-correct checkpoints maps through `tierForPassed` — nothing
  proven (or the first checkpoint failed) → beginner, at least half →
  intermediate, everything → expert. The thresholds are ratios, so they
  hold for any checkpoint count, and degenerate inputs (empty list, zero
  total) degrade to beginner instead of over-claiming.
- **Ready-for band, not a certificate.** The tier describes the material
  the learner is ready to study next (checkpoints sample course depth
  evenly and never unit 0), which is precisely what `PathEngine.build`
  filters units by.
- **Additive state, one writer.** `AppState.setPathTier(courseId, tier)`
  validates the enum name, keeps any previously chosen domain (an existing
  plan moves to the detected tier), skips no-op saves, and persists in the
  same `pathTier` map — nothing new in the schema. "Start from zero" links
  the beginner tier so no stale higher tier survives a deliberate reset.
- **Shared keys, one source.** The domain/tier → l10n-key and emoji maps
  moved into Flutter-free `path.dart` (v4.12) so the placement result
  badge, the learn-path banner and the setup wizard render identical
  labels. The wizard pre-seeds its level step from the stored result and
  refreshes it when the learner returns from the test.
- **The field is a vote, not a placement (v4.13).**
  `Placement.recommendedDomain` lets every CORRECTLY answered word vote
  for the domain of the unit its checkpoint sampled
  (`PathEngine.domainOfUnit`); majority wins, ties resolve in catalog
  (enum) order, and no correct answers → null (no signal, no guess).
  Unlike the tier (a prefix rule for the skip), it reads all correct
  answers — including partial ones inside a failed checkpoint — because
  the suggestion describes demonstrated strengths, not a skip position.
  `AppState.setPathDomain` mirrors `setPathTier` (validates the name,
  keeps the stored tier, skips no-op saves): with both linked, confirming
  the test can complete a WHOLE plan (field × level) without the wizard,
  and the wizard pre-seeds + refreshes both steps on return.

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
