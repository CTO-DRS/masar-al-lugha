// Home shell: bottom navigation between Learn / Cards / Profile.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'flashcards.dart';
import 'learn_path.dart';
import 'profile.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final tr = (String k) => context.tr(k);
    final pages = [const LearnPath(), const FlashcardsScreen(), const ProfileScreen()];

    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _navItem(context, 0, Icons.school, tr('learn'), AppColors.green),
                _navItem(context, 1, Icons.style, tr('cards'), AppColors.blue),
                _navItem(context, 2, Icons.person, tr('profile'), AppColors.purple),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon,
      String label, Color activeColor) {
    final selected = tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => tab = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border(
                        top: BorderSide(color: activeColor, width: 3),
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Icon(icon,
                      color: selected
                          ? activeColor
                          : AppColors.lockedDark,
                      size: 26),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? activeColor : AppColors.lockedDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top stats bar shared across tabs.
class TopStatsBar extends StatelessWidget implements PreferredSizeWidget {
  const TopStatsBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final today = AppState.todayKey();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _showCourseSwitcher(context, st),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Row(
                  children: [
                    Text(st.course.flag,
                        style: const TextStyle(fontSize: 18)),
                    const Icon(Icons.expand_more,
                        size: 18, color: AppColors.inkLight),
                  ],
                ),
              ),
            ),
            const Spacer(),
            StatChip(
                icon: Icons.local_fire_department,
                color: AppColors.orange,
                value: '${st.streak}'),
            const SizedBox(width: 8),
            StatChip(
                icon: Icons.diamond,
                color: AppColors.blue,
                value: '${st.xp}'),
          ],
        ),
      ),
    );
  }

  void _showCourseSwitcher(BuildContext context, AppState st) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('selectLanguage'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 16),
                ...st.courses.values.map((c) {
                  final selected = c.id == st.courseId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        st.switchCourse(c.id);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.greenLight
                              : Colors.white,
                          border: Border.all(
                            color: selected
                                ? AppColors.green
                                : AppColors.border,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(c.flag,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                st.uiLocale == 'ar'
                                    ? c.nameAr
                                    : c.nameEn,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle,
                                  color: AppColors.green),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
