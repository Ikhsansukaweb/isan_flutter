import 'package:flutter/material.dart';

/// Diagnosa: menampilkan canvas intro TANPA lapisan sapuan lensa,
/// untuk membuktikan apakah sapuan itu sumber warna kuning.
/// Dibuka lewat: lib/diag_intro.dart
library;

import 'widgets/animasi_intro_isan.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DiagIntro(),
    ));

class DiagIntro extends StatelessWidget {
  const DiagIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: AnimasiIntroIsan(
        // setelan bawaan — untuk melihat apakah kuning muncul di sini
        setelahSelesai: _kosong,
      ),
    );
  }

  static void _kosong() {}
}
