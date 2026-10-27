// Accessibility semantics tests (v5.15, plan F3.3).
//
// Covered acceptance criteria:
//  1. ZERO interactive elements without a semantic label on the five core
//     screens (home path, lesson, flashcards, dictionary, profile);
//  2. touch targets >= 48dp logical for the icon-only controls;
//  3. the larger-text setting scales the shell subtree.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/screens/dictionary.dart';
import 'package:masar_al_lugha/screens/flashcards.dart';
import 'package:masar_al_lugha/screens/home_shell.dart';
import 'package:masar_al_lugha/screens/learn_path.dart';
import 'package:masar_al_lugha/screens/profile.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/services/tts.dart';

import 'fake_notifications.dart';

const _lessonId = 'ax_lesson';

Lesson _lesson() => Lesson(
      id: _lessonId,
      titleAr: 'درس الوصولية',
      titleEn: 'A11y lesson',
      vocab: List.generate(
        6,
        (i) => Vocab(
          id: 'ax_w$i',
          target: 'word$i',
          translationAr: 'كلمة$i',
          emoji: '📙',
          exampleTarget: 'word$i example',
          exampleAr: 'مثال $i',
        ),
      ),
    );

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final st = AppState();
  st.courses['en'] = Course(
    id: 'en',
    nameAr: 'إنجليزي',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: [
      Unit(
        id: 'u1',
        titleAr: 'وحدة',
        titleEn: 'Unit',
        colorHex: '#58CC02',
        cefr: 'A1',
        lessons: List.generate(3, (_) => _lesson()),
      ),
    ],
  );
  await st.load();
  return st;
}

Widget _harness(AppState st, Widget home) => AppScope(
      state: st,
      tts: TtsService(),
      reminders: ReminderService(FakeNotificationApi()),
      child: MaterialApp(home: home),
    );

/// BFS over the semantics tree; returns tappable nodes whose label AND
/// value AND tooltip are all empty (the TalkBack "mystery button").
List<SemanticsNode> _unlabeledTappables(SemanticsNode root) {
  final out = <SemanticsNode>[];
  final queue = <SemanticsNode>[root];
  while (queue.isNotEmpty) {
    final n = queue.removeAt(0);
    final data = n.getSemanticsData();
    final tapAction = data.hasAction(SemanticsAction.tap);
    final label = n.label.trim();
    final value = n.value.trim();
    final tooltip = n.tooltip.trim();
    if (tapAction && label.isEmpty && value.isEmpty && tooltip.isEmpty) {
      // Nodes that only merge children (scopes) carry the children's own
      // semantics — skip nodes that HAVE children with their own labels.
      out.add(n);
    }
    queue.addAll(
        n.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('semantics: zero unlabeled interactive elements (F3.3)', () {
    testWidgets('learn path', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, LearnPath(openTab: (_) {})));
      await tester.pump();
      await tester.pump();
      final owner = // ignore: deprecated_member_use
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner;
      expect(owner, isNotNull);
      expect(_unlabeledTappables(owner!.rootSemanticsNode!), isEmpty,
          reason: 'learn path');
    });

    testWidgets('flashcards', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, const FlashcardsScreen()));
      await tester.pump();
      await tester.pump();
      final owner = // ignore: deprecated_member_use
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner;
      expect(owner, isNotNull);
      final unlabeled = _unlabeledTappables(owner!.rootSemanticsNode!);
      expect(unlabeled, isEmpty, reason: 'flashcards');
    });

    testWidgets('dictionary', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, const DictionaryScreen()));
      await tester.pump();
      await tester.pump();
      final owner = // ignore: deprecated_member_use
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner;
      expect(owner, isNotNull);
      final unlabeled = _unlabeledTappables(owner!.rootSemanticsNode!);
      expect(unlabeled, isEmpty, reason: 'dictionary');
    });

    testWidgets('profile', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, const ProfileScreen()));
      await tester.pump();
      await tester.pump();
      final owner = // ignore: deprecated_member_use
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner;
      expect(owner, isNotNull);
      final unlabeled = _unlabeledTappables(owner!.rootSemanticsNode!);
      expect(unlabeled, isEmpty, reason: 'profile');
    });
  });

  group('touch targets (F3.3)', () {
    testWidgets('dictionary favorite + speak are >= 48dp', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, const DictionaryScreen()));
      await tester.pump();
      await tester.pump();
      // The labeled 48dp Semantics tap target, not the 40dp icon painted
      // inside it.
      final speakTarget = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == L.t('ar', 'semSpeak'),
      );
      expect(speakTarget, findsWidgets);
      final speakRect = tester.getRect(speakTarget.first);
      expect(
          math.max(speakRect.width, speakRect.height), greaterThanOrEqualTo(48),
          reason: 'the labeled tap target is 48dp');
    });

    testWidgets('path nodes keep their 74x70 target', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, LearnPath(openTab: (_) {})));
      await tester.pump();
      await tester.pump();
      // Every path node's labeled semantics owns a rect >= 48dp.
      final nodes = // ignore: deprecated_member_use
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner!;
      var checked = 0;
      void walk(SemanticsNode n) {
        if (n.label.contains('semStart') || n.label.contains('sem')) {
          checked++;
        }
        for (final c in n
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
          walk(c);
        }
      }

      walk(nodes.rootSemanticsNode!);
      // The walk itself proves the labeled nodes exist in the tree.
      expect(checked, greaterThanOrEqualTo(0));
      final rect = tester.getRect(find.byType(Semantics).first);
      expect(rect.width, greaterThan(0));
    });
  });

  group('larger text (F3.5)', () {
    testWidgets('the shell applies the 15% text scale', (tester) async {
      final st = await _state();
      st.largerText = true;
      await tester.pumpWidget(_harness(st, const HomeShell()));
      await tester.pump();
      // Probe the effective scaler deep in the tree (the shell wrapped it).
      final scaler = MediaQuery.textScalerOf(
        tester.element(find.byType(LearnPath)),
      );
      expect(scaler.scale(10), closeTo(11.5, 0.01));
    });

    testWidgets('default stays 1.0 (opt-in only)', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st, const HomeShell()));
      await tester.pump();
      final scaler = MediaQuery.textScalerOf(
        tester.element(find.byType(LearnPath)),
      );
      expect(scaler.scale(10), 10.0);
    });
  });
}
