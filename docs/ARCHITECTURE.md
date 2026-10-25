# ARCHITECTURE — Masar Al-Lugha v5.10

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
Assets: assets/data/course_{en,ur,fr,de}.json (read-only content)
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

## 3. Learning engine (v5.3) — honest description

`srs.dart` is a **real FSRS-4.5 scheduler**: every card carries difficulty
(D ∈ [1,10]) and stability (S, days) memory states, retrievability follows
the power-law forgetting curve R(t,S) = (1 + 19/81·t/S)^(−1/2) (so
R(S) = 0.9), ratings map to FSRS grades 1..4 with the official default
weights w0..w16 (difficulty drift + mean reversion, recall-stability growth
with hard penalty / easy bonus, post-lapse stability), and a **target
retention dial** (default 90%, clamp 0.70–0.98, `AppState.retentionTarget`,
slider in Settings) turns stability into scheduled intervals. What is NOT
shipped: a per-user weight optimizer — the 17 defaults are not trained on
this learner's log, and no UI copy claims otherwise.

Pre-v5.3 cards migrate once and lazily (`Srs.migrateLegacy`, called from
`rate()`): stability ≈ the committed interval (review cards) or the good
anchor (learning cards), difficulty ≈ D0(good) shifted by the old ease,
last review ≈ `due − interval` clamped to now — `due/ivl/reps/lapses/state/
ease` never move, so no due review is lost or reshuffled. The legacy fields
stay in the payload forever; the new additive keys `d`, `s`, `last` are
ignored by older app versions (forward-compatible). The 10-minute learning
step survives for new/lapsed cards; FSRS-4.5 grants no same-day stability
growth, so graduating a re-shown card schedules from its existing stability.

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

### 4e. Placement → level & domain auto-link (v4.12 + v4.13, adaptive in v5.5)

Since v5.5 the screen drives `PlacementProber` (a depth staircase, see
ROADMAP v5.5): 18 questions sampled near the running band, a per-CEFR
breakdown on the result card, a solid-band skip
(`recommendedFlatIndexSolid`) and a band→tier mapping. The fixed-probe
API below remains the compatibility contract and the domain votes flow
through it unchanged.

### 4e.1. Placement → level & domain auto-link (v4.12 + v4.13)

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

### 4f. RTL direction safety (v4.13.1)

The shell is Arabic-first RTL (`uiLocale='ar'` → `Locale('ar')`), but a
course's TARGET language may be Latin-script (English/French) or
Arabic-script (Urdu). Any target-language content that inherits the
shell's direction renders REVERSED — the learner-reported case: the
build (arrange) exercise laid "Good morning" out as `morning | Good`.

- **`directionOf(text)`** (`theme.dart`, pure): first-strong-character
  rule — Arabic/Hebrew blocks → RTL, Latin/Greek/Cyrillic → LTR,
  digits/punctuation/`______`/space/emoji are neutral and skipped,
  defaults LTR. Per-content, NOT a blanket LTR, so the Urdu course keeps
  its natural right-to-left flow.
- **`ScriptDirection`** (`theme.dart`): `Directionality` wrapper keyed on
  its `text`. The build exercise wraps BOTH rows (placed answer + source
  bank) with `text: tiles.join(' ')` so the sentence under construction
  and the word bank always read in the sentence's own direction.
- Same-class sweep: cloze prompt (blank side), dictation `TextField`
  (typed direction), mcq/truefalse prompt card, the "الجواب الصحيح"
  feedback answer (own line + direction so trailing punctuation cannot
  flip), `OptionCard` (full sentence options in listen rounds), the
  flashcard front for sentence vocab, and every `exampleTarget` example
  line (flashcards / dictionary / weak-words).
- Pinned by `test/rtl_direction_test.dart`: pure first-strong cases
  (incl. neutral-first cloze blanks and French accents), ScriptDirection
  widget tests asserting `Directionality.of` = LTR for English and RTL
  for Urdu inside an RTL shell, and OptionCard direction for both
  scripts.

### 4g. Fourth course — German (v5.0, expanded v5.4)

The course registry holds FOUR languages: en, ur, fr, de. German ships
as `course_de.json` (25 units / 75 lessons / 779 words since v5.4, CEFR A1→C1,
`ttsLang de-DE`) and flows through every existing engine untouched —
they are course-agnostic by design: the onboarding picker iterates
`state.courses.values`, TTS reads `course.ttsLang`, and placement /
path domains / exercise generation / SRS / custom decks all take the
course as a parameter. Two wiring points were explicit: badges
(`all_de_units` added; `polyglot` now spans four courses) and the
custom-deck `courseId` whitelist (`['en','fr','ur','de']`).

A routing subtlety worth remembering: the frozen path-keyword catalog
matches Arabic keywords by SUBSTRING, and `التعريف` (introduction)
contains `ريف` (countryside) — so the unit's Arabic title was retitled
`التعرّف على النفس` to keep the domain partition honest. The pin lives
in `test/path_test.dart`; `scripts/domain_counts_sim.py` recomputes the
per-domain expectations from the data.

