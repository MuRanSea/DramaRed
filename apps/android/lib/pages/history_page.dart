import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../services/history_store.dart';
import '../services/ohg_client.dart';
import 'player_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = HistoryStore().list();
    });
  }

  String _fmtPos(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openResume(HistoryEntry e) async {
    List<Episode> episodes = const [];
    if (e.seriesId.isNotEmpty) {
      try {
        final client = await OhgClient.instance();
        final page = await client.listEpisodes(e.seriesId);
        episodes = page.items;
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          title: e.title.isEmpty ? e.seriesId : e.title,
          seriesId: e.seriesId,
          seriesTitle: e.seriesTitle.isEmpty ? e.title : e.seriesTitle,
          episodeId: e.episodeId,
          episodes: episodes,
          initialPositionMs: e.positionMs,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败：${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('重试')),
                ],
              ),
            );
          }
          final items = snap.data ?? const <HistoryEntry>[];
          if (items.isEmpty) {
            return const Center(child: Text('暂无历史'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              final when = e.updatedAt.toLocal();
              return ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(e.title.isEmpty ? e.seriesId : e.title),
                subtitle: Text(
                  '续播 ${_fmtPos(e.positionMs)} · ep=${e.episodeId}\n'
                  '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
                  '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                ),
                isThreeLine: true,
                onTap: () {
                  // ignore: discarded_futures
                  _openResume(e);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await HistoryStore().remove(e.seriesId);
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
