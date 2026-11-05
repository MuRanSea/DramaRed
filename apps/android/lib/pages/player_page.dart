import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:openhongguo/openhongguo.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/favorites_store.dart';
import '../services/history_store.dart';
import '../services/ohg_client.dart';
import '../services/player_controller.dart';
import '../theme/app_theme.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.episodeId,
    this.seriesId = '',
    this.seriesTitle = '',
    this.episodes = const [],
    this.initialPositionMs = 0,
    this.coverUrl = '',
  });

  final String title;
  final String episodeId;
  final String seriesId;
  final String seriesTitle;
  final List<Episode> episodes;
  /// Resume position from history (milliseconds).
  final int initialPositionMs;
  final String coverUrl;

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
  Timer? _progressTicker;
  List<Episode> _episodes = const [];
  bool _favorited = false;
  bool _liked = false;
  bool _playing = false;

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
      if (mounted) setState(() => _playing = playing);
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
    if (widget.seriesId.isNotEmpty) {
      FavoritesStore().contains(widget.seriesId).then((v) {
        if (mounted) setState(() => _favorited = v);
      });
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

  int get _epNumber {
    final i = _episodes.indexWhere((e) => e.id == _episodeId);
    if (i >= 0) return _episodes[i].number != 0 ? _episodes[i].number : i + 1;
    return 0;
  }

  HistoryEntry _historySnapshot({int? positionMs}) {
    return HistoryEntry(
      seriesId: widget.seriesId,
      episodeId: _episodeId,
      title: _title,
      seriesTitle: widget.seriesTitle,
      coverUrl: widget.coverUrl,
      episodeNumber: _epNumber,
      episodeCount: _episodes.length,
      positionMs: positionMs ?? _controller.player.state.position.inMilliseconds,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _persistProgress() async {
    if (widget.seriesId.isEmpty && _episodeId.isEmpty) return;
    await HistoryStore().upsert(_historySnapshot());
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
    await _advanceTo(next, status: '自动连播：第 ${next.number} 集…');
  }

  Future<void> _advanceTo(Episode next, {String? status}) async {
    if (_advancing) return;
    _advancing = true;
    try {
      if (mounted) {
        setState(() {
          _episodeId = next.id;
          _title =
              '${widget.seriesTitle.isEmpty ? widget.seriesId : widget.seriesTitle} · ${next.number}';
          if (status != null) _status = status;
        });
      }
      await _load();
    } finally {
      _advancing = false;
    }
  }

  Future<void> _playNext() async {
    final next = PlayerController.nextEpisode(_episodes, _episodeId);
    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是最后一集')),
      );
      return;
    }
    await _advanceTo(next, status: '下一集：第 ${next.number} 集…');
  }

  Future<void> _load({Duration? seekTo}) async {
    if (_episodeId.isEmpty) {
      setState(() => _status = '缺少 episodeId');
      return;
    }
    try {
      final client = await OhgClient.instance();
      final result = await client.resolvePlayback(_episodeId);
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
        _historySnapshot(positionMs: seekTo?.inMilliseconds),
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

  Future<void> _toggleFav() async {
    if (widget.seriesId.isEmpty) return;
    final store = FavoritesStore();
    if (_favorited) {
      await store.remove(widget.seriesId);
    } else {
      await store.add(
        FavoriteEntry(
          seriesId: widget.seriesId,
          title: widget.seriesTitle.isEmpty ? widget.title : widget.seriesTitle,
          coverUrl: widget.coverUrl,
          episodeCount: _episodes.length,
        ),
      );
    }
    if (mounted) setState(() => _favorited = !_favorited);
  }

  void _togglePlay() {
    if (_controller.player.state.playing) {
      unawaited(_controller.pause());
    } else {
      unawaited(_controller.play());
    }
  }

  void _showEpisodeSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HgColors.bgElevated,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '剧集 · 共 ${_episodes.length} 集',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _episodes.length,
                    itemBuilder: (context, i) {
                      final ep = _episodes[i];
                      final on = ep.id == _episodeId;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          unawaited(_advanceTo(ep, status: '第 ${ep.number} 集…'));
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? HgColors.accent : const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${ep.number == 0 ? i + 1 : ep.number}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HgColors.bgElevated,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('清晰度'),
                    trailing: DropdownButton<String>(
                      dropdownColor: HgColors.bgElevated,
                      value: _definitions.contains(_definition) ? _definition : '自动',
                      items: _definitions
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) {
                        Navigator.pop(ctx);
                        unawaited(_switchDefinition(v));
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('倍速'),
                    trailing: DropdownButton<double>(
                      dropdownColor: HgColors.bgElevated,
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
                        setSheet(() {});
                        await _controller.setRate(rate);
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('自动连播'),
                    subtitle: Text(
                      _episodes.isEmpty
                          ? '未传入分集列表（从剧场/搜索进播可连播）'
                          : '播完自动下一集（共 ${_episodes.length} 集）',
                    ),
                    value: _autoNext,
                    onChanged: (v) {
                      setState(() => _autoNext = v);
                      setSheet(() {});
                    },
                  ),
                  ListTile(
                    title: const Text('定时停止'),
                    subtitle: Text(
                      _stopAfterMinutes == 0 ? '关闭' : '$_stopAfterMinutes 分钟后暂停',
                    ),
                    trailing: DropdownButton<int>(
                      dropdownColor: HgColors.bgElevated,
                      value: _stopAfterMinutes,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('关闭')),
                        DropdownMenuItem(value: 15, child: Text('15 分钟')),
                        DropdownMenuItem(value: 30, child: Text('30 分钟')),
                        DropdownMenuItem(value: 45, child: Text('45 分钟')),
                        DropdownMenuItem(value: 60, child: Text('60 分钟')),
                      ],
                      onChanged: (v) {
                        _setStopAfter(v ?? 0);
                        setSheet(() {});
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('后台 / 隐藏继续听'),
                    subtitle: const Text('开启时切后台不主动暂停，并保持 wakelock'),
                    value: _backgroundListen,
                    onChanged: (v) async {
                      setState(() => _backgroundListen = v);
                      setSheet(() {});
                      await _syncWakelock(_controller.player.state.playing);
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
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
    final displayTitle =
        widget.seriesTitle.isNotEmpty ? widget.seriesTitle : _title;
    final epLabel = epIndex >= 0
        ? '第 ${_episodes[epIndex].number == 0 ? epIndex + 1 : _episodes[epIndex].number}/${_episodes.length} 集'
        : _status;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: ColoredBox(
                color: Colors.black,
                child: Video(
                  controller: _video,
                  fit: BoxFit.cover,
                  controls: NoVideoControls,
                ),
              ),
            ),
            if (!_playing)
              const IgnorePointer(
                child: Center(
                  child: Icon(Icons.play_arrow_rounded, size: 72, color: Colors.white70),
                ),
              ),
            ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0, 0.2, 0.55, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        onPressed: _showMoreSheet,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 140,
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFE8E0D4),
                      child: Icon(Icons.person, color: Color(0xFF8A7A60)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: HgColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('关注', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(height: 18),
                    _SideAction(
                      icon: _liked ? Icons.favorite : Icons.favorite_border,
                      label: _liked ? '已赞' : '赞',
                      onTap: () => setState(() => _liked = !_liked),
                    ),
                    const SizedBox(height: 16),
                    _SideAction(
                      icon: Icons.chat_bubble_outline,
                      label: '评论',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('评论占位')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SideAction(
                      icon: _favorited ? Icons.star : Icons.star_border,
                      label: _favorited ? '已收藏' : '收藏',
                      onTap: () => unawaited(_toggleFav()),
                    ),
                    const SizedBox(height: 16),
                    _SideAction(
                      icon: Icons.reply,
                      label: '分享',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('分享「$displayTitle」占位')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 80,
                bottom: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      epLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _PillButton(
                          icon: Icons.grid_view,
                          label: '剧集',
                          onTap: _showEpisodeSheet,
                        ),
                        const SizedBox(width: 10),
                        _PillButton(
                          icon: Icons.skip_next,
                          label: '下一集',
                          onTap: () => unawaited(_playNext()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x66FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
