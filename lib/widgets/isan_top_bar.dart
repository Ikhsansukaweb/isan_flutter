import 'package:flutter/material.dart';
import '../theme.dart';

/// Top bar persisten di semua tab: logo ISAN (merah, gede di Beranda) +
/// tombol cari & akun di kanan — gantiin tombol search elevated di tengah
/// navbar dan tab Akun yang lama (sekarang dipindah ke sini).
class IsanTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isHome;
  final VoidCallback onSearchTap;
  final VoidCallback onAccountTap;
  final VoidCallback onMenuTap;

  const IsanTopBar({
    super.key,
    required this.isHome,
    required this.onSearchTap,
    required this.onAccountTap,
    required this.onMenuTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        color: Colors.transparent,
      child: Row(
        children: [
          // Logo ISAN — digedein & ditonjolin pas di Beranda, dikasih
          // glow merah di belakangnya (request: "background svg merah").
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              if (isHome)
                Positioned(
                  left: -10,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.red.withValues(alpha: 0.55), AppColors.red.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Text(
                    'ISA',
                    style: AppFonts.title(
                      color: Colors.white,
                      weight: FontWeight.w400,
                      size: isHome ? 26 : 20,
                      letterSpacing: 0.5,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1))],
                    ),
                  ),
                  Text(
                    'N',
                    style: AppFonts.title(
                      color: AppColors.red,
                      weight: FontWeight.w400,
                      size: isHome ? 26 : 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          _circleButton(Icons.menu_rounded, onMenuTap),
          const SizedBox(width: 10),
          _circleButton(Icons.search, onSearchTap),
          const SizedBox(width: 10),
          _circleButton(Icons.person, onAccountTap),
        ],
      ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}
