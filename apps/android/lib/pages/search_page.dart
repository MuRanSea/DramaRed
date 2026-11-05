import 'package:flutter/material.dart';

/// 搜索占位。后续接 openhongguo search / suggest / hotSearch。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索短剧（占位）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) {
                // TODO: OhgClient.search(query)
              },
            ),
            const SizedBox(height: 24),
            const Text('TODO: 热搜 / 联想 / 结果列表'),
          ],
        ),
      ),
    );
  }
}
