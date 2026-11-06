import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:openhongguo/openhongguo.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/favorites_store.dart';
import '../services/history_store.dart';
import '../services/ohg_client.dart';
import '../services/playback_policies.dart';
import '../services/playback_settings_store.dart';
import '../services/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/episode_swipe_shell.dart';
import '../widgets/status_pane.dart';

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
  late VideoController _video;

  late String _episodeId;
  late String _title;
  String _definition = '自动';
  double _speed = 1.0;
  bool _autoNext = true;
  bool _backgroundListen = true;
  String _status = '解析播放地址…';
  List<String> _definitions = const ['自动'];
  DateTime? _stopDeadline;
  Timer? _stopTicker;
  StreamSubscription? _completedSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _errorSub;
  bool _advancing = false;
  Timer? _progressTicker;
  List<Episode> _episodes = const [];
  bool _favorited = false;
  bool _playing = false;
  final _playbackCache = <String, PlaybackResult>{};
  late final PageController _epPageController;
  int _pageIndex = 0;
  bool _ignorePageChange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episodeId = widget.episodeId;
    _title = widget.title;
    _episodes = widget.episodes;
    final initialIdx = _episodes.indexWhere((e) => e.id == widget.episodeId);
    _pageIndex = initialIdx >= 0 ? initialIdx : 0;
    _epPageController = PageController(initialPage: _pageIndex);
    _controller = PlayerController();
    _video = VideoController(_controller.player);
    _bindPlayerStreams();
    _progressTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_persistProgress());
    });
    final resume = widget.initialPositionMs > 0
        ? Duration(milliseconds: widget.initialPositionMs)
        : null;
    unawaited(_bootstrap(seekTo: resume));
    if (widget.seriesId.isNotEmpty && _episodes.isEmpty) {
      unawaited(_ensureEpisodes());
    }
    if (widget.seriesId.isNotEmpty) {
      FavoritesStore().contains(widget.seriesId).then((v) {
        if (mounted) setState(() => _favorited = v);
      });
    }
  }

  void _bindPlayerStreams() {
    _completedSub?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _completedSub = _controller.player.stream.completed.listen((done) {
      if (done) unawaited(_onCompleted());
    });
    _playingSub = _controller.player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _playing = playing;
          if (playing) _status = '播放中';
        });
      }
      unawaited(_syncWakelock(playing));
    });
    // Never surface ClearKey / demuxer jargon from the engine.
    _errorSub = _controller.player.stream.error.listen((err) {
      if (!mounted || err.trim().isEmpty) return;
      debugPrint('[DramaRedPlayer] engine_error=$err');
      setState(() => _status = StatusPane.playFailedFriendly);
    });
  }

  Future<void> _bootstrap({Duration? seekTo}) async {
    try {
      final settings = await PlaybackSettingsStore().load();
      if (!mounted) return;
      setState(() {
        _autoNext = settings.autoNext;
        _backgroundListen = settings.backgroundListen;
      });
      if (settings.stopAfterMinutes > 0) {
        _armStopTimer(settings.stopAfterMinutes);
      }
    } catch (_) {}
    await _load(seekTo: seekTo);
  }

  Future<void> _ensureEpisodes() async {
    try {
      final client = await OhgClient.instance();
      final page = await client.listEpisodes(widget.seriesId);
      if (!mounted) return;
      setState(() => _episodes = page.items);
      _syncPageToCurrent();
    } catch (_) {}
  }

  void _syncPageToCurrent() {
    final i = _episodes.indexWhere((e) => e.id == _episodeId);
    if (i < 0) return;
    _pageIndex = i;
    if (_epPageController.hasClients) {
      _ignorePageChange = true;
      _epPageController.jumpToPage(i);
      _ignorePageChange = false;
    }
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
    if (PlaybackPolicies.shouldPauseOnBackground(
      backgroundListen: _backgroundListen,
      state: state,
    )) {
      debugPrint('[DramaRedPlayer] background_listen pause');
      unawaited(_controller.pause());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      debugPrint('[DramaRedPlayer] background_listen keep_playing');
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

  Future<void> _advanceTo(
    Episode next, {
    String? status,
    bool syncPage = true,
  }) async {
    if (_advancing) return;
    if (next.id == _episodeId) return;
    _advancing = true;
    debugPrint(
      '[DramaRedPlayer] advance_to episode=${next.id} number=${next.number}',
    );
    try {
      if (mounted) {
        setState(() {
          _episodeId = next.id;
          _title =
              '${widget.seriesTitle.isEmpty ? widget.seriesId : widget.seriesTitle} · ${next.number}';
          if (status != null) _status = status;
        });
      }
      if (syncPage) _syncPageToCurrent();
      await _load();
    } finally {
      _advancing = false;
    }
  }

  void _onEpisodePageChanged(int i) {
    if (_ignorePageChange || i == _pageIndex) return;
    if (i < 0 || i >= _episodes.length) return;
    _pageIndex = i;
    unawaited(_advanceTo(_episodes[i], syncPage: false, status: '第 ${_episodes[i].number} 集…'));
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

  Future<void> _playPrev() async {
    final prev = PlayerController.previousEpisode(_episodes, _episodeId);
    if (prev == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是第一集')),
      );
      return;
    }
    await _advanceTo(prev, status: '上一集：第 ${prev.number} 集…');
  }

  void _applyResultMeta(PlaybackResult result) {
    final defs = result.playback.streams
        .where((s) => s.url.isNotEmpty)
        .map(PlayerController.streamLabel)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    _definitions = ['自动', ...defs];
    // Silent ClearKey UX (PR #25 / audit B06): keep decrypting internally;
    // never show 「受保护流」「ClearKey」「decryption_key」 or 「解密」 jargon.
    final hasKey = result.contentKey?.key.isNotEmpty == true;
    if (result.playback.protected) {
      debugPrint(
        '[DramaRedPlayer] protected=${result.playback.protected} hasKey=$hasKey (silent)',
      );
    }
    _status = '缓冲中…';
  }

  Future<void> _prefetchNext() async {
    final next = PlayerController.nextEpisode(_episodes, _episodeId);
    if (next == null) return;
    try {
      var result = _playbackCache[next.id];
      result ??= await (await OhgClient.instance()).resolvePlayback(next.id);
      _playbackCache[next.id] = result;
      await _controller.preloadPlayback(
        result,
        next.id,
        preferDefinition: _definition,
      );
    } catch (_) {}
  }

  Future<void> _load({Duration? seekTo, bool forceResolve = false}) async {
    if (_episodeId.isEmpty) {
      setState(() => _status = '缺少 episodeId');
      return;
    }
    try {
      final client = await OhgClient.instance();
      final kind = PlaybackPolicies.decideLoad(
        forceResolve: forceResolve,
        preloaded: _controller.isPreloaded(_episodeId),
        cached: _playbackCache.containsKey(_episodeId),
      );
      if (forceResolve) {
        _playbackCache.remove(_episodeId);
      }

      if (kind == PlaybackLoadKind.promote &&
          await _controller.takePreloaded(_episodeId)) {
        _bindPlayerStreams();
        if (mounted) setState(() {});
        final cached = _playbackCache[_episodeId];
        if (cached != null && mounted) {
          setState(() => _applyResultMeta(cached));
        } else {
          try {
            final result = await client.resolvePlayback(_episodeId);
            _playbackCache[_episodeId] = result;
            if (mounted) setState(() => _applyResultMeta(result));
          } catch (_) {}
        }
        await _controller.setRate(_speed);
        if (seekTo != null && seekTo > Duration.zero) {
          try {
            await _controller.player.seek(seekTo);
          } catch (_) {}
        }
        await HistoryStore().upsert(
          _historySnapshot(positionMs: seekTo?.inMilliseconds),
        );
        unawaited(_prefetchNext());
        return;
      }

      final result = kind == PlaybackLoadKind.useCache
          ? _playbackCache[_episodeId]!
          : await client.resolvePlayback(_episodeId);
      _playbackCache[_episodeId] = result;
      if (mounted) setState(() => _applyResultMeta(result));
      await _controller.openPlayback(
        result,
        preferDefinition: _definition,
        seekTo: seekTo,
      );
      await _controller.setRate(_speed);
      await HistoryStore().upsert(
        _historySnapshot(positionMs: seekTo?.inMilliseconds),
      );
      unawaited(_prefetchNext());
    } catch (e) {
      debugPrint('[DramaRedPlayer] load_failed=$e');
      if (mounted) {
        setState(() => _status = StatusPane.friendlyPlaybackStatus('播放失败：$e'));
      }
    }
  }

  Future<void> _switchDefinition(String? v) async {
    final next = v ?? '自动';
    final pos = _controller.player.state.position;
    setState(() => _definition = next);
    await _load(seekTo: pos, forceResolve: true);
  }

  void _armStopTimer(int minutes) {
    _stopTicker?.cancel();
    _stopDeadline = PlaybackPolicies.stopDeadline(DateTime.now(), minutes);
    if (_stopDeadline == null) return;
    _stopTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _stopDeadline;
      if (!PlaybackPolicies.shouldFireStop(DateTime.now(), deadline)) return;
      _stopTicker?.cancel();
      debugPrint('[DramaRedPlayer] stop_timer_fired minutes=$minutes');
      unawaited(_controller.pause());
      unawaited(WakelockPlus.disable());
      if (mounted) {
        setState(() {
          _stopDeadline = null;
          _status = '定时停止已触发';
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

  void _showPickerSheet({
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HgColors.bgElevated,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...children,
            ],
          ),
        );
      },
    );
  }

  void _showDefinitionSheet() {
    _showPickerSheet(
      title: '清晰度',
      children: [
        for (final d in _definitions)
          ListTile(
            title: Text(d),
            trailing: d == _definition ? const Icon(Icons.check, color: HgColors.accent) : null,
            onTap: () {
              Navigator.pop(context);
              unawaited(_switchDefinition(d));
            },
          ),
      ],
    );
  }

  void _showSpeedSheet() {
    const rates = [0.75, 1.0, 1.25, 1.5, 2.0];
    _showPickerSheet(
      title: '倍速',
      children: [
        for (final rate in rates)
          ListTile(
            title: Text('${rate}x'),
            trailing: rate == _speed ? const Icon(Icons.check, color: HgColors.accent) : null,
            onTap: () async {
              Navigator.pop(context);
              setState(() => _speed = rate);
              await _controller.setRate(rate);
            },
          ),
      ],
    );
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
                    '选集 · 共 ${_episodes.length} 集',
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker?.cancel();
    _progressTicker?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _epPageController.dispose();
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
    final speedLabel = _speed == _speed.roundToDouble()
        ? '${_speed.toInt()}x'
        : '${_speed}x';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: IgnorePointer(
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
            const IgnorePointer(
              child: DecoratedBox(
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
            ),
            _buildInteractionLayer(
              displayTitle: displayTitle,
              epLabel: epLabel,
              speedLabel: speedLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionLayer({
    required String displayTitle,
    required String epLabel,
    required String speedLabel,
  }) {
    return EpisodeSwipeShell(
      episodeCount: _episodes.length,
      controller: _epPageController,
      onPageChanged: _onEpisodePageChanged,
      onSwipeNext: () => unawaited(_playNext()),
      onSwipePrev: () => unawaited(_playPrev()),
      onTap: _togglePlay,
      overlayBuilder: (context) => _PlayerChrome(
        displayTitle: displayTitle,
        epLabel: epLabel,
        status: _status,
        definition: _definition,
        speedLabel: speedLabel,
        favorited: _favorited,
        onBack: () => Navigator.of(context).maybePop(),
        onFavorite: () => unawaited(_toggleFav()),
        onDefinition: _showDefinitionSheet,
        onSpeed: _showSpeedSheet,
        onEpisodes: _showEpisodeSheet,
      ),
    );
  }
}

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({
    required this.displayTitle,
    required this.epLabel,
    required this.status,
    required this.definition,
    required this.speedLabel,
    required this.favorited,
    required this.onBack,
    required this.onFavorite,
    required this.onDefinition,
    required this.onSpeed,
    required this.onEpisodes,
  });

  final String displayTitle;
  final String epLabel;
  final String status;
  final String definition;
  final String speedLabel;
  final bool favorited;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onDefinition;
  final VoidCallback onSpeed;
  final VoidCallback onEpisodes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: onBack,
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 140,
          child: _SideAction(
            icon: favorited ? Icons.star : Icons.star_border,
            label: favorited ? '已收藏' : '收藏',
            onTap: onFavorite,
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
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 6),
              const Text(
                '上滑下一集 · 下滑上一集',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _PillButton(
                    icon: Icons.high_quality_outlined,
                    label: definition,
                    onTap: onDefinition,
                  ),
                  _PillButton(
                    icon: Icons.speed,
                    label: speedLabel,
                    onTap: onSpeed,
                  ),
                  _PillButton(
                    icon: Icons.grid_view,
                    label: '选集',
                    onTap: onEpisodes,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
