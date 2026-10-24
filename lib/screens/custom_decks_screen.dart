// v4.7 — custom word lists ("قوائمي"): user-authored decks stored in the
// schema-v2 profile. Three surfaces in one file:
//   CustomDecksScreen — deck list for the current course + create
//   CustomDeckScreen  — deck detail: add/remove words, launch practice
//   DeckPracticeScreen — flip-card drill over the deck (tap to flip,
//     prev/next, shuffle, tap-to-hear via TTS)
// Offline-only: decks ride the existing profile persistence (decks key).
import 'package:flutter/material.dart';

import '../decks.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';

class CustomDecksScreen extends StatelessWidget {
  const CustomDecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final decks = st.customDecks.where((d) => d.courseId == st.courseId);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Mascot(size: 44, mood: MascotMood.happy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('myLists'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(tr('myListsHint'),
                    style: TextStyle(color: context.mutedText, fontSize: 14)),
              ),
            ),
            Expanded(
              child: decks.isEmpty
                  ? _emptyState(context, tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      children: [
                        for (final d in decks) _deckCard(context, tr, d),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ChunkyButton(
                  label: tr('createList'),
                  icon: Icons.add,
                  onPressed: () => _createDialog(context, tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String Function(String) tr) {
    final st = AppScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(size: 96, mood: MascotMood.neutral),
            const SizedBox(height: 14),
            Text(tr('noListsYet'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            MascotBubble(
              characterId: st.mascotId,
              mood: MascotMood.happy,
              text: tr('myListsHint'),
              showAvatar: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deckCard(
      BuildContext context, String Function(String) tr, CustomDeck d) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CustomDeckScreen(deckId: d.id),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.line, width: 2),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.style, color: AppColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(
                    context.trF('wordCount', {'n': '${d.words.length}'}),
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: context.mutedText, textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
  }

  void _createDialog(BuildContext context, String Function(String) tr) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('createList'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: tr('listNameHint'),
            filled: true,
            fillColor: context.softBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.line),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel'),
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () {
              final st = AppScope.of(context);
              final deck = st.createCustomDeck(ctl.text);
              Navigator.pop(ctx);
              if (deck != null) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CustomDeckScreen(deckId: deck.id),
                ));
              }
            },
            child: Text(tr('create'),
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// ---------------- deck detail ----------------

class CustomDeckScreen extends StatefulWidget {
  final String deckId;
  const CustomDeckScreen({super.key, required this.deckId});

  @override
  State<CustomDeckScreen> createState() => _CustomDeckScreenState();
}

class _CustomDeckScreenState extends State<CustomDeckScreen> {
  final _targetCtl = TextEditingController();
  final _meaningCtl = TextEditingController();
  String? _error; // l10n key from addCustomWord

  @override
  void dispose() {
    _targetCtl.dispose();
    _meaningCtl.dispose();
    super.dispose();
  }

  void _addWord(String Function(String) tr) {
    final st = AppScope.of(context);
    setState(() {
      _error =
          st.addCustomWord(widget.deckId, _targetCtl.text, _meaningCtl.text);
    });
    if (_error == null) {
      _targetCtl.clear();
      _meaningCtl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _confirmDelete(String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('deleteList'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(tr('deleteListBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('stay'),
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppScope.of(context).deleteCustomDeck(widget.deckId);
              Navigator.of(context).pop(); // back to the deck list
            },
            child: Text(tr('delete'),
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final deck = st.deckById(widget.deckId);
    if (deck == null) {
      // Deleted while open — leave gracefully.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deck.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _confirmDelete(tr),
                    child: const Icon(Icons.delete_outline,
                        size: 26, color: AppColors.red),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ChunkyButton(
                  label: tr('practiceList'),
                  icon: Icons.play_arrow,
                  color: AppColors.blue,
                  colorDark: AppColors.blueDark,
                  disabled: deck.words.isEmpty,
                  onPressed: deck.words.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                DeckPracticeScreen(deckId: widget.deckId),
                          ));
                        },
                ),
              ),
            ),
            _addForm(tr),
            Expanded(
              child: deck.words.isEmpty
                  ? Center(
                      child: Text(tr('emptyList'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: context.mutedText, fontSize: 15)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      children: [
                        for (final w in deck.words) _wordRow(tr, w),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addForm(String Function(String) tr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.line, width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetCtl,
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: tr('wordHint'),
                      filled: true,
                      fillColor: context.softBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.blue, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _meaningCtl,
                    maxLength: 80,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: tr('meaningHint'),
                      filled: true,
                      fillColor: context.softBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.blue, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addWord(tr),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: AppColors.greenDark,
                            offset: Offset(0, 3),
                            blurRadius: 0),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(tr(_error!),
                      style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wordRow(String Function(String) tr, CustomWord w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.line, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.target,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(w.translationAr,
                    style: TextStyle(color: context.mutedText, fontSize: 14)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final st = AppScope.of(context);
              final tts = AppScope.ttsOf(context);
              tts
                  .setLanguage(st.course.ttsLang)
                  .then((_) => tts.speak(w.target));
            },
            child: const Icon(Icons.volume_up, color: AppColors.blue, size: 24),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () =>
                AppScope.of(context).removeCustomWord(widget.deckId, w.id),
            child: const Icon(Icons.close, color: AppColors.red, size: 22),
          ),
        ],
      ),
    );
  }
}

// ---------------- flip-card practice ----------------

class DeckPracticeScreen extends StatefulWidget {
  final String deckId;
  const DeckPracticeScreen({super.key, required this.deckId});

  @override
  State<DeckPracticeScreen> createState() => _DeckPracticeScreenState();
}

class _DeckPracticeScreenState extends State<DeckPracticeScreen> {
  List<CustomWord> _words = [];
  int _i = 0;
  bool _flipped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words.isEmpty) {
      final st = AppScope.of(context);
      final deck = st.deckById(widget.deckId);
      _words = deck?.words.toList() ?? [];
    }
  }

  void _next() {
    if (_i >= _words.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _i++;
      _flipped = false;
    });
  }

  void _prev() {
    if (_i == 0) return;
    setState(() {
      _i--;
      _flipped = false;
    });
  }

  void _shuffle() {
    setState(() {
      _words.shuffle();
      _i = 0;
      _flipped = false;
    });
  }

  void _speak() {
    final st = AppScope.of(context);
    final tts = AppScope.ttsOf(context);
    tts
        .setLanguage(st.course.ttsLang)
        .then((_) => tts.speak(_words[_i].target));
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    if (_words.isEmpty) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final w = _words[_i];
    final done = _i >= _words.length - 1;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child:
                        const Icon(Icons.close, size: 26, color: AppColors.ink),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (_i + 1) / _words.length,
                        minHeight: 12,
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.green),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _shuffle,
                    child: const Icon(Icons.shuffle,
                        size: 24, color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                  context.trF('wordCount', {'n': '${_i + 1}/${_words.length}'}),
                  style: TextStyle(
                      color: context.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: Container(
                  width: double.infinity,
                  height: 260,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: context.line, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: context.line,
                          offset: const Offset(0, 5),
                          blurRadius: 0),
                    ],
                  ),
                  child: Center(
                    child: !_flipped
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _speak,
                                child: const Icon(Icons.volume_up,
                                    color: AppColors.blue, size: 30),
                              ),
                              const SizedBox(height: 10),
                              Text(w.target,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 10),
                              Text(tr('tapToFlip'),
                                  style: TextStyle(
                                      color: context.mutedText, fontSize: 13)),
                            ],
                          )
                        : Text(w.translationAr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      label: tr('backWord'),
                      color: context.mutedText,
                      colorDark: AppColors.inkLight,
                      disabled: _i == 0,
                      onPressed: _prev,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChunkyButton(
                      label: done ? tr('done') : tr('nextWord'),
                      color: AppColors.green,
                      colorDark: AppColors.greenDark,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
