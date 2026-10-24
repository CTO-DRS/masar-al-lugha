#!/usr/bin/env python3
"""v4.6 content expansion — ENGLISH: units 55-56 (C1).

u55 Business & Economics   (3 lessons x 10 words)
u56 Argument & Persuasion  (3 lessons x 10 words)
Every vocab item: id, target, translationAr, phonetic (Arabic
transliteration), emoji (unique within its lesson), exampleTarget,
exampleAr. Appends to course_en.json (append-only rule: existing ids
untouched). Pre-flight collision check: any vocab id already present in
the corpus aborts the script before writing. Run:
python3 scripts/content_v46_en.py
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
PATH = os.path.join(ROOT, 'assets', 'data', 'course_en.json')


def v(vid, target, ar, ph, emoji, ex_t, ex_a):
    return {
        'id': f'en_{vid}',
        'target': target,
        'translationAr': ar,
        'phonetic': ph,
        'emoji': emoji,
        'exampleTarget': ex_t,
        'exampleAr': ex_a,
    }


U55 = {
    'id': 'en_u55',
    'color': '#0EA5E9',
    'titleAr': 'الأعمال والاقتصاد',
    'titleEn': 'Business & Economics',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'en_u55_l1',
            'titleAr': 'الصفقات والاتفاقات',
            'titleEn': 'Deals & agreements',
            'vocab': [
                v('vendor', 'Vendor', 'مورّد', 'فيندور', '🏪',
                  'Our vendor ships every Monday.',
                  'يشحن مورّدنا كل اثنين.'),
                v('stakeholder', 'Stakeholder', 'صاحب مصلحة', 'ستيكهولدِر', '👥',
                  'Every stakeholder signed the charter.',
                  'وقّع كل صاحب مصلحة على الميثاق.'),
                v('quota', 'Quota', 'حصة مستهدفة', 'كووتا', '🎯',
                  'The team hit its quota early.',
                  'حقق الفريق حصته مبكراً.'),
                v('merger', 'Merger', 'اندماج شركات', 'مَرجَر', '🤝',
                  'The merger created a giant.',
                  'أنشأ الاندماج عملاقاً.'),
                v('consensus', 'Consensus', 'توافق في الرأي', 'كونسِنسِس', '🧩',
                  'After hours, we reached a consensus.',
                  'بعد ساعات وصلنا إلى توافق.'),
                v('compromise', 'Compromise', 'حل وسط', 'كومبرمايز', '⚖️',
                  'A compromise saved the deal.',
                  'أنقذ الحل الوسط الصفقة.'),
                v('agreement', 'Agreement', 'اتفاق', 'أغرِيمِنت', '📜',
                  'We shook hands on the agreement.',
                  'تصافحنا على الاتفاق.'),
                v('leverage', 'Leverage', 'ورقة نفوذ', 'ليفِرِدج', '🎚️',
                  'We used our data as leverage.',
                  'استخدمنا بياناتنا ورقة نفوذ.'),
                v('concession', 'Concession', 'تنازل', 'كونسِشن', '🤲',
                  'Her final concession ended the deadlock.',
                  'أنهى تنازلها الأخير الجمود.'),
                v('follow_up', 'Follow up', 'يتابع الأمر', 'فولو أَب', '📞',
                  'I will follow up next week.',
                  'سأتابع الأمر الأسبوع القادم.'),
            ],
        },
        {
            'id': 'en_u55_l2',
            'titleAr': 'الأسواق والاقتصاد',
            'titleEn': 'Markets & economy',
            'vocab': [
                v('tariff', 'Tariff', 'تعريفة جمركية', 'تاريف', '🚢',
                  'The tariff raised import prices.',
                  'رفعت التعريفة الجمركية أسعار الواردات.'),
                v('downturn', 'Downturn', 'تراجع اقتصادي', 'داونترن', '📉',
                  'The downturn lasted two years.',
                  'استمر التراجع الاقتصادي سنتين.'),
                v('audit', 'Audit', 'تدقيق حسابات', 'أودِت', '🧾',
                  'The audit found no errors.',
                  'لم يجد التدقيق أي أخطاء.'),
                v('outsource', 'Outsource', 'يُعهد للخارج', 'أوتسورس', '🌍',
                  'They outsource the design work.',
                  'يُعهدون بعمل التصميم لجهة خارجية.'),
                v('monopoly', 'Monopoly', 'احتكار', 'منوبولي', '🏰',
                  'That company holds a monopoly.',
                  'تحتفظ تلك الشركة باحتكار.'),
                v('subsidy', 'Subsidy', 'دعم حكومي', 'سَبسِدي', '🏦',
                  'Farmers rely on the subsidy.',
                  'يعتمد المزارعون على الدعم الحكومي.'),
                v('volatility', 'Volatility', 'تقلب حاد', 'فولاتيليتي', '🌊',
                  'Market volatility worried investors.',
                  'أقلق تقلب السوق المستثمرين.'),
                v('forecast', 'Forecast', 'توقّع مالي', 'فوركاست', '🔮',
                  'The forecast predicts slower growth.',
                  'يتوقع التنبؤ نمواً أبطأ.'),
                v('surplus', 'Surplus', 'فائض', 'سَرفَس', '📈',
                  'The country runs a trade surplus.',
                  'تحقق الدولة فائضاً تجارياً.'),
                v('bankruptcy', 'Bankruptcy', 'إفلاس', 'بانكروبتسي', '💳',
                  'Two chains filed for bankruptcy.',
                  'أعلنت سلسلتان إفلاسهما.'),
            ],
        },
        {
            'id': 'en_u55_l3',
            'titleAr': 'ثقافة مكان العمل',
            'titleEn': 'Workplace culture',
            'vocab': [
                v('internship', 'Internship', 'تدريب مهني', 'إنترنشِب', '🎓',
                  'She landed an internship in Berlin.',
                  'حصلت على تدريب مهني في برلين.'),
                v('performance', 'Performance', 'أداء وظيفي', 'بيرفورمنس', '⭐',
                  'Her performance impressed the board.',
                  'أثار أداؤها إعجاب المجلس.'),
                v('workflow', 'Workflow', 'سير العمل', 'ووركفلو', '🔄',
                  'The new workflow saves hours.',
                  'يوفر سير العمل الجديد ساعات.'),
                v('executive', 'Executive', 'تنفيذي', 'إغزيكيتيف', '👔',
                  'The executive approved the budget.',
                  'وافق التنفيذي على الميزانية.'),
                v('feedback', 'Feedback', 'تغذية راجعة', 'فيدباك', '💬',
                  'Honest feedback improves the team.',
                  'صدق التغذية الراجعة يطوّر الفريق.'),
                v('burnout', 'Burnout', 'احتراق وظيفي', 'بَرناوت', '🔥',
                  'Burnout creeps in silently.',
                  'يتسلل الاحتراق الوظيفي بصمت.'),
                v('remote_work', 'Remote work', 'عمل عن بُعد', 'ريموت وورك', '🏠',
                  'Remote work suits focused people.',
                  'يناسب العمل عن بُعد الأشخاص المركّزين.'),
                v('flexibility', 'Flexibility', 'مرونة', 'فليكسِبيليتي', '🤸',
                  'Flexibility keeps parents employed.',
                  'المرونة تُبقي الآباء في وظائفهم.'),
                v('mentor', 'Mentor', 'مرشد مهني', 'منتور', '🧭',
                  'A mentor changed my career.',
                  'غيّر مرشدٌ مهني مسيرتي.'),
                v('resignation', 'Resignation', 'استقالة', 'ريزِغنيشن', '📤',
                  'His resignation surprised everyone.',
                  'فاجأت استقالته الجميع.'),
            ],
        },
    ],
}

U56 = {
    'id': 'en_u56',
    'color': '#7C3AED',
    'titleAr': 'الحجة والإقناع',
    'titleEn': 'Argument & Persuasion',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'en_u56_l1',
            'titleAr': 'أدوات الربط في الحوار',
            'titleEn': 'Discourse connectors',
            'vocab': [
                v('however', 'However', 'غير أنّ', 'هاوإيفِر', '🔄',
                  'However, the results differ.',
                  'غير أن النتائج تختلف.'),
                v('therefore', 'Therefore', 'ومن ثمّ', 'ذيرفور', '🎯',
                  'Therefore, we must act now.',
                  'ومن ثم علينا التحرك الآن.'),
                v('in_addition', 'In addition', 'إضافة إلى ذلك', 'إن أديشن', '➕',
                  'In addition, costs dropped.',
                  'إضافة إلى ذلك انخفضت التكاليف.'),
                v('for_instance', 'For instance', 'على سبيل المثال', 'فور إنستنس', '💡',
                  'For instance, look at Norway.',
                  'على سبيل المثال انظر إلى النرويج.'),
                v('other_hand', 'On the other hand', 'من جهة أخرى', 'أون ذ أَذَر هاند', '🤹',
                  'On the other hand, risks remain.',
                  'من جهة أخرى تبقى المخاطر.'),
                v('as_result', 'As a result', 'نتيجة لذلك', 'آز أ رِزَلت', '⚡',
                  'As a result, trust returned.',
                  'نتيجة لذلك عادت الثقة.'),
                v('in_summary', 'In summary', 'خلاصة القول', 'إن سامري', '📝',
                  'In summary, the plan works.',
                  'خلاصة القول أن الخطة تنجح.'),
                v('admittedly', 'Admittedly', 'يُعترف بذلك', 'أدمِتِدلي', '🎩',
                  'Admittedly, the data is limited.',
                  'يُعترف بأن البيانات محدودة.'),
                v('conversely', 'Conversely', 'بالمقابل', 'كونفَرسلي', '🔁',
                  'Conversely, demand may rise.',
                  'بالمقابل قد يرتفع الطلب.'),
                v('in_conclusion', 'In conclusion', 'في الختام', 'إن كونكلوشن', '🏁',
                  'In conclusion, we recommend patience.',
                  'في الختام نوصي بالصبر.'),
            ],
        },
        {
            'id': 'en_u56_l2',
            'titleAr': 'التدقيق والتقدير',
            'titleEn': 'Hedging & precision',
            'vocab': [
                v('roughly', 'Roughly', 'تقريباً', 'رَفلي', '≈',
                  'Roughly sixty percent agreed.',
                  'وافق نحو ستون بالمئة.'),
                v('approximately', 'Approximately', 'على نحو تقريبي', 'أبروكسِمِتلي', '📏',
                  'It costs approximately ten dollars.',
                  'يكلف تقريباً عشرة دولارات.'),
                v('likely', 'Likely', 'مرجَّح', 'لايكلي', '🎲',
                  'Rain is likely tonight.',
                  'يُرجَّح سقوط المطر الليلة.'),
                v('somewhat', 'Somewhat', 'إلى حدٍّ ما', 'سَموَت', '🔅',
                  'The findings are somewhat surprising.',
                  'النتائج مدهشة إلى حدٍّ ما.'),
                v('tends_to', 'Tends to', 'يميل إلى', 'تِندز تو', '📊',
                  'Demand tends to drop in summer.',
                  'يميل الطلب للانخفاض صيفاً.'),
                v('on_average', 'On average', 'في المتوسط', 'أون أفِرِدج', '⚖️',
                  'On average, users read ten minutes.',
                  'في المتوسط يقرأ المستخدم عشر دقائق.'),
                v('virtually', 'Virtually', 'عملياً', 'فَرشوَلي', '🫥',
                  'Virtually all testers succeeded.',
                  'عملياً نجح كل المختبرين.'),
                v('marginally', 'Marginally', 'بهامش ضئيل', 'مارجِنَلي', '🪶',
                  'Prices fell marginally last quarter.',
                  'انخفضت الأسعار بهامش ضئيل الربع الماضي.'),
                v('broadly', 'Broadly', 'على نطاق واسع', 'برودلي', '🌐',
                  'Broadly, the theory holds.',
                  'على نطاق واسع تنطبق النظرية.'),
                v('strictly', 'Strictly speaking', 'بدقة القول', 'ستريكتلي سبيكينغ', '🔬',
                  'Strictly speaking, that is an estimate.',
                  'بدقة القول هذا تقدير.'),
            ],
        },
        {
            'id': 'en_u56_l3',
            'titleAr': 'لغة الإقناع',
            'titleEn': 'Persuasive language',
            'vocab': [
                v('convince', 'Convince', 'يُقنع', 'كونفِنس', '🎯',
                  'She convinced the whole committee.',
                  'أقنعت اللجنة بأكملها.'),
                v('persuade', 'Persuade', 'يُقنع بالحجة', 'برسويد', '🧲',
                  'They persuaded voters with facts.',
                  'أقنعوا الناخبين بالحقائق.'),
                v('proof', 'Proof', 'إثبات', 'بروف', '🔍',
                  'Keep every receipt as proof.',
                  'احفظ كل إيصال كإثبات.'),
                v('claim', 'Claim', 'ادعاء', 'كلايم', '🗯️',
                  'His claim lacks any source.',
                  'ادعاؤه يفتقر لأي مصدر.'),
                v('counterargument', 'Counterargument', 'حجة مضادة', 'كونتَرأرغيومِنت', '🔀',
                  'A strong counterargument emerged.',
                  'برزت حجة مضادة قوية.'),
                v('emphasize', 'Emphasize', 'يؤكّد على', 'إمفَسايز', '🔆',
                  'Let me emphasize one point.',
                  'دعني أؤكد على نقطة واحدة.'),
                v('insight', 'Insight', 'رؤية ثاقبة', 'إنسايت', '💡',
                  'Her insight explained the trend.',
                  'فسّرت بصيرتها الاتجاه.'),
                v('compelling', 'Compelling', 'مقنع بقوة', 'كوميلينغ', '🧨',
                  'She made a compelling case.',
                  'قدّمت حجة مقنعة بقوة.'),
                v('bias', 'Bias', 'انحياز', 'بايِس', '🎭',
                  'Watch for sampling bias.',
                  'انتبه للانحياز في العينة.'),
                v('standpoint', 'Standpoint', 'وجهة نظر', 'ستاندبوينت', '📍',
                  'From a financial standpoint, it works.',
                  'من الناحية المالية، الأمر ينجح.'),
            ],
        },
    ],
}


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    existing_units = {u['id'] for u in data['units']}
    existing_ids = {
        item['id']
        for u in data['units']
        for l in u.get('lessons', [])
        for item in l.get('vocab', [])
    }
    collisions = [
        item['id']
        for unit in (U55, U56)
        for l in unit['lessons']
        for item in l['vocab']
        if item['id'] in existing_ids
    ]
    if collisions:
        print('FATAL: vocab id collisions:', sorted(set(collisions)))
        sys.exit(1)
    added = 0
    for unit in (U55, U56):
        if unit['id'] not in existing_units:
            data['units'].append(unit)
            added += 1
    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    words = sum(
        len(l['vocab']) for unit in (U55, U56) for l in unit['lessons'])
    print(f'en: appended {added} units, {words} words '
          f'(total units now {len(data["units"])})')


if __name__ == '__main__':
    main()
