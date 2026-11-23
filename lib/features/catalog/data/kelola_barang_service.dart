import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../upload_item/data/upload_barang_service.dart';

class KelolaBarangException implements Exception {
  const KelolaBarangException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KelolaBarangService {
  KelolaBarangService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  late final UploadBarangService _uploadService = UploadBarangService();

  // Satu instance digunakan selama halaman edit terbuka. Percobaan ulang
  // penyimpanan memakai foto yang sama jika foto sudah berhasil diunggah.
  String? _pathFotoTerunggah;
  Map<String, String>? _fotoTerunggah;

  String _userId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const KelolaBarangException('Silakan login terlebih dahulu.');
    }
    return user.uid;
  }

  void _periksaPemilik(Map<String, dynamic> data, String userId) {
    if (_userId() != userId || data['userId'] != userId) {
      throw const KelolaBarangException(
        'Kamu hanya dapat mengelola barang milik akun yang sedang login.',
      );
    }
  }

  void _periksaVersi(Map<String, dynamic> data, Timestamp? expectedUpdatedAt) {
    // Dokumen lama yang belum memiliki updatedAt tetap dapat dikelola.
    if (expectedUpdatedAt != null && data['updatedAt'] != expectedUpdatedAt) {
      throw const KelolaBarangException(
        'Barang sudah berubah. Kembali ke Barang Saya dan buka ulang barang.',
      );
    }
  }

  Future<void> perbaruiBarang({
    required String barangId,
    required String namaBarang,
    required String deskripsi,
    required String kategoriId,
    required String jenisKondisi,
    required String tingkatKondisi,
    required String detailMinus,
    required int harga,
    required String lokasi,
    required String statusBarang,
    Timestamp? expectedUpdatedAt,
    XFile? fotoUtamaBaru,
  }) async {
    if (namaBarang.trim().isEmpty ||
        deskripsi.trim().isEmpty ||
        kategoriId.trim().isEmpty ||
        lokasi.trim().isEmpty ||
        harga <= 0) {
      throw const KelolaBarangException('Lengkapi informasi barang dan harga.');
    }
    if (!const {'Baru', 'Bekas'}.contains(jenisKondisi) ||
        !const {'Tanpa minus', 'Ada minus'}.contains(tingkatKondisi) ||
        !const {'tersedia', 'terjual'}.contains(statusBarang)) {
      throw const KelolaBarangException(
        'Kondisi atau status barang tidak valid.',
      );
    }
    if (tingkatKondisi == 'Ada minus' && detailMinus.trim().isEmpty) {
      throw const KelolaBarangException('Detail minus wajib diisi.');
    }

    final userId = _userId();
    final ref = _firestore.collection('barang').doc(barangId);
    final kategoriRef = _firestore.collection('kategori').doc(kategoriId);

    // Periksa akses dan keberadaan barang sebelum mengunggah foto.
    final awal = await ref.get(const GetOptions(source: Source.server));
    final dataAwal = awal.data();
    if (dataAwal == null) {
      throw const KelolaBarangException('Barang sudah dihapus.');
    }
    _periksaPemilik(dataAwal, userId);
    _periksaVersi(dataAwal, expectedUpdatedAt);
    if (dataAwal['kategoriId'] != kategoriId) {
      final kategori = await kategoriRef.get(
        const GetOptions(source: Source.server),
      );
      if (!kategori.exists) {
        throw const KelolaBarangException(
          'Kategori belum tersedia di Firestore.',
        );
      }
    }

    Map<String, String>? fotoBaru;
    if (fotoUtamaBaru != null) {
      if (_pathFotoTerunggah != fotoUtamaBaru.path || _fotoTerunggah == null) {
        _fotoTerunggah = await _uploadService.unggahFotoBarang(fotoUtamaBaru);
        _pathFotoTerunggah = fotoUtamaBaru.path;
      }
      fotoBaru = _fotoTerunggah;
    }

    final detail = tingkatKondisi == 'Ada minus' ? detailMinus.trim() : '';
    final kondisi = detail.isEmpty
        ? '$jenisKondisi - $tingkatKondisi'
        : '$jenisKondisi - $tingkatKondisi: $detail';

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw const KelolaBarangException('Barang sudah dihapus.');
      }
      _periksaPemilik(data, userId);
      _periksaVersi(data, expectedUpdatedAt);
      if (data['updatedAt'] != dataAwal['updatedAt']) {
        throw const KelolaBarangException(
          'Barang berubah saat diproses. Buka ulang barang dari Barang Saya.',
        );
      }

      // Kategori lama tetap dapat dipertahankan walaupun referensinya dihapus.
      if (data['kategoriId'] != kategoriId) {
        final kategori = await transaction.get(kategoriRef);
        if (!kategori.exists) {
          throw const KelolaBarangException(
            'Kategori belum tersedia di Firestore.',
          );
        }
      }

      final perubahan = <String, dynamic>{
        'namaBarang': namaBarang.trim(),
        'deskripsi': deskripsi.trim(),
        'kategoriId': kategoriId,
        'kondisi': kondisi,
        'jenisKondisi': jenisKondisi,
        'tingkatKondisi': tingkatKondisi,
        'detailMinus': detail,
        'harga': harga,
        'lokasi': lokasi.trim(),
        'statusBarang': statusBarang,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fotoBaru != null) {
        final fotoLama = List<dynamic>.from(data['fotoBarang'] as List? ?? []);
        // Mengganti foto pertama dan mempertahankan foto tambahan.
        perubahan['fotoBarang'] = [fotoBaru, ...fotoLama.skip(1)];
      }

      // update mempertahankan userId, createdAt, tags, dan atribut lain.
      transaction.update(ref, perubahan);
    });
  }

  Future<void> hapusBarang({
    required String barangId,
    Timestamp? expectedUpdatedAt,
  }) async {
    final userId = _userId();
    final ref = _firestore.collection('barang').doc(barangId);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      // Mengulang permintaan hapus yang sudah berhasil tetap dianggap berhasil.
      if (data == null) return;
      _periksaPemilik(data, userId);
      _periksaVersi(data, expectedUpdatedAt);
      transaction.delete(ref);
    });
  }

  static String messageFor(Object error) {
    if (error is KelolaBarangException) return error.message;
    if (error is UploadBarangException) return error.message;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Akses ditolak. Periksa akun pemilik dan Rules Firestore.';
        case 'unauthenticated':
          return 'Sesi berakhir. Silakan login kembali.';
        case 'not-found':
          return 'Barang sudah dihapus. Kembali ke Barang Saya.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Koneksi ke Firestore gagal. Periksa internet dan coba lagi.';
        case 'aborted':
          return 'Barang sedang diperbarui. Buka ulang barang dan coba lagi.';
        default:
          return 'Perubahan gagal disimpan (${error.code}). Coba lagi.';
      }
    }
    return 'Operasi gagal. Periksa koneksi dan coba lagi.';
  }
}
