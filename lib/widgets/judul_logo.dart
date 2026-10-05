import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

/// Tulisan judul bergaya filmnya sendiri — bukan teks biasa, melainkan
/// PNG transparan dari TMDB `images.logos` (mis. huruf "MOANA" yang
/// terbuat dari air). Backend mengirimnya lewat field `logo`/`logoBesar`.
///
/// Dipakai di halaman detail film & series, di sisi KANAN backdrop.
///
/// Selalu ada nilai yang dikembalikan:
///   * kalau [url] ada   -> gambar logo (lebar dibatasi, tinggi mengikuti
///                          rasio aslinya, efek bayangan biar terbaca di
///                          atas backdrop yang ramai)
///   * kalau [url] kosong -> teks [judul] sebagai pengganti
///   * kalau gambar gagal dimuat -> teks [judul] juga
///
/// [maxLebar] & [maxTinggi] sengaja dibatasi: logo TMDB ada yang sangat
/// lebar (rasio 5:1) dan ada yang hampir persegi, jadi tingginya ditulis
/// `null` supaya rasio aslinya tidak dipaksa gepeng.
class JudulLogo extends StatelessWidget {
  /// URL PNG logo (sudah lewat Api.imgProxy bila berasal dari sumber luar).
  final String url;

  /// Judul untuk cadangan teks + keterangan aksesibilitas.
  final String judul;

  /// Batas lebar logo. Kalau layar lebih sempit, otomatis mengecil.
  final double maxLebar;

  /// Batas tinggi logo.
  final double maxTinggi;

  /// Ukuran teks cadangan (dipakai saat logo tidak tersedia).
  final double ukuranTeks;

  /// Perataan isi kotak.
  final Alignment perataan;

  const JudulLogo({
    super.key,
    required this.url,
    required this.judul,
    this.maxLebar = 220,
    this.maxTinggi = 96,
    this.ukuranTeks = 20,
    this.perataan = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _teks();

    final Align gambar = Align(
      alignment: perataan,
      child: Image.network(
        // Logo TMDB datang dari domain luar -> wajib lewat proxy backend.
        Api.imgProxy(url),
        // Lebar dibatasi, tinggi mengikuti rasio asli (null = jangan
        // dipaksa), supaya logo memanjang tidak jadi pipih.
        width: maxLebar,
        height: null,
        fit: BoxFit.contain,
        alignment: perataan,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _teks(),
        // Bayangan hitam lembut di sekeliling logo supaya tetap terbaca
        // walau bagian backdrop di belakangnya terang.
        loadingBuilder: (ctx, anak, progres) {
          if (progres == null) return anak;
          return SizedBox(
            width: maxLebar,
            height: maxTinggi,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.red,
                ),
              ),
            ),
          );
        },
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxLebar, maxHeight: maxTinggi),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 18, spreadRadius: 2),
            ],
          ),
          child: gambar,
        ),
      ),
    );
  }

  /// Cadangan: teks judul diwarnai seperti judul halaman lain.
  Widget _teks() => Text(
        judul,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: perataan == Alignment.center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontSize: ukuranTeks,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.15,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
        ),
      );
}
