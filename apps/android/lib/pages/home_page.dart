import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import '../pages/search_page.dart';
import '../services/favorites_store.dart';
import '../services/ohg_client.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/status_pane.dart';

/// 首页：竖滑换剧的推荐流。点封面进入播放页后再切集。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<PagedResult<SeriesSummary>> _future;
  final _fav = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
    FavoritesStore().listSeriesIds().then((ids) {
      if (mounted) setState(() => _fav.addAll(ids));
    });
  }

  void _reload() {
    setState(() {
      _future = OhgClient.instance().then((c) => c.discover());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HgColors.bg,
      body: FutureBuilder<PagedResult<SeriesSummary>>(
        future: _future,
        builder: (context, snap) {
          Widget body;
          if (snap.connectionState != ConnectionState.done) {
            body = const Center(child: CircularProgressIndicator());
          } else if (snap.hasError) {
            body = StatusPane.error(error: snap.error, onRetry: _reload);
          } else {
            final items = snap.data?.items ?? const <SeriesSummary>[];
            if (items.isEmpty) {
              body = StatusPane.empty(
                title: '暂时没有推荐',
                detail: '可以下拉刷新，或去剧场找剧。',
                actionLabel: '刷新',
                onAction: _reload,
              );
            } else {
              body = PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final s = items[i];
                  return _FeedCard(
                    series: s,
                    favorited: _fav.contains(s.id),
                    onOpen: () => playSeries(context, series: s),
                    onFavorite: () async {
                      final store = FavoritesStore();
                      if (_fav.contains(s.id)) {
                        await store.remove(s.id);
                        setState(() => _fav.remove(s.id));
                      } else {
                        await store.addSummary(s);
                        setState(() => _fav.add(s.id));
                      }
                    },
                  );
                },
              );
            }
          }
          return Stack(
            children: [
              Positioned.fill(child: body),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  onSearch: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SearchPage()),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '推荐',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  SizedBox(
                    width: 16,
                    height: 2,
                    child: ColoredBox(color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: onSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.series,
    required this.favorited,
    required this.onOpen,
    required this.onFavorite,
  });

  final SeriesSummary series;
  final bool favorited;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  List<String> get _tags {
    final tags = <String>[];
    if (series.episodeCount > 0) tags.add('全${series.episodeCount}集');
    if (series.category.isNotEmpty) {
      tags.addAll(
        series.category.split(RegExp(r'[·/,，\s]+')).where((s) => s.isNotEmpty),
      );
    }
    return tags.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onOpen,
          child: CoverImage(url: series.coverUrl),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xCC000000),
              ],
              stops: [0, 0.22, 0.55, 1],
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: onOpen,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0x66FFFFFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 120,
          child: _SideBtn(
            icon: favorited ? Icons.star : Icons.star_border,
            label: favorited ? '已收藏' : '收藏',
            onTap: onFavorite,
          ),
        ),
        Positioned(
          left: 16,
          right: 72,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onOpen,
                child: Text(
                  '${series.title} ›',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: HgColors.chip,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (series.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  series.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          series.episodeCount > 0
                              ? '观看完整短剧 · 全${series.episodeCount}集'
                              : '进入播放',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideBtn extends StatelessWidget {
  const _SideBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

