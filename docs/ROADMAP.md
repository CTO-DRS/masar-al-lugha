# ROADMAP — Masar Al-Lugha

**Current release: v4.12.0+21** — see docs/PROJECT_AUDIT.md and the v4.12
section below for the placement→level auto-link increment with test
evidence.

## Where we are

| Version | Theme |
|---|---|
| v1.0 | Flutter app born: EN+UR, SRS flashcards, leveled lessons, gamification |
| v2.0 | +170 words, picture rounds, fill-blank, true/false, dictionary tab, 16 badges |
| v3.0 | French course; 1042 new words; new badges |
| v3.1 | +576 words (EN 19-24, UR 11-14, FR 9-12) |
| v3.2 | +10 units (EN 25-28, UR 15-17, FR 13-15) |
| v3.3 | Full English expansion: EN 48 units / 188 lessons / 2016 words — 2986 total |
| **v4.0** | **Audit-driven upgrade: 4 HIGH + 10 MEDIUM defects fixed, schema v2 storage, placement test, dark mode, export/import, honest SRS docs, CI quality gates, 27 tests** |
| v4.0.1 | External review fixes: streak progression (was pinned at 1 — HIGH, test-backed), match-exercise duplicate TTS speak, dead `\|\| true` condition, dark-mode surfaces on flashcards/lesson match/dictionary/settings, debounced saves for XP |
| v4.1 | Architecture & engine polish: `ProfileStore` persistence class extracted (backend-swap seam), tough-words practice lane (`weakestVocab`, feeds real SRS), error-analysis screen (accuracy + top-20 misses), placement re-test entry, 34 tests |
| **v4.2** | **Curriculum depth: EN 52 units (+192 words: phrasal verbs, idioms, business, academic C1), FR/UR 21 units each (+360 words), formal monotonic CEFR ladder A1→C1 on every unit (validator- + test-enforced), CEFR pill on unit banners, `test/content_test.dart` asset tests — 3538 words / 94 units / 334 lessons** |
| v4.3 | Lesson styles on the same corpus: **sentence-mining** (cloze-first: fill-blank on real sentences → sentence building → listen-and-pick-the-sentence) and **audio-first** (TTS-led: hear→word / hear→meaning pass, audio sentence building, listen rounds) with a lesson-style bottom sheet in the learn path — 49 tests |
| v4.4 | **Local intelligence + favorites: on-device insights engine (accuracy trend, best study hour, confusion pairs, smart daily-goal suggestion, review forecast, rule-based tutor tips), Learning Insights screen, confusion capture inside lessons with pair practice, favorites (star in dictionary + dedicated flashcards deck), new launcher icon — 72 tests** |
| v4.5 | **Companion wave: Rafiq & Friends — interactive character system (5 evidence-unlocked companions, 9 event types, 54 bilingual encouragement lines with anti-repeat rotation), speech-bubble moments on lesson result/failed screens, companion picker card in Profile, +180 CEFR words (EN idioms & nuance C1, FR/UR B2→C1) — 104 tests** |
| v4.6 | **Mastery wave: two new exercise types — dictation (hear→type with tolerant grading: case/punctuation/diacritics/spacing) and listening comprehension (hear the sentence→pick its Arabic meaning), wired into all three lesson styles; confusion capture extended to typed answers; +180 words (EN business/economics + argument/persuasion C1, FR argumentation/médias + monde professionnel C1, UR صحافت/میڈیا + رسمی خطابت C1) — 106 units / 370 lessons / 3898 words, 118 tests** |
| v4.7 | **Custom word lists ("قوائمي"): user-authored decks stored in the schema-v2 profile (bounded 12×200, tamper-proof strict parse, stable monotonic word ids), add/remove words with duplicate + length guards, flip-card practice with shuffle + tap-to-hear, full export/import/reset coverage, entry from the Cards tab — 128 tests** |
| v4.8 | **Records board ("السجلات"): all-time personal bests engine (Flutter-free) + dedicated screen — bestStreak / bestDayXp / activeDays counters maintained at zero storage cost inside the existing streak hook, 14-record grid, two-week XP momentum bars, record-broken mascot celebration (10th event, 6 new bilingual lines), entry from Profile — 143 tests** |
| v4.8.1 | **Companion art upgrade: the five characters are redrawn as layered vector art (CustomPainter, normalized 100×100 canvas) — owl tufts + eye discs + feet, chick crest, cat whiskers + tail, fox muzzle + big ears, bunny long ears + blush, per-mood expressions (smile / neutral / worried frown / star + confetti), mood-aware beaks and mouths. No new deps, no images, same Mascot/MascotBubble API — 143 tests** |
| v4.9 | **Living human companions: the cast is redrawn as HUMANS (coach Rafiq with glasses, hijabi classmates Farah/Nur/Salma, curly-haired path expert Zayd) and everything LIVES — idle breathing + blink cycle, celebration hop with raised arms, typewriter speech bubbles with a talking mouth synced to the reveal, tap any companion → it waves and says a fresh encouragement line (6 tap lines), home-path companion greets by time of day (3 slots × 2 lines), reduce-motion respected, animated:false stays static for tests — 153 tests** |
| v4.10 | **The companions never go quiet: automatic speech + ambient chatter — lesson companions react LIVE to every answer (header mascot hops on correct / frowns on wrong, zero taps), the feedback bar speaks a praise line after every correct answer and a gentle nudge after every wrong one (2 new banks × 6 bilingual lines), a fresh spoken line triggers a body gesture automatically (talking-edge motion), and the new `LiveCompanion` widget keeps the home path and profile card talking ALL the time (greeting → 8 ambient motivation lines every 24–36 s, tap = instant reply, paused in background, welcome-back on resume) — 160 tests** |
| v4.11 | **Path determination: 9 thematic fields (business/travel/food/…) tagged over the CEFR-tagged units by a frozen keyword catalog + 3 level tiers (مبتدئ A1–A2 / متوسط B1–B2 / خبير C1+) with band relaxation — a setup wizard stores a per-course plan (field × level) and the learn path re-orders plan units first (never locks); additive null-safe `pathDomain`/`pathTier` maps** |
| v4.12 | **The placement test now AUTO-LINKS its result to the level: `Placement.recommendedTier` reuses the consecutive-pass prefix rule (nothing proven → مبتدئ, ≥ half → متوسط, all → خبير), `AppState.setPathTier` stores it keeping any chosen field, the result card shows a green "level detected" badge, and the setup wizard pre-fills + refreshes the level step from the test** |

