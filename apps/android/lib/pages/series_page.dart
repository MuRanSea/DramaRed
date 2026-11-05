import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../services/favorites_store.dart';
import '../services/ohg_client.dart';
import 'player_page.dart';

class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key, required this.series});

  final SeriesSummary series;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  late Future<PagedResult<Episode>> _future;
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _future = OhgClient.instance().then((c) => c.listEpisodes(widget.series.id));
    FavoritesStore().contains(widget.series.id).then((v) {
      if (mounted) setState(() => _fav = v);
    });
  }

  Future<void> _toggleFav() async {
    final store = FavoritesStore();
    if (_fav) {
      await store.remove(widget.series.id);
    } else {
      await store.add(widget.series.id);
    }
    setState(() => _fav = !_fav);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.title),
        actions: [
          IconButton(
            icon: Icon(_fav ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: FutureBuilder<PagedResult<Episode>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('分集加载失败：${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _future = OhgClient.instance()
                              .then((c) => c.listEpisodes(widget.series.id));
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snap.data?.items ?? const <Episode>[];
          if (items.isEmpty) {
            return const Center(child: Text('暂无分集'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final ep = items[i];
              return ListTile(
                leading: Text('${ep.number}'),
                title: Text(ep.title.isEmpty ? '第 ${ep.number} 集' : ep.title),
                subtitle: Text(ep.playable ? '可播放' : '不可播放'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerPage(
                        title: '${widget.series.title} · ${ep.number}',
                        seriesId: widget.series.id,
                        seriesTitle: widget.series.title,
                        episodeId: ep.id,
                        episodes: items,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
