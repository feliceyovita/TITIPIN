import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/kategori_barang.dart';
import 'catalog_item.dart';
import 'data/kelola_barang_service.dart';
import 'widgets/catalog_photo.dart';

typedef EditBarangDraft = ({
String namaBarang,
String deskripsi,
String kategori,
String jenisKondisi,
String tingkatKondisi,
String detailMinus,
String kondisi,
int harga,
String lokasi,
XFile? fotoUtamaBaru,
});

class EditBarangResult {
  const EditBarangResult.simpan({
    required this.barangId,
    required EditBarangDraft draft,
  }) : draft = draft,
        hapus = false;

  const EditBarangResult.konfirmasiHapus({required this.barangId})
      : draft = null,
        hapus = true;

  final String barangId;
  final EditBarangDraft? draft;
  final bool hapus;
}

class EditBarangScreen extends StatefulWidget {
  const EditBarangScreen({
    super.key,
    required this.item,
    required this.kategoriTersedia,
    this.kelolaService,
  });

  final CatalogItem item;
  final List<String> kategoriTersedia;
  final KelolaBarangService? kelolaService;

  @override
  State<EditBarangScreen> createState() => _EditBarangScreenState();
}

class _EditBarangScreenState extends State<EditBarangScreen> {
  static const _latar = Color(0xFFF0F5FA);
  static const _hijau = Color(0xFF506D54);
  static const _warnaTeks = Color(0xFF61758F);
  static const _merah = Color(0xFFC62828);

  static const _pilihanJenis = ['Baru', 'Bekas'];
  static const _pilihanKondisi = ['Tanpa minus', 'Ada minus'];

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final _kelolaService = widget.kelolaService ?? KelolaBarangService();

  late final TextEditingController _nama;
  late final TextEditingController _deskripsi;
  late final TextEditingController _harga;
  late final TextEditingController _lokasi;
  late final TextEditingController _detailMinus;
  late String _kategori;
  late String _statusBarang;
  bool _isBusy = false;

  String? _jenisBarang;
  String? _kondisiFisik;
  XFile? _fotoUtamaBaru;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    _nama = TextEditingController(text: item.name);
    _deskripsi = TextEditingController(text: item.description);
    _harga = TextEditingController(text: item.price.toString());
    _lokasi = TextEditingController(text: item.location);
    _kategori = item.category;
    _statusBarang = item.status;

    final kondisiTersimpan = item.condition.trim();
    final pemisahDetail = kondisiTersimpan.indexOf(':');
    final ringkasan = pemisahDetail < 0
        ? kondisiTersimpan
        : kondisiTersimpan.substring(0, pemisahDetail);

    final bagianKondisi = ringkasan
        .split(RegExp(r'\s*[-–—]\s*'))
        .map((bagian) => bagian.trim().toLowerCase())
        .toSet();

    _jenisBarang = _pilihanAwal(_pilihanJenis, bagianKondisi);
    _kondisiFisik = _pilihanAwal(_pilihanKondisi, bagianKondisi);

