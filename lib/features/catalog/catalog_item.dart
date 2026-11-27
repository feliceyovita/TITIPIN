import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.sellerPhone,
    this.isSellerVerified = false,
    this.categoryId = '',
    this.status = 'tersedia',
    this.userId = '',
    this.fotoBarang = const [],
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
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
  final String? sellerPhone;
  final bool isSellerVerified;

  final String categoryId;
  final String status;
  final String userId;
  final List<Map<String, dynamic>> fotoBarang;
  final List<String> tags;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory CatalogItem.fromFirestore(
      String documentId,
      Map<String, dynamic> data, {
        required String categoryName,
        String? sellerName,
        String? sellerPhone,
        bool isSellerVerified = false,
      }) {
    String text(String key, [String fallback = '']) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
    }

    final name = text('namaBarang');
    final amount = data['harga'];
    final status = text('statusBarang');
    final owner = text('userId');
    if (name.isEmpty || amount is! num || !amount.isFinite || amount <= 0 ||
        amount != amount.truncate() || !{'tersedia', 'terjual'}.contains(status) ||
        !validDocumentId(owner)) {
      throw const FormatException('Nama, harga, status, atau pemilik barang tidak valid.');
    }
    final photos = data['fotoBarang'];
    final tags = data['tags'];
    return CatalogItem(
      id: documentId,
      name: name,
      price: amount.toInt(),
      category: categoryName,
      categoryId: text('kategoriId'),
      condition: text('kondisi', 'Belum dicantumkan'),
      location: text('lokasi', 'Belum dicantumkan'),
      description: text('deskripsi', 'Deskripsi belum tersedia.'),
      status: status,
      userId: owner,
      fotoBarang: photos is List ? photos.whereType<Map<String, dynamic>>().toList() : [],
      tags: tags is List ? tags.whereType<String>().toList() : [],
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : null,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      isSellerVerified: isSellerVerified,
    );
  }
  static bool validDocumentId(Object? value) =>
      value is String && value.trim().isNotEmpty && !value.contains('/') &&
          value != '.' && value != '..';

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
    if (price <= 0) return 'Harga tidak tersedia';
    final amount = price.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
    );

    return 'Rp$amount';
  }
  List<String> get photoUrls {
    return fotoBarang
        .map((foto) => foto['url'])
        .whereType<String>()
        .map((url) => url.trim())
        .where((url) {
      final uri = Uri.tryParse(url);

      return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty;
    })
        .toList();
  }
  List<String> get galleryPhotoSources {
    if (photoUrls.isNotEmpty) {
      return photoUrls;
    }

    return galleryAssets;
  }
  String get primaryPhotoSource {
    return galleryPhotoSources.first;
  }
}