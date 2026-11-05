import 'package:flutter/material.dart';

/// 播放页占位：清晰度、倍速、自动连播、定时停止 UI 壳。
/// 实际解码交给 media_kit；ClearKey / 后台继续听仅预留。
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.episodeId,
  });

  final String title;
  final String episodeId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  String _definition = '自动';
  double _speed = 1.0;
  bool _autoNext = true;

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
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Text('media_kit 视频区占位'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('清晰度'),
            trailing: DropdownButton<String>(
              value: _definition,
              items: const [
                DropdownMenuItem(value: '自动', child: Text('自动')),
                DropdownMenuItem(value: '1080P', child: Text('1080P')),
                DropdownMenuItem(value: '720P', child: Text('720P')),
                DropdownMenuItem(value: '540P', child: Text('540P')),
              ],
              onChanged: (v) => setState(() => _definition = v ?? '自动'),
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
              onChanged: (v) => setState(() => _speed = v ?? 1.0),
            ),
          ),
          SwitchListTile(
            title: const Text('自动连播'),
            value: _autoNext,
            onChanged: (v) => setState(() => _autoNext = v),
          ),
          const ListTile(
            title: Text('定时停止'),
            subtitle: Text('TODO: 定时器占位'),
          ),
          const ListTile(
            title: Text('后台 / 隐藏继续听'),
            subtitle: Text('TODO: 音频会话 / media_kit 后台预留'),
          ),
          Text('episodeId: ${widget.episodeId.isEmpty ? "(empty)" : widget.episodeId}'),
        ],
      ),
    );
  }
}
