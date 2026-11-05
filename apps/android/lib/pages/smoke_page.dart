import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/ohg_client.dart';
import '../services/player_controller.dart';

/// Emulator / CI smoke: search → first series → first episode → open playback.
/// Optional [directUrl] skips ohg (local/reverse sample) to prove media_kit out画.
/// Logs lines tagged [DramaRedSmoke] for adb logcat scraping.
class SmokePage extends StatefulWidget {
  const SmokePage({
    super.key,
    this.initialQuery = '短剧',
    this.observeSeconds = 20,
    this.directUrl = '',
  });

  final String initialQuery;
  final int observeSeconds;
  final String directUrl;

  @override
  State<SmokePage> createState() => _SmokePageState();
}

class _SmokePageState extends State<SmokePage> {
  static const _tag = 'DramaRedSmoke';
  late final PlayerController _controller;
  late final VideoController _video;
  final _lines = <String>[];
  String _phase = 'init';
  StreamSubscription? _playingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _widthSub;
  bool _sawPlaying = false;
  int _videoWidth = 0;

  void _log(String msg) {
    final line = '[$_tag] $msg';
    debugPrint(line);
    if (mounted) {
      setState(() {
        _lines.add(line);
        _phase = msg;
      });
    }
  }

  Future<T> _timeout<T>(Future<T> f, String label, {int seconds = 45}) {
    return f.timeout(
      Duration(seconds: seconds),
      onTimeout: () => throw TimeoutException('$label after ${seconds}s'),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = PlayerController();
    _video = VideoController(_controller.player);
    _playingSub = _controller.player.stream.playing.listen((playing) {
      _log('playing=$playing');
      if (playing) _sawPlaying = true;
    });
    _errorSub = _controller.player.stream.error.listen((err) {
      _log('player_error=$err');
    });
    _widthSub = _controller.player.stream.width.listen((w) {
      if (w != null && w > 0) {
        _videoWidth = w;
        _log('video_width=$w');
      }
    });
    unawaited(_run());
  }

  Future<void> _observeAndJudge(String passTag) async {
    final observe = widget.observeSeconds.clamp(5, 120);
    await Future<void>.delayed(Duration(seconds: observe));
    final pos = _controller.player.state.position;
    final dur = _controller.player.state.duration;
    _log(
      'observe_done sawPlaying=$_sawPlaying width=$_videoWidth '
      'posMs=${pos.inMilliseconds} durMs=${dur.inMilliseconds}',
    );
    if (_sawPlaying || _videoWidth > 0 || pos.inMilliseconds > 0) {
      _log('PASS $passTag');
    } else {
      _log('FAIL no_playback_signal');
    }
  }

  Future<void> _runDirect(String url) async {
    _log('mode=direct_url url=$url');
    await _controller.player.open(Media(url));
    _log('open_direct_done');
    await _observeAndJudge('media_kit_local_ok');
  }

  Future<void> _runOhg() async {
    final query = widget.initialQuery.trim().isEmpty ? '短剧' : widget.initialQuery.trim();
    _log('mode=ohg query="$query"');
    final client = await _timeout(OhgClient.instance(), 'ohg_client', seconds: 60);
    _log('ohg_client_ready');

    final search = await _timeout(client.search(query), 'search', seconds: 60);
    _log('search_count=${search.items.length}');
    if (search.items.isEmpty) {
      _log('FAIL no_search_hits');
      return;
    }
    final series = search.items.first;
    _log('series id=${series.id} title=${series.title}');

    final eps = await _timeout(client.listEpisodes(series.id), 'episodes', seconds: 60);
    _log('episodes_count=${eps.items.length}');
    if (eps.items.isEmpty) {
      _log('FAIL no_episodes');
      return;
    }
    final ep = eps.items.first;
    _log('episode id=${ep.id} title=${ep.title}');

    final playback = await _timeout(client.resolvePlayback(ep.id), 'playback', seconds: 60);
    final streams = playback.playback.streams.where((s) => s.url.isNotEmpty).length;
    _log(
      'playback protected=${playback.playback.protected} '
      'streams=$streams hasKey=${playback.contentKey?.key.isNotEmpty == true}',
    );

    await _controller.openPlayback(playback);
    _log('openPlayback_done');
    await _observeAndJudge('playback_signal_ok');
  }

  Future<void> _run() async {
    try {
      _log('start observe=${widget.observeSeconds}s');
      final direct = widget.directUrl.trim();
      if (direct.isNotEmpty) {
        await _runDirect(direct);
        return;
      }
      await _runOhg();
    } catch (e, st) {
      _log('FAIL exception=$e');
      debugPrint('[$_tag] $st');
    }
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _errorSub?.cancel();
    _widthSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DramaRed Smoke')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Video(controller: _video),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('phase: $_phase', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<SmokeLaunch?> resolveSmokeLaunch() async {
  const defineAuto = bool.fromEnvironment('SMOKE_AUTO', defaultValue: false);
  const defineQuery = String.fromEnvironment('SMOKE_QUERY', defaultValue: '短剧');
  const defineSeconds = int.fromEnvironment('SMOKE_SECONDS', defaultValue: 20);
  const defineUrl = String.fromEnvironment('SMOKE_URL', defaultValue: '');

  var auto = defineAuto;
  var query = defineQuery;
  var seconds = defineSeconds;
  var url = defineUrl;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      const ch = MethodChannel('com.dramared.app/smoke');
      final raw = await ch.invokeMapMethod<String, dynamic>('getSmokeArgs');
      if (raw != null) {
        auto = auto || (raw['auto'] == true);
        final q = (raw['query'] as String?)?.trim() ?? '';
        if (q.isNotEmpty) query = q;
        final s = raw['seconds'];
        if (s is int && s > 0) seconds = s;
        final u = (raw['url'] as String?)?.trim() ?? '';
        if (u.isNotEmpty) url = u;
      }
    } catch (_) {}
  }

  if (!auto) return null;
  return SmokeLaunch(query: query, seconds: seconds, directUrl: url);
}

class SmokeLaunch {
  const SmokeLaunch({
    required this.query,
    required this.seconds,
    this.directUrl = '',
  });
  final String query;
  final int seconds;
  final String directUrl;
}
