#!/usr/bin/env python3
"""v4.5 content expansion — ENGLISH: units 53-54 (C1).

u53 Idioms & Expressions (3 lessons x 10 words)
u54 Nuance & Register  (3 lessons x 10 words)
Every vocab item: id, target, translationAr, phonetic (Arabic
transliteration), emoji (unique within its lesson), exampleTarget,
exampleAr. Appends to course_en.json (append-only rule: existing ids
untouched). Run: python3 scripts/content_v45_en.py
"""
import json
import os

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


U53 = {
    'id': 'en_u53',
    'color': '#1CB0F6',
    'titleAr': 'التعبيرات الاصطلاحية',
    'titleEn': 'Idioms & Expressions',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'en_u53_l1',
            'titleAr': 'تعبيرات الحياة اليومية',
            'titleEn': 'Everyday idioms',
            'vocab': [
                v('blessing_disguise', 'A blessing in disguise', 'نعمة مقنّعة في صورة سيئة', 'أ بليسِنغ إن دِسغايز', '🍀',
                  'Losing that job was a blessing in disguise.', 'كانت خسارة تلك الوظيفة نعمة مقنّعة.'),
                v('burn_midnight_oil', 'Burn the midnight oil', 'يسهر متأثراً يعمل أو يدرس', 'برن ذ ميدنايت أويل', '🕯️',
                  'She burned the midnight oil before finals.', 'سهرة متأثرة قبل الامتحانات النهائية.'),
                v('on_the_mend', 'On the mend', 'في طريقه للتحسّن والشفاء', 'أون ذ مِند', '🩹',
                  'After rest, he is on the mend.', 'بعد الراحة صار في طريقه للتحسن.'),
                v('blue_moon', 'Once in a blue moon', 'نادراً جداً', 'وانس إن أ بلو مون', '🌙',
                  'We meet once in a blue moon.', 'نتقابل نادراً جداً.'),
                v('cat_out_of_bag', 'Let the cat out of the bag', 'يفشي السر دون قصد', 'ليت ذ كات أوت أوف ذ باغ', '🐱',
                  'He let the cat out of the bag early.', 'فشى السر مبكراً دون قصد.'),
                v('arm_and_leg', 'Cost an arm and a leg', 'غالٍ جداً', 'كوست أن آرم اند أ ليغ', '💰',
                  'That car cost an arm and a leg.', 'تلك السيارة كلّفت ثروة.'),
                v('walk_in_park', 'A walk in the park', 'مهمة في غاية السهولة', 'أ ووك إن ذ بارك', '🌳',
                  'The test was a walk in the park.', 'كان الاختبار في غاية السهولة.'),
                v('cloud_nine', 'On cloud nine', 'في قمة السعادة', 'أون كلاود ناين', '☁️',
                  'She was on cloud nine after the win.', 'كانت في قمة السعادة بعد الفوز.'),
                v('face_the_music', 'Face the music', 'يواجه عواقب أفعاله بشجاعة', 'فيس ذ ميوزيك', '🎺',
                  'He had to face the music at home.', 'كان عليه مواجهة العواقب في البيت.'),
                v('cold_feet', 'Get cold feet', 'يفقد جرأته في اللحظة الأخيرة', 'غِت كولد فيت', '🥶',
                  'She got cold feet before the speech.', 'فقدت جرأتها قبل الخطاب مباشرة.'),
            ],
        },
        {
            'id': 'en_u53_l2',
            'titleAr': 'تعبيرات العمل والنجاح',
            'titleEn': 'Work & success idioms',
            'vocab': [
                v('climb_ladder', 'Climb the ladder', 'يصعد السلطة الوظيفية', 'كلايم ذ لادِر', '🪜',
                  'She is climbing the ladder quickly.', 'هي تصعد السلطة الوظيفية بسرعة.'),
                v('outside_box', 'Think outside the box', 'يفكر خارج الصندوق', 'ثينك أوتسايد ذ بوكس', '📦',
                  'Good designers think outside the box.', 'المصممون الجيدون يفكرون خارج الصندوق.'),
                v('ball_rolling', 'Get the ball rolling', 'يبدأ العمل ويحرّك الأمور', 'غِت ذ بول رولينغ', '⚽',
                  'Let us get the ball rolling.', 'لنبدأ العمل ونحرّك الأمور.'),
                v('square_one', 'Back to square one', 'يعود لنقطة الصفر', 'باك تو سكوير وان', '↩️',
                  'The plan failed; we are back to square one.', 'فشلت الخطة؛ عدنا لنقطة الصفر.'),
                v('cut_corners', 'Cut corners', 'يختصر الجودة ليوفّر', 'كات كورنِرز', '✂️',
                  'Never cut corners on safety.', 'لا تختصر أبداً في السلامة.'),
                v('extra_mile', 'Go the extra mile', 'يبذل جهدًا إضافيًا', 'غو ذ إكسترا مايل', '🏃',
                  'Our team goes the extra mile.', 'فريقنا يبذل جهداً إضافياً.'),
                v('raise_bar', 'Raise the bar', 'يرفع سقف التوقعات', 'ريز ذ بار', '📈',
                  'Her last book raised the bar.', 'رفع كتابها الأخير سقف التوقعات.'),
                v('touch_base', 'Touch base', 'يتواصل سريعاً للمتابعة', 'تش بايس', '🤝',
                  'Let us touch base on Monday.', 'لنتواصل للمتابعة يوم الاثنين.'),
                v('in_pipeline', 'In the pipeline', 'قيد الإعداد', 'إن ذ بايبلاين', '🚧',
                  'Two new courses are in the pipeline.', 'دورتان جديدتان قيد الإعداد.'),
                v('strike_balance', 'Strike a balance', 'يحقق التوازن', 'ستريك أ بالانس', '⚖️',
                  'Try to strike a balance between work and rest.', 'حاول أن تحقق التوازن بين العمل والراحة.'),
            ],
        },
        {
            'id': 'en_u53_l3',
            'titleAr': 'تعبيرات المشاعر والمواقف',
            'titleEn': 'Feelings & situations',
            'vocab': [
                v('head_over_heels', 'Head over heels', 'غارق في الحب تماماً', 'هيد أوفر هيلز', '💘',
                  'They are head over heels in love.', 'هما غارقان في الحب تماماً.'),
                v('feeling_blue', 'Feeling blue', 'حزين الكبد', 'فيلينغ بلو', '💧',
                  'Rainy days make me feel blue.', 'أيام المطر تجعلني حزيناً.'),
                v('pull_together', 'Pull yourself together', 'يستعيد أعصابه وينضبط', 'بول يورسِلف توغِذَر', '🧘',
                  'Pull yourself together; it is almost done.', 'استعد أعصابك؛ لقد أوشكت على الانتهاء.'),
                v('on_edge', 'On edge', 'متوتر ومقلق', 'أون إدج', '😰',
                  'The exam results put me on edge.', 'نتائج الامتحان جعلتني متوتراً.'),
                v('give_hand', 'Give someone a hand', 'يساعد شخصاً', 'غِف سَموان أ هاند', '🖐️',
                  'Can you give me a hand with these boxes?', 'أيمكنك مساعدتي مع هذه الصناديق؟'),
                v('blink_of_eye', 'In the blink of an eye', 'في لمح البصر', 'إن ذ بلينك أوف أن آي', '⚡',
                  'The summer passed in the blink of an eye.', 'مرّ الصيف في لمح البصر.'),
                v('eye_to_eye', 'See eye to eye', 'يتفقان في الرأي', 'سي آي تو آي', '👀',
                  'We finally see eye to eye.', 'أخيراً اتفقنا في الرأي.'),
                v('twist_arm', 'Twist someone\'s arm', 'يضغط على شخص لإقناعه', 'توِست سَموانز آرم', '💪',
                  'I did not need to twist his arm.', 'لم أحتج أن أضغط عليه ليقتنع.'),
                v('break_a_leg', 'Break a leg', 'بالتوفيق (تشجيع قبل الأداء)', 'بريك أ ليغ', '🎭',
                  'Break a leg in your presentation today!', 'بالتوفيق في عرضك اليوم!'),
                v('change_mind', 'Change your mind', 'يغيّر رأيه', 'تشينج يور مايند', '🔄',
                  'She changed her mind about the trip.', 'غيّرت رأيها بشأن الرحلة.'),
            ],
        },
    ],
}

