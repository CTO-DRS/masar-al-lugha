#!/usr/bin/env python3
"""Course content validator (v4.0, MASTER PROMPT Wave 5).

Runs against every course JSON in assets/data and FAILS (exit 1) on any
fatal problem, so CI catches broken content before it ships:

  fatal   : missing/empty required fields, duplicate vocab ids (in-course or
            cross-course), invalid JSON, bad unit color, unknown id format
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
REQ_UNIT = ('id', 'titleAr', 'titleEn', 'color', 'lessons')
REQ_LESSON = ('id', 'titleAr', 'titleEn', 'vocab')
REQ_VOCAB = ('id', 'target', 'translationAr')


def walk(course, name, fatal, notices):
    ids = {}
    n_lessons = n_vocab = 0
    for u in course.get('units', []):
        uid = u.get('id', '?')
        for req in REQ_UNIT:
            if req not in u:
                fatal.append(f"{name}: unit {uid} missing field '{req}'")
        color = u.get('color')
        if not (isinstance(color, str) and len(color) in (6, 7)):
            fatal.append(f"{name}: unit {uid} bad color '{color}'")
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
    return ids, n_lessons, n_vocab


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'data')
    fatal, notices = [], []
    global_ids = {}
    stats = {}
    for lang in ('en', 'ur', 'fr'):
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
        ids, nl, nv = walk(course, lang, fatal, notices)
        stats[lang] = (len(course.get('units', [])), nl, nv)
        for vid, loc in ids.items():
            if vid in global_ids:
                fatal.append(f"CROSS-COURSE duplicate id '{vid}': "
                             f"{global_ids[vid]} AND {lang}/{loc}")
            global_ids[vid] = f"{lang}/{loc}"

    print("=== CONTENT VALIDATION ===")
    for lang, (nu, nl, nv) in stats.items():
        print(f"  {lang}: {nu} units, {nl} lessons, {nv} words")
    print(f"  total unique vocab ids: {len(global_ids)}")
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