## v4.3 — lesson styles (SHIPPED)

1. ✅ **Sentence-mining lessons** — dedicated cloze-first lesson style: up to 6
   fill-blank rounds on real example sentences, up to 4 sentence-arrange
   build rounds, up to 4 listen-to-the-sentence rounds; lessons with thin
   sentence material are topped up with classic drills so every plan is
   playable. Sentence-material coverage: en 881/2208 · fr 264/711 ·
   ur 350/619 vocab items (CONTENT_AUDIT.md — sentence-material coverage).
2. ✅ **Audio-first lessons** — TTS-led listening rounds: every word opens
   as sound (hear→pick word / hear→pick meaning), audio sentence building
   with a replay button, a whole-sentence listening round, and a
   tap-to-hear match boss. Every exercise except the boss carries
   `audioText` (test-enforced).
3. ✅ **Lesson-style chooser** — bottom sheet on lesson tap (learn path):
   Full lesson / Sentence mining / Listening lesson. The hero quick-start
   button keeps the classic one-tap flow; retry keeps the same style.

## v4.4 — local intelligence + favorites (SHIPPED)

1. ✅ **Insights engine (`lib/insights.dart`)** — Flutter-free, rule-based and
   explainable: best study hour (hour buckets, min 8 samples), 7-day accuracy
   trend + trend delta (needs >= 20 answers per half), smart daily-goal
   suggestion (raise +5 after a 6/7 met week with avg >= goal+15, lower -5
   after 4+ missed days, cap 60 / floor 10), top confusion pairs, review
   forecast (due within 24h) and up to 4 prioritized tutor tips. Zero
   network, zero accounts — evidence thresholds everywhere, never guesses.
