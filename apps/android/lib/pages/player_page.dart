import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/history_store.dart';
import '../services/ohg_client.dart';
import '../services/player_controller.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.episodeId,
    this.seriesId = '',
  });

  final String title;
  final String episodeId;
  final String seriesId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerController _controller;
  late final VideoController _video;
  String _definition = '自动';
  double _speed = 1.0;
  bool _autoNext = true;
  String _status = '解析播放地址…';
  List<String> _definitions = const ['自动'];

  @override
  void initState() {
    super.initState();
    _controller = PlayerController();
    _video = VideoController(_controller.player);
    _load();
  }

  Future<void> _load() async {
    if (widget.episodeId.isEmpty) {
      setState(() => _status = '缺少 episodeId');
      return;
    }
    try {
      final client = await OhgClient.instance();
      final result = await client.resolvePlayback(widget.episodeId);
      final defs = result.playback.streams
          .where((s) => s.url.isNotEmpty)
          .map((s) => s.definition.isEmpty ? s.quality : s.definition)
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      setState(() {
        _definitions = ['自动', ...defs];
        _status = result.playback.protected
            ? '受保护流（尝试 ClearKey/decryption_key）'
            : '开始播放';
      });
      await _controller.openPlayback(result, preferDefinition: _definition);
      await HistoryStore().upsert(
        HistoryEntry(
          seriesId: widget.seriesId,
          episodeId: widget.episodeId,
          title: widget.title,
          positionMs: 0,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      setState(() => _status = '播放失败：$e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Video(controller: _video),
            ),
          ),
          const SizedBox(height: 8),
          Text(_status),
          ListTile(
            title: const Text('清晰度'),
            trailing: DropdownButton<String>(
              value: _definitions.contains(_definition) ? _definition : '自动',
              items: _definitions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) async {
                setState(() => _definition = v ?? '自动');
                await _load();
              },
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
            value: _autoNext,
            onChanged: (v) => setState(() => _autoNext = v),
          ),
          const ListTile(
            title: Text('定时停止'),
            subtitle: Text('UI 预留；未实现计时器'),
          ),
          const ListTile(
            title: Text('后台 / 隐藏继续听'),
            subtitle: Text('预留：音频会话 / media_kit 后台'),
          ),
        ],
      ),
    );
  }
}
