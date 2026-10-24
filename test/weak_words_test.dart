// v4.1 tests: tough-words practice lane foundations.
// - weakestVocab: course filtering + most-missed-first ordering
// - practice ratings flow through the same SRS/stats path as the Cards tab
// - foreign word ids (other courses / removed content) never leak through
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/srs.dart';

Course _course(String id, Map<String, List<String>> unitsWords) {
  var wi = 0;
  return Course(
    id: id,
    nameAr: 'دورة $id',
    nameEn: 'Course $id',
    flag: '🌍',
    ttsLang: 'en-US',
    units: unitsWords.entries.map((e) {
      return Unit(
        id: '${id}_u_${e.key}',
        titleAr: 'وحدة ${e.key}',
        titleEn: 'Unit ${e.key}',
        colorHex: '#58CC02',
        lessons: [
          Lesson(
            id: '${id}_l_${e.key}',
            titleAr: 'درس ${e.key}',
            titleEn: 'Lesson ${e.key}',
            vocab: e.value
                .map((w) => Vocab(
                      id: w,
                      target: w,
                      translationAr: 'معنى $wi',
                    ))
                .toList(),
          ),
        ],
      );
    }).toList(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('weakestVocab sorts most-missed first within the current course',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    final en = _course('en', {
      '1': ['apple', 'banana', 'cherry', 'dates'],
    });
    final ur = _course('ur', {
      '1': ['paani'],
    });
    st.courses['en'] = en;
    st.courses['ur'] = ur;

    st.wordMistakes['apple'] = 2;
    st.wordMistakes['cherry'] = 5;
    st.wordMistakes['dates'] = 1;
    st.wordMistakes['banana'] = 3;
    st.wordMistakes['paani'] = 9; // other course — must be filtered out
    st.wordMistakes['ghost_id'] = 99; // removed/foreign id — filtered out

    final weak = st.weakestVocab(en);
    expect(
        weak.map((v) => v.id).toList(), ['cherry', 'banana', 'apple', 'dates']);

    // Urdu course sees only its own weak word.
    expect(st.weakestVocab(ur).map((v) => v.id).toList(), ['paani']);
  });

  test('practice ratings update SRS, answers, XP — and never wordMistakes',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    final en = _course('en', {
      '1': ['apple', 'banana'],
    });
    st.courses['en'] = en;

    // Simulate a 3-card practice session: again, good, good.
    final session = ['apple', 'banana', 'apple'];
    for (final id in session) {
      final q = id == 'apple' ? Srs.again : Srs.good;
      st.rateCard(id, q);
      st.addXp(1);
      st.recordAnswer(q != Srs.again);
    }
    await st.flush();

    expect(st.cardsReviewed, 3);
    expect(st.totalAnswers, 3);
    expect(st.correctAnswers, 2);
    expect(st.xp, 3);

    // Design decision (documented in ARCHITECTURE.md §3): practice-mode
    // self-ratings do NOT inflate lifetime lesson-mistake counts, so the
    // weak list stays driven by real lesson errors only.
    expect(st.wordMistakes, isEmpty);

    // "Again" keeps the card in learning state; "good" advances a new card.
    expect(st.cards['apple']!.state, 'learning');
    expect(st.cards['banana']!.reps, 1);
  });

  test('empty mistake map yields an empty practice queue', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    st.courses['en'] = _course('en', {
      '1': ['apple'],
    });
    expect(st.weakestVocab(st.courses['en']!), isEmpty);
  });
}
