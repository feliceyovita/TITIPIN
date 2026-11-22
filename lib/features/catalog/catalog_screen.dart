import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../upload_item/upload_item_screen.dart';
import 'catalog_item.dart';
import 'data/catalog_service.dart';
import 'detail_barang_screen.dart';
import 'edit_barang_screen.dart';
import 'widgets/catalog_bottom_navigation.dart';
import 'widgets/product_card.dart';

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
  static const _categories = [
    'Semua',
    'Buku',
    'Elektronik',
    'Fashion',
    'Kecantikan',
    'Perlengkapan Kuliah',
    'Perlengkapan Kos',
    'Olahraga & Hobi',
    'Lainnya',
  ];

  final _catalogService = CatalogService();
  final _searchController = TextEditingController();
  final _myItemsSearchController = TextEditingController();
  final Set<String> _savedIds = {};

  late Stream<List<CatalogItem>> _itemsStream =
  _catalogService.watchAvailableItems();
  Stream<List<CatalogItem>>? _myItemsStream;

  String _category = 'Semua';
  _CatalogTab _activeTab = _CatalogTab.home;

  bool get _showSaved => _activeTab == _CatalogTab.saved;
  bool get _showMyItems => _activeTab == _CatalogTab.myItems;

  TextEditingController get _activeSearchController =>
      _showMyItems ? _myItemsSearchController : _searchController;

  @override
  void dispose() {
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

  void _retryLoad() {
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
    setState(() {
      _activeTab = showSaved ? _CatalogTab.saved : _CatalogTab.home;
    });
  }

  void _selectMyItemsTab() {
    FocusScope.of(context).unfocus();

    final openMyItems = widget.onOpenMyItems;
    if (openMyItems != null) {
      openMyItems();
      return;
    }

    if (_showMyItems) return;

    setState(() {
      _myItemsStream = _loadMyItems();
      _activeTab = _CatalogTab.myItems;
    });
  }

  void _toggleSaved(String itemId) {
    setState(() {
      if (!_savedIds.remove(itemId)) {
        _savedIds.add(itemId);
      }
    });
  }

  Future<void> _openDetail(CatalogItem item) async {
    FocusScope.of(context).unfocus();

    if (_showMyItems) {
      final hasil = await Navigator.of(context).push<EditBarangResult>(
        MaterialPageRoute<EditBarangResult>(
          builder: (_) => EditBarangScreen(
            item: item,
            kategoriTersedia: _categories
                .where((kategori) => kategori != 'Semua')
                .toList(),
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
                  ? 'Permintaan hapus dikonfirmasi.'
                  : 'Isian edit siap diteruskan.',
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
        builder: (_) {
          final initiallySaved = _savedIds.contains(item.id);

          if (widget.items != null) {
            return DetailBarangScreen(
              item: item,
              initiallySaved: initiallySaved,
              onToggleSaved: () => _toggleSaved(item.id),
            );
          }

          return DetailBarangByIdScreen(
            barangId: item.id,
            initiallySaved: initiallySaved,
            onToggleSaved: () => _toggleSaved(item.id),
          );
        },
      ),
    );
  }

  void _openProfile() {
    FocusScope.of(context).unfocus();

    final openProfile = widget.onOpenProfile;
    if (openProfile != null) {
      openProfile();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Halaman Profil belum terhubung.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final providedItems = widget.items;

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
    final query = _activeSearchController.text.trim().toLowerCase();

    final visibleItems = items.where((item) {
      if (_showSaved) {
        return _savedIds.contains(item.id);
      }

      final matchesCategory =
          _showMyItems || _category == 'Semua' || item.category == _category;

      return matchesCategory && item.name.toLowerCase().contains(query);
    }).toList();

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      backgroundColor: _backgroundColor,
      bottomNavigationBar: CatalogBottomNavigation(
        showingSaved: _showSaved,
        showingMyItems: _showMyItems,
        onHome: () => _selectSavedTab(false),
        onSaved: () => _selectSavedTab(true),
        onAdd: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const UploadItemScreen(),
            ),
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
            if (!_showSaved)
              _CatalogHeader(
                backgroundColor: _headerColor,
                searchController: _activeSearchController,
                onSearchChanged: (_) => setState(() {}),
              ),
            Expanded(
              child: CustomScrollView(
                key: PageStorageKey<_CatalogTab>(_activeTab),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (_showSaved)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: Text(
                          'Barang Tersimpan',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    )
                  else if (!_showMyItems)
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
                  if (isLoading)
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
                  else if (visibleItems.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(_emptyMessage(items)),
                        ),
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
                          gridDelegate:
                          SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: textScale > 1.4 ? 360 : 220,
                            mainAxisExtent: 148.0 + 145.0 * textScale,
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
                                showSaveButton: !_showMyItems,
                                onTap: () => _openDetail(item),
                                onToggleSaved: () => _toggleSaved(item.id),
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

  String _emptyMessage(List<CatalogItem> items) {
    if (_showSaved) return 'Belum ada barang tersimpan.';
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
  });

  final Color backgroundColor;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

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
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama barang...',
                prefixIcon: const Icon(Icons.search),
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