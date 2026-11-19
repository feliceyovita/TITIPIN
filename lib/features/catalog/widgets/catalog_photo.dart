
import 'package:flutter/material.dart';
import '../catalog_item.dart';

class CatalogPhoto extends StatelessWidget {
  const CatalogPhoto({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String source;
  final BoxFit fit;
  final String? semanticLabel;

  Widget _placeholder() {
    return Image.asset(
      CatalogItem.placeholderAsset,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (_, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 42,
            color: Color(0xFF506D54),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageSource = source.trim();

    if (imageSource.isEmpty) {
      return _placeholder();
    }

    if (imageSource.startsWith('https://')) {
      return Image.network(
        imageSource,
        fit: fit,
        semanticLabel: semanticLabel,

        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF506D54),
            ),
          );
        },

        errorBuilder: (_, error, stackTrace) {
          return _placeholder();
        },
      );
    }

    return Image.asset(
      imageSource,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (_, error, stackTrace) {
        return _placeholder();
      },
    );
  }
}
