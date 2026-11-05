import 'package:flutter/material.dart';

import '../services/playback_policies.dart';

/// Vertical swipe / pager used by the immersive player.
///
/// Each page builds its own overlay via [overlayBuilder] so a cached
/// neighbor page never reuses the same widget instance.
class EpisodeSwipeShell extends StatelessWidget {
  const EpisodeSwipeShell({
    super.key,
    required this.episodeCount,
    required this.controller,
    required this.onPageChanged,
    required this.onSwipeNext,
    required this.onSwipePrev,
    required this.onTap,
    required this.overlayBuilder,
  });

  final int episodeCount;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onSwipeNext;
  final VoidCallback onSwipePrev;
  final VoidCallback onTap;
  final WidgetBuilder overlayBuilder;

  static const singleKey = Key('episode-swipe-single');
  static const pagerKey = Key('episode-swipe-pager');

  @override
  Widget build(BuildContext context) {
    if (episodeCount <= 1) {
      return GestureDetector(
        key: singleKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragEnd: (details) {
          final dir = PlaybackPolicies.swipeDirection(
            details.primaryVelocity ?? 0,
          );
          if (dir > 0) onSwipeNext();
          if (dir < 0) onSwipePrev();
        },
        child: overlayBuilder(context),
      );
    }
    return PageView.builder(
      key: pagerKey,
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: episodeCount,
      onPageChanged: onPageChanged,
      itemBuilder: (context, i) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: overlayBuilder(context),
        );
      },
    );
  }
}
