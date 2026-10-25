# CONTENT AUDIT — course_en / course_ur / course_fr (v4.6 baseline)

**Validator:** `scripts/validate_content.py` (runs in CI from v4.0 — exit 1 on any fatal problem; since v4.2 it also enforces valid + monotonic CEFR tags)

## Corpus

| Course | Units | Lessons | Words | Example coverage | CEFR ladder | TTS lang |
|---|---|---|---|---|---|---|
| English | 56 | 216 | 2328 | 21.0% | A1→A2→B1→B2→C1 | en-US |
| Urdu | 56 | 216 | 2328 | 39.3% | A1→A2→B1→B2→C1 | ur-PK |
| French | 25 | 75 | 831 | 41.6% | A1→A2→B1→B2→C1 | fr-FR |
| German | 25 | 75 | 779 | 100.0% | A1→A2→B1→B2→C1 | de-DE |
| **Total** | **162** | **582** | **6266** | | | |

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

## Sentence-material coverage (v4.3 — lesson styles)

v4.3 adds sentence-mining and audio-first lesson styles that mine the
`exampleTarget`/`exampleAr` fields and multi-word (`isSentence`) items.
Coverage counted over the shipped corpus (vocab items usable by the
sentence plan: multi-word item, or example containing its target word):

| Course | Sentence-plan candidates | Total vocab | Coverage |
|---|---|---|---|
| English | 881 | 2208 | 39.9% |
| French | 264 | 711 | 37.1% |
| Urdu | 350 | 619 | 56.5% |

What this means in practice: the sentence plan opens with real-sentence
cloze/build rounds wherever material exists; lessons with thin material
(<5 sentence exercises) are transparently topped up with classic drills, so
**every** lesson stays playable in every style (test-enforced in
`test/lesson_modes_test.dart`). Expanding example-sentence coverage on the
legacy (pre-v4.2) vocab is the natural next content task — new v4.2+ words
already ship examples by generator contract.

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

## v4.5 expansion (companion wave)

- **EN u53–u54** (3 lessons × 10 words each, +60, all C1): Idioms &
  Expressions (fresh idioms, pre-checked against the v4.2 u50 idiom set —
  no target/id overlap), Nuance & Register (formal verbs, precise
  adjectives, academic connectors). Every item carries Arabic
  transliteration + unique emoji + example sentence pair.
- **FR u22–u23** (3 × 10, +60): Médias & Débats (B2) and Littérature &
  Nuances (C1) — media nouns, debate verbs, literary terms, hint/clarify
  verbs, poetic vocabulary.
- **UR u22–u23** (3 × 10, +60): شاعری اور محاورے (B2) — poetry terms and
  common idioms — and زبانِ ادب (C1) — literary adjectives/verbs and
  text-element nouns. Urdu-script targets with Arabic-script pronunciation
  aids; legacy Urdu-text id shapes untouched (append-only rule respected).
- **Authoring pipeline**: content shipped as persisted, re-runnable
  generators `scripts/content_v45_{en,fr,ur}.py` (pre-checked every target
  AND id against the live corpus before append; fixed 2 EN id collisions,
  1 FR mixed-script phonetic, 4 UR target/id collisions caught pre-flight).
- **Validation**: `validate_content.py` → PASS (0 fatal), CEFR ladders now
  end at C1 for all three courses; `test/content_test.dart` counts updated
  (100 units / 352 lessons / 3718 words) and the append-only tail test now
  pins u53–u54 / u22–u23 with the v4.2 tail intact.

## v4.6 expansion (mastery wave)

- **EN u55–u56** (3 lessons × 10 words each, +60, all C1): Business &
  Economics (deals & agreements, markets & economy, workplace culture) and
  Argument & Persuasion (discourse connectors, hedging & precision,
  persuasive language). Both units feed the new dictation/listening-
  comprehension rounds richly: every item carries an example sentence pair.
- **FR u24–u25** (3 × 10, +60, B2→C1): Argumentation & Médias (opinion
  markers, debate verbs, press nouns) and Monde professionnel (recruitment,
  meetings & projects, career).
- **UR u24–u25** (3 × 10, +60, B2→C1): صحافت اور میڈیا (news & reporting,
  media & society, formal oratory) and دستیابی اور دفاتر (offices &
  correspondence, law & justice, thought & reasoning). Urdu-script targets
  with Arabic-script pronunciation aids; legacy Urdu id shapes untouched.
- **Authoring pipeline**: persisted, re-runnable generators
  `scripts/content_v46_{en,fr,ur}.py` with a hard pre-flight abort on any
  vocab-id already present in the live corpus: 13 EN / 7 FR / 2 UR
  collisions were caught and replaced before any write.
- **Validation**: `validate_content.py` → PASS (0 fatal); all CEFR ladders
  end at C1. `test/content_test.dart` counts updated (106 units / 370
  lessons / 3898 words) and the append-only tail test now pins u55–u56
  (en) / u24–u25 (fr, ur) with the v4.5 tail (u53–u54 / u22–u23) intact.
- **Dictation/comprehension fit**: the new exercise types draw on
  `exampleTarget`/example-Arabic pairs — every v4.5+v4.6 word ships with
  them by authoring rule, so the newest 12 units are fully usable in all
  three lesson styles.

## v5.4 wave — GENERATED CONTENT REQUIRES HUMAN REVIEW

This wave (v5.4) added: German backfill sentences (522), German units
de_u21–de_u25 (5 units / 15 lessons / 180 words, per-level insertion),
Urdu backfill sentences (500). All of it was machine-authored in this
project's pipeline and is marked as **needing human review**:

- German target sentences and their Arabic glosses follow A2–C1 grammar
  but were NOT reviewed by a certified German/Arabic teacher.
- Urdu sentences use standard register (خالص اردو) with Arabic glosses;
  Urdu phonetics for the new units follow the same approximation policy
  as the shipped course (documented below) — Arabic readers may find
  regional variants differ.
- The CEFR tags remain SELF-REFERENCED and monotonic; this is still NOT
  an official CEFR certification.
- Example sentences were chosen so the target string appears verbatim
  (cloze-compatible); where grammar forbids a verbatim match, the item
  degrades gracefully to build/listen/dictation rounds (by design).

Enforced floors (validator + `test/content_test.dart`): en ≥18% ·
fr ≥40% · ur ≥35% · de ≥95%. Later waves must RAISE these floors, never
lower them.
