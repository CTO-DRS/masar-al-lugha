# ROADMAP — Masar Al-Lugha

**Current release: v4.0.0+7** (2026-10-24) — see docs/PROJECT_AUDIT.md §5 for
what the v4.0 upgrade actually changed, with file/line evidence.

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

## v4.1 — architecture & engine polish (next)

1. **Extract `ProfileStore`** — move `load/save/flush/_migrateSchema` out of
   AppState into a dedicated class behind the same API; adds no behavior change,
   unlocks backend swaps (docs/ARCHITECTURE.md §2 decision stays under review).
2. **Weak-words practice mode** — a dedicated review lane driven by
   `wordMistakes` (lifetime error counts already persisted) with its own stats.
3. **Error-analysis screen in Profile** — top-20 mistake words per course,
   accuracy trend from existing `totalAnswers/correctAnswers`.
4. **Placement per course** — currently one placement pass per course start;
   add "re-test" entry for returning users who feel misplaced.

## v4.2 — curriculum depth

1. **EN: 52 units** (idioms, phrasal verbs, business English, exam prep).
2. **Formal CEFR mapping** — tag every unit A1→C1 (self-referenced; the app does
   **not** claim official certification), show level on unit cards.
3. **Sentence-mining lessons** — longer `isSentence` items with cloze variants.
4. **Audio-first lessons** — TTS-led listening rounds (already no network needed;
   device TTS engine quality is the ceiling, documented in SECURITY_AUDIT.md §7).

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
