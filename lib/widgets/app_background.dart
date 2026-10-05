import 'package:flutter/material.dart';
import '../theme.dart';

/// Pembungkus latar halaman.
///
/// DULU ini memasang FOTO wallpaper di belakang setiap halaman
/// (assets/images/bg_*.jpg) plus dua lapis gradasi di atasnya. Atas
/// permintaan, wallpaper aplikasi dihapus — jadi widget ini sekarang
/// hanya memberi warna latar TEMA yang rata.
///
/// Kenapa widgetnya tidak langsung dihapus saja dari 11 layar?
/// Karena kalau ada satu saja pemakaian yang ketinggalan, proyeknya
/// gagal di-build. Mengubah isinya di SATU tempat ini membuat semua
/// layar ikut bersih sekaligus, dan nama `AppBackground` tetap ada
/// sehingga tidak ada berkas layar yang perlu disentuh.
///
/// Parameter `image` masih diterima supaya pemanggil lama tidak perlu
/// diubah, tapi nilainya tidak dipakai lagi.
class AppBackground extends StatelessWidget {
  /// Alamat gambar latar.
  ///
  /// Kosong berarti latar polos (hanya warna tema). Dipakai layar
  /// yang memang TIDAK berlatar gambar, mis. beranda dan tab konten.
  final String image;

  final Widget child;

  /// Seberapa pekat lapisan gelap di atas gambar.
  ///
  /// 0 = gambar apa adanya; 1 = gambar tertutup penuh. Dipakai supaya
  /// tulisan di atas gambar tetap terbaca.
  final double overlayStrength;

  const AppBackground({
    super.key,
    this.image = '',
    required this.child,
    this.overlayStrength = 0,
  });

  @override
  Widget build(BuildContext context) {
    // ── Latar polos ──
    // Dipakai kalau tidak ada gambar: cuma warna tema.
    if (image.isEmpty) {
      return ColoredBox(color: AppColors.bg, child: child);
    }

    // ── Latar bergambar ──
    // Gambar menutupi seluruh layar; lapisan gelap tipis di atasnya
    // supaya teks (judul, tombol) tetap terbaca. Kalau gambarnya
    // gagal dimuat, yang tampil warna tema — bukan layar rusak.
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.bg),
        ),
        if (overlayStrength > 0)
          IgnorePointer(
            child: ColoredBox(
              color: AppColors.bg.withOpacity(overlayStrength.clamp(0.0, 1.0)),
            ),
          ),
        child,
      ],
    );
  }
}
