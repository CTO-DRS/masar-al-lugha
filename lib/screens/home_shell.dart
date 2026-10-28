// Home shell: bottom navigation between Learn / Cards / Dictionary / Profile.
// v4.0: dark-mode-aware chrome, 48dp+ touch targets (a11y), tab API for hero.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../scope.dart';
import '../design_system.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dictionary.dart';
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

  // v5.17 Phase-1 (audit D-1): the shell used to render `pages[tab]`, which
  // UNMOUNTS the previous tab on every switch — scroll positions, the
  // flashcards session queue and the dictionary search query were all lost.
  // A lazy IndexedStack keeps every VISITED tab mounted (offscreen tabs are
  // excluded from semantics and hit-testing) while never building an
  // unvisited one, so startup cost stays the same as before.
  final Set<int> _visited = {0};

  void switchTab(int i) => setState(() {
        tab = i;
        _visited.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final pages = [
      LearnPath(openTab: switchTab),
      const FlashcardsScreen(),
      const DictionaryScreen(),
      const ProfileScreen(),
    ];

    // v5.15 (F3.5): the larger-text accessibility setting scales the whole
    // shell subtree by 15% (opt-in, off by default).
    final scaler = st.largerText
        ? const TextScaler.linear(1.15)
        : MediaQuery.textScalerOf(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Scaffold(
        body: IndexedStack(
          index: tab,
          children: [
            for (var i = 0; i < pages.length; i++)
              _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.line, width: 2)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              // v5.17 (Phase-1 audit M-6): 66 clipped the nav pill by 3px on
              // 360dp phones — 72 gives the labels room on every width.
              height: 72,
              child: Row(
                children: [
                  _navItem(
                    context,
                    0,
                    Icons.school,
                    tr('learn'),
                    AppColors.green,
                  ),
                  _navItem(
                      context, 1, Icons.style, tr('cards'), AppColors.blue),
                  _navItem(
                    context,
                    2,
                    Icons.menu_book,
                    tr('dictionary'),
                    AppColors.purple,
                  ),
                  _navItem(
                    context,
                    3,
                    Icons.person,
                    tr('profile'),
                    AppColors.orange,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    Color activeColor,
  ) {
    final selected = tab == index;
    return Expanded(
      child: InkWell(
        // v5.17 (Phase-1 D-1 fix): MUST go through switchTab — the old
        // inline setState never marked the tab visited, so the lazy
        // IndexedStack showed a BLANK screen on first visit.
        onTap: () => switchTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border(top: BorderSide(color: activeColor, width: 3))
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: selected ? activeColor : context.lockedText,
                    size: 26,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? activeColor : context.lockedText,
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            // v5.15 (F3.3): the flag pill is a real button to screen readers.
            Semantics(
              button: true,
              label: context.tr('semCourseSwitcher'),
              child: GestureDetector(
                onTap: () => _showCourseSwitcher(context, st),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.line, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(st.course.flag,
                          style: const TextStyle(fontSize: 18)),
                      Icon(Icons.expand_more,
                          size: 18, color: context.mutedText),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            StatChip(
              icon: Icons.local_fire_department,
              color: AppColors.orange,
              value: '${st.streak}',
            ),
            const SizedBox(width: 8),
            StatChip(
              icon: Icons.bolt,
              color: AppColors.yellow,
              value: '${st.xp}',
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseSwitcher(BuildContext context, AppState st) {
    showModalBottomSheet(
      context: context,
      // v5.17 Phase-1: the glass recipe (design_system.dart) paints the
      // sheet itself; reduce-motion collapses it to a solid surface.
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassSurface(
          frosted: !st.reduceMotion,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ctx.tr('selectLanguage'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
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
                            color: selected ? AppColors.greenLight : ctx.card,
                            border: Border.all(
                              color: selected ? AppColors.green : ctx.line,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      st.uiLocale == 'ar' ? c.nameAr : c.nameEn,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: selected
                                            ? AppColors.greenDark
                                            : ctx.bodyText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.allVocab.length} ${ctx.tr('words')} · ${c.allLessons.length} ${ctx.tr('lessons')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ctx.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.green,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
