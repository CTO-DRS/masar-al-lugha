// Path setup wizard (v4.11): the learner picks a field (PathDomain) and a
// level (LevelTier); the pure-Dart PathEngine derives the ordered unit plan
// and AppState stores it per course. Reached from the learn-path hero.
// v4.12: the level step is pre-filled from the placement-test result
// (lib/placement.dart → AppState.setPathTier) and refreshes when the
// learner returns from the test, so the two stay linked automatically.
import 'package:flutter/material.dart';

import '../path.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import 'placement_screen.dart';

class PathSetupScreen extends StatefulWidget {
  const PathSetupScreen({super.key});

  @override
  State<PathSetupScreen> createState() => _PathSetupScreenState();
}

class _PathSetupScreenState extends State<PathSetupScreen> {
  PathDomain? _domain;
  LevelTier? _tier;

  /// Guards the one-time seed of [_tier] from a stored placement result —
  /// afterwards the learner's manual pick in this session wins.
  bool _tierSeeded = false;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final course = st.course;

    // v4.12: seed the level once from a stored placement result (null-safe
    // — learners without a test simply see the manual picker as before).
    if (!_tierSeeded) {
      _tierSeeded = true;
      _tier ??= st.pathTierOf(st.courseId);
    }

    // Cheap per-course counts (56 units max) recomputed per frame.
    final unitsOfDomain = <PathDomain, int>{};
    final tierUnits = <LevelTier, int>{};
    if (_domain != null) {
      final domainUnitIdx = PathEngine.domainUnits(course, _domain!);
      for (final t in LevelTier.values) {
        tierUnits[t] = domainUnitIdx
            .where((i) => PathEngine.cefrInTier(course.units[i].cefr, t))
            .length;
      }
    }
    for (final d in PathDomain.values) {
      unitsOfDomain[d] = PathEngine.domainUnits(course, d).length;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('pathSetupTitle'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Center(
                    child: Mascot(
                      size: 84,
                      mood: _domain == null
                          ? MascotMood.happy
                          : MascotMood.celebrate,
                      characterId: st.mascotId,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('pathSetupIntro'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  _stepChip(context, 0, context.tr('pathDomainStep')),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      for (final d in PathDomain.values)
                        _domainCard(context, d, unitsOfDomain[d] ?? 0),
                    ],
                  ),
                  if (_domain != null) ...[
                    const SizedBox(height: 18),
                    _stepChip(context, 1, context.tr('pathLevelStep')),
                    const SizedBox(height: 10),
                    for (final t in LevelTier.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _tierCard(context, t, tierUnits[t] ?? 0),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        // v4.12: taking the test links its result to the
                        // level — when the learner comes back the tier
                        // step is already reflecting the detected level.
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PlacementScreen(),
                        ));
                        if (!mounted) return;
                        setState(() {
                          _tier = st.pathTierOf(st.courseId) ?? _tier;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(Icons.quiz, size: 17, color: context.mutedText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(context.tr('pathPlacementHint'),
                                style: TextStyle(
                                    color: context.mutedText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5)),
                          ),
                          Icon(Icons.chevron_right,
                              size: 17, color: context.mutedText),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: ChunkyButton(
                label: context.tr('pathStartPlan'),
                icon: Icons.alt_route,
                disabled: _tier == null,
                onPressed: _tier == null
                    ? null
                    : () {
                        st.setPathPlan(st.courseId, _domain!.name, _tier!.name);
                        Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepChip(BuildContext context, int n, String label) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }

  Widget _domainCard(BuildContext context, PathDomain d, int unitCount) {
    final selected = _domain == d;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _domain = d),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.12)
              : context.softBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.green : context.line,
            width: selected ? 2.5 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pathDomainEmoji(d), style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              context.tr(pathDomainL10nKey(d)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                color: selected ? AppColors.green : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.trF('pathDomainCount', {'u': '$unitCount'}),
              style: TextStyle(color: context.mutedText, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierCard(BuildContext context, LevelTier t, int unitCount) {
    final selected = _tier == t;
    final empty = unitCount == 0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: empty ? null : () => setState(() => _tier = t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.12)
              : context.softBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.green : context.line,
            width: selected ? 2.5 : 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(pathTierL10nKey(t)),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: empty ? context.mutedText : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(pathTierSubL10nKey(t)),
                    style: TextStyle(color: context.mutedText, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Text(
              context.trF('pathDomainCount', {'u': '$unitCount'}),
              style: TextStyle(
                color: empty ? context.mutedText : AppColors.green,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.green : context.mutedText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
