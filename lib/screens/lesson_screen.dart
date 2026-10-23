// Lesson runner: MCQ / reverse / listen / build / match + v2.0 picture,
// fill-blank and true-false exercises.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../exercise_gen.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/mascot.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final List<Exercise> exercises;
  int index = 0;
  int hearts = 5;
  int mistakes = 0;
  int correctCount = 0;

  // per-exercise interaction state
  int? selected;
  bool answered = false;
  bool wasCorrect = false;
  List<int> placed = []; // indices into tiles
  final Set<String> matchedPairs = {};
  String? matchSelLeft;
  String? matchSelRight;
  bool matchError = false;

  bool get isLast => index >= exercises.length - 1;
  Exercise get ex => exercises[index];

  @override
  void initState() {
    super.initState();
    exercises = ExerciseGen.forLesson(widget.lesson);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakIfNeeded();
      setState(() {});
    });
  }

  void _speakIfNeeded() {
    switch (ex.type) {
      case ExerciseType.listen:
      case ExerciseType.mcq:
      case ExerciseType.wordToPic:
      case ExerciseType.picToWord:
      case ExerciseType.truefalse:
        AppScope.ttsOf(context)
            .setLanguage(AppScope.of(context).course.ttsLang)
            .then((_) => AppScope.ttsOf(context).speak(ex.audioText));
        break;
      case ExerciseType.fillblank:
        AppScope.ttsOf(context)
            .setLanguage(AppScope.of(context).course.ttsLang)
            .then((_) => AppScope.ttsOf(context).speak(ex.audioText));
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = (String k) => context.tr(k);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(tr),
              Expanded(child: _body(tr)),
              _bottomAction(tr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(String Function(String) tr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _confirmQuit(tr),
            child: const Icon(Icons.close,
                color: AppColors.lockedDark, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (index + (answered ? 1 : 0)) / exercises.length,
                minHeight: 14,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.green),
              ),
            ),
          ),
          const SizedBox(width: 12),
          HeartsRow(hearts: hearts),
        ],
      ),
    );
  }

  Widget _body(String Function(String) tr) {
    switch (ex.type) {
      case ExerciseType.mcq:
      case ExerciseType.reverse:
        return _mcqBody(tr, isListen: false);
      case ExerciseType.listen:
        return _mcqBody(tr, isListen: true);
      case ExerciseType.build:
        return _buildBody(tr);
      case ExerciseType.match:
        return _matchBody(tr);
      case ExerciseType.wordToPic:
        return _picBody(tr, pickPicture: true);
      case ExerciseType.picToWord:
        return _picBody(tr, pickPicture: false);
      case ExerciseType.fillblank:
        return _fillBody(tr);
      case ExerciseType.truefalse:
        return _tfBody(tr);
    }
  }

  Widget _promptCard(String Function(String) tr,
      {required bool isListen}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Mascot(size: 56, mood: MascotMood.happy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isListen
                      ? tr('listenAndChoose')
                      : ex.type == ExerciseType.reverse
                          ? tr('chooseWord')
                          : tr('chooseTranslation'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isListen)
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => AppScope.ttsOf(context)
                        .speak(ex.audioText)
                        .then((_) => AppScope.ttsOf(context)
                            .speak(ex.audioText)),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                              color: AppColors.blueDark,
                              offset: Offset(0, 5),
                              blurRadius: 0),
                        ],
                      ),
                      child: const Icon(Icons.volume_up,
                          color: Colors.white, size: 52),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ex.vocab.phonetic ?? '',
                    style: const TextStyle(
                        color: AppColors.inkLight, fontSize: 15),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Text(
                  ex.prompt,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          if (!isListen &&
              ex.type == ExerciseType.mcq &&
              ex.vocab.phonetic != null)
            Text(ex.vocab.phonetic!,
                style: const TextStyle(
                    color: AppColors.inkLight, fontSize: 14)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _mcqBody(String Function(String) tr, {required bool isListen}) {
    final badgeLetters =
        AppScope.of(context).uiLocale == 'ar' ? ['أ', 'ب', 'ج', 'د'] : ['A', 'B', 'C', 'D'];
    return Column(
      children: [
        _promptCard(tr, isListen: isListen),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: ex.options.length,
            itemBuilder: (context, i) {
              return OptionCard(
                text: ex.options[i],
                badge: i < badgeLetters.length ? badgeLetters[i] : null,
                selected: selected == i,
                correct: answered && ex.options[i] == ex.answer,
                wrong: answered && selected == i && !wasCorrect,
                onTap: answered
                    ? null
                    : () {
                        AppScope.ttsOf(context).stop();
                        setState(() => selected = i);
                      },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(String Function(String) tr) {
    final prompt = ex.tiles.join(' ').contains(' ')
        ? tr('buildThePhrase')
        : tr('buildTheWord');
    final remaining = List<int>.generate(ex.tiles.length, (i) => i)
        .where((i) => !placed.contains(i))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Mascot(size: 56, mood: MascotMood.happy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(prompt,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Column(
              children: [
                // target meaning
                Text(ex.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                // answer line
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final i in placed)
                      WordTile(
                        text: ex.tiles[i],
                        onTap: answered
                            ? null
                            : () => setState(() => placed.remove(i)),
                      ),
                  ],
                ),
                const Divider(color: AppColors.border, height: 24),
                // source tiles
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final i in remaining)
                      WordTile(
                        text: ex.tiles[i],
                        onTap: answered
                            ? null
                            : () => setState(() => placed.add(i)),
                      ),
                    if (remaining.isEmpty && placed.isEmpty)
                      const Text('',
                          style: TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- v2.0 interactive picture exercises ----
  Widget _picBody(String Function(String) tr, {required bool pickPicture}) {
    final badgeLetters =
        AppScope.of(context).uiLocale == 'ar' ? ['أ', 'ب', 'ج', 'د'] : ['A', 'B', 'C', 'D'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Mascot(size: 56, mood: MascotMood.happy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pickPicture
                          ? tr('whichPicture')
                          : tr('whichWordForPic'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pickPicture) ...[
                // word prompt -> pick emoji picture
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: AppColors.border, width: 2),
                    ),
                    child: Text(
                      ex.prompt,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                if (ex.vocab.phonetic != null) ...[
                  const SizedBox(height: 6),
                  Text(ex.vocab.phonetic!,
                      style: const TextStyle(
                          color: AppColors.inkLight, fontSize: 14)),
                ],
              ] else ...[
                // emoji prompt -> pick word
                GestureDetector(
                  onTap: () => AppScope.ttsOf(context).speak(ex.audioText),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.yellow, width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: AppColors.yellowDark,
                            offset: Offset(0, 5),
                            blurRadius: 0),
                      ],
                    ),
                    child: Center(
                      child: Text(ex.prompt,
                          style:
                              const TextStyle(fontSize: 64, height: 1.1)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tr('correctAnswerIs')} ${ex.hint ?? ''}',
                  style: const TextStyle(
                      color: AppColors.inkLight, fontSize: 14),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: ex.options.length,
            itemBuilder: (context, i) {
              if (pickPicture) {
                return PictureCard(
                  emoji: ex.options[i],
                  selected: selected == i,
                  correct: answered && ex.options[i] == ex.answer,
                  wrong: answered && selected == i && !wasCorrect,
                  onTap: answered
                      ? null
                      : () => setState(() => selected = i),
                );
              }
              return OptionCard(
                text: ex.options[i],
                badge: i < badgeLetters.length ? badgeLetters[i] : null,
                selected: selected == i,
                correct: answered && ex.options[i] == ex.answer,
                wrong: answered && selected == i && !wasCorrect,
                onTap: answered
                    ? null
                    : () => setState(() => selected = i),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- v2.0 fill-in-the-blank ----
  Widget _fillBody(String Function(String) tr) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Mascot(size: 56, mood: MascotMood.happy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('fillBlank'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Text(
                  ex.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              if (ex.hint != null) ...[
                const SizedBox(height: 8),
                Text(ex.hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.inkLight, fontSize: 14)),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: ex.options.length,
            itemBuilder: (context, i) {
              return OptionCard(
                text: ex.options[i],
                selected: selected == i,
                correct: answered && ex.options[i] == ex.answer,
                wrong: answered && selected == i && !wasCorrect,
                onTap: answered
                    ? null
                    : () => setState(() => selected = i),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- v2.0 true / false ----
  Widget _tfBody(String Function(String) tr) {
    final shownMeaning = ex.hint ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Mascot(size: 56, mood: MascotMood.happy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('trueOrFalse'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 4),
                    blurRadius: 0),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () =>
                      AppScope.ttsOf(context).speak(ex.audioText),
                  child: Text(
                    ex.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                ),
                if (ex.vocab.phonetic != null) ...[
                  const SizedBox(height: 4),
                  Text(ex.vocab.phonetic!,
                      style: const TextStyle(
                          color: AppColors.inkLight, fontSize: 14)),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shownMeaning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OptionCard(
                  text: '✅ ${tr('trueWord')}',
                  selected: selected == 0,
                  correct: answered && ex.answer == 'true',
                  wrong: answered && selected == 0 && !wasCorrect,
                  onTap: answered
                      ? null
                      : () => setState(() => selected = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OptionCard(
                  text: '❌ ${tr('falseWord')}',
                  selected: selected == 1,
                  correct: answered && ex.answer == 'false',
                  wrong: answered && selected == 1 && !wasCorrect,
                  onTap: answered
                      ? null
                      : () => setState(() => selected = 1),
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _matchBody(String Function(String) tr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Mascot(size: 56, mood: MascotMood.happy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('matchPairs'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final w in ex.matchLeft)
                        _matchChip(w, AppScope.of(context).course.ttsLang == 'ur' || true, tr),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final m in ex.matchRight)
                        _matchChip(m, false, tr),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchChip(String text, bool speakable, String Function(String) tr) {
    final isLeft = ex.matchLeft.contains(text);
    final matched = matchedPairs.contains('L:$text') ||
        matchedPairs.contains('R:$text');
    final selectedNow =
        (isLeft && matchSelLeft == text) || (!isLeft && matchSelRight == text);
    final flashRed = matchError && selectedNow;

    Color border = AppColors.border;
    Color bg = Colors.white;
    if (matched) {
      border = AppColors.green;
      bg = AppColors.greenLight;
    } else if (selectedNow) {
      border = flashRed ? AppColors.red : AppColors.blue;
      bg = flashRed ? AppColors.redLight : AppColors.blueLight;
    }

    return GestureDetector(
      onTap: matched || answered
          ? null
          : () => _onMatchTap(text, isLeft, speakable),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: AppColors.border, offset: Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: matched ? AppColors.greenDark : AppColors.ink,
            decoration: matched ? TextDecoration.none : null,
          ),
        ),
      ),
    );
  }

  void _onMatchTap(String text, bool isLeft, bool speakable) {
    final st = AppScope.of(context);
    setState(() {
      if (isLeft) {
        matchSelLeft = text;
        if (speakable) {
          AppScope.ttsOf(context)
              .setLanguage(st.course.ttsLang)
              .then((_) => AppScope.ttsOf(context).speak(text));
        }
      } else {
        matchSelRight = text;
      }
      if (matchSelLeft != null && matchSelRight != null) {
        final li = ex.matchLeft.indexOf(matchSelLeft!);
        final correct = ex.matchRight[li] == matchSelRight;
        if (correct) {
          matchedPairs.add('L:${matchSelLeft!}');
          matchedPairs.add('R:${matchSelRight!}');
          st.recordAnswer(true);
          correctCount++;
          AppScope.ttsOf(context).speak(matchSelLeft!);
        } else {
          st.recordAnswer(false);
          mistakes++;
          hearts--;
        }
        matchError = !correct;
        // clear selection after flash
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          setState(() {
            matchSelLeft = null;
            matchSelRight = null;
            matchError = false;
          });
          if (matchedPairs.length >= ex.matchLeft.length * 2) {
            _finishExercise(correct: true);
          } else if (hearts <= 0) {
            _showFailed(tr2: null);
          }
        });
      }
    });
  }

  String? tr2; // helper holder

  Widget _bottomAction(String Function(String) tr) {
    final canCheck = _canCheck();
    if (answered) {
      return _feedbackBar(tr);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: ChunkyButton(
              label: tr('check'),
              color: AppColors.green,
              colorDark: AppColors.greenDark,
              disabled: !canCheck,
              onPressed: canCheck ? () => _check(tr) : null,
            ),
          ),
        ],
      ),
    );
  }

  bool _canCheck() {
    switch (ex.type) {
      case ExerciseType.mcq:
      case ExerciseType.reverse:
      case ExerciseType.listen:
      case ExerciseType.picToWord:
      case ExerciseType.wordToPic:
      case ExerciseType.fillblank:
      case ExerciseType.truefalse:
        return selected != null;
      case ExerciseType.build:
        return placed.length == ex.tiles.length;
      case ExerciseType.match:
        return false; // handled by taps
    }
  }

  void _check(String Function(String) tr) {
    final st = AppScope.of(context);
    String userAnswer = '';
    if (ex.type == ExerciseType.build) {
      userAnswer = placed.map((i) => ex.tiles[i]).join(
          ex.tiles.join(' ').contains(' ') ? ' ' : '');
      // Compare case-insensitively without spaces for letter builds.
      final norm = (String s) =>
          s.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      wasCorrect = norm(userAnswer) == norm(ex.answer);
    } else if (ex.type == ExerciseType.fillblank) {
      userAnswer = selected != null ? ex.options[selected!] : '';
      final norm = (String s) =>
          s.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      wasCorrect = norm(userAnswer) == norm(ex.answer);
    } else {
      userAnswer = selected != null ? ex.options[selected!] : '';
      wasCorrect = userAnswer == ex.answer;
    }
    st.recordAnswer(wasCorrect);
    if (wasCorrect) {
      correctCount++;
      if (ex.audioText.isNotEmpty) {
        AppScope.ttsOf(context).speak(ex.audioText);
      }
    } else {
      mistakes++;
      hearts--;
    }
    setState(() => answered = true);
  }

  Widget _feedbackBar(String Function(String) tr) {
    final bg = wasCorrect ? AppColors.greenLight : AppColors.redLight;
    final fg = wasCorrect ? AppColors.greenDark : AppColors.redDark;
    final btnColor = wasCorrect ? AppColors.green : AppColors.red;
    final btnDark = wasCorrect ? AppColors.greenDark : AppColors.redDark;

    return Container(
      color: bg,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 14 + MediaQuery.of(context).padding.bottom * 0.4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                wasCorrect ? Icons.check_circle : Icons.error,
                color: fg,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wasCorrect ? tr('correct') : tr('wrong'),
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 17),
                    ),
                    if (!wasCorrect)
                      Text(
                        '${tr('correctAnswerIs')} ${ex.answer}',
                        style: TextStyle(color: fg, fontSize: 15),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            label: tr('continue'),
            color: btnColor,
            colorDark: btnDark,
            onPressed: () => _next(tr),
          ),
        ],
      ),
    );
  }

  void _next(String Function(String) tr) {
    if (hearts <= 0) {
      _showFailed(tr2: null);
      return;
    }
    if (isLast) {
      _showComplete(tr);
      return;
    }
    setState(() {
      index++;
      selected = null;
      answered = false;
      wasCorrect = false;
      placed = [];
      matchedPairs.clear();
      matchSelLeft = null;
      matchSelRight = null;
      matchError = false;
    });
    _speakIfNeeded();
  }

  void _finishExercise({required bool correct}) {
    if (isLast) {
      _showComplete((k) => context.tr(k));
    } else {
      _next((k) => context.tr(k));
    }
  }

  void _showComplete(String Function(String) tr) {
    final st = AppScope.of(context);
    final xpEarned = 10 + (mistakes == 0 ? 5 : 0) + correctCount;
    st.addXp(xpEarned);
    st.completeLesson(
      widget.lesson.id,
      mistakes: mistakes,
      vocabCount: widget.lesson.vocab.length,
    );
    st.touchCardsForLesson(widget.lesson.vocab);
    AppScope.ttsOf(context).stop();

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LessonResultScreen(
        lesson: widget.lesson,
        xpEarned: xpEarned,
        accuracy: correctCount + mistakes > 0
            ? (correctCount * 100 / (correctCount + mistakes)).round()
            : 100,
        perfect: mistakes == 0,
      ),
    ));
  }

  void _showFailed({String? tr2}) {
    AppScope.ttsOf(context).stop();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LessonFailedScreen(lesson: widget.lesson),
    ));
  }

  void _confirmQuit(String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('quitLesson'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(tr('quitLessonBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('stay'),
                style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text(tr('exit'),
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ---------------- Result screens ----------------

class LessonResultScreen extends StatefulWidget {
  final Lesson lesson;
  final int xpEarned;
  final int accuracy;
  final bool perfect;

  const LessonResultScreen({
    super.key,
    required this.lesson,
    required this.xpEarned,
    required this.accuracy,
    required this.perfect,
  });

  @override
  State<LessonResultScreen> createState() => _LessonResultScreenState();
}

class _LessonResultScreenState extends State<LessonResultScreen> {
  String? badgeShown;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final st = AppScope.of(context);
      final b = st.consumePendingBadge();
      if (b.isNotEmpty) setState(() => badgeShown = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = (String k) => context.tr(k);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const Mascot(size: 150, mood: MascotMood.celebrate),
                  const SizedBox(height: 24),
                  Text(
                    tr('lessonComplete'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  if (widget.perfect) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🎉 ${tr('perfectLesson')}',
                      style: const TextStyle(
                          color: AppColors.yellowDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _resultCard(
                          icon: Icons.bolt,
                          color: AppColors.yellow,
                          value: '+${widget.xpEarned}',
                          label: tr('xpEarned'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _resultCard(
                          icon: Icons.gps_fixed,
                          color: AppColors.blue,
                          value: '${widget.accuracy}%',
                          label: tr('accuracy'),
                        ),
                      ),
                    ],
                  ),
                  if (badgeShown != null) ...[
                    const SizedBox(height: 20),
                    _badgeCard(badgeShown!, tr),
                  ],
                  const Spacer(),
                  ChunkyButton(
                    label: tr('backHome'),
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ],
              ),
            ),
            // Celebratory confetti burst (v2.0).
            const Positioned.fill(
              child: IgnorePointer(child: ConfettiBurst()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: const [
          BoxShadow(
              color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 20)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.inkLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _badgeCard(String badgeId, String Function(String) tr) {
    final def = AppState.badgeDefs.firstWhere(
      (b) => b.id == badgeId,
      orElse: () => const BadgeDef('?', icon: Icons.star, color: AppColors.yellow),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.yellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: def.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(def.icon, color: def.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🏆 ${tr('newBadge')}',
                    style: TextStyle(
                        color: AppColors.yellowDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
                Text(tr('badge_$badgeId'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LessonFailedScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonFailedScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final tr = (String k) => context.tr(k);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Mascot(size: 150, mood: MascotMood.sad),
              const SizedBox(height: 24),
              Text(
                tr('lessonFailed'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                tr('heartsEmpty'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.inkLight, fontSize: 15),
              ),
              const Spacer(),
              ChunkyButton(
                label: tr('tryAgain'),
                icon: Icons.refresh,
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => LessonScreen(lesson: lesson),
                  ));
                },
              ),
              const SizedBox(height: 12),
              ChunkyButton(
                label: tr('backHome'),
                color: AppColors.inkLight,
                colorDark: AppColors.inkLight,
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
