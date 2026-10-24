# ROADMAP — Masar Al-Lugha

**Current release: v4.3.0+11** — see docs/PROJECT_AUDIT.md §8 for the v4.3
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

## v5.0 — platform growth

1. **Fourth language** (Turkish or German — poll in-app after v4.1).
2. **Local leaderboard** (device-local, offline-only; no accounts by design).
3. **Custom word lists** — user-authored decks stored in the same schema-v2
   profile; exportable via the existing backup format.
4. **Tablet two-pane layout** — learn path + lesson side-by-side.

## Hard invariants (never break)

- `applicationId com.masar.allugha` is immutable.
- Vocab/lesson IDs are append-only — renaming would orphan user progress.
- No paid APIs, no network in release, no secrets in the repository.
- All claims in docs must be reproducible by a command or a test.
