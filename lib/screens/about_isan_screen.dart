import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/instagram_button.dart';
import '../responsive.dart';

/// Halaman "Tentang ISAN" -- info panjang soal apa itu ISAN, fitur-fitur,
/// aturan pemakaian, privasi, dan disclaimer konten. Dibuka dari menu Akun.
class AboutIsanScreen extends StatelessWidget {
  const AboutIsanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      image: AppBg.account,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Tentang ISAN', style: AppFonts.title(size: 19, color: Colors.white, weight: FontWeight.w400)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          children: [
            Center(
              child: Column(
                children: [
                  Text('ISAN', style: AppFonts.title(size: 44, color: Colors.white, weight: FontWeight.w400, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('Anime · Movie · Series · Musik',
                      style: AppFonts.body(size: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 22),

            _section(context,
              icon: Icons.info_outline,
              title: 'Apa itu ISAN?',
              body:
                  'ISAN adalah platform streaming pribadi yang menghadirkan '
                  'anime, film, series, dan musik dalam satu aplikasi. ISAN '
                  'dibuat dan dikembangkan secara mandiri sebagai proyek '
                  'pribadi, dengan tujuan memudahkan pengguna menonton dan '
                  'mendengarkan konten favorit tanpa harus berpindah-pindah '
                  'aplikasi. Semua konten yang tersedia di ISAN diambil dari '
                  'berbagai sumber pihak ketiga di internet dan ditampilkan '
                  'ulang melalui antarmuka aplikasi ini.',
            ),

            _section(context,
              icon: Icons.star_border_rounded,
              title: 'Fitur Utama',
              children: const [
                _Bullet('Streaming Anime dengan update episode rutin, lengkap dengan filter genre.'),
                _Bullet('Katalog Movie & Series dari berbagai sumber, sub Indonesia.'),
                _Bullet('Pemutar Musik dengan playlist pribadi yang tersimpan di akun kamu.'),
                _Bullet('Riwayat tontonan otomatis, jadi kamu bisa lanjut dari episode terakhir.'),
                _Bullet('Pencarian cepat lintas kategori (anime, movie, series, musik).'),
                _Bullet('Kolom chat global & komentar per-konten untuk berdiskusi dengan pengguna lain.'),
              ],
            ),

            _section(context,
              icon: Icons.gavel_rounded,
              title: 'Aturan Pemakaian',
              children: const [
                _Bullet('Satu akun hanya untuk satu pengguna. Dilarang memperjualbelikan atau membagikan akun ke pihak lain.'),
                _Bullet('Dilarang menggunakan bot, script otomatis, atau cara curang lain untuk mengeksploitasi sistem ISAN (termasuk sistem chat, playlist, dan API).'),
                _Bullet('Jaga sopan santun di kolom chat global dan komentar. Ujaran kebencian, SARA, konten pornografi, spam, dan promosi di luar konteks tidak diperbolehkan.'),
                _Bullet('Dilarang mengunggah ulang, mendistribusikan ulang, atau menjual konten yang diambil dari ISAN untuk kepentingan komersial.'),
                _Bullet('Pelanggaran berulang terhadap aturan di atas dapat berakibat pemblokiran akun secara permanen tanpa pemberitahuan sebelumnya.'),
                _Bullet('Pengguna bertanggung jawab penuh atas keamanan akun masing-masing (email & kata sandi).'),
              ],
            ),

            _section(context,
              icon: Icons.shield_outlined,
              title: 'Privasi & Data Pengguna',
              body:
                  'ISAN menyimpan data akun (username, email, kata sandi '
                  'terenkripsi) dan riwayat aktivitas (tontonan, playlist) '
                  'semata-mata untuk keperluan fungsi aplikasi -- seperti '
                  'menyimpan progres tontonan dan playlist musik kamu. Data '
                  'ini tidak diperjualbelikan ke pihak ketiga. Kamu bisa '
                  'meminta penghapusan akun beserta datanya kapan saja lewat '
                  'menu dukungan/support.',
            ),

            _section(context,
              icon: Icons.warning_amber_rounded,
              title: 'Disclaimer Konten',
              body:
                  'ISAN tidak meng-hosting file video/audio di server sendiri. '
                  'Seluruh konten yang ditampilkan bersumber dari layanan '
                  'pihak ketiga yang tersedia bebas di internet. ISAN hanya '
                  'berperan sebagai antarmuka penonton (media player). '
                  'Jika kamu adalah pemegang hak cipta suatu konten dan '
                  'keberatan konten tersebut ditampilkan di ISAN, silakan '
                  'hubungi tim ISAN melalui kontak di bawah untuk proses '
                  'penghapusan.',
            ),

            _section(context,
              icon: Icons.build_circle_outlined,
              title: 'Pengembangan Aplikasi',
              body:
                  'ISAN dikembangkan dan dikelola oleh Muhammad Ikhsan '
                  'Setiawan sebagai proyek pengembangan aplikasi pribadi, '
                  'terus diperbarui secara berkala -- baik dari sisi fitur, '
                  'tampilan, maupun stabilitas server. Masukan, saran, dan '
                  'laporan bug dari pengguna sangat membantu perkembangan '
                  'ISAN ke depannya.',
            ),

            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text('Hubungi & Ikuti ISAN', style: AppFonts.title(size: 17, color: Colors.white, weight: FontWeight.w400)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const InstagramButton(size: 34),
                      const SizedBox(width: 10),
                      Text('@muhammad_ikhsan_setiawan', style: AppFonts.body(size: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('ISAN © 2026 -- Dibuat oleh Muhammad Ikhsan Setiawan',
                  style: AppFonts.body(size: 10.5, color: AppColors.textFaint)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context,
      {required IconData icon, required String title, String? body, List<Widget>? children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(Layout.desktop(context) ? 28 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.red, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppFonts.title(size: 18, color: Colors.white, weight: FontWeight.w400)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (body != null)
            Text(body, style: AppFonts.body(size: 12.5, color: AppColors.textMuted, weight: FontWeight.w400)),
          if (children != null) ...children,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 8),
            child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
          ),
          Expanded(child: Text(text, style: AppFonts.body(size: 12.5, color: AppColors.textMuted, weight: FontWeight.w400))),
        ],
      ),
    );
  }
}