2. ✅ **Confusion capture** — lesson screen maps every wrong picked option
   (word/meaning text) back to a real vocab id and records the normalized
   pair (`recordConfusion`); pairs are bounded (60 -> top 40). Both the
   wrong MCQ/option flow and the wrong match pairs feed it.
3. ✅ **Learning Insights screen** — privacy banner, 7-day accuracy bars,
   best-hour card, goal suggestion with one-tap apply, confusion pairs with
   a per-pair "practice" CTA, review forecast and the tutor tips list.
   Entry: new insights button on the Profile weak-words card.
4. ✅ **Pair practice** — `WeakWordsScreen(fixedPool: ...)` drills a single
   confusion pair through the same SRS flow.
5. ✅ **Favorites** — star toggle in the dictionary (per course, newest
   first), persisted in the schema-v2 profile, plus a favorites deck in the
   Cards tab (hand-picked words bypass the daily new-card budget by design;
   ratings still flow through the SRS engine).
6. ✅ **New launcher icon** — generated "language path" emblem (winding path
   to a star + A/ع speech bubbles on the brand green gradient), full-bleed
   square + round variants at all 5 mipmap densities (scripts/apply_app_icon.py).

## v4.5 — companion wave (SHIPPED)

1. ✅ **Companion engine (`lib/mascot.dart`)** — Flutter-free, offline,
   deterministic: 5 characters (Rafiq the owl — default; Farah — 500 XP;
   Nur — 7-day streak; Zayd — 50 lessons; Salma — 1500 XP) unlocked by
   evidence the profile already tracks (no new stored state); 9 event
   types (perfect/great/good/struggled/failed/streak-milestone/level-up/
   comeback/idle) with 54 bilingual lines; placeholders {s}/{lvl}/{p}/{m}
   only, test-enforced; deterministic salt-based rotation (no randomness,
   widget-test stable); result-event priority: fresh streak milestone >
   level up > lesson quality.
2. ✅ **Character rendering (`lib/widgets/mascot.dart`)** — shape-drawn
   companions get per-character palettes + ear accessories (owl tufts,
   crest, cat/fox triangles, bunny ears) behind a stable API (`Mascot`
   defaults to rafiq; `MascotMood` re-exported — pre-4.5 call sites keep
   compiling); new `MascotBubble` (speech bubble, entrance animation
   gated by reduce-motion, `showAvatar: false` for screens that already
   render the big companion).
3. ✅ **Three wired surfaces** — LessonResultScreen (companion celebrates
   the computed moment: streak milestone / level-up / lesson quality),
   LessonFailedScreen (comfort, never shame), Profile (companion card:
   comeback bubble after ≥ 3 missed days, tap-to-rotate study tips, full
   cast picker with lock badges + localized unlock hints).
4. ✅ **Persistence** — `mascotId` rides the schema-v2 payload additively
   (`mascot` key); load/import validate against the cast and fall back to
   rafiq on garbage; export/import carry the choice; `resetAll` clears.
5. ✅ **Content +180** — EN u53–u54 (C1 idioms & nuance/register), FR
   u22–u23 (B2 media/debates, C1 literature), UR u22–u23 (B2 poetry &
   idioms, C1 literary language) — corpus now 100 units / 352 lessons /
   3718 words, all ladders reach C1; generators persisted in scripts/.

## v4.6 — mastery wave (SHIPPED)

