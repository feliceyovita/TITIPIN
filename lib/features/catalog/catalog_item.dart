
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
    return CatalogItem(
      id: documentId,
      name: data['namaBarang'] as String,
      price: data['harga'] as int,
      category: categoryName,
      categoryId: data['kategoriId'] as String,
      condition: data['kondisi'] as String,
      location: data['lokasi'] as String,
      description: data['deskripsi'] as String,
      status: data['statusBarang'] as String,
      userId: data['userId'] as String,
      fotoBarang: (data['fotoBarang'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      isSellerVerified: isSellerVerified,
    );
  }
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
