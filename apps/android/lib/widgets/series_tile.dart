import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../navigation/play_nav.dart';
import 'cover_image.dart';

/// Shared row with cover thumb; tap opens the immersive player.
class SeriesTile extends StatelessWidget {
  const SeriesTile({
    super.key,
    required this.series,
    this.trailing,
  });

  final SeriesSummary series;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SizedBox(
        width: 56,
        height: 74,
        child: CoverImage(
          url: series.coverUrl,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      title: Text(series.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (series.episodeCount > 0) '${series.episodeCount} 集',
          if (series.category.isNotEmpty) series.category,
          if (series.author.isNotEmpty) series.author,
          if (series.description.isNotEmpty) series.description,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: () => playSeries(context, series: series),
    );
  }
}
