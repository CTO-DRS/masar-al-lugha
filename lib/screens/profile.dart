// Profile: stats, badges, daily goal ring.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mascot.dart';
import 'home_shell.dart';
import 'settings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final tr = (String k) => context.tr(k);
    final today = AppState.todayKey();
    final goalProgress =
        st.dailyXpDay == today ? (st.dailyXp / st.dailyGoal).clamp(0.0, 1.0) : 0.0;

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
              child: Row(
                children: [
                  const Mascot(size: 76, mood: MascotMood.happy),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.uiLocale == 'ar' ? 'متعلّم متميز' : 'Star Learner',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 19),
                        ),
                        Text(
                          st.uiLocale == 'ar'
                              ? st.course.nameAr
                              : st.course.nameEn,
                          style: const TextStyle(
                              color: AppColors.inkLight, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                    icon: const Icon(Icons.settings,
                        color: AppColors.inkLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // stats grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                        icon: Icons.diamond,
                        color: AppColors.blue,
                        value: '${st.xp}',
                        label: tr('totalXp')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                        icon: Icons.local_fire_department,
                        color: AppColors.orange,
                        value: '${st.streak}',
                        label: tr('streak')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                        icon: Icons.school,
                        color: AppColors.green,
                        value: '${st.lessonsCompleted}',
                        label: tr('lessonsDone')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
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
                          color: Colors.white.withOpacity(0.25),
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
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.military_tech,
                          color: Colors.white.withOpacity(0.9), size: 30),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: st.levelProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.yellow),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart,
                          color: AppColors.blue, size: 22),
                      const SizedBox(width: 8),
                      Text(tr('weeklyActivity'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: Row(
                children: [
                  ProgressRing(
                    progress: goalProgress,
                    size: 86,
                    stroke: 9,
                    center: Text(
                      '${st.dailyXpDay == today ? st.dailyXp : 0}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('dailyGoal'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          goalProgress >= 1.0
                              ? '🎉 ${tr('goalDone')}'
                              : '${st.dailyGoal} XP ${tr('goalXp')}',
                          style: const TextStyle(
                              color: AppColors.inkLight, fontSize: 13),
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
                                  color: sel
                                      ? AppColors.green
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: sel
                                        ? AppColors.green
                                        : AppColors.border,
                                    width: 2,
                                  ),
                                ),
                                child: Text('$g',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.inkLight,
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
            // badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('badges'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
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
                                ? b.color.withOpacity(0.18)
                                : AppColors.bgSoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: earned ? b.color : AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            earned ? b.icon : Icons.lock,
                            color: earned ? b.color : AppColors.lockedDark,
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

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.inkLight, fontSize: 12)),
        ],
      ),
    );
  }
}

// Weekly XP bar chart (last 7 days) — v2.0.
class _WeeklyChart extends StatelessWidget {
  final List<(String, int)> days;
  const _WeeklyChart({required this.days});

  static const _dayLabelsAr = [
    'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'
  ];
  static const _dayLabelsEn = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

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
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkLight),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height:
                        (day.$2 / maxVal * 70).clamp(4.0, 70.0).toDouble(),
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
                          : AppColors.inkLight,
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
