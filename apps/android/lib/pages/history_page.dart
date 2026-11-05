import 'package:flutter/material.dart';

import '../services/history_store.dart';
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
          final items = snap.data ?? const <HistoryEntry>[];
          if (items.isEmpty) {
            return const Center(child: Text('暂无历史'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final e = items[i];
              return ListTile(
                title: Text(e.title.isEmpty ? e.seriesId : e.title),
                subtitle: Text('续播 ep=${e.episodeId} @ ${e.positionMs}ms'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerPage(
                        title: e.title,
                        seriesId: e.seriesId,
                        episodeId: e.episodeId,
                      ),
                    ),
                  );
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
