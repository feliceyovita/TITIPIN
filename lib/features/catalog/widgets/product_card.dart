import 'package:flutter/material.dart';

import '../catalog_item.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.item,
    required this.isSaved,
    required this.onToggleSaved,
    this.onTap,
  });

  final CatalogItem item;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback? onTap;

  static const _accent = Color(0xFF3C6247);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final coverAsset = item.galleryAssets.first;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD9E6F2)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    coverAsset,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, error, stackTrace) {
                      debugPrint('[KATALOG] Gagal memuat $coverAsset: $error');
                      return _placeholder();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isSaved ? 'Batal simpan' : 'Simpan barang',
                    isSelected: isSaved,
                    selectedIcon: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                    ),
                    icon: const Icon(Icons.favorite_border),
                    onPressed: onToggleSaved,
                  ),
                ],
              ),
              Text(
                item.formattedPrice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE1ECE1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    item.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(color: _accent),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.condition,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: Color(0xFFF5F7F5),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 42,
          color: _accent,
        ),
      ),
    );
  }
}