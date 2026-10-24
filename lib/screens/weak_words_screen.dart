// Tough-words practice lane (v4.1, ROADMAP item 2 / MASTER PROMPT Wave 4):
// a dedicated flashcard session driven by the learner's real mistake counts
// (wordMistakes). Rates through the same SRS engine as the Cards tab, so
// practice results flow into the normal review schedule. Works fully offline.
import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../srs.dart';
import '../theme.dart';
import '../widgets/mascot.dart';

class WeakWordsScreen extends StatefulWidget {
  const WeakWordsScreen({super.key});

  @override
  State<WeakWordsScreen> createState() => _WeakWordsScreenState();
}

class _WeakWordsScreenState extends State<WeakWordsScreen> {
  List<Vocab> queue = [];
  Vocab? current;
  bool flipped = false;
  bool started = false;
  int practiced = 0;
  int xpGained = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = AppScope.of(context);
      setState(() {
        // Most-missed first; hard cap keeps a session short by design.
        queue = st.weakestVocab(st.course).take(20).toList();
        current = queue.isNotEmpty ? queue.first : null;
        started = true;
      });
    });
  }

  void _rate(int q) {
    final st = AppScope.of(context);
    final v = current!;
    st.rateCard(v.id, q); // SRS update — practice feeds the review schedule
    st.addXp(1);
    st.recordAnswer(q != Srs.again);
    setState(() {
      practiced += 1;
      xpGained += 1;
      queue.removeAt(0);
      // "Again" = still tough: re-show at the end of this session.
      if (q == Srs.again) queue.add(v);
      current = queue.isNotEmpty ? queue.first : null;
      flipped = false;
    });
  }

  Future<void> _speak(String text) async {
    final st = AppScope.of(context);
    final tts = AppScope.ttsOf(context);
    await tts.setLanguage(st.course.ttsLang);
    await tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    final total = practiced + queue.length;

    return Scaffold(
      appBar: AppBar(title: Text(tr('weakPracticeTitle'))),
      body: !started
          ? const SizedBox.shrink()
          : current == null
              ? _summary(tr)
              : _session(tr, total),
    );
  }

  Widget _session(String Function(String) tr, int total) {
    final v = current!;
    final st = AppScope.of(context);
    final c = st.cardFor(v.id);
    final done = practiced;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0.0 : done / total,
                    minHeight: 8,
                    backgroundColor: context.softBg,
                    valueColor: const AlwaysStoppedAnimation(AppColors.red),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$done/$total',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: context.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('weakPracticeHint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => flipped = !flipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Container(
                  key: ValueKey(flipped ? 'w-back${v.id}' : 'w-front${v.id}'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: flipped
                        ? (context.isDark
                            ? AppColors.darkSoft
                            : AppColors.redLight)
                        : context.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: flipped ? AppColors.red : context.line,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.border,
                        offset: Offset(0, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: flipped ? _back(v, c) : _front(v),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (flipped)
            _ratingRow((k) => tr(k))
          else
            ChunkyButton(
              label: tr('tapToFlip'),
              color: AppColors.red,
              colorDark: AppColors.redDark,
              onPressed: () => setState(() => flipped = true),
            ),
        ],
      ),
    );
  }

  Widget _front(Vocab v) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.fitness_center, color: AppColors.red, size: 26),
        const SizedBox(height: 8),
        Text(
          v.target,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        if (v.phonetic != null)
          Text(
            v.phonetic!,
            style: TextStyle(color: context.mutedText, fontSize: 16),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _speak(v.target),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.redDark,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(Icons.volume_up, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _back(Vocab v, CardData? c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          v.translationAr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        if (v.exampleTarget != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.softBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  v.exampleTarget!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  v.exampleAr ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${context.tr('misses')}: ${AppScope.of(context).wordMistakes[v.id] ?? 0}',
          style: TextStyle(
            color: context.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (c == null || c.reps == 0)
          Text(
            context.tr('newCards'),
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
      ],
    );
  }

  Widget _ratingRow(String Function(String) tr) {
    final st = AppScope.of(context);
    final c = st.cardFor(current!.id) ?? CardData();

    final items = [
      (Srs.again, tr('rateAgain'), AppColors.red, AppColors.redDark),
      (Srs.hard, tr('rateHard'), AppColors.orange, AppColors.yellowDark),
      (Srs.good, tr('rateGood'), AppColors.blue, AppColors.blueDark),
      (Srs.easy, tr('rateEasy'), AppColors.green, AppColors.greenDark),
    ];

    return Row(
      children: [
        for (final (q, label, color, dark) in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => _rate(q),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: dark,
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        Srs.hintFor(c, q),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary(String Function(String) tr) {
    final st = AppScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Mascot(size: 110, mood: MascotMood.celebrate),
            const SizedBox(height: 18),
            Text(
              practiced == 0 ? tr('noWeakWords') : tr('practiceDone'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (practiced > 0) ...[
              Text(
                '$practiced ${tr('cardsPracticed')} · +$xpGained ${tr('xpEarned')}',
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${st.accuracyPct}% ${tr('accuracy')} · ${st.wordsLearned} ${tr('wordsLearned')}',
                style: TextStyle(color: context.mutedText, fontSize: 13),
              ),
            ],
            const SizedBox(height: 26),
            ChunkyButton(
              label: tr('backHome'),
              icon: Icons.check,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
