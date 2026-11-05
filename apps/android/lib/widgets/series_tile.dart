import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../pages/series_page.dart';

/// Shared book-store / search / favorites row with cover thumb and SeriesPage nav.
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
    final cover = series.coverUrl.trim();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 56,
          height: 74,
          child: cover.isEmpty
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_outlined),
                )
              : Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
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
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SeriesPage(series: series),
          ),
        );
      },
    );
  }
}
