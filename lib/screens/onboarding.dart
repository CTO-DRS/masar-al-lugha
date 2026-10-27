// Splash + onboarding. v5.15 (plan F3.1): the first-run journey is THREE
// screens — UI language, target course, and ONE experience question — and
// then the first lesson starts AUTOMATICALLY. Domain/level (the path
// wizard) are deferred to a non-blocking card on the first-win screen;
// every choice stays changeable later in Settings. No door ever closes.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import 'home_shell.dart';
import 'lesson_screen.dart';
import 'placement_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      final st = AppScope.of(context);
      // F3.1: a learner with an active profile NEVER sees the journey.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            st.onboardingDone ? const HomeShell() : const OnboardingScreen(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Mascot(size: 140, mood: MascotMood.celebrate),
            const SizedBox(height: 24),
            const Text(
              'مسار اللغة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Language Path',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0; // 0 = ui lang, 1 = course, 2 = experience (F3.1)
  bool _uiPicked = false;
  String? _pickedCourse;

  bool _canContinue() => step == 0 ? _uiPicked : _pickedCourse != null;

  // F3.1: end the journey by STARTING the first lesson automatically —
  // completing it is the first win, celebrated on the result screen.
  void _finishAndStartFirstLesson(BuildContext context, AppState st) {
    st.finishOnboarding();
    final first = st.course.units.first.lessons.first;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LessonScreen(lesson: first, firstWin: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(child: Mascot(size: 110, mood: MascotMood.happy)),
              const SizedBox(height: 20),
              Text(
                step == 0
                    ? L.t(st.uiLocale, 'chooseUiLang')
                    : step == 1
                        ? L.t(st.uiLocale, 'chooseCourse')
                        : L.t(st.uiLocale, 'experienceQuestion'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              if (step < 2)
                Text(
                  L.t(st.uiLocale, 'tagline'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: context.mutedText),
                ),
              const SizedBox(height: 28),
              if (step == 0) _buildUiLangChoices(st),
              if (step == 1) _buildCourseChoices(st),
              // F3.1: step 2 = the experience question; step 3 = its
              // experience branch (placement CTA + skip) stays on the
              // same screen — so the guard is >= 2, not == 2.
              if (step >= 2) _buildExperienceChoices(context, st),
              if (step < 2) ...[
                const Spacer(),
                ChunkyButton(
                  label: L.t(st.uiLocale, 'continue'),
                  onPressed:
                      _canContinue() ? () => setState(() => step += 1) : null,
                  disabled: !_canContinue(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceChoices(BuildContext context, AppState st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bigChoice(
          icon: Icons.emoji_emotions,
          title: L.t(st.uiLocale, 'fromZero'),
          subtitle: L.t(st.uiLocale, 'fromZeroHint'),
          onTap: () => _finishAndStartFirstLesson(context, st),
        ),
        const SizedBox(height: 14),
        _bigChoice(
          icon: Icons.school,
          title: L.t(st.uiLocale, 'withExperience'),
          subtitle: L.t(st.uiLocale, 'withExperienceHint'),
          onTap: () => setState(() => step = 3),
        ),
        // The "experience" branch: the adaptive placement test stays fully
        // available, but so is skipping — no mandatory decision (F3.1).
        if (step == 3) ...[
          const SizedBox(height: 18),
          ChunkyButton(
            label: L.t(st.uiLocale, 'startPlacement'),
            color: AppColors.blue,
            icon: Icons.quiz,
            onPressed: () {
              st.finishOnboarding();
              final nav = Navigator.of(context);
              nav
                  .push(MaterialPageRoute(
                builder: (_) => const PlacementScreen(),
              ))
                  .then((_) {
                if (!mounted) return;
                nav.pushReplacement(MaterialPageRoute(
                  builder: (_) => const HomeShell(),
                ));
              });
            },
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            label: L.t(st.uiLocale, 'skipForNow'),
            color: Colors.transparent,
            colorDark: Colors.transparent,
            textColor: context.mutedText,
            onPressed: () {
              st.finishOnboarding();
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => const HomeShell(),
              ));
            },
          ),
        ],
      ],
    );
  }

  Widget _bigChoice({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.card,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: context.line, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 34, color: AppColors.green),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(fontSize: 13, color: context.mutedText)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: context.mutedText),
          ],
        ),
      ),
    );
  }

  Widget _langCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? AppColors.blueLight : context.card,
            border: Border.all(
              color: selected ? AppColors.blue : AppColors.border,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: context.line, offset: Offset(0, 4), blurRadius: 0),
            ],
          ),
          child: Row(
            children: [
              Text(subtitle, style: TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.blue, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUiLangChoices(AppState st) {
    return Column(
      children: [
        _langCard(
          title: 'العربية',
          subtitle: '🇸🇦',
          selected: _uiPicked && st.uiLocale == 'ar',
          onTap: () {
            st.setLocale('ar');
            setState(() => _uiPicked = true);
          },
        ),
        _langCard(
          title: 'English',
          subtitle: '🌐',
          selected: _uiPicked && st.uiLocale == 'en',
          onTap: () {
            st.setLocale('en');
            setState(() => _uiPicked = true);
          },
        ),
      ],
    );
  }

  Widget _buildCourseChoices(AppState st) {
    return Column(
      children: st.courses.values
          .map((c) => _langCard(
                title: st.uiLocale == 'ar' ? c.nameAr : c.nameEn,
                subtitle: c.flag,
                selected: _pickedCourse == c.id,
                onTap: () {
                  _pickedCourse = c.id;
                  st.switchCourse(c.id);
                  setState(() {});
                },
              ))
          .toList(),
    );
  }
}
