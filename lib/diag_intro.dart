library diag_intro;

import 'package:flutter/material.dart';
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
