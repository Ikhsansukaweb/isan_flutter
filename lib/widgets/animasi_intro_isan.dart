import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ════════════════════════════════════════════════════════════════════
///  ANIMASI INTRO LOGO ISAN — VERSI FLUTTER
/// ════════════════════════════════════════════════════════════════════
///
///  Ini PEMINDAHAN PERSIS dari animasi Remotion (isan-remotion) ke Dart.
///  Semua angka diambil apa adanya dari berkas asli:
///
///     animations.ts   → Warna, Waktu, PEGAS_*, GAYA_HURUF,
///                       POSISI_HURUF, pendarHuruf, derau3, acakStabil
///     index.tsx       → komposisi utama, napas, getar, tagline, pudar
///     LetterI/S/A/N   → animasi tiap huruf
///     BackgroundGrid  → kisi, pendar ambien, vignette
///     GlowParticles   → orb, percikan, debu
///     LightSweep      → sapuan lensa
///
///  KENAPA DI-REMAKE (bukan pakai berkas .mp4)?
///  HP Infinix X655C (MediaTek MT6765, Android 10) punya decoder video
///  perangkat keras yang RUSAK: SEMUA berkas H.264 gagal di-decode
///  ("Decoder init failed: OMX.MTK.VIDEO.DECODER.AVC").
///  Sudah diuji 1080x1920@60, 854x480@30, 576x1024@30, 320x240@24 —
///  semuanya gagal. Decoder perangkat lunak pun tidak tersedia di HP
///  itu. Animasi Flutter tidak memakai decoder sama sekali: digambar
///  langsung oleh mesin render Flutter, jadi PASTI tampil.
///
///  Durasi 15 detik, 6 fase — sama seperti video aslinya.
class AnimasiIntroIsan extends StatefulWidget {
  const AnimasiIntroIsan({super.key, required this.setelahSelesai});

  /// Dipanggil saat animasi selesai.
  final VoidCallback setelahSelesai;

  @override
  State<AnimasiIntroIsan> createState() => _AnimasiIntroIsanState();
}

