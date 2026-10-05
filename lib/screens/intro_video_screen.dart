import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';

/// ════════════════════════════════════════════════════════════════════
///  LAYAR INTRO VIDEO (ISAN)
/// ════════════════════════════════════════════════════════════════════
///
///  Memutar animasi logo ISAN (berkas `isan_intro.mp4`, 1080x1920,
///  60 fps, 15 detik) lalu memanggil [setelahSelesai] untuk lanjut
///  ke halaman berikutnya.
///
///  BERSIFAT OPSIONAL & AMAN:
///    • Kalau berkas video tidak ada / gagal diputar → langsung
///      memanggil [setelahSelesai]. Intro TIDAK PERNAH memblokir
///      pengguna masuk ke aplikasi.
///    • Menghormati setelan "kurangi gerak" (reduce motion) milik
///      sistem: kalau aktif, intro dilewati.
///    • Bisa diketuk untuk melewati (skip).
///
///  Catatan: `video_player` sengaja dipakai karena sudah terpasang
///  di proyek ini (lihat pubspec.yaml) — tidak menambah paket baru.
class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({
    super.key,
    this.setelahSelesai,
    this.berkasAset = 'assets/video/isan_intro.mp4',
    this.lewatiBilaGagal = true,
  });

  /// Dipanggil setelah video selesai (atau dilewati / gagal).
  final VoidCallback? setelahSelesai;

  /// Jalur berkas video di dalam daftar aset.
  final String berkasAset;

  /// Kalau true, kegagalan memutar video TIDAK menahan pengguna.
  final bool lewatiBilaGagal;

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  VideoPlayerController? _pengendali;
  bool _siap = false;
  bool _sudahPindah = false;
  bool _gagal = false;

  /// Pengaman: kalau karena alasan apa pun video tidak pernah
  /// melaporkan selesai, pindah paksa setelah durasi + 2 detik.
  Timer? _pengamanWaktu;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    // Lewati intro kalau pengguna meminta "kurangi gerak".
    if (_kurangiGerak()) {
      debugPrint('[INTRO VIDEO] dilewati: pengguna memakai "kurangi gerak"');
      _pindah();
      return;
    }

    debugPrint('[INTRO VIDEO] mulai memuat aset: ${widget.berkasAset}');

    try {
      final pengendali = VideoPlayerController.asset(widget.berkasAset);

      // Batas waktu 6 detik untuk memuat video. Kalau lewat, anggap
      // gagal dan lanjut — jangan biarkan pengguna menunggu.
      await pengendali.initialize().timeout(const Duration(seconds: 6));
      debugPrint(
        '[INTRO VIDEO] BERHASIL dimuat — durasi=${pengendali.value.duration} '
        'ukuran=${pengendali.value.size}',
      );

      if (!mounted) {
        pengendali.dispose();
        return;
      }

      await pengendali.setLooping(false);
      await pengendali.setVolume(0); // intro tanpa suara
      await pengendali.play();
      debugPrint('[INTRO VIDEO] play() dipanggil — video mulai berjalan');

      // Pengaman berdasarkan durasi video.
      final durasi = pengendali.value.duration;
      _pengamanWaktu = Timer(
        durasi + const Duration(seconds: 2),
        () => _pindah(),
      );

      pengendali.addListener(_pantau);

      setState(() {
        _pengendali = pengendali;
        _siap = true;
      });
    } catch (e, jejak) {
      // Jangan sampai intro merusak pengalaman masuk aplikasi.
      debugPrint('[INTRO VIDEO] gagal menyiapkan: $e');
      debugPrintStack(stackTrace: jejak);
      if (!mounted) return;
      setState(() {
        _gagal = true;
      });
      if (widget.lewatiBilaGagal) {
        _pindah();
      }
    }
  }

  void _pantau() {
    final pengendali = _pengendali;
    if (pengendali == null || _sudahPindah) return;

    final nilai = pengendali.value;

    // Video selesai.
    if (nilai.position >= nilai.duration && nilai.duration > Duration.zero) {
      _pindah();
      return;
    }

    // Video berhenti karena galat.
    if (nilai.hasError) {
      debugPrint('[INTRO VIDEO] galat pemutaran: ${nilai.errorDescription}');
      _pindah();
    }
  }

  void _pindah() {
    if (_sudahPindah || !mounted) return;
    _sudahPindah = true;
    _pengamanWaktu?.cancel();
    widget.setelahSelesai?.call();
    if (mounted) setState(() {});
  }

  bool _kurangiGerak() {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isLinux) {
      return false;
    }
    final jendela = WidgetsBinding.instance.platformDispatcher;
    return jendela.accessibilityFeatures.reduceMotion;
  }

  @override
  void dispose() {
    _pengamanWaktu?.cancel();
    _pengendali?.removeListener(_pantau);
    _pengendali?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Ketuk di mana saja = lewati intro.
        onTap: _pindah,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Isi utama ──
            if (_siap && _pengendali != null)
              Center(
                child: AspectRatio(
                  // Kanvas 9:16 tegak — penuhi layar HP.
                  aspectRatio: _pengendali!.value.aspectRatio == 0
                      ? 9 / 16
                      : _pengendali!.value.aspectRatio,
                  child: VideoPlayer(_pengendali!),
                ),
              )
            else if (_gagal)
              const _TampilanCadangan()
            else
              const _TampilanMemuat(),

            // ── Tombol lewati (pojok kanan bawah) ──
            Positioned(
              right: 18,
              bottom: 26,
              child: SafeArea(
                child: Opacity(
                  opacity: 0.85,
                  child: TextButton(
                    onPressed: _pindah,
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: AppColors.red.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    child: Text(
                      'LEWATI',
                      style: AppFonts.body(
                        size: 11.5,
                        color: AppColors.red,
                        weight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
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

/// Tampilan sementara selagi video dimuat.
class _TampilanMemuat extends StatelessWidget {
  const _TampilanMemuat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 128,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 22),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan kalau video gagal diputar — tetap enak dilihat,
/// tidak menampilkan galat mentah ke pengguna.
class _TampilanCadangan extends StatelessWidget {
  const _TampilanCadangan();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 150,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Text(
            'ISAN',
            style: AppFonts.body(
              size: 30,
              color: AppColors.red,
              weight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}
