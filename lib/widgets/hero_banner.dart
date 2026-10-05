import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme.dart';

/// Satu judul di banner beranda.
class BannerItem {
  final String title;
  final String subtitle;
  /// URL gambar LEBAR (backdrop TMDB) — bukan poster tegak.
  final String image;
  /// URL PNG tulisan judul bergaya filmnya (TMDB `images.logos`).
  /// Kosong kalau TMDB tidak punya; UI memakai `title` sebagai gantinya.
  final String logo;
  /// id TMDB, dipakai untuk membuka halaman detail.
  final String url;

  BannerItem({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.url,
    this.logo = '',
  });
}

/// Banner beranda: 7 FILM TERBARU, otomatis ikut berubah.
///
/// Kenapa 7? Karena itu yang terbaca nyaman di layar HP — cukup banyak
/// supaya terasa hidup saat digeser, tapi tidak sampai memakan seluruh
/// layar pertama.
///
/// Kenapa film saja? Permintaan pemilik aplikasi: banner khusus film
/// terbaru. Series, anime, dan drakor tetap punya sectionnya sendiri
/// tepat di bawah banner.
///
/// Kenapa tidak diambil dari /api/beranda/terbaru yang sudah bercampur?
/// Karena di situ film bersaing dengan series/anime/drakor, jadi belum
/// tentu 7 film terbaru yang didapat.
class HeroBannerCarousel extends StatefulWidget {
  final List<BannerItem>? items;
  final void Function(BannerItem) onTapItem;
  final int jumlah;

  const HeroBannerCarousel({
    super.key,
    this.items,
    required this.onTapItem,
    this.jumlah = 7,
  });

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  late final PageController _controller = PageController(viewportFraction: 1.0);
  Timer? _timer;
  int _active = 0;

