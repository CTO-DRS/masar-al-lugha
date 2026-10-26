// Quick review mode (v5.11): a capped, due-only flashcard sprint.
//
// Difference from the Cards tab (flashcards.dart), stated honestly:
//  - due review cards ONLY — a quick review never introduces new words
//    (Insights.quickReviewQueue drops anything with reps == 0);
//  - hard-capped at Insights.quickReviewCap (12) cards so the session
//    stays a one-minute habit;
//  - ratings flow through the SAME SRS engine (rateCard) — nothing here
//    bypasses or reshapes the schedule.
// Works fully offline; the empty state is honest when nothing is due.
import 'package:flutter/material.dart';

import '../insights.dart';
import '../models.dart';
import '../scope.dart';
import '../srs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mascot.dart';

class QuickReviewScreen extends StatefulWidget {
  const QuickReviewScreen({super.key});

  @override
  State<QuickReviewScreen> createState() => _QuickReviewScreenState();
}

class _QuickReviewScreenState extends State<QuickReviewScreen> {
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
      // Pool = vocab of lessons the learner already completed (same rule
      // as the Cards tab), then the pure engine picks the due-only,
      // shuffled, capped queue.
      final pool = <Vocab>[];
      for (final l in st.course.allLessons) {
        if (!st.lessonStars.containsKey(l.id)) continue;
        pool.addAll(l.vocab);
      }
      setState(() {
        queue = Insights.quickReviewQueue(pool: pool, cards: st.cards);
        current = queue.isNotEmpty ? queue.first : null;
        started = true;
      });
    });
  }

  void _rate(int q) {
    final st = AppScope.of(context);
    final v = current!;
    st.rateCard(
        v.id, q); // SRS update — the schedule stays the single source of truth
    st.addXp(1);
    st.recordAnswer(q != Srs.again);
    setState(() {
      practiced += 1;
      xpGained += 1;
      queue.removeAt(0);
      // "Again" = not recalled: re-show at the end of this session.
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
      appBar: AppBar(title: Text(tr('quickReviewTitle'))),
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
                    valueColor: const AlwaysStoppedAnimation(AppColors.blue),
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
            tr('quickReviewHint'),
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
                  key: ValueKey(flipped ? 'qr-back${v.id}' : 'qr-front${v.id}'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: flipped
                        ? (context.isDark
                            ? AppColors.darkSoft
                            : AppColors.blueLight)
                        : context.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: flipped ? AppColors.blue : context.line,
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
              color: AppColors.blue,
              colorDark: AppColors.blueDark,
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
        const Icon(Icons.bolt, color: AppColors.blue, size: 26),
        const SizedBox(height: 8),
        Text(
          v.target,
          textDirection: directionOf(v.target),
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
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.blueDark,
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
                  // The example is target-language text — own direction.
                  textDirection: directionOf(v.exampleTarget!),
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
        // v5.11: one rule-based memory hint from the card's own review
        // history — renders nothing when no rule fires.
        MemoryHintLine(card: c),
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
                        Srs.hintFor(c, q, requestRetention: st.retentionTarget),
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
    final dueLeft = Insights.dueWithinDays(st.cards, 0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Mascot(size: 110, mood: MascotMood.celebrate),
            const SizedBox(height: 18),
            Text(
              practiced == 0 ? tr('quickReviewNoneDue') : tr('quickReviewDone'),
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
            ],
            Text(
              context.trF('quickReviewDueLeft', {'n': '$dueLeft'}),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
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
