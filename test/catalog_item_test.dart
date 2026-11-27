import 'package:flutter_test/flutter_test.dart';
import 'package:titipin/features/auth/data/firebase_auth_service.dart';
import 'package:titipin/features/catalog/catalog_item.dart';

void main() {
  final listing = <String, dynamic>{
    'namaBarang': 'Buku kuliah', 'harga': 50000, 'userId': 'penjual',
    'statusBarang': 'tersedia',
  };
  CatalogItem read(Map<String, dynamic> data) =>
      CatalogItem.fromFirestore('buku', data, categoryName: 'Buku');

  test('field opsional lama atau rusak memakai nilai tampilan cadangan', () {
    final item = read({...listing, 'harga': 50000.0, 'fotoBarang': 1,
      'updatedAt': 'kemarin', 'tags': ['kuliah', 10], 'lokasi': false});
    expect(item.price, 50000);
    expect(item.primaryPhotoSource, CatalogItem.placeholderAsset);
    expect(item.location, 'Belum dicantumkan');
    expect(item.updatedAt, isNull);
    expect(item.tags, ['kuliah']);
  });

  test('harga, status, dan identitas yang tidak dapat dipercaya ditolak per barang', () {
    for (final bad in [
      {'harga': 'gratis'}, {'harga': 1.5}, {'harga': 0}, {'statusBarang': null},
      {'userId': 'salah/path'}, {'namaBarang': []},
    ]) {
      expect(() => read({...listing, ...bad}), throwsFormatException);
    }
    expect(read(listing).name, 'Buku kuliah');
  });

  test('nomor registrasi, profil, dan WhatsApp menggunakan format yang sama', () {
    for (final number in ['0812-3456-7890', '+62 (812) 34567890', '6281234567890']) {
      expect(FirebaseAuthService.normalizeWhatsApp(number), '6281234567890');
    }
    expect(FirebaseAuthService.normalizeWhatsApp('0812x12345'), isNull);
    expect(FirebaseAuthService.normalizeWhatsApp('123'), isNull);
  });
}
