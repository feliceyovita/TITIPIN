
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'upload_item_success_screen.dart';

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

  final picker = ImagePicker();
  final images = <XFile>[];
  final tags = <String>[];

  String? category, status, condition;

  final blue = const Color(0xFF4895F7);
  final textColor = const Color(0xFF61758F);

  final categories = ['Elektronik', 'Buku', 'Fashion', 'Peralatan', 'Lainnya'];
  final statuses = ['Baru', 'Bekas'];
  final conditions = ['Tanpa minus', 'Ada minus'];

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    tagController.dispose();
    detailMinus.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final result = await picker.pickMultiImage(imageQuality: 85);

    for (var image in result) {
      if (await File(image.path).length() <= 10 * 1024 * 1024) {
        setState(() => images.add(image));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran foto maksimal 10MB')),
        );
      }
    }
  }

  void addTag() {
    final tag = tagController.text.trim();

    if (tag.isNotEmpty && !tags.contains(tag)) {
      setState(() => tags.add(tag));
    }
    tagController.clear();
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(
      fontSize: 14, fontWeight: FontWeight.bold, color: textColor,
    )),
  );

  Widget input(TextEditingController controller, String hint,
      {int lines = 1, TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboard,
      style: TextStyle(fontSize: 13, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: textColor),
        filled: true,
        fillColor: const Color(0xFFFAFCFF),
        contentPadding: const EdgeInsets.all(11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1E8F0)),
        ),
      ),
    );
  }

  Widget dropdown(String hint, String? value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(fontSize: 13, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.all(11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: items.map((item) =>
          DropdownMenuItem(value: item, child: Text(item))
      ).toList(),
      onChanged: onChanged,
    );
  }

  void publish() {
    String? error;

    if (name.text.trim().isEmpty) {
      error = 'Nama barang belum diisi';
    } else if (category == null) {
      error = 'Kategori belum dipilih';
    } else if (status == null) {
      error = 'Status barang belum dipilih';
    } else if (condition == null) {
      error = 'Kondisi barang belum dipilih';
    } else if (condition == 'Ada minus' &&
        detailMinus.text.trim().isEmpty) {
      error = 'Detail minus harus diisi';
    } else if (price.text.trim().isEmpty) {
      error = 'Harga belum diisi';
    } else if (images.isEmpty) {
      error = 'Foto barang belum dipilih';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const UploadItemSuccessScreen(),
      ),
    );
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
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto barang
            Center(
              child: InkWell(
                onTap: pickImage,
                child: DottedBorder(
                  color: const Color(0xFF80B18E),
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
                        Text('Maks.10MB\nper Gambar',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8, color: textColor)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

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
                          onTap: () => setState(() => images.removeAt(e.key)),
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
            Card(
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
                    input(name, 'Contoh: Baju Lengan Panjang'),

                    const SizedBox(height: 12),
                    label('Deskripsi'),
                    input(description, 'Deskripsi Barang', lines: 3),

                    const SizedBox(height: 12),
                    label('Kategori *'),
                    dropdown('Pilih Kategori', category, categories,
                            (v) => setState(() => category = v)),

                    const SizedBox(height: 12),
                    label('Status Barang *'),
                    dropdown('Pilih Status', status, statuses,
                            (v) => setState(() => status = v)),

                    const SizedBox(height: 12),
                    label('Kondisi Barang *'),
                    dropdown('Pilih Kondisi', condition, conditions, (v) {
                      setState(() {
                        condition = v;
                        if (v != 'Ada minus') detailMinus.clear();
                      });
                    }),

                    if (condition == 'Ada minus') ...[
                      const SizedBox(height: 12),
                      label('Detail Minus *'),
                      input(detailMinus, 'Contoh: Tutup baterai longgar',
                          lines: 3),
                    ],

                    const SizedBox(height: 12),
                    label('Harga *'),
                    input(price, 'Rp', keyboard: TextInputType.number),

                    const SizedBox(height: 12),
                    label('Tags'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagController,
                            style: TextStyle(fontSize: 13, color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Tambah Tag...',
                              prefixIcon: const Icon(Icons.sell_outlined,
                                  size: 17),
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
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
                          onDeleted: () =>
                              setState(() => tags.remove(tag)),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 45,
              child: ElevatedButton(
                onPressed: publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Upload Barang',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
