import 'dart:async';

import 'package:flutter/material.dart';
import 'package:titipin/features/catalog/widgets/catalog_bottom_navigation.dart';

import 'catalog_item.dart';
import 'detail_barang_screen.dart';
import 'widgets/product_card.dart';
import '../upload_item/upload_item_screen.dart';
import 'data/catalog_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    this.items,
    this.onOpenItem,
    this.onAddItem,
    this.onOpenMyItems,
    this.onOpenProfile,
  });

  final List<CatalogItem>? items;
  final ValueChanged<CatalogItem>? onOpenItem;
  final VoidCallback? onAddItem;
  final VoidCallback? onOpenMyItems;
  final VoidCallback? onOpenProfile;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Stream<List<CatalogItem>> _itemsStream =
  CatalogService().watchAvailableItems();

  static const _headerColor = Color(0xFF506D54);
  static const _backgroundColor = Color(0xFFF0F5FA);
  static const _categories = ['Semua', 'Buku', 'Elektronik', 'Fashion',
  ];

  final _searchController = TextEditingController();
  final Set<String> _savedIds = {};

  String _category = 'Semua';
  bool _showSaved = false;

  // untuk fitur pencarian
  Timer? _debounce;
  String _keyword = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // dipanggil tiap kali user ngetik di kolom search
  // pakai jeda 500ms biar ga langsung filter tiap huruf
  void _onSearchChanged(String value) {
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      _clearSearch();
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _keyword = value.trim().toLowerCase();
        _isSearching = false;
      });
    });
  }

  // kalau user tekan enter/search di keyboard, langsung cari
  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    setState(() {
      _keyword = value.trim().toLowerCase();
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _keyword = '';
      _isSearching = false;
    });
  }

  void _retryLoad() {
    setState(() {
      _itemsStream = CatalogService().watchAvailableItems();
    });
  }

  void _selectSavedTab(bool showSaved) {
    FocusScope.of(context).unfocus();
    setState(() => _showSaved = showSaved);
  }

  void _toggleSaved(String itemId) {
    setState(() {
      if (!_savedIds.remove(itemId)) {
        _savedIds.add(itemId);
      }
    });
  }


  void _openDetail(CatalogItem item) {
    FocusScope.of(context).unfocus();

    final customOpenItem = widget.onOpenItem;

    if (customOpenItem != null) {
      customOpenItem(item);
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          if (widget.items != null) {
            return DetailBarangScreen(
              item: item,
              initiallySaved: _savedIds.contains(item.id),
              onToggleSaved: () => _toggleSaved(item.id),
            );
          }

          return DetailBarangByIdScreen(
            barangId: item.id,
            initiallySaved: _savedIds.contains(item.id),
            onToggleSaved: () => _toggleSaved(item.id),
          );
        },
      ),
    );
  }


  void _openPage(VoidCallback? open, String name) {
    FocusScope.of(context).unfocus();

    if (open != null) {
      open();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Halaman $name belum terhubung.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final providedItems = widget.items;

    if (providedItems != null) {
      return _buildCatalog(context, providedItems);
    }

    return StreamBuilder<List<CatalogItem>>(
      stream: _itemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCatalog(
            context,
            const [],
            isLoading: true,
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            '[KATALOG] Gagal memuat data: ${snapshot.error}',
          );

          return _buildCatalog(
            context,
            const [],
            hasError: true,
          );
        }

        return _buildCatalog(
          context,
          snapshot.data ?? const [],
        );
      },
    );
  }

  Widget _buildCatalog(
      BuildContext context,
      List<CatalogItem> items, {
        bool isLoading = false,
        bool hasError = false,
      }) {
    final visibleItems = items.where((item) {
      if (_showSaved) {
        return _savedIds.contains(item.id);
      }

      final matchesCategory =
          _category == 'Semua' || item.category == _category;

      return matchesCategory &&
          item.name.toLowerCase().contains(_keyword);
    }).toList();

    final textScale =
        MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      backgroundColor: _backgroundColor,

      bottomNavigationBar: CatalogBottomNavigation(
        showingSaved: _showSaved,

        onHome: () => _selectSavedTab(false),

        onSaved: () => _selectSavedTab(true),

        onAdd: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadItemScreen(),
            ),
          );
        },

        onMyItems: () => _openPage(
          widget.onOpenMyItems,
          'Barang Saya',
        ),

        onProfile: () => _openPage(
          widget.onOpenProfile,
          'Profil',
        ),
      ),

      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_showSaved)
              _CatalogHeader(
                backgroundColor: _headerColor,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onSearchSubmitted: _onSearchSubmitted,
                onClear: _clearSearch,
              ),

            Expanded(
              child: CustomScrollView(
                key: PageStorageKey<String>(
                  _showSaved
                      ? 'saved-items'
                      : 'catalog-items',
                ),

                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,

                slivers: [
                  if (_showSaved)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          12,
                        ),
                        child: Text(
                          'Barang Tersimpan',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge,
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          6,
                        ),
                        child: Row(
                          children: [
                            for (final category in _categories)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                ),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: _category == category,
                                  selectedColor:
                                  const Color(0xFFE1ECE1),
                                  backgroundColor: Colors.white,
                                  onSelected: (_) {
                                    setState(
                                          () => _category = category,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // info hasil pencarian
                  if (!_showSaved &&
                      _keyword.isNotEmpty &&
                      visibleItems.isNotEmpty &&
                      !_isSearching &&
                      !isLoading &&
                      !hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Text(
                          'Hasil pencarian "${_searchController.text.trim()}" '
                              '(${visibleItems.length} barang)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: const Color(0xFF61758F)),
                        ),
                      ),
                    ),

                  if (_isSearching && !_showSaved)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF506D54),
                            ),
                            SizedBox(height: 12),
                            Text('Mencari barang...'),
                          ],
                        ),
                      ),
                    )
                  else if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF506D54),
                        ),
                      ),
                    )
                  else if (hasError)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: _headerColor,
                              ),

                              const SizedBox(height: 12),

                              const Text(
                                'Gagal memuat data barang.',
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: _retryLoad,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (visibleItems.isEmpty && _keyword.isNotEmpty && !_showSaved)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _SearchNotFound(
                            keyword: _searchController.text.trim(),
                          ),
                        )
                      else if (visibleItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                _showSaved
                                    ? 'Belum ada barang tersimpan.'
                                    : items.isEmpty
                                    ? 'Belum ada barang tersedia.'
                                    : 'Barang tidak ditemukan.',
                              ),
                            ),
                          )

                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              16, 4, 16, 20,
                            ),

                            sliver: SliverGrid(
                              gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                textScale > 1.4 ? 360 : 220,

                                mainAxisExtent:
                                148.0 + 145.0 * textScale,

                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),

                              delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                  final item = visibleItems[index];

                                  return ProductCard(
                                    key: ValueKey(item.id),
                                    item: item,
                                    isSaved: _savedIds.contains(item.id),

                                    onTap: () => _openDetail(item),

                                    onToggleSaved: () =>
                                        _toggleSaved(item.id),
                                  );
                                },

                                childCount: visibleItems.length,
                              ),
                            ),
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.backgroundColor,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClear,
  });

  final Color backgroundColor;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16, 12, 16, 16,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/titipin_logo.png',
                  width: 26,
                  height: 26,
                  excludeFromSemantics: true,

                  errorBuilder: (_, error, stackTrace) =>
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  'Titipin',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              textInputAction: TextInputAction.search,

              decoration: InputDecoration(
                hintText: 'Cari nama barang...',

                prefixIcon: const Icon(Icons.search),

                // tombol X cuma muncul kalau kolom search ada isinya
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: 'Hapus kata kunci',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onClear,
                    );
                  },
                ),

                isDense: true,
                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// tampilan kalau barang yang dicari ga ketemu
class _SearchNotFound extends StatelessWidget {
  const _SearchNotFound({
    required this.keyword,
  });

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/catalog/box_mascot.png',
            width: 110,
            height: 110,
            errorBuilder: (_, error, stackTrace) => const Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Color(0xFF506D54),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Barang tidak ditemukan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada barang dengan kata kunci "$keyword". '
                'Coba pakai kata kunci lain atau ganti kategori.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: const Color(0xFF61758F)),
          ),
        ],
      ),
    );
  }
}