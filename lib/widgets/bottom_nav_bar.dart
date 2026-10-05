import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'nav_svg_icons.dart';

/// Bottom navbar MELAYANG (floating pill) ala LokLok -- gak nempel penuh ke
/// tepi layar, ada margin di kiri/kanan/bawah, sudut membulat penuh, dan
/// shadow biar keliatan "ngambang" di atas konten.
class IsanBottomNavBar extends StatelessWidget {
  final int currentIndex; // 0 beranda, 1 film, 2 series, 3 anime, 4 musik, 5 akun
  final ValueChanged<int> onTap;

  const IsanBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    ('Beranda', NavSvgIcons.home),
    ('Film', NavSvgIcons.movie),
    // Series & Anime DIHAPUS dari navbar atas permintaan pemilik
    // aplikasi: halaman terpisah untuk keduanya dihapus, dan menggantinya
    // cukup lewat FILTER di halaman Film (jenis: Film/Series/Anime/Drakor).
    // Tempatnya sekarang dipakai Playlist — lebih sering dibuka.
    ('Playlist', NavSvgIcons.playlist),
    ('Musik', NavSvgIcons.music),
    ('Akun', NavSvgIcons.account),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad > 0 ? bottomPad * 0.5 : 10),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border, width: 0.8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final (label, svg) = _items[i];
            return _NavItem(
              label: label,
              svg: svg,
              active: currentIndex == i,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final String Function(String color) svg;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.svg,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge bulat merah di belakang icon kalau lagi aktif —
            // ini bagian "background svg warna merah" yang diminta.
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.red : Colors.transparent,
                boxShadow: active
                    ? [BoxShadow(color: AppColors.red.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: SvgPicture.string(svg(active ? '#FFFFFF' : '#888888')),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
