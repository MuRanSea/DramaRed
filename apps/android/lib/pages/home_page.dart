import 'package:flutter/material.dart';

/// 书城 / 推荐入口占位。后续接 openhongguo discover。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DramaRed · 书城')),
      body: const Center(
        child: Text(
          '推荐 / 书城占位\nTODO: OhgClient.discover()',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
