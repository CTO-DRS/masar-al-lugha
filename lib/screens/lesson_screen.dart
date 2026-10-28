// Lesson runner: MCQ / reverse / listen / build / match + v2.0 picture,
// fill-blank and true-false exercises. F1.2: instant micro-repair card.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../exercise_gen.dart';
import '../l10n.dart';
import '../mascot.dart';
import '../models.dart';
import '../repair.dart';
import '../scope.dart';
import '../theme.dart';
import '../warmup.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/mascot.dart';
import 'path_setup_screen.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  /// v4.3: lesson style — classic (default), sentence-mining or audio-first.
  final LessonMode mode;

  /// v5.15 (F3.1): true when this lesson AUTO-STARTED from the first-run
  /// journey — completing it is the learner's first win, so the result
  /// screen shows the non-blocking "customize your path" card and records
  /// the time-to-first-win for the opt-in local analytics.
  final bool firstWin;

  const LessonScreen(
      {super.key,
      required this.lesson,
      this.mode = LessonMode.classic,
      this.firstWin = false});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  /// F1.1: the plan is built lazily on first access (initState cannot read
  /// AppScope) so the generator receives the learner's live confusion pairs
  /// and the lesson's CEFR band — confusion partners become distractor
  /// priorities 1+2, and A2+ lessons get the production floor.
  late final List<Exercise> exercises = _buildExercises();

  List<Exercise> _buildExercises() {
    final st = AppScope.of(context);
    var cefr = 'A1';
    for (final u in st.course.units) {
      if (u.lessons.any((l) => l.id == widget.lesson.id)) {
        cefr = u.cefr;
        break;
      }
    }
    // v5.15 (F3.4): the learn path may have warmed this exact plan in a
    // background isolate (same lesson + same mode + same cefr + same
    // confusion fingerprint). A cache hit means the first round renders
    // instantly; any mismatch falls through to the synchronous build.
    final warm = LessonWarmup.take(WarmupRequest(
      lessonId: widget.lesson.id,
      lesson: widget.lesson,
      mode: widget.mode,
      cefr: cefr,
      confusions: st.confusionPairs,
    ));
    if (warm != null) return warm;
    return ExerciseGen.forLesson(widget.lesson,
        mode: widget.mode, confusions: st.confusionPairs, cefr: cefr);
  }

  int index = 0;
  int hearts = 5;
  int mistakes = 0;
  int correctCount = 0;

  // v4.0 (audit H4): per-word correctness gathered during the lesson and
  // fed into the SRS on completion — replaces the old "everyone gets good".
  final Map<String, bool> wordResults = {};
  late final Map<String, String> _idByTarget = {
    for (final v in widget.lesson.vocab) v.target: v.id,
  };

  // v4.4 (local intelligence): text -> vocabId over the WHOLE course
  // (targets + Arabic meanings). Lets us capture WHICH word the learner
  // picked when they meant another one — the confusion-pair signal behind
  // the insights screen. Distractor options that are not real corpus
  // words (e.g. realWordReserve padding, emojis, true/false) simply miss.
  Map<String, String>? _idByTextCache;
  Map<String, String> get _idByText {
    var m = _idByTextCache;
    if (m == null) {
      m = {};
      for (final v in AppScope.of(context).course.allVocab) {
        m.putIfAbsent(v.target, () => v.id);
        m.putIfAbsent(v.translationAr, () => v.id);
      }
      _idByTextCache = m;
    }
    return m;
  }

  // per-exercise interaction state
  int? selected;
  bool answered = false;
  bool wasCorrect = false;
  List<int> placed = []; // indices into tiles
  final Set<String> matchedPairs = {};
  String? matchSelLeft;
  String? matchSelRight;
  bool matchError = false;

  // v4.6 dictation: typed answer state.
  final TextEditingController _typed = TextEditingController();

  // v4.6: normalized target -> vocabId over the whole course, so a wrong
  // dictation attempt that exactly spells another known word still feeds
  // the confusion engine ("their" typed for "there").
  Map<String, String>? _idByNormTargetCache;
  Map<String, String> get _idByNormTarget {
    var m = _idByNormTargetCache;
    if (m == null) {
      m = {};
      for (final v in AppScope.of(context).course.allVocab) {
        final n = ExerciseGen.normalizeTyped(v.target);
        if (n.isNotEmpty) m.putIfAbsent(n, () => v.id);
      }
      _idByNormTargetCache = m;
    }
    return m;
  }

  @override
  void dispose() {
    _typed.dispose();
    _fbTalking.dispose();
    super.dispose();
  }

  bool get isLast => index >= exercises.length - 1;

  /// F1.2: during a repair's question steps the body renders the REPAIR
  /// exercise (re-rolled question / quick pick), not the lesson round.
  Exercise get ex {
    if (_repairActive && _repairEx != null) return _repairEx!;
    return exercises[index];
  }

  // v4.10: the feedback-bar companion's mouth is driven by its bubble's
  // typewriter while it praises/nudges after every answer.
  final ValueNotifier<bool> _fbTalking = ValueNotifier(false);

  // ---- F1.2: instant micro-repair state ----------------------------------
  /// Words answered wrong at least once this session (first-mistake rule).
  final Set<String> _mistakenWords = {};

  /// Words whose repair already ran this session (the "repaired" flag the
  /// plan reserves for F2.4's later reuse).
  final Set<String> _repairedWords = {};

  /// A repair is due when the feedback bar's continue is tapped.
  bool _repairPending = false;
  bool _repairActive = false;
  RepairSession? _repair;

  /// The exercise rendered by the current repair step (null on the hint).
  Exercise? _repairEx;

  /// v5.17 (Phase-1 audit H-3): same-frame re-entrancy lock for the Check
  /// button (covers the repair state machine steps).
  bool _checkBusy = false;

  /// The vocab the learner actually picked on the failed round (when the
  /// wrong option mapped to a real corpus word) — feeds the repair hint.
  String? _lastWrongPickId;

  /// Match-boss bookkeeping: words missed inside the current pairing game
  /// (the game has no mid-round checkpoint, so its repair opens on finish).
  final Set<String> _matchMistakeIds = {};

  /// F1.2: stable intro tween — see _repairBody (a fresh Tween per build
  /// would restart the entrance animation on every setState).
  final Tween<double> _repairIntroTween = Tween(begin: 0, end: 1);

  /// v4.10: the in-prompt companion reacts to the answer LIVE — it hops
  /// with raised arms on a correct answer and shows a worried face on a
  /// wrong one, then returns to happy for the next exercise. No tap
  /// needed: the mood flip plays the celebration animation by itself.
  MascotMood get _headerMood => answered
      ? (wasCorrect ? MascotMood.celebrate : MascotMood.sad)
      : MascotMood.happy;

  @override
  void initState() {
    super.initState();
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
      case ExerciseType.dictation: // v4.6: the audio IS the prompt
      case ExerciseType.listenComp: // v4.6: the audio IS the prompt
        final tts = AppScope.ttsOf(context);
        tts
            .setLanguage(AppScope.of(context).course.ttsLang)
            .then((_) => tts.speak(ex.audioText));
        break;
      case ExerciseType.fillblank:
        final tts = AppScope.ttsOf(context);
        tts
            .setLanguage(AppScope.of(context).course.ttsLang)
            .then((_) => tts.speak(ex.audioText));
        break;
      case ExerciseType.build:
        // v4.3 audio-first: the sentence is played before the learner
        // arranges its words (with a replay button on the card).
        if (widget.mode == LessonMode.audio && ex.audioText.isNotEmpty) {
          final tts = AppScope.ttsOf(context);
          tts
              .setLanguage(AppScope.of(context).course.ttsLang)
              .then((_) => tts.speak(ex.audioText));
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.pageBg,
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
            child: Icon(Icons.close, color: context.lockedText, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (index + (answered ? 1 : 0)) / exercises.length,
                minHeight: 14,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
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
    // F1.2: the repair card replaces the round body entirely.
    if (_repairActive) return _repairBody(tr);
    return _roundBody(tr);
  }

  /// The plain per-type round renderer (no repair branching) — also used by
  /// the repair's question steps, which read `ex` (the repair exercise).
  Widget _roundBody(String Function(String) tr) {
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
      case ExerciseType.dictation:
        return _dictationBody(tr);
      case ExerciseType.listenComp:
        return _mcqBody(tr, isListen: true);
      case ExerciseType.grammar: // v5.18: the drill renders like an mcq
        return _mcqBody(tr, isListen: false);
    }
  }

  /// v4.3: the three listen variants get accurate captions — word options
  /// (classic), Arabic-meaning options (audio mode) and whole-sentence
  /// options (sentence-mining / audio mode).
  String _listenTitle(String Function(String) tr) {
    // v4.6: comprehension asks for the meaning, not the sentence itself.
    if (ex.type == ExerciseType.listenComp) return tr('listenUnderstand');
    if (ex.answer == ex.vocab.translationAr &&
        ex.vocab.translationAr.isNotEmpty) {
      return tr('listenMeaning');
    }
    if (ex.options.any((o) => o.trim().contains(' '))) {
      return tr('listenSentence');
    }
    return tr('listenAndChoose');
  }

  Widget _promptCard(String Function(String) tr, {required bool isListen}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Mascot(
                size: 56,
                mood: _headerMood,
                characterId: AppScope.of(context).mascotId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isListen
                      ? _listenTitle(tr)
                      : ex.type == ExerciseType.reverse
                          ? tr('chooseWord')
                          : ex.type == ExerciseType.grammar
                              ? tr('grammarPrompt')
                              : tr('chooseTranslation'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
                    onTap: () {
                      final tts = AppScope.ttsOf(context);
                      tts
                          .speak(ex.audioText)
                          .then((_) => tts.speak(ex.audioText));
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
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
                    style: TextStyle(color: context.mutedText, fontSize: 15),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.line, width: 2),
                ),
                child: Text(
                  ex.prompt,
                  // v4.12.1: the mcq prompt can be a full target-language
                  // sentence — lay it out in its own direction.
                  textDirection: directionOf(ex.prompt),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          // v5.18 (Batch B4): the grammar round teaches BEFORE it asks —
          // the rule reminder (drill.explainAr) rides in Exercise.hint and
          // is rendered here, where the learner reads it pre-answer.
          if (ex.type == ExerciseType.grammar && (ex.hint ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                ex.hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          if (!isListen &&
              ex.type == ExerciseType.mcq &&
              ex.vocab.phonetic != null)
            Text(ex.vocab.phonetic!,
                style: TextStyle(color: context.mutedText, fontSize: 14)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _mcqBody(String Function(String) tr, {required bool isListen}) {
    final badgeLetters = AppScope.of(context).uiLocale == 'ar'
        ? ['أ', 'ب', 'ج', 'د']
        : ['A', 'B', 'C', 'D'];
    // v4.3: sentence-length options (sentence-mining / audio rounds) get
    // full-width rows so they wrap instead of overflowing a 2-col grid.
    final longOptions = ex.options.any((o) => o.trim().length > 24);
    return Column(
      children: [
        _promptCard(tr, isListen: isListen),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: longOptions ? 1 : 2,
              childAspectRatio: longOptions ? 3.2 : 2.1,
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
              Mascot(
                size: 56,
                mood: _headerMood,
                characterId: AppScope.of(context).mascotId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    // v4.3 audio-first: the sentence was just spoken —
                    // say so instead of the generic arrange prompt.
                    widget.mode == LessonMode.audio && ex.audioText.isNotEmpty
                        ? tr('audioBuild')
                        : prompt,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.mode == LessonMode.audio && ex.audioText.isNotEmpty) ...[
            // Replay button — the core interaction of an audio-first build.
            GestureDetector(
              onTap: () {
                final tts = AppScope.ttsOf(context);
                tts
                    .setLanguage(AppScope.of(context).course.ttsLang)
                    .then((_) => tts.speak(ex.audioText));
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.blueDark,
                        offset: Offset(0, 4),
                        blurRadius: 0),
                  ],
                ),
                child:
                    const Icon(Icons.volume_up, color: Colors.white, size: 38),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.softBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.line, width: 2),
            ),
            child: Column(
              children: [
                // target meaning
                Text(ex.prompt,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                // answer line — v4.12.1: tiles are the TARGET language
                // (English/French LTR, Urdu RTL); they must lay out in
                // their own script direction, NOT the Arabic UI's RTL,
                // or the built sentence renders reversed ("morning | Good").
                ScriptDirection(
                  text: ex.tiles.join(' '),
                  child: Wrap(
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
                ),
                Divider(color: context.line, height: 24),
                // source tiles — same direction as the answer line so the
                // bank visually matches the sentence being built.
                ScriptDirection(
                  text: ex.tiles.join(' '),
                  child: Wrap(
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
                        const Text('', style: TextStyle(fontSize: 8)),
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

  // ---- v2.0 interactive picture exercises ----
  Widget _picBody(String Function(String) tr, {required bool pickPicture}) {
    final badgeLetters = AppScope.of(context).uiLocale == 'ar'
        ? ['أ', 'ب', 'ج', 'د']
        : ['A', 'B', 'C', 'D'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Mascot(
                    size: 56,
                    mood: _headerMood,
                    characterId: AppScope.of(context).mascotId,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pickPicture ? tr('whichPicture') : tr('whichWordForPic'),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
                      color: context.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.line, width: 2),
                    ),
                    child: Text(
                      ex.prompt,
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                if (ex.vocab.phonetic != null) ...[
                  const SizedBox(height: 6),
                  Text(ex.vocab.phonetic!,
                      style: TextStyle(color: context.mutedText, fontSize: 14)),
                ],
              ] else ...[
                // emoji prompt -> pick word
                GestureDetector(
                  onTap: () => AppScope.ttsOf(context).speak(ex.audioText),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.yellow, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.yellowDark,
                            offset: Offset(0, 5),
                            blurRadius: 0),
                      ],
                    ),
                    child: Center(
                      child: Text(ex.prompt,
                          style: TextStyle(fontSize: 64, height: 1.1)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tr('correctAnswerIs')} ${ex.hint ?? ''}',
                  style: TextStyle(color: context.mutedText, fontSize: 14),
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
                  onTap: answered ? null : () => setState(() => selected = i),
                );
              }
              return OptionCard(
                text: ex.options[i],
                badge: i < badgeLetters.length ? badgeLetters[i] : null,
                selected: selected == i,
                correct: answered && ex.options[i] == ex.answer,
                wrong: answered && selected == i && !wasCorrect,
                onTap: answered ? null : () => setState(() => selected = i),
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
                  Mascot(
                    size: 56,
                    mood: _headerMood,
                    characterId: AppScope.of(context).mascotId,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('fillBlank'),
                        style: TextStyle(
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
                  color: context.softBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.line, width: 2),
                ),
                child: Text(
                  ex.prompt,
                  // v4.12.1: the cloze prompt is a TARGET-language sentence
                  // with a blank — keep the blank on its correct side.
                  textDirection: directionOf(ex.prompt),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              if (ex.hint != null) ...[
                const SizedBox(height: 8),
                Text(ex.hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedText, fontSize: 14)),
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
                onTap: answered ? null : () => setState(() => selected = i),
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
              Mascot(
                size: 56,
                mood: _headerMood,
                characterId: AppScope.of(context).mascotId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('trueOrFalse'),
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.line, width: 2),
              boxShadow: [
                BoxShadow(
                    color: context.line, offset: Offset(0, 4), blurRadius: 0),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => AppScope.ttsOf(context).speak(ex.audioText),
                  child: Text(
                    ex.prompt,
                    // v4.12.1: prompt is the target-language word/phrase.
                    textDirection: directionOf(ex.prompt),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                ),
                if (ex.vocab.phonetic != null) ...[
                  const SizedBox(height: 4),
                  Text(ex.vocab.phonetic!,
                      style: TextStyle(color: context.mutedText, fontSize: 14)),
                ],
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.softBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shownMeaning,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
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
                  onTap: answered ? null : () => setState(() => selected = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OptionCard(
                  text: '❌ ${tr('falseWord')}',
                  selected: selected == 1,
                  correct: answered && ex.answer == 'false',
                  wrong: answered && selected == 1 && !wasCorrect,
                  onTap: answered ? null : () => setState(() => selected = 1),
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ---- v4.6 dictation: hear it -> type it ----
  Widget _dictationBody(String Function(String) tr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Mascot(
                size: 56,
                mood: _headerMood,
                characterId: AppScope.of(context).mascotId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('typeWhatYouHear'),
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Replay button — the core interaction of dictation.
          GestureDetector(
            onTap: () {
              final tts = AppScope.ttsOf(context);
              tts
                  .setLanguage(AppScope.of(context).course.ttsLang)
                  .then((_) => tts.speak(ex.audioText));
            },
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.blueDark,
                      offset: Offset(0, 5),
                      blurRadius: 0),
                ],
              ),
              child: const Icon(Icons.volume_up, color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 10),
          // The meaning — the learner must know WHAT to type.
          if (ex.hint != null)
            Text(ex.hint!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedText, fontSize: 15)),
          const SizedBox(height: 14),
          // v4.12.1: typed target-language text — align and shape it in its
          // own direction instead of the Arabic UI's RTL.
          ScriptDirection(
            text: ex.answer,
            child: TextField(
              controller: _typed,
              enabled: !answered,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: tr('typeHere'),
                filled: true,
                fillColor: context.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.line, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.blue, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.line, width: 2),
                ),
              ),
            ),
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
              Mascot(
                size: 56,
                mood: _headerMood,
                characterId: AppScope.of(context).mascotId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('matchPairs'),
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
                      // v4.0.1 fix: was `ttsLang == 'ur' || true` — a dead
                      // condition that always evaluated to true. Intent is
                      // tap-to-hear on every target word, so pass true.
                      for (final w in ex.matchLeft) _matchChip(w, true, tr),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final m in ex.matchRight) _matchChip(m, false, tr),
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
    final matched =
        matchedPairs.contains('L:$text') || matchedPairs.contains('R:$text');
    final selectedNow =
        (isLeft && matchSelLeft == text) || (!isLeft && matchSelRight == text);
    final flashRed = matchError && selectedNow;

    Color border = AppColors.border;
    Color bg = context.card;
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
          boxShadow: [
            BoxShadow(color: context.line, offset: Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: matched ? AppColors.greenDark : context.bodyText,
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
          final tts = AppScope.ttsOf(context);
          tts.setLanguage(st.course.ttsLang).then((_) => tts.speak(text));
        }
      } else {
        matchSelRight = text;
      }
      if (matchSelLeft != null && matchSelRight != null) {
        final li = ex.matchLeft.indexOf(matchSelLeft!);
        final correct = ex.matchRight[li] == matchSelRight;
        final leftWordId = _idByTarget[matchSelLeft!];
        if (correct) {
          matchedPairs.add('L:${matchSelLeft!}');
          matchedPairs.add('R:${matchSelRight!}');
          if (leftWordId != null) wordResults[leftWordId] = true;
          st.recordAnswer(true);
          correctCount++;
          // v4.0.1 fix: removed the second speak() here — the word was just
          // spoken on tap (async setLanguage race made them overlap).
        } else {
          if (leftWordId != null) {
            wordResults[leftWordId] = false;
            st.recordWordMistake(leftWordId);
            // v5.18 (Batch C): classify the mistake by its exercise kind.
            st.recordErrorKind(leftWordId, ex.type.name);
            // v4.4: wrong match -> the right-side text belongs to another
            // word; record the pair for the confusion engine.
            final rightId = _idByText[matchSelRight!];
            if (rightId != null && rightId != leftWordId) {
              st.recordConfusion(leftWordId, rightId);
              _lastWrongPickId = rightId; // F1.2: repair hint material
            }
            // F1.2: the repair opens when the whole board is done (the
            // game has no mid-round checkpoint).
            _matchMistakeIds.add(leftWordId);
          }
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
            _finishExercise();
          } else if (hearts <= 0) {
            _showFailed();
          }
        });
      }
    });
  }

  Widget _bottomAction(String Function(String) tr) {
    // F1.2: repair mode owns the bottom bar entirely — hint CTA, check
    // button for its questions, or the reused success feedback bar.
    if (_repairActive) {
      if (answered) return _feedbackBar(tr); // success green bar
      if (_repair!.step == RepairStep.hint) {
        final retry = _repair!.plan.retryOriginalOnly;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ChunkyButton(
            key: const ValueKey('repairHintCta'),
            label: tr(retry ? 'repairRetryCta' : 'repairHintCta'),
            color: AppColors.yellow,
            colorDark: AppColors.yellowDark,
            onPressed: _repairHintDone,
          ),
        );
      }
    } else if (answered) {
      return _feedbackBar(tr);
    }
    final canCheck = _canCheck();
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
      case ExerciseType.listenComp: // v4.6: option pick
      case ExerciseType.grammar: // v5.18: option pick
        return selected != null;
      case ExerciseType.dictation: // v4.6: something typed
        return _typed.text.trim().isNotEmpty;
      case ExerciseType.build:
        return placed.length == ex.tiles.length;
      case ExerciseType.match:
        return false; // handled by taps
    }
  }

  /// F1.2: pure correctness evaluation of the current round — shared by the
  /// scored check (normal rounds) and the XP-neutral repair check.
  bool _evaluate() {
    switch (ex.type) {
      case ExerciseType.build:
        String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final userAnswer = placed
            .map((i) => ex.tiles[i])
            .join(ex.tiles.join(' ').contains(' ') ? ' ' : '');
        return norm(userAnswer) == norm(ex.answer);
      case ExerciseType.fillblank:
        String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final userAnswer = selected != null ? ex.options[selected!] : '';
        return norm(userAnswer) == norm(ex.answer);
      case ExerciseType.dictation:
        return ExerciseGen.normalizeTyped(_typed.text) ==
            ExerciseGen.normalizeTyped(ex.answer);
      default:
        return selected != null && ex.options[selected!] == ex.answer;
    }
  }

  void _check(String Function(String) tr) {
    // v5.17 (Phase-1 audit H-3): same-frame double-tap on Check used to run
    // the whole scoring path twice (recordAnswer/mistakes/hearts). setState
    // below flips `answered` synchronously, so this guard closes the window
    // for scored rounds; _checkBusy covers the repair state machine, whose
    // steps keep answered=false while advancing.
    if (answered || _checkBusy) return;
    _checkBusy = true;
    try {
      // F1.2: inside a repair the same check button must NOT score the round —
      // correctness only drives the repair state machine (XP-neutral).
      if (_repairActive) {
        _checkRepair();
        return;
      }
      final st = AppScope.of(context);
      wasCorrect = _evaluate();
      st.recordAnswer(wasCorrect);
      // v4.0 (H4): remember how this specific word went. A word that was ever
      // answered wrong in this lesson stays flagged as shaky.
      _lastWrongPickId = null;
      if (!wasCorrect || wordResults[ex.vocab.id] == false) {
        wordResults[ex.vocab.id] = false;
        if (!wasCorrect) {
          st.recordWordMistake(ex.vocab.id);
          // v5.18 (Batch C): classify the mistake by its exercise kind —
          // rides the same guarded scored path, so rebuilds/double-taps
          // and XP-neutral repair rounds can never inflate it.
          st.recordErrorKind(ex.vocab.id, ex.type.name);
          // v4.4: capture WHICH word was picked instead (when the chosen
          // option maps to a real corpus word). true/false answers and
          // emoji options never map, so they are excluded implicitly.
          if (selected != null && selected! < ex.options.length) {
            switch (ex.type) {
              case ExerciseType.mcq:
              case ExerciseType.reverse:
              case ExerciseType.listen:
              case ExerciseType.picToWord:
              case ExerciseType.fillblank:
              case ExerciseType.listenComp: // v4.6: options are real meanings
                final other = _idByText[ex.options[selected!]];
                if (other != null && other != ex.vocab.id) {
                  st.recordConfusion(ex.vocab.id, other);
                  _lastWrongPickId = other; // F1.2: repair hint material
                }
                break;
              default:
                break; // build/match/truefalse/wordToPic: no text option
            }
          } else if (ex.type == ExerciseType.dictation) {
            // v4.6: a misheard dictation that exactly spells another known
            // word is a true confusion pair ("their" for "there").
            final other =
                _idByNormTarget[ExerciseGen.normalizeTyped(_typed.text)];
            if (other != null && other != ex.vocab.id) {
              st.recordConfusion(ex.vocab.id, other);
              _lastWrongPickId = other; // F1.2: repair hint material
            }
          }
        }
      } else {
        wordResults[ex.vocab.id] = true;
      }
      if (wasCorrect) {
        correctCount++;
        if (ex.audioText.isNotEmpty) {
          AppScope.ttsOf(context).speak(ex.audioText);
        }
      } else {
        mistakes++;
        hearts--;
        // F1.2: the FIRST mistake on a word in this session opens the instant
        // micro-repair after the feedback bar (unless the lesson just died).
        if (hearts > 0 &&
            RepairEngine.isFirstMistake(ex.vocab.id, _mistakenWords)) {
          _repairPending = true;
        }
      }
      // v5.15 (F3.3): simplified-audio mode announces the result aloud for
      // low-vision learners (opt-in in Settings; rides the existing TTS).
      if (st.simplifiedAudio) {
        AppScope.ttsOf(context)
            .speak(L.t(st.uiLocale, wasCorrect ? 'audioRight' : 'audioWrong'));
      }
      setState(() => answered = true);
    } finally {
      _checkBusy = false;
    }
  }

  Widget _feedbackBar(String Function(String) tr) {
    final bg = wasCorrect ? AppColors.greenLight : AppColors.redLight;
    final fg = wasCorrect ? AppColors.greenDark : AppColors.redDark;
    final btnColor = wasCorrect ? AppColors.green : AppColors.red;
    final btnDark = wasCorrect ? AppColors.greenDark : AppColors.redDark;
    // v4.10: the companion speaks AUTOMATICALLY after every answer —
    // praise after a correct one, a gentle nudge after a wrong one.
    final st = AppScope.of(context);
    // F1.2: a due repair swaps the nudge for the dedicated repair line and
    // the continue button for the repair opener; a repair success reuses the
    // normal green bar, but its continue resumes the lesson via _finishRepair.
    final repairDue = !wasCorrect && _repairPending;
    final repairSuccess = wasCorrect && _repairActive;
    final spoken = repairDue
        ? MascotEngine.repairLine(st.uiLocale, salt: mistakes)
        : wasCorrect
            ? MascotEngine.praiseLine(st.uiLocale, salt: correctCount)
            : MascotEngine.nudgeLine(st.uiLocale, salt: mistakes);

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
                          color: fg, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    if (!wasCorrect) ...[
                      Text(
                        tr('correctAnswerIs'),
                        style: TextStyle(color: fg, fontSize: 15),
                      ),
                      // v4.12.1: the answer is target-language text — render
                      // it in its own line and direction so trailing
                      // punctuation cannot flip in the RTL feedback bar.
                      Text(
                        ex.answer,
                        textDirection: directionOf(ex.answer),
                        style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // v4.10: automatic encouragement — the avatar animates (talks
          // and gestures) without any tap, exactly when it matters.
          const SizedBox(height: 8),
          MascotBubble(
            characterId: st.mascotId,
            mood: wasCorrect ? MascotMood.celebrate : MascotMood.happy,
            text: spoken,
            size: 40,
            animate: !st.reduceMotion,
            talking: _fbTalking,
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            key: ValueKey(repairDue
                ? 'repairOpen'
                : (repairSuccess ? 'repairDone' : 'lessonContinue')),
            label: repairDue
                ? tr('repairFixIt')
                : (repairSuccess ? tr('repairDone') : tr('continue')),
            color: btnColor,
            colorDark: btnDark,
            onPressed: repairDue
                ? _openRepair
                : (repairSuccess ? _finishRepairSuccess : () => _next(tr)),
          ),
        ],
      ),
    );
  }

  // ---- F1.2: instant micro-repair -----------------------------------------

  /// The repair card: hint step renders the dedicated hint card; question
  /// steps reuse the normal exercise bodies (they read `ex`, which resolves
  /// to the repair exercise). Entrance is instant under reduce-motion.
  Widget _repairBody(String Function(String) tr) {
    final st = AppScope.of(context);
    final Widget card;
    switch (_repair!.step) {
      case RepairStep.hint:
        card = _repairHintCard(tr);
        break;
      case RepairStep.reask:
      case RepairStep.quickPick:
        card = _roundBody(tr); // exercise body for the repair question
        break;
    }
    final content = Column(
      key: const ValueKey('repairPanel'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Row(
            children: [
              Icon(Icons.build_circle, color: AppColors.yellowDark, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('repairTitle'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink)),
              ),
            ],
          ),
        ),
        Expanded(child: card),
      ],
    );
    // Acceptance 3: reduce-motion shows the repair instantly, no animation.
    if (st.reduceMotion) return content;
    // NOTE: the tween must be a STABLE instance — a fresh Tween on every
    // build would restart the intro on every step change (and make the
    // content briefly untappable while it restarts).
    return TweenAnimationBuilder<double>(
      key: const ValueKey('repairIntro'),
      tween: _repairIntroTween,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)), child: child)),
      child: content,
    );
  }

  /// Step 1 — the rule/distinction + the word's own example as the neutral
  /// anchor. Content comes from RepairPlan (confusion pair > memory hint >
  /// generic; first match wins).
  Widget _repairHintCard(String Function(String) tr) {
    final st = AppScope.of(context);
    final plan = _repair!.plan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      children: [
        MascotBubble(
          characterId: st.mascotId,
          mood: MascotMood.happy,
          text: MascotEngine.repairLine(st.uiLocale, salt: mistakes),
          size: 44,
          animate: !st.reduceMotion,
          talking: _fbTalking,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.softBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.line, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.word.target,
                textDirection: directionOf(plan.word.target),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                context.trF(plan.hintKey, plan.hintArgs),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
        if (plan.exampleTarget != null && plan.exampleTarget!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.yellow.withValues(alpha: 0.5), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('repairExample'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.mutedText)),
                const SizedBox(height: 4),
                Text(
                  plan.exampleTarget!,
                  textDirection: directionOf(plan.exampleTarget!),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (plan.exampleAr != null && plan.exampleAr!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plan.exampleAr!,
                      style: TextStyle(fontSize: 14, color: context.mutedText)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Opens the repair for the round the learner just missed (feedback bar).
  void _openRepair() {
    final st = AppScope.of(context);
    final original = exercises[index];
    final plan = RepairEngine.buildPlan(
      original: original,
      word: original.vocab,
      pool: widget.lesson.vocab,
      confusions: st.confusionPairs,
      card: st.cards[original.vocab.id],
      confusedWithId: _lastWrongPickId,
      courseVocab: st.course.allVocab,
      random: math.Random(RepairEngine.seedFor(
          widget.lesson.id, original.vocab.id, _repairedWords.length)),
    );
    setState(() {
      _repairPending = false;
      _repairActive = true;
      _repair = RepairSession(plan);
      _repairEx = null; // hint step first
      answered = false; // the failed round's bar is dismissed
      wasCorrect = false;
      selected = null;
      placed = [];
      _typed.clear();
      _matchMistakeIds.clear();
    });
  }

  /// Opens the repair for a word missed inside a match boss — the pairing
  /// game has no mid-round checkpoint, so the repair opens when it completes.
  void _openRepairForMatchWord(String vocabId) {
    final st = AppScope.of(context);
    final word = widget.lesson.vocab
        .firstWhere((v) => v.id == vocabId, orElse: () => ex.vocab);
    final plan = RepairEngine.buildPlan(
      original: ex, // the match exercise itself (provenance only)
      word: word,
      pool: widget.lesson.vocab,
      confusions: st.confusionPairs,
      card: st.cards[vocabId],
      confusedWithId: _lastWrongPickId,
      courseVocab: st.course.allVocab,
      forMatch: true, // requeue the re-rolled round, not the whole boss
      random: math.Random(RepairEngine.seedFor(
          widget.lesson.id, vocabId, _repairedWords.length)),
    );
    setState(() {
      _repairPending = false;
      _repairActive = true;
      _repair = RepairSession(plan);
      _repairEx = null;
      answered = false;
      wasCorrect = false;
      selected = null;
      placed = [];
      _typed.clear();
    });
  }

  /// Hint CTA -> show the step-2 question (and speak it when it is audio-led).
  void _repairHintDone() {
    final action = _repair!.hintDone();
    setState(() {
      _repairEx = _repair!.plan.reask;
      selected = null;
      placed = [];
      _typed.clear();
    });
    if (action == RepairAction.toReask && _repairEx!.audioText.isNotEmpty) {
      _speakIfNeeded();
    }
  }

  /// Repair answer check — drives the state machine ONLY. No recordAnswer,
  /// no correctCount/mistakes, no hearts, no XP: repair rounds are
  /// treatment, not scored rounds (plan acceptance 4).
  void _checkRepair() {
    final r = _repair!;
    final ok = _evaluate();
    final action =
        r.step == RepairStep.reask ? r.answerReask(ok) : r.answerQuick(ok);
    if (action == RepairAction.success) {
      // Green feedback bar first (reused UI), then the continue button
      // resumes the lesson via _finishRepairSuccess.
      setState(() {
        wasCorrect = true;
        answered = true;
        selected = null;
        _typed.clear();
      });
      return;
    }
    if (action == RepairAction.giveUp) {
      // Two cycles exhausted — continue without embarrassment. The failed
      // question still comes back later as a normal scored round.
      _finishRepair();
      return;
    }
    setState(() {
      switch (action) {
        case RepairAction.toReask:
        case RepairAction.toQuickPick:
          _repairEx = action == RepairAction.toReask
              ? _repair!.plan.reask
              : _repair!.plan.quickPick;
          selected = null;
          placed = [];
          _typed.clear();
          break;
        case RepairAction.toHint:
          _repairEx = null;
          selected = null;
          placed = [];
          _typed.clear();
          break;
        default:
          break;
      }
    });
    if (action == RepairAction.toReask || action == RepairAction.toQuickPick) {
      final audio = _repairEx!.audioText;
      if (audio.isNotEmpty) _speakIfNeeded();
    }
  }

  /// Continue pressed on the repair-success green bar.
  void _finishRepairSuccess() {
    _finishRepair();
  }

  /// Ends the repair, requeues the failed question for >= 3 rounds later,
  /// and resumes the lesson at the next round.
  void _finishRepair() {
    final plan = _repair!.plan;
    _repairedWords.add(plan.word.id);
    _repair = null;
    _repairActive = false;
    _repairEx = null;
    selected = null;
    placed = [];
    _typed.clear();
    // The re-queued round is a NORMAL scored round (original question for
    // ordinary repairs; the re-rolled round for match-boss repairs).
    exercises.insert(
        RepairEngine.requeueIndex(justLeft: index, length: exercises.length),
        plan.requeue);
    _next((k) => context.tr(k));
  }

  /// v5.17 (Phase-1 audit H-3): true once the completion/failure route has
  /// been pushed — a same-frame double-tap on the last Continue used to call
  /// _showComplete twice, awarding the lesson XP twice.
  bool _finished = false;

  void _next(String Function(String) tr) {
    if (_finished) return;
    if (hearts <= 0) {
      _showFailed();
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
      _typed.clear(); // v4.6: fresh field for the next dictation
      _lastWrongPickId = null; // F1.2: hint material is per-round
      _matchMistakeIds.clear(); // F1.2: per-match bookkeeping
    });
    _speakIfNeeded();
  }

  void _finishExercise() {
    // F1.2: a first-mistake word inside the match boss still gets its
    // repair — opened now that the pairing game is complete. The first
    // missed word in board order goes (deterministic, no surprise).
    if (ex.type == ExerciseType.match && hearts > 0) {
      for (final id in _matchMistakeIds) {
        if (!_repairedWords.contains(id)) {
          _openRepairForMatchWord(id);
          return;
        }
      }
    }
    if (isLast) {
      _showComplete((k) => context.tr(k));
    } else {
      _next((k) => context.tr(k));
    }
  }

  void _showComplete(String Function(String) tr) {
    // v5.17 (Phase-1 audit H-3): the XP award + pushReplacement must run
    // exactly once per lesson, from every entry path (_next, _finishExercise).
    if (_finished) return;
    _finished = true;
    final st = AppScope.of(context);
    // v4.5: capture pre-lesson evidence so the companion can celebrate
    // level-ups and fresh streak milestones on the result screen.
    final levelBefore = st.level;
    final streakBefore = st.streak;
    // v4.8: capture pre-lesson records for the record-broken celebration.
    final bestStreakBefore = st.bestStreak;
    final bestDayXpBefore = st.bestDayXp;
    final accuracy = correctCount + mistakes > 0
        ? (correctCount * 100 / (correctCount + mistakes)).round()
        : 100;
    final xpEarned = 10 + (mistakes == 0 ? 5 : 0) + correctCount;
    st.addXp(xpEarned);
    st.completeLesson(
      widget.lesson.id,
      mistakes: mistakes,
      vocabCount: widget.lesson.vocab.length,
    );
    // v4.0 (H4): seed the SRS from REAL per-word performance instead of
    // marking every word as "good".
    st.applyLessonResults(wordResults);
    AppScope.ttsOf(context).stop();

    final mascotEvent = MascotEngine.resultEvent(
      lessonQuality:
          MascotEngine.lessonEvent(perfect: mistakes == 0, accuracy: accuracy),
      leveledUp: st.level > levelBefore,
      streakBefore: streakBefore,
      streakAfter: st.streak,
      brokeRecord: st.bestStreak > bestStreakBefore ||
          st.bestDayXp > bestDayXpBefore, // v4.8
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LessonResultScreen(
        lesson: widget.lesson,
        xpEarned: xpEarned,
        accuracy: accuracy,
        perfect: mistakes == 0,
        mascotEvent: mascotEvent,
        firstWin: widget.firstWin, // v5.15 (F3.1)
      ),
    ));
  }

  void _showFailed() {
    if (_finished) return;
    _finished = true;
    AppScope.ttsOf(context).stop();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          LessonFailedScreen(lesson: widget.lesson, mode: widget.mode),
    ));
  }

  void _confirmQuit(String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('quitLesson'),
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(tr('quitLessonBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('stay'),
                style: TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text(tr('exit'),
                style: TextStyle(
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

  /// v4.5: which companion moment this result represents (streak
  /// milestone / level-up / lesson quality), computed in _showComplete.
  final MascotEvent mascotEvent;

  /// v5.15 (F3.1): this result IS the learner's first win — shows the
  /// non-blocking customize-path card + records the journey timer.
  final bool firstWin;

  const LessonResultScreen({
    super.key,
    required this.lesson,
    required this.xpEarned,
    required this.accuracy,
    required this.perfect,
    this.mascotEvent = MascotEvent.lessonGreat,
    this.firstWin = false,
  });

  @override
  State<LessonResultScreen> createState() => _LessonResultScreenState();
}

class _LessonResultScreenState extends State<LessonResultScreen> {
  String? badgeShown;
  // v4.9: the companion's mouth is driven by the bubble's typewriter,
  // and tapping it re-rolls a fresh encouragement line.
  final ValueNotifier<bool> _talking = ValueNotifier(false);
  int _lineSalt = 0;

  @override
  void dispose() {
    _talking.dispose();
    super.dispose();
  }

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
    String tr(String k) => context.tr(k);
    final st = AppScope.of(context);
    // v4.5: companion speaks the moment — line rotates per lesson count.
    // v4.9: after a tap the companion switches to tap lines instead.
    final bubbleText = _lineSalt == 0
        ? MascotEngine.lineFor(widget.mascotEvent, st.mascotFacts, st.uiLocale,
            salt: st.lessonsCompleted)
        : MascotEngine.tapLine(st.mascotFacts, st.uiLocale,
            salt: _lineSalt + st.lessonsCompleted);
    final mood = MascotEngine.moodFor(widget.mascotEvent);
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Mascot(
                    size: 120,
                    mood: mood,
                    characterId: st.mascotId,
                    talking: _talking,
                    onTap: () => setState(() => _lineSalt++),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tr('lessonComplete'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  if (widget.perfect) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🎉 ${tr('perfectLesson')}',
                      style: TextStyle(
                          color: AppColors.yellowDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 14),
                  MascotBubble(
                    characterId: st.mascotId,
                    mood: mood,
                    text: bubbleText,
                    showAvatar: false,
                    animate: !st.reduceMotion,
                    talking: _talking,
                  ),
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
                  // v5.15 (F3.1): the first-win screen — the journey's
                  // celebration + a NON-BLOCKING path-customization card
                  // (the plan wizard, one tap, skippable forever).
                  if (widget.firstWin) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.softBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.line, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('firstWinTitle'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 17)),
                          const SizedBox(height: 4),
                          Text(tr('firstWinBody'),
                              style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 12.5,
                                  height: 1.35)),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const PathSetupScreen(),
                              ));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.alt_route,
                                    size: 20, color: AppColors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(tr('firstWinCustomize'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5)),
                                      Text(tr('firstWinCustomizeHint'),
                                          style: TextStyle(
                                              color: context.mutedText,
                                              fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 20, color: context.mutedText),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ChunkyButton(
                    key: ValueKey(
                        widget.firstWin ? 'firstWinContinue' : 'backHome'),
                    label:
                        tr(widget.firstWin ? 'firstWinContinue' : 'backHome'),
                    onPressed: () {
                      if (widget.firstWin) {
                        // The journey timer closes here (recorded once).
                        AppScope.of(context).markFirstWin();
                      }
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
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.line, width: 2),
        boxShadow: [
          BoxShadow(color: context.line, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          Text(label, style: TextStyle(color: context.mutedText, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _badgeCard(String badgeId, String Function(String) tr) {
    final def = AppState.badgeDefs.firstWhere(
      (b) => b.id == badgeId,
      orElse: () =>
          const BadgeDef('?', icon: Icons.star, color: AppColors.yellow),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: 0.2),
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
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LessonFailedScreen extends StatefulWidget {
  final Lesson lesson;
  final LessonMode mode; // v4.3: retry keeps the same lesson style

  const LessonFailedScreen({
    super.key,
    required this.lesson,
    this.mode = LessonMode.classic,
  });

  @override
  State<LessonFailedScreen> createState() => _LessonFailedScreenState();
}

class _LessonFailedScreenState extends State<LessonFailedScreen> {
  // v4.9: talking sync + tap for a fresh comfort line.
  final ValueNotifier<bool> _talking = ValueNotifier(false);
  int _lineSalt = 0;

  @override
  void dispose() {
    _talking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    // v4.5: the chosen companion speaks comfort (never shame).
    final st = AppScope.of(context);
    final bubbleText = _lineSalt == 0
        ? MascotEngine.lineFor(
            MascotEvent.lessonFailed, st.mascotFacts, st.uiLocale,
            salt: st.lessonsCompleted)
        : MascotEngine.tapLine(st.mascotFacts, st.uiLocale,
            salt: _lineSalt + st.lessonsCompleted);
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Mascot(
                size: 120,
                mood: MascotMood.sad,
                characterId: st.mascotId,
                talking: _talking,
                onTap: () => setState(() => _lineSalt++),
              ),
              const SizedBox(height: 18),
              Text(
                tr('lessonFailed'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                tr('heartsEmpty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedText, fontSize: 15),
              ),
              const SizedBox(height: 14),
              MascotBubble(
                characterId: st.mascotId,
                mood: MascotMood.sad,
                text: bubbleText,
                showAvatar: false,
                animate: !st.reduceMotion,
                talking: _talking,
              ),
              const Spacer(),
              ChunkyButton(
                label: tr('tryAgain'),
                icon: Icons.refresh,
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => LessonScreen(
                        lesson: widget.lesson,
                        mode: widget.mode), // v4.3: keep style
                  ));
                },
              ),
              const SizedBox(height: 12),
              ChunkyButton(
                label: tr('backHome'),
                color: context.mutedText,
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
