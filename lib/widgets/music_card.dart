import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../theme.dart';
import 'add_to_playlist_sheet.dart';

/// Kartu musik bergaya SongCard.tsx di frontend web. Punya 2 mode layout:
/// - MusicCardLayout.square: artwork persegi (aspect 1:1), buat horizontal
///   scroll row di Beranda / grid kotak.
/// - MusicCardLayout.list: baris panjang (artwork kecil di kiri, judul+
///   artist di tengah, tombol di kanan) -- buat daftar lagu di playlist,
///   hasil pencarian, dan sisa lagu di bawah grid kotak page Musik.
///
/// onTap memutar langsung di tempat (lewat MusicPlayerState) — TIDAK
/// pindah ke halaman lain. Tombol + (kalau onAddToPlaylist null, tombolnya
/// gak ditampilkan) buka AddToPlaylistSheet.
enum MusicCardLayout { square, list }

class MusicCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;
  final double width;
  final MusicCardLayout layout;
  final Song? song; // dibutuhkan kalau mau nampilin tombol tambah-ke-playlist
  final bool showAddButton;
  final VoidCallback? onRemove; // dipakai di playlist detail (hapus dari playlist)

  const MusicCard({
    super.key,
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.onTap,
    this.isActive = false,
    this.isPlaying = false,
    this.width = 140,
    this.layout = MusicCardLayout.square,
    this.song,
    this.showAddButton = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return layout == MusicCardLayout.list ? _buildList(context) : _buildSquare(context);
  }

  Widget _artwork(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceAlt,
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: AppColors.border, size: 22),
                placeholder: (_, __) => const SizedBox.shrink(),
              )
            : const Icon(Icons.music_note, color: AppColors.border, size: 22),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                _artwork(48),
                if (isActive)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.red,
                      size: 22,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (isActive && isPlaying)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: _EqualizerBars(),
              ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.textFaint, size: 20),
                onPressed: onRemove,
              )
            else if (showAddButton && song != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.textFaint, size: 22),
                onPressed: () => AddToPlaylistSheet.show(context, song!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquare(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppColors.surfaceAlt,
                      child: (imageUrl != null && imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.music_note,
                                color: AppColors.border,
                                size: 28,
                              ),
                              placeholder: (_, __) => const SizedBox.shrink(),
                            )
                          : const Icon(Icons.music_note, color: AppColors.border, size: 28),
                    ),
                  ),
                  // Overlay gelap + tombol play/pause merah bulat, persis
                  // seperti hover state di SongCard.tsx (di mobile selalu
                  // tampil kalau aktif, biar jelas ini yang lagi diputar).
                  if (isActive)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: AnimatedOpacity(
                      opacity: isActive ? 1 : 0.92,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          isActive && isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  if (isActive && isPlaying)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const _EqualizerBars(),
                      ),
                    ),
                  // Tombol + tambah-ke-playlist, pojok kiri-bawah, biar gak
                  // numpuk sama tombol play/pause yang di kanan-bawah.
                  if (showAddButton && song != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: GestureDetector(
                        onTap: () => AddToPlaylistSheet.show(context, song!),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.red : Colors.white,
              ),
            ),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiga batang kecil yang "menari" — mirror dari animasi equalizer
/// (bar bouncing) di SongCard.tsx saat isActive && isPlaying.
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500 + i * 150),
      )..repeat(reverse: true);
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (_, __) {
              final heightFactor = 0.35 + _controllers[i].value * 0.65;
              return Container(
                width: 2.5,
                height: 14 * heightFactor,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