### 4h. Urdu course at full parity (v5.1)

`course_ur.json` grew from 25 to **56 units / 172 lessons / 1669
words — the same unit count and level spread as the English course**
(A1 14 · A2 14 · B1 18 · B2 5 · C1 5). The 31 new units were authored
as batch files under `scripts/ur_new_*.json` and merged by
`scripts/expand_urdu.py`, which inserts each level's units AFTER that
level's existing units so the CEFR-monotonic path order survives.

Invariants that made the append safe:

- not one pre-existing vocab id moved (append-only progress keys);
  37 candidate ids that already existed were renamed inside the NEW
  units only (e.g. `ur_ghar` → `ur_ghar_home`, `ur_seb` → `ur_sayb`);
- new unit titles avoid accidental catalog-substring hits — the domain
  spread (daily 16 / nature 8 / business 6 / culture 7 / travel 5 /
  food 5 / health 4 / basics 3 / tech 2) is pinned in
  `test/path_test.dart`;
- `content_test.dart` pins the per-course shape (56/172/1669) and the
  global vocab total (5427), mirroring `validate_content.py`.

### 4j. Example-sentence coverage floors (v5.4)

`scripts/validate_content.py` and `test/content_test.dart` enforce a
MINIMUM example-sentence coverage per course (en 18% · fr 40% · ur 35% ·
de 95%). The floors are a ratchet — later content waves must raise, never
lower, them. All v5.4 example content is machine-authored and flagged
"needs human review" in docs/CONTENT_AUDIT.md; no official CEFR
certification is claimed.

### 4i. Urdu lesson-for-lesson parity (v5.2)

v5.2 closed the last structural gap: `course_ur.json` now sits at
**56 units / 216 lessons / 2328 words — digit-for-digit the English
course's shape** (and the same 4-lesson-unit spread per level:
A1 12 · A2 12 · B1 18 · B2 5 · C1 1). The wave added 44 themed `l4`
lessons (one for every unit whose English twin has four lessons) plus
exactly one densification word per existing l1/l2/l3 lesson (168
words). Content was authored as `scripts/ur_l4_*.json` batch files +
`scripts/ur_dense.json` and merged by `scripts/expand_urdu_l4.py`,
which enforces four invariants before writing: the stay-at-three unit
set (u7, u8, u24, u25, u32, u33, u55, u56), global id uniqueness
across all four courses, per-lesson emoji uniqueness, and per-lesson
target uniqueness. Not one pre-existing vocab/lesson id moved; the 12
new-item ids that collided with legacy ids were renamed in the new
content only, and 4 same-spelling/different-meaning targets were
swapped for unambiguous words. `content_test.dart` now pins ur at
[56, 216, 2328] with the global total at 6086.

## 4k. Pronunciation skill (v5.6)

`lib/pronunciation.dart` grades the DEVICE speech recognizer's transcript
against the expected text (normalized Levenshtein similarity) — an
APPROXIMATE score by construction, labeled as such in the UI. `SttService`
wraps `speech_to_text` with per-course locale mapping and degrades to an
explicit "unavailable" state on any platform failure (including tests).
The mic permission is optional and only requested on first use of the
screen. No network, no cloud recognizer — consistent with the hard
invariants.

## 4l. Grammar module (v5.7)

`lib/grammar.dart` holds the lesson catalog as DATA (8 contrastive
lessons across the four courses) with a `verify()` contract pinned by
tests; `grammar_screen.dart` is a plain reader + MCQ drills over it. The
catalog is machine-authored ("needs human review" in CONTENT_AUDIT) and
lives outside the course JSONs on purpose — grammar ids are namespaced
`gr_` and can never collide with the append-only vocab ids.

## 4m. Reading skill (v5.8)

`lib/reading.dart` holds leveled texts with aligned Arabic glosses and an
honest corpus lookup (null outside the course). Tap-to-review feeds the
REAL SRS through `rateCard(id, Srs.hard)` — identical to the flashcards
path, so reading practice reshapes the schedule honestly. Texts are
machine-authored ("needs human review").

## 4n. Conversation trainer (v5.9)

Role-play chat behind `ConversationProvider`; the shipped
`OfflineScriptedProvider` is deterministic keyword-group matching over
scripted steps — on-device, zero network (hard invariants). The seam is
deliberately small (`reply(scenario, step, text) → result`): any future
AI provider implements it, but wiring one would change the no-network
invariant and is therefore an explicit user decision. Dialogues are
machine-authored ("needs human review").

## 2b. Storage additions (v5.10)

Multi-profile slots: progress payloads live at `progress_json_v1[_2|_3]`
per device slot (max 3), each with its own corrupt-backup key. Slot 1 is
byte-compatible with every older build — the default stays "no account".
Profile display names are device-level and load unconditionally (a fresh
slot has no payload yet). Opt-in analytics (`RetentionStats`) derive
from the existing xpLog only and never leave the device.

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
