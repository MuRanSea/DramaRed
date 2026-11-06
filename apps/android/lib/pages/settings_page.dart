import 'package:flutter/material.dart';

import '../services/playback_settings_store.dart';
import '../theme/app_theme.dart';

/// 「我的」里的设置：定时停播、后台继续听、自动连播（线框：芯片单选 + 开关）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PlaybackSettings _settings = const PlaybackSettings();
  bool _loading = true;

  static const _timerOptions = <(int, String)>[
    (0, '关'),
    (15, '15分'),
    (30, '30分'),
    (60, '60分'),
  ];

  @override
  void initState() {
    super.initState();
    PlaybackSettingsStore().load().then((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _loading = false;
      });
    });
  }

  Future<void> _update(PlaybackSettings next) async {
    setState(() => _settings = next);
    await PlaybackSettingsStore().save(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HgColors.mineBg,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: HgColors.mineBg,
        foregroundColor: HgColors.mineText,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Material(
                  color: HgColors.mineCard,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '定时停播',
                          style: TextStyle(
                            color: HgColors.mineText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _settings.stopAfterMinutes == 0
                              ? '关闭（进入播放页后不自动暂停）'
                              : '进入播放后 ${_settings.stopAfterMinutes} 分钟暂停',
                          style: const TextStyle(color: HgColors.mineMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (minutes, label) in _timerOptions)
                              ChoiceChip(
                                label: Text(label),
                                selected: _settings.stopAfterMinutes == minutes,
                                selectedColor: HgColors.accent.withOpacity(0.25),
                                labelStyle: TextStyle(
                                  color: _settings.stopAfterMinutes == minutes
                                      ? HgColors.accent
                                      : HgColors.mineText,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) => _update(
                                  _settings.copyWith(stopAfterMinutes: minutes),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: HgColors.mineCard,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(14),
                  child: SwitchListTile(
                    title: const Text('后台继续听', style: TextStyle(color: HgColors.mineText)),
                    subtitle: const Text(
                      '切到后台时不主动暂停播放',
                      style: TextStyle(color: HgColors.mineMuted),
                    ),
                    value: _settings.backgroundListen,
                    activeThumbColor: HgColors.accent,
                    onChanged: (v) => _update(
                      _settings.copyWith(backgroundListen: v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: HgColors.mineCard,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(14),
                  child: SwitchListTile(
                    title: const Text('自动连播下一集', style: TextStyle(color: HgColors.mineText)),
                    subtitle: const Text(
                      '当前集播完后自动进入下一集',
                      style: TextStyle(color: HgColors.mineMuted),
                    ),
                    value: _settings.autoNext,
                    activeThumbColor: HgColors.accent,
                    onChanged: (v) => _update(
                      _settings.copyWith(autoNext: v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: Text(
                    '设置会立即保存，并在下次进入播放页时生效。不做下载。',
                    style: TextStyle(color: HgColors.mineMuted, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }
}
