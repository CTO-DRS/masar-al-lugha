#!/usr/bin/env python3
"""v4.5 content expansion — FRENCH: units 22-23.

u22 Médias & Débats       (B2, 3 lessons x 10 words)
u23 Littérature & Nuances (C1, 3 lessons x 10 words)
Every vocab item: id, target, translationAr, phonetic (Arabic
transliteration), emoji (unique within its lesson), exampleTarget,
exampleAr. Appends to course_fr.json (append-only rule). Candidate
targets/ids were pre-checked against the existing corpus; run
validate_content.py afterwards. Run: python3 scripts/content_v45_fr.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')
PATH = os.path.join(ROOT, 'assets', 'data', 'course_fr.json')


def v(vid, target, ar, ph, emoji, ex_t, ex_a):
    return {
        'id': f'fr_{vid}',
        'target': target,
        'translationAr': ar,
        'phonetic': ph,
        'emoji': emoji,
        'exampleTarget': ex_t,
        'exampleAr': ex_a,
    }


U22 = {
    'id': 'fr_u22',
    'color': '#FFC800',
    'titleAr': 'الإعلام والنقاشات',
    'titleEn': 'Media & Debates',
    'cefr': 'B2',
    'lessons': [
        {
            'id': 'fr_u22_l1',
            'titleAr': 'عالم الإعلام',
            'titleEn': 'The media world',
            'vocab': [
                v('les_medias', 'les médias', 'وسائل الإعلام', 'لي ميديا', '📺',
                  'Les médias suivent l\'événement de près.', 'وسائل الإعلام تتابع الحدث عن قرب.'),
                v('le_presentateur', 'le présentateur', 'المذيع مقدّم البرنامج', 'لبريزانتاتور', '🎤',
                  'Le présentateur annonce les résultats.', 'يعلن المذيع النتائج.'),
                v('une_source', 'une source', 'مصدر (خبر)', 'أن سورس', '🔎',
                  'Le journal cite une source fiable.', 'تستشهد الجريدة بمصدر موثوق.'),
                v('actualite', 'l\'actualité', 'الأخبار والمستجدات', 'لاكتواليتي', '🗞️',
                  'L\'actualité change chaque heure.', 'تتغير الأخبار كل ساعة.'),
                v('un_sondage', 'un sondage', 'استطلاع رأي', 'أن سون داج', '📊',
                  'Le sondage surprend les experts.', 'يُفاجئ استطلاع الرأي الخبراء.'),
                v('reportage', 'un reportage', 'تقرير صحفي مصوّر', 'أن ريبورتاج', '🎥',
                  'Son reportage a gagné un prix.', 'فاز تقريره بجائزة.'),
                v('propagande', 'la propagande', 'الدعاية المضللة', 'لا بروباغاند', '📢',
                  'La propagande répand des mensonges.', 'تنشر الدعاية الأكاذيب.'),
                v('fausses_nouvelles', 'les fausses nouvelles', 'الأخبار الزائفة', 'لي فوس نوڤيل', '⚠️',
                  'Ne partagez pas les fausses nouvelles.', 'لا تشاركوا الأخبار الزائفة.'),
                v('un_scoop', 'un scoop', 'خبر حصري مُثير', 'أن سكوب', '🚨',
                  'Le journaliste a décroché un scoop.', 'حصل الصحفي على خبر حصري.'),
                v('entretien', 'un entretien', 'مقابلة (صحفية/رسمية)', 'أن أونتروتيان', '🗓️',
                  'L\'entretien dure trente minutes.', 'تدوم المقابلة ثلاثين دقيقة.'),
            ],
        },
        {
            'id': 'fr_u22_l2',
            'titleAr': 'أفعال النقاش',
            'titleEn': 'Debate verbs',
            'vocab': [
                v('affirmer', 'affirmer', 'يجزم ويؤكد', 'أفيرمي', '✅',
                  'Il affirme son innocence.', 'يجزم براءته.'),
                v('nier', 'nier', 'ينكر', 'نييه', '🚫',
                  'Elle nie avoir vu la lettre.', 'تنكر أنها رأت الرسالة.'),
                v('convaincre', 'convaincre', 'يقنع', 'كونفانكر', '🧠',
                  'Il a convaincu tout le jury.', 'أقنع لجنة التحكيم بأكملها.'),
                v('persuader', 'persuader', 'يُغرِ ويقنع بالحجة', 'بيرسوادي', '🤝',
                  'Elle persuade ses collègues facilement.', 'تقنع زملاءها بسهولة.'),
                v('soutenir', 'soutenir', 'يدعم ويؤيّد', 'سوتونير', '🛡️',
                  'Je soutiens cette proposition.', 'أؤيد هذا الاقتراح.'),
                v('contredire', 'contredire', 'يعارض ويناقض', 'كونتردير', '↔️',
                  'Les chiffres contredisent son récit.', 'تناقض الأرقام روايته.'),
                v('critiquer', 'critiquer', 'ينقد', 'كريتيكيه', '🖊️',
                  'Il critique la politique sans agressivité.', 'ينقد السياسة دون عدوانية.'),
                v('approuver', 'approuver', 'يوافق ويرضى', 'أبروڤيه', '👍',
                  'Le comité approuve le projet.', 'توافق اللجنة على المشروع.'),
                v('desapprouver', 'désapprouver', 'يرفض ولا يوافق', 'ديزابروڤيه', '👎',
                  'Mes parents désapprouvent cette idée.', 'يرفض والداي هذه الفكرة.'),
                v('nuancer', 'nuancer', 'يضبط الكلام بفروق دقيقة', 'نوانسيه', '🎚️',
                  'Elle nuance ses propos avec prudence.', 'تضبط كلامها بفروق دقيقة وحذر.'),
            ],
        },
        {
            'id': 'fr_u22_l3',
            'titleAr': 'حول المشهد الإعلامي',
            'titleEn': 'Around the media scene',
            'vocab': [
                v('telespectateur', 'le téléspectateur', 'المشاهد التلفزيوني', 'لتيليزبيكتاتور', '🛋️',
                  'Le téléspectateur choisit ses chaînes.', 'يختار المشاهد قنواته.'),
                v('un_article', 'un article', 'مقال صحفي', 'أن أرتيكل', '📄',
                  'Son article a déclenché un débat.', 'أثار مقاله نقاشاً.'),
                v('desinformation', 'la désinformation', 'التضليل ونشر الأخبار الكاذبة', 'لا ديزنفورماسيون', '🎭',
                  'La désinformation se propage vite.', 'ينتشر التضليل بسرعة.'),
                v('une_chaine', 'une chaîne', 'قناة تلفزيونية', 'أن شين', '📡',
                  'Cette chaîne diffuse les matchs.', 'تبثّ هذه القناة المباريات.'),
                v('abonnement', 'un abonnement', 'اشتراك', 'أن أبونمان', '🎫',
                  'Il a résilié son abonnement.', 'ألغى اشتراكه.'),
                v('l_antenne', 'l\'antenne', 'البثّ المباشر للقناة', 'لانتان', '📶',
                  'L\'émission revient à l\'antenne à 20h.', 'يعود البرنامج للبث في الثامنة.'),
                v('kiosque', 'le kiosque', 'كشك بيع الصحف', 'لكيوسك', '🏪',
                  'Il achète son journal au kiosque.', 'يشتري جريدته من الكشك.'),
                v('slogan', 'le slogan', 'الشعار الترويجي', 'لسلوغان', '🪧',
                  'Le slogan est court et mémorable.', 'الشعار قصير وسهل التذكر.'),
                v('opinion_publique', 'l\'opinion publique', 'الرأي العام', 'لوبينيون بوبليك', '🗳️',
                  'L\'opinion publique évolue lentement.', 'يتغير الرأي العام ببطء.'),
                v('le_plateau', 'le plateau', 'استوديو التصوير', 'لبلاتو', '🎬',
                  'Le plateau est prêt pour le direct.', 'الاستوديو جاهز للبث المباشر.'),
            ],
        },
    ],
}

U23 = {
    'id': 'fr_u23',
    'color': '#FF9600',
    'titleAr': 'الأدب والفروق الدقيقة',
    'titleEn': 'Literature & Nuances',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'fr_u23_l1',
            'titleAr': 'مصطلحات الأدب',
            'titleEn': 'Literary terms',
            'vocab': [
                v('un_roman', 'un roman', 'رواية', 'أن رومان', '📕',
                  'Ce roman se passe à Alger.', 'تدور أحداث هذه الرواية في الجزائر.'),
                v('une_nouvelle', 'une nouvelle', 'قصة قصيرة', 'أن نوڤيل', '📗',
                  'Elle publie une nouvelle chaque mois.', 'تنشر قصة قصيرة كل شهر.'),
                v('la_poesie', 'la poésie', 'الشعر', 'لا بويزي', '🪶',
                  'La poésie cache des sens profonds.', 'يخفي الشعر معانٍ عميقة.'),
                v('un_vers', 'un vers', 'بيت شعري (سطر)', 'أن ڤير', '📏',
                  'Il récite un vers par cœur.', 'يتلو بيتاً من الشعر عن ظهر قلب.'),
                v('l_intrigue', 'l\'intrigue', 'حبكة القصة', 'لانتريغ', '🧩',
                  'L\'intrigue se complique au chapitre trois.', 'تتعقد الحبكة في الفصل الثالث.'),
                v('narrateur', 'le narrateur', 'الراوي', 'لناراتور', '🗣️',
                  'Le narrateur raconte son enfance.', 'يحكي الراوي طفولته.'),
                v('un_chapitre', 'un chapitre', 'فصل من كتاب', 'أن شابيتر', '📑',
                  'Je lis un chapitre chaque soir.', 'أقرأ فصلاً كل مساء.'),
                v('denouement', 'le dénouement', 'خاتمة القصة وحلّها', 'لودِنومان', '🎯',
                  'Le dénouement surprend le lecteur.', 'تُفاجئ الخاتمة القارئ.'),
                v('l_heroine', 'l\'héroïne', 'بطلة الرواية', 'ليروين', '🦸',
                  'L\'héroïne surmonte tous les obstacles.', 'تتغلب البطلة على كل العقبات.'),
                v('la_strophe', 'la strophe', 'مقطع من قصيدة', 'لا ستروف', '🎼',
                  'La dernière strophe est triste.', 'المقطع الأخير حزين.'),
            ],
        },
        {
            'id': 'fr_u23_l2',
            'titleAr': 'أفعال التلميح والتوضيح',
            'titleEn': 'Hint & clarify verbs',
            'vocab': [
                v('evoquer', 'évoquer', 'يستحضر ويشير إلى', 'يڤوكيه', '💭',
                  'Ce parfum évoque mon enfance.', 'يستحضر هذا العطر طفولتي.'),
                v('suggerer', 'suggérer', 'يلوّح ويقترح بخفة', 'سوژهيه', '💡',
                  'Il suggère une autre lecture du texte.', 'يلوّح بقراءة أخرى للنص.'),
                v('souligner', 'souligner', 'يؤكد ويبرز', 'سولينييه', '🖍️',
                  'Elle souligne l\'importance du détail.', 'تؤكد أهمية التفصيل.'),
                v('sous_entendre', 'sous-entendre', 'يعني ضمنياً دون تصريح', 'سوزاأنطاندُر', '🤫',
                  'Sa lettre sous-entend un départ.', 'تلويح رسالته ضمنياً برحيل.'),
                v('esquisser', 'esquisser', 'يرسم خطوطاً أولى ويبسط', 'أسكيسيه', '✏️',
                  'Il esquisse un sourire.', 'يرسم ابتسامة خفيفة.'),
                v('reveLER', 'révéler', 'يكشف ويجلي', 'ريڤيليه', '🔓',
                  'Le document révèle la vérité.', 'يكشف المستند الحقيقة.'),
                v('glisser', 'glisser', 'يدسّ كلمة بغير تصريح', 'غليسيه', '🍃',
                  'Elle glisse une remarque en passant.', 'تدسّ ملاحظة عابرة.'),
                v('insinuer', 'insinuer', 'يطعن بتلميح', 'انسينويه', '🐍',
                  'Il insinue que le rapport est faux.', 'يطعن بتلميح في صحة التقرير.'),
                v('elucider', 'élucider', 'يوضّح ويحلّ غموضاً', 'يلوسيديه', '🔦',
                  'La police élucide l\'affaire.', 'تحلّ الشرطة غموض القضية.'),
                v('preciser', 'préciser', 'يحدّد ويوضّح بدقة', 'بريسيزيه', '📌',
                  'Il précise sa pensée en deux mots.', 'يحدّد فكرته بكلمتين.'),
            ],
        },
        {
            'id': 'fr_u23_l3',
            'titleAr': 'مفردات شعرية',
            'titleEn': 'Poetic vocabulary',
            'vocab': [
                v('le_regard', 'le regard', 'النظرة', 'لروجار', '👁️',
                  'Son regard exprime la joie.', 'تعبر نظراته عن الفرح.'),
                v('l_ame', 'l\'âme', 'الروح والنفس', 'لام', '🕊️',
                  'La musique parle à l\'âme.', 'تخاطب الموسيقى الروح.'),
                v('le_destin', 'le destin', 'المصير والقدر', 'لودستين', '🧵',
                  'Le destin change en un instant.', 'يتغير المصير في لحظة.'),
                v('la_memoire', 'la mémoire', 'الذاكرة والذكرى', 'لاميموار', '🏛️',
                  'La mémoire garde les beaux jours.', 'تحفظ الذاكرة الأيام الجميلة.'),
                v('l_ombre', 'l\'ombre', 'الظل', 'لومبر', '🌒',
                  'Il s\'assoit à l\'ombre du vieux mur.', 'يجلس في ظل الجدار القديم.'),
                v('la_lumiere', 'la lumière', 'النور والضوء', 'لاميوزيار', '🔆',
                  'La lumière traverse les rideaux.', 'يتخلل النور الستائر.'),
                v('l_essence', 'l\'essence', 'الجوهر المكشوف', 'ليسانس', '💎',
                  'L\'essence du texte est l\'espoir.', 'جوهر النص هو الأمل.'),
                v('l_imagination', 'l\'imagination', 'الخيال', 'ليماجيناسيون', '🌈',
                  'L\'imagination crée des mondes.', 'يخلق الخيال عوالم.'),
                v('un_lecteur', 'un lecteur', 'قارئ', 'أن لوكتور', '👓',
                  'Le lecteur devine la fin.', 'يستنتج القارئ النهاية.'),
                v('traduction', 'la traduction', 'الترجمة', 'لا ترادوكسيون', '🌐',
                  'La traduction fidèle est rare.', 'الترجمة الأمينة نادرة.'),
            ],
        },
    ],
}


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    existing = {u['id'] for u in data['units']}
    for unit in (U22, U23):
        if unit['id'] not in existing:
            data['units'].append(unit)
    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('fr: appended 2 units,',
          sum(len(l['vocab']) for u in (U22, U23) for l in u['lessons']),
          'words')


if __name__ == '__main__':
    main()
