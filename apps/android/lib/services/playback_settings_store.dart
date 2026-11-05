import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// App-wide playback preferences. Timer lives here (not on the player page).
class PlaybackSettings {
  const PlaybackSettings({
    this.stopAfterMinutes = 0,
    this.backgroundListen = true,
    this.autoNext = true,
  });

  /// 0 = off; otherwise minutes until pause after playback starts.
  final int stopAfterMinutes;
  final bool backgroundListen;
  final bool autoNext;

  PlaybackSettings copyWith({
    int? stopAfterMinutes,
    bool? backgroundListen,
    bool? autoNext,
  }) {
    return PlaybackSettings(
      stopAfterMinutes: stopAfterMinutes ?? this.stopAfterMinutes,
      backgroundListen: backgroundListen ?? this.backgroundListen,
      autoNext: autoNext ?? this.autoNext,
    );
  }

  Map<String, Object?> toJson() => {
        'stopAfterMinutes': stopAfterMinutes,
        'backgroundListen': backgroundListen,
        'autoNext': autoNext,
      };

  factory PlaybackSettings.fromJson(Map<String, dynamic> j) => PlaybackSettings(
        stopAfterMinutes: j['stopAfterMinutes'] as int? ?? 0,
        backgroundListen: j['backgroundListen'] as bool? ?? true,
        autoNext: j['autoNext'] as bool? ?? true,
      );
}

class PlaybackSettingsStore {
  static const _key = 'dramared.playback.settings';

  Future<PlaybackSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const PlaybackSettings();
    try {
      return PlaybackSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PlaybackSettings();
    }
  }

  Future<void> save(PlaybackSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
