import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import '../pages/search_page.dart';
import '../services/ohg_client.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';

/// 剧场：三列竖海报找剧（原「书城」列表）。
class TheaterPage extends StatefulWidget {
  const TheaterPage({super.key});

  @override
  State<TheaterPage> createState() => _TheaterPageState();
}

class _TheaterPageState extends State<TheaterPage> {
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
      backgroundColor: HgColors.bg,
      appBar: AppBar(
        title: const Text('剧场'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              );
            },
          ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败\n${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('重试')),
                ],
              ),
            );
          }
          final items = snap.data?.items ?? const <SeriesSummary>[];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('暂无剧集'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reload, child: const Text('刷新')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
                childAspectRatio: 0.48,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final s = items[i];
                return PosterCard.fromSeries(
                  series: s,
                  onTap: () => playSeries(context, series: s),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
