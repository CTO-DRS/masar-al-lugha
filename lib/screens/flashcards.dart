// Smart flashcards with FSRS-lite spaced repetition.
import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../srs.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import 'custom_decks_screen.dart';
import 'home_shell.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<Vocab> dueQueue = [];
  bool flipped = false;
  Vocab? current;
  bool showingAll = false;
  bool newCapped = false; // daily new-card budget exhausted (v4.0 H3)
  bool favMode = false; // v4.4: practice the starred (favorites) deck

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    final st = AppScope.of(context);
    final course = st.course;
    final now = DateTime.now().millisecondsSinceEpoch;

    // v4.4 favorites deck: the learner's explicitly starred words, in
    // starred order. The daily new-card budget does not gate this lane —
    // the user hand-picked these words — but ratings still flow through
    // the same SRS engine (rateCard).
    if (favMode) {
      final fav = st.favoriteVocab(course);
      setState(() {
        dueQueue = fav;
        current = fav.isNotEmpty ? fav.first : null;
        flipped = false;
      });
      return;
    }

    // v4.0 (audit H3): new SRS cards come ONLY from lessons the learner
    // already completed, in course order, capped by the daily budget —
    // a first-run user no longer faces every word in the course at once.
    final due = <Vocab>[];
    final newQueue = <Vocab>[];
    for (final l in course.allLessons) {
      if (!st.lessonStars.containsKey(l.id)) continue;
      for (final v in l.vocab) {
        final c = st.cardFor(v.id);
        if (c == null) {
          newQueue.add(v); // unseen but earned
        } else if (c.dueEpochMs <= now) {
          due.add(v);
        }
      }
    }
    final remaining = st.newCardsRemainingToday;
    newCapped = newQueue.length > remaining;
    final limitedNew = newQueue.take(remaining).toList();

    due.shuffle();
    setState(() {
      dueQueue = [...due, ...limitedNew];
      current = dueQueue.isNotEmpty ? dueQueue.first : null;
      flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final allCount = st.course.allVocab.length;
    final dueCount = dueQueue.length;
    final favCount = st.favoriteVocab(st.course).length;

    return Scaffold(
      body: Column(
        children: [
          const TopStatsBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _deckStat(
                    icon: favMode ? Icons.star : Icons.style,
                    color: favMode ? AppColors.yellow : AppColors.blue,
                    value: '$dueCount',
                    label: favMode ? tr('favorites') : tr('dueToday'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _deckStat(
                    icon: Icons.inventory_2,
                    color: AppColors.purple,
                    value: '$allCount',
                    label: tr('words'),
                  ),
                ),
              ],
            ),
          ),
          // v4.4: favorites deck toggle (only when there is something to show).
          if (favCount > 0 || favMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => favMode = !favMode);
                    _refresh();
                  },
                  icon: Icon(
                    favMode ? Icons.close : Icons.star,
                    color: AppColors.yellow,
                    size: 20,
                  ),
                  label: Text(
                    favMode
                        ? tr('exitFavorites')
                        : context.trF('practiceFavorites', {'n': '$favCount'}),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: AppColors.yellow,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.yellow, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          // v4.7: entry to user-authored word lists (always available).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CustomDecksScreen(),
                  ));
                },
                icon: const Icon(
                  Icons.playlist_add,
                  color: AppColors.purple,
                  size: 20,
                ),
                label: Text(
                  tr('myLists'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: AppColors.purple,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.purple, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: dueCount == 0
                ? _emptyState(tr)
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          tr('tapToFlip'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: _card(context, tr)),
                        const SizedBox(height: 14),
                        if (flipped) _ratingRow(tr) else _flipHint(tr),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _deckStat({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: context.mutedText, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String Function(String) tr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mascot(size: 120, mood: MascotMood.celebrate),
          const SizedBox(height: 20),
          Text(
            favMode
                ? tr('favoritesEmpty')
                : (newCapped ? tr('newCardsTomorrow') : tr('noCardsDue')),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            favMode ? tr('favoritesHint') : tr('comeBackTomorrow'),
            style: TextStyle(color: context.mutedText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _flipHint(String Function(String) tr) {
    return ChunkyButton(
      label: tr('tapToFlip'),
      color: AppColors.blue,
      colorDark: AppColors.blueDark,
      onPressed: () => setState(() => flipped = true),
    );
  }

  Widget _card(BuildContext context, String Function(String) tr) {
    final v = current!;
    final st = AppScope.of(context);
    final c = st.cardFor(v.id);

    return GestureDetector(
      onTap: () => setState(() => flipped = !flipped),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Container(
          key: ValueKey(flipped ? 'back$v.id' : 'front$v.id'),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // v4.0.1: dark-aware card surfaces — the front used a hardcoded
            // white and the back a hardcoded light blue.
            color: flipped
                ? (context.isDark ? AppColors.darkSoft : AppColors.blueLight)
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
    );
  }

  Widget _front(Vocab v) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          v.target,
          // v4.12.1: sentence vocab builds a full target-language line.
          textDirection: directionOf(v.target),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (v.phonetic != null)
          Text(
            v.phonetic!,
            style: TextStyle(color: context.mutedText, fontSize: 17),
          ),
        const SizedBox(height: 18),
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
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        if (v.exampleTarget != null) ...[
          const SizedBox(height: 16),
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
                  // v4.12.1: example is target-language text — own direction.
                  textDirection: directionOf(v.exampleTarget!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
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
          c == null
              ? context.tr('newCards')
              : c.state == 'learning'
                  ? context.tr('learningCards')
                  : context.tr('reviewCards'),
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _speak(String text) async {
    final st = AppScope.of(context);
    final tts = AppScope.ttsOf(context);
    await tts.setLanguage(st.course.ttsLang);
    await tts.speak(text);
  }

  Widget _ratingRow(String Function(String) tr) {
    final st = AppScope.of(context);
    final v = current!;
    final c = st.cardFor(v.id) ?? CardData();

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

  void _rate(int q) {
    final st = AppScope.of(context);
    final v = current!;
    st.rateCard(v.id, q);
    st.addXp(1);
    setState(() {
      dueQueue.removeAt(0);
      // "Again" = learning step: re-show this card later in the session.
      if (q == Srs.again) dueQueue.add(v);
      current = dueQueue.isNotEmpty ? dueQueue.first : null;
      flipped = false;
    });
  }
}
