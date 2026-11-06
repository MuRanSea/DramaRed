import 'package:flutter/material.dart';

import '../services/playback_settings_store.dart';
import '../theme/app_theme.dart';

/// 「我的」里的设置：定时停播、后台继续听、自动连播。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PlaybackSettings _settings = const PlaybackSettings();
  bool _loading = true;

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
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    '播放偏好',
                    style: TextStyle(
                      color: HgColors.mineMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Material(
                  color: HgColors.mineCard,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('定时停播', style: TextStyle(color: HgColors.mineText)),
                        subtitle: Text(
                          _settings.stopAfterMinutes == 0
                              ? '关闭（进入播放页后不自动暂停）'
                              : '进入播放后 ${_settings.stopAfterMinutes} 分钟暂停',
                          style: const TextStyle(color: HgColors.mineMuted),
                        ),
                        trailing: DropdownButton<int>(
                          value: _settings.stopAfterMinutes,
                          dropdownColor: Colors.white,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('关闭')),
                            DropdownMenuItem(value: 15, child: Text('15 分钟')),
                            DropdownMenuItem(value: 30, child: Text('30 分钟')),
                            DropdownMenuItem(value: 45, child: Text('45 分钟')),
                            DropdownMenuItem(value: 60, child: Text('60 分钟')),
                          ],
                          onChanged: (v) => _update(
                            _settings.copyWith(stopAfterMinutes: v ?? 0),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      SwitchListTile(
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
                      const Divider(height: 1, indent: 16),
                      SwitchListTile(
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
                    ],
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
