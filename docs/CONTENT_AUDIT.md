# CONTENT AUDIT — course_en / course_ur / course_fr (v4.2 baseline)

**Validator:** `scripts/validate_content.py` (runs in CI from v4.0 — exit 1 on any fatal problem; since v4.2 it also enforces valid + monotonic CEFR tags)

## Corpus

| Course | Units | Lessons | Words | CEFR ladder | TTS lang |
|---|---|---|---|---|---|
| English | 52 | 204 | 2208 | A1→A2→B1→B2→C1 | en-US |
| Urdu | 21 | 67 | 619 | A1→A2→B1→B2 | ur-PK |
| French | 21 | 63 | 711 | A1→A2→B1→B2 | fr-FR |
| **Total** | **94** | **334** | **3538** | | |

## v4.2 expansion (ROADMAP items 1+2)

- **EN u49–u52** (4 lessons × 12 words each, +192): Phrasal Verbs (B2), Idioms &
  Sayings (B2), Business & Money (B2), Academic & Exams (C1).
- **FR u16–u21** (3 lessons × 12 words each, +216): Health & Body, Clothes &
  Shopping, Weather & Seasons, Digital Life, News & Media (B1), French Idioms (B2).
- **UR u18–u21** (3 lessons × 12 words each, +144): Health & Body, Weather &
  Seasons, News & Media (B1), Urdu Idioms (B2).
- **CEFR mapping** — every unit (old and new) now carries a `cefr` field; the
  ladder is **self-referenced and monotonic** (path order = difficulty order).
  The validator fails on invalid values or any decrease. The app shows the tag
  as a pill on the unit banner. **This is NOT an official CEFR certification** —
  see the classification note below.
- **New-unit quality bar (enforced by the generator script and tests):** every
  new vocab entry has `exampleTarget`/`exampleAr` (feeds fill-blank + listening),
  unique emoji within its lesson, no target/id collisions with shipped content,
  append-only ids (`en_u49_l1`…, `fr_u16_l1`…, `ur_u18_l1`…).
- `test/content_test.dart` loads the real assets in `flutter test` and asserts
  the corpus shape (52/204/2208 · 21/63/711 · 21/67/619 = 3538), CEFR validity
  and monotonicity, global id uniqueness, and per-lesson emoji uniqueness for
  the new units — so a content regression fails both the Python gate and tests.

## Verified clean

- ✅ JSON parses; required course/unit/lesson/vocab fields present and non-empty
  (**including `cefr` on every unit — v4.2**)
- ✅ **Zero duplicate vocab IDs** within each course **and across all three courses**
  (3538 unique IDs) — user SRS progress keys stay valid
- ✅ Unit colors are valid hex; every lesson has ≥ 1 word
- ✅ **CEFR tags valid + monotonic on every unit (v4.2)** — enforced by validator
  and `test/content_test.dart`

## Known issues

### 1. Same-lesson emoji conflicts (24 lessons) — generator-guarded in v4.0
Two different words in the same lesson share one emoji, making picture rounds visually
ambiguous (e.g. `fr_u3_l3`: two words with 🍽️). Rather than mutating shipped vocab
(which risks regressions across 3 languages), v4.0 **fixes the generator**:
`exercise_gen` now excludes shared-emoji words from `wordToPic`/`picToWord` selection,
so an ambiguous picture can never appear as a question or option.

Affected: en_u11_l3, en_u11_l4, en_u12_l3, en_u12_l4, en_u14_l2, en_u15_l1, en_u15_l2,
en_u16_l2, en_u17_l2, en_u17_l4, en_u18_l2, ur_u8_l2, fr_u1_l1, fr_u2_l1, fr_u2_l2,
fr_u3_l2, fr_u3_l3, fr_u4_l1, fr_u4_l2, fr_u4_l3, fr_u5_l1, fr_u5_l3, fr_u7_l2, fr_u8_l3

### 2. Urdu lesson IDs contain raw Urdu text + `؟` (cosmetic)
IDs like `ur_آپ_کیا_کام_کرتے_ہیں؟` are unusual but function correctly (they are opaque
map keys). **They are user-progress keys → will not be renamed** (append-only rule).
Documented as a naming-convention note for future content.

### 3. Fallback distractors (code-level)
Lessons with < 4 distinct words could produce `"___"` placeholder options in old
versions; v4.0 pads from a real global word reserve instead.

## Classification (MASTER PROMPT requirement)

- **Reference-verified content** (validated programmatically): structure, uniqueness,
  field completeness, emoji-distinctness handling, unlock ordering.
- **Needs human review** (cannot be certified by a script): translation nuance and
  naturalness (esp. Urdu idiomatic phrasing), phonetic transcription accuracy
  (`phonetic` is Arabic transliteration), example-sentence grammar at scale, and the
  CEFR *level labels* — the app presents courses as **reference material aligned in
  spirit to CEFR A1→B1 progression; it makes no official certification claim**.

## No emoji dictionary (intentional)

v1–v2 audit history: some words have no emoji by nature (abstract words). The
generator already degrades to text exercises; picture rounds remain optional garnish.
