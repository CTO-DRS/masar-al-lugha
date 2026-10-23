// Placement quiz UI (v4.0): quick multiple-choice across course depth,
// then pre-unlocks the recommended level. Reached from the learn path
// header when a course has no completed lessons yet.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../placement.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  List<PlacementCheckpoint> checkpoints = [];
  Map<String, String> key = {}; // wordId -> correct translation
  final Map<String, String> wordOf = {}; // wordId -> target text
  final Map<String, bool> results = {};

  int cpIndex = 0;
  bool finished = false;
  int? selected;
  bool answered = false;

  String? currentId;
  List<String> currentOptions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = AppScope.of(context);
      final course = st.course;
      checkpoints = Placement.sample(course);
      key = Placement.answerKey(course, checkpoints.expand((c) => c.wordIds));
      for (final v in course.allVocab) {
        wordOf[v.id] = v.target;
      }
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    while (cpIndex < checkpoints.length) {
      final cp = checkpoints[cpIndex];
      final remaining =
          cp.wordIds.where((id) => !results.containsKey(id)).toList();
      if (remaining.isEmpty) {
        // Checkpoint complete — advance only if fully correct.
        final allCorrect = cp.wordIds.every((id) => results[id] == true);
        if (!allCorrect) break;
        cpIndex++;
        continue;
      }
      final id = remaining.first;
      final wrongs = key.values.where((t) => t != key[id]).toSet().toList()
        ..shuffle();
      setState(() {
        currentId = id;
        currentOptions = [key[id]!, ...wrongs.take(3)]..shuffle();
        selected = null;
        answered = false;
      });
      return;
    }
    setState(() => finished = true);
  }

  int get recommended => Placement.recommendedFlatIndex(
      AppScope.of(context).course, checkpoints, results);

  void _answer(String opt) {
    if (answered || currentId == null) return;
    final st = AppScope.of(context);
    setState(() {
      selected = currentOptions.indexOf(opt);
      answered = true;
      results[currentId!] = opt == key[currentId!];
      st.recordAnswer(results[currentId!]!);
    });
  }

  void _continue() => _nextQuestion();

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    final st = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('placementTitle'))),
      body: finished
          ? _result(tr, st)
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('placementIntro'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedText, fontSize: 14)),
                  const SizedBox(height: 18),
                  Text(tr('placementMeaningOf'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 16),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.line, width: 2),
                      ),
                      child: Text(
                        currentId == null ? '' : (wordOf[currentId!] ?? ''),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: ListView(
                      children: [
                        for (var i = 0; i < currentOptions.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: OptionCard(
                              text: currentOptions[i],
                              selected: selected == i,
                              correct: answered &&
                                  currentOptions[i] == key[currentId!],
                              wrong: answered &&
                                  selected == i &&
                                  currentOptions[i] != key[currentId!],
                              onTap: () => _answer(currentOptions[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ChunkyButton(
                    label: tr('continue'),
                    disabled: !answered,
                    onPressed: answered ? _continue : null,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _result(String Function(String) tr, AppState st) {
    final course = st.course;
    final flat = recommended;
    String title;
    if (flat <= 0) {
      title = tr('placementFromStart');
    } else {
      var acc = 0;
      String unitTitle = '';
      var unitNo = 0;
      for (var u = 0; u < course.units.length; u++) {
        final len = course.units[u].lessons.length;
        if (flat < acc + len) {
          unitNo = u + 1;
          unitTitle = st.uiLocale == 'ar'
              ? course.units[u].titleAr
              : course.units[u].titleEn;
          break;
        }
        acc += len;
      }
      title = '${tr('placementResult')}: ${tr('unit')} $unitNo — $unitTitle';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Mascot(size: 120, mood: MascotMood.celebrate),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
          ),
          const SizedBox(height: 30),
          ChunkyButton(
            label: tr('placementConfirm'),
            onPressed: () {
              st.setPlacementSkip(st.courseId, flat);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            label: tr('placementSkip'),
            color: AppColors.inkLight,
            colorDark: AppColors.inkLight,
            onPressed: () {
              st.setPlacementSkip(st.courseId, 0);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
