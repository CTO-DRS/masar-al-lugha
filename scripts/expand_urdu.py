#!/usr/bin/env python3
"""Expand the Urdu course to full parity (v5.1 wave).

Inserts the 31 hand-authored units from scripts/ur_new_*.json into
assets/data/course_ur.json, keeping the CEFR-monotonic path order:
existing units of each level first, then the new units of that level.

Run:  python3 scripts/expand_urdu.py
"""
import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
COURSE = os.path.join(ROOT, 'assets', 'data', 'course_ur.json')
BATCHES = [
    'ur_new_a1a',   # u26-u29  (A1)
    'ur_new_a1b',   # u30-u33  (A1)
    'ur_new_a2a',   # u34-u37  (A2)
    'ur_new_a2b',   # u38-u41  (A2)
    'ur_new_b1a',   # u42-u45  (B1)
    'ur_new_b1b',   # u46-u49  (B1)
    'ur_new_b1c',   # u50-u51  (B1)
    'ur_new_b2c1',  # u52-u56  (B2 + C1)
]
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']


def main() -> int:
    with open(COURSE, encoding='utf-8') as f:
        course = json.load(f)

    existing_ids = {u['id'] for u in course['units']}
    new_by_level = collections.defaultdict(list)
    added = 0
    added_vocab = 0
    for name in BATCHES:
        path = os.path.join(HERE, f'{name}.json')
        with open(path, encoding='utf-8') as f:
            for unit in json.load(f):
                if unit['id'] in existing_ids:
                    print(f"SKIP duplicate unit id {unit['id']}")
                    continue
                existing_ids.add(unit['id'])
                new_by_level[unit['cefr']].append(unit)
                added += 1
                added_vocab += sum(len(l['vocab']) for l in unit['lessons'])

    old_by_level = collections.defaultdict(list)
    for u in course['units']:
        old_by_level[u['cefr']].append(u)

    units = []
    for lvl in LEVELS:
        units.extend(old_by_level[lvl])
        units.extend(new_by_level[lvl])
    course['units'] = units

    total_vocab = sum(
        len(l['vocab']) for u in units for l in u['lessons'])
    with open(COURSE, 'w', encoding='utf-8') as f:
        json.dump(course, f, ensure_ascii=False, indent=1)
        f.write('\n')

    n_lessons = sum(len(u['lessons']) for u in units)
    print(f'added {added} units / {added_vocab} vocab')
    print(f'course now: {len(units)} units, {n_lessons} lessons, '
          f'{total_vocab} vocab')
    dist = collections.Counter(u['cefr'] for u in units)
    print('levels:', dict(dist))
    return 0


if __name__ == '__main__':
    sys.exit(main())
