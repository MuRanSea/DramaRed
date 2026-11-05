import 'package:flutter/material.dart';

import '../navigation/play_nav.dart';
import '../pages/search_page.dart';
import '../services/favorites_store.dart';
import '../services/history_store.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import 'player_page.dart';
import '../services/ohg_client.dart';
import 'package:openhongguo/openhongguo.dart';

/// 「我的」：头像资料 + 作品/历史/收藏等 Tab + 三列海报网格。
class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  static const _tabs = ['作品', '历史', '收藏', '点赞', '预约'];
  int _tab = 1; // 历史
  int _filter = 0; // 0全部 1已看完 2未看完
  late Future<List<HistoryEntry>> _history;
  late Future<List<FavoriteEntry>> _favorites;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _history = HistoryStore().list();
      _favorites = FavoritesStore().list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HgColors.mineBg,
      body: SafeArea(
        child: Column(
          children: [
            const _ProfileHeader(),
            const _ShortcutRow(),
            _TabRow(
              tabs: _tabs,
              index: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
            if (_tab == 1) _FilterRow(index: _filter, onSelect: (i) => setState(() => _filter = i)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tabs[_tab]) {
      case '历史':
        return _HistoryGrid(future: _history, filter: _filter, onChanged: _reload);
      case '收藏':
        return _FavoritesGrid(future: _favorites, onChanged: _reload);
      default:
        return Center(
          child: Text('暂无${_tabs[_tab]}（占位）', style: const TextStyle(color: HgColors.mineMuted)),
        );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFE8E0D4),
                child: Icon(Icons.person, color: Color(0xFF8A7A60), size: 32),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DramaRed 用户',
                      style: TextStyle(
                        color: HgColors.mineText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('红果号：guest', style: TextStyle(color: HgColors.mineMuted, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.mail_outline, color: HgColors.mineText),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('消息占位')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.menu, color: HgColors.mineText),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const _Stat(value: '0', label: '关注'),
              const SizedBox(width: 24),
              const _Stat(value: '0', label: '粉丝'),
              const SizedBox(width: 24),
              const _Stat(value: '0', label: '获赞'),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('编辑资料占位')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: HgColors.mineText,
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('编辑资料'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HgColors.mineText)),
        Text(label, style: const TextStyle(fontSize: 12, color: HgColors.mineMuted)),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow();

  @override
  Widget build(BuildContext context) {
    Widget card(IconData icon, String title, String sub) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: HgColors.mineCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: HgColors.accent),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: HgColors.mineText)),
              Text(sub, style: const TextStyle(fontSize: 11, color: HgColors.mineMuted)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          card(Icons.card_giftcard_outlined, '福利', '去领取'),
          card(Icons.receipt_long_outlined, '订单', '查看订单'),
          card(Icons.sports_esports_outlined, '游戏', '来玩'),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tabs, required this.index, required this.onSelect});
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontSize: i == index ? 18 : 15,
                    fontWeight: i == index ? FontWeight.w800 : FontWeight.w400,
                    color: i == index ? HgColors.mineText : HgColors.mineMuted,
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: HgColors.mineMuted),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(int i, String label) {
      final on = i == index;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onSelect(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFFF1E8) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: on ? HgColors.accent : HgColors.mineMuted,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          chip(0, '全部'),
          chip(1, '已看完'),
          chip(2, '未看完'),
        ],
      ),
    );
  }
}

class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({required this.future, required this.filter, required this.onChanged});
  final Future<List<HistoryEntry>> future;
  final int filter;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HistoryEntry>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        var items = snap.data ?? const <HistoryEntry>[];
        if (filter == 1) {
          items = items.where((e) => e.episodeCount > 0 && e.episodeNumber >= e.episodeCount).toList();
        } else if (filter == 2) {
          items = items.where((e) => e.episodeCount == 0 || e.episodeNumber < e.episodeCount).toList();
        }
        if (items.isEmpty) {
          return const Center(child: Text('暂无历史', style: TextStyle(color: HgColors.mineMuted)));
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
            final e = items[i];
            final title = e.seriesTitle.isNotEmpty ? e.seriesTitle : (e.title.isNotEmpty ? e.title : e.seriesId);
            String sub;
            if (e.episodeNumber > 0 && e.episodeCount > 0) {
              sub = '${e.episodeNumber}集/${e.episodeCount}集';
            } else if (e.episodeNumber > 0) {
              sub = '已看到第${e.episodeNumber}集';
            } else {
              sub = '继续观看';
            }
            return PosterCard(
              title: title,
              coverUrl: e.coverUrl,
              subtitle: sub,
              light: true,
              onTap: () async {
                List<Episode> episodes = const [];
                if (e.seriesId.isNotEmpty) {
                  try {
                    final client = await OhgClient.instance();
                    episodes = (await client.listEpisodes(e.seriesId)).items;
                  } catch (_) {}
                }
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerPage(
                      title: e.title.isEmpty ? e.seriesId : e.title,
                      seriesId: e.seriesId,
                      seriesTitle: e.seriesTitle.isEmpty ? e.title : e.seriesTitle,
                      episodeId: e.episodeId,
                      episodes: episodes,
                      initialPositionMs: e.positionMs,
                      coverUrl: e.coverUrl,
                    ),
                  ),
                );
                onChanged();
              },
            );
          },
        );
      },
    );
  }
}

class _FavoritesGrid extends StatelessWidget {
  const _FavoritesGrid({required this.future, required this.onChanged});
  final Future<List<FavoriteEntry>> future;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FavoriteEntry>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <FavoriteEntry>[];
        if (items.isEmpty) {
          return const Center(child: Text('暂无收藏', style: TextStyle(color: HgColors.mineMuted)));
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
            final e = items[i];
            final s = e.toSummary();
            return PosterCard.fromSeries(
              series: s,
              light: true,
              onTap: () => playSeries(context, series: s).then((_) => onChanged()),
            );
          },
        );
      },
    );
  }
}
