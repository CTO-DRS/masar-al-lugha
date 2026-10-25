#!/usr/bin/env python3
"""v5.2 wave: Urdu matches English lesson-for-lesson.

Appends 44 new l4 lessons (from scripts/ur_l4_*.json) to their units and
1 densification word (from scripts/ur_dense.json) to every existing
l1/l2/l3 lesson. Final shape: 56 units, 216 lessons, 2328 words — exact
structural parity with course_en.json.

Run:  python3 scripts/expand_urdu_l4.py
"""
import collections
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
UR = os.path.join(ROOT, 'assets', 'data', 'course_ur.json')
COURSES = ['en', 'ur', 'fr', 'de']

# Units that must STAY at 3 lessons (mirror en_u13-16/u53-56 positions).
STAY_AT_3 = {'ur_u7', 'ur_u8', 'ur_u24', 'ur_u25', 'ur_u32', 'ur_u33',
             'ur_u55', 'ur_u56'}


def main() -> int:
    with open(UR, encoding='utf-8') as f:
        course = json.load(f)
    by_unit = {u['id']: u for u in course['units']}

    # ---- 1. append the 44 l4 lessons -------------------------------
    l4_added = l4_words = 0
    for path in sorted(glob.glob(os.path.join(HERE, 'ur_l4_*.json'))):
        with open(path, encoding='utf-8') as f:
            for lesson in json.load(f):
                uid = lesson['id'][:lesson['id'].rfind('_l4')]
                if uid in STAY_AT_3:
                    sys.exit(f"FATAL {lesson['id']}: unit must stay at 3 lessons")
                unit = by_unit.get(uid)
                if unit is None:
                    sys.exit(f"FATAL {lesson['id']}: unknown unit {uid}")
                if any(l['id'] == lesson['id'] for l in unit['lessons']):
                    print(f"SKIP already present {lesson['id']}")
                    continue
                unit['lessons'].append(lesson)
                l4_added += 1
                l4_words += len(lesson['vocab'])

    # ---- 2. densify every existing l1/l2/l3 lesson ------------------
    with open(os.path.join(HERE, 'ur_dense.json'), encoding='utf-8') as f:
        dense = json.load(f)
    dense_added = 0
    for lid, word in dense.items():
        unit = by_unit[lid[:lid.rfind('_l')]]
        lesson = next(l for l in unit['lessons'] if l['id'] == lid)
        lesson['vocab'].append(word)
        dense_added += 1

    # ---- 3. invariants ----------------------------------------------
    course_ids = set()
    for lang in COURSES:
        if lang == 'ur':
            continue  # ur ids verified separately against each other below
        with open(os.path.join(ROOT, 'assets', 'data', f'course_{lang}.json'),
                  encoding='utf-8') as f:
            other = json.load(f)
        for u in other['units']:
            for l in u['lessons']:
                for v in l['vocab']:
                    course_ids.add(v['id'])
    all_ids = []
    for u in course['units']:
        for l in u['lessons']:
            for v in l['vocab']:
                all_ids.append(v['id'])
    dup_in_course = [k for k, c in collections.Counter(all_ids).items() if c > 1]
    cross = sorted(set(all_ids) & set(course_ids))
    if dup_in_course:
        sys.exit(f'FATAL duplicate ids inside ur: {dup_in_course[:8]}')
    if cross:
        sys.exit(f'FATAL ids colliding with other courses: {cross[:8]}')

    bad_emoji = bad_target = []
    for u in course['units']:
        for l in u['lessons']:
            emjs = [v.get('emoji', '') for v in l['vocab'] if v.get('emoji')]
            dups = [e for e, c in collections.Counter(emjs).items() if c > 1]
            if dups:
                bad_emoji.append((l['id'], dups))
            tgts = [v['target'] for v in l['vocab']]
            tdups = [t for t, c in collections.Counter(tgts).items() if c > 1]
            if tdups:
                bad_target.append((l['id'], tdups))
    if bad_emoji:
        sys.exit(f'FATAL repeated emoji within lesson: {bad_emoji[:8]}')
    if bad_target:
        sys.exit(f'FATAL repeated target within lesson: {bad_target[:8]}')

    # ---- 4. write ----------------------------------------------------
    with open(UR, 'w', encoding='utf-8') as f:
        json.dump(course, f, ensure_ascii=False, indent=1)
        f.write('\n')

    units = course['units']
    n_l = sum(len(u['lessons']) for u in units)
    n_v = sum(len(l['vocab']) for u in units for l in u['lessons'])
    dist = collections.Counter(u['cefr'] for u in units)
    l4dist = collections.Counter(
        u['cefr'] for u in units if len(u['lessons']) == 4)
    print(f'added {l4_added} l4 lessons ({l4_words} words) + '
          f'{dense_added} dense words')
    print(f'course now: {len(units)} units, {n_l} lessons, {n_v} vocab')
    print('levels:', dict(dist))
    print('4-lesson units by level:', dict(sorted(l4dist.items())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