1. ✅ **Dictation (`ExerciseType.dictation`)** — hear it → type it. The answer
   is graded by `ExerciseGen.normalizeTyped`: case-insensitive, unicode-aware
   punctuation/symbol stripping, whitespace collapsing, Arabic tashkeel +
   tatweel stripping — so "Hello, World!", "hello world" and "مَدْرَسَةٌ" vs
   "مدرسة" all compare equal (Flutter-free, test-enforced). Sentences 2–8
   words dictate from `exampleTarget`/sentence targets; bare words 3–12
   chars dictate as single words, so every lesson can afford a typing round.
   Classic gets 1, audio-first up to 2, sentence-mining 1. The Arabic meaning
   rides in `hint` so the learner knows WHAT to type; a replay button is the
   core interaction. A wrong attempt that exactly spells another known word
   (normalized) feeds the confusion engine ("their" for "there").
2. ✅ **Listening comprehension (`ExerciseType.listenComp`)** — hear the whole
   sentence → pick its Arabic meaning among 4 (correct + 3 real meanings from
   the same lesson). Understanding, not just recognition: the heard text is
   the target-language sentence, the options are Arabic meanings, and the
   answer never equals the audio (test-enforced). Sentence-mining gets up to
   2 rounds, audio-first 1; lessons too poor to supply 3 distinct distractor
   meanings skip the type entirely (graceful degradation).
3. ✅ **UI wiring** — `_dictationBody` (replay button + meaning hint +
   TextField, `onChanged` gates the check button, field disabled after
   answering, cleared on advance); `listenComp` reuses the listen option
   grid with its own caption (`listenUnderstand`); `_speakIfNeeded`,
   `_canCheck`, `_check` and the confusion switch all grew the new cases;
   `onNext` resets the typed field. l10n +3 keys/locale (221).
4. ✅ **Content +180** — EN u55–u56 (C1): Business & Economics (deals,
   markets, workplace), Argument & Persuasion (connectors, hedging,
   persuasive language). FR u24–u25 (B2→C1): Argumentation & Médias, Monde
   professionnel. UR u24–u25 (B2→C1): صحافت اور میڈیا، رسمی خطابت + دستیابی
   اور دفاتر + قانون. Generators persisted (`scripts/content_v46_{en,fr,ur}.py`)
   with pre-flight id-collision abort — 13 EN / 7 FR / 2 UR collisions were
   caught and replaced before any write. Corpus: **106 units / 370 lessons /
   3898 words**, every ladder reaches C1.
5. ✅ **Tests 104 → 118** (+14: `test/exercise_v46_test.dart` — normalizer
   units incl. idempotence, dictation invariants per mode + bare-word
   fallback + tolerant-grading round-trip, listenComp uniqueness/meaning
   guards, and a corpus-wide sweep: first/middle/last lesson of all three
   courses × all three modes keep the v4.6 invariants).

## v4.7 — custom word lists (SHIPPED)

1. ✅ **Deck engine (`lib/decks.dart`, Flutter-free)** — `CustomDeck` /
   `CustomWord` with strict `fromJson` validation: ids must match
   `^cd[0-9]+$` (can never collide with `en_`/`fr_`/`ur_` course ids),
   word ids must belong to their own deck, malformed entries are dropped
   silently, bounds are enforced at parse time (12 decks × 200 words).
   Word ids are **stable across deletions** — a per-deck monotonic
   counter (`next`) survives round-trips, so future per-word progress can
   safely key on them.
2. ✅ **State & persistence** — AppState CRUD (`createCustomDeck`,
   `renameCustomDeck`, `deleteCustomDeck`, `addCustomWord` with duplicate
   (punct/case-folded) + length guards returning l10n error keys,
   `removeCustomWord`, `deckById`); the additive schema-v2 `decks` key
   rides load/save/export/import/reset — payload ids never drive the
   counter (`rebaseDeckCounter`).
3. ✅ **UI** — entry button on the Cards tab → `CustomDecksScreen`
   (decks of the current course + create dialog + empty state with the
   companion) → `CustomDeckScreen` (add-word form with two fields and
   inline error keys, word rows with tap-to-hear + remove, delete-deck
   confirm, practice button disabled when empty) → `DeckPracticeScreen`
   (flip cards, prev/next, shuffle, progress, TTS in the course
   language). l10n +21 keys/locale (242).
