import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import '../services/ohg_client.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/status_pane.dart';

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
      _future = OhgClient.instance().then((c) => c.discoverResilient());
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
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
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
            return StatusPane.error(error: snap.error, onRetry: _reload);
          }
          final items = snap.data?.items ?? const <SeriesSummary>[];
          if (items.isEmpty) {
            return StatusPane.empty(
              title: '剧场暂无内容',
              detail: '稍后再试，或去搜索找剧。',
              actionLabel: '重试',
              onAction: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
                childAspectRatio: 0.50,
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
