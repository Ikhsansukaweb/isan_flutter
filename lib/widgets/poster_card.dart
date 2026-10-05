import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';

/// Kartu poster generik (dipakai untuk anime, movie, series) — aspect 2:3
/// dengan badge opsional di kiri-atas dan rating di kanan-atas, mirror dari
/// AnimeCard.tsx / SeriesCard.tsx pada frontend.
class PosterCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? badge;
  final String? ratingText;
  final IconData placeholderIcon;
  final VoidCallback onTap;
  final double width;

  const PosterCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.badge,
    this.ratingText,
    this.placeholderIcon = Icons.live_tv_outlined,
    this.width = 130,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.width >= 900 ? 13 : 10),
                    child: Container(
                      color: AppColors.surfaceAlt,
                      child: (imageUrl != null && imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                placeholderIcon,
                                color: AppColors.border,
                                size: 28,
                              ),
                              placeholder: (_, __) => const SizedBox.shrink(),
                            )
                          : Icon(placeholderIcon, color: AppColors.border, size: 28),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Tag(text: badge!, bg: AppColors.red),
                    ),
                  if (ratingText != null && ratingText!.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Tag(
                        text: '★ $ratingText',
                        bg: Colors.black.withValues(alpha: 0.8),
                        color: AppColors.gold,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // Desktop: kartu jauh lebih besar (kolom grid lebih
                // sedikit per baris tapi layar 1280), jadi judulnya
                // dinaikkan agar seimbang. Di HP (lebar < 900) nilainya
                // tetap 12.5 — persis seperti sebelumnya.
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width >= 900
                      ? 14.5
                      : 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color color;
  const _Tag({required this.text, required this.bg, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
