import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'nav_svg_icons.dart';

/// ══════════════════════════════════════════════════════════════════
///  SIDEBAR KANAN — NAVIGASI KHUSUS DESKTOP
/// ══════════════════════════════════════════════════════════════════
///
///  Pengganti floating bottom navbar saat aplikasi dibuka di desktop.
///  Ditaruh di SISI KANAN sesuai permintaan, berisi:
///     • logo & nama aplikasi (atas)
///     • tombol navigasi utama (tengah)
///     • tombol akun / riwayat (bawah)
///
///  Widget ini TIDAK dipakai di Android maupun di jalur HP: pemanggilnya
///  (root_shell.dart) hanya memanggilnya kalau lebar layar >= 900.
///  Jadi tampilan HP/Android sama sekali tidak tersentuh.
/// ══════════════════════════════════════════════════════════════════
class IsanSidebarKanan extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAccountTap;
  final VoidCallback onHistoryTap;
  final double lebar;

  const IsanSidebarKanan({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onSearchTap,
    required this.onAccountTap,
    required this.onHistoryTap,
    this.lebar = 220,
  });

  /// Label + fungsi pembuat ikon SVG (ikonnya butuh warna sebagai argumen).
  static const _items = <(String, String Function(String))>[
    ('Beranda', NavSvgIcons.home),
    ('Film', NavSvgIcons.movie),
    ('Playlist', NavSvgIcons.playlist),
    ('Musik', NavSvgIcons.music),
    ('Akun', NavSvgIcons.account),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lebar,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0B0B),
        border: Border(
          left: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo / nama aplikasi ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('I',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 19)),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text('ISAN',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: 1.6)),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),

            // ── Tombol navigasi utama ──
            for (int i = 0; i < _items.length; i++)
              _SideTile(
                label: _items[i].$1,
                ikon: _items[i].$2,
                aktif: currentIndex == i,
                onTap: () => onTap(i),
              ),

            const Spacer(),

            // ── Tombol pendukung ──
            const Divider(color: AppColors.border, height: 1),
            _SideTileAksi(
              label: 'Cari',
              ikon: Icons.search_rounded,
              onTap: onSearchTap,
            ),
            _SideTileAksi(
              label: 'Riwayat Tontonan',
              ikon: Icons.history_rounded,
              onTap: onHistoryTap,
            ),

            // ── Kartu akun di bawah ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              child: InkWell(
                onTap: onAccountTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_rounded,
                          color: AppColors.textMuted, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Profil Saya',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris menu sidebar (dengan penanda aktif).
class _SideTile extends StatelessWidget {
  final String label;
  final String Function(String color) ikon;
  final bool aktif;
  final VoidCallback onTap;

  const _SideTile({
    required this.label,
    required this.ikon,
    required this.aktif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final warna = aktif ? AppColors.red : AppColors.textMuted;
    final svg = ikon('#${warna.value.toRadixString(16).padLeft(8, '0').substring(2)}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: aktif ? AppColors.red.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SvgPicture.string(svg, width: 21, height: 21),
                const SizedBox(width: 13),
                Text(
                  label,
                  style: TextStyle(
                    color: aktif ? Colors.white : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (aktif) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris menu pendukung (pakai ikon Material).
class _SideTileAksi extends StatelessWidget {
  final String label;
  final IconData ikon;
  final VoidCallback onTap;

  const _SideTileAksi({
    required this.label,
    required this.ikon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(ikon, color: AppColors.textMuted, size: 20),
              const SizedBox(width: 13),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
