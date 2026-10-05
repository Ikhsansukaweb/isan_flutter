import 'package:flutter/material.dart';

/// Alat uji isolasi warna: tampilkan HURUF SAJA, tanpa bayangan,
/// tanpa lapisan lain. Kalau di sini masih muncul kuning, berarti
/// kuningnya berasal dari FONT (bukan dari kode animasi).
void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UjiWarna(),
    ));

class UjiWarna extends StatelessWidget {
  const UjiWarna({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Huruf TANPA fontFamily (font default Flutter)
            const Text(
              'ISAN',
              style: TextStyle(
                fontSize: 90,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF2A3B),
              ),
            ),
            const SizedBox(height: 40),

            // 2. Huruf DENGAN font DejaVu (yang dibundel)
            const Text(
              'ISAN',
              style: TextStyle(
                fontFamily: 'DejaVu Sans',
                fontSize: 90,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF2A3B),
              ),
            ),
            const SizedBox(height: 40),

            // 3. Huruf putih (kontrol)
            const Text(
              'ISAN',
              style: TextStyle(
                fontFamily: 'DejaVu Sans',
                fontSize: 90,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),

            // 4. Kotak merah polos (kontrol warna murni)
            Container(
              width: 200,
              height: 60,
              color: const Color(0xFFFF2A3B),
            ),
          ],
        ),
      ),
    );
  }
}
