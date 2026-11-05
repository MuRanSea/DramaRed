import 'package:flutter/material.dart';

import '../services/favorites_store.dart';
import '../widgets/series_tile.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<FavoriteEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = FavoritesStore().list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: FutureBuilder<List<FavoriteEntry>>(
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
          final items = snap.data ?? const <FavoriteEntry>[];
          if (items.isEmpty) {
            return const Center(child: Text('暂无收藏'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              return SeriesTile(
                series: e.toSummary(),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await FavoritesStore().remove(e.seriesId);
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
