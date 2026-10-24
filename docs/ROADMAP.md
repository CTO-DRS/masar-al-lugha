# ROADMAP — Masar Al-Lugha

**Current release: v4.7.0+15** — see docs/PROJECT_AUDIT.md §12 for the v4.7
increment with file/test evidence.

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

## v5.0 — platform growth

1. **Fourth language** (Turkish or German — poll in-app after v4.1).
2. **Local leaderboard** (device-local, offline-only; no accounts by design).
3. ✅ **Custom word lists** — SHIPPED in v4.7 (user-authored decks in the
   schema-v2 profile, exportable via the existing backup format).
4. **Tablet two-pane layout** — learn path + lesson side-by-side.

## Hard invariants (never break)

- `applicationId com.masar.allugha` is immutable.
- Vocab/lesson IDs are append-only — renaming would orphan user progress.
- No paid APIs, no network in release, no secrets in the repository.
- All claims in docs must be reproducible by a command or a test.
