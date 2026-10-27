// Profile: stats, badges, daily goal ring, weak-words analysis.
// v4.0: dark-mode-aware surfaces + error-analysis card (MASTER PROMPT H4).
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../mascot.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mascot.dart';
import 'error_analysis_screen.dart';
import 'home_shell.dart';
import 'insights_screen.dart';
import 'records_screen.dart';
import 'settings.dart';
import 'weak_words_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final today = AppState.todayKey();
    final goalProgress = st.dailyXpDay == today
        ? (st.dailyXp / st.dailyGoal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          children: [
            const TopStatsBar(),
            // header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.line, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: context.line,
                      offset: const Offset(0, 4),
                      blurRadius: 0),
                ],
              ),
              child: Row(
                children: [
                  Mascot(
                      size: 76,
                      mood: MascotMood.happy,
                      characterId: st.mascotId),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.uiLocale == 'ar' ? 'متعلّم متميز' : 'Star Learner',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              color: context.bodyText),
                        ),
                        Text(
                          st.uiLocale == 'ar'
                              ? st.course.nameAr
                              : st.course.nameEn,
                          style:
                              TextStyle(color: context.mutedText, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    icon: Icon(Icons.settings, color: context.mutedText),
                    tooltip: tr('settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // v4.5: companion card — chosen friend, rotating tips, picker.
            const _CompanionCard(),
            const SizedBox(height: 16),
            // stats grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(context,
                        icon: Icons.bolt,
                        color: AppColors.yellow,
                        value: '${st.xp}',
                        label: tr('totalXp')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(context,
                        icon: Icons.local_fire_department,
                        color: AppColors.orange,
                        value: '${st.streak}',
                        label: tr('streak')),
                  ),
                ],
              ),
            ),
            // v5.12 (F2.5): streak freeze wallet — visible whenever the
            // learner holds at least one shield.
            if (st.streakFreezes > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.blue, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ac_unit,
                          color: AppColors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.trF(
                                  'freezeChip', {'n': '${st.streakFreezes}'}),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              tr('freezeHint'),
                              style: TextStyle(
                                  fontSize: 11.5, color: context.mutedText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(context,
                        icon: Icons.school,
                        color: AppColors.green,
                        value: '${st.lessonsCompleted}',
                        label: tr('lessonsDone')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(context,
                        icon: Icons.style,
                        color: AppColors.purple,
                        value: '${st.wordsLearned}',
                        label: tr('wordsLearned')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // level card (v2.0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF58CC02), Color(0xFF1CB0F6)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.greenDark,
                      offset: Offset(0, 4),
                      blurRadius: 0),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${st.level}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('level'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17)),
                            Text(
                              '${st.xpToNextLevel} XP ${tr('nextLevel')}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.military_tech,
                          color: Colors.white.withValues(alpha: 0.9), size: 30),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: st.levelProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.yellow),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // weekly activity chart (v2.0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.line, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: context.line,
                      offset: const Offset(0, 4),
                      blurRadius: 0),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart,
                          color: AppColors.blue, size: 22),
                      const SizedBox(width: 8),
                      Text(tr('weeklyActivity'),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: context.bodyText)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _WeeklyChart(days: st.last7Days),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // daily goal
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.line, width: 2),
              ),
              child: Row(
                children: [
                  ProgressRing(
                    progress: goalProgress,
                    size: 86,
                    stroke: 9,
                    center: Text(
                      '${st.dailyXpDay == today ? st.dailyXp : 0}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: context.bodyText),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('dailyGoal'),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: context.bodyText)),
                        const SizedBox(height: 4),
                        Text(
                          goalProgress >= 1.0
                              ? '🎉 ${tr('goalDone')}'
                              : '${st.dailyGoal} XP ${tr('goalXp')}',
                          style:
                              TextStyle(color: context.mutedText, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: [10, 20, 50].map((g) {
                            final sel = st.dailyGoal == g;
                            return GestureDetector(
                              onTap: () {
                                st.setDailyGoal(g);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel ? AppColors.green : context.card,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: sel ? AppColors.green : context.line,
                                    width: 2,
                                  ),
                                ),
                                child: Text('$g',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: sel
                                          ? Colors.white
                                          : context.mutedText,
                                    )),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // v4.0: error analysis — the learner's hardest words
            _WeakWordsCard(st: st, tr: tr),
            const SizedBox(height: 20),
            // badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('badges'),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: context.bodyText)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AppState.badgeDefs.map((b) {
                      final earned = st.badges.contains(b.id);
                      return Tooltip(
                        message: tr('badge_${b.id}'),
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: earned
                                ? b.color.withValues(alpha: 0.18)
                                : context.softBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: earned ? b.color : context.line,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            earned ? b.icon : Icons.lock,
                            color: earned ? b.color : context.lockedText,
                            size: 28,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.line, width: 2),
        boxShadow: [
          BoxShadow(
              color: context.line, offset: const Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: context.bodyText)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12)),
        ],
      ),
    );
  }
}

// v4.0: words the learner keeps getting wrong (from per-word lesson results).
class _WeakWordsCard extends StatelessWidget {
  final AppState st;
  final String Function(String) tr;
  const _WeakWordsCard({required this.st, required this.tr});

  @override
  Widget build(BuildContext context) {
    // Map word ids -> vocab of the current course.
    final byId = {for (final v in st.course.allVocab) v.id: v};
    final weak = st.weakestWordIds
        .map((id) => byId[id])
        .whereType<Vocab>()
        .take(5)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.line, width: 2),
        ),
        child: weak.isEmpty
            ? Row(
                children: [
                  Icon(Icons.sentiment_satisfied,
                      color: AppColors.green, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('noWeakWords'),
                        style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up,
                          color: AppColors.red, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tr('weakWords'),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: context.bodyText)),
                      ),
                      // v4.1: quick lane into the tough-words practice.
                      IconButton(
                        tooltip: tr('practiceWeak'),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const WeakWordsScreen(),
                          ));
                        },
                        icon: const Icon(Icons.fitness_center,
                            color: AppColors.red, size: 22),
                      ),
                      // v4.1: full error-analysis screen (top-20 + accuracy).
                      IconButton(
                        tooltip: tr('errorAnalysis'),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ErrorAnalysisScreen(),
                          ));
                        },
                        icon: Icon(Icons.chevron_right,
                            size: 22, color: context.mutedText),
                      ),
                      // v4.4: local-intelligence dashboard (insights).
                      IconButton(
                        tooltip: tr('insightsTitle'),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const InsightsScreen(),
                          ));
                        },
                        icon: const Icon(Icons.insights,
                            color: AppColors.blue, size: 22),
                      ),
                      // v4.8: all-time personal records board.
                      IconButton(
                        tooltip: tr('recordsTitle'),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const RecordsScreen(),
                          ));
                        },
                        icon: const Icon(Icons.emoji_events,
                            color: AppColors.yellow, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...weak.map((v) {
                    final n = st.wordMistakes[v.id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final tts = AppScope.ttsOf(context);
                                tts
                                    .setLanguage(st.course.ttsLang)
                                    .then((_) => tts.speak(v.target));
                              },
                              child: Text(
                                '${v.target} — ${v.translationAr}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: context.bodyText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '✗ $n',
                              style: const TextStyle(
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}

// Weekly XP bar chart (last 7 days) — v2.0.
class _WeeklyChart extends StatelessWidget {
  final List<(String, int)> days;
  const _WeeklyChart({required this.days});

  static const _dayLabelsAr = [
    'أحد',
    'اثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
    'سبت'
  ];
  static const _dayLabelsEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final maxVal = days
        .map((d) => d.$2)
        .reduce((a, b) => a > b ? a : b)
        .clamp(10, 1 << 20);
    final st = AppScope.of(context);
    final labels = st.uiLocale == 'ar' ? _dayLabelsAr : _dayLabelsEn;

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, day) in days.indexed)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    day.$2 > 0 ? '${day.$2}' : '',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: context.mutedText),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: (day.$2 / maxVal * 70).clamp(4.0, 70.0).toDouble(),
                    width: 18,
                    decoration: BoxDecoration(
                      color: i == days.length - 1
                          ? AppColors.orange
                          : AppColors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[DateTime.parse('${day.$1} 12:00:00').weekday % 7],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: i == days.length - 1
                          ? AppColors.orange
                          : context.mutedText,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// v4.5 — companion card: the chosen friend speaks (comeback or rotating
// study tip), plus the full cast picker with evidence-based unlocks.
class _CompanionCard extends StatefulWidget {
  const _CompanionCard();

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard> {
  // v4.10: the card is now a LiveCompanion — it speaks the comeback/idle
  // moment on open, keeps chatting ambient motivation every 24–36 s, and
  // replies to every tap. No local tap counter or talking notifier needed.
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);

    // Comeback beats idle tips: >= 3 fully-missed days triggers the
    // welcome-back moment (evidence-gated, never guilt-tripping).
    final comeback = st.mascotMissedDays >= 3;
    final event = comeback ? MascotEvent.comeback : MascotEvent.idle;
    final tip = MascotEngine.lineFor(event, st.mascotFacts, st.uiLocale,
        salt: comeback ? 0 : AppState.todayKey().hashCode % 97);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.line, width: 2),
        boxShadow: [
          BoxShadow(
              color: context.line, offset: const Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_emotions, color: AppColors.yellow, size: 20),
              const SizedBox(width: 8),
              Text(tr('companionCard'),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: context.bodyText)),
              const Spacer(),
              Text(mascotById(st.mascotId).name(st.uiLocale),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          LiveCompanion(
            characterId: st.mascotId,
            facts: st.mascotFacts,
            locale: st.uiLocale,
            mood: comeback ? MascotMood.happy : MascotMood.neutral,
            size: 64,
            reduceMotion: st.reduceMotion,
            openingText: tip,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              tr('companionSub'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.mutedText),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr('companionChoose'),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: context.mutedText)),
          const SizedBox(height: 8),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mascotCast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _tile(context, mascotCast[i], st, tr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, MascotCharacter c, AppState st,
      String Function(String) tr) {
    final unlocked = st.isMascotUnlocked(c.id);
    final selected = st.mascotId == c.id;
    final req = c.missingRequirement(st.mascotFacts);

    String hint;
    if (selected) {
      hint = tr('mascotSelected');
    } else if (!unlocked) {
      final (kind, amount) = req!;
      hint = switch (kind) {
        'xp' => context.trF('unlockXp', {'n': '$amount'}),
        'streak' => context.trF('unlockStreak', {'n': '$amount'}),
        _ => context.trF('unlockLessons', {'n': '$amount'}),
      };
    } else {
      hint = tr('mascotTapSelect');
    }

    return GestureDetector(
      onTap: unlocked ? () => st.selectMascot(c.id) : null,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenLight : context.softBg,
          border: Border.all(
              color: selected ? AppColors.green : context.line, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Mascot(
                  size: 46,
                  mood: selected
                      ? MascotMood.celebrate
                      : (unlocked ? MascotMood.happy : MascotMood.neutral),
                  characterId: c.id,
                ),
                if (!unlocked)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.inkLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(c.name(st.uiLocale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: context.bodyText)),
            const SizedBox(height: 3),
            Text(
              hint,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.greenDark : context.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
