import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import 'cover_image.dart';

/// 三列竖海报：封面 + 标题 + 副标题（进度/集数）。
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.onTap,
    this.coverUrl = '',
    this.subtitle = '',
    this.badge = '',
    this.light = false,
  });

  final String title;
  final String coverUrl;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;
  final bool light;

  factory PosterCard.fromSeries({
    required SeriesSummary series,
    required VoidCallback onTap,
    String subtitle = '',
    bool light = false,
  }) {
    return PosterCard(
      title: series.title,
      coverUrl: series.coverUrl,
      subtitle: subtitle.isNotEmpty
          ? subtitle
          : (series.episodeCount > 0 ? '全${series.episodeCount}集' : ''),
      badge: series.category,
      onTap: onTap,
      light: light,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? const Color(0xFF1A1A1A) : Colors.white;
    final subColor = light ? const Color(0xFF8A8A8A) : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: coverUrl,
                  borderRadius: BorderRadius.circular(8),
                ),
                if (badge.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subColor, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
