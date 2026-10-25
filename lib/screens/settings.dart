// Settings: UI language, theme, motion, TTS, backup, reset, about.
// v4.0: dark mode + reduce motion + persisted TTS + profile export/import.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
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
          _sectionTitle(tr('uiLanguage')),
          const SizedBox(height: 10),
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
          const SizedBox(height: 24),
          _sectionTitle(tr('darkMode')),
          const SizedBox(height: 6),
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
            subtitle: Text(tr('reduceMotion'),
                style: TextStyle(fontSize: 12, color: context.mutedText)),
            value: st.reduceMotion,
            onChanged: (v) => setState(() => st.setReduceMotion(v)),
          ),
          const SizedBox(height: 12),
          _sectionTitle(tr('ttsSound')),
          const SizedBox(height: 6),
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
                        color: context.mutedText, fontWeight: FontWeight.w800),
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
                        color: context.mutedText, fontWeight: FontWeight.w800),
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
          const SizedBox(height: 24),
          // v5.10: local multi-profile slots (up to 3 learners on this
          // device) — purely on-device, no accounts, no network.
          _sectionTitle(tr('profilesTitle')),
          const SizedBox(height: 4),
          Text(tr('profilesHint'),
              style: TextStyle(fontSize: 12.5, color: context.mutedText)),
          const SizedBox(height: 10),
          for (var slot = 1; slot <= ProfileStore.maxProfiles; slot++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      st.profileNames[slot] ?? '${tr('profileDefault')} $slot',
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
                            color: AppColors.green))
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
          const SizedBox(height: 24),
          _sectionTitle(tr('backupRestore')),
          const SizedBox(height: 10),
          ChunkyButton(
            label: tr('exportProfile'),
            color: AppColors.blue,
            colorDark: AppColors.blueDark,
            icon: Icons.ios_share,
            height: 46,
            fontSize: 14,
            onPressed: _exportProfile,
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            label: tr('importProfile'),
            color: AppColors.purple,
            colorDark: AppColors.purple,
            icon: Icons.download,
            height: 46,
            fontSize: 14,
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
                        color: AppColors.blue, size: 22),
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
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
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
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('importProfile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('importHint'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
    );
    if (ok != true || !mounted) return;

    final st = AppScope.of(context);
    final err = await st.importProfileJson(controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null ? tr('importDone') : tr(err)),
        backgroundColor: err == null ? AppColors.green : AppColors.red,
      ),
    );
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
}
