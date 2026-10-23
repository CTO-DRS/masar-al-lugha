// Settings: UI language, TTS, reset, about.
import 'package:flutter/material.dart';

import '../scope.dart';
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
    final tr = (String k) => context.tr(k);

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
          _sectionTitle(tr('ttsSound')),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('ttsSound'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            value: AppScope.ttsOf(context).enabled,
            activeColor: AppColors.green,
            onChanged: (v) {
              setState(() {
                AppScope.ttsOf(context).enabled = v;
              });
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('ttsRate'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${AppScope.ttsOf(context).rate.toStringAsFixed(1)}x',
                    style: const TextStyle(
                        color: AppColors.inkLight,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Slider(
                value: AppScope.ttsOf(context).rate,
                min: 0.5,
                max: 1.2,
                divisions: 7,
                activeColor: AppColors.blue,
                label: '${AppScope.ttsOf(context).rate.toStringAsFixed(1)}x',
                onChanged: (v) {
                  setState(() {
                    AppScope.ttsOf(context).rate = v;
                  });
                },
              ),
            ],
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
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 2),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr('aboutBody'),
                  style: const TextStyle(
                      color: AppColors.inkLight, fontSize: 13.5, height: 1.5),
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
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: AppColors.ink,
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
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blueLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.blue : AppColors.inkLight,
          ),
        ),
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
                style: const TextStyle(
                    color: AppColors.inkLight,
                    fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () async {
              await AppScope.of(context).resetAll();
              if (!mounted) return;
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
