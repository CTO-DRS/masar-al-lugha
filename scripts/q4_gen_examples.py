#!/usr/bin/env python3
"""Q4/F4.1 orchestrator: fill every missing example sentence.

Usage (from repo root):
  python3 scripts/q4_gen_examples.py            # dry-run: report + samples
  python3 scripts/q4_gen_examples.py --write    # persist JSON changes

Rules:
  - only rows with an empty exampleTarget/exampleAr are filled;
  - existing examples are never modified (append-only culture);
  - new examples must contain the target verbatim (case-insensitive),
    be 2..8 words long, and be unique inside their course;
  - deterministic output (seeded by course+word id).
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from q4_engine import apply_frame, classify, seed_for, validate_pair
import q4_lang_en as en_mod
import q4_lang_fr as fr_mod
import q4_lang_ur as ur_mod

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "data")
COURSES = {
    "en": en_mod,
    "ur": ur_mod,
    "fr": fr_mod,
    # de is already 100% covered — kept as the style reference, untouched
}
LEFTOVER_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "q4_leftovers.txt"
)


def norm_key(course, target):
    target = target.strip()
    return target.lower() if course in ("en", "fr") else target


HAND_ONLY = {"interject", "unknown", "adj", "adv", "fragment"}


def fill_course(course, mod, write):
    path = os.path.join(BASE, f"course_{course}.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    missing = []
    partial = []
    for u in data["units"]:
        for l in u["lessons"]:
            for w in l["vocab"]:
                has_t = bool((w.get("exampleTarget") or "").strip())
                has_a = bool((w.get("exampleAr") or "").strip())
                if has_t != has_a:
                    partial.append(w)  # never overwrite half-filled rows
                elif not has_t:
                    missing.append(w)
    if partial:
        print(f"  WARNING: {len(partial)} partial rows (one field set) "
              "left untouched for hand-fixing")

    used_examples = set()
    for u in data["units"]:
        for l in u["lessons"]:
            for w in l["vocab"]:
                ex = (w.get("exampleTarget") or "").strip()
                if ex:
                    used_examples.add(ex.lower())

    class_counts = {}
    filled, leftovers, generated = 0, [], []
    for w in missing:
        target = (w.get("target") or "").strip()
        cls = classify(w, course)
        class_counts[cls] = class_counts.get(cls, 0) + 1
        pair = mod.BANK.get(w["id"]) or mod.TARGET_BANK.get(
            norm_key(course, target)) or mod.OVERRIDES.get(norm_key(course, target))
        if pair is not None:
            err = validate_pair(pair[0], pair[1], w)
            if err is not None:
                leftovers.append((target, w.get("translationAr", ""),
                                  f"bank-invalid:{err}"))
                continue
            if pair[0].strip().lower() in used_examples:
                leftovers.append((target, w.get("translationAr", ""),
                                  "bank-duplicate"))
                continue
            _apply(w, pair)
            used_examples.add(pair[0].strip().lower())
            filled += 1
            generated.append((target, pair[0], pair[1]))
            continue
        if cls in HAND_ONLY:
            leftovers.append((target, w.get("translationAr", ""), cls))
            continue
        if cls == "sentence" and len(target.split()) > 5:
            leftovers.append((target, w.get("translationAr", ""), cls))
            continue
        seed = seed_for(course, w["id"])
        frames = mod.frames_for(cls, w, course)
        done = False
        for i in range(len(frames)):
            frame = frames[(seed + i) % len(frames)]
            got = apply_frame(frame, w)
            if got is None:
                continue
            err = validate_pair(got[0], got[1], w)
            if err is not None:
                continue
            if got[0].strip().lower() in used_examples:
                continue
            _apply(w, got)
            used_examples.add(got[0].strip().lower())
            filled += 1
            generated.append((target, got[0], got[1]))
            done = True
            break
        if not done and pair is None:
            leftovers.append((target, w.get("translationAr", ""), cls))
    print(f"=== {course.upper()} === missing={len(missing)} filled={filled} "
          f"leftovers={len(leftovers)} classes={class_counts}")

    random.seed(29 + len(generated))
    print(f"--- {course}: sample of GENERATED examples ---")
    for target, ex, ar in random.sample(
            generated, min(24, len(generated))):
        print(f"  {target!r:36} -> {ex!r}")
        print(f"  {'':36}    {ar!r}")

    if write and filled:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"  written: {path}")
    return course, missing, filled, leftovers


def _apply(w, pair):
    w["exampleTarget"] = pair[0]
    w["exampleAr"] = pair[1]


def dump_samples(course):
    path = os.path.join(BASE, f"course_{course}.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    rows = [w for u in data["units"] for l in u["lessons"] for w in l["vocab"]
            if (w.get("exampleTarget") or "").strip()]
    # only freshly filled ones have no emoji-tagged marker; sample by class mix
    random.seed(len(rows))
    picks = random.sample(rows, min(28, len(rows)))
    print(f"--- {course}: sample of filled examples ---")
    for w in picks:
        print(f"  {w['target']!r:36} -> {w['exampleTarget']!r}")
        print(f"  {'':36}    {w['exampleAr']!r}")


def main():
    write = "--write" in sys.argv
    all_leftovers = []
    for course, mod in COURSES.items():
        _, _, _, leftovers = fill_course(course, mod, write)
        all_leftovers.extend((course,) + x for x in leftovers)
    if all_leftovers:
        with open(LEFTOVER_FILE, "w", encoding="utf-8") as f:
            for course, target, tr, cls in all_leftovers:
                f.write(f"{course}\t{target}\t{tr}\t{cls}\n")
        print(f"\nleftover list -> {LEFTOVER_FILE} ({len(all_leftovers)} rows)")
        for course, target, tr, cls in all_leftovers[:20]:
            print(f"  {course} {target!r} ({tr!r}) [{cls}]")
    else:
        print("\nno leftovers — full coverage")


if __name__ == "__main__":
    main()
