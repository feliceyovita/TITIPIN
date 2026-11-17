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

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isUsuEmail(email)) {
      throw const TitipinAuthException('Gunakan alamat email resmi USU.');
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
      await user.sendEmailVerification();
    } on FirebaseException {
      throw const TitipinAuthException(
        'Akun sudah dibuat, tetapi email verifikasi belum terkirim. '
            'Coba masuk lagi setelah memeriksa email, atau hubungi pengelola Titipin.',
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

    if (_auth.currentUser?.emailVerified != true) {
      await _auth.signOut();
      throw const TitipinAuthException(
        'Email belum diverifikasi. Klik tautan verifikasi dari Firebase '
            'di kotak masuk atau spam, lalu coba login kembali.',
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
    return true;
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