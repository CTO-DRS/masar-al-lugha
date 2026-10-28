# PHASE 1 — تقرير الاختبار والتحقق الفعلي

**الإصدار**: v5.17.0+42 | **تاريخ التنفيذ**: جلسة 2026-10-28 | **الفرع**: `phase1/foundation` → main

قاعدة التقرير: لا ادعاء نجاح إلا بنتيجة مسجلة من أمر مُنفذ. كل ما يلي من نتائج فعلية لهذه الجلسة.

---

## 1) البيئة (فُحصت دون افتراض — الحاوية أُعيد تعيينها قبل الجلسة)

| الأداة | الحالة عند البدء | الإجراء |
|---|---|---|
| Flutter 3.47.7 stable | **غير موجود** | نُزّل من flutter_infra_release (1.58GB) وتحققت سلامة الأرشيف بـ`xz -t` ثم فُك |
| OpenJDK 17.0.21 | **غير موجود** | Temurin 17 (latest GA) → `/home/z/jdk17` |
| Android SDK | **غير موجود** | cmdline-tools 11076708 + `platforms;android-36` + `build-tools;36.0.0` + platform-tools بعد قبول التراخيص |
| قرص | 8.8GB حر | كافٍ |
| شبكة | متاحة | نعم (كانت تتقطع — استؤنف التحميل بـ`curl -C -`) |

## 2) الأوامر المنفذة ونتائجها الفعلية

| # | الأمر | النتيجة الفعلية |
|---|---|---|
| 1 | `git status` + `git diff --stat` (قبل أي تعديل) | 75 ملف «معدلًا» **وضعًا فقط** (644→755، صفر محتوى) — عُولج بـ`core.fileMode false`، لا استعادة عمياء ولا فقد عمل |
| 2 | `dart format --output=none --set-exit-if-changed .` (الأساس) | نظيف — 0 تغيير |
| 3 | `flutter analyze --fatal-infos` (الأساس) | `No issues found!` |
| 4 | `flutter test --concurrency=1` (الأساس) | **470/470 PASS** |
| 5 | `python3 scripts/validate_content.py` (الأساس) | **PASS** (FATAL 0، إشعارات معلومات فقط) |
| 6 | `flutter analyze` بعد كل دفعة | نهائيًا: `No issues found!` |
| 7 | `flutter test test/phase1_fixes_test.dart` (تكراري أثناء التطوير) | مرّ بمسارات فاشلة موثقة أدناه حتى **11/11** |
| 8 | `flutter test --concurrency=1` (النهائي) | **482/482 PASS** (470 أساس + 11 جديد + 1 انقسام عدّاد محدث) |
| 9 | فحص الأسرار النمطي (grep على lib/android/.github/pubspec) | نظيف — إيجابية كاذبة وحيدة (كلمة مفردات) |
| 10 | حسابات WCAG (سكربت صيغة التباين على 31 زوجًا) | **ALL OK** قبل هبوط اللوحة |

## 3) الاختبارات الجديدة (11) — كل إصلاح باختبار يثبته

`test/phase1_fixes_test.dart`:
1. `resetAll wipes the F2.x engine fields` (H-2)
2. `switchProfile does not bleed engine state into the new slot` (H-2)
3. `load() REPLACES engine containers instead of merging` (H-2)
4. `load() with an old payload lacking engine keys resets them` (H-2)
5. `a mid-parse failure restores the persisted snapshot` (M-1)
6. `double-tap on Check scores the round once` (H-3)
7. `a double-tapped final Continue awards the lesson XP once` (H-3) — يقود درسًا كاملًا بكل أنواع التمارين
8. `rating one card twice counts one review` (M-4)
9. `opens without LateInitializationError` (H-1)
10. `memoized search still returns correct results` (P-1)
11. `switching tabs keeps the dictionary search query` (D-1)

كما أُعيدت كتابة `test/contrast_test.dart` لتثبيت أزواج الهوية الجديدة (نفس العتبات ونفس التأكيدات السالبة).

## 4) إخفاقات حدثت أثناء التطوير — وكيف حُلّت (للشفافية)

| الفشل | السبب الجذري | الحل |
|---|---|---|
| `A Timer is still pending` (×2) | مؤقت الحفظ المؤجل 2s وشارة النتيجة 700ms حية عند نهاية الاختبار | `st.flush()` قبل النهاية + ضخ 800ms |
| `Expected <1> Actual <2>` في تقييم البطاقات | القفل try/finally يُحل تزامنيًا فلا يمنع النقرة الثانية؛ والنقرة الثانية كانت تقيّم البطاقة **التالية** فعلاً | قفل يُحل بعد الإطار (`addPostFrameCallback`) — والاختبار كشف سلوك الطابور الحقيقي |
| تحليل: `must_be_immutable`/`const_constructor` | حقل قفل نسخي على StatelessWidget | مرشّح تنقل ساكن مشترك |
| `Bad state: No element` في enterText | التبويب غير المزار غير مبني (كسول) — الاختبار زار القاموس أولًا | تصحيح تسلسل الاختبار |
| **انحدار حقيقي اكتشفه الاختبار D-1** | نقرة بلاطة التنقل كانت تتجاوز `switchTab` → **شاشة فارغة** عند أول زيارة للتبويب | `onTap: switchTab(index)` — وهذا برهان قيمة اختبار الانحدار |
| فائضات تخطيط متكررة أثناء الاختبارات | 5 عيوب **مسبقة** ظهرت فقط على سطح 360dp | أُصلحت كلها (M-6) والسطح الهاتفي صار شبكة أمان |

## 5) ما تعذّر تشغيله وسببه

- **بناء APK محليًا**: لم يُبنَ محليًا في هذه الجلسة — البناء الإصداري مرتبط ببوابة CI (نفس ممارسة الإصدارات السابقة)؛ الحالة أدناه §6.
- **قياس P95 حقيقي على جهاز**: لا جهاز مادي في هذه البيئة — بنود P-3 (إعادة البناء الجذرية) بقيت «موثقة بالدليل النصي دون قياس» عمدًا بدل إعادة هيكلة بالتخمين.
- **اختبار M-5 (مرشح التنقل) بويدجت**: القفل متزامن بسيط والمسار مغطى باختبارات a11y/سلوك قائمة — مُسند بصدق: إصلاح مُراجع بالكود غير مُثبت باختبار مخصص.

## 6) حالة بناء APK

- البناء يُنفذ في CI على دفع main بعد: التحقق من المحتوى + التنسيق + التحليل + كل الاختبارات.
- **خطوة جديدة في CI**: «Sign-check» تكتب في ملخص التشغيل تحذيرًا صريحًا بأن APK بدون `key.properties` موقّع بشهادة **debug** — لا توقيع صامت بعد الآن.
- بعد الدفع: يُتحقق من تشغيل CI الأخضر، ويُنزّل الأثر ويُوثّق تحققُه المستقل (aapt2/apksigner/محتوى مدمج) في سجل العمل — انظر القسم النهائي لهذه الوثيقة بعد إغلاق الالتزام.

## 7) التحقق المستقل النهائي (يُحدّث بعد إغلاق CI)

- المخرج: `masar-al-lugha-v5.17.0.apk` في مجلد التسليم، مقارنة SHA-256 مع أثر CI، وتدقيق `aapt2 dump badging` (com.masar.allugha / 5.17.0 / 42)، و`apksigner verify` (debug متوقع ومعلن)، وفحص مستقبِلي التذكير في manifest المدمج (بقاء إصلاح v5.14.1)، وإحصاء المحتوى المدمج (6346 كلمة — لم يمسّ).
