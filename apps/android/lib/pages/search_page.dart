import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../services/ohg_client.dart';
import 'series_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Future<PagedResult<SeriesSummary>>? _future;
  String? _error;

  Future<void> _run(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _error = null;
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
          if (_error != null) Text(_error!),
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
                        return Center(child: Text('搜索失败：${snap.error}'));
                      }
                      final items = snap.data?.items ?? const <SeriesSummary>[];
                      if (items.isEmpty) {
                        return const Center(child: Text('无结果'));
                      }
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final s = items[i];
                          return ListTile(
                            title: Text(s.title),
                            subtitle: Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis),
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
          ),
        ],
      ),
    );
  }
}
