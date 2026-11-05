import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'pages/smoke_page.dart';
import 'pages/theater_page.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.dark,
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
    TheaterPage(),
    MinePage(),
  ];

  bool get _mine => _index == 2;

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: _mine ? HgColors.mineBg : HgColors.bg,
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
      bottomNavigationBar: _HgBottomNav(
        index: _index,
        light: _mine,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _HgBottomNav extends StatelessWidget {
  const _HgBottomNav({
    required this.index,
    required this.light,
    required this.onSelect,
  });

  final int index;
  final bool light;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bg = light ? HgColors.navLight : HgColors.navDark;
    final selected = light ? HgColors.mineText : Colors.white;
    final muted = light ? HgColors.mineMuted : Colors.white54;
    const items = [
      (Icons.home_outlined, Icons.home, '首页'),
      (Icons.grid_view_outlined, Icons.grid_view, '剧场'),
      (Icons.person_outline, Icons.person, '我的'),
    ];
    return ColoredBox(
      color: bg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? items[i].$2 : items[i].$1,
                          color: i == index ? selected : muted,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == index ? selected : muted,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
