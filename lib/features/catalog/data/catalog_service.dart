
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../catalog_item.dart';

class CatalogService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<List<CatalogItem>> watchAvailableItems() {
    return _watchItems(
      _firestore.collection('barang').where(
        'statusBarang',
        isEqualTo: 'tersedia',
      ),
    );
  }

  Stream<List<CatalogItem>> watchMyItems(String userId) {
    return _watchItems(
      _firestore.collection('barang').where('userId', isEqualTo: userId),
    );
  }

  Stream<List<CatalogItem>> _watchItems(Query<Map<String, dynamic>> query) {
    return query.snapshots().asyncMap((snapshot) async {
      final kategoriSnapshot = await _firestore.collection('kategori').get();

      final kategoriMap = <String, String>{
        for (final doc in kategoriSnapshot.docs)
          if (doc.data()['namaKategori'] case final String name) doc.id: name,
      };

      final items = <CatalogItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          items.add(CatalogItem.fromFirestore(doc.id, data,
            categoryName: kategoriMap[data['kategoriId']] ?? 'Kategori tidak tersedia',
          ));
        } on FormatException {
          debugPrint('[KATALOG] Dokumen barang ${doc.id} dilewati karena isinya tidak valid.');
        }
      }
      return items;
    });
  }

  Future<Map<String, dynamic>?> getSellerProfile(
      String userId,
      ) async {
    if (userId.trim().isEmpty) {
      return null;
    }

    final sellerSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('public')
        .doc('profile')
        .get();

    return sellerSnapshot.data();
  }

  Stream<CatalogItem?> watchItemById(String barangId) {
    return _firestore
        .collection('barang')
        .doc(barangId)
        .snapshots()
        .asyncMap((snapshot) async {
      final data = snapshot.data();

      if (!snapshot.exists ||
          data == null ||
          data['statusBarang'] != 'tersedia') {
        return null;
      }

      final categoryId = data['kategoriId'];
      final owner = data['userId'];
      if (!CatalogItem.validDocumentId(owner)) return null;
      final category = CatalogItem.validDocumentId(categoryId)
          ? await _firestore.collection('kategori').doc(categoryId as String).get()
          : null;
      final categoryLabel = category?.data()?['namaKategori'];
      final namaKategori = categoryLabel is String ? categoryLabel : 'Kategori tidak tersedia';
      final seller = await getSellerProfile(owner as String);
      final sellerName = seller?['nama'];
      final sellerPhone = seller?['nomorTelepon'];

      return CatalogItem.fromFirestore(
        snapshot.id,
        data,
        categoryName: namaKategori,
        sellerName: sellerName is String ? sellerName : null,
        sellerPhone: sellerPhone is String ? sellerPhone : null,
        isSellerVerified: seller?['isSellerVerified'] == true,
      );
    });
  }
}
