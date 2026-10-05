import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna ISAN — tema merah, sekarang didesain buat dipakai di atas
/// foto background (bukan warna solid polos lagi). Sebagian besar warna
/// "panel" (surface/surfaceAlt/border) sengaja dikasih alpha < 0xFF supaya
/// SEMUA widget yang sudah pakai warna-warna ini (card, sheet, dialog, tab,
/// dll di seluruh app) otomatis jadi kaca/transparan dan background foto di
/// belakangnya tetap keliatan -- tanpa harus ubah satu-satu tiap widget.
class AppColors {
  // Dasar solid, dipakai di halaman yang MEMANG gak punya background foto
  // (contoh: layar player video full-screen).
  static const bg = Color(0xFF0A0505);
  static const bgSolidAlt = Color(0xFF120808);

  // Panel/kartu -- sekarang translucent (kaca), bukan solid lagi.
  // ~90% opacity: cukup transparan buat nampilin background, tapi tetap
  // gampang dibaca ("jangan transparan banget").
  static const surface = Color(0xE6140A0A); // ~90%
  static const surfaceAlt = Color(0xDD1C0F0F); // ~87%
  static const surfaceGlass = Color(0xB3160B0B); // ~70%, versi lebih tembus buat overlay besar

  // Border kaca tipis (putih transparan) -- lebih cocok buat efek glass
  // dibanding abu solid yang lama.
  static const border = Color(0x33FFFFFF);
  static const borderStrong = Color(0x55FFFFFF);

  static const red = Color(0xFFE50914);
  static const redDark = Color(0xFFC8060F);
  static const redGlow = Color(0xFFFF2A3D);

  static const textMuted = Color(0xFFBFAFAF);
  static const textFaint = Color(0xFF8A7676);
  static const purple = Color(0xFFA855F7);
  static const blue = Color(0xFF3B82F6);
  static const gold = Color(0xFFF5C518);
}

/// Path-path aset gambar background. Semua halaman WAJIB pakai salah satu
/// Path gambar latar halaman.
///
/// DULU berisi tiga foto wallpaper (bg_intro / bg_main / bg_account) yang
/// dipasang di belakang setiap halaman. Atas permintaan, wallpaper
/// aplikasi DIHAPUS — jadi ketiganya sekarang kosong dan warna latar
/// diambil dari `AppColors.bg`.
///
/// Namanya sengaja MASIH ADA dan tetap berupa String kosong: ada 11
/// layar yang menuliskan `AppBg.main` / `AppBg.intro` / `AppBg.account`
/// sebagai argumen `AppBackground(image: ...)`. Kalau kelas ini dibuang,
/// kesebelas layar itu gagal dikompilasi. Dengan dibiarkan begini,
/// nilainya cuma tidak dipakai.
class AppBg {
  /// Foto latar layar Intro & Login/Daftar.
  ///
  /// Dipakai HANYA di dua layar itu (layar pembuka dan layar masuk) —
  /// di sana latar bergambar memang diinginkan. Layar lain sengaja
  /// dibiarkan polos supaya isi konten lebih menonjol.
  static const intro = 'assets/images/bg_intro.jpg';

  /// Kosong — foto latar Beranda & tab konten sudah dihapus.
  static const main = '';

  /// Kosong — foto latar halaman Akun sudah dihapus.
  static const account = '';
}

/// Dua font sesuai request: GRIFFY buat judul/teks besar (logo ISAN, judul
/// halaman, header section) dan BELLEZA buat teks kecil/keterangan (body,
/// caption, label). Dipisah jadi helper class ketimbang dipaksa jadi 1
/// fontFamily global, karena Griffy adalah font dekoratif (jelek dipakai
/// buat paragraf panjang) sedangkan Belleza pas buat body.
class AppFonts {
  static TextStyle title({
    double size = 24,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.griffy(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );

  static TextStyle body({
    double size = 13,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
  }) =>
      GoogleFonts.belleza(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );
}

ThemeData buildIsanTheme() {
  final base = ThemeData.dark();
  final bellezaText = GoogleFonts.bellezaTextTheme(base.textTheme).apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.red,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.red,
      secondary: AppColors.purple,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    // Default seluruh teks di app pakai Belleza (sesuai request: font buat
    // teks kecil/keterangan). Judul-judul besar di-override manual pakai
    // `AppFonts.title(...)` (Griffy) di titik-titik yang relevan (logo,
    // judul halaman, header section, dst).
    textTheme: bellezaText,
  );
}
