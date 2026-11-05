import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import '../services/ohg_client.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';

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
            hintText: '搜索短剧',
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
          ? const Center(child: Text('输入关键词搜索', style: TextStyle(color: Colors.white54)))
          : FutureBuilder<PagedResult<SeriesSummary>>(
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
                        Text('搜索失败：${snap.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _run(_controller.text),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }
                final items = snap.data?.items ?? const <SeriesSummary>[];
                if (items.isEmpty) {
                  return const Center(child: Text('无结果', style: TextStyle(color: Colors.white54)));
                }
                return GridView.builder(
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
                );
              },
            ),
    );
  }
}
