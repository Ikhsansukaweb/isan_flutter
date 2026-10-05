import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme.dart';

/// Daftar pemeran yang bisa DIGESER KE KANAN.
///
/// Digambar sebagai baris mendatar (bukan teks berjajar dipisah koma),
/// berisi foto bulat + nama + peran tiap pemeran.
///
/// Foto diambil dari TMDB (profile_path). Sekitar 1 dari 5 pemeran tidak
/// punya foto di TMDB — untuk yang begitu ditampilkan huruf awal namanya
/// di dalam bulatan, supaya tinggi barisnya tetap sama dan tidak ada
/// lubang menganga di tengah daftar.
class PemeranGeser extends StatelessWidget {
  final List<PemeranItem> pemeran;
  final String judul;

  const PemeranGeser({
    super.key,
    required this.pemeran,
    this.judul = 'Pemeran',
  });

  @override
  Widget build(BuildContext context) {
    if (pemeran.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(judul,
            style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                letterSpacing: 0.6)),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: pemeran.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _KartuPemeran(p: pemeran[i]),
          ),
        ),
      ],
    );
  }
}

class _KartuPemeran extends StatelessWidget {
  final PemeranItem p;
  const _KartuPemeran({required this.p});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 68,
              height: 68,
              child: p.adaFoto
                  ? Image.network(
                      p.foto,
                      fit: BoxFit.cover,
                      // Kalau gambarnya gagal dimuat (putus jaringan /
                      // file di TMDB sudah dihapus), tampilkan huruf awal
                      // nama, bukan kotak rusak.
                      errorBuilder: (_, __, ___) => _hurufAwal(),
                      loadingBuilder: (_, anak, kemajuan) {
                        if (kemajuan == null) return anak;
                        return Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.6),
                            ),
                          ),
                        );
                      },
                    )
                  : _hurufAwal(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.nama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFE8E8E8),
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600),
          ),
          if (p.peran.isNotEmpty)
            Text(
              p.peran,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 9.5, height: 1.2),
            ),
        ],
      ),
    );
  }

  /// Bulatan berisi huruf awal nama — pengganti saat foto tidak ada.
  Widget _hurufAwal() {
    final awal = p.nama.trim().isEmpty ? '?' : p.nama.trim()[0].toUpperCase();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          awal,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 24,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