    _detailMinus = TextEditingController(
      text: _kondisiFisik == 'Ada minus' && pemisahDetail >= 0
          ? kondisiTersimpan.substring(pemisahDetail + 1).trim()
          : '',
    );
  }

  String? _pilihanAwal(List<String> pilihan, Set<String> bagianKondisi) {
    for (final opsi in pilihan) {
      if (bagianKondisi.contains(opsi.toLowerCase())) {
        return opsi;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _nama.dispose();
    _deskripsi.dispose();
    _harga.dispose();
    _lokasi.dispose();
    _detailMinus.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto() async {
    if (_isBusy) return;
    try {
      final foto = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted || foto == null) return;
      setState(() => _fotoUtamaBaru = foto);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto gagal dibuka.')));
    }
  }

  int? _bacaHarga(String? value) {
    final teks = (value ?? '').trim();
    final formatHarga = RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$');

    if (!formatHarga.hasMatch(teks)) return null;
    return int.tryParse(teks.replaceAll('.', ''));
  }

  Future<void> _simpan() async {
    if (_isBusy || _formKey.currentState?.validate() != true) return;

    final kategoriId = _kategori == widget.item.category
        ? widget.item.categoryId
        : kategoriBarang[_kategori];
    if (kategoriId == null || kategoriId.isEmpty) {
      _tampilkanKesalahan(
        const KelolaBarangException('Pilih kategori yang valid.'),
      );
      return;
    }

    final jenis = _jenisBarang!;
    final tingkat = _kondisiFisik!;
    final detail = tingkat == 'Ada minus' ? _detailMinus.text.trim() : '';
    final kondisi = detail.isEmpty
        ? '$jenis - $tingkat'
        : '$jenis - $tingkat: $detail';

    final EditBarangDraft draft = (
    namaBarang: _nama.text.trim(),
    deskripsi: _deskripsi.text.trim(),
    kategori: _kategori,
    jenisKondisi: jenis,
    tingkatKondisi: tingkat,
    detailMinus: detail,
    kondisi: kondisi,
    harga: _bacaHarga(_harga.text)!,
    lokasi: _lokasi.text.trim(),
    fotoUtamaBaru: _fotoUtamaBaru,
    );
    FocusScope.of(context).unfocus();
    setState(() => _isBusy = true);
    try {
      await _kelolaService.perbaruiBarang(
        barangId: widget.item.id,
        namaBarang: draft.namaBarang,
        deskripsi: draft.deskripsi,
        kategoriId: kategoriId,
        jenisKondisi: draft.jenisKondisi,
        tingkatKondisi: draft.tingkatKondisi,
        detailMinus: draft.detailMinus,
        harga: draft.harga,
        lokasi: draft.lokasi,
        statusBarang: _statusBarang,
        expectedUpdatedAt: widget.item.updatedAt,
        fotoUtamaBaru: draft.fotoUtamaBaru,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pop(EditBarangResult.simpan(barangId: widget.item.id, draft: draft));
    } catch (error) {
      if (mounted) _tampilkanKesalahan(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _tampilkanKesalahan(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(KelolaBarangService.messageFor(error))),
      );
  }

  Future<void> _konfirmasiHapus() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();

    const warnaHapus = Color(0xFFE91646);
    const warnaIkon = Color(0xFFFFE1E6);
    const warnaJudul = Color(0xFF53637A);
    const warnaDeskripsi = Color(0xFF61758F);

    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final bentukTombol = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        );

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 352,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 21,
                    backgroundColor: warnaIkon,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: warnaHapus,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Apakah Anda yakin ingin menghapus barang ini?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: warnaJudul,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tindakan ini tidak dapat dibatalkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: warnaDeskripsi, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 156,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: warnaHapus,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: bentukTombol,
                          ),
                          child: const Text('Hapus Barang'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: warnaJudul,
                            minimumSize: const Size.fromHeight(44),
                            side: const BorderSide(color: Color(0xFFB0B0B0)),
                            shape: bentukTombol,
                          ),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || setuju != true) return;

    setState(() => _isBusy = true);
    try {
      await _kelolaService.hapusBarang(
        barangId: widget.item.id,
        expectedUpdatedAt: widget.item.updatedAt,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pop(EditBarangResult.konfirmasiHapus(barangId: widget.item.id));
    } catch (error) {
      if (mounted) _tampilkanKesalahan(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _label(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        teks,
        style: const TextStyle(
          color: _warnaTeks,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _input(
      String label,
      TextEditingController controller, {
        int lines = 1,
        String? hintText,
        String? prefixText,
        TextInputType? keyboardType,
        FormFieldValidator<String>? validator,
      }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE1E8F0)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          TextFormField(
            enabled: !_isBusy,
            controller: controller,
            maxLines: lines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13, color: _warnaTeks),
            decoration: InputDecoration(
              hintText: hintText,
              prefixText: prefixText,
              filled: true,
              fillColor: const Color(0xFFFAFCFF),
              contentPadding: const EdgeInsets.all(11),
              errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
              border: border,
              enabledBorder: border,
            ),
            validator:
            validator ??
                ((value) =>
                (value ?? '').trim().isEmpty ? 'Wajib diisi.' : null),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
      String label,
      String hint,
      String? nilai,
      Iterable<String> pilihan,
      ValueChanged<String> onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          DropdownButtonFormField<String>(
            initialValue: nilai,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: _warnaTeks),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.all(11),
              errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: [
              for (final opsi in pilihan)
                DropdownMenuItem<String>(
                  value: opsi,
                  child: Text(opsi, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (value) => value == null ? 'Wajib dipilih.' : null,
            onChanged: (value) {
              if (!_isBusy && value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _pratinjauFoto() {
    final fotoBaru = _fotoUtamaBaru;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 138,
            height: 148,
            child: fotoBaru == null
                ? CatalogPhoto(
              source: widget.item.primaryPhotoSource,
              fit: BoxFit.cover,
              semanticLabel: 'Foto ${widget.item.name}',
            )
                : Image.file(File(fotoBaru.path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: _isBusy ? null : _pilihFoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          tooltip: 'Pilih foto utama',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final kategori = {widget.item.category, ...widget.kategoriTersedia};

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        backgroundColor: _latar,
        appBar: AppBar(
          backgroundColor: _latar,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _warnaTeks,
          centerTitle: true,
          title: const Text(
            'Edit Barang',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_isBusy) const LinearProgressIndicator(color: _hijau),
                _pratinjauFoto(),
                const SizedBox(height: 18),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _input('Nama Barang *', _nama),
                        _input('Deskripsi *', _deskripsi, lines: 3),
                        _dropdown(
                          'Kategori *',
                          'Pilih Kategori',
                          _kategori,
                          kategori,
                              (value) => setState(() => _kategori = value),
                        ),
                        _dropdown(
                          'Jenis Barang *',
                          'Pilih Status',
                          _jenisBarang,
                          _pilihanJenis,
                              (value) => setState(() => _jenisBarang = value),
                        ),
                        _dropdown(
                          'Kondisi Fisik *',
                          'Pilih Kondisi',
                          _kondisiFisik,
                          _pilihanKondisi,
                              (value) {
                            setState(() {
                              _kondisiFisik = value;
                              if (value != 'Ada minus') _detailMinus.clear();
                            });
                          },
                        ),
                        if (_kondisiFisik == 'Ada minus')
                          _input(
                            'Detail Minus *',
                            _detailMinus,
                            hintText: 'Contoh: Tutup baterai longgar',
                            lines: 3,
                          ),
                        _input(
                          'Harga *',
                          _harga,
                          prefixText: 'Rp ',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final harga = _bacaHarga(value);
                            return harga == null || harga <= 0
                                ? 'Masukkan harga lebih dari Rp0.'
                                : null;
                          },
                        ),
                        _input('Lokasi *', _lokasi),
                        _dropdown(
                          'Status Barang *',
                          'Pilih Status Barang',
                          _statusBarang,
                          const ['tersedia', 'terjual'],
                              (value) => setState(() => _statusBarang = value),
                        ),
                        const SizedBox(height: 4),
                        FilledButton(
                          onPressed: _isBusy ? null : _simpan,
                          style: FilledButton.styleFrom(
                            backgroundColor: _hijau,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: Text(
                            _isBusy ? 'Memproses...' : 'Simpan Perubahan',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _konfirmasiHapus,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _merah,
                            side: const BorderSide(color: Color(0xFFFFCBCB)),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 19),
                          label: const Text('Hapus Barang'),
                        ),
                      ],
                    ),
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
