import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../services/ohg_client.dart';
import '../widgets/series_tile.dart';

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
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索短剧',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _run(_controller.text),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _run,
            ),
          ),
          Expanded(
            child: _future == null
                ? const Center(child: Text('输入关键词搜索'))
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
                        return const Center(child: Text('无结果'));
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => SeriesTile(series: items[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