4. ✅ **Tests 118 → 128** (+10: validation bounds, dupKey semantics,
   tampered-shape rejection incl. course-id collision attempt, lossless
   round-trip, CRUD with id stability across removals, both budgets,
   reset behavior, save→load survival, export/import carry + tampered
   import drop).

## v4.8 — records board (SHIPPED)

1. ✅ **Records engine (`lib/records.dart`, Flutter-free)** — same
   philosophy as insights: every number derived from data already
   tracked, rules documented next to each record, no estimates.
   `compute(...)` emits 14 display-ordered `RecordStat`s (bestStreak,
   streak, xp, bestDayXp, activeDays, lessons, perfectLessons, stars,
   words, cards, accuracy, customWords, favorites, badges);
   `weeklyXp(xpLog, today)` compares the 7-day window ending today with
   the 7 days before it, using the exact `AppState.todayKey` day-key
   convention.
2. ✅ **Zero-cost record counters** — three additive profile fields
   (`bestStreak`, `bestDayXp`, `activeDays`) maintained inside the
   hooks that already run: `_bumpStreak` (fires exactly once per active
   day → counts the day + stamps the streak record) and `addXp` (stamps
   the day-XP record). No extra stored state beyond the three ints;
   additive null-safe keys ride load/save/export/import/reset.
3. ✅ **Records screen (`lib/screens/records_screen.dart`)** — privacy
   banner, green hero card (current streak / longest streak / total XP),
   two-week XP momentum card with signed delta + trend icon, 2-column
   grid of 14 record tiles (key → localized label + icon map in the
   screen, engine stays Flutter-free). Entry: trophy IconButton next to
   Insights on the Profile weak-words card. l10n +14 keys/locale (235).
4. ✅ **Record-broken celebration** — 10th mascot event `recordBroken`
   (celebrate mood, 6 new bilingual lines, no new placeholders — the
   concrete number sits on the result card next to the mascot);
   `resultEvent` priority: streak milestone > record broken > level up
   > lesson quality; lesson screen captures pre-lesson record evidence.
5. ✅ **Tests 128 → 143** (+15 in `test/records_test.dart`: compute order
   & values, day-key convention, weekly window boundaries incl.
   future/empty/even logs, counter semantics across simulated days
   (same-day, consecutive, 3-day gap), completeLesson feeding, save/load
   + export/import round trips, old-payload zeros, record-vs-levelup
   priority, milestone outranks record, catalog shape/parity/rotation).

## v4.9 — living human companions (SHIPPED)

1. ✅ **Human cast (same IDs, same unlocks)** — the five companions are
   now drawn as people, keeping the persisted `mascotId` values and
   evidence gates intact: Rafiq = personal coach (green polo, glasses),
   Farah = cheerful classmate (orange hijab, blue top), Nur = calm
   night friend (blue hijab, teal top), Zayd = path expert (curly hair,
   yellow tee), Salma = patient mentor (purple hijab). Taglines
   rewritten from animal species to human roles (engine-only change).
2. ✅ **Everyone moves** — `Mascot` is now a `StatefulWidget` driving
   four controllers: idle breathing bob (2.6 s loop), a natural blink
   cycle (one blink per ~4.4 s), a celebration action (springy arm
   raise + hop on `didUpdateWidget` mood change) and a one-shot wave.
   Motion auto-disables under `MediaQuery.disableAnimations` and the
   `animated:false` flag keeps controllers stopped (static art — and
   `pumpAndSettle` keeps terminating in tests).
3. ✅ **Everyone talks** — `MascotBubble` reveals engine lines through a
   typewriter (34 cps, Flutter-free math in `MascotEngine.revealedChars`
   / `revealDuration`), tapping the bubble completes the line instantly,
   and a shared `talking` ValueNotifier drives the companion's mouth
   open/close while the reveal is in flight (auto-synced when the
   bubble renders its own avatar; wired explicitly on lesson result,
   lesson failed, profile card and the new home companion).
