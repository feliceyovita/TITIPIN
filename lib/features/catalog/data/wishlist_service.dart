import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../catalog_item.dart';

/// Satu dokumen per barang per akun. Ringkasan dipakai jika listing sudah hilang.
class WishlistService extends ChangeNotifier {
  WishlistService() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      _listen(user?.uid);
    });
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<Map<String, CatalogItem>>? _subscription;
  final _pending = <String>{};
  Map<String, CatalogItem> _saved = {};
  String? _uid;
  int _generation = 0;
  bool ready = false;
  bool hasError = false;

  int get count => _saved.length;
  bool contains(String id) => _saved.containsKey(id);
  bool canChange(String id) => ready && !_pending.contains(id) &&
      _uid != null && _uid == _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('wishlist');

  void retry() => _listen(_auth.currentUser?.uid);

  void _listen(String? uid) {
    final generation = ++_generation;
    _subscription?.cancel();
    _uid = uid;
    _saved = {};
    _pending.clear();
    ready = false;
    hasError = uid == null;
    notifyListeners();
    if (uid == null) return;

    _subscription = _collection(uid).snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => {
          for (final doc in snapshot.docs) doc.id: _readSummary(doc.id, doc.data()),
        }).listen((saved) {
      if (_generation != generation) return;
      // Snapshot lokal dari operasi hapus dapat langsung menghilangkan dokumen.
      // Pertahankan status lama sampai Future penulisan selesai di server.
      for (final id in _pending) {
        final previous = _saved[id];
        if (previous == null) {
          saved.remove(id);
        } else {
          saved[id] = previous;
        }
      }
      _saved = saved;
      ready = true;
      hasError = false;
      notifyListeners();
    }, onError: (Object error) {
      if (_generation != generation) return;
      ready = false;
      hasError = true;
      notifyListeners();
    });
  }

  CatalogItem _readSummary(String id, Map<String, dynamic> data) {
    final photo = data['fotoUrl'];
    return CatalogItem(
      id: id,
      name: data['namaBarang'] as String,
      price: data['harga'] as int,
      category: data['kategori'] as String,
      categoryId: data['kategoriId'] as String,
      condition: data['kondisi'] as String,
      fotoBarang: [
        if (photo is String && photo.isNotEmpty) {'url': photo},
      ],
      status: 'tidak tersedia',
    );
  }

  List<CatalogItem> resolveItems(List<CatalogItem> available) {
    final live = {for (final item in available) item.id: item};
    return [for (final entry in _saved.entries) live[entry.key] ?? entry.value];
  }

  Future<void> toggle(CatalogItem item) async {
    if (!canChange(item.id)) return;
    final generation = _generation;
    final ref = _collection(_uid!).doc(item.id);
    _pending.add(item.id);
    notifyListeners();
    try {
      if (contains(item.id)) {
        await ref.delete();
        if (generation == _generation) _saved.remove(item.id);
      } else {
        final data = <String, dynamic>{
          'namaBarang': item.name,
          'harga': item.price,
          'kategori': item.category,
          'kategoriId': item.categoryId,
          'kondisi': item.condition,
          'fotoUrl': item.fotoBarang.isNotEmpty &&
                  item.fotoBarang.first['url'] == item.primaryPhotoSource
              ? item.primaryPhotoSource : '',
        };
        await ref.set(data);
        if (generation == _generation) _saved[item.id] = _readSummary(item.id, data);
      }
    } finally {
      if (generation == _generation) {
        _pending.remove(item.id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _authSubscription.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
