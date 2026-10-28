// Conversation trainer screen (v5.9, Phase 4 skill 4): a role-play chat UI
// over `ConversationProvider`. The shipped provider is on-device and
// offline (OfflineScriptedProvider); any future AI provider implements the
// same interface — wiring it is a separate, explicit decision because it
// would touch the "no network in release" invariant.
import 'package:flutter/material.dart';

import '../conversation.dart';
import '../scope.dart';
import '../theme.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late ConversationScenario _scenario;
  int _stepIndex = 0;
  bool _complete = false;
  bool _waitingReply = false;
  bool _xpAwarded = false; // v5.18 (Batch D2): once-per-visit completion XP
  final List<ConversationMsg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ConversationProvider _provider = const OfflineScriptedProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scenario =
          ConversationCatalog.forCourse(AppScope.of(context).courseId).first;
      _restart();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      _stepIndex = 0;
      _complete = false;
      _waitingReply = false;
      _messages
        ..clear()
        ..add(ConversationMsg.partner(_scenario.steps.first.partner,
            textAr: _scenario.steps.first.partnerAr));
    });
  }

  void _selectScenario(ConversationScenario s) {
    setState(() {
      _scenario = s;
      _restart();
    });
    Navigator.of(context).pop();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _waitingReply || _complete) return;
    setState(() {
      _messages.add(ConversationMsg.user(trimmed));
      _waitingReply = true;
    });
    _input.clear();
    _scrollDown();
    final result = await _provider.reply(_scenario, _stepIndex, trimmed);
    if (!mounted) return;
    setState(() {
      _messages.add(ConversationMsg.partner(result.partnerText,
          textAr: result.partnerTextAr));
      if (result.accepted) _stepIndex += 1;
      _complete = result.scenarioComplete;
      _waitingReply = false;
    });
    if (!result.accepted) {
      // v5.18 (Batch D2): explicit corrective feedback — the reply did not
      // carry the step's target structure. Honest, immediate, retryable.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('conversationTryAgain')),
        duration: const Duration(seconds: 3),
      ));
    } else if (_complete && !_xpAwarded) {
      // v5.18 (Batch D2): scenario completion earns XP exactly ONCE per
      // screen visit — the guard makes restart-farming and rebuilds
      // incapable of inflating it.
      _xpAwarded = true;
      AppScope.of(context).addXp(5);
    }
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// v5.18 (Batch D2): hear a practiced keyword in the target language.
  Future<void> _speak(String text) async {
    final st = AppScope.of(context);
    final tts = AppScope.ttsOf(context);
    await tts.setLanguage(st.course.ttsLang);
    await tts.speak(text);
  }

  void _showHint() {
    if (_complete || _stepIndex >= _scenario.steps.length) return;
    final step = _scenario.steps[_stepIndex];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sheetCtx.tr('conversationHint'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 10),
              Text(step.sampleReply,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(step.sampleReplyAr,
                  style: TextStyle(
                      color: Theme.of(sheetCtx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    final scenarios =
        ConversationCatalog.forCourse(AppScope.of(context).courseId);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('conversationTitle')),
        actions: [
          IconButton(
            tooltip: tr('conversationRestart'),
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _restart,
          ),
        ],
      ),
      body: Column(
        children: [
          // scenario picker
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final s in scenarios)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${s.emoji} ${s.titleAr}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      selected: s.id == _scenario.id,
                      onSelected: (_) => _selectScenario(s),
                    ),
                  ),
              ],
            ),
          ),
          // provider + honesty badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Icon(Icons.offline_bolt, size: 14, color: AppColors.green),
                const SizedBox(width: 6),
                Text(tr(_provider.labelKey),
                    style: TextStyle(
                        color: context.mutedText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                      '${tr('conversationStep')} ${_complete ? _scenario.steps.length : _stepIndex + 1}/${_scenario.steps.length}',
                      style: TextStyle(
                          color: context.mutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          // v5.18 (Batch D2): the scenario's learning objective, derived
          // from its own role — who the learner is role-playing with.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Row(
              children: [
                Icon(Icons.flag, size: 14, color: AppColors.purple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      tr('conversationGoal')
                          .replaceFirst('{r}', _scenario.roleAr),
                      style: TextStyle(
                          color: context.mutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.line),
          // chat
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length + (_complete ? 1 : 0),
              itemBuilder: (context, i) {
                if (_complete && i == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        // v5.18 (Batch D2): a completion summary of what was
                        // ACTUALLY practised — the scenario's own target
                        // keywords, tappable to hear them.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.green, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(tr('conversationSummaryTitle'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final k in _scenario.practicedKeywords)
                                    GestureDetector(
                                      onTap: () => _speak(k),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.green
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(k,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(tr('conversationXpNote'),
                                  style: TextStyle(
                                      color: context.mutedText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _restart,
                          icon: const Icon(Icons.replay, size: 18),
                          label: Text(tr('conversationRestart')),
                        ),
                      ],
                    ),
                  );
                }
                final m = _messages[i];
                return Align(
                  alignment: m.fromPartner
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: m.fromPartner ? context.card : AppColors.green,
                      borderRadius: BorderRadiusDirectional.only(
                        topStart: const Radius.circular(16),
                        topEnd: const Radius.circular(16),
                        bottomStart: Radius.circular(m.fromPartner ? 4 : 16),
                        bottomEnd: Radius.circular(m.fromPartner ? 16 : 4),
                      ),
                      border: m.fromPartner
                          ? Border.all(color: context.line, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          // v4.13.1 seam: the line reads in its OWN script
                          // direction (Latin replies LTR, Urdu/Arabic RTL).
                          textDirection: directionOf(m.text),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: m.fromPartner ? null : Colors.white,
                            ),
                          ),
                        ),
                        if (m.textAr != null) ...[
                          const SizedBox(height: 3),
                          Text(m.textAr!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: m.fromPartner
                                      ? context.mutedText
                                      : Colors.white.withValues(alpha: 0.9))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: context.line),
          // input row
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: tr('conversationHint'),
                    icon: const Icon(Icons.lightbulb_outline, size: 22),
                    color: AppColors.orange,
                    onPressed: _complete ? null : _showHint,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: _waitingReply || _complete ? null : _send,
                      decoration: InputDecoration(
                        hintText: tr('conversationTypePlaceholder'),
                        filled: true,
                        fillColor: context.softBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: context.line, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: context.line, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              BorderSide(color: AppColors.green, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: (_waitingReply || _complete)
                        ? null
                        : () => _send(_input.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_waitingReply || _complete)
                            ? context.line
                            : AppColors.green,
                      ),
                      child:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
