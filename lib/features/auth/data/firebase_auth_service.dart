import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Kesalahan alur autentikasi yang dapat ditampilkan ke pengguna.
class TitipinAuthException implements Exception {
  const TitipinAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mengizinkan alamat mahasiswa USU dan domain utama USU.
  /// Jika Titipin khusus mahasiswa, hapus domain @usu.ac.id sesuai kebijakan tim.
  static bool isUsuEmail(String email) {
    final clean = email.trim().toLowerCase();
    final parts = clean.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return false;
    if (!RegExp(r'^[a-z0-9._%+\-]+$').hasMatch(parts.first)) return false;
    return const {'students.usu.ac.id', 'usu.ac.id'}.contains(parts.last);
  }

  static String? validateUsuEmail(String? email) {
    if (email == null || email.trim().isEmpty) return 'Email harus diisi';
    if (!isUsuEmail(email)) {
      return 'Gunakan email resmi USU (@students.usu.ac.id atau @usu.ac.id)';
    }
    return null;
  }

  static String? normalizeWhatsApp(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';
    return RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(phone) ? phone : null;
  }

  Future<void> register({
    required String name,
    required String whatsappNumber,
    required String email,
    required String password,
  }) async {
    if (!isUsuEmail(email)) {
      throw const TitipinAuthException('Gunakan alamat email resmi USU.');
    }

    final phone = normalizeWhatsApp(whatsappNumber);
    if (phone == null) {
      throw const TitipinAuthException('Nomor WhatsApp tidak valid.');
    }

    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      await _auth.signOut();
      throw const TitipinAuthException('Akun belum berhasil dibuat. Coba lagi.');
    }

    try {
      await user.updateDisplayName(name.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .collection('private').doc('registration').set({'nomorTelepon': phone});
      await user.sendEmailVerification();
    } on FirebaseException {
      throw const TitipinAuthException(
        'Akun sudah dibuat. Gunakan Kirim ulang verifikasi di halaman masuk. '
            'Setelah login, periksa nomor WhatsApp di Profil.',
      );
    } finally {
      // Akun belum boleh masuk ke katalog sampai email diverifikasi.
      await _auth.signOut();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (!isUsuEmail(email)) {
      throw const TitipinAuthException('Gunakan alamat email resmi USU.');
    }

    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      await _auth.signOut();
      throw const TitipinAuthException('Gagal membaca informasi akun.');
    }

    try {
      // Memperbarui status emailVerified setelah pengguna mengklik tautan email.
      await user.reload();
    } on FirebaseException {
      await _auth.signOut();
      rethrow;
    }

    final verifiedUser = _auth.currentUser;
    if (verifiedUser == null || !verifiedUser.emailVerified) {
      await _auth.signOut();
      throw const TitipinAuthException(
        'Email belum diverifikasi. Klik tautan verifikasi dari Firebase '
            'di kotak masuk atau spam, lalu coba login kembali.',
      );
    }

    try {
      await _syncVerifiedSellerProfile(verifiedUser);
    } on FirebaseException {
      await _auth.signOut();
      throw const TitipinAuthException(
        'Profil gagal disinkronkan. Periksa koneksi lalu masuk kembali.',
      );
    }
  }

  /// Firebase Auth menyimpan sesi di Android; reload menyegarkan status verifikasi.
  Future<bool> hasVerifiedSession() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return false;
    if (!isUsuEmail(user.email ?? '')) {
      await _auth.signOut();
      return false;
    }

    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-disabled' || error.code == 'user-not-found') {
        await _auth.signOut();
        return false;
      }
      // Jika tidak ada jaringan, pertahankan sesi yang sudah pernah terverifikasi.
      return user.emailVerified;
    } on FirebaseException {
      return user.emailVerified;
    }

    final refreshed = _auth.currentUser;
    if (refreshed == null ||
        !refreshed.emailVerified ||
        !isUsuEmail(refreshed.email ?? '')) {
      await _auth.signOut();
      return false;
    }
    // Pulihkan navigasi segera setelah sesi terverifikasi.
    unawaited(_syncRestoredProfile(refreshed));
    return true;
  }

  Future<void> _syncRestoredProfile(User user) async {
    try {
      await _syncVerifiedSellerProfile(user);
    } on FirebaseException catch (error) {
      debugPrint('[AUTH] Sinkronisasi profil akan dicoba saat masuk ulang (${error.code}).');
    }
  }

  Future<void> _syncVerifiedSellerProfile(User user) async {
    if (!user.emailVerified || !isUsuEmail(user.email ?? '')) return;

    await user.getIdToken(true);
    await _writeProfile(user);
  }

  Future<void> updateWhatsApp(String input) async {
    final user = _auth.currentUser;
    final phone = normalizeWhatsApp(input);
    if (user == null || !user.emailVerified || !isUsuEmail(user.email ?? '')) {
      throw const TitipinAuthException('Silakan masuk kembali dengan akun USU.');
    }
    if (phone == null) {
      throw const TitipinAuthException('Nomor WhatsApp tidak valid.');
    }
    await _writeProfile(user, newPhone: phone);
  }

  Future<void> _writeProfile(User user, {String? newPhone}) async {
    final db = FirebaseFirestore.instance;
    final account = db.collection('users').doc(user.uid);
    final pending = account.collection('private').doc('registration');
    final profile = account.collection('public').doc('profile');
    final name = user.displayName?.trim();
    await db.runTransaction<void>((tx) async {
      final draft = await tx.get(pending);
      final phone = newPhone ?? draft.data()?['nomorTelepon'];
      tx.set(profile, {
        if (name != null && name.isNotEmpty) 'nama': name,
        if (phone is String) 'nomorTelepon': phone,
        'isSellerVerified': true,
      }, SetOptions(merge: true));
      if (draft.exists) tx.delete(pending);
    });
  }

  Future<void> resetPassword(String email) async {
    if (!isUsuEmail(email)) {
      throw const TitipinAuthException('Isi email USU di kolom Email dahulu.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
    }
  }

  Future<void> resendVerification(String email, String password) async {
    if (!isUsuEmail(email) || password.isEmpty) {
      throw const TitipinAuthException('Isi email USU dan password untuk mengirim ulang verifikasi.');
    }
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(), password: password,
    );
    try {
      final user = credential.user;
      if (user == null) throw const TitipinAuthException('Silakan coba lagi.');
      if (user.emailVerified) {
        throw const TitipinAuthException('Email sudah terverifikasi. Silakan masuk.');
      }
      await user.sendEmailVerification();
    } finally {
      await _auth.signOut();
    }
  }

  Future<void> logout() => _auth.signOut();

  static String messageFor(Object error) {
    if (error is TitipinAuthException) return error.message;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Email sudah terdaftar. Silakan masuk.';
        case 'invalid-email':
          return 'Format email tidak valid.';
        case 'weak-password':
          return 'Password terlalu lemah. Gunakan password yang lebih kuat.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Email atau password salah.';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan. Coba lagi nanti.';
        case 'network-request-failed':
          return 'Tidak dapat terhubung. Periksa internet HP.';
        case 'user-disabled':
          return 'Akun ini dinonaktifkan. Hubungi pengelola.';
        default:
          return 'Autentikasi gagal (${error.code}). Coba lagi.';
      }
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }
}