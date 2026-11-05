import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../services/ohg_client.dart';
import 'series_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<PagedResult<SeriesSummary>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = OhgClient.instance().then((c) => c.discover());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DramaRed · 书城'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: FutureBuilder<PagedResult<SeriesSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败（需 Android/iOS 真机或模拟器）\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final items = snap.data?.items ?? const <SeriesSummary>[];
          if (items.isEmpty) {
            return const Center(child: Text('推荐为空'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final s = items[i];
              return ListTile(
                title: Text(s.title),
                subtitle: Text('${s.episodeCount} 集 · ${s.category}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SeriesPage(series: s),
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
