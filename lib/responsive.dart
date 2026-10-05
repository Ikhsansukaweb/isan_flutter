import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════════
///  PONDASI TAMPILAN DESKTOP  (lib/responsive.dart)
/// ══════════════════════════════════════════════════════════════════
///
///  ATURAN UTAMA — supaya Android TIDAK berubah sama sekali:
///
///     Tampilan desktop dipakai HANYA kalau lebar layar >= 900 piksel
///     (dalam satuan logis/DP).
///
///     Lebar layar HP:
///        HP kecil   : 320 – 400  dp
///        HP besar   : 400 – 480  dp
///        HP lipat   : 480 – 700  dp
///        Tablet HP  : 600 – 840  dp   ← MASIH di bawah 900
///        Desktop    : 900+      dp   ← hanya ini yang dapat tampilan desktop
///
///     Jadi di Android, `Layout.desktop(context)` SELALU bernilai false,
///     dan seluruh kode jalur-HP dijalankan PERSIS seperti sebelumnya.
///
///  Cara pakai di dalam widget:
///
///     final d = Layout.of(context);       // data ukuran layar
///     if (d.desktop) { ...tampilan desktop... }
///     else          { ...tampilan HP (lama)... }
///
///     // atau langsung:
///     if (Layout.desktop(context)) { ... } else { ... }
///
/// ══════════════════════════════════════════════════════════════════
class Layout {
  /// Lebar minimum supaya dianggap layar desktop.
  ///
  /// 900 dp dipilih dengan sengaja: semua HP (termasuk tablet 7 inci)
  /// berada di bawah angka ini, sehingga tampilan HP tidak pernah
  /// tergantikan oleh tampilan desktop.
  static const double ambangDesktop = 900.0;

  /// Lebar minimum untuk tata letak "lebar" (desktop besar).
  static const double ambangLebar = 1400.0;

  final double lebar;
  final double tinggi;

  const Layout(this.lebar, this.tinggi);

  /// Baca ukuran layar sekarang.
  static Layout of(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return Layout(s.width, s.height);
  }

  /// Apakah sekarang di desktop?
  static bool desktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ambangDesktop;

  /// Apakah layar desktop besar?
  static bool lebarSekali(BuildContext context) =>
      MediaQuery.of(context).size.width >= ambangLebar;

  bool get isDesktop => lebar >= ambangDesktop;
  bool get isLebar => lebar >= ambangLebar;

  /// true = tampilan HP (persis seperti sekarang).
  bool get isHp => !isDesktop;

  /// Tinggi area vertikal yang tersedia (tanpa app bar / bottom bar default).
  double get tinggiIsi => tinggi;

  /// ── Ukuran yang dipakai berulang di berbagai layar ──
  /// Semua nilai ini HANYA dipakai saat desktop; jalur HP tetap
  /// memakai angka lamanya masing-masing.

  /// Padding tepi halaman.
  double get paddingTepi => isLebar ? 48 : 32;

  /// Tinggi banner beranda.
  double get tinggiBanner => isLebar ? 460 : 380;

  /// Tinggi baris kartu (poster) horizontal.
  double get tinggiKartu => isLebar ? 300 : 250;

  /// Lebar kartu (poster) horizontal.
  double get lebarKartu => isLebar ? 190 : 160;

  /// Jumlah kolom grid poster.
  /// HP selalu memakai nilai `hp` yang dikirim pemanggil (3, 2, dst).
  int kolom(int hp) {
    if (!isDesktop) return hp;
    if (isLebar) return hp * 3; // desktop besar: 3x lipat
    return (hp * 2).clamp(hp, 8); // desktop biasa: 2x lipat (maks 8)
  }

  /// Lebar sidebar kanan (navigasi desktop).
  double get lebarSidebar => isLebar ? 250 : 220;

  /// Lebar maksimum kolom isi supaya baris tulisan tidak terlalu panjang
  /// di layar lebar (nyaman dibaca).
  double get lebarMaksIsi => 1200;
}
