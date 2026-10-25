#!/usr/bin/env python3
"""Replicates lib/path.dart PathEngine.domainOfUnit exactly and prints
per-domain unit counts per course — used to pin path_test expectations.

Rules (must stay in sync with lib/path.dart _catalog / domainOfUnit):
- catalog order: basics, travel, food, health, tech, nature, culture,
  business; unmatched titles fall back to 'daily';
- Latin keywords match whole words (\\b..\\b, case-insensitive) against
  titleEn lowercased;
- Arabic keywords match by substring against titleAr;
- first domain in catalog order wins.
"""
import json
import os
import re
import sys

CATALOG = [
    ('basics', ['basics', 'numbers', 'colors', 'days', 'alphabet', 'calendar',
                'أساسيات', 'أرقام', 'الوقت', 'ألوان', 'أيام', 'تقويم']),
    ('travel', ['travel', 'transport', 'airport', 'flying', 'hotel', 'beach',
                'sea', 'سفر', 'مواصلات', 'مطار', 'طيران', 'فندق', 'شاطئ',
                'بحر']),
    ('food', ['food', 'drink', 'restaurant', 'kitchen', 'cook', 'flavor',
              'cafe', 'طعام', 'شراب', 'مطعم', 'مطبخ', 'أطعمة', 'نكهات',
              'مأكولات', 'حلويات']),
    ('health', ['health', 'body', 'illness', 'medicine', 'doctor', 'emergency',
                'safety', 'symptom', 'صحة', 'جسم', 'مرض', 'علاج', 'طبيب',
                'طوارئ', 'سلامة', 'أعراض']),
    ('tech', ['technology', 'science', 'laboratory', 'internet', 'devices',
              'تقنية', 'علوم', 'مختبر', 'أجهزة', 'إنترنت', 'تواصل']),
    ('nature', ['animals', 'nature', 'weather', 'space', 'astronomy',
                'geography', 'farm', 'birds', 'insects', 'seasons', 'climate',
                'countryside', 'حيوان', 'طبيعة', 'طقس', 'فضاء', 'فلك',
                'جغرافيا', 'مزرعة', 'طيور', 'حشرات', 'فصول', 'مناخ', 'ريف']),
    ('culture', ['music', 'movie', 'entertainment', 'celebrations',
                 'traditions', 'idioms', 'poetry', 'media', 'news', 'press',
                 'literary', 'موسيقى', 'أفلام', 'مناسبات', 'تقاليد',
                 'اصطلاح', 'محاور', 'شعر', 'إعلام', 'أخبار', 'صحافة',
                 'ترفيه', 'أدب', 'تعبيرات', 'أعياد']),
    ('business', ['business', 'economics', 'money', 'bank', 'office', 'work',
                  'job', 'law', 'government', 'market', 'shopping', 'commerce',
                  'career', 'أعمال', 'تجارة', 'اقتصاد', 'مال', 'بنك', 'عمل',
                  'مهن', 'مكتب', 'سوق', 'قانون', 'تسوق', 'حكومة', 'صفقات']),
]


def is_latin(s):
    return all(ord(c) < 0x600 for c in s)


def domain_of_unit(unit):
    latin = unit['titleEn'].lower()
    for domain, kws in CATALOG:
        for kw in kws:
            if is_latin(kw):
                if re.search(r'\b' + re.escape(kw) + r'\b', latin):
                    return domain
            elif kw in unit['titleAr']:
                return domain
    return 'daily'


def main():
    base = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), 'assets', 'data')
    for lang in ('en', 'ur', 'fr', 'de'):
        course = json.load(open(os.path.join(base, f'course_{lang}.json'),
                                encoding='utf-8'))
        counts = {}
        detail = {}
        for u in course['units']:
            d = domain_of_unit(u)
            counts[d] = counts.get(d, 0) + 1
            detail.setdefault(d, []).append(u['id'])
        order = [d for d, _ in CATALOG] + ['daily']
        line = '  '.join(f"{d}={counts.get(d, 0)}" for d in order
                         if counts.get(d, 0) > 0)
        print(f"{lang}: total={len(course['units'])} | {line}")
        if lang == 'de':
            for d in order:
                if d in detail:
                    print(f"   {d}: {', '.join(detail[d])}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
