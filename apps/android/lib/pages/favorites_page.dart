import 'package:flutter/material.dart';

import '../services/favorites_store.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = FavoritesStore().listSeriesIds());
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
      body: FutureBuilder<List<String>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snap.data ?? const <String>[];
          if (ids.isEmpty) {
            return const Center(child: Text('暂无收藏'));
          }
          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, i) {
              final id = ids[i];
              return ListTile(
                title: Text(id),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await FavoritesStore().remove(id);
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
