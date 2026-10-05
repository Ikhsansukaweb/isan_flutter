import 'package:flutter/material.dart';
import '../theme.dart';

/// ══════════════════════════════════════════════════════════════════
///  KUNCI: ambang desktop = 900
/// ══════════════════════════════════════════════════════════════════
///  Di HP lebar layar selalu < 900 → `_desktop(context)` SELALU false →
///  seluruh angka HP di bawah dipakai PERSIS seperti sebelumnya.
///  Android tidak berubah.
bool _desktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 900;

class SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, required this.color, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    // Di desktop tepi halaman lebih lebar (16 → 28) supaya tidak mepet,
    // dan judul section diperbesar sedikit.
    final d = _desktop(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(d ? 28 : 16, 0, d ? 28 : 16, d ? 14 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: d ? 19 : 16,
                color: color,
                margin: const EdgeInsets.only(right: 8),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: d ? 16.5 : 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text('Lihat semua',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: d ? 13.5 : 12)),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HScrollSection extends StatelessWidget {
  final bool loading;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double height;

  const HScrollSection({
    super.key,
    required this.loading,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 230,
  });

  @override
  Widget build(BuildContext context) {
    final count = loading ? 8 : itemCount;
    final d = _desktop(context);

    // Di desktop: baris kartu diperbesar ±30% dan tepinya 28 px supaya
    // seimbang dengan header section. Di HP cabang ini dilewati, jadi
    // `height` tetap angka yang dikirim pemanggil (230, dst) — sama.
    final tinggi = d ? (height * 1.3).clamp(height, 420.0) : height;
    final tepi = d ? 28.0 : 16.0;

    return SizedBox(
      height: tinggi,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tepi),
        itemCount: count,
        separatorBuilder: (_, __) => SizedBox(width: d ? 14 : 10),
        itemBuilder: (ctx, i) {
          if (loading) {
            return Container(
              width: d ? 170 : 130,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }
          return itemBuilder(ctx, i);
        },
      ),
    );
  }
}
