import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog_item.dart';
import 'data/catalog_service.dart';
import 'widgets/catalog_photo.dart';

class DetailBarangScreen extends StatefulWidget {
  const DetailBarangScreen({
    super.key,
    required this.item,
    required this.initiallySaved,
    required this.onToggleSaved,
  });

  final CatalogItem item;
  final bool initiallySaved;
  final VoidCallback onToggleSaved;

  @override
  State<DetailBarangScreen> createState() => _DetailBarangScreenState();
}

class _DetailBarangScreenState extends State<DetailBarangScreen> {
  static const _green = Color(0xFF506D54);
  static const _background = Color(0xFFF0F5FA);

  int _photoIndex = 0;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.initiallySaved;
  }

  void _toggleSaved() {
    widget.onToggleSaved();
    setState(() => _isSaved = !_isSaved);
  }

  Future<void> _contactSeller() async {
    final item = widget.item;
    String phone = (item.sellerPhone ?? '')
        .trim()
        .replaceAll(RegExp(r'[\s()+-]'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    if (!RegExp(r'^[1-9]\d{7,14}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nomor WhatsApp penjual belum tersedia atau tidak valid.',
          ),
        ),
      );
      return;
    }

    final message = 'Halo, saya tertarik dengan barang '
        '${item.name} yang ditawarkan di TITIPIN. '
        'Apakah barangnya masih tersedia?';

    final url = Uri.https('wa.me', '/$phone', {'text': message});

    try {
      final opened = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp tidak dapat dibuka.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    debugPrint('Barang ${item.id}: isSellerVerified=${item.isSellerVerified}');
    final photos = item.galleryPhotoSources;
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        leadingWidth: 48,
        titleSpacing: 0,
        title: const Text('Detail Barang'),
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: PageView.builder(
                        itemCount: photos.length,
                        physics: photos.length == 1
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (index) {
                          setState(() => _photoIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: CatalogPhoto(
                              source: photos[index],
                              fit: BoxFit.contain,
                              semanticLabel:
                              'Foto ${index + 1} dari ${photos.length}',
                            ),
                          );
                        },
                      ),
                    ),
                    if (photos.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var index = 0; index < photos.length; index++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _photoIndex
                                      ? _green
                                      : const Color(0xFFD5DED7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: theme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            item.formattedPrice,
                            style: theme.titleMedium?.copyWith(
                              color: _green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(label: Text(item.category)),
                              Chip(label: Text(item.condition)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Detail Barang', style: theme.titleMedium),
                          const SizedBox(height: 6),
                          Text('Kategori: ${item.category}'),
                          Text('Lokasi: ${item.location}'),
                          const SizedBox(height: 14),
                          Text('Deskripsi', style: theme.titleMedium),
                          const SizedBox(height: 6),
                          Text(item.description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Penjual',
                        style: theme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.person_outline),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.sellerName ?? 'Nama penjual belum tersedia',
                                  style: theme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.isSellerVerified) ...[
                                  const SizedBox(height: 6),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1ECE1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            size: 16,
                                            color: Color(0xFF78B23D),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              'Mahasiswa Terverifikasi',
                                              style: theme.labelSmall?.copyWith(
                                                color: _green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _toggleSaved,
                  icon: Icon(
                    _isSaved ? Icons.favorite : Icons.favorite_border,
                    color: _isSaved ? Colors.red : _green,
                  ),
                  label: Text(_isSaved ? 'Tersimpan' : 'Simpan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  onPressed: _contactSeller,
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text('Hubungi via WhatsApp'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailBarangByIdScreen extends StatefulWidget {
  const DetailBarangByIdScreen({
    super.key,
    required this.barangId,
    required this.initiallySaved,
    required this.onToggleSaved,
  });

  final String barangId;
  final bool initiallySaved;
  final VoidCallback onToggleSaved;

  @override
  State<DetailBarangByIdScreen> createState() =>
      _DetailBarangByIdScreenState();
}

class _DetailBarangByIdScreenState extends State<DetailBarangByIdScreen> {
  late Stream<CatalogItem?> _itemStream =
  CatalogService().watchItemById(widget.barangId);

  void _retryLoad() {
    setState(() {
      _itemStream = CatalogService().watchItemById(widget.barangId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogItem?>(
      stream: _itemStream,
      builder: (context, snapshot) {
        // Kondisi data sedang dimuat
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Barang')),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF506D54)),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint('[DETAIL BARANG] ${snapshot.error}');
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Barang')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat detail barang.'),
                  TextButton(
                    onPressed: _retryLoad,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Barang')),
            body: const Center(
              child: Text('Barang sudah tidak tersedia.'),
            ),
          );
        }
        return DetailBarangScreen(
          item: item,
          initiallySaved: widget.initiallySaved,
          onToggleSaved: widget.onToggleSaved,
        );
      },
    );
  }
}
