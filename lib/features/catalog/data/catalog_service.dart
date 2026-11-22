
import 'package:cloud_firestore/cloud_firestore.dart';
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
          doc.id: doc.data()['namaKategori'] as String,
      };

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final kategoriId = data['kategoriId'] as String;

        return CatalogItem.fromFirestore(
          doc.id,
          data,
          categoryName: kategoriMap[kategoriId] ??
              'Kategori tidak tersedia',
        );
      }).toList();
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

      final kategoriId = data['kategoriId'] as String;

      final kategoriSnapshot = await _firestore
          .collection('kategori')
          .doc(kategoriId)
          .get();

      final namaKategori =
          kategoriSnapshot.data()?['namaKategori']
          as String? ??
              'Kategori tidak tersedia';

      final userId = data['userId'] as String;
      final seller = await getSellerProfile(userId);

      final sellerName = seller?['nama'] as String?;
      final sellerPhone =
      seller?['nomorTelepon'] as String?;

      return CatalogItem.fromFirestore(
        snapshot.id,
        data,
        categoryName: namaKategori,
        sellerName: sellerName,
        sellerPhone: sellerPhone,
        isSellerVerified: seller?['isSellerVerified'] == true,
      );
    });
  }
}
