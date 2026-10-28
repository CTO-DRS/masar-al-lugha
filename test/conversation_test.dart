// Conversation catalog + scripted provider tests (v5.9): integrity,
// deterministic keyword matching, step advance and completion. The
// provider abstraction itself is the seam for any future AI provider.
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/conversation.dart';

void main() {
  test('catalog verifies: unique ids, real courses, well-formed steps', () {
    expect(ConversationCatalog.verify(), isTrue);
  });

  test('every course has at least one starter scenario', () {
    for (final c in ['en', 'de', 'fr', 'ur']) {
      final s = ConversationCatalog.forCourse(c);
      expect(s.length, greaterThanOrEqualTo(1), reason: c);
      expect(s.every((x) => x.courseId == c), isTrue, reason: c);
    }
  });

  test('scenarios carry 3+ steps with sample replies and accept groups', () {
    for (final s in ConversationCatalog.scenarios) {
      expect(s.steps.length, greaterThanOrEqualTo(3), reason: s.id);
      for (final st in s.steps) {
        expect(st.sampleReply.trim().isNotEmpty, isTrue, reason: s.id);
        expect(st.acceptAny.isNotEmpty, isTrue, reason: s.id);
        for (final g in st.acceptAny) {
          expect(g.isNotEmpty, isTrue, reason: s.id);
        }
      }
    }
  });

  test('normalize strips punctuation and case', () {
    expect(ConversationTrainer.normalize('Hello, WORLD!'), 'hello world');
    expect(ConversationTrainer.normalize('مَرْحباً!'), 'مرحبا');
  });

  test('satisfies matches any-of groups (all keywords of one group)', () {
    const groups = [
      ['no', 'thanks'],
      ['tea'],
    ];
    expect(ConversationTrainer.satisfies(groups, 'No, thanks.'), isTrue);
    expect(ConversationTrainer.satisfies(groups, 'a cup of TEA.'), isTrue);
    expect(ConversationTrainer.satisfies(groups, 'just water'), isFalse);
    expect(ConversationTrainer.satisfies(groups, ''), isFalse);
    // matching is substring-based: 'nope' contains 'no' — choose a real
    // negative that misses at least one keyword of every group
    expect(ConversationTrainer.satisfies(groups, 'yes please'), isFalse);
  });

  test('scripted provider: accepted reply advances the dialogue', () async {
    const p = OfflineScriptedProvider();
    final s = ConversationCatalog.byId('cv_en_cafe')!;
    final r1 = await p.reply(s, 0, 'I would like a coffee, please.');
    expect(r1.accepted, isTrue);
    expect(r1.partnerText, s.steps[1].partner);
    expect(r1.scenarioComplete, isFalse);
  });

  test('scripted provider: wrong reply stays on the same step', () async {
    const p = OfflineScriptedProvider();
    final s = ConversationCatalog.byId('cv_en_cafe')!;
    final r = await p.reply(s, 0, 'blah blah');
    expect(r.accepted, isFalse);
    expect(r.partnerText, s.steps[0].partner);
    expect(r.scenarioComplete, isFalse);
  });

  test('scripted provider: last accepted step closes the scenario', () async {
    const p = OfflineScriptedProvider();
    final s = ConversationCatalog.byId('cv_en_cafe')!;
    final r =
        await p.reply(s, s.steps.length - 1, 'No, thank you. That is all.');
    expect(r.accepted, isTrue);
    expect(r.scenarioComplete, isTrue);
    expect(r.partnerText, s.closing);
  });

  test('scripted provider is deterministic (same input, same output)',
      () async {
    const p = OfflineScriptedProvider();
    final s = ConversationCatalog.byId('cv_de_baecker')!;
    final a = await p.reply(s, 0, 'Ich möchte zwei Brötchen, bitte.');
    final b = await p.reply(s, 0, 'Ich möchte zwei Brötchen, bitte.');
    expect(a.partnerText, b.partnerText);
    expect(a.accepted, b.accepted);
  });

  test('scenario ids are namespaced and byId is null-safe', () {
    for (final s in ConversationCatalog.scenarios) {
      expect(s.id.startsWith('cv_'), isTrue, reason: s.id);
    }
    expect(ConversationCatalog.byId('cv_en_cafe'), isNotNull);
    expect(ConversationCatalog.byId('en_apple'), isNull);
  });

  // ===== v5.18 (Phase-2 Batch D2): the practiced-keywords summary =====
  test('practicedKeywords exposes one primary target per step, in order', () {
    for (final s in ConversationCatalog.scenarios) {
      final keys = s.practicedKeywords;
      expect(keys.length, s.steps.length, reason: s.id);
      expect(keys.every((k) => k.trim().isNotEmpty), isTrue, reason: s.id);
      // The summary is real data: each keyword IS a member of its step's
      // first accept group (the primary target the provider checks).
      for (var i = 0; i < s.steps.length; i++) {
        expect(s.steps[i].acceptAny.first.contains(keys[i]), isTrue,
            reason: '${s.id} step $i');
      }
    }
  });
}
