import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 统一空态 / 错误态：标题 + 一句说明 + 主操作，避免甩技术异常原文。
class StatusPane extends StatelessWidget {
  const StatusPane({
    super.key,
    required this.title,
    this.detail,
    this.actionLabel = '重试',
    this.onAction,
    this.icon = Icons.inbox_outlined,
    this.light = false,
  });

  factory StatusPane.error({
    required Object? error,
    required VoidCallback onRetry,
    bool light = false,
  }) {
    return StatusPane(
      title: '暂时无法加载',
      detail: friendlyError(error),
      actionLabel: '重试',
      onAction: onRetry,
      icon: Icons.wifi_tethering_error_rounded,
      light: light,
    );
  }

  factory StatusPane.empty({
    required String title,
    String? detail,
    String actionLabel = '刷新',
    VoidCallback? onAction,
    bool light = false,
  }) {
    return StatusPane(
      title: title,
      detail: detail,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: Icons.movie_filter_outlined,
      light: light,
    );
  }

  final String title;
  final String? detail;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  final bool light;

  /// User-facing playback failure — never leaks ClearKey / DRM jargon.
  static const playFailedFriendly = '暂时无法播放，请换一集或稍后重试';

  static String friendlyError(Object? error) {
    final raw = '$error';
    final low = raw.toLowerCase();
    if (_looksLikeDrmJargon(low) || raw.contains('受保护')) {
      return playFailedFriendly;
    }
    if (low.contains('socket') || low.contains('network') || low.contains('failed host')) {
      return '网络不通，请检查连接后重试';
    }
    if (low.contains('timeout')) {
      return '请求超时，请稍后重试';
    }
    if (low.contains('502') || low.contains('bad gateway')) {
      return '服务暂时繁忙，请稍后重试';
    }
    if (low.contains('anonymous') || low.contains('empty')) {
      return '推荐暂时没有内容，可刷新或去剧场看看';
    }
    // 截断过长技术细节，保留可读首句
    final oneLine = raw.replaceAll('\n', ' ').trim();
    if (oneLine.length > 96) {
      return '${oneLine.substring(0, 96)}…';
    }
    if (oneLine.isEmpty || oneLine == 'null') {
      return '出了点问题，请重试';
    }
    return oneLine;
  }

  static bool _looksLikeDrmJargon(String low) {
    return low.contains('clearkey') ||
        low.contains('decryption_key') ||
        low.contains('decryption') ||
        low.contains('drm') ||
        low.contains('protected stream') ||
        low.contains('cenc');
  }

  /// Map player status / exceptions to silent UX copy (PR #25 follow-up).
  static String friendlyPlaybackStatus(String? statusOrError) {
    final raw = (statusOrError ?? '').trim();
    if (raw.isEmpty) return playFailedFriendly;
    final low = raw.toLowerCase();
    if (_looksLikeDrmJargon(low) ||
        raw.contains('受保护') ||
        raw.contains('ClearKey') ||
        raw.contains('解密')) {
      return playFailedFriendly;
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? HgColors.mineText : Colors.white;
    final detailColor = light ? HgColors.mineMuted : Colors.white70;
    final cardBg = light ? HgColors.mineCard : HgColors.bgElevated;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: light ? const Color(0x11000000) : const Color(0x22FFFFFF)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: HgColors.accent.withOpacity(0.9)),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null && detail!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      detail!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: detailColor, fontSize: 13, height: 1.4),
                    ),
                  ],
                  if (onAction != null) ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: HgColors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
