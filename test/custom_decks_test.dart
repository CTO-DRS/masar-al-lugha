// v4.7 custom word lists: CRUD + bounds + id stability + persistence.
// The deck engine (lib/decks.dart) is Flutter-free; the state layer is
// exercised through the same profile round-trip used by storage_test.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/decks.dart';

Future<AppState> _freshState() async {
  SharedPreferences.setMockInitialValues({});
  final st = AppState();
  await st.load();
  return st;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('deck engine (lib/decks.dart)', () {
    test('name/word validation trims and bounds', () {
      expect(DeckLimits.cleanName('  My words '), 'My words');
      expect(DeckLimits.cleanName('   '), isNull);
      expect(DeckLimits.cleanName('x' * 41), isNull);
      expect(DeckLimits.cleanWord('y' * 61), isNull);
      expect(DeckLimits.cleanWord('  hi  '), 'hi');
    });

    test('dupKey folds case and punctuation only', () {
      expect(
          DeckLimits.dupKey('Hello, World!'), DeckLimits.dupKey('hello world'));
      // Diacritics are content for user decks — only punct/case fold.
      expect(DeckLimits.dupKey('مَدْرَسَة'), isNot(DeckLimits.dupKey('مدرسة')));
    });

    test('fromJson rejects tampered deck shapes', () {
      // Bad id shape — must never collide with course ids (en_/fr_/ur_).
      expect(
          CustomDeck.fromJson({
            'id': 'en_u1',
            'name': 'x',
            'courseId': 'en',
            'words': [],
          }),
          isNull);
      expect(
          CustomDeck.fromJson({
            'id': 'cdX',
            'name': 'x',
            'courseId': 'en',
          }),
          isNull);
      // Bad course.
      expect(
          CustomDeck.fromJson({
            'id': 'cd1',
            'name': 'x',
            'courseId': 'xx',
          }),
          isNull);
      // Words with foreign id prefixes are dropped, the deck survives with
      // its legitimately-prefixed words.
      final d = CustomDeck.fromJson({
        'id': 'cd1',
        'name': 'ok',
        'courseId': 'en',
        'next': 5,
        'words': [
          {'id': 'cd1_w1', 'target': 'cat', 'translationAr': 'قط'},
          {'id': 'en_cat', 'target': 'dog', 'translationAr': 'كلب'},
          {'id': 'cd2_w1', 'target': 'bird', 'translationAr': 'طائر'},
          {'id': 'cd1_w2', 'target': 'mouse', 'translationAr': 'فأر'},
        ],
      })!;
      expect(d.words.map((w) => w.id), ['cd1_w1', 'cd1_w2']);
      expect(d.words.first.target, 'cat');
      expect(d.nextSeq, 5); // stored counter wins over max seen
    });

    test('from->to->from round-trips losslessly', () {
      const original = CustomDeck(
        id: 'cd7',
        name: 'قائمة الطعام',
        courseId: 'fr',
        nextSeq: 3,
        words: [
          CustomWord(id: 'cd7_w1', target: 'pain', translationAr: 'خبز'),
          CustomWord(
              id: 'cd7_w2',
              target: 'fromage',
              translationAr: 'جبن',
              exampleTarget: 'Le fromage est bon.',
              exampleAr: 'الجبن لذيذ.'),
        ],
      );
      final parsed = CustomDeck.fromJson(original.toJson())!;
      expect(parsed.id, original.id);
      expect(parsed.name, original.name);
      expect(parsed.courseId, original.courseId);
      expect(parsed.nextSeq, original.nextSeq);
      expect(parsed.words.length, 2);
      expect(parsed.words[1].exampleTarget, 'Le fromage est bon.');
    });
  });

  group('AppState custom-deck CRUD', () {
    test('create, add, duplicate-guard, remove, delete', () async {
      final st = await _freshState();
      st.courseId = 'en';

      final deck = st.createCustomDeck('  Exam prep  ')!;
      expect(deck.name, 'Exam prep');
      expect(deck.courseId, 'en');
      expect(deck.id, startsWith('cd'));

      expect(st.addCustomWord(deck.id, 'Cat', 'قط'), isNull);
      expect(st.addCustomWord(deck.id, ' cat ', 'كلب'), 'dupWord');
      expect(st.addCustomWord(deck.id, '', 'فارغ'), 'invalidWord');
      expect(st.addCustomWord(deck.id, 'Dog', ''), 'invalidWord');

      final reloaded = st.deckById(deck.id)!;
      expect(reloaded.words.length, 1);
      expect(reloaded.words.first.target, 'Cat');
      expect(reloaded.words.first.id, '${deck.id}_w1');

      // Ids stay stable across removals (monotonic counter).
      expect(st.addCustomWord(deck.id, 'Dog', 'كلب'), isNull);
      st.removeCustomWord(deck.id, '${deck.id}_w1');
      expect(st.addCustomWord(deck.id, 'Bird', 'طائر'), isNull);
      final after = st.deckById(deck.id)!;
      expect(after.words.map((w) => w.id), ['${deck.id}_w2', '${deck.id}_w3']);

      expect(st.deleteCustomDeck(deck.id), isTrue);
      expect(st.deckById(deck.id), isNull);
      expect(st.deleteCustomDeck(deck.id), isFalse);
    });

    test('deck budget (12) is enforced', () async {
      final st = await _freshState();
      for (var i = 0; i < DeckLimits.maxDecks; i++) {
        expect(st.createCustomDeck('deck $i'), isNotNull);
      }
      expect(st.createCustomDeck('one too many'), isNull);
    });

    test('word budget (200) is enforced', () async {
      final st = await _freshState();
      final deck = st.createCustomDeck('big')!;
      for (var i = 0; i < CustomDeck.maxWords; i++) {
        expect(st.addCustomWord(deck.id, 'word $i', 'معنى'), isNull);
      }
      expect(st.addCustomWord(deck.id, 'one more', 'معنى'), 'listFull');
      expect(st.deckById(deck.id)!.words.length, CustomDeck.maxWords);
    });

    test('resetAll clears decks and the counter restarts', () async {
      final st = await _freshState();
      st.createCustomDeck('first');
      await st.resetAll();
      expect(st.customDecks, isEmpty);
      final d = st.createCustomDeck('again')!;
      expect(d.id, 'cd1');
    });
  });

  group('persistence & export/import', () {
    test('decks survive save -> load', () async {
      final st = await _freshState();
      final deck = st.createCustomDeck('travel')!;
      st.addCustomWord(deck.id, 'passport', 'جواز سفر');
      await st.save();

      final st2 = AppState();
      await st2.load();
      final d2 = st2.deckById(deck.id);
      expect(d2, isNotNull);
      expect(d2!.name, 'travel');
      expect(d2.words.single.target, 'passport');
    });

    test('export carries decks; import restores them; tampered drop', () async {
      final st = await _freshState();
      final deck = st.createCustomDeck('work')!;
      st.addCustomWord(deck.id, 'meeting', 'اجتماع');
      final raw = st.exportProfileJson();

      final st2 = await _freshState();
      expect(await st2.importProfileJson(raw), isNull);
      expect(st2.deckById(deck.id)!.words.single.target, 'meeting');

      // Tampered payload: an invalid course-shaped deck id is dropped,
      // the legitimate deck survives.
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final progress = Map<String, dynamic>.from(decoded['progress'] as Map);
      progress['decks'] = [
        ...(progress['decks'] as List),
        {
          'id': 'en_u1',
          'name': 'evil',
          'courseId': 'en',
          'words': [
            {'id': 'en_u1_w1', 'target': 'x', 'translationAr': 'y'},
          ],
        },
      ];
      decoded['progress'] = progress;
      final st3 = await _freshState();
      expect(await st3.importProfileJson(jsonEncode(decoded)), isNull);
      expect(st3.customDecks.any((d) => d.id == 'en_u1'), isFalse);
      expect(st3.deckById(deck.id), isNotNull);
    });
  });
}
