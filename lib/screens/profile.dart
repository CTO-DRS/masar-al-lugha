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
