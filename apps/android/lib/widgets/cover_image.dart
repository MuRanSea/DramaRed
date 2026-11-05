import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final child = url.trim().isEmpty
        ? const ColoredBox(
            color: Color(0xFF2A2A2E),
            child: Center(
              child: Icon(Icons.movie_outlined, color: Colors.white54, size: 36),
            ),
          )
        : Image.network(
            url,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFF2A2A2E),
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white54),
              ),
            ),
          );
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}
