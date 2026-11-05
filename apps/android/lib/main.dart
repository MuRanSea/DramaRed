import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'pages/favorites_page.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/smoke_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit must init before creating Player (Android/iOS/desktop).
  MediaKit.ensureInitialized();
  final smoke = await resolveSmokeLaunch();
  runApp(DramaRedApp(smoke: smoke));
}

class DramaRedApp extends StatelessWidget {
  const DramaRedApp({super.key, this.smoke});

  final SmokeLaunch? smoke;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DramaRed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: smoke == null
          ? const RootShell()
          : SmokePage(
              initialQuery: smoke!.query,
              observeSeconds: smoke!.seconds,
              directUrl: smoke!.directUrl,
            ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    SearchPage(),
    FavoritesPage(),
    HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: Column(
        children: [
          if (!isMobile)
            MaterialBanner(
              content: const Text(
                'openhongguo 仅支持 Android/iOS。当前平台可浏览 UI，业务 API 会失败。',
              ),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: const Text('知道了'),
                ),
              ],
            ),
          Expanded(child: IndexedStack(index: _index, children: _pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: '收藏'),
          NavigationDestination(icon: Icon(Icons.history), label: '历史'),
        ],
      ),
    );
  }
}
