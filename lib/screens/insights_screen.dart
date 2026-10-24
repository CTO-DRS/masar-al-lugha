// Learning Insights (v4.4): the local-intelligence dashboard.
//
// Every card here is computed ON DEVICE by lib/insights.dart from the
// learner's own logs — accuracy trend, best study hour, confusion pairs,
// smart goal suggestion, review forecast and rule-based tutor tips.
// No network, no accounts: the privacy banner says exactly that.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../insights.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import 'weak_words_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final ar = st.uiLocale == 'ar';

    final trend = Insights.accuracyTrend(st.answerLog, days: 7);
    final bestHour = Insights.bestStudyHour(st.hourTotal, st.hourCorrect);
    final suggestion = Insights.goalSuggestion(
      currentGoal: st.dailyGoal,
      xpLog: st.xpLog,
    );
    final pairs = st.courseConfusionPairs(5);
    final tips = Insights.tutorTips(
      confusionPairs: st.confusionPairs,
      vocabById: st.vocabById(st.course),
      hourTotal: st.hourTotal,
      hourCorrect: st.hourCorrect,
      cards: st.cards,
      streak: st.streak,
      todayXp: st.dailyXp,
      dailyGoal: st.dailyGoal,
      answerLog: st.answerLog,
    );
    final hasData = st.totalAnswers > 0;

    return Scaffold(
      appBar: AppBar(title: Text(tr('insightsTitle'))),
      body: !hasData
          ? _empty(tr)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _privacyBanner(tr),
                const SizedBox(height: 16),
                _trendCard(tr, trend, ar),
                const SizedBox(height: 16),
                if (bestHour != null) ...[
                  _bestHourCard(tr, st, bestHour),
                  const SizedBox(height: 16),
                ],
                if (suggestion != null) ...[
                  _goalCard(tr, suggestion),
                  const SizedBox(height: 16),
                ],
                if (pairs.isNotEmpty) ...[
                  _pairsCard(tr, st, pairs),
                  const SizedBox(height: 16),
                ],
                _forecastCard(tr, st),
                const SizedBox(height: 16),
                if (tips.isNotEmpty) ...[
                  _tipsCard(tr, tips),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  // ---------------- shared card chrome ----------------

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

  Widget _sectionTitle(String text, IconData icon, Color color) => Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: context.bodyText)),
          ),
        ],
      );

  // ---------------- 1. privacy banner ----------------

  Widget _privacyBanner(String Function(String) tr) => Container(
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
              child: Text(tr('insightsPrivacy'),
                  style: const TextStyle(
                      color: AppColors.blueDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
          ],
        ),
      );

  Widget _empty(String Function(String) tr) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights, size: 64, color: AppColors.blue),
              const SizedBox(height: 16),
              Text(tr('noInsightsYet'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      );

  // ---------------- 2. accuracy trend ----------------

  Widget _trendCard(
      String Function(String) tr, List<(String, int)> trend, bool ar) {
    const dayNamesAr = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    const dayNamesEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final bars = <Widget>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final entry = trend.where((t) => t.$1 == key).toList();
      final pct = entry.isNotEmpty ? entry.first.$2 : null;
      final label = ar
          ? dayNamesAr[d.weekday - 1].substring(0, 3)
          : dayNamesEn[d.weekday - 1];
      bars.add(_trendBar(pct, label, isToday: i == 0));
    }
    final active = trend.length;
    final avg = active == 0
        ? 0
        : trend.map((t) => t.$2).reduce((a, b) => a + b) ~/ active;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(tr('insightsTrend'), Icons.show_chart, AppColors.blue),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: bars[i]),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active == 0
                ? tr('noAnswersLogged')
                : context.trF('insightsTrendAvg', {
                    'avg': '$avg',
                    'days': '$active',
                  }),
            style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _trendBar(int? pct, String label, {required bool isToday}) {
    final h = pct == null ? 4.0 : (8.0 + (pct / 100.0) * 72.0);
    final color = pct == null
        ? context.lockedFill
        : pct >= 80
            ? AppColors.green
            : pct >= 50
                ? AppColors.orange
                : AppColors.red;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(pct == null ? '—' : '$pct',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: pct == null ? context.mutedText : color)),
        const SizedBox(height: 4),
        Container(
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(isToday ? '$label •' : label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isToday ? context.bodyText : context.mutedText)),
      ],
    );
  }

  // ---------------- 3. best study hour ----------------

  Widget _bestHourCard(String Function(String) tr, AppState st, int hour) {
    final ar = st.uiLocale == 'ar';
    final acc =
        (Insights.accuracyAt(st.hourTotal, st.hourCorrect, hour) * 100).round();
    final hourLabel = _hourLabel(hour, ar);
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.schedule, color: AppColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('insightsBestHour'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: context.bodyText)),
                const SizedBox(height: 4),
                Text(
                  context
                      .trF('bestHourText', {'hour': hourLabel, 'pct': '$acc'}),
                  style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(int hour, bool ar) {
    if (ar) {
      if (hour < 12) return '$hour صباحاً';
      if (hour == 12) return '12 ظهراً';
      if (hour == 0) return '12 منتصف الليل';
      return '${hour - 12} مساءً';
    }
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }

  // ---------------- 4. smart goal suggestion ----------------

  Widget _goalCard(String Function(String) tr, GoalSuggestion s) {
    final st = AppScope.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              tr('insightsGoal'), Icons.track_changes, AppColors.orange),
          const SizedBox(height: 10),
          Text(
            context.trF(s.reasonKey, s.params),
            style: TextStyle(
                color: context.bodyText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            context.trF('goalCurrentNew', {
              'current': '${st.dailyGoal}',
              'new': '${s.newGoal}',
            }),
            style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w800,
                fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            label: context.trF('goalApply', {'goal': '${s.newGoal}'}),
            icon: Icons.check_circle,
            color: AppColors.orange,
            colorDark: AppColors.orange,
            onPressed: () {
              AppScope.of(context).setDailyGoal(s.newGoal);
              setState(() {}); // suggestion recompute -> disappears
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('goalApplied'))),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------- 5. confusion pairs ----------------

  Widget _pairsCard(
      String Function(String) tr, AppState st, List<ConfusionPair> pairs) {
    final byId = st.vocabById(st.course);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(tr('insightsPairs'), Icons.swap_horiz, AppColors.red),
          const SizedBox(height: 4),
          Text(tr('pairsHint'),
              style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(height: 10),
          for (var i = 0; i < pairs.length; i++)
            _pairRow(tr, st, pairs[i], byId),
        ],
      ),
    );
  }

  Widget _pairRow(String Function(String) tr, AppState st, ConfusionPair p,
      Map<String, Vocab> byId) {
    final a = byId[p.vocabIdA];
    final b = byId[p.vocabIdB];
    if (a == null || b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.softBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${a.target} ↔ ${b.target}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: context.bodyText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.trF('pairTimes', {'n': '${p.count}'}),
                    style: const TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w900,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ChunkyButton(
              label: tr('pairPractice'),
              color: AppColors.blue,
              colorDark: AppColors.blueDark,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WeakWordsScreen(
                  fixedPool: [a, b],
                  titleKey: 'pairPracticeTitle',
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 6. review forecast ----------------

  Widget _forecastCard(String Function(String) tr, AppState st) {
    final dueNow = st.cards.values.where((c) => c.isDue).length;
    final tomorrow = st.dueTomorrowCount;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              tr('insightsForecast'), Icons.event_repeat, AppColors.green),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _forecastStat(tr, Icons.today, AppColors.green,
                    '$dueNow', 'dueNowCount', {'n': '$dueNow'}),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _forecastStat(tr, Icons.event, AppColors.blue,
                    '$tomorrow', 'dueTomorrowCount', {'n': '$tomorrow'}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _forecastStat(String Function(String) tr, IconData icon, Color color,
      String value, String key, Map<String, String> params) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.trF(key, params),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: context.bodyText),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 7. tutor tips ----------------

  Widget _tipsCard(String Function(String) tr, List<TutorTip> tips) {
    const tipIcons = {
      'tipConfusion': Icons.swap_horiz,
      'tipBestHour': Icons.schedule,
      'tipStreakGuard': Icons.local_fire_department,
      'tipReviewWave': Icons.event_repeat,
      'tipTrendUp': Icons.trending_up,
      'tipTrendDown': Icons.trending_down,
    };
    const tipColors = {
      'tipConfusion': AppColors.red,
      'tipBestHour': AppColors.purple,
      'tipStreakGuard': AppColors.red,
      'tipReviewWave': AppColors.blue,
      'tipTrendUp': AppColors.green,
      'tipTrendDown': AppColors.orange,
    };
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              tr('insightsTips'), Icons.tips_and_updates, AppColors.yellow),
          const SizedBox(height: 10),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tipIcons[tip.key] ?? Icons.lightbulb,
                      size: 19, color: tipColors[tip.key] ?? AppColors.yellow),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tipText(tip),
                      style: TextStyle(
                          color: context.bodyText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.8,
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _tipText(TutorTip tip) {
    // Strip the engine-only params (ids) from the display substitution.
    final params = <String, String>{...tip.params}
      ..remove('idA')
      ..remove('idB');
    return context.trF(tip.key, params);
  }
}
