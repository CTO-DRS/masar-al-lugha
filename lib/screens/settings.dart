// Settings: UI language, theme, motion, TTS, backup, reset, about.
// v4.0: dark mode + reduce motion + persisted TTS + profile export/import.
// v5.15 (plan F3.5): the settings screen reorganizes into FOUR titled
// sections — Profiles · Learning · Appearance & accessibility · Data &
// about — plus a local search field that filters sections by title. PURE
// display reorganization: no storage key changed, every existing widget
// and callback behaves exactly as before (the old tests stay green).
// New in this wave: simplified-audio and larger-text switches (F3.3).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../scope.dart';
import '../profile_store.dart';
import '../srs.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // v5.15 (F3.5): local settings search — filters the four sections by
  // their own titles and their items' labels. Display-only.
  String _query = '';

  bool _matches(
      String Function(String) tr, String sectionKey, List<String> itemKeys) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final haystacks = <String>[
      tr(sectionKey),
      for (final k in itemKeys) tr(k),
    ];
    return haystacks.any((h) => h.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final tts = AppScope.ttsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: tr('semSearchSettings'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.line, width: 2),
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 20),

          // ---- v5.15 (F3.5) section 1/4: PROFILES ----
          if (_matches(tr, 'setSectionProfiles', const [
            'profilesTitle',
            'profileSwitch',
            'profileRename',
          ])) ...[
            // v5.10: local multi-profile slots (up to 3 learners on this
            // device) — purely on-device, no accounts, no network.
            _sectionTitle(tr('setSectionProfiles')),
            const SizedBox(height: 4),
            Text(tr('profilesHint'),
                style: TextStyle(fontSize: 12.5, color: context.mutedText)),
            const SizedBox(height: 10),
            for (var slot = 1; slot <= ProfileStore.maxProfiles; slot++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: slot == st.profileSlot
                      ? AppColors.green.withValues(alpha: 0.10)
                      : context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: slot == st.profileSlot
                          ? AppColors.green.withValues(alpha: 0.5)
                          : context.line,
                      width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      slot == 1 ? Icons.person : Icons.person_outline,
                      size: 20,
                      color: slot == st.profileSlot
                          ? AppColors.green
                          : context.mutedText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        st.profileNames[slot] ??
                            '${tr('profileDefault')} $slot',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: slot == st.profileSlot
                              ? AppColors.green
                              : context.bodyText,
                        ),
                      ),
                    ),
                    if (slot == st.profileSlot)
                      Text(tr('profileCurrent'),
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.greenText))
                    else
                      TextButton(
                        onPressed: () => setState(() => st.switchProfile(slot)),
                        child: Text(tr('profileSwitch'),
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w900)),
                      ),
                    IconButton(
                      tooltip: tr('profileRename'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.edit,
                          size: 16,
                          color: slot == st.profileSlot
                              ? AppColors.green
                              : context.mutedText),
                      onPressed: () => _renameProfile(context, st, slot, tr),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
          ],

          // ---- v5.15 (F3.5) section 2/4: LEARNING ----
          if (_matches(tr, 'setSectionLearning', const [
            'retentionTitle',
            'reminderSection',
            'reminderEnable',
          ])) ...[
            _sectionTitle(tr('setSectionLearning')),
            const SizedBox(height: 12),
            // v5.3: FSRS target-retention dial — lower = longer intervals.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(tr('retentionTitle'),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.bodyText)),
                    ),
                    Text(
                      '${(st.retentionTarget * 100).round()}%',
                      style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Text(tr('retentionHint'),
                    style: TextStyle(fontSize: 12.5, color: context.mutedText)),
                Slider(
                  value: st.retentionTarget
                      .clamp(Srs.minRetention, Srs.maxRetention),
                  min: Srs.minRetention,
                  max: Srs.maxRetention,
                  divisions: 7,
                  label: '${(st.retentionTarget * 100).round()}%',
                  onChanged: (v) => setState(() => st.setRetentionTarget(v)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // v5.12 (F2.5): local daily practice reminder — on-device only,
            // re-anchored on every app launch, never any network.
            Text(tr('reminderSection'),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: context.bodyText)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.line, width: 2),
              ),
              child: Material(
                // v5.15: the ListTiles must paint on their OWN Material —
                // the decorated container would hide their ink otherwise
                // (a debug-assert the new IA tests caught).
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: st.reminders.enabled,
                      onChanged: (v) => _toggleReminder(v, tr),
                      activeThumbColor: AppColors.green,
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('reminderEnable'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    if (st.reminders.enabled)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.schedule, size: 20),
                        title: Text(tr('reminderTime'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        trailing: Text(
                          '${st.reminders.hour.toString().padLeft(2, '0')}:${st.reminders.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        onTap: () => _pickReminderTime(tr),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('reminderRebootNote'),
              style: TextStyle(
                  fontSize: 11.5, color: context.mutedText, height: 1.4),
            ),
            const SizedBox(height: 28),
          ],

          // ---- v5.15 (F3.5) section 3/4: APPEARANCE & ACCESSIBILITY ----
          if (_matches(tr, 'setSectionAppearance', const [
            'uiLanguage',
            'darkMode',
            'reduceMotion',
            'ttsSound',
            'ttsRate',
            'simplifiedAudio',
            'largerText',
          ])) ...[
            _sectionTitle(tr('setSectionAppearance')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _choice(
                    label: tr('arabic'),
                    selected: st.uiLocale == 'ar',
                    onTap: () => setState(() => st.setLocale('ar')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choice(
                    label: tr('english'),
                    selected: st.uiLocale == 'en',
                    onTap: () => setState(() => st.setLocale('en')),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('darkMode'),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.bodyText)),
              value: st.darkMode,
              onChanged: (v) => setState(() => st.setDarkMode(v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('reduceMotion'),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.bodyText)),
              value: st.reduceMotion,
              onChanged: (v) => setState(() => st.setReduceMotion(v)),
            ),
            // v5.15 (F3.3): speaks the result after every answer.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('simplifiedAudio'),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.bodyText)),
              subtitle: Text(tr('simplifiedAudioHint'),
                  style: TextStyle(fontSize: 12, color: context.mutedText)),
              value: st.simplifiedAudio,
              onChanged: (v) => setState(() => st.setSimplifiedAudio(v)),
            ),
            // v5.15 (F3.5): scales the interface text by 15%.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('largerText'),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.bodyText)),
              subtitle: Text(tr('largerTextHint'),
                  style: TextStyle(fontSize: 12, color: context.mutedText)),
              value: st.largerText,
              onChanged: (v) => setState(() => st.setLargerText(v)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('ttsSound'),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.bodyText)),
              value: st.ttsEnabled,
              onChanged: (v) {
                // v4.0: persisted (audit M2) — service + state stay in sync.
                tts.enabled = v;
                setState(() => st.setTtsEnabled(v));
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr('ttsRate'),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.bodyText)),
                    Text(
                      '${st.ttsRate.toStringAsFixed(1)}x',
                      style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Slider(
                  value: st.ttsRate.clamp(0.5, 1.2),
                  min: 0.5,
                  max: 1.2,
                  divisions: 7,
                  label: '${st.ttsRate.toStringAsFixed(1)}x',
                  onChanged: (v) {
                    tts.rate = v;
                    setState(() => st.setTtsRate(v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],

          // ---- v5.15 (F3.5) section 4/4: DATA & ABOUT ----
          if (_matches(tr, 'setSectionData', const [
            'backupRestore',
            'exportProfile',
            'importProfile',
            'resetProgress',
            'about',
          ])) ...[
            _sectionTitle(tr('setSectionData')),
            const SizedBox(height: 12),
            Text(tr('backupRestore'),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: context.bodyText)),
            const SizedBox(height: 10),
            ChunkyButton(
              label: tr('exportProfile'),
              color: AppColors.blue,
              colorDark: AppColors.blueDark,
              icon: Icons.ios_share,
              height: 46,
              onPressed: _exportProfile,
            ),
            const SizedBox(height: 10),
            ChunkyButton(
              label: tr('importProfile'),
              color: AppColors.purple,
              colorDark: AppColors.purple,
              icon: Icons.download,
              height: 46,
              onPressed: _importProfile,
            ),
            const SizedBox(height: 24),
            _sectionTitle(tr('resetProgress')),
            const SizedBox(height: 10),
            ChunkyButton(
              label: tr('resetProgress'),
              color: AppColors.red,
              colorDark: AppColors.redDark,
              icon: Icons.delete_forever,
              onPressed: () => _confirmReset(tr),
            ),
            const SizedBox(height: 28),
            // About
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.softBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.line, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.blueText, size: 22),
                      const SizedBox(width: 8),
                      Text(tr('about'),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: context.bodyText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('aboutBody'),
                    style: TextStyle(
                        color: context.mutedText, fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('aboutEngine'),
                    style: TextStyle(
                        color: context.mutedText, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${tr('version')} • ${tr('openSource')}',
                    style: const TextStyle(
                        color: AppColors.greenText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: context.bodyText,
        ),
      );

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48, // a11y: minimum touch target
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blueLight : context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : context.line,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.blue : context.mutedText,
          ),
        ),
      ),
    );
  }

  // ---------- v4.0 backup / restore ----------

  Future<void> _exportProfile() async {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final json = st.exportProfileJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('copied'))),
    );
  }

  Future<void> _importProfile() async {
    String tr(String k) => context.tr(k);
    final st = AppScope.of(context);
    final controller = TextEditingController();
    // v5.17 (Phase-1 audit L-4): the dialog-scoped controller is disposed
    // when the dialog closes instead of leaking until GC.
    try {
      // v5.11: the learner picks WHICH local slot receives the backup —
      // the current one (default, v4.0 behavior) or another slot on this
      // device. Cross-slot restore never touches the current slot's data.
      int chosenSlot = st.profileSlot;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(tr('importProfile')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('importHint'), style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('importTargetSlot'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13)),
                  RadioGroup<int>(
                    groupValue: chosenSlot,
                    onChanged: (v) => setDialogState(() => chosenSlot = v ?? 1),
                    child: Column(
                      children: [
                        for (var slot = 1;
                            slot <= ProfileStore.maxProfiles;
                            slot++)
                          RadioListTile<int>(
                            value: slot,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              st.profileNames[slot] ??
                                  '${tr('profileDefault')} $slot',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            subtitle: slot == st.profileSlot
                                ? Text(tr('importSlotCurrent'),
                                    style: const TextStyle(fontSize: 11.5))
                                : Text(tr('importSlotOverwrite'),
                                    style: const TextStyle(fontSize: 11.5)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('importProfile')),
              ),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;

      final err =
          await st.importProfileJson(controller.text, targetSlot: chosenSlot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err == null ? tr('importDone') : tr(err)),
          backgroundColor: err == null ? AppColors.green : AppColors.red,
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// v5.12 (F2.5): applies the reminder switch through the shared
  /// ReminderService. If Android denies POST_NOTIFICATIONS, the switch is
  /// reverted and the learner is told where to enable it.
  Future<void> _toggleReminder(bool on, String Function(String) tr) async {
    final st = AppScope.of(context);
    final svc = AppScope.remindersOf(context);
    final next = st.reminders.copyWith(enabled: on);
    final ok = await svc.sync(
      settings: next,
      title: L.t(st.uiLocale, 'dailyReminderTitle'),
      body: L.t(st.uiLocale, 'dailyReminderBody'),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('reminderDenied'))),
      );
      return; // state unchanged — switch snaps back on rebuild
    }
    st.setReminders(next);
  }

  /// v5.12 (F2.5): picks the reminder time and re-syncs the notifier.
  Future<void> _pickReminderTime(String Function(String) tr) async {
    final st = AppScope.of(context);
    final svc = AppScope.remindersOf(context);
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: st.reminders.hour, minute: st.reminders.minute),
    );
    if (picked == null || !mounted) return;
    final next =
        st.reminders.copyWith(hour: picked.hour, minute: picked.minute);
    final ok = await svc.sync(
      settings: next,
      title: L.t(st.uiLocale, 'dailyReminderTitle'),
      body: L.t(st.uiLocale, 'dailyReminderBody'),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('reminderDenied'))),
      );
      return;
    }
    st.setReminders(next);
  }

  void _confirmReset(String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('resetConfirm'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(tr('resetBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel'),
                style: TextStyle(
                    color: context.mutedText, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () async {
              final st = AppScope.of(context);
              await st.resetAll();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text(tr('reset'),
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

Future<void> _renameProfile(BuildContext context, AppState st, int slot,
    String Function(String) tr) async {
  final ctrl = TextEditingController(
      text: st.profileNames[slot] ?? '${tr('profileDefault')} $slot');
  // v5.17 (Phase-1 audit L-4): dispose the dialog-scoped controller.
  try {
    await showDialog<void>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(tr('profileRename')),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlg).pop(),
              child: Text(MaterialLocalizations.of(dlg).cancelButtonLabel)),
          FilledButton(
            onPressed: () {
              st.renameProfile(slot, ctrl.text);
              Navigator.of(dlg).pop();
            },
            child: Text(tr('profileRename')),
          ),
        ],
      ),
    );
  } finally {
    ctrl.dispose();
  }
}
