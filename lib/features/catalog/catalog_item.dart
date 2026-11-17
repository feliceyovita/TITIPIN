class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.condition,
    this.imageAsset,
    this.imageAssets = const [],
    this.location = 'Belum dicantumkan',
    this.description = 'Deskripsi belum tersedia.',
    this.sellerName,
    this.isSellerVerified = false,
  });

  static const placeholderAsset =
      'assets/images/catalog/box_placeholder.png';

  final String id;
  final String name;
  final int price;
  final String category;
  final String condition;
  final String? imageAsset;
  final List<String> imageAssets;
  final String location;
  final String description;
  final String? sellerName;
  final bool isSellerVerified;

  List<String> get galleryAssets {
    if (imageAssets.isNotEmpty) return imageAssets;

    final singlePhoto = imageAsset?.trim();
    return [
      if (singlePhoto == null || singlePhoto.isEmpty)
        placeholderAsset
      else
        singlePhoto,
    ];
  }

  String get formattedPrice {
    final amount = price.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
    );
    return 'Rp$amount';
  }
}