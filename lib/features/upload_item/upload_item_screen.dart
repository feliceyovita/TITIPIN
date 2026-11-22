import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/constants/kategori_barang.dart';
import '../catalog/catalog_screen.dart';
import 'data/upload_barang_service.dart';

class UploadItemScreen extends StatefulWidget {
  const UploadItemScreen({super.key});

  @override
  State<UploadItemScreen> createState() => _UploadItemScreenState();
}

class _UploadItemScreenState extends State<UploadItemScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final tagController = TextEditingController();
  final detailMinus = TextEditingController();
  final location = TextEditingController();

  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _photoError;
  String? _tagError;
  bool _sudahMencobaUnggah = false;

  final picker = ImagePicker();
  final images = <XFile>[];
  final tags = <String>[];

  String? category, status, condition;
  final UploadBarangService _uploadService = UploadBarangService();
  bool _isUploading = false;

  final blue = const Color(0xFF4895F7);
  final textColor = const Color(0xFF61758F);

  final statuses = ['Baru', 'Bekas'];
  final conditions = ['Tanpa minus', 'Ada minus'];

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    tagController.dispose();
    detailMinus.dispose();
    location.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Memilih sumber foto tanpa mengubah mekanisme unggah Cloudinary.
  Future<void> _pilihSumberFoto() async {
    if (_isUploading) return;

    if (images.length >= UploadBarangService.maxFoto) {
      setState(() => _photoError = 'Maksimal 5 foto per barang.');
      return;
    }

    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: Color(0xFF4895F7),
                ),
                title: const Text('Ambil Foto'),
                subtitle: const Text('Gunakan kamera HP'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF4895F7),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Pilih satu atau beberapa foto'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || sumber == null) return;
    if (sumber == ImageSource.camera) {
      await _ambilFotoKamera();
    } else {
      await pickImage();
    }
  }

  // Kamera menghasilkan satu foto, sedangkan galeri dapat memilih banyak.
  Future<void> _ambilFotoKamera() async {
    if (_isUploading) return;

    try {
      final foto = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted || foto == null) return;
      await _tambahkanFoto([foto]);
    } catch (e) {
      if (mounted) _showMessage('Kamera tidak dapat dibuka: $e');
    }
  }

  // Fungsi galeri lama tetap tersedia.
  Future<void> pickImage() async {
    if (_isUploading) return;

    try {
      final hasil = await picker.pickMultiImage(imageQuality: 85);
      if (!mounted || hasil.isEmpty) return;
      await _tambahkanFoto(hasil);
    } catch (e) {
      if (mounted) _showMessage('Gagal memilih foto: $e');
    }
  }

  // Kedua sumber melewati validasi yang sama sebelum foto dimasukkan.
  Future<void> _tambahkanFoto(List<XFile> fotoBaru) async {
    final accepted = <XFile>[];
    String? warning;

    for (final foto in fotoBaru) {
      if (images.length + accepted.length >= UploadBarangService.maxFoto) {
        warning = 'Maksimal 5 foto per barang.';
        break;
      }

      final bagianNama = foto.name.split('.');
      final ekstensi = bagianNama.length > 1
          ? bagianNama.last.toLowerCase()
          : '';
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ekstensi)) {
        warning = 'Foto hanya boleh JPG, JPEG, PNG, atau WebP.';
        continue;
      }

      final ukuran = await foto.length();
      if (ukuran == 0 || ukuran > UploadBarangService.maxUkuranFoto) {
        warning = 'Ukuran tiap foto maksimal 5 MB.';
        continue;
      }

      if (images.any((item) => item.path == foto.path) ||
          accepted.any((item) => item.path == foto.path)) {
        continue;
      }
      accepted.add(foto);
    }

    if (!mounted) return;
    setState(() {
      images.addAll(accepted);
      _photoError = warning;
      if (_sudahMencobaUnggah && images.isEmpty) {
        _photoError ??= 'Foto barang tidak boleh kosong.';
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void addTag() {
    final tag = tagController.text.trim();

    setState(() {
      if (tag.isNotEmpty && !tags.contains(tag)) {
        tags.add(tag);
      }
      tagController.clear();
      _tagError = tags.isEmpty
          ? 'Tags tidak boleh kosong. Tambahkan minimal 1 tag.'
          : null;
    });
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(
      fontSize: 14, fontWeight: FontWeight.bold, color: textColor,
    )),
  );

  // Pesan error ditampilkan tepat di bawah kotak input.
  Widget input(
      TextEditingController controller,
      String hint, {
        int lines = 1,
        TextInputType? keyboard,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: lines,
      keyboardType: keyboard,
      style: TextStyle(fontSize: 13, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: textColor),
        filled: true,
        fillColor: const Color(0xFFFAFCFF),
        contentPadding: const EdgeInsets.all(11),
        errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1E8F0)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget dropdown(
      String hint,
      String? value,
      List<String> items,
      ValueChanged<String?> onChanged, {
        required String pesanKosong,
      }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      validator: (value) => value == null ? pesanKosong : null,
      style: TextStyle(fontSize: 13, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.all(11),
        errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  String? _validasiNama(String? value) {
    final nama = (value ?? '').trim();
    if (nama.isEmpty) return 'Nama barang tidak boleh kosong.';
    if (nama.length < 2) return 'Nama barang minimal 2 karakter.';
    return null;
  }

  String? _validasiHarga(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Harga barang tidak boleh kosong.';
    final formatBenar = RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$').hasMatch(text);
    if (!formatBenar) return 'Harga harus berupa angka, contoh: 80000.';
    final angka = int.tryParse(text.replaceAll('.', ''));
    if (angka == null || angka <= 0) {
      return 'Harga barang harus lebih dari Rp0.';
    }
    return null;
  }

  String? _validasiWajib(String? value, String namaField) {
    if ((value ?? '').trim().isEmpty) {
      return '$namaField tidak boleh kosong.';
    }
    return null;
  }

  String? _validasiDeskripsi(String? value) {
    final deskripsi = (value ?? '').trim();
    if (deskripsi.isEmpty) {
      return 'Deskripsi barang tidak boleh kosong.';
    }
    if (deskripsi.length < 10) {
      return 'Deskripsi barang minimal 10 karakter.';
    }
    return null;
  }

  // Popup ditampilkan hanya setelah Cloudinary dan Firestore berhasil.
  Future<void> _tampilkanPopupBerhasil() async {
    final pilihan = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF43B95B), size: 58),
            SizedBox(height: 12),
            Text(
              'Barang Berhasil Diunggah!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Foto dan informasi barang telah tersimpan. '
              'Barangmu siap dilihat di katalog TITIPIN.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('baru'),
            child: const Text('Unggah Lagi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop('katalog'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4895F7),
              foregroundColor: Colors.white,
            ),
            child: const Text('Lihat Katalog'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (pilihan == 'baru') {
      // Formulir dibersihkan tanpa pindah ke halaman kosong.
      setState(() {
        name.clear();
        description.clear();
        price.clear();
        tagController.clear();
        detailMinus.clear();
        location.clear();
        images.clear();
        tags.clear();
        category = null;
        status = null;
        condition = null;
        _photoError = null;
        _tagError = null;
        _sudahMencobaUnggah = false;
        _autovalidateMode = AutovalidateMode.disabled;
        // FormState baru mencegah nilai dropdown lama muncul lagi.
        _formKey = GlobalKey<FormState>();
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } else if (pilihan == 'katalog') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const CatalogScreen(),
        ),
            (route) => false,
      );
    }
  }

  Future<void> publish() async {
    if (_isUploading) return;

    // Mendukung angka biasa (120000) maupun pemisah ribuan (120.000).
    final rawPrice = price.text.trim();
    final validPrice = RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$')
        .hasMatch(rawPrice);
    final parsedPrice = validPrice
        ? int.tryParse(rawPrice.replaceAll('.', ''))
        : null;
    final kategoriId = kategoriBarang[category];

    // Tag yang masih diketik tanpa menekan (+) tetap dianggap sebagai tag.
    final allTags = List<String>.of(tags);
    final pendingTag = tagController.text.trim();
    if (pendingTag.isNotEmpty && !allTags.contains(pendingTag)) {
      allTags.add(pendingTag);
    }

    // Memunculkan semua pesan error pada field masing-masing sekaligus.
    setState(() {
      _sudahMencobaUnggah = true;
      _autovalidateMode = AutovalidateMode.onUserInteraction;
      _photoError = images.isEmpty
          ? 'Foto barang tidak boleh kosong.'
          : images.length > UploadBarangService.maxFoto
          ? 'Maksimal 5 foto per barang.'
          : null;
      _tagError = allTags.isEmpty
          ? 'Tags tidak boleh kosong. Tambahkan minimal 1 tag.'
          : null;
    });

    final formulirValid = _formKey.currentState?.validate() ?? false;
    if (!formulirValid ||
        _photoError != null ||
        _tagError != null ||
        parsedPrice == null ||
        kategoriId == null) {
      // Kembali ke awal agar pengguna langsung melihat pesan validasi.
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    try {
      final barangId = await _uploadService.unggahBarang(
        namaBarang: name.text,
        harga: parsedPrice,
        kategoriId: kategoriId,
        jenisKondisi: status!,
        tingkatKondisi: condition!,
        detailMinus: detailMinus.text,
        lokasi: location.text,
        deskripsi: description.text,
        tags: allTags,
        fotoDipilih: List<XFile>.of(images),
      );

      if (!mounted) return;
      debugPrint('Barang berhasil disimpan: $barangId');
      await _tampilkanPopupBerhasil();
    } on UploadBarangException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal mengunggah barang. Periksa koneksi atau izin akses.');
      }
      debugPrint('Error unggah barang: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.albertSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F6FD),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF0F6FD),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: textColor),
          title: Text('Unggah Barang', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: textColor,
          )),
        ),
        body: AbsorbPointer(
          absorbing: _isUploading,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Foto barang
              Center(
                child: InkWell(
                  onTap: _isUploading ? null : _pilihSumberFoto,
                  child: DottedBorder(
                    color: _photoError != null
                        ? Colors.red
                        : const Color(0xFF80B18E),
                    strokeWidth: 1.5,
                    dashPattern: const [3, 3],
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(12),
                    child: Container(
                      width: 64,
                      height: 68,
                      color: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Color(0xFF699C7B)),
                          const SizedBox(height: 5),
                          Text('Maks.5MB\nper Gambar',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 8, color: textColor)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_photoError != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _photoError!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
              ],

              // Preview foto
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 75,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: images.asMap().entries.map((e) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(e.value.path),
                                width: 75, height: 75, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              images.removeAt(e.key);
                              _photoError = _sudahMencobaUnggah && images.isEmpty
                                  ? 'Foto barang tidak boleh kosong.'
                                  : null;
                            }),
                            child: const Icon(Icons.cancel, color: Colors.red),
                          ),
                        ),
                      ],
                    )).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Form barang
              Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Card(
                  color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Nama Barang *'),
                        input(
                          name,
                          'Contoh: Baju Lengan Panjang',
                          validator: _validasiNama,
                        ),

                        const SizedBox(height: 12),
                        label('Deskripsi *'),
                        input(
                          description,
                          'Deskripsi Barang',
                          lines: 3,
                          validator: _validasiDeskripsi,
                        ),

                        const SizedBox(height: 12),
                        label('Kategori *'),
                        dropdown(
                          'Pilih Kategori',
                          category,
                          kategoriBarang.keys.toList(),
                              (v) => setState(() => category = v),
                          pesanKosong: 'Kategori barang wajib dipilih.',
                        ),

                        const SizedBox(height: 12),
                        label('Jenis Barang *'),
                        dropdown(
                          'Pilih Status',
                          status,
                          statuses,
                              (v) => setState(() => status = v),
                          pesanKosong: 'Jenis barang wajib dipilih.',
                        ),

                        const SizedBox(height: 12),
                        label('Kondisi Fisik *'),
                        dropdown(
                          'Pilih Kondisi',
                          condition,
                          conditions,
                              (v) {
                            setState(() {
                              condition = v;
                              if (v != 'Ada minus') detailMinus.clear();
                            });
                          },
                          pesanKosong: 'Kondisi fisik wajib dipilih.',
                        ),

                        if (condition == 'Ada minus') ...[
                          const SizedBox(height: 12),
                          label('Detail Minus *'),
                          input(
                            detailMinus,
                            'Contoh: Tutup baterai longgar',
                            lines: 3,
                            validator: (v) => _validasiWajib(v, 'Detail minus'),
                          ),
                        ],

                        const SizedBox(height: 12),
                        label('Harga *'),
                        input(
                          price,
                          'Rp',
                          keyboard: TextInputType.number,
                          validator: _validasiHarga,
                        ),

                        const SizedBox(height: 12),
                        label('Lokasi *'),
                        input(
                          location,
                          'Contoh: Padang Bulan, Medan',
                          validator: (v) => _validasiWajib(v, 'Lokasi barang'),
                        ),

                        const SizedBox(height: 12),
                        label('Tags *'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: tagController,
                                onSubmitted: (_) => addTag(),
                                onChanged: (value) {
                                  if (_sudahMencobaUnggah || _tagError != null) {
                                    setState(() {
                                      _tagError = tags.isEmpty &&
                                          value.trim().isEmpty
                                          ? 'Tags tidak boleh kosong. Tambahkan minimal 1 tag.'
                                          : null;
                                    });
                                  }
                                },
                                style: TextStyle(fontSize: 13, color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Tambah Tag...',
                                  prefixIcon: const Icon(Icons.sell_outlined,
                                      size: 17),
                                  contentPadding: const EdgeInsets.all(10),
                                  errorText: _tagError,
                                  errorStyle: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.red),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: addTag,
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),

                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 5,
                            children: tags.map((tag) => Chip(
                              label: Text(tag,
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setState(() {
                                tags.remove(tag);
                                _tagError = _sudahMencobaUnggah &&
                                    tags.isEmpty &&
                                    tagController.text.trim().isEmpty
                                    ? 'Tags tidak boleh kosong. Tambahkan minimal 1 tag.'
                                    : null;
                              }),
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                ), // Card
              ), // Form

              const SizedBox(height: 16),

              SizedBox(
                height: 45,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isUploading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Mengunggah...'),
                    ],
                  )
                      : const Text(
                    'Unggah Barang',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
