import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/kategori_barang.dart';
import '../upload_item/upload_item_screen.dart';
import 'catalog_item.dart';
import 'data/catalog_service.dart';
import 'data/wishlist_service.dart';
import 'detail_barang_screen.dart';
import 'edit_barang_screen.dart';
import 'widgets/catalog_bottom_navigation.dart';
import 'widgets/product_card.dart';
import '../profile/profile_screen.dart';

enum _CatalogTab { home, saved, myItems }

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
  static const _headerColor = Color(0xFF506D54);
  static const _backgroundColor = Color(0xFFF0F5FA);
  static final _categories = ['Semua', ...kategoriBarang.keys];

  final _catalogService = CatalogService();
  final _searchController = TextEditingController();
  final _myItemsSearchController = TextEditingController();
  late final _wishlist = WishlistService();

  late Stream<List<CatalogItem>> _itemsStream = _catalogService
      .watchAvailableItems();
  Stream<List<CatalogItem>>? _myItemsStream;

  String _category = 'Semua';
  _CatalogTab _activeTab = _CatalogTab.home;

  bool get _showSaved => _activeTab == _CatalogTab.saved;
  bool get _showMyItems => _activeTab == _CatalogTab.myItems;

  TextEditingController get _activeSearchController =>
      _showMyItems ? _myItemsSearchController : _searchController;

  // untuk fitur pencarian
  Timer? _debounce;
  String _keyword = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _wishlist.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _myItemsSearchController.dispose();
    super.dispose();
  }

  Stream<List<CatalogItem>> _loadMyItems() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream<List<CatalogItem>>.value(const <CatalogItem>[]);
    }

    return _catalogService.watchMyItems(uid);
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
    _activeSearchController.clear();
    setState(() {
      _keyword = '';
      _isSearching = false;
    });
  }

  // cek apakah barang cocok sama kata kunci
  // dicari dari nama barang, nama kategori, dan tag barang
  bool _cocokDenganKeyword(CatalogItem item) {
    if (_keyword.isEmpty) return true;

    final cocokNama = item.name.toLowerCase().contains(_keyword);
    final cocokKategori = item.category.toLowerCase().contains(_keyword);
    final cocokTag = item.tags.any(
          (tag) => tag.toLowerCase().contains(_keyword),
    );

    return cocokNama || cocokKategori || cocokTag;
  }

  void _retryLoad() {
    if (_wishlist.hasError) _wishlist.retry();
    setState(() {
      if (_showMyItems) {
        _myItemsStream = _loadMyItems();
      } else {
        _itemsStream = _catalogService.watchAvailableItems();
      }
    });
  }


  void _selectSavedTab(bool showSaved) {
    FocusScope.of(context).unfocus();

    _debounce?.cancel();
    _searchController.clear();

    setState(() {
      _activeTab = showSaved
          ? _CatalogTab.saved
          : _CatalogTab.home;

      _keyword = '';
      _isSearching = false;
    });
  }


  void _selectMyItemsTab() {
    FocusScope.of(context).unfocus();

    final openMyItems = widget.onOpenMyItems;
    if (openMyItems != null) {
      openMyItems();
      return;
    }

    _selectTab(_CatalogTab.myItems);
  }

  void _selectTab(_CatalogTab tab) {
    if (_activeTab == tab) return;

    _debounce?.cancel();
    setState(() {
      if (tab == _CatalogTab.myItems) {
        _myItemsStream = _loadMyItems();
      }

      _activeTab = tab;
      _keyword = _activeSearchController.text.trim().toLowerCase();
      _isSearching = false;
    });
  }

  Future<void> _toggleSaved(CatalogItem item) async {
    try {
      await _wishlist.toggle(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan wishlist gagal. Coba lagi.')),
      );
    }
  }

  Future<void> _openDetail(CatalogItem item) async {
    FocusScope.of(context).unfocus();

    if (_showMyItems) {
      final hasil = await Navigator.of(context).push<EditBarangResult>(
        MaterialPageRoute<EditBarangResult>(
          builder: (_) => EditBarangScreen(
            item: item,
            kategoriTersedia: kategoriBarang.keys.toList(),
          ),
        ),
      );

      if (!mounted || hasil == null) return;


      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              hasil.hapus
                  ? 'Barang berhasil dihapus.'
                  : 'Perubahan barang berhasil disimpan.',
            ),
          ),
        );
      return;
    }

    final customOpenItem = widget.onOpenItem;
    if (customOpenItem != null) {
      customOpenItem(item);
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ListenableBuilder(
          listenable: _wishlist,
          builder: (_, _) {
            final saved = _wishlist.contains(item.id);
            final toggle = _wishlist.canChange(item.id)
                ? () => _toggleSaved(item)
                : null;
            if (widget.items != null) {
              return DetailBarangScreen(
                item: item, initiallySaved: saved, onToggleSaved: toggle,
              );
            }
            return DetailBarangByIdScreen(
              barangId: item.id, initiallySaved: saved, onToggleSaved: toggle,
            );
          },
        ),
      ),
    );
  }


  Future<void> _openProfile() async {
    FocusScope.of(context).unfocus();

    final customOpenProfile = widget.onOpenProfile;
    if (customOpenProfile != null) {
      customOpenProfile();
      return;
    }

    final destination =
    await Navigator.of(context).push<ProfileDestination>(
      MaterialPageRoute<ProfileDestination>(
        builder: (_) => ListenableBuilder(
          listenable: _wishlist,
          builder: (_, _) => ProfileScreen(savedCount: _wishlist.count),
        ),
      ),
    );

    if (!mounted) return;

    switch (destination) {
      case ProfileDestination.home:
        _selectTab(_CatalogTab.home);
        break;
      case ProfileDestination.saved:
        _selectTab(_CatalogTab.saved);
        break;
      case ProfileDestination.myItems:
        _selectMyItemsTab();
        break;
      case null:
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _wishlist,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final providedItems = widget.items;
    if (_showSaved && !_wishlist.ready) {
      return _buildCatalog(context, const [],
          isLoading: !_wishlist.hasError, hasError: _wishlist.hasError);
    }

    if (!_showMyItems && providedItems != null) {
      return _buildCatalog(context, providedItems);
    }

    return StreamBuilder<List<CatalogItem>>(
      key: ValueKey(_showMyItems),
      stream: _showMyItems ? _myItemsStream : _itemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCatalog(context, const [], isLoading: true);
        }

        if (snapshot.hasError) {
          debugPrint('[KATALOG] Gagal memuat data: ${snapshot.error}');
          return _buildCatalog(context, const [], hasError: true);
        }

        return _buildCatalog(context, snapshot.data ?? const []);
      },
    );
  }

  Widget _buildCatalog(
      BuildContext context,
      List<CatalogItem> items, {
        bool isLoading = false,
        bool hasError = false,
      }) {

    final selectedCategoryId = kategoriBarang[_category]?.toLowerCase();

    final source = _showSaved ? _wishlist.resolveItems(items) : items;
    final visibleItems = source.where((item) {

      final matchesCategory =
          _showMyItems ||
              _category == 'Semua' ||
              (item.categoryId.isEmpty
                  ? item.category.toLowerCase() == _category.toLowerCase()
                  : item.categoryId.toLowerCase() == selectedCategoryId);

      final matchesSearch = _cocokDenganKeyword(item);

      return matchesCategory && matchesSearch;
    }).toList();


    final searchText = _activeSearchController.text.trim();
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      backgroundColor: _backgroundColor,
      bottomNavigationBar: CatalogBottomNavigation(
        showingSaved: _showSaved,
        showingMyItems: _showMyItems,
        onHome: () => _selectSavedTab(false),
        onSaved: () => _selectSavedTab(true),
        onAdd: widget.onAddItem ?? () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const UploadItemScreen()),
          );
        },
        onMyItems: _selectMyItemsTab,
        onProfile: _openProfile,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CatalogHeader(
              backgroundColor: _headerColor,
              searchController: _activeSearchController,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: _onSearchSubmitted,
              onClear: _clearSearch,
            ),
            Expanded(
              child: CustomScrollView(
                key: PageStorageKey<_CatalogTab>(_activeTab),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (_wishlist.hasError && !_showSaved && !_showMyItems)
                    SliverToBoxAdapter(
                      child: ListTile(
                        title: const Text('Simpan Barang tidak dapat dimuat.'),
                        trailing: TextButton(
                          onPressed: _wishlist.retry,
                          child: const Text('Coba lagi'),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: [
                          for (final category in _categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: _category == category,
                                selectedColor: const Color(0xFFE1ECE1),
                                backgroundColor: Colors.white,
                                onSelected: (_) {
                                  setState(() => _category = category);
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
                          'Hasil pencarian "$searchText" '
                              '(${visibleItems.length} barang)',
                          style: Theme.of(context).textTheme.bodySmall
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
                            CircularProgressIndicator(color: Color(0xFF506D54)),
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
                        child: CircularProgressIndicator(color: _headerColor),
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
                    else if (visibleItems.isEmpty &&
                          _keyword.isNotEmpty &&
                          !_showSaved)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _SearchNotFound(keyword: searchText),
                        )
                      else if (visibleItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text(_emptyMessage(items))),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              _showMyItems ? 20 : 4,
                              16,
                              20,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: textScale > 1.4 ? 360 : 220,
                                mainAxisExtent: 148.0 + 145.0 * textScale,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate((context, index) {
                                final item = visibleItems[index];

                                return ProductCard(
                                  key: ValueKey(item.id),
                                  item: item,
                                  isSaved: _wishlist.contains(item.id),
                                  showSaveButton: !_showMyItems,
                                  showStatus: _showMyItems || _showSaved,
                                  onTap: () => _openDetail(item),
                                  onToggleSaved: _wishlist.canChange(item.id)
                                      ? () => _toggleSaved(item) : null,
                                );
                              }, childCount: visibleItems.length),
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

  String _emptyMessage(List<CatalogItem> items) {
    if (_showSaved) {
      return _wishlist.count == 0 ? 'Belum ada barang tersimpan.' : 'Barang tidak ditemukan.';
    }
    if (items.isNotEmpty) return 'Barang tidak ditemukan.';

    return _showMyItems
        ? 'Kamu belum mengunggah barang.'
        : 'Belum ada barang tersedia.';
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  errorBuilder: (_, error, stackTrace) => const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Titipin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                hintText: 'Cari nama, kategori, atau tag...',

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
  const _SearchNotFound({required this.keyword});

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
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada barang dengan kata kunci "$keyword". '
                'Coba pakai kata kunci lain atau ganti kategori.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF61758F)),
          ),
        ],
      ),
    );
  }
}