class _AnimasiIntroIsanState extends State<AnimasiIntroIsan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali;
  late final Ticker _ticker;
  DateTime? _mulai;

  @override
  void initState() {
    super.initState();

    // ── PACU KE 60 FPS ──────────────────────────────────────────
    // AnimationController bawaan Flutter TIDAK menjamin 60 fps:
    // detaknya mengikuti jadwal animasi, dan kalau ada frame yang
    // berat, ia melompat beberapa detak sekaligus (terasa tersendat).
    //
    // Di sini dipakai Ticker mentah: satu detak = satu frame layar
    // (vsync). Kemajuan dihitung dari WAKTU NYATA, bukan dari
    // jumlah detak — jadi walau sempat melompat, animasinya tetap
    // selesai tepat 15 detik dan geraknya tetap mulus.
    _mulai = DateTime.now();
    _kendali = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    );
    _ticker = createTicker((_) {
      if (!mounted) return;
      final lewat = DateTime.now().difference(_mulai!).inMicroseconds;
      final nilai = (lewat / 15000000).clamp(0.0, 1.0);
      _kendali.value = nilai;
      if (nilai >= 1.0) {
        _ticker.stop();
        widget.setelahSelesai();
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kendali,
      builder: (context, _) {
        // Frame global 0..900 — sama seperti useCurrentFrame() Remotion.
        final frame = _kendali.value * _IsanAnim.totalFrame;
        return Stack(
          children: [
            _KanvasIntro(frame: frame),

            // ══ TOMBOL LEWATI ══════════════════════════════════════
            // Tombol ini DI LUAR kanvas animasi, jadi tidak ikut
            // bergoyang/bergetar saat layar bergetar (fase S), dan
            // tidak ikut pudar di akhir animasi.
            Positioned(
              right: 20,
              bottom: 40,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: _lewati,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0x33FFFFFF),
                    foregroundColor: Color(0xFFFF0019),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(
                        color: Color(0x66FF2A3B),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: const Text(
                    'LEWATI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Lewati animasi: hentikan ticker, langsung panggil [setelahSelesai].
  void _lewati() {
    debugPrint('[INTRO] tombol LEWATI ditekan');
    _ticker.stop();
    widget.setelahSelesai();
  }
}

// ══════════════════════════════════════════════════════════════════════
//  NILAI-NILAI ASLI — dipindah apa adanya dari animations.ts
// ══════════════════════════════════════════════════════════════════════
/// Saklar diagnosa: kalau true, lapisan sapuan lensa DIMATIKAN.
/// Dipakai untuk membuktikan apakah sapuan itu sumber warna kuning.
const bool matikanSapuanUntukDiagnosa = bool.fromEnvironment('MATIKAN_SAPUAN');

/// Saklar diagnosa: kalau true, SEMUA bayangan huruf dimatikan.
/// Untuk membuktikan apakah kuning berasal dari Shadow atau dari huruf.
const bool matikanBayanganUntukDiagnosa =
    bool.fromEnvironment('MATIKAN_BAYANGAN');

class _IsanAnim {
  // ── Palet warna (Warna) ──
  static const merahUtama = Color(0xFFE50914);
  static const merahNyala = Color(0xFFFF2A3B);
  static const neonScarlet = Color(0xFFFF0033);
  static const obsidianTerang = Color(0xFF0D0D0E);
  static const obsidianGelap = Color(0xFF000000);
  static const kilauPutih = Color(0xFFFF0019); // dulu putih; putih+merah tampak kuning di HP

  static const totalFrame = 900.0;

  // ── Peta waktu (Waktu) — dalam frame @60fps ──
  static const percikanMunculMulai = 30.0;
  static const percikanMunculSelesai = 90.0;
  static const percikanMeledakMulai = 90.0;
  static const percikanMeledakSelesai = 150.0;

  static const iJatuhMulai = 150.0;
  static const iJatuhSelesai = 210.0;
  static const iSinarMulai = 210.0;
  static const iSinarSelesai = 270.0;
  static const iRiakMulai = 270.0;
  static const iRiakSelesai = 300.0;

  static const sGoresMulai = 300.0;
  static const sGoresSelesai = 360.0;
  static const sIsiMulai = 360.0;
  static const sIsiSelesai = 410.0;
  static const sGetarMulai = 410.0;
  static const sGetarSelesai = 450.0;

  static const aKakiMulai = 450.0;
  static const aKakiSelesai = 510.0;
  static const aSkalaMulai = 510.0;
  static const aSkalaSelesai = 570.0;
  static const aBintangMulai = 570.0;
  static const aBintangSelesai = 600.0;

  static const nGeserMulai = 600.0;
  static const nGeserSelesai = 660.0;
  static const napasMulai = 660.0;
  static const napasSelesai = 720.0;

  static const sapuanMulai = 720.0;
  static const sapuanSelesai = 800.0;
  static const taglineMulai = 800.0;
  static const taglineSelesai = 850.0;
  static const pudarMulai = 850.0;
  static const pudarSelesai = 900.0;

  // ── Posisi mendatar huruf (POSISI_HURUF) ──
  static const posisiI = -264.0;
  static const posisiS = -88.0;
  static const posisiA = 88.0;
  static const posisiN = 264.0;
  static const titikAncang = <double>[-264, -88, 88, 264];

  /// Gaya huruf (GAYA_HURUF): tebal 900, warna merahNyala, garis tepi.
  static const ukuranHuruf = 232.0; // fontSize, dalam px kanvas 1080
  // Font dibundel sendiri di pubspec.yaml (assets/fonts/).
  static const fontHuruf = 'DejaVu Sans';

  // ══════════════════════════════════════════════════════════════════
  //  Fungsi bantu — memindahkan petakan() / pegas() / derau() / acakStabil()
  // ══════════════════════════════════════════════════════════════════

  /// Padanan interpolate(): memetakan frame dari satu rentang ke rentang
  /// lain, dijepit di kedua ujung.
  static double petakan(
    double frame,
    double f0,
    double f1,
    double v0,
    double v1, {
    double Function(double)? easing,
  }) {
    if (f1 == f0) return v1;
    double t = (frame - f0) / (f1 - f0);
    t = t.clamp(0.0, 1.0);
    if (easing != null) t = easing(t);
    return v0 + (v1 - v0) * t;
  }

  // ── Kurva easing (dari animations.ts) ──
  /// easingSinematik: bezier(0.16, 1, 0.3, 1)
  static double sinematik(double t) => _bezier(t, 0.16, 1.0, 0.3, 1.0);
  /// easingKeluar: bezier(0.55, 0, 1, 0.45)
  static double keluar(double t) => _bezier(t, 0.55, 0.0, 1.0, 0.45);
  /// easingKaret: bezier(0.34, 1.56, 0.64, 1)
  static double karet(double t) => _bezier(t, 0.34, 1.56, 0.64, 1.0);
  /// easingLinear
  static double linear(double t) => t;
  /// Easing.out(Easing.cubic)
  static double keluarKubik(double t) => 1 - math.pow(1 - t, 3).toDouble();

  /// Bezier kubik sederhana (cukup akurat untuk animasi visual).
  static double _bezier(double t, double x1, double y1, double x2, double y2) {
    // Pecahkan X(t) = target memakai bagi-dua, lalu ambil Y(t).
    double lo = 0.0, hi = 1.0, u = t;
    for (int i = 0; i < 28; i++) {
      u = (lo + hi) / 2;
      final x = _bez1(u, x1, x2);
      if (x < t) {
        lo = u;
      } else {
        hi = u;
      }
    }
    return _bez1(u, y1, y2);
  }

  static double _bez1(double u, double p1, double p2) {
    final v = 1 - u;
    return 3 * v * v * u * p1 + 3 * v * u * u * p2 + u * u * u;
  }

  /// Padanan spring() Remotion: pegas teredam dari 0 → 1.
  ///
  /// Remotion memakai rumus fisika pegas; di sini dipakai bentuk analitik
  /// pegas teredam yang menghasilkan gerak serupa (termasuk kelebihan
  /// gerak/overshoot), memakai parameter damping & stiffness yang sama.
  static double pegas(
    double frame,
    double mulai,
    double damping,
    double mass,
    double stiffness, {
    double durasi = 60,
  }) {
    final t = frame - mulai;
    if (t <= 0) return 0.0;
    // Waktu dinormalkan supaya `durasi` frame ≈ pegas selesai.
    final tn = t / durasi;
    // Frekuensi sudut dari stiffness/mass, disetel agar cocok dgn Remotion.
    final omega = math.sqrt(stiffness / mass) / 10.0;
    final zeta = damping / (2 * math.sqrt(stiffness * mass));
    double nilai;
    if (zeta < 1) {
      // Kurang teredam: ada osilasi & overshoot.
      final omegaD = omega * math.sqrt(1 - zeta * zeta);
      nilai = 1 -
          math.exp(-zeta * omega * tn) *
              (math.cos(omegaD * tn) +
                  (zeta * omega / omegaD) * math.sin(omegaD * tn));
    } else {
      // Terdampak kritis/lebih: mendekati 1 tanpa osilasi.
      nilai = 1 - math.exp(-omega * tn) * (1 + omega * tn);
    }
    // Jaring pengaman: jangan sampai lewat jauh.
    return nilai.clamp(-0.6, 1.9);
  }

  /// Derau halus (derau) — dipakai getaran layar & goyangan.
  static double derau(double t, [double benih = 0]) {
    return math.sin(t * 1.7 + benih) * 0.5 +
        math.sin(t * 3.9 + benih * 2.3) * 0.3 +
        math.sin(t * 8.1 + benih * 5.7) * 0.2;
  }

  /// Derau 3 kanal (derau3).
  static _Derau3 derau3(double t, [double benih = 0]) {
    return _Derau3(
      derau(t, benih),
      derau(t, benih + 11.3),
      derau(t, benih + 27.9),
    );
  }

  /// Angka acak stabil/deterministik (acakStabil).
  static double acakStabil(double indeks, [double benih = 0]) {
    final x = math.sin(indeks * 127.1 + benih * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }
}

class _Derau3 {
  const _Derau3(this.x, this.y, this.r);
  final double x;
  final double y;
  final double r;
}

// ══════════════════════════════════════════════════════════════════════
//  KANVAS — digambar pada ukuran dasar 1080x1920, lalu diskalakan
// ══════════════════════════════════════════════════════════════════════
class _KanvasIntro extends StatelessWidget {
  const _KanvasIntro({required this.frame});
  final double frame;

  // Ukuran dasar kanvas (LEBAR/TINGGI dari animations.ts).
  static const _lebarDasar = 1080.0;
  static const _tinggiDasar = 1920.0;

  @override
  Widget build(BuildContext context) {
    final ukuran = MediaQuery.sizeOf(context);
    // Skala supaya kanvas 1080x1920 mengisi layar (menjaga proporsi).
    final skala = math.min(ukuran.width / _lebarDasar, ukuran.height / _tinggiDasar);

    // ⚠️ PENTING — DI SINILAH KUNING HILANG.
    //
    // Sebelumnya kanvas dibungkus:
    //     ClipRect > SizedBox > FittedBox(fit: contain) > SizedBox
    //
    // FittedBox di HP ini (MediaTek MT6765, Android 10) menghasilkan
    // ARTEFAK KUNING murni RGB(255,255,0) di tepi bawah huruf. Warna
    // itu TIDAK ADA di kode animasi (semua warna di sini kanal
    // hijau-nya <= 64, mustahil jadi kuning). Artefak ini muncul saat
    // Flutter menskalakan ulang lapisan teks berat (banyak Shadow)
    // lewat raster cache.
    //
    // Perbaikan: JANGAN pakai FittedBox. Kanvas digambar pada ukuran
    // aslinya (1080x1920) lalu diskalakan dengan Transform.scale, yang
    // hanya mengubah matriks gambar tanpa penskalaan ulang lapisan.
    return ColoredBox(
      color: _IsanAnim.obsidianGelap,
      child: Center(
        child: Transform.scale(
          scale: skala,
          child: SizedBox(
            width: _lebarDasar,
            height: _tinggiDasar,
            child: _IsiKanvas(frame: frame),
          ),
        ),
      ),
    );
  }
}

/// Isi kanvas pada ukuran asli 1080x1920.
class _IsiKanvas extends StatelessWidget {
  const _IsiKanvas({required this.frame});
  final double frame;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    // ── GETARAN LAYAR saat 'S' mengunci (index.tsx) ──
    final kemajuanGetar = _IsanAnim.petakan(
      f, _IsanAnim.sGetarMulai, _IsanAnim.sGetarSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final kekuatanGetar = kemajuanGetar > 0
        ? (1 - kemajuanGetar) * math.sin(kemajuanGetar * math.pi * 2)
        : 0.0;
    final getaran = _IsanAnim.derau3(f * 1.4, 7.7);
    final getarX = getaran.x * kekuatanGetar * 9;
    final getarY = getaran.y * kekuatanGetar * 9;
    final getarRotasi = getaran.r * kekuatanGetar * 0.7;

    // ── DENYUT NAPAS BERSAMA (frame 660–720) ──
    final gerakNapas = _IsanAnim.petakan(
      f, _IsanAnim.napasMulai, _IsanAnim.napasMulai + 30, 1, 1.05,
      easing: _IsanAnim.karet,
    );
    final gerakNapas2 = _IsanAnim.petakan(
      f, _IsanAnim.napasMulai + 30, _IsanAnim.napasSelesai, 1.05, 1,
      easing: _IsanAnim.karet,
    );
    final napasNilai = f < _IsanAnim.napasMulai + 30 ? gerakNapas : gerakNapas2;
    final napasLanjutan =
        1 + 0.006 * math.sin((f / 60) * math.pi * 2 * 0.5);
    final skalaLogo = f >= _IsanAnim.napasMulai ? napasNilai * napasLanjutan : 1.0;

    // ── PENDAR KESELURUHAN ──
    final pendar1 = _IsanAnim.petakan(
      f, _IsanAnim.napasMulai, _IsanAnim.sapuanMulai, 0, 0.5,
      easing: _IsanAnim.sinematik,
    );
    final pendar2 = _IsanAnim.petakan(
      f, _IsanAnim.sapuanMulai, _IsanAnim.sapuanSelesai, 0.5, 1,
      easing: _IsanAnim.sinematik,
    );
    final pendarKeseluruhan = f < _IsanAnim.sapuanMulai ? pendar1 : pendar2;

    // ── TAGLINE ──
    final opacityTagline = _IsanAnim.petakan(
      f, _IsanAnim.taglineMulai, _IsanAnim.taglineSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final jarakHurufTagline = _IsanAnim.petakan(
      f, _IsanAnim.taglineMulai, _IsanAnim.taglineSelesai, 0, 16,
      easing: _IsanAnim.sinematik,
    );
    final yTagline = _IsanAnim.petakan(
      f, _IsanAnim.taglineMulai, _IsanAnim.taglineSelesai, 18, 0,
      easing: _IsanAnim.sinematik,
    );
    final lebarGarisTagline = _IsanAnim.petakan(
      f, _IsanAnim.taglineMulai + 20, _IsanAnim.taglineSelesai + 20, 0, 420,
      easing: _IsanAnim.sinematik,
    );

    // ── PUDAR PENUTUP ──
    final opacityPenutup = _IsanAnim.petakan(
      f, _IsanAnim.pudarMulai, _IsanAnim.pudarSelesai, 1, 0,
      easing: _IsanAnim.keluar,
    );

    // ── KILATAN BLOOM ──
    final kilatanBloom = _IsanAnim.petakan(
      f, _IsanAnim.sapuanMulai + 24, _IsanAnim.sapuanMulai + 40, 0, 0.42,
      easing: _IsanAnim.sinematik,
    );
    final kilatanBloom2 = _IsanAnim.petakan(
      f, _IsanAnim.sapuanMulai + 40, _IsanAnim.sapuanMulai + 62, 0.42, 0,
      easing: _IsanAnim.sinematik,
    );
    final bloom = f < _IsanAnim.sapuanMulai + 40 ? kilatanBloom : kilatanBloom2;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(getarX, getarY)
        ..rotateZ(getarRotasi * math.pi / 180)
        ..scale(1 + kekuatanGetar.abs() * 0.006),
      child: Opacity(
        opacity: opacityPenutup.clamp(0.0, 1.0),
        child: Stack(
          children: [
            // ══ 1. LATAR GELAP OBSIDIAN ══
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.04),
                  radius: 0.78,
                  colors: [
                    _IsanAnim.obsidianTerang,
                    _IsanAnim.obsidianGelap,
                    _IsanAnim.obsidianGelap,
                  ],
                  stops: [0.0, 0.62, 1.0],
                ),
              ),
            ),

            // ══ 2. KISI & PENDAR AMBIEN ══
            _LatarKisi(frame: f),

            // ══ 3. PARTIKEL & PERCIKAN ══
            _PartikelPendar(frame: f),

            // ══ 4. KEEMPAT HURUF ══
            Center(
              child: Transform.scale(
                scale: skalaLogo,
                child: SizedBox(
                  width: 1080,
                  height: 1920,
                  child: Stack(
                    children: [
                      _HurufI(frame: f),
                      _HurufS(frame: f),
                      _HurufA(frame: f),
                      _HurufN(frame: f),
                    ],
                  ),
                ),
              ),
            ),

            // ══ 5. PENDAR MENYELURUH LOGO ══
            Center(
              child: Opacity(
                opacity: (pendarKeseluruhan * 0.85).clamp(0.0, 1.0),
                child: Container(
                  width: 1100,
                  height: 420,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0x6BE50914), // rgba(229,9,20,0.42)
                        Color(0x2EFF0033), // rgba(255,0,51,0.18)
                        Color(0x00000000),
                      ],
                      stops: [0.0, 0.42, 0.76],
                    ),
                  ),
                ),
              ),
            ),

            // ══ 6. KILATAN BLOOM ══
            if (bloom > 0.001)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color.fromRGBO(255, 70, 70, (bloom * 0.45).clamp(0.0, 1.0)),
                  ),
                ),
              ),

            // ══ 7. SAPUAN LENSA ══
            _SapuanLensa(frame: f),

            // ══ 8. TAGLINE "STREAMING APPS" ══
            //
            // ⚠️ PERBAIKAN JARAK: dulu `bottom: 420`. Huruf ISAN
            // dasarnya ada di sekitar y=1075 (kanvas 1920), sedangkan
            // tagline dengan yTagline yang bergerak naik bisa sampai
            // y≈1100 — hanya berselisih ~48px di layar (3% tinggi
            // layar), sehingga terlihat MENYATU dengan huruf ISAN.
            //
            // Sekarang: bottom diturunkan ke 330, jadi tagline duduk
            // di y≈1250-an. Jaraknya ke dasar huruf ISAN menjadi
            // ~175px (≈11% tinggi layar) — jelas terpisah, tapi masih
            // menyatu secara komposisi.
            Positioned(
              left: 0,
              right: 0,
              bottom: 330,
              child: Opacity(
                opacity: opacityTagline.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, yTagline),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'STREAMING APPS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _IsanAnim.fontHuruf,
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                          letterSpacing: jarakHurufTagline,
                          color: _IsanAnim.merahNyala,
                          shadows: [
                            const Shadow(color: Color(0xE6E50914), blurRadius: 18),
                            const Shadow(color: Color(0x99FF0033), blurRadius: 42),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Garis aksen di bawah tagline.
                      //
                      // ⚠️ CATATAN PERBAIKAN: sebelumnya di sini ada
                      // `foregroundDecoration` dengan warna merah pekat.
                      // Itu lapisan warna DI ATAS gradien, sehingga
                      // gradiennya tertutup dan warnanya jadi keruh
                      // (tampak kekuningan di layar HP).
                      //
                      // Sekarang memakai Opacity() — sama persis dengan
                      // Remotion yang hanya memakai gradient + boxShadow.
                      Opacity(
                        opacity: (opacityTagline * 0.85).clamp(0.0, 1.0),
                        child: Container(
                          width: lebarGarisTagline,
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0x00FF2A3B),
                                _IsanAnim.merahNyala,
                                Color(0x00FF2A3B),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _IsanAnim.neonScarlet,
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
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

// ══════════════════════════════════════════════════════════════════════
//  LATAR: KISI, PENDAR AMBIEN, VIGNETTE  (BackgroundGrid.tsx)
// ══════════════════════════════════════════════════════════════════════
class _LatarKisi extends StatelessWidget {
  const _LatarKisi({required this.frame});
  final double frame;

  static const _jarakKisi = 90.0;

  @override
  Widget build(BuildContext context) {

    // Putaran kisi sangat lambat (satu putaran ~90 detik).
    final putaranKisi = _IsanAnim.petakan(frame, 0, 5400, 0, 360, easing: _IsanAnim.linear);

    // Pendar ambien: denyut lembut sepanjang video.
    final denyutAmbien =
        0.5 + 0.5 * math.sin((frame / 60) * math.pi * 2 * 0.35);
    final skalaAmbien = 1 + denyutAmbien * 0.12;

    // Menguat menjelang pudar.
    final kekuatanAkhir = _IsanAnim.petakan(frame, 700, 820, 1, 1.35);

    final opacityKisi = _IsanAnim.petakan(frame, 0, 180, 0, 0.085,
        easing: _IsanAnim.sinematik);

    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          children: [
            // ══ 1. PENDAR AMBIEN DI TENGAH ══
            Center(
              child: Transform.scale(
                scale: skalaAmbien,
                child: Container(
                  width: 1700,
                  height: 1900,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(950),
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(229, 9, 20, 0.16 * kekuatanAkhir),
                        Color.fromRGBO(229, 9, 20, 0.06 * kekuatanAkhir),
                        const Color(0x00000000),
                      ],
                      stops: const [0.0, 0.34, 0.68],
                    ),
                  ),
                ),
              ),
            ),

            // ══ 2. KISI PERSPEKTIF ══
            Center(
              child: Transform.rotate(
                angle: putaranKisi * math.pi / 180,
                child: Opacity(
                  opacity: opacityKisi,
                  child: CustomPaint(
                    size: const Size(2800, 2800),
                    painter: _PelukisKisi(
                      jarak: _jarakKisi,
                      warna: _IsanAnim.merahNyala,
                    ),
                  ),
                ),
              ),
            ),

            // ══ 3. GARIS CAKRAWALA HALUS ══
            Center(
              child: Opacity(
                opacity: _IsanAnim.petakan(frame, 60, 220, 0, 0.55,
                    easing: _IsanAnim.sinematik),
                child: Container(
                  width: 1900,
                  height: 1.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00E50914),
                        Color(0x59E50914),
                        Color(0x99FF2A3B),
                        Color(0x59E50914),
                        Color(0x00E50914),
                      ],
                      stops: [0.0, 0.3, 0.5, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ══ 4. VIGNETTE ══
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.04),
                      radius: 0.72,
                      colors: [
                        Color(0x00000000),
                        Color(0x8C000000), // 0.55
                        Color(0xEB000000), // 0.92
                      ],
                      stops: [0.34, 0.72, 1.0],
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

/// Pelukis kisi garis tipis (pengganti backgroundImage berulang).
class _PelukisKisi extends CustomPainter {
  _PelukisKisi({required this.jarak, required this.warna});
  final double jarak;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = warna
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += jarak) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += jarak) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisKisi old) => false;
}

// ══════════════════════════════════════════════════════════════════════
//  PENDAR & PARTIKEL  (GlowParticles.tsx)
// ══════════════════════════════════════════════════════════════════════
class _PartikelPendar extends StatelessWidget {
  const _PartikelPendar({required this.frame});
  final double frame;

  static const _jumlahDebu = 34; // dikurangi dari 70: hemat untuk HP

  @override
  Widget build(BuildContext context) {
    final f = frame;

    // ── ORB PUSAT (frame 30–150) ──
    final orbMuncul = _IsanAnim.petakan(
      f, _IsanAnim.percikanMunculMulai, _IsanAnim.percikanMunculSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final denyutOrb = 1 + math.sin((f / 60) * math.pi * 2 * 0.9) * 0.07;
    final ukuranOrb = 44 * orbMuncul * denyutOrb;
    final orbPadam = _IsanAnim.petakan(
      f, _IsanAnim.percikanMeledakMulai, _IsanAnim.percikanMeledakMulai + 40, 0, 1,
    );
    final opacityOrb = orbMuncul * (1 - orbPadam);

    // ── DEBU LATAR ──
    final opacityDebu = _IsanAnim.petakan(f, 20, 140, 0, 0.55);

    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              // ══ ORB PUSAT ══
              if (opacityOrb > 0.01) ...[
                Center(
                  child: Opacity(
                    opacity: (opacityOrb * 0.75).clamp(0.0, 1.0),
                    child: Container(
                      width: ukuranOrb * 6,
                      height: ukuranOrb * 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _IsanAnim.neonScarlet,
                            Color(0x73E50914), // 0.45
                            Color(0x00E50914),
                          ],
                          stops: [0.0, 0.32, 0.70],
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: opacityOrb.clamp(0.0, 1.0),
                    child: Container(
                      width: ukuranOrb,
                      height: ukuranOrb,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFFF0019),
                            _IsanAnim.merahNyala,
                            _IsanAnim.merahUtama,
                            Color(0x00E50914),
                          ],
                          stops: [0.0, 0.40, 0.75, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(color: _IsanAnim.neonScarlet, blurRadius: 34),
                          BoxShadow(
                            color: Color(0xBFE50914),
                            blurRadius: 130,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // ══ PERCIKAN AWAL: 4 jejak ke titik ancang ══
              if (f >= _IsanAnim.percikanMeledakMulai && f < _IsanAnim.iJatuhSelesai)
                ...List.generate(_IsanAnim.titikAncang.length, (i) {
                  final xTujuan = _IsanAnim.titikAncang[i];
                  final tunda = i * 5.0;
                  final t = _IsanAnim.petakan(
                    f,
                    _IsanAnim.percikanMeledakMulai + tunda,
                    _IsanAnim.percikanMeledakSelesai,
                    0, 1,
                    easing: _IsanAnim.sinematik,
                  );
                  final x = xTujuan * t;
                  final y = -80 * math.sin(t * math.pi);
                  final panjangJejak = 60 + (1 - t) * 170;
                  final opPercikan = t <= 0
                      ? 0.0
                      : math.min(1.0, t * 2.2) *
                          (t > 0.92 ? (1 - t) / 0.08 : 1.0);

                  return [
                    // Jejak ekor
                    Center(
                      child: Transform.translate(
                        offset: Offset(x - panjangJejak / 2, y),
                        child: Opacity(
                          opacity: (opPercikan * 0.7).clamp(0.0, 1.0),
                          child: Container(
                            width: panjangJejak,
                            height: 7,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00FF2A3B),
                                  _IsanAnim.merahNyala,
                                  Color(0xFFFF0019),
                                ],
                                stops: [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Kepala percikan
                    Center(
                      child: Transform.translate(
                        offset: Offset(x, y),
                        child: Opacity(
                          opacity: opPercikan.clamp(0.0, 1.0),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFFFF0019),
                                  _IsanAnim.merahNyala,
                                  Color(0x00FF2A3B),
                                ],
                                stops: [0.0, 0.55, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(color: _IsanAnim.neonScarlet, blurRadius: 16),
                                BoxShadow(
                                  color: Color(0xB3E50914),
                                  blurRadius: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                }).expand((e) => e),

              // ══ DEBU LATAR ══
              ...List.generate(_jumlahDebu, (i) {
                final x0 = _IsanAnim.acakStabil(i.toDouble(), 1) * 1080;
                final y0 = _IsanAnim.acakStabil(i.toDouble(), 2) * 1920;
                final ukuran = 1.2 + _IsanAnim.acakStabil(i.toDouble(), 3) * 3.4;
                final laju = 0.25 + _IsanAnim.acakStabil(i.toDouble(), 4) * 0.9;

                final naik = (f * laju * 0.35) % 2100;
                final goyang = math.sin(f * 0.018 * laju + i) * 26;
                final y = ((y0 - naik + 2100) % 2100) - 60;
                final x = x0 + goyang;

                final kedip = 0.35 +
                    0.65 *
                        (0.5 +
                            0.5 * math.sin(f * 0.05 * laju + i * 2.1));

                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: (opacityDebu * kedip).clamp(0.0, 1.0),
                    child: Container(
                      width: ukuran,
                      height: ukuran,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i % 4 == 0
                            ? const Color(0xFFFF0019)
                            : _IsanAnim.merahNyala,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SAPUAN CAHAYA & KILAU LENSA  (LightSweep.tsx)
// ══════════════════════════════════════════════════════════════════════
class _SapuanLensa extends StatelessWidget {
  const _SapuanLensa({required this.frame});
  final double frame;

  static const _jumlahKilau = 9;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    if (matikanSapuanUntukDiagnosa) return const SizedBox.shrink();
    final sapuan = _IsanAnim.petakan(
      f, _IsanAnim.sapuanMulai, _IsanAnim.sapuanSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final xSapuan = -200 + sapuan * 400;
    final kekuatan = math.sin(sapuan * math.pi);
    final aktif = f >= _IsanAnim.sapuanMulai && f < _IsanAnim.sapuanSelesai;
    if (!aktif) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              // ══ SAPUAN LENSA UTAMA ══
              Center(
                child: Transform.rotate(
                  angle: -38 * math.pi / 180,
                  child: Transform.translate(
                    offset: Offset(
                      (xSapuan / 100) * 540,
                      -(xSapuan / 100) * 540,
                    ),
                    child: Opacity(
                      opacity: (kekuatan * 0.95).clamp(0.0, 1.0),
                      child: Container(
                        width: 2000,
                        height: 420,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00000000),
                              Color(0x0DFF0033),
                              Color(0x59E50914),
                              Color(0xFFFF0019),
                              Color(0xFFFF0019),
                              Color(0xFFFF0019),
                              Color(0x59E50914),
                              Color(0x0DFF0033),
                              Color(0x00000000),
                            ],
                            stops: [
                              0.00, 0.18, 0.38, 0.49, 0.50,
                              0.51, 0.62, 0.82, 1.00,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ══ PITA SAMPING ══
              Center(
                child: Transform.rotate(
                  angle: -38 * math.pi / 180,
                  child: Transform.translate(
                    offset: Offset(
                      (xSapuan / 100) * 640,
                      -(xSapuan / 100) * 640,
                    ),
                    child: Opacity(
                      opacity: (kekuatan * 0.7).clamp(0.0, 1.0),
                      child: Container(
                        width: 2400,
                        height: 900,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00000000),
                              Color(0x1FE50914),
                              Color(0x38FF2A3B),
                              Color(0x1FE50914),
                              Color(0x00000000),
                            ],
                            stops: [0.0, 0.40, 0.50, 0.60, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ══ TITIK KILAU LENSA ══
              ...List.generate(_jumlahKilau, (i) {
                final lajuTitik = 0.72 + (i % 5) * 0.09;
                final xTitik = (xSapuan / 100) * 540 * lajuTitik;
                final yTitik = -(xSapuan / 100) * 540 * lajuTitik;
                final ukuranTitik = 14.0 + ((i * 7) % 30);

                final kedip = kekuatan *
                    (0.35 +
                        0.65 *
                            (math.sin(i * 1.7 + sapuan * math.pi * 3)).abs());

                return Center(
                  child: Transform.translate(
                    offset: Offset(xTitik, yTitik),
                    child: Opacity(
                      opacity: (kedip * 0.9).clamp(0.0, 1.0),
                      child: Container(
                        width: ukuranTitik,
                        height: ukuranTitik,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: i % 3 == 0
                                ? [
                                    Color(0xFFFF0019),
                                    _IsanAnim.merahNyala,
                                    const Color(0x00FF2A3B),
                                  ]
                                : [
                                    Color(0xFFFF0019),
                                    _IsanAnim.neonScarlet,
                                    const Color(0x00FF0033),
                                  ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _IsanAnim.neonScarlet,
                              blurRadius: ukuranTitik * 2.4,
                            ),
                            BoxShadow(
                              color: const Color(0xA6E50914),
                              blurRadius: ukuranTitik * 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ══ KILAUAN INTI LENSA ══
              Center(
                child: Transform.translate(
                  offset: Offset(
                    (xSapuan / 100) * 480,
                    -(xSapuan / 100) * 480,
                  ),
                  child: Opacity(
                    opacity: (kekuatan * 0.8).clamp(0.0, 1.0),
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          // ⚠️ DULU puncaknya PUTIH 55% (0x8CFFFFFF).
                          // Putih + merah di sekitarnya = KUNING
                          // (terbukti: RGB 254,226,48 di bawah logo).
                          // Sekarang merah terang dengan G rendah,
                          // sehingga mustahil menghasilkan kuning.
                          colors: [
                            Color(0x8CFF0019),
                            Color(0x40FF2A3B),
                            Color(0x00E50914),
                          ],
                          stops: [0.0, 0.30, 0.68],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  GAYA HURUF BERSAMA  (GAYA_HURUF + pendarHuruf)
// ══════════════════════════════════════════════════════════════════════
TextStyle _gayaHuruf() => const TextStyle(
      fontFamily: _IsanAnim.fontHuruf,
      fontWeight: FontWeight.w900,
      fontSize: _IsanAnim.ukuranHuruf,
      // ⚠️ DULU height: 1.0. Kotak baris jadi PERSIS setinggi font,
      // sehingga descender (ekor huruf di bawah garis dasar) tumpah
      // keluar kotak. Tumpahan itu digambar sebagai artefak KUNING
      // memanjang tepat di dasar huruf (terbukti dari peta layar:
      // huruf berhenti merah di 50%, lalu kuning di 51%).
      // Dinaikkan ke 1.15 supaya ada ruang untuk descender.
      height: 1.15,
      letterSpacing: -0.02 * _IsanAnim.ukuranHuruf,
      color: _IsanAnim.merahNyala,
    );

/// pendarHuruf(kekuatan) → daftar bayangan bertumpuk.
List<Shadow> _pendarHuruf(double kekuatan) {
  if (matikanBayanganUntukDiagnosa) return const [];
  final k = kekuatan.clamp(0.0, 1.0);
  return [
    Shadow(
      color: Color.fromRGBO(255, 42, 59, 0.95 * k),
      blurRadius: 10 + 18 * k,
    ),
    Shadow(
      color: Color.fromRGBO(229, 9, 20, 0.85 * k),
      blurRadius: 16 + 22 * k,
    ),
    Shadow(
      color: Color.fromRGBO(255, 0, 51, 0.6 * k),
      // Dikecilkan dari 62+90k menjadi 34+44k: blur 152px terlalu
      // berat untuk HP kelas bawah dan membuat animasi tersendat.
      blurRadius: 34 + 44 * k,
    ),
  ];
}

// ══════════════════════════════════════════════════════════════════════
//  HURUF 'I'  (LetterI.tsx)  — fase 2
// ══════════════════════════════════════════════════════════════════════
class _HurufI extends StatelessWidget {
  const _HurufI({required this.frame});
  final double frame;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    // 1. Jatuh dengan kelebihan gerak (PEGAS_JATUH: damping 8, mass 0.5).
    final jatuh = _IsanAnim.pegas(f, _IsanAnim.iJatuhMulai, 8, 0.5, 100);
    final yJatuh = -200 * (1 - jatuh);

    // 2. Sapuan berkas cahaya.
    final kemajuanSinar = _IsanAnim.petakan(
      f, _IsanAnim.iSinarMulai, _IsanAnim.iSinarSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final posisiSinar = -60 + kemajuanSinar * 220;

    final opacityHuruf = _IsanAnim.petakan(
      f, _IsanAnim.iSinarMulai, _IsanAnim.iJatuhSelesai + 30, 0, 1,
      easing: _IsanAnim.sinematik,
    );

    final blurHuruf = _IsanAnim.petakan(
      f, _IsanAnim.iJatuhMulai, _IsanAnim.iSinarSelesai, 10, 0,
      easing: _IsanAnim.sinematik,
    );

    // 3. Riak gelombang.
    final kemajuanRiak = _IsanAnim.petakan(
      f, _IsanAnim.iRiakMulai, _IsanAnim.iRiakSelesai, 0, 1,
      easing: _IsanAnim.keluarKubik,
    );
    final radiusRiak = 60 + kemajuanRiak * 260;
    final opacityRiak = (1 - kemajuanRiak) * 0.85;

    final kekuatanPendar = _IsanAnim.petakan(
          f, _IsanAnim.iSinarMulai, _IsanAnim.iSinarSelesai, 0, 0.85,
          easing: _IsanAnim.sinematik,
        ) +
        0.25 * (1 - kemajuanRiak);

    return Stack(
      children: [
        // ── RIAK: cincin yang membesar ──
        if (kemajuanRiak > 0 && kemajuanRiak < 1)
          Center(
            child: Transform.translate(
              offset: const Offset(_IsanAnim.posisiI, 0),
              child: Opacity(
                opacity: opacityRiak.clamp(0.0, 1.0),
                child: Container(
                  width: radiusRiak * 2,
                  height: radiusRiak * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _IsanAnim.neonScarlet,
                      width: 9 * (1 - kemajuanRiak) + 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── HURUF 'I' ──
        Center(
          child: Transform.translate(
            offset: Offset(_IsanAnim.posisiI, yJatuh),
            child: Opacity(
              opacity: opacityHuruf.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1 + kekuatanPendar * 0.02,
                child: Text(
                  'I',
                  style: _gayaHuruf().copyWith(
                    shadows: [
                      // ⚠️ DULU pakai bayangan PUTIH. Merah + putih
                      // terang ternyata menghasilkan KUNING di layar HP
                      // (terbukti dari pengukuran piksel: RGB 255,255,0).
                      // Sekarang pakai merah pudar supaya warna huruf
                      // tetap merah walau sedang kabur (blur).
                      Shadow(
                        color: Color.fromRGBO(
                            255, 42, 59, (blurHuruf / 40).clamp(0.0, 0.55)),
                        blurRadius: blurHuruf * 2,
                      ),
                      ..._pendarHuruf(kekuatanPendar),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── BERKAS CAHAYA VERTIKAL (sapuan) ──
        if (kemajuanSinar > 0 && kemajuanSinar < 1)
          Center(
            child: Transform.translate(
              offset: Offset(
                _IsanAnim.posisiI,
                (posisiSinar / 100) * 260,
              ),
              child: Opacity(
                // Opacity diturunkan dari 0.92 -> 0.55: berkas ini
                // menumpuk di atas pendar huruf, dan tumpukan merah
                // berlapis menaikkan kanal HIJAU -> tampak KUNING
                // (terbukti RGB 255,255,0 di dasar huruf 'I').
                opacity:
                    (0.55 * math.sin(kemajuanSinar * math.pi)).clamp(0.0, 1.0),
                child: Container(
                  width: 150,
                  height: 22,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      // ⚠️ DULU 0xFFFF0019 (G=64) dan 0xFFFA8072 (G=128).
                      // Kanal HIJAU tinggi = sumber KUNING di layar HP.
                      // Sekarang merah MURNI (G=9), mustahil jadi kuning.
                      colors: [
                        Color(0x00E50914),
                        Color(0xFFFF0019),
                        Color(0xFFFF0019),
                        Color(0xFFFF0019),
                        Color(0x00E50914),
                      ],
                      stops: [0.0, 0.22, 0.5, 0.78, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HURUF 'S'  (LetterS.tsx)  — fase 3
// ══════════════════════════════════════════════════════════════════════
class _HurufS extends StatelessWidget {
  const _HurufS({required this.frame});
  final double frame;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    // 1. Goresan jalur.
    final kemajuanGores = _IsanAnim.petakan(
      f, _IsanAnim.sGoresMulai, _IsanAnim.sGoresSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    // 2. Isian berputar (rotateY -90° → 0°).
    final kemajuanIsi = _IsanAnim.petakan(
      f, _IsanAnim.sIsiMulai, _IsanAnim.sIsiSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final putarY = -90 + kemajuanIsi * 90;
    // 3. Getaran mengunci.
    final kemajuanGetar = _IsanAnim.petakan(
      f, _IsanAnim.sGetarMulai, _IsanAnim.sGetarSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final amplitudoGetar =
        (1 - kemajuanGetar) * (kemajuanGetar > 0 ? 7 : 0);
    final g = _IsanAnim.derau3(f * 0.9, 3.1);

    final kekuatanPendar = _IsanAnim.petakan(
          f, _IsanAnim.sIsiMulai, _IsanAnim.sIsiSelesai, 0, 0.88,
          easing: _IsanAnim.sinematik,
        ) +
        0.2 * math.sin(kemajuanGetar * math.pi);

    return Stack(
      children: [
        Center(
          child: Transform.translate(
            offset: Offset(
              _IsanAnim.posisiS + g.x * amplitudoGetar,
              g.y * amplitudoGetar * 0.6,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── LAPISAN 1: goresan jalur 'S' (digambar bertahap) ──
                if (kemajuanGores > 0 && kemajuanIsi < 1)
                  Opacity(
                    opacity: (1 - kemajuanIsi * 0.65).clamp(0.0, 1.0),
                    child: CustomPaint(
                      size: const Size(250, 300),
                      painter: _PelukisJalurS(
                        kemajuan: kemajuanGores,
                        warna: _IsanAnim.merahNyala,
                        tebal: 8,
                      ),
                    ),
                  ),
                if (kemajuanGores > 0 && kemajuanIsi < 1)
                  Opacity(
                    opacity:
                        (0.85 * math.sin(kemajuanGores * math.pi)).clamp(0.0, 1.0),
                    child: CustomPaint(
                      size: const Size(250, 300),
                      painter: _PelukisJalurS(
                        kemajuan: kemajuanGores,
                        warna: Color(0xFFFF0019),
                        tebal: 2.6,
                      ),
                    ),
                  ),

                // ── LAPISAN 2: isian huruf 'S' ──
                Opacity(
                  opacity: kemajuanIsi.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(putarY * math.pi / 180),
                    child: Transform.scale(
                      scale: 0.92 + kemajuanIsi * 0.08,
                      child: Text(
                        'S',
                        style: _gayaHuruf().copyWith(
                          shadows: _pendarHuruf(kekuatanPendar),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pelukis jalur 'S' yang menggambar dirinya sendiri (strokeDashoffset).
class _PelukisJalurS extends CustomPainter {
  _PelukisJalurS({
    required this.kemajuan,
    required this.warna,
    required this.tebal,
  });
  final double kemajuan;
  final Color warna;
  final double tebal;

  @override
  void paint(Canvas canvas, Size size) {
    final jalur = Path()
      ..moveTo(205, 70)
      ..cubicTo(205, 30, 163, 10, 120, 10)
      ..cubicTo(71, 10, 34, 36, 34, 78)
      ..cubicTo(34, 116, 66, 134, 115, 146)
      ..cubicTo(168, 158, 207, 178, 207, 222)
      ..cubicTo(207, 268, 163, 290, 115, 290)
      ..cubicTo(66, 290, 30, 266, 30, 234);

    final metrik = jalur.computeMetrics().toList();
    if (metrik.isEmpty) return;
    final m = metrik.first;
    final panjang = m.length;
    final terlihat = panjang * kemajuan;

    final p = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = tebal > 4
          ? const MaskFilter.blur(BlurStyle.normal, 8)
          : const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawPath(m.extractPath(0, terlihat), p);
  }

  @override
  bool shouldRepaint(covariant _PelukisJalurS old) =>
      old.kemajuan != kemajuan || old.warna != warna;
}

// ══════════════════════════════════════════════════════════════════════
//  HURUF 'A'  (LetterA.tsx)  — fase 4
// ══════════════════════════════════════════════════════════════════════
class _HurufA extends StatelessWidget {
  const _HurufA({required this.frame});
  final double frame;

  static const _jumlahBintang = 22;
  static const _tinggiKaki = 260.0;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    // 1a. Kaki kiri & kanan.
    final tumbuhKaki = _IsanAnim.petakan(
      f, _IsanAnim.aKakiMulai, _IsanAnim.aKakiSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );
    final tumbuhKiri = math.min(1.0, tumbuhKaki * 1.35);
    final tumbuhKanan = _IsanAnim.petakan(
      f, _IsanAnim.aKakiMulai + 12, _IsanAnim.aKakiSelesai + 12, 0, 1,
      easing: _IsanAnim.sinematik,
    );

    // 1b. Palang horizontal.
    final kilatanPalang = _IsanAnim.petakan(
      f, _IsanAnim.aKakiMulai + 42, _IsanAnim.aKakiMulai + 66, 0, 1,
      easing: _IsanAnim.sinematik,
    );

    // 2. Skala kenyal (PEGAS_KENYAL: damping 7, mass 0.6).
    final p = _IsanAnim.pegas(f, _IsanAnim.aSkalaMulai, 7, 0.6, 90, durasi: 70);
    final skala = 0.2 + p * 0.9;

    final kekuatanPendar = _IsanAnim.petakan(
      f, _IsanAnim.aKakiSelesai, _IsanAnim.aSkalaSelesai, 0.3, 0.9,
      easing: _IsanAnim.sinematik,
    );

    // Ledakan bintang.
    final kemajuanLedak = _IsanAnim.petakan(
      f, _IsanAnim.aBintangMulai, _IsanAnim.aBintangSelesai, 0, 1,
      easing: _IsanAnim.sinematik,
    );

    final opacityIsian = _IsanAnim.petakan(
      f, _IsanAnim.aKakiMulai + 58, _IsanAnim.aSkalaMulai, 0, 1,
      easing: _IsanAnim.sinematik,
    );

    return Stack(
      children: [
        Center(
          child: Transform.translate(
            offset: const Offset(_IsanAnim.posisiA, 0),
            child: SizedBox(
              width: 400,
              height: 400,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── LEDAKAN BINTANG ──
                  if (f >= _IsanAnim.aBintangMulai)
                    ...List.generate(_jumlahBintang, (i) {
                      final sudut = (i / _jumlahBintang) * math.pi * 2 +
                          _IsanAnim.acakStabil(i.toDouble(), 5) * 0.5;
                      final jarakMaks =
                          120 + _IsanAnim.acakStabil(i.toDouble(), 9) * 190;
                      final jarak = kemajuanLedak * jarakMaks;
                      final ukuran = 3 + _IsanAnim.acakStabil(i.toDouble(), 13) * 6;
                      final opPartikel = (1 - kemajuanLedak) * 0.95;
                      final x = math.cos(sudut) * jarak;
                      final y = math.sin(sudut) * jarak +
                          math.pow(kemajuanLedak, 2) * 34;

                      return Center(
                        child: Transform.translate(
                          offset: Offset(x, y),
                          child: Opacity(
                            opacity: opPartikel.clamp(0.0, 1.0),
                            child: Container(
                              width: ukuran,
                              height: ukuran,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // Putih diganti merah terang: bintang
                                // putih di tengah pendar merah tampak
                                // kekuningan di layar HP.
                                color: i % 3 == 0
                                    ? const Color(0xFFFF0019)
                                    : _IsanAnim.neonScarlet,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  // ── BATANG KAKI KIRI ──
                  //
                  // ⚠️ PERBAIKAN POSISI: dulu alignmen Y = 1 (dasar wadah
                  // 400px). Padahal teks 'A' cuma setinggi ~232px dan
                  // berakhir di y≈316, bukan 400. Akibatnya kaki menjulur
                  // 84px terlalu ke bawah sehingga "x"-nya tidak sejajar
                  // dengan huruf A (kelihatan aneh).
                  //
                  // Perhitungan yang benar (meniru Remotion: bottom:0 pada
                  // wadah setinggi teks):
                  //   wadah 400, kaki 260 → pusat kaki = 200 + a*(400-260)/2
                  //   dasar kaki = pusat + 130 = 316  →  a = -0.2
                  Align(
                    alignment: const Alignment(-0.28, -0.2),
                    child: Opacity(
                      opacity: tumbuhKiri.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: 19 * math.pi / 180,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 26,
                          height: _tinggiKaki * tumbuhKiri,
                          decoration: const BoxDecoration(
                            borderRadius:
                                BorderRadius.all(Radius.circular(13)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              // ⚠️ DULU puncaknya kilauPutih (putih terang).
                              // Putih + merah di sekitarnya tampak KUNING
                              // di layar HP (terbukti dari pemindaian piksel
                              // RGB 255,254,4 tepat di posisi kaki 'A').
                              // Sekarang puncaknya merah terang.
                              colors: [
                                Color(0xFFFF0019),
                                _IsanAnim.merahNyala,
                                _IsanAnim.merahUtama,
                                Color(0x00E50914),
                              ],
                              stops: [0.0, 0.18, 0.70, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── BATANG KAKI KANAN ──
                  // Sama seperti kaki kiri: alignment Y disetel -0.2 supaya
                  // dasar kaki berada di y≈316 (sejajar dasar huruf A),
                  // bukan menjulur sampai 400.
                  Align(
                    alignment: const Alignment(0.28, -0.2),
                    child: Opacity(
                      opacity: tumbuhKanan.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: -19 * math.pi / 180,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 26,
                          height: _tinggiKaki * tumbuhKanan,
                          decoration: const BoxDecoration(
                            borderRadius:
                                BorderRadius.all(Radius.circular(13)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFF0019),
                                _IsanAnim.merahNyala,
                                _IsanAnim.merahUtama,
                                Color(0x00E50914),
                              ],
                              stops: [0.0, 0.18, 0.70, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── PALANG HORIZONTAL ──
                  Align(
                    alignment: const Alignment(0, 0.28),
                    child: Opacity(
                      opacity: kilatanPalang.clamp(0.0, 1.0),
                      child: Container(
                        width: 150 * kilatanPalang,
                        height: 20,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00FF2A3B),
                              Color(0xFFFF0019),
                              _IsanAnim.merahNyala,
                              Color(0xFFFF0019),
                              Color(0x00FF2A3B),
                            ],
                            stops: [0.0, 0.30, 0.50, 0.70, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── ISIAN HURUF 'A' ──
                  Opacity(
                    opacity: opacityIsian.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: skala,
                      child: Text(
                        'A',
                        style: _gayaHuruf().copyWith(
                          shadows: _pendarHuruf(kekuatanPendar),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HURUF 'N'  (LetterN.tsx)  — fase 5
// ══════════════════════════════════════════════════════════════════════
class _HurufN extends StatelessWidget {
  const _HurufN({required this.frame});
  final double frame;

  static const _jumlahJejak = 5;
  static const _jarakAwal = 500.0;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    // 1. Geseran dari kanan (PEGAS_GESER: damping 14, mass 0.7).
    final geserPegas = _IsanAnim.pegas(f, _IsanAnim.nGeserMulai, 14, 0.7, 130, durasi: 62);
    final x = _jarakAwal * (1 - geserPegas);

    // Kabur gerak dari kecepatan.
    final geserSebelumnya =
        _IsanAnim.pegas(f - 1, _IsanAnim.nGeserMulai, 14, 0.7, 130, durasi: 62);
    final xSebelumnya = _jarakAwal * (1 - geserSebelumnya);
    final kecepatan = (x - xSebelumnya).abs();
    final blurGerak = math.min(26.0, kecepatan * 0.55);
    final skalaX = 1 + math.min(0.34, kecepatan * 0.008);

    final opacityHuruf = _IsanAnim.petakan(
      f, _IsanAnim.nGeserMulai, _IsanAnim.nGeserMulai + 22, 0, 1,
      easing: _IsanAnim.sinematik,
    );

    final kekuatanPendar = _IsanAnim.petakan(
      f, _IsanAnim.nGeserMulai + 30, _IsanAnim.nGeserSelesai, 0.25, 0.9,
      easing: _IsanAnim.sinematik,
    );

    final masihMeluncur = f >= _IsanAnim.nGeserMulai && f < _IsanAnim.nGeserSelesai;

    return Stack(
      children: [
        Center(
          child: Transform.translate(
            offset: Offset(_IsanAnim.posisiN + x, 0),
            child: Opacity(
              opacity: opacityHuruf.clamp(0.0, 1.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── JEJAK GERAK ──
                  if (masihMeluncur && kecepatan > 0.8)
                    ...List.generate(_jumlahJejak, (i) {
                      final mundur = (i + 1) * 26.0;
                      final kekuatanJejak =
                          (1 - i / _jumlahJejak) * 0.4;
                      return Transform.translate(
                        offset: Offset(mundur, 0),
                        child: Opacity(
                          opacity: (kekuatanJejak * (blurGerak / 26))
                              .clamp(0.0, 1.0),
                          child: Text(
                            'N',
                            style: _gayaHuruf().copyWith(
                              color: Colors.transparent,
                              shadows: [
                                Shadow(
                                  color: _IsanAnim.neonScarlet,
                                  blurRadius: blurGerak * 0.6 + i * 1.4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  // ── HURUF 'N' ──
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(skalaX, 1 - math.min(0.1, kecepatan * 0.002)),
                    child: Text(
                      'N',
                      style: _gayaHuruf().copyWith(
                        shadows: [
                          // Sama seperti huruf I: jangan pakai putih,
                          // karena merah + putih = KUNING di layar HP.
                          Shadow(
                            color: Color.fromRGBO(
                                255, 42, 59, (blurGerak / 60).clamp(0.0, 0.55)),
                            blurRadius: blurGerak * 2,
                          ),
                          ..._pendarHuruf(kekuatanPendar),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