U54 = {
    'id': 'en_u54',
    'color': '#CE82FF',
    'titleAr': 'الفروق الدقيقة والسجلات',
    'titleEn': 'Nuance & Register',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'en_u54_l1',
            'titleAr': 'أفعال رسمية',
            'titleEn': 'Formal verbs',
            'vocab': [
                v('obtain', 'Obtain', 'يحصل على (رسمي)', 'أوبتين', '📥',
                  'You must obtain a permit first.', 'عليك الحصول على تصريح أولاً.'),
                v('purchase', 'Purchase', 'يشتري (رسمي)', 'بورتشِس', '🛒',
                  'Customers can purchase tickets online.', 'يمكن للزبائن شراء التذاكر عبر الإنترنت.'),
                v('assist', 'Assist', 'يعين ويساعد (رسمي)', 'أسِست', '🤲',
                  'Staff will assist you promptly.', 'سيوظف الموظفون مساعدتك فوراً.'),
                v('inquire', 'Inquire', 'يستفسر (رسمي)', 'إنكواير', '❓',
                  'She inquired about the schedule.', 'استفسرت عن الجدول.'),
                v('commence', 'Commence', 'يبدأ (رسمي)', 'كومِنس', '🎬',
                  'The ceremony will commence at nine.', 'سيبدأ الحفل في التاسعة.'),
                v('require', 'Require', 'يستلزم ويقتضي', 'ريكواير', '📋',
                  'The job requires patience.', 'تستلزم الوظيفة صبراً.'),
                v('provide', 'Provide', 'يوفّر ويقدّم', 'بروفايد', '🎁',
                  'The hotel provides free breakfast.', 'يوفّر الفندق فطوراً مجانياً.'),
                v('attempt', 'Attempt', 'يحاول (محاولة جادة)', 'أتَمبت', '🎯',
                  'They attempted the summit twice.', 'حاولوا الوصول للقمة مرتين.'),
                v('inform', 'Inform', 'يُعلم ويبلّغ', 'إنفورم', '📢',
                  'Please inform us of any delays.', 'أعلمنا من فضلك عن أي تأخير.'),
                v('acknowledge', 'Acknowledge', 'يعترف ويقرّ بـ', 'أكنولِدج', '🙋',
                  'He acknowledged his mistake openly.', 'اعترف بخطئه علناً.'),
            ],
        },
        {
            'id': 'en_u54_l2',
            'titleAr': 'صفات دقيقة',
            'titleEn': 'Precise adjectives',
            'vocab': [
                v('meticulous', 'Meticulous', 'دقيق الحرفية شديد الانتباه', 'مِتيكيولِس', '🔍',
                  'She keeps meticulous notes.', 'تحتفظ بملاحظات دقيقة جداً.'),
                v('reluctant', 'Reluctant', 'متردّد غير راغب', 'رِلاكتِنت', '🙅',
                  'He was reluctant to leave.', 'كان متردداً في المغادرة.'),
                v('intrigued', 'Intrigued', 'منجذب بحيرة وتشويق', 'إنتريغد', '🤩',
                  'I am intrigued by the idea.', 'الفكرة تشوّقني فعلاً.'),
                v('overwhelmed', 'Overwhelmed', 'مرهق بسبب الإغراق', 'أوفَرويلمد', '🌊',
                  'She felt overwhelmed by emails.', 'شعرت بالإغراق بسبب رسائل البريد.'),
                v('skeptical', 'Skeptical', 'شكّاك متحفّظ', 'سكِبتِكال', '🧐',
                  'I am skeptical of quick fixes.', 'أشكّك في الحلول السريعة.'),
                v('relieved', 'Relieved', 'مرتاح بعد قلق', 'رِليفد', '😮‍💨',
                  'We were relieved to hear the news.', 'ارتاحنا عندما سمعنا الخبر.'),
                v('frustrated', 'Frustrated', 'محبَط متعِب', 'فرَستريتد', '😫',
                  'He got frustrated with the delay.', 'أصيب بالإحباط بسبب التأخير.'),
                v('ambitious', 'Ambitious', 'طموح', 'آمبِشِس', '🏔️',
                  'She is an ambitious engineer.', 'هي مهندسة طموحة.'),
                v('diligent', 'Diligent', 'مجتهد مثابر في عمله', 'دِلجِنت', '🐜',
                  'Diligent students review daily.', 'الطلاب المجتهدون يراجعون يومياً.'),
                v('assertive', 'Assertive', 'حازم واثق بثقة هادئة', 'أسيرتِف', '🗣️',
                  'Be assertive, not aggressive.', 'كن حازماً لا عدوانياً.'),
            ],
        },
        {
            'id': 'en_u54_l3',
            'titleAr': 'أدوات الربط الأكاديمية',
            'titleEn': 'Academic connectors',
            'vocab': [
                v('nevertheless', 'Nevertheless', 'مع ذلك', 'نِفَرذِلِس', '🔁',
                  'It was risky; nevertheless, we tried.', 'كان الأمر مجازفة؛ ومع ذلك حاولنا.'),
                v('consequently', 'Consequently', 'بالنتيجة لذلك', 'كونسِكونتلي', '➡️',
                  'Prices rose; consequently, sales fell.', 'ارتفعت الأسعار؛ وبذلك انخفضت المبيعات.'),
                v('furthermore', 'Furthermore', 'علاوة على ذلك', 'فَرذَرمور', '➕',
                  'Furthermore, the data is verified.', 'علاوة على ذلك، البيانات موثّقة.'),
                v('in_contrast', 'In contrast', 'في المقابل', 'إن كونتراست', '🔀',
                  'In contrast, rural areas stayed quiet.', 'في المقابل، بقت المناطق الريفية هادئة.'),
                v('accordingly', 'Accordingly', 'وبناءً عليه', 'أكوردينغلي', '📌',
                  'The plan was adjusted accordingly.', 'عُدّلت الخطة بناءً على ذلك.'),
                v('whereas', 'Whereas', 'بينما في حين أن', 'وِيرآز', '⚖️',
                  'He walks, whereas she cycles.', 'هو يمشي، بينما هي تركب الدراجة.'),
                v('albeit', 'Albeit', 'وإن كان', 'أولبيِت', '🎭',
                  'A quiet, albeit tense, meeting.', 'اجتماع هادئ، وإن كان متوتراً.'),
                v('hence', 'Hence', 'ومن ثم', 'هِنس', '🧭',
                  'The road was flooded; hence the delay.', 'كان الطريق مغموراً؛ ومن ثم التأخير.'),
                v('moreover', 'Moreover', 'فضلاً عن ذلك', 'موروفر', '🏗️',
                  'Moreover, the cost is lower.', 'فضلاً عن ذلك، التكلفة أقل.'),
                v('thus', 'Thus', 'وهكذا', 'ذَس', '✅',
                  'Thus the problem was solved.', 'وهكذا حُلّت المشكلة.'),
            ],
        },
    ],
}


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    existing = {u['id'] for u in data['units']}
    for unit in (U53, U54):
        if unit['id'] not in existing:
            data['units'].append(unit)
    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    n = sum(len(u['lessons']) for u in (U53, U54) for l in u['lessons'])
    print(f'en: appended {sum(1 for u in (U53, U54))} units, '
          f'{sum(len(l["vocab"]) for u in (U53, U54) for l in u["lessons"])} words')


if __name__ == '__main__':
    main()
