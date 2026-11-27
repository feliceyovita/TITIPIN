import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../splash/presentation/splash_screen.dart';
import '../upload_item/upload_item_screen.dart';

// Digunakan CatalogScreen saat pengguna memilih tab di navigasi bawah.
enum ProfileDestination { home, saved, myItems }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.savedCount,
  });

  final int savedCount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _green = Color(0xFF506D54);
  static const _background = Color(0xFFF0F5FA);
  static const _muted = Color(0xFF49566A);
  static const _red = Color(0xFFEE2345);

  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _itemsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _profileStream = null;
      _itemsStream = null;
    } else {
      final db = FirebaseFirestore.instance;
      _profileStream = db
          .collection('users')
          .doc(uid)
          .collection('public')
          .doc('profile')
          .snapshots();
      _itemsStream = db
          .collection('barang')
          .where('userId', isEqualTo: uid)
          .snapshots();
    }
    _reloadAuthUser();
  }

  Future<void> _reloadAuthUser() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      if (mounted) setState(() {});
    } on FirebaseAuthException {
      // Tetap tampilkan data lokal Authentication bila refresh gagal.
    }
  }

  bool _isVerifiedStudent(User user) {
    final email = (user.email ?? '').trim().toLowerCase();
    return user.emailVerified &&
        (email.endsWith('@students.usu.ac.id') ||
            email.endsWith('@usu.ac.id'));
  }

  String _initials(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      final value = words.first;
      return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String _joinDate(DateTime? date) {
    if (date == null) return 'Tanggal bergabung belum tersedia';
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final localDate = date.toLocal();
    return 'Bergabung ${months[localDate.month - 1]} ${localDate.year}';
  }

  void _returnTo(ProfileDestination destination) {
    Navigator.of(context).pop(destination);
  }

  void _toSplash() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _askLogout() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => const _DangerConfirmationDialog(
        icon: Icons.logout_rounded,
        title: 'Keluar dari akun?',
        message: 'Sesi akan berakhir.',
        confirmLabel: 'Keluar',
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) _toSplash();
    } on FirebaseAuthException {
      _showError('Gagal keluar dari akun. Coba lagi.');
    }
  }

  Future<void> _askDeleteAccount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Sesi pengguna tidak tersedia. Silakan login kembali.');
      return;
    }

    // Tahap 1: konfirmasi tindakan berisiko.
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => const _DangerConfirmationDialog(
        icon: Icons.warning_amber_rounded,
        title: 'Apakah Anda yakin ingin menghapus akun?',
        message: 'Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'Konfirmasi Hapus Akun',
      ),
    );
    if (approved != true || !mounted) return;

    // Tahap 2: Firebase memeriksa password yang dimasukkan, bukan
    // sekadar membandingkan teks di aplikasi.
    final email = currentUser.email;
    if (email == null || email.isEmpty ||
        !currentUser.providerData.any((p) => p.providerId == 'password')) {
      _showError('Akun ini tidak menggunakan login email dan password.');
      return;
    }

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(expectedEmail: email),
    );
    if (deleted == true && mounted) {
      _toSplash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _background,
        body: const Center(child: Text('Silakan login untuk melihat profil.')),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _profileStream,
          builder: (context, snapshot) {
            final profile = snapshot.data?.data();
            final profileName = (profile?['nama'] as String?)?.trim() ?? '';
            final authName = user.displayName?.trim() ?? '';
            final displayName = profileName.isNotEmpty
                ? profileName
                : (authName.isNotEmpty ? authName : 'Pengguna Titipin');
            final email = user.email ?? 'Email belum tersedia';
            final isStudent = _isVerifiedStudent(user);

            return ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                // Header dan avatar yang menumpuk seperti desain Figma.
                SizedBox(
                  height: 151,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned.fill(
                        bottom: 37,
                        child: ColoredBox(color: _green),
                      ),
                      Positioned(
                        top: 65,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 39,
                            backgroundColor: const Color(0xFF759A7E),
                            child: Text(
                              _initials(displayName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isStudent) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1ECE1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 14, color: Color(0xFF7DB43A)),
                          SizedBox(width: 4),
                          Text(
                            'Mahasiswa Terverifikasi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _itemsStream,
                          builder: (context, snapshot) {
                            final count = snapshot.hasData
                                ? snapshot.data!.docs.where((doc) {
                                    final status = doc.data()['statusBarang'];
                                    return status == 'tersedia';
                                  }).length.toString()
                                : '–';
                            return _Metric(value: count, label: 'Barang Dijual');
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _Metric(
                          value: '${widget.savedCount}',
                          label: 'Barang Tersimpan',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Personal',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(icon: Icons.mail_outline, text: email),
                            const SizedBox(height: 13),
                            _InfoRow(
                              icon: Icons.school_outlined,
                              text: isStudent
                                  ? 'Universitas Sumatera Utara'
                                  : 'Universitas belum terverifikasi',
                            ),
                            const SizedBox(height: 13),
                            _InfoRow(
                              icon: Icons.group_outlined,
                              text: _joinDate(user.metadata.creationTime),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Panel(
                        border: Border.all(color: const Color(0xFFFFB2BE), width: 1.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Zona Berbahaya',
                              style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: _askDeleteAccount,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _red,
                                  side: const BorderSide(color: Color(0xFFFFB2BE)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Hapus Akun'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 40,
                              child: FilledButton.icon(
                                onPressed: _askLogout,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('Keluar dari Akun'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFD9E6F2))),
          ),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  label: 'Beranda',
                  onTap: () => _returnTo(ProfileDestination.home),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.favorite_border,
                  label: 'Simpan',
                  onTap: () => _returnTo(ProfileDestination.saved),
                ),
              ),
              Expanded(
                child: Center(
                  heightFactor: 1,
                  child: IconButton(
                    tooltip: 'Unggah Barang',
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const UploadItemScreen(),
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF759A7E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.square(48),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.add, size: 28),
                  ),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Barang Saya',
                  onTap: () => _returnTo(ProfileDestination.myItems),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  selected: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF687C95), fontSize: 12),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.border});
  final Widget child;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: border,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8391A6), size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF687C95), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF506D54);
    const inactive = Color(0xFF687C95);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? const Color(0xFFE1ECE1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 23, color: selected ? green : inactive),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? green : inactive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog 1 dan 2, sesuai gaya konfirmasi merah dari Figma.
class _DangerConfirmationDialog extends StatelessWidget {
  const _DangerConfirmationDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFEE2345);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFFE8EC),
                child: Icon(icon, color: red, size: 25),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF687C95)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 210,
                height: 38,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(confirmLabel, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 210,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF506D54),
                    side: const BorderSide(color: Color(0xFFB8C0CB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialog 3. Penghapusan akun benar-benar mensyaratkan password valid di
// Firebase Authentication; bukan validasi password buatan di sisi UI.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.expectedEmail});
  final String expectedEmail;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const _red = Color(0xFFEE2345);
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_loading) return;
    final enteredEmail = _email.text.trim().toLowerCase();
    if (enteredEmail != widget.expectedEmail.trim().toLowerCase()) {
      setState(() => _error = 'Email tidak sesuai dengan akun yang login.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Password wajib diisi.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null ||
          user.email!.toLowerCase() != enteredEmail) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _password.text,
      );

      // Firebase sendiri memeriksa apakah password benar.
      await user.reauthenticateWithCredential(credential);
      await user.delete();

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential':
          case 'invalid-login-credentials':
            _error = 'Password salah. Akun tidak dihapus.';
            break;
          case 'too-many-requests':
            _error = 'Terlalu banyak percobaan. Coba beberapa saat lagi.';
            break;
          case 'network-request-failed':
            _error = 'Koneksi terputus. Coba lagi.';
            break;
          case 'requires-recent-login':
            _error = 'Silakan login ulang lalu coba kembali.';
            break;
          default:
            _error = 'Gagal menghapus akun (${e.code}).';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal menghapus akun. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Konfirmasi Hapus Akun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Email', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.email],
                  decoration: _inputDecoration(
                    hint: 'Masukkan email anda',
                    icon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Password', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _password,
                  enabled: !_loading,
                  obscureText: _hidePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  decoration: _inputDecoration(
                    hint: 'Masukkan password anda',
                    icon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? 'Tampilkan password' : 'Sembunyikan password',
                      icon: Icon(
                        _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                      onPressed: _loading
                          ? null
                          : () => setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 39,
                  child: FilledButton(
                    onPressed: _loading ? null : _delete,
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Hapus Akun'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF687C95)),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFAFCFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD9E6F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD9E6F2)),
      ),
    );
  }
}