4. ✅ **Everyone interacts** — tapping any companion plays a wave and
   (on result/failed/home surfaces) re-rolls a fresh line from the new
   6-line tap bank (`MascotEngine.tapLine`, parity-tested, no
   placeholders). The learn-path hero gained `_HomeCompanion`: it
   greets by time of day (`MascotEngine.greetingLine`, morning 5-11 /
   afternoon 12-17 / night slots, daily salt rotation) and switches to
   celebrate + tap lines when poked.
5. ✅ **Tests 143 → 153** (+10 in `test/mascot_test.dart`: typewriter
   math clamp/rate/full-reveal, tap-line parity+determinism, greeting
   slot boundaries, progressive reveal, tap-to-complete, talking
   notifier lifecycle, tap-wave smoke, static `animated:false`
   settle-ability; the two legacy widget tests moved from
   `pumpAndSettle` to fixed-duration pumps because idle motion now
   intentionally never settles).

## v4.10 — the companions never go quiet (SHIPPED)

1. ✅ **Reactive lesson companions (zero taps)** — the seven in-prompt
   mascots now render the LIVE answer state: on a correct answer the
   header companion hops with raised arms (`_headerMood` → celebrate,
   the mood flip auto-plays the celebration action), on a wrong one it
   shows the worried face — then returns to happy for the next
   exercise. They also render the SELECTED companion for the first
   time (`characterId: st.mascotId` instead of the rafiq default).
2. ✅ **Automatic encouragement in the feedback bar** — after every
   answer the companion speaks WITHOUT any tap: a praise line after a
   correct one (`MascotEngine.praiseLine`, 6 bilingual lines) and a
   gentle nudge after a wrong one (`mascotNudgeLines`, comfort never
   shame), through a compact `MascotBubble` with the typewriter +
   talking mouth. Praise/nudge banks are parity-tested, placeholder-
   free and deterministic (`salt: correctCount` / `salt: mistakes`).
3. ✅ **Speech moves the body** — `Mascot` now listens to the `talking`
   notifier edge (false→true) and plays a gesture burst automatically,
   so every spoken line visibly animates its speaker everywhere (result
   screen, failed screen, feedback bar, live companions) — suppressed
   while a celebration owns the arms or motion is disabled.
4. ✅ **LiveCompanion: talks ALL the time** — a new widget wraps
   `MascotBubble` with an autonomous conversation loop: opening line
   (time-of-day greeting, or a caller-provided `openingText`), then a
   deterministic ambient timer (`MascotEngine.ambientIntervalMs`,
   24–36 s per turn) speaking fresh motivation from the new 8-line
   ambient bank ({s}/{lvl} personalized and fill-tested). Every tap
   (avatar or bubble — `MascotBubble` now forwards `onTap` to its
   avatar too) replies instantly and restarts the quiet window; the
   timer pauses in the background (`WidgetsBindingObserver`) and a
   welcome-back line fires on resume. Wired on the learn path (replaces
   `_HomeCompanion` internals) and the profile companion card.
5. ✅ **Tests 153 → 160** (+7 in `test/mascot_test.dart`: praise/nudge
   parity + script checks + rotation, ambient placeholder allow-list
   {s}/{lvl} + fill + rotation, `ambientIntervalMs` determinism/range/
   variety, LiveCompanion greeting→ambient rotation without input, tap
   replies with fresh lines, reduce-motion still chatters; each widget
   test unmounts at the end so the re-armed timer is cancelled).

## v5.0 — platform growth

1. **Fourth language** (Turkish or German — poll in-app after v4.1).
2. ~~**Local leaderboard** (device-local, offline-only; no accounts by
   design)~~ — SHIPPED in v4.8 as the **Records board** (all-time
   personal bests + weekly momentum; per-course splits can follow).
