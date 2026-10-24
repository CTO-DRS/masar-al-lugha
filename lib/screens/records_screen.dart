// Records screen (v4.8): the all-time personal-best board.
//
// Every number on this screen is computed ON DEVICE by lib/records.dart
// from the learner's own profile state — best streak, best day, active
// days, perfect lessons, authored words and more, plus a two-week XP
// momentum comparison. No network, no accounts: the banner says exactly
// that. Mirrors the visual language of InsightsScreen.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../records.dart';
import '../scope.dart';
import '../theme.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);

    final perfectLessons = st.lessonStars.values.where((s) => s >= 3).length;
    final starsTotal = st.lessonStars.values.fold<int>(0, (a, b) => a + b);
    final customWords =
        st.customDecks.fold<int>(0, (a, d) => a + d.words.length);
    final favorites = st.favorites.values.fold<int>(0, (a, l) => a + l.length);

    final records = Records.compute(
      bestStreak: st.bestStreak,
      streak: st.streak,
      xp: st.xp,
      bestDayXp: st.bestDayXp,
      activeDays: st.activeDays,
      lessonsCompleted: st.lessonsCompleted,
      perfectLessons: perfectLessons,
      starsTotal: starsTotal,
      wordsMastered: st.wordsLearned,
      cardsReviewed: st.cardsReviewed,
      accuracyPct: st.accuracyPct,
      customWords: customWords,
      favorites: favorites,
      badges: st.badges.length,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('recordsTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _banner(tr),
          const SizedBox(height: 16),
          _heroCard(tr, st),
          const SizedBox(height: 16),
          _weekCard(tr, st),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              for (final r in records) _statCard(tr, r),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------- shared chrome ----------------

  Widget _banner(String Function(String) tr) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blueLight.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blue.withValues(alpha: .4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock, color: AppColors.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr('recordsPrivacy'),
                  style: const TextStyle(
                      color: AppColors.blueDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.line, width: 2),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: child,
      );

  // ---------------- hero: streaks + xp ----------------

  Widget _heroCard(String Function(String) tr, AppState st) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green, AppColors.greenDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.greenDark.withValues(alpha: .5),
              offset: const Offset(0, 4),
              blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 40),
          const SizedBox(height: 6),
          Text(tr('recordsHero'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _heroCell(
                  icon: Icons.local_fire_department,
                  value: '${st.streak}',
                  label: tr('streak'),
                ),
              ),
              Expanded(
                child: _heroCell(
                  icon: Icons.whatshot,
                  value: '${st.bestStreak}',
                  label: tr('recordBestStreak'),
                ),
              ),
              Expanded(
                child: _heroCell(
                  icon: Icons.stars,
                  value: '${st.xp}',
                  label: tr('totalXp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCell({
    required IconData icon,
    required String value,
    required String label,
  }) =>
      Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .9),
                  fontWeight: FontWeight.w700,
                  fontSize: 11)),
        ],
      );

  // ---------------- weekly momentum ----------------

  Widget _weekCard(String Function(String) tr, AppState st) {
    final week = Records.weeklyXp(st.xpLog, DateTime.now());
    final max = week.thisWeek > week.lastWeek ? week.thisWeek : week.lastWeek;
    final delta = week.delta;
    final deltaColor = delta > 0
        ? AppColors.green
        : delta < 0
            ? AppColors.red
            : context.mutedText;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 20, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('weekMomentum'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: context.bodyText)),
              ),
              Icon(
                delta > 0
                    ? Icons.trending_up
                    : delta < 0
                        ? Icons.trending_down
                        : Icons.trending_flat,
                size: 20,
                color: deltaColor,
              ),
              const SizedBox(width: 4),
              Text(
                delta > 0 ? '+$delta' : '$delta',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: deltaColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _weekBar(
              label: tr('weekThis'),
              value: week.thisWeek,
              frac: max == 0 ? 0.0 : week.thisWeek / max,
              highlight: true),
          const SizedBox(height: 10),
          _weekBar(
              label: tr('weekLast'),
              value: week.lastWeek,
              frac: max == 0 ? 0.0 : week.lastWeek / max,
              highlight: false),
        ],
      ),
    );
  }

  Widget _weekBar({
    required String label,
    required int value,
    required double frac,
    required bool highlight,
  }) =>
      Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: context.mutedText)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    height: 18,
                    color: context.softBg,
                  ),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: highlight ? AppColors.green : AppColors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text('$value',
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: context.bodyText)),
          ),
        ],
      );

  // ---------------- record grid ----------------

  Widget _statCard(String Function(String) tr, RecordStat r) {
    final style = _styleFor(r.key);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.line, width: 2),
        boxShadow: [
          BoxShadow(
              color: context.line, offset: const Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: style.$2.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(style.$1, size: 20, color: style.$2),
          ),
          const SizedBox(height: 6),
          Text('${r.value}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: context.bodyText)),
          Text(tr(_labelKey(r.key)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: context.mutedText)),
        ],
      ),
    );
  }

  String _labelKey(String key) => switch (key) {
        'bestStreak' => 'recordBestStreak',
        'streak' => 'streak',
        'xp' => 'totalXp',
        'bestDayXp' => 'recordBestDay',
        'activeDays' => 'recordActiveDays',
        'lessons' => 'lessonsDone',
        'perfectLessons' => 'recordPerfectLessons',
        'stars' => 'recordStars',
        'words' => 'wordsLearned',
        'cards' => 'recordCards',
        'accuracy' => 'accuracy',
        'customWords' => 'recordCustomWords',
        'favorites' => 'recordFavorites',
        'badges' => 'badges',
        _ => key,
      };

  (IconData, Color) _styleFor(String key) => switch (key) {
        'bestStreak' => (Icons.whatshot, AppColors.red),
        'streak' => (Icons.local_fire_department, AppColors.orange),
        'xp' => (Icons.stars, AppColors.yellow),
        'bestDayXp' => (Icons.today, AppColors.purple),
        'activeDays' => (Icons.event_available, AppColors.green),
        'lessons' => (Icons.school, AppColors.blue),
        'perfectLessons' => (Icons.military_tech, AppColors.green),
        'stars' => (Icons.star, AppColors.yellow),
        'words' => (Icons.translate, AppColors.blue),
        'cards' => (Icons.style, AppColors.purple),
        'accuracy' => (Icons.track_changes, AppColors.red),
        'customWords' => (Icons.list_alt, AppColors.purple),
        'favorites' => (Icons.favorite, AppColors.red),
        'badges' => (Icons.emoji_events, AppColors.yellow),
        _ => (Icons.flag, AppColors.blue),
      };
}
