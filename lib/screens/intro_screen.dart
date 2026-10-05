import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/instagram_button.dart';
import 'auth_screen.dart';

/// Halaman paling awal aplikasi -- tampil SEBELUM login, gayanya diadaptasi
/// dari referensi (logo besar di tengah atas, keterangan + keunggulan
/// aplikasi, tombol MASUK besar di bawah), tapi tetap tema merah ISAN dan
/// background-nya pakai foto (bukan ilustrasi flat). Login WAJIB dilewati
/// dulu di sini sebelum bisa ke Beranda -- lihat widgets/auth_gate.dart.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      image: AppBg.intro,
      overlayStrength: 0.68,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo ISAN, besar, di tengah atas -- pakai font Griffy.
                _GlowLogo(),
                const SizedBox(height: 10),
                Text(
                  'ISAN · UNTUK KAMU',
                  style: AppFonts.body(
                    size: 12.5,
                    color: AppColors.red,
                    weight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Platform streaming anime, film, series, dan musik\ndalam satu aplikasi -- lengkap dan gratis.',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(size: 13, color: AppColors.textMuted, weight: FontWeight.w400),
                ),
                const Spacer(flex: 2),

                // Kartu keunggulan aplikasi.
                _FeatureGrid(),
                const Spacer(flex: 1),

                // Kenapa pilih ISAN.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Text('KENAPA PILIH ISAN?',
                              style: AppFonts.body(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Update konten rutin, kualitas streaming stabil, dan '
                        'punya fitur playlist musik + riwayat tontonan yang '
                        'tersimpan otomatis di akun kamu. ISAN, dibuat buat '
                        'kamu yang hobi nonton & dengerin musik.',
                        style: AppFonts.body(size: 12, color: AppColors.textMuted, weight: FontWeight.w400),
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip('Anime'),
                          _Chip('Movie'),
                          _Chip('Series'),
                          _Chip('Musik'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol MASUK -> ke layar login/daftar.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 19),
                        const SizedBox(width: 8),
                        Text('MASUK', style: AppFonts.title(size: 16, color: Colors.white, weight: FontWeight.w700, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // IG ISAN -- SVG icon asli, bukan emoji.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ikuti ISAN di ', style: AppFonts.body(size: 11.5, color: AppColors.textFaint)),
                    const InstagramButton(size: 30),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [AppColors.red.withValues(alpha: 0.55), AppColors.red.withValues(alpha: 0.0)],
            ),
          ),
        ),
        Text(
          'ISAN',
          style: AppFonts.title(
            size: 52,
            color: Colors.white,
            weight: FontWeight.w400,
            letterSpacing: 3,
            shadows: [Shadow(color: AppColors.red.withValues(alpha: 0.85), blurRadius: 22)],
          ),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  static const _items = [
    (Icons.live_tv_rounded, 'Anime', 'Update tiap hari'),
    (Icons.movie_rounded, 'Movie', 'Ribuan judul'),
    (Icons.theaters_rounded, 'Series', 'Sub Indo lengkap'),
    (Icons.music_note_rounded, 'Musik', 'Playlist pribadi'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: _items
          .map((it) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(it.$1, color: AppColors.red, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(it.$2, style: AppFonts.body(size: 12.5, color: Colors.white, weight: FontWeight.w700)),
                          Text(it.$3, style: AppFonts.body(size: 10, color: AppColors.textFaint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: AppFonts.body(size: 10.5, color: Colors.white, weight: FontWeight.w600)),
    );
  }
}