3. ✅ **Custom word lists** — SHIPPED in v4.7 (user-authored decks in the
   schema-v2 profile, exportable via the existing backup format).
4. **Tablet two-pane layout** — learn path + lesson side-by-side.

## v4.11 — path & level & field determination (SHIPPED)

1. ✅ **Domain catalog (engine, Flutter-free)** — `lib/path.dart` tags every
   unit of every course with one of nine thematic fields (basics, travel,
   food, health, tech, nature, culture, business, daily) via a keyword
   catalog mirroring `scripts/domain_mapping_sim.py`: Latin keywords match
   whole words only (`\b..\b` — a start-only boundary once sent
   "Seasons & Climate" to travel via `sea`), Arabic keywords match by
   substring, first match wins, `daily` is the catch-all — so the 81 shipped
   units partition cleanly (pinned counts in `test/path_test.dart`).
2. ✅ **Level tiers over CEFR** — beginner A1–A2, intermediate B1–B2,
   expert C1+. `PathEngine.build(course, domain, tier)` keeps only units
   inside the requested band, RELAXES one band at a time toward beginner
   when the band is empty in that field (never returns an empty plan), and
   orders the result by CEFR rank (course order as tiebreak) so easier
   material always teaches first.
3. ✅ **Setup wizard** — `PathSetupScreen`: field grid (emoji + unit counts
   per course) → level cards (unit counts per band, empty bands disabled)
   → "start my path" stores the plan per course. The placement test stays
   one tap away for learners unsure of their level.
4. ✅ **The plan re-orders, it never locks** — with a plan active the learn
   path lists the planned units first in pedagogical order, then an
   "other units" divider, then the rest of the course; stars, unlock
   chains and placement skips all keep working unchanged. A compact hero
   banner shows field × level × plan size with edit/remove, and the whole
   thing is additive: `pathDomain`/`pathTier` are per-course maps in the
   schema-v2 payload, null-safe on old backups, unknown names dropped on
   import.

## v4.12 — placement result auto-links the level (SHIPPED)

1. ✅ **One rule, two outputs (engine, Flutter-free)** —
   `Placement.recommendedTier` reuses the exact consecutive-pass prefix
   semantics of `recommendedFlatIndex` and maps the passed-checkpoint count
   through `tierForPassed`: nothing proven (or the first checkpoint failed)
   → beginner, at least half the checkpoints → intermediate, everything →
   expert. Thresholds are ratios (hold for any checkpoint count) and
   degenerate inputs degrade to beginner instead of over-claiming — pinned
   in `test/path_test.dart` ("auto level linking (v4.12)").
2. ✅ **`AppState.setPathTier(courseId, tier)`** — validates the enum name,
   keeps any previously chosen domain (an existing plan moves to the
   detected tier), skips no-op saves, and persists through the existing
   `pathTier` map: save/load and export/import round-trips tested; nothing
   new in the schema, old payloads import untouched. Confirming the
   placement stores the detected level; "start from zero" links the
   beginner tier so no stale higher tier survives a deliberate reset.
3. ✅ **Result screen shows the link** — a green badge on the placement
   result card ("مستواك المحدد من الاختبار: متوسط") renders the detected
   level via the SAME shared `pathTierL10nKey` labels the path banner and
   wizard use (the domain/tier l10n-key + emoji maps moved into
   Flutter-free `path.dart` so all three surfaces share one source of
   truth — no import cycle).
4. ✅ **Wizard pre-fills the level** — `PathSetupScreen` seeds its level
   step from the stored test result (null-safe: no test → unchanged
   manual picker) and refreshes it when the learner returns from the
   placement test launched from its own hint row; the hint now says the
   test detects the level automatically.

## Hard invariants (never break)

- `applicationId com.masar.allugha` is immutable.
- Vocab/lesson IDs are append-only — renaming would orphan user progress.
- No paid APIs, no network in release, no secrets in the repository.
- All claims in docs must be reproducible by a command or a test.
