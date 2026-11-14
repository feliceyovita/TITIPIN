
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titipin/app/app.dart';

void main() {
  testWidgets('Aplikasi Titipin menampilkan Splash Screen',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TitipinApp());

        expect(
          find.byKey(const ValueKey('titipin_logo')),
          findsOneWidget,
        );
      });
}
