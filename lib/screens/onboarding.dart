// Splash + onboarding: pick UI language, pick course.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import 'home_shell.dart';

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
  int step = 0; // 0 = ui lang, 1 = course

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
                    : L.t(st.uiLocale, 'chooseCourse'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                L.t(st.uiLocale, 'tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: context.mutedText),
              ),
              const SizedBox(height: 28),
              if (step == 0) _buildUiLangChoices(st),
              if (step == 1) _buildCourseChoices(st),
              const Spacer(),
              ChunkyButton(
                label: L.t(st.uiLocale, 'continue'),
                onPressed: _canContinue()
                    ? () {
                        if (step == 0) {
                          setState(() => step = 1);
                        } else {
                          st.finishOnboarding();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const HomeShell()),
                          );
                        }
                      }
                    : null,
                disabled: !_canContinue(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _uiPicked = false;
  String? _pickedCourse;

  bool _canContinue() => step == 0 ? _uiPicked : _pickedCourse != null;

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
