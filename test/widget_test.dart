// Tes dasar untuk aplikasi ISAN.
//
// Catatan: file ini asalnya template bawaan `flutter create` yang menguji
// aplikasi "counter" contoh. Sudah diganti karena ISAN tidak punya counter —
// yang diuji di sini hanya hal yang aman tanpa jaringan/DB.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('aplikasi bisa merender MaterialApp sederhana', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('ISAN'))),
      ),
    );

    expect(find.text('ISAN'), findsOneWidget);
  });
}
