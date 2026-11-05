import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import '../pages/search_page.dart';
import '../services/favorites_store.dart';
import '../services/ohg_client.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';

/// 首页：竖滑沉浸推荐流（红果风格），点进全屏播放。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _tabs = ['剧', '关注', '漫剧', '真人剧', '推荐'];
  int _tab = 4; // 推荐
  late Future<PagedResult<SeriesSummary>> _future;
  final _fav = <String>{};
  final _liked = <String>{};

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

  List<SeriesSummary> _filter(List<SeriesSummary> items) {
    switch (_tabs[_tab]) {
      case '关注':
        return const [];
      case '漫剧':
        return items
            .where((s) =>
                s.category.contains('漫') ||
                s.title.contains('漫') ||
                s.description.contains('漫'))
            .toList();
      case '真人剧':
        return items
            .where((s) =>
                !s.category.contains('漫') && !s.title.contains('漫'))
            .toList();
      default:
        return items;
    }
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
            body = _ErrorPane(error: snap.error, onRetry: _reload);
          } else {
            final items = _filter(snap.data?.items ?? const <SeriesSummary>[]);
            if (_tabs[_tab] == '关注') {
              body = const _EmptyPane(message: '暂无关注（占位）');
            } else if (items.isEmpty) {
              body = _EmptyPane(
                message: '暂无内容',
                action: '刷新',
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
                    liked: _liked.contains(s.id),
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
                    onLike: () => setState(() {
                      if (!_liked.add(s.id)) _liked.remove(s.id);
                    }),
                    onComment: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('评论占位')),
                      );
                    },
                    onShare: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('分享「${s.title}」占位')),
                      );
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
                  tabs: _tabs,
                  index: _tab,
                  onSelect: (i) => setState(() => _tab = i),
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
  const _TopBar({
    required this.tabs,
    required this.index,
    required this.onSelect,
    required this.onSearch,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelect;
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
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 18),
                  itemBuilder: (context, i) {
                    final selected = i == index;
                    return GestureDetector(
                      onTap: () => onSelect(i),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tabs[i],
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: selected ? 18 : 16,
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 16,
                              height: 2,
                              color: selected ? Colors.white : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
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
    required this.liked,
    required this.onOpen,
    required this.onFavorite,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  final SeriesSummary series;
  final bool favorited;
  final bool liked;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

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
          top: MediaQuery.of(context).padding.top + 88,
          right: 16,
          child: GestureDetector(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fullscreen, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('全屏观看', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 120,
          child: Column(
            children: [
              _SideBtn(
                icon: favorited ? Icons.star : Icons.star_border,
                label: favorited ? '已收藏' : '收藏',
                onTap: onFavorite,
              ),
              const SizedBox(height: 18),
              _SideBtn(icon: Icons.chat_bubble_outline, label: '评论', onTap: onComment),
              const SizedBox(height: 18),
              _SideBtn(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: liked ? '已赞' : '赞',
                onTap: onLike,
              ),
              const SizedBox(height: 18),
              _SideBtn(icon: Icons.reply, label: '分享', onTap: onShare),
            ],
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
              const SizedBox(height: 6),
              Text(
                series.author.isNotEmpty ? '作者：${series.author}' : '作者声明：内容来自开放源',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
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
                              : '观看完整短剧',
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

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败\n$error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
            const SizedBox(height: 8),
            const Text(
              '需 Android/iOS；模拟器需可出网才能拉推荐。',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.message, this.action, this.onAction});
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.white70)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
