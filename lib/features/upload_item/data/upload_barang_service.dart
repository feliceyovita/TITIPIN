import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Kesalahan pada proses unggah. Public ID membantu admin menelusuri
/// foto yang sudah terunggah ketika proses berikutnya gagal.
class UploadBarangException implements Exception {
  const UploadBarangException(
      this.message, {
        this.uploadedPublicIds = const [],
      });

  final String message;
  final List<String> uploadedPublicIds;

  @override
  String toString() => message;
}

class UploadBarangService {
  static const String cloudName = 'oqwwtk0y';
  static const String uploadPreset = 'titipin_unsigned';
  static const int maxFoto = 5;
  static const int maxUkuranFoto = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _formatDiizinkan = {'jpg', 'jpeg', 'png', 'webp'};
  static const _jenisDiizinkan = {'Baru', 'Bekas'};
  static const _kondisiDiizinkan = {'Tanpa minus', 'Ada minus'};

  /// Dipakai juga saat mengganti foto utama pada halaman Edit Barang.
  Future<Map<String, String>> unggahFotoBarang(XFile foto) async {
    await _validasiFoto(foto);
    return _uploadFoto(foto);
  }

  Future<void> _validasiFoto(XFile foto) async {
    final bagianNama = foto.name.split('.');
    final ekstensi = bagianNama.length > 1 ? bagianNama.last.toLowerCase() : '';

    if (!_formatDiizinkan.contains(ekstensi)) {
      throw const UploadBarangException(
        'Foto harus berformat JPG, JPEG, PNG, atau WebP.',
      );
    }

    final ukuran = await foto.length();
    if (ukuran == 0 || ukuran > maxUkuranFoto) {
      throw const UploadBarangException(
        'Ukuran tiap foto harus lebih dari 0 dan maksimal 5 MB.',
      );
    }
  }

  Future<Map<String, String>> _uploadFoto(XFile foto) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload'),
    );
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await foto.readAsBytes(),
        filename: foto.name,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UploadBarangException(
        'Gagal mengunggah foto (HTTP ${response.statusCode}). '
            'Periksa format, preset Cloudinary, dan koneksi internet.',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final url = decoded['secure_url'];
    final publicId = decoded['public_id'];

    if (url is! String ||
        !url.startsWith('https://') ||
        publicId is! String ||
        publicId.trim().isEmpty) {
      throw const UploadBarangException(
        'Cloudinary tidak mengembalikan URL dan Public ID yang valid.',
      );
    }

    return {'publicId': publicId, 'url': url};
  }

  /// Mengunggah foto terlebih dahulu, kemudian membuat dokumen barang.
  /// Cloudinary dan Firestore tidak berada dalam satu transaksi atomik.
  Future<String> unggahBarang({
    required String namaBarang,
    required int harga,
    required String kategoriId,
    required String jenisKondisi,
    required String tingkatKondisi,
    required String detailMinus,
    required String lokasi,
    required String deskripsi,
    required List<String> tags,
    required List<XFile> fotoDipilih,
  }) async {
    final sebelumReload = _auth.currentUser;
    if (sebelumReload == null) {
      throw const UploadBarangException('Silakan login terlebih dahulu.');
    }

    await sebelumReload.reload();
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw const UploadBarangException(
        'Email akun harus terverifikasi sebelum mengunggah barang.',
      );
    }
    await user.getIdToken(true);

    if (namaBarang.trim().length < 2) {
      throw const UploadBarangException('Nama barang minimal 2 karakter.');
    }
    if (harga <= 0) {
      throw const UploadBarangException('Harga harus lebih dari Rp0.');
    }
    if (!_jenisDiizinkan.contains(jenisKondisi) ||
        !_kondisiDiizinkan.contains(tingkatKondisi)) {
      throw const UploadBarangException('Kondisi barang belum valid.');
    }
    if (tingkatKondisi == 'Ada minus' && detailMinus.trim().isEmpty) {
      throw const UploadBarangException('Detail minus wajib diisi.');
    }
    if (lokasi.trim().isEmpty) {
      throw const UploadBarangException('Lokasi barang tidak boleh kosong.');
    }
    if (deskripsi.trim().isEmpty) {
      throw const UploadBarangException('Deskripsi barang tidak boleh kosong.');
    }
    if (deskripsi.trim().length < 10) {
      throw const UploadBarangException(
        'Deskripsi barang minimal 10 karakter.',
      );
    }
    final tagsBersih = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    if (tagsBersih.isEmpty) {
      throw const UploadBarangException(
        'Tags tidak boleh kosong. Tambahkan minimal 1 tag.',
      );
    }
    if (fotoDipilih.isEmpty || fotoDipilih.length > maxFoto) {
      throw const UploadBarangException('Pilih 1 sampai 5 foto barang.');
    }

    // Periksa semua foto sebelum foto pertama dikirim.
    for (final foto in fotoDipilih) {
      await _validasiFoto(foto);
    }

    final kategori = await _firestore
        .collection('kategori')
        .doc(kategoriId)
        .get();
    if (!kategori.exists) {
      throw UploadBarangException(
        'Kategori "$kategoriId" belum tersedia di Firestore. '
            'Tambahkan dokumen kategori dahulu.',
      );
    }

    final dokumen = _firestore.collection('barang').doc();
    final fotoBarang = <Map<String, String>>[];

    try {
      for (final foto in fotoDipilih) {
        fotoBarang.add(await _uploadFoto(foto));
      }

      final keteranganMinus = tingkatKondisi == 'Ada minus'
          ? ': ${detailMinus.trim()}'
          : '';
      final kondisiTampil = '$jenisKondisi - $tingkatKondisi$keteranganMinus';

      await dokumen.set({
        'barangId': dokumen.id,
        'namaBarang': namaBarang.trim(),
        'harga': harga,
        'kategoriId': kategoriId,
        'kondisi': kondisiTampil,
        'lokasi': lokasi.trim(),
        'deskripsi': deskripsi.trim(),
        'statusBarang': 'tersedia',
        'userId': user.uid,
        'fotoBarang': fotoBarang,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Field tambahan agar semua input formulir tidak hilang.
        'jenisKondisi': jenisKondisi,
        'tingkatKondisi': tingkatKondisi,
        'detailMinus': tingkatKondisi == 'Ada minus' ? detailMinus.trim() : '',
        'tags': tagsBersih,
      });
      return dokumen.id;
    } catch (e, stackTrace) {
      final uploadedIds = fotoBarang
          .map((foto) => foto['publicId']!)
          .toList(growable: false);
      debugPrint('Unggah barang gagal: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (uploadedIds.isNotEmpty) {
        debugPrint(
          'Foto Cloudinary yang mungkin perlu dibersihkan admin: '
              '${uploadedIds.join(', ')}',
        );
      }
      throw UploadBarangException(
        'Unggah barang gagal. Periksa koneksi dan izin Firestore, '
            'lalu coba lagi.',
        uploadedPublicIds: uploadedIds,
      );
    }
  }
}
