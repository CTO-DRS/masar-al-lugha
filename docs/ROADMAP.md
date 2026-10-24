# ROADMAP — Masar Al-Lugha

**Current release: v4.1.0+9** — see docs/PROJECT_AUDIT.md §6 for the v4.1
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

## v4.2 — curriculum depth (SHIPPED: items 1+2)

1. ✅ **EN: 52 units** (phrasal verbs, idioms & sayings, business & money,
   academic & exam prep C1) — plus FR/UR grown to 21 units each.
2. ✅ **Formal CEFR mapping** — every unit tagged A1→C1 (self-referenced; the
   app does **not** claim official certification), level shown as a pill on
   unit banners, validity + monotonicity enforced by
   `scripts/validate_content.py` and `test/content_test.dart`.
3. **Sentence-mining lessons** — longer `isSentence` items with cloze variants.
   *(moved to v4.3 — partially seeded: every v4.2 word ships an example
   sentence, so fill-blank/audio exercises already use real sentences.)*
4. **Audio-first lessons** — TTS-led listening rounds (already no network needed;
   device TTS engine quality is the ceiling, documented in SECURITY_AUDIT.md §7).
   *(moved to v4.3)*

## v4.3 — next

1. Sentence-mining lessons (item 3 above) — dedicated cloze-first lesson type.
2. Audio-first lessons (item 4 above) — TTS-led listening rounds.

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
