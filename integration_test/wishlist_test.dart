import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:titipin/features/catalog/catalog_screen.dart';
import 'package:titipin/firebase_options.dart';

// Hanya untuk Android Emulator dengan Auth dan Firestore Emulator di host.
const _host = '10.0.2.2';
const _headers = {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'};

Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (!condition() && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(condition(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wishlist persisten, privat, dan tetap dapat dihapus saat listing hilang', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await auth.useAuthEmulator(_host, 9099);
    db.useFirestoreEmulator(_host, 8080);
    final run = DateTime.now().millisecondsSinceEpoch;
    final id = 'wishlist-$run';
    final title = 'Buku Algoritma $run';
    final project = Firebase.app().options.projectId;
    final documents = 'http://$_host:8080/v1/projects/$project/databases/(default)/documents';
    final password = 'Emulator-only-$run';

    Future<User> register(String account) async {
      final email = 'wishlist-$account-$run@students.usu.ac.id';
      final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      final verified = await http.post(
        Uri.parse('http://$_host:9099/identitytoolkit.googleapis.com/v1/projects/$project/accounts:update'),
        headers: _headers, body: jsonEncode({'localId': uid, 'emailVerified': true}),
      );
      expect(verified.statusCode, 200, reason: verified.body);
      await auth.signOut();
      return (await auth.signInWithEmailAndPassword(email: email, password: password)).user!;
    }

    Future<void> fixture(String path, Map<String, dynamic> fields) async {
      final response = await http.patch(Uri.parse('$documents/$path'), headers: _headers,
          body: jsonEncode({'fields': fields}));
      expect(response.statusCode, 200, reason: response.body);
    }

    Future<void> openCatalog() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MaterialApp(home: CatalogScreen()));
      await waitFor(tester, () => find.text(title).evaluate().isNotEmpty);
    }

    Finder heart(String label) => find.descendant(
        of: find.byKey(ValueKey(id)), matching: find.byTooltip(label));
    Future<void> tapHeart(String label) async {
      final button = heart(label);
      await waitFor(tester, () => button.evaluate().isNotEmpty &&
          tester.widget<IconButton>(find.ancestor(of: button, matching: find.byType(IconButton)).first).onPressed != null);
      await tester.tap(button);
      await tester.pump();
    }

    final a = await register('a');
    final fields = {
      'namaBarang': {'stringValue': title}, 'harga': {'integerValue': '75000'},
      'kategoriId': {'stringValue': 'buku'}, 'kondisi': {'stringValue': 'Bekas - Tanpa minus'},
      'lokasi': {'stringValue': 'USU'}, 'deskripsi': {'stringValue': 'Buku untuk uji wishlist.'},
      'userId': {'stringValue': a.uid}, 'statusBarang': {'stringValue': 'tersedia'},
    };
    await fixture('kategori/buku', {'namaKategori': {'stringValue': 'Buku'}});
    await fixture('barang/$id', fields);
    await openCatalog();
    debugPrint('WISHLIST_TEST_READY');
    await tester.pump(const Duration(seconds: 2));
    await tapHeart('Simpan barang');
    await waitFor(tester, () => heart('Batal simpan').evaluate().isNotEmpty);
    final filledHeart = tester.widget<Icon>(find.descendant(
        of: find.byKey(ValueKey(id)), matching: find.byIcon(Icons.favorite)));
    expect(filledHeart.color, Colors.red);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(title));
    await waitFor(tester, () => find.text('Detail Barang').evaluate().isNotEmpty &&
        find.text('Tersimpan').evaluate().isNotEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await auth.signOut();
    final b = await register('b');
    await openCatalog();
    await tester.tap(find.text('Simpan'));
    await waitFor(tester, () => find.text('Belum ada barang tersimpan.').evaluate().isNotEmpty);
    await expectLater(db.doc('users/${a.uid}/wishlist/$id').get(const GetOptions(source: Source.server)),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    await tapHeart('Simpan barang');
    await waitFor(tester, () => heart('Batal simpan').evaluate().isNotEmpty);
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: a.email!, password: password);
    await openCatalog();
    await tester.tap(find.text('Simpan'));
    await waitFor(tester, () => heart('Batal simpan').evaluate().isNotEmpty);

    await fixture('barang/$id', {...fields, 'statusBarang': {'stringValue': 'terjual'}});
    await waitFor(tester, () => find.text('Tidak tersedia').evaluate().isNotEmpty);
    final deleted = await http.delete(Uri.parse('$documents/barang/$id'), headers: _headers);
    expect(deleted.statusCode, 200);
    await tester.tap(find.text(title));
    await waitFor(tester, () => find.text('Barang sudah tidak tersedia.').evaluate().isNotEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapHeart('Batal simpan');
    await waitFor(tester, () => find.text('Belum ada barang tersimpan.').evaluate().isNotEmpty);
    expect((await db.doc('users/${a.uid}/wishlist/$id').get(const GetOptions(source: Source.server))).exists, isFalse);
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: b.email!, password: password);
    expect((await db.doc('users/${b.uid}/wishlist/$id').get(const GetOptions(source: Source.server))).exists, isTrue);
    debugPrint('Dokumen bukti emulator: users/${b.uid}/wishlist/$id');
  });
}
