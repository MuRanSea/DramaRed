import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Poster image that tolerates OHG HEIC covers (desktop uses ffmpeg; Android
/// decodes via BitmapFactory on API 28+ through a MethodChannel).
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  static bool looksHeic(String url) {
    final low = url.toLowerCase();
    return low.contains('.heic') || low.contains('.heif');
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    final child = trimmed.isEmpty
        ? const _CoverPlaceholder(icon: Icons.movie_outlined)
        : looksHeic(trimmed)
            ? _HeicCover(url: trimmed, fit: fit)
            : Image.network(
                trimmed,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _CoverPlaceholder(icon: Icons.movie_outlined);
                },
                errorBuilder: (_, __, ___) =>
                    const _CoverPlaceholder(icon: Icons.broken_image_outlined),
              );
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2A2A2E),
      child: Center(child: Icon(icon, color: Colors.white54, size: 36)),
    );
  }
}

class _HeicCover extends StatefulWidget {
  const _HeicCover({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  State<_HeicCover> createState() => _HeicCoverState();
}

class _HeicCoverState extends State<_HeicCover> {
  static const _channel = MethodChannel('com.dramared.app/covers');
  static final _memoryCache = <String, Uint8List>{};

  Uint8List? _png;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _HeicCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _png = null;
      _error = null;
      _loading = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final cached = _memoryCache[widget.url];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _png = cached;
        _loading = false;
        _error = null;
      });
      return;
    }
    try {
      final bytes = await _download(widget.url);
      final png = await _channel.invokeMethod<Uint8List>('decodeToPng', bytes);
      if (png == null || png.isEmpty) {
        throw StateError('empty png from decoder');
      }
      _memoryCache[widget.url] = png;
      // Cap memory cache roughly.
      if (_memoryCache.length > 64) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      if (!mounted) return;
      setState(() {
        _png = png;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('[CoverImage] heic decode failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  static Future<Uint8List> _download(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'DramaRed/0.1');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _CoverPlaceholder(icon: Icons.movie_outlined);
    }
    final png = _png;
    if (png == null || _error != null) {
      return const _CoverPlaceholder(icon: Icons.broken_image_outlined);
    }
    return Image.memory(
      png,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
  }
}