  List<BannerItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.items != null && widget.items!.isNotEmpty) {
      _items = widget.items!;
      _loading = false;
      _mulaiPutar();
    } else {
      _muat();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Ambil film terbaru dari backend.
  ///
  /// Ditaruh di dalam widget ini (bukan dikirim dari layar induk) supaya
  /// banner bisa menyegarkan dirinya sendiri saat beranda di-refresh,
  /// tanpa perlu layar induk tahu-menahu soal banner.
  Future<void> _muat() async {
    try {
      final d = await Api.get('/api/film/terbaru');
      final daftar = bacaDaftar(d)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final hasil = <BannerItem>[];
      for (final x in daftar) {
        if (hasil.length >= widget.jumlah) break;

        // BACKDROP dulu (gambar lebar 16:9), baru poster sebagai
        // cadangan. Poster tegak TIDAK dipakai kalau backdrop ada.
        var gambar = (x['backdrop'] ?? x['backdropHd'] ?? '').toString();
        if (gambar.isEmpty) gambar = (x['poster'] ?? '').toString();
        gambar = Api.imgProxy(gambar);

        final judul = (x['title'] ?? x['judul'] ?? '').toString();
        final id = (x['tmdbId'] ?? x['id'] ?? '').toString();
        if (judul.isEmpty || id.isEmpty) continue;

        // LOGO: backend mengambilnya di rute DETAIL, bukan di daftar.
        // Jadi banner menampilkan teks judul dulu, lalu logo diambil
        // menyusul per judul — daftar tetap tampil cepat walau logo
        // belum siap.
        hasil.add(BannerItem(
          title: judul,
          subtitle: (x['year'] ?? '').toString(),
          image: gambar,
          url: id,
        ));
      }

      if (!mounted) return;
      setState(() {
        _items = hasil;
        _loading = false;
      });
      if (hasil.isNotEmpty) _mulaiPutar();
      _ambilLogo();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ambil logo tiap judul satu per satu (di belakang layar).
  ///
  /// Dilakukan terpisah supaya banner langsung tampil walau logo belum
  /// siap — tiap logo butuh satu permintaan detail ke backend.
  Future<void> _ambilLogo() async {
    for (var i = 0; i < _items.length; i++) {
      final id = _items[i].url;
      try {
        final d = await Api.get('/api/film/detail', {'id': id});
        if (d is Map) {
          final logo = Api.imgProxy((d['logo'] ?? '').toString());
          if (logo.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _items = [
                for (var j = 0; j < _items.length; j++)
                  if (j == i)
                    BannerItem(
                      title: _items[j].title,
                      subtitle: _items[j].subtitle,
                      image: _items[j].image,
                      url: _items[j].url,
                      logo: logo,
                    )
                  else
                    _items[j],
              ];
            });
          }
        }
      } catch (_) {
        // Logo gagal diambil bukan masalah: teks judul sudah tampil.
      }
    }
  }

  void _mulaiPutar() {
    _timer?.cancel();
    if (_items.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _active = (_active + 1) % _items.length;
      _controller.animateToPage(
        _active,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── TINGGI BANNER ──────────────────────────────────────────────
    //
    // Diambil dari tinggi layar, bukan angka mati. Dulu 210 px — di HP
    // layar panjang angka itu terasa pendek dan gambarnya tidak sampai
    // menyentuh bagian paling atas. Sekarang 46% tinggi layar (dibatasi
    // supaya di layar pendek tidak berlebihan), jadi gambarnya BENAR-
    // BENAR naik sampai langit-langit layar.
    //
    // DESKTOP: jangan pakai 46% tinggi layar — di layar 1280x720 itu cuma
    // ~330 px padahal lebarnya 1280, jadi banner terlihat gepeng. Di
    // desktop dipakai tinggi tetap yang proporsional terhadap LEBAR.
    // Cabang ini hanya jalan kalau lebar >= 900, sehingga Android (yang
    // selalu lebih sempit) tetap memakai hitungan 46% di bawah.
    final bool desktop = MediaQuery.of(context).size.width >= 900;
    final tinggiLayar = MediaQuery.of(context).size.height;
    final tinggiBanner = desktop
        ? (tinggiLayar * 0.62).clamp(380.0, 560.0)
        : (tinggiLayar * 0.46).clamp(260.0, 430.0);

    if (_loading) {
      return SizedBox(
        height: tinggiBanner,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: tinggiBanner,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _active = i),
            itemBuilder: (ctx, i) => _kartu(_items[i]),
          ),
          // Titik penanda posisi
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _active ? AppColors.red : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartu(BannerItem item) {
    return GestureDetector(
      onTap: () => widget.onTapItem(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── GAMBAR LEBAR (backdrop) ────────────────────────────────
          //
          // TIDAK ada kotak membulat mengambang lagi. Gambar menyentuh
          // tepi layar di atas, kiri, kanan ("nyentuh langit-langit"),
          // dan hanya sudut BAWAH yang membulat — supaya terlihat
          // menyatu dengan halaman, bukan seperti kartu yang ditempel.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(22),
            ),
            child: Image.network(
              item.image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.surface),
            ),
          ),

          // ── GRADASI KE WALLPAPER ────────────────────────────────────
          //
          // Tiga persinggahan (0% / 55% / 100%) supaya peralihannya
          // mulus: bagian atas gambar masih jelas, lalu berangsur gelap,
          // dan di paling bawah warnanya SAMA PERSIS dengan latar
          // halaman. Itu sebabnya "garis" tempat banner berakhir tidak
          // kelihatan — gambarnya seolah luluh ke wallpaper.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.22),
                    AppColors.bg,
                  ],
                ),
              ),
            ),
          ),

          // ── JUDUL / LOGO: DI TENGAH-TENGAH BAWAH ───────────────────
          //
          // Pakai LOGO kalau ada (PNG tulisan judul bergaya filmnya),
          // kalau tidak ada pakai teks judul biasa.
          //
          // Ditaruh di TENGAH secara mendatar dan di bagian BAWAH
          // banner. Sebelumnya logo menempel di kiri; pemilik aplikasi
          // minta dipindah ke tengah bawah supaya tampak seperti
          // poster film pada umumnya.
          //
          // Lebarnya dibatasi 62% supaya logo yang aslinya sangat lebar
          // tidak melebar keluar layar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FractionallySizedBox(
                widthFactor: 0.62,
                child: item.logo.isEmpty
                    ? Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                        ),
                      )
                    : Image.network(
                        item.logo,
                        height: 54,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => Text(
                          item.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
