import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../pages/player_page.dart';
import '../services/ohg_client.dart';

/// Resolve episodes then push the immersive player.
Future<void> playSeries(
  BuildContext context, {
  required SeriesSummary series,
  String? episodeId,
  int initialPositionMs = 0,
  String coverUrl = '',
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final client = await OhgClient.instance();
    final page = await client.listEpisodes(series.id);
    final items = page.items;
    Episode? ep;
    if (episodeId != null && episodeId.isNotEmpty) {
      for (final e in items) {
        if (e.id == episodeId) {
          ep = e;
          break;
        }
      }
    }
    ep ??= _firstPlayable(items);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (ep == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无分集')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          title: '${series.title} · ${ep!.number}',
          seriesId: series.id,
          seriesTitle: series.title,
          episodeId: ep.id,
          episodes: items,
          initialPositionMs: initialPositionMs,
          coverUrl: coverUrl.isNotEmpty ? coverUrl : series.coverUrl,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打开播放失败：$e')),
    );
  }
}

Episode? _firstPlayable(List<Episode> items) {
  for (final e in items) {
    if (e.id.isNotEmpty && e.playable) return e;
  }
  for (final e in items) {
    if (e.id.isNotEmpty) return e;
  }
  return null;
}
