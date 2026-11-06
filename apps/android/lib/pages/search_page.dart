import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import '../services/ohg_client.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/status_pane.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Future<PagedResult<SeriesSummary>>? _future;

  Future<void> _run(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _future = OhgClient.instance().then((c) => c.search(query));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HgColors.bg,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '搜剧名 / 关键词',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _run,
        ),
        actions: [
          TextButton(
            onPressed: () => _run(_controller.text),
            child: const Text('搜索'),
          ),
        ],
      ),
      body: _future == null
          ? StatusPane.empty(
              title: '搜索短剧',
              detail: '输入剧名、演员或关键词，回车即可。',
              actionLabel: '去剧场逛逛',
              onAction: () => Navigator.of(context).maybePop(),
            )
          : FutureBuilder<PagedResult<SeriesSummary>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return StatusPane.error(
                    error: snap.error,
                    onRetry: () => _run(_controller.text),
                  );
                }
                final items = snap.data?.items ?? const <SeriesSummary>[];
                if (items.isEmpty) {
                  return StatusPane.empty(
                    title: '没有找到相关短剧',
                    detail: '换个关键词试试，或去剧场浏览推荐。',
                    actionLabel: '去剧场逛逛',
                    onAction: () => Navigator.of(context).maybePop(),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
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
                );
              },
            ),
    );
  }
}
