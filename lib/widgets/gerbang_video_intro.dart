import 'package:flutter/material.dart';

import 'animasi_intro_isan.dart';

/// ════════════════════════════════════════════════════════════════════
///  GERBANG ANIMASI INTRO ISAN
/// ════════════════════════════════════════════════════════════════════
///
///  Membungkus [anak] (yaitu AuthGate). Sebelum anak ditampilkan,
///  animasi logo ISAN diputar.
///
///  ── PERILAKU (diubah atas permintaan) ────────────────────────────
///
///     SEBELUMNYA: hanya pada pemasangan PERTAMA (penanda di
///                 SharedPreferences). Buka kedua & seterusnya → dilewati.
///
///     SEKARANG  : SETIAP KALI app dibuka, animasi selalu ditampilkan.
///                 Tidak ada lagi penanda/penyimpanan.
///
///  Catatan: kode penanda SharedPreferences sengaja TIDAK dihapus,
///  hanya tidak dipakai — supaya mudah dikembalikan bila nanti mau
///  lagi. Lihat blok komentar di bawah.
///
///  Animasi memakai Flutter (lib/widgets/animasi_intro_isan.dart),
///  BUKAN berkas video .mp4. Alasannya: decoder video perangkat keras
///  di sejumlah HP (mis. Infinix X655C / MediaTek MT6765) rusak dan
///  menolak SEMUA berkas H.264, sedangkan decoder perangkat lunak pun
///  tidak tersedia. Animasi Flutter tidak memakai decoder sama sekali.
class GerbangVideoIntro extends StatefulWidget {
  const GerbangVideoIntro({super.key, required this.anak});

  /// Halaman yang ditampilkan setelah animasi selesai.
  final Widget anak;

  // ────────────────────────────────────────────────────────────────────
  //  KODE CADANGAN — perilaku "hanya sekali" (tidak dipakai sekarang).
  //
  //  Kalau nanti mau kembali ke perilaku lama (hanya pertama kali),
  //  ubah build() di bawah menjadi:
  //
  //      static bool _sudahDiperiksa = false;
  //      bool? _perluPutarVideo;   // null = masih membaca
  //
  //  dan kembalikan _periksa() memakai SharedPreferences dengan kunci:
  //
  //      static const String kunciPenyimpanan =
  //          'isan_intro_video_sudah_diputar_v4';
  //
  //  lalu di build(): jika _perluPutarVideo == null → tunggu,
  //  jika true → tampilkan AnimasiIntroIsan, jika false → widget.anak.
  // ────────────────────────────────────────────────────────────────────

  /// Nama kunci cadangan (tidak dipakai lagi, disimpan untuk dokumentasi).
  static const String kunciPenyimpananCadangan =
      'isan_intro_video_sudah_diputar_v4';

  @override
  State<GerbangVideoIntro> createState() => _GerbangVideoIntroState();
}

class _GerbangVideoIntroState extends State<GerbangVideoIntro> {
  /// Sudah selesai memperlihatkan animasi?
  bool _selesai = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[GERBANG INTRO] dibuka — animasi akan ditampilkan');
  }

  void _selesaikan() {
    if (!mounted) return;
    debugPrint('[GERBANG INTRO] animasi selesai — lanjut ke aplikasi');
    setState(() => _selesai = true);
  }

  @override
  Widget build(BuildContext context) {
    // Animasi ditampilkan SETIAP KALI aplikasi dibuka.
    if (!_selesai) {
      return AnimasiIntroIsan(setelahSelesai: _selesaikan);
    }
    return widget.anak;
  }
}
