# CONTENT AUDIT — course_en / course_ur / course_fr (v3.3 baseline)

**Validator:** `scripts/validate_content.py` (runs in CI from v4.0 — exit 1 on any fatal problem)

## Corpus

| Course | Units | Lessons | Words | TTS lang |
|---|---|---|---|---|
| English | 48 | 188 | 2016 | en-US |
| Urdu | 17 | 55 | 475 | ur-PK |
| French | 15 | 45 | 495 | fr-FR |
| **Total** | **80** | **288** | **2986** | |

## Verified clean

- ✅ JSON parses; required course/unit/lesson/vocab fields present and non-empty
- ✅ **Zero duplicate vocab IDs** within each course **and across all three courses**
  (2986 unique IDs) — user SRS progress keys stay valid
- ✅ Unit colors are valid hex; every lesson has ≥ 1 word
- ✅ Difficulty progression is linear (units unlock in order; earlier units are
  vocabulary-concrete, later units topical — see roadmap for formal CEFR mapping)

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
