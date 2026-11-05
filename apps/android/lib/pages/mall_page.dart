import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 商城占位（无真实商品数据）。
class MallPage extends StatelessWidget {
  const MallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HgColors.bg,
      appBar: AppBar(title: const Text('商城')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text('商城即将上线', style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 8),
            Text('占位页，暂无商品数据', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
