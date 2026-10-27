#!/usr/bin/env python3
"""Course content validator (v4.2, MASTER PROMPT Wave 5).

Runs against every course JSON in assets/data and FAILS (exit 1) on any
fatal problem, so CI catches broken content before it ships:

  fatal   : missing/empty required fields, duplicate vocab ids (in-course or
            cross-course), invalid JSON, bad unit color, unknown id format,
            bad/missing unit CEFR tag, non-monotonic CEFR progression
            (unit order on the path IS the difficulty order)
  notice  : same-lesson duplicate emojis (the exercise generator now skips
            shared-emoji words for picture rounds, so these are ambiguity
            notes, not defects — see docs/CONTENT_AUDIT.md M10)

Usage:  python3 scripts/validate_content.py [assets/data]
"""
import collections
import json
import os
import sys

REQ_COURSE = ('id', 'nameAr', 'nameEn', 'flag', 'ttsLang', 'units')
REQ_UNIT = ('id', 'titleAr', 'titleEn', 'color', 'lessons', 'cefr')
REQ_LESSON = ('id', 'titleAr', 'titleEn', 'vocab')
REQ_VOCAB = ('id', 'target', 'translationAr')
CEFR_LEVELS = ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')


def walk(course, name, fatal, notices):
    ids = {}
    n_lessons = n_vocab = 0
    prev_cefr_idx = -1
    cefr_seen = []
    for u in course.get('units', []):
        uid = u.get('id', '?')
        for req in REQ_UNIT:
            if req not in u:
                fatal.append(f"{name}: unit {uid} missing field '{req}'")
        color = u.get('color')
        if not (isinstance(color, str) and len(color) in (6, 7)):
            fatal.append(f"{name}: unit {uid} bad color '{color}'")
        cefr = u.get('cefr')
        if cefr not in CEFR_LEVELS:
            fatal.append(f"{name}: unit {uid} bad cefr '{cefr}' "
                         f"(must be one of {','.join(CEFR_LEVELS)})")
            cefr_idx = -1
        else:
            cefr_idx = CEFR_LEVELS.index(cefr)
            if cefr_idx < prev_cefr_idx:
                fatal.append(f"{name}: unit {uid} cefr {cefr} is lower than "
                             f"the previous unit's ({CEFR_LEVELS[prev_cefr_idx]}) "
                             "— path order must be non-decreasing")
            prev_cefr_idx = max(prev_cefr_idx, cefr_idx)
            if not cefr_seen or cefr_seen[-1] != cefr:
                cefr_seen.append(cefr)
        for l in u.get('lessons', []):
            lid = l.get('id', '?')
            n_lessons += 1
            for req in REQ_LESSON:
                if req not in l:
                    fatal.append(f"{name}: lesson {lid} missing '{req}'")
            emj = []
            for v in l.get('vocab', []):
                n_vocab += 1
                vid = v.get('id', '?')
                if vid in ids:
                    fatal.append(f"{name}: DUPLICATE vocab id '{vid}' "
                                 f"({ids[vid]} vs {uid}/{lid})")
                ids[vid] = f"{uid}/{lid}"
                for req in REQ_VOCAB:
                    if not str(v.get(req, '') or '').strip():
                        fatal.append(f"{name}: vocab {vid} missing/empty '{req}'")
                e = v.get('emoji') or ''
                if e:
                    emj.append(e)
            dup = [e for e, c in collections.Counter(emj).items() if c > 1]
            if dup:
                notices.append(f"{name}: lesson {lid} repeated emoji within "
                               f"lesson (picture rounds skip these): {dup}")
    for req in REQ_COURSE:
        if req not in course:
            fatal.append(f"{name}: course missing '{req}'")
    # id format sanity: ids must stay stable (append-only rule) — flag weird
    # new shapes so they never silently become progress-key collisions.
    # Historical exception: v1-era Urdu ids look like 'ur_آپ_کیا...؟' (raw
    # Urdu text). They are already live progress keys and MUST NOT be renamed
    # (docs/PROJECT_AUDIT.md L6), so they are accepted as a notice; any OTHER
    # non-slug id is fatal.
    legacy_urdu = [v for v in ids if v.startswith('ur_') and not v.isascii()]
    if legacy_urdu:
        notices.append(f"{name}: {len(legacy_urdu)} legacy Urdu-text vocab ids "
                       f"(append-only, must not be renamed) e.g. {legacy_urdu[:3]}")
    bad = [v for v in ids
           if v not in set(legacy_urdu)
           and not v.replace('_v31', '').replace('_', '').replace('-', '').isalnum()]
    if bad:
        fatal.append(f"{name}: unusual id format: {bad[:8]}")
    return ids, n_lessons, n_vocab, ('→'.join(cefr_seen) if cefr_seen else '?')


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'data')
    fatal, notices = [], []
    global_ids = {}
    stats = {}
    for lang in ('en', 'ur', 'fr', 'de'):
        path = os.path.join(base, f'course_{lang}.json')
        if not os.path.exists(path):
            fatal.append(f"missing course file: {path}")
            continue
        try:
            with open(path, encoding='utf-8') as f:
                course = json.load(f)
        except json.JSONDecodeError as e:
            fatal.append(f"{lang}: INVALID JSON — {e}")
            continue
        ids, nl, nv, span = walk(course, lang, fatal, notices)
        stats[lang] = (len(course.get('units', [])), nl, nv, span)
        for vid, loc in ids.items():
            if vid in global_ids:
                fatal.append(f"CROSS-COURSE duplicate id '{vid}': "
                             f"{global_ids[vid]} AND {lang}/{loc}")
            global_ids[vid] = f"{lang}/{loc}"

    print("=== CONTENT VALIDATION ===")
    # v5.4: enforced minimum example-sentence coverage per course (mirrors
    # test/content_test.dart). Floors rise as later waves backfill examples.
    # v5.16 (Q4/F4.5): the backfill is complete — every course at 100%.
    MIN_EXAMPLE_COVERAGE = {"en": 1.0, "fr": 1.0, "ur": 1.0, "de": 1.0}
    # v5.16 (Q4/F4.5): verbatim containment of the target inside its example
    # for single-word rows (what _canBlank needs for fill-blank). New rows are
    # guaranteed by construction; the floor locks the CURRENT ratio so legacy
    # conjugated examples (FR/DE verb forms) can neither regress nor silently
    # multiply. Legacy-tolerant by design — counted as a notice below.
    MIN_CONTAINMENT = {"en": 0.99, "ur": 0.99, "fr": 0.85, "de": 0.80}
    for lang, (nu, nl, nv, span) in stats.items():
        print(f"  {lang}: {nu} units, {nl} lessons, {nv} words "
              f"(CEFR {span})")
    print(f"  total unique vocab ids: {len(global_ids)}")
    for lang in ('en', 'ur', 'fr', 'de'):
        path = os.path.join(base, f'course_{lang}.json')
        if not os.path.exists(path):
            continue
        try:
            with open(path, encoding='utf-8') as f:
                course = json.load(f)
        except json.JSONDecodeError:
            continue
        words = [v for u in course.get('units', [])
                 for l in u.get('lessons', []) for v in l.get('vocab', [])]
        if not words:
            continue
        with_ex = sum(1 for v in words
                      if (v.get('exampleTarget') or '').strip()
                      and (v.get('exampleAr') or '').strip())
        ratio = with_ex / len(words)
        floor = MIN_EXAMPLE_COVERAGE[lang]
        mark = "ok" if ratio >= floor else "FAIL"
        print(f"  {lang}: example coverage {with_ex}/{len(words)} = "
              f"{ratio:.1%} (floor {floor:.0%}) [{mark}]")
        if ratio < floor:
            fatal.append(f"{lang}: example coverage {ratio:.1%} below "
                         f"enforced floor {floor:.0%}")
        # v5.16: containment ratio for single-word rows (fill-blank gate)
        single = [v for v in words
                  if ' ' not in (v.get('target') or '').strip()]
        if single:
            okc = sum(1 for v in single
                      if v['target'].strip().lower()
                      in (v.get('exampleTarget') or '').strip().lower())
            rc = okc / len(single)
            cf = MIN_CONTAINMENT[lang]
            mark = "ok" if rc >= cf else "FAIL"
            print(f"  {lang}: containment {okc}/{len(single)} = "
                  f"{rc:.1%} (floor {cf:.0%}) [{mark}]")
            if rc < cf:
                fatal.append(f"{lang}: containment {rc:.1%} below "
                             f"enforced floor {cf:.0%}")
            else:
                missed = len(single) - okc
                if missed:
                    notices.append(
                        f"{lang}: {missed} single-word rows without verbatim "
                        "containment (legacy conjugated examples, "
                        "fill-blank skips them)")
        # v5.16: duplicate examples inside a course are a notice (the same
        # sentence teaching two words weakens both)
        seen_ex = {}
        dup_ex = []
        for v in words:
            ex = (v.get('exampleTarget') or '').strip().lower()
            if not ex:
                continue
            if ex in seen_ex:
                dup_ex.append(v['id'])
            else:
                seen_ex[ex] = v['id']
        if dup_ex:
            notices.append(f"{lang}: {len(dup_ex)} duplicate example "
                           f"sentences e.g. {dup_ex[:5]}")
        # v5.16: dictation word-count gate (2..8 words) for single-word rows
        wc_bad = [v['id'] for v in single
                  if not 2 <= len((v.get('exampleTarget') or '').split()) <= 8]
        if wc_bad:
            notices.append(f"{lang}: {len(wc_bad)} examples outside the "
                           f"2-8 word dictation gate e.g. {wc_bad[:5]}")

    # v5.16 (Q4/F4.5): skill-corpus floors — every course keeps at least four
    # items per skill (reading / conversation / grammar), counted from the
    # Dart catalog ids. Mirrors test/content_test.dart.
    import re
    repo = os.path.dirname(os.path.dirname(base))
    lib = os.path.join(repo, 'lib')
    corpus_counts = {}
    for kind, fname in (("rd", "reading.dart"), ("cv", "conversation.dart"),
                        ("gr", "grammar.dart")):
        p = os.path.join(lib, fname)
        if not os.path.exists(p):
            continue
        with open(p, encoding='utf-8') as f:
            src = f.read()
        found = {m.group(0).strip("'") for m in re.finditer(
            r"'%s_(?:en|ur|fr|de)_[A-Za-z0-9_]+'" % kind, src)}
        for cid in found:
            key = (kind, cid.split('_')[1])
            corpus_counts[key] = corpus_counts.get(key, 0) + 1
    MIN_CORPUS_PER_COURSE = {"rd": 4, "cv": 4, "gr": 4}
    print("  skill corpora (min 4 per course):")
    for kind in ("rd", "cv", "gr"):
        row = []
        for lang in ("en", "ur", "fr", "de"):
            n = corpus_counts.get((kind, lang), 0)
            f = MIN_CORPUS_PER_COURSE[kind]
            if n < f:
                fatal.append(f"{lang}: {kind} corpus has {n} items, "
                             f"floor is {f}")
            row.append(f"{lang}={n}")
        print(f"    {kind}: {' '.join(row)}")

    # v5.16 (Q4/F4.5): KPI — lesson parity between the two flagship courses
    if "en" in stats and "ur" in stats and stats["en"][1] != stats["ur"][1]:
        notices.append(f"lesson parity: en {stats['en'][1]} vs "
                       f"ur {stats['ur'][1]} lessons")
    ok = not fatal
    print(f"=== FATAL: {len(fatal)} | NOTICES: {len(notices)} ===")
    for p in fatal[:60]:
        print(" ✗", p)
    for p in notices[:25]:
        print(" ℹ", p)
    if len(fatal) > 60:
        print(f" ... and {len(fatal) - 60} more fatal")
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
