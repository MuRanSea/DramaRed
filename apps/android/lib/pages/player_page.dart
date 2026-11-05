import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:openhongguo/openhongguo.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/history_store.dart';
import '../services/ohg_client.dart';
import '../services/player_controller.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.episodeId,
    this.seriesId = '',
    this.seriesTitle = '',
    this.episodes = const [],
    this.initialPositionMs = 0,
  });

  final String title;
  final String episodeId;
  final String seriesId;
  final String seriesTitle;
  final List<Episode> episodes;
  /// Resume position from history (milliseconds).
  final int initialPositionMs;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final PlayerController _controller;
  late final VideoController _video;

  late String _episodeId;
  late String _title;
  String _definition = '自动';
  double _speed = 1.0;
  bool _autoNext = true;
  bool _backgroundListen = true;
  /// 0 = off; otherwise minutes until pause.
  int _stopAfterMinutes = 0;
  String _status = '解析播放地址…';
  List<String> _definitions = const ['自动'];
  DateTime? _stopDeadline;
  Timer? _stopTicker;
  StreamSubscription? _completedSub;
  StreamSubscription? _playingSub;
  bool _advancing = false;
  PlaybackResult? _lastPlayback;
  Timer? _progressTicker;
  List<Episode> _episodes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episodeId = widget.episodeId;
    _title = widget.title;
    _episodes = widget.episodes;
    _controller = PlayerController();
    _video = VideoController(_controller.player);
    _completedSub = _controller.player.stream.completed.listen((done) {
      if (done) unawaited(_onCompleted());
    });
    _playingSub = _controller.player.stream.playing.listen((playing) {
      unawaited(_syncWakelock(playing));
    });
    _progressTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_persistProgress());
    });
    final resume = widget.initialPositionMs > 0
        ? Duration(milliseconds: widget.initialPositionMs)
        : null;
    unawaited(_load(seekTo: resume));
    if (widget.seriesId.isNotEmpty && _episodes.isEmpty) {
      unawaited(_ensureEpisodes());
    }
  }

  Future<void> _ensureEpisodes() async {
    try {
      final client = await OhgClient.instance();
      final page = await client.listEpisodes(widget.seriesId);
      if (!mounted) return;
      setState(() => _episodes = page.items);
    } catch (_) {}
  }

  Future<void> _persistProgress() async {
    if (widget.seriesId.isEmpty && _episodeId.isEmpty) return;
    final pos = _controller.player.state.position.inMilliseconds;
    await HistoryStore().upsert(
      HistoryEntry(
        seriesId: widget.seriesId,
        episodeId: _episodeId,
        title: _title,
        seriesTitle: widget.seriesTitle,
        positionMs: pos,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _syncWakelock(bool playing) async {
    try {
      if (_backgroundListen && playing) {
        await WakelockPlus.enable();
      } else if (!playing) {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When background listen is on, keep audio; otherwise pause on background.
    if (!_backgroundListen &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive)) {
      unawaited(_controller.pause());
    }
  }

  Future<void> _onCompleted() async {
    if (!_autoNext || _advancing) return;
    final next = PlayerController.nextEpisode(_episodes, _episodeId);
    if (next == null) {
      if (mounted) setState(() => _status = '已播完本剧');
      return;
    }
    _advancing = true;
    try {
      if (mounted) {
        setState(() {
          _episodeId = next.id;
          _title =
              '${widget.seriesTitle.isEmpty ? widget.seriesId : widget.seriesTitle} · ${next.number}';
          _status = '自动连播：第 ${next.number} 集…';
        });
      }
      await _load();
    } finally {
      _advancing = false;
    }
  }

  Future<void> _load({Duration? seekTo}) async {
    if (_episodeId.isEmpty) {
      setState(() => _status = '缺少 episodeId');
      return;
    }
    try {
      final client = await OhgClient.instance();
      final result = await client.resolvePlayback(_episodeId);
      _lastPlayback = result;
      final defs = result.playback.streams
          .where((s) => s.url.isNotEmpty)
          .map(PlayerController.streamLabel)
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      if (mounted) {
        setState(() {
          _definitions = ['自动', ...defs];
          _status = result.playback.protected
              ? '受保护流（尝试 ClearKey/decryption_key）'
              : '播放中';
        });
      }
      await _controller.openPlayback(
        result,
        preferDefinition: _definition,
        seekTo: seekTo,
      );
      await _controller.setRate(_speed);
      await HistoryStore().upsert(
        HistoryEntry(
          seriesId: widget.seriesId,
          episodeId: _episodeId,
          title: _title,
          seriesTitle: widget.seriesTitle,
          positionMs: seekTo?.inMilliseconds ??
              _controller.player.state.position.inMilliseconds,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

    } catch (e) {
      if (mounted) setState(() => _status = '播放失败：$e');
    }
  }

  Future<void> _switchDefinition(String? v) async {
    final next = v ?? '自动';
    final pos = _controller.player.state.position;
    setState(() => _definition = next);
    await _load(seekTo: pos);
  }

  void _setStopAfter(int minutes) {
    _stopTicker?.cancel();
    setState(() {
      _stopAfterMinutes = minutes;
      if (minutes <= 0) {
        _stopDeadline = null;
        _status = _status.contains('定时') ? '播放中' : _status;
        return;
      }
      _stopDeadline = DateTime.now().add(Duration(minutes: minutes));
    });
    if (minutes <= 0) return;
    _stopTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _stopDeadline;
      if (deadline == null) return;
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        _stopTicker?.cancel();
        unawaited(_controller.pause());
        unawaited(WakelockPlus.disable());
        if (mounted) {
          setState(() {
            _stopAfterMinutes = 0;
            _stopDeadline = null;
            _status = '定时停止已触发';
          });
        }
      } else if (mounted) {
        setState(() {
          final m = left.inMinutes;
          final s = left.inSeconds % 60;
          _status = '定时停止倒计时 ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker?.cancel();
    _progressTicker?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    unawaited(_persistProgress());
    unawaited(WakelockPlus.disable());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epIndex = _episodes.indexWhere((e) => e.id == _episodeId);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Video(controller: _video),
            ),
          ),
          const SizedBox(height: 8),
          Text(_status),
          if (epIndex >= 0)
            Text(
              '分集 ${epIndex + 1}/${_episodes.length}'
              '${_lastPlayback == null ? '' : ' · streams=${_lastPlayback!.playback.streams.length}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ListTile(
            title: const Text('清晰度'),
            trailing: DropdownButton<String>(
              value: _definitions.contains(_definition) ? _definition : '自动',
              items: _definitions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: _switchDefinition,
            ),
          ),
          ListTile(
            title: const Text('倍速'),
            trailing: DropdownButton<double>(
              value: _speed,
              items: const [
                DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                DropdownMenuItem(value: 2.0, child: Text('2.0x')),
              ],
              onChanged: (v) async {
                final rate = v ?? 1.0;
                setState(() => _speed = rate);
                await _controller.setRate(rate);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('自动连播'),
            subtitle: Text(
              _episodes.isEmpty
                  ? '未传入分集列表（从书城/搜索进分集页再播可连播）'
                  : '播完自动下一集（共 ${_episodes.length} 集）',
            ),
            value: _autoNext,
            onChanged: (v) => setState(() => _autoNext = v),
          ),
          ListTile(
            title: const Text('定时停止'),
            subtitle: Text(
              _stopAfterMinutes == 0
                  ? '关闭'
                  : '$_stopAfterMinutes 分钟后暂停',
            ),
            trailing: DropdownButton<int>(
              value: _stopAfterMinutes,
              items: const [
                DropdownMenuItem(value: 0, child: Text('关闭')),
                DropdownMenuItem(value: 15, child: Text('15 分钟')),
                DropdownMenuItem(value: 30, child: Text('30 分钟')),
                DropdownMenuItem(value: 45, child: Text('45 分钟')),
                DropdownMenuItem(value: 60, child: Text('60 分钟')),
              ],
              onChanged: (v) => _setStopAfter(v ?? 0),
            ),
          ),
          SwitchListTile(
            title: const Text('后台 / 隐藏继续听'),
            subtitle: const Text('开启时切后台不主动暂停，并保持 wakelock'),
            value: _backgroundListen,
            onChanged: (v) async {
              setState(() => _backgroundListen = v);
              await _syncWakelock(_controller.player.state.playing);
            },
          ),
        ],
      ),
    );
  }
}
