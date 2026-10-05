import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/embed_penyedia.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../widgets/pemeran_geser.dart';
import '../widgets/app_background.dart';
import '../widgets/auth_guard.dart';
// Pemutar: PlatformView native "isan_background_webview" (BackgroundWebView.java),
// bukan WebViewWidget-nya webview_flutter — lihat penjelasan di "Player inline".
import '../widgets/isan_background_webview.dart';

// ── Widget komentar (dipakai bersama, sudah sama seperti di anime) ─────────
class _KomentarSection extends StatefulWidget {
  final String contentId;
  const _KomentarSection({required this.contentId});
  @override
  State<_KomentarSection> createState() => _KomentarSectionState();
}

class _KomentarSectionState extends State<_KomentarSection> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() { super.initState(); _load(); }

  // ── Layar penuh untuk pemutar ───────────────────────────────────────
  // Saat video di pemutar DIKLIK, halaman pemutar meminta layar penuh.
  // JANGAN memakai Navigator dari initState: saat itu context belum
  // terpasang ke pohon widget sehingga aplikasi membuat Activity baru yang
  // kosong — yang tampil hanya layar bawaan Android dengan ikon di sudut
  // kiri atas. Simpan tampilan layar penuh di dalam pohon layar ini saja.

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await Api.komentarList(widget.contentId);
      setState(() {
        // Backend mengirim `{ hasil: [...] }`, bukan `{ komentar: [...] }`.
        // Membaca `d['komentar']` membuat daftar ini SELALU kosong walau
        // komentarnya sudah tersimpan di database.
        _items = _bacaKomentar(d);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _post() async {
    final teks = _ctrl.text.trim();
    if (teks.isEmpty) return;
    if (!AuthGuard.requireLoginOr(context)) return;
    setState(() => _posting = true);
    try {
      await Api.komentarPost(widget.contentId, teks);
      _ctrl.clear();
      await _load();
    } catch (_) {} finally { setState(() => _posting = false); }
  }

  /// Ambil daftar komentar dari balasan backend.
  ///
  /// Backend mengirim `{ hasil: [...] }`, sedangkan layar ini dulu
  /// membaca `d['komentar']` — kunci yang tidak pernah ada, sehingga
  /// daftar komentarnya SELALU kosong walau datanya sudah tersimpan
  /// di database. Sekarang semua kunci yang mungkin dicoba, dan kalau
  /// tidak ada yang cocok, dipakai array pertama di dalam balasan.
  static List<Map<String, dynamic>> _bacaKomentar(dynamic d) {
    if (d is List) {
      return d
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (d is! Map) return [];

    for (final kunci in const [
      'komentar', 'comments', 'hasil', 'results', 'items', 'data',
    ]) {
      final v = d[kunci];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    for (final v in d.values) {
      if (v is List && v.isNotEmpty && v.first is Map) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KOMENTAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tulis komentar...',
                hintStyle: const TextStyle(color: AppColors.textFaint),
                filled: true, fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _posting ? null : _post,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.red))
        else if (_items.isEmpty)
          const Text('Belum ada komentar. Jadilah yang pertama!', style: TextStyle(color: AppColors.textFaint, fontSize: 12))
        else
          ..._items.take(30).map((k) => _KomentarItem(data: k)),
      ],
    );
  }
}

class _KomentarItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const _KomentarItem({required this.data});
  @override
  Widget build(BuildContext context) {
    final username = data['username']?.toString() ?? 'Anonim';
    final teks = data['teks']?.toString() ?? '';
    final waktu = data['waktu']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_outline, color: AppColors.red, size: 14),
          const SizedBox(width: 5),
          Text(username, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          Text(waktu, style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
        ]),
        const SizedBox(height: 5),
        Text(teks, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 12.5)),
      ]),
    );
  }
}

// ── Rekomendasi serupa ─────────────────────────────────────────────────────
class _RekomendasiMovie extends StatefulWidget {
  final String genre;
  final String excludeUrl;
  const _RekomendasiMovie({required this.genre, required this.excludeUrl});
  @override
  State<_RekomendasiMovie> createState() => _RekomendasiMovieState();
}
class _RekomendasiMovieState extends State<_RekomendasiMovie> {
  List<MovieItem> _items = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await Api.rekomendasiMovie(widget.genre, excludeUrl: widget.excludeUrl);
      final list = daftarDari(d)
          .map((e) => MovieItem.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.url != widget.excludeUrl)
          .take(10).toList();
      setState(() => _items = list);
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      const Text('REKOMENDASI SERUPA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
      const SizedBox(height: 12),
      SizedBox(height: 190, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final m = _items[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: m.url))),
            child: SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 150, width: 110,
                child: Image.network(Api.imgProxy(m.image), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt)),
              )),
              const SizedBox(height: 5),
              Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ])),
          );
        },
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MovieDetailScreen — player langsung tampil, "episode" jadi 1 tombol lebar
// ══════════════════════════════════════════════════════════════════════════════
class MovieDetailScreen extends StatefulWidget {
  final String url;
  final int? resumePosition; // dari riwayat: lanjut ke detik ini
  const MovieDetailScreen({super.key, required this.url, this.resumePosition});
  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

// Pemutar iframe embed — satu-satunya sumber stream.
/// Pilihan penyedia pemutar yang dikirim backend (field `daftar`).
///
/// Backend sekarang mengirim DAFTAR penyedia, bukan satu URL saja:
///   daftar: [
///     { id: 'vidsrc',   label: 'VidSrc (utama)',    embed: 'https://vidsrc.sbs/embed/movie/550' },
///     { id: 'vidsrc', label: 'VidSrc (utama)', embed: 'https://vidsrc.sbs/embed/movie/550' },
///   ]
/// Jadi tombol ganti-server di bawah pemutar dibangun dari data itu —
/// tambah penyedia di backend otomatis muncul di sini tanpa ubah Flutter.
class _PilihanServer {
  final String id;
  final String label;
  final String embed;
  const _PilihanServer({required this.id, required this.label, required this.embed});

  factory _PilihanServer.dari(dynamic m) {
    final map = (m is Map) ? m : const {};
    final embed = map['embed']?.toString() ?? '';
    final id = map['id']?.toString() ?? '';
    return _PilihanServer(
      id: id,
      // Buang keterangan "(utama)"/"(cadangan)" dari label backend supaya
      // tombolnya ringkas — cukup nama penyedianya.
      label: (map['label']?.toString() ?? id).replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().toUpperCase(),
      embed: embed,
    );
  }

  bool get berguna => id.isNotEmpty && embed.isNotEmpty;
}


class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieDetail? _detail;
  bool _loading = true;
  bool _streamLoading = false;
  String? _streamError;
  String? _streamUrl;

  /// Daftar penyedia pemutar dari backend (saat ini: vidsrc).
  /// Kosong = backend hanya mengirim satu URL (cara lama) → tombol
  /// ganti-server tidak ditampilkan.
  List<_PilihanServer> _daftarServer = const [];

  // ── FAVORIT ────────────────────────────────────────────────────
  // `_favoritId` diisi kalau judul ini SUDAH ada di daftar favorit
  // (dipakai untuk menghapus). Kosong = belum difavoritkan.
  String? _favoritId;
  bool _favoritSibuk = false;
  String? _serverId;

  /// Controller pemutar native (isan_background_webview). Ganti dari
  /// WebViewController-nya webview_flutter — lihat "Player inline" di build().
  final IsanWebViewController _webNativeCtrl = IsanWebViewController();



  // ── Riwayat tontonan: posisi terakhir dilaporkan lewat JS channel ──
  int _lastPositionSec = 0; // ignore: prefer_final_fields — diisi dari JS channel saat pemutaran
  int _lastDurationSec = 0; // ignore: prefer_final_fields — diisi dari JS channel saat pemutaran

  @override
  void initState() {
    super.initState();
    // Pemutar memakai IsanBackgroundWebView (PlatformView native), bukan
    // WebViewWidget dari webview_flutter. Lihat penjelasan di bagian
    // "Player inline" pada build().
    // (IsanWebViewController hanya punya onEnded/onError/onLog/onPopupBlocked/
    //  onRedirectBlocked; event pageFinished per-view dikirim lewat widget.)
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.movieDetail(widget.url);
      if (d['error'] != null) throw Exception(d['error']);
      setState(() { _detail = MovieDetail.fromJson(Map<String, dynamic>.from(d)); _loading = false; });
      // Auto-play begitu detail selesai dimuat
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
      // Periksa sekalian apakah judul ini sudah difavoritkan, supaya
      // tombolnya tampil terisi sejak halaman dibuka (bukan kosong
      // dulu lalu berubah).
      _muatFavorit();
    } catch (_) { setState(() => _loading = false); }
  }

  // (pemutar <video> lama dihapus — sekarang pakai iframe embed)

  // ── FAVORIT: muat keadaan & tombol ─────────────────────────────
  Future<void> _muatFavorit() async {
    final id = widget.url;
    try {
      final daftar = await Api.favoritList(batas: 300);
      if (!mounted) return;
      for (final x in daftar) {
        if (x['contentId']?.toString() == id &&
            (x['kind']?.toString() ?? 'movie') == 'movie') {
          setState(() => _favoritId = x['id']?.toString());
          return;
        }
      }
    } catch (_) {
      // Gagal memeriksa bukan masalah: tombol tetap tampil kosong dan
      // pengguna masih bisa mencoba menekannya.
    }
  }

  /// Tandai / lepas tanda favorit.
  ///
  /// `_favoritSibuk` mencegah dua permintaan berjalan bersamaan kalau
  /// tombol ditekan cepat dua kali.
  Future<void> _togelFavorit() async {
    if (_favoritSibuk) return;
    setState(() => _favoritSibuk = true);
    try {
      if (_favoritId != null) {
        // Sudah favorit -> hapus
        await Api.favoritHapus(_favoritId!);
        if (!mounted) return;
        setState(() => _favoritId = null);
        _pesan('Dihapus dari favorit');
      } else {
        // Belum favorit -> tambah
        final d = _detail;
        final ok = await Api.favoritToggle(
          contentId: widget.url,
          kind: 'movie',
          jenis: 'movie',
          title: d?.title,
          poster: d?.image,
          tahun: d?.year,
          rating: d?.rating,
        );
        if (!mounted) return;
        if (ok) {
          // Ambil ulang supaya dapat id barisnya (dibutuhkan untuk
          // menghapus nanti).
          setState(() => _favoritId = 'ada');
          _pesan('Ditambahkan ke favorit');
          _muatFavorit();
        } else {
          _pesan('Gagal menyimpan favorit');
        }
      }
    } catch (e) {
      if (mounted) _pesan('Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _favoritSibuk = false);
    }
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(teks), duration: const Duration(seconds: 2)),
    );
  }

  // ── SUMBER EMBED ────────────────────────────────────────────────
  // Backend menyusun URL embed dari id TMDB:
  //   /api/movie/stream?id=550  ->  { embed: "https://vidsrc.sbs/embed/movie/550" }
  // Video diputar di dalam iframe (bukan m3u8/proxy), jadi:
  //   * pakai WebView, bukan <video src=...>
  //   * tidak ada resume/progress tracking (isi iframe cross-origin)
  Future<void> _play() async {
    if (!AuthGuard.requireLoginOr(context)) return;
    setState(() { _streamLoading = true; _streamError = null; });
    try {
      final d = await Api.movieStream(widget.url);
      if (d is! Map) throw Exception('Balasan tidak dikenal');

      // galat otentikasi
      final galat = d['error']?.toString();
      if (galat == 'unauthorized' || galat == 'token_expired' ||
          galat == 'ip_mismatch' || galat == 'device_mismatch' ||
          galat == 'invalid_token') {
        setState(() => _streamLoading = false);
        if (mounted) {
          AuthGuard.showLoginRequiredDialog(context, message: d['message']?.toString());
        }
        return;
      }
      if (galat != null) throw Exception(galat);

      // Backend mengirim DAFTAR penyedia embed (saat ini: vidsrc).
      // Ambil semuanya; kalau kosong, jatuh ke 'embed' tunggal cara lama.
      final daftar = daftarPenyediaDari(d)
          .map((e) => _PilihanServer.dari(e))
          .where((p) => p.berguna)
          .toList();
      // URL embed film disusun di aplikasi (id TMDB sudah pasti ikut).
      final embedSendiri = embedFilmUrl(widget.url);
      final embedMentah = d['embed']?.toString() ?? '';
      final embed = embedSendiri.isNotEmpty ? embedSendiri : embedMentah;
      if (daftar.isEmpty && embed.isEmpty) {
        throw Exception('Pemutar tidak tersedia');
      }

      final utama = daftar.isNotEmpty ? daftar.first : null;
      setState(() {
        _daftarServer = daftar;
        _serverId = utama?.id ?? d['sumber']?.toString();
  // URL susunan aplikasi dipakai lebih dulu; URL backend cadangan.
        _streamUrl = embed.isNotEmpty
            ? embed
            : (utama?.embed.isNotEmpty == true ? utama!.embed : embedMentah);
        _streamLoading = false;
      });
      // Pemutar native menunggu widget-nya terpasang dulu; loadUrl dipanggil
      // setelah PlatformView dibuat (lihat onPlatformViewCreated di
      // isan_background_webview.dart) — di sini cukup simpan URL-nya.

      // ── RIWAYAT OTOMATIS ──
      // Pemutar sudah BERHASIL disiapkan (bukan gagal), jadi judul ini
      // dicatat ke riwayat tontonan. Tidak menunggu sampai halaman
      // ditutup, karena kalau pemutar embed tidak melaporkan posisi
      // tonton, riwayat tidak akan pernah tersimpan.
      //
      // Dijalankan TANPA ditunggu (fire-and-forget) supaya pemutar
      // tidak tertunda dan kegagalan menyimpan tidak sampai
      // menggagalkan pemutaran.
      _catatRiwayat();
    } catch (e) {
      setState(() {
        _streamError = 'Gagal memuat player. Coba lagi atau pilih film lain.';
        _streamLoading = false;
      });
    }
  }

  /// Ganti penyedia TANPA memanggil backend lagi — URL-nya sudah dikirim
  /// sekaligus di `daftar`, jadi cuma tukar URL di pemutar yang sama.
  void _switchServer(_PilihanServer pilihan) {
    if (_serverId == pilihan.id || pilihan.embed.isEmpty) return;
    setState(() {
      _serverId = pilihan.id;
      _streamUrl = pilihan.embed;
      _streamError = null;
    });
  }

  Widget _serverButton(_PilihanServer pilihan) {
    final active = _serverId == pilihan.id;
    return GestureDetector(
      onTap: () => _switchServer(pilihan),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.red : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.red : AppColors.border),
        ),
        child: Text(pilihan.label, style: TextStyle(
          color: active ? Colors.white : AppColors.textFaint,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        )),
      ),
    );
  }

  /// Catat judul ini ke riwayat tontonan.
  ///
  /// Dipanggil begitu pemutar dibuka. Sengaja tidak menunggu balasan
  /// (fire-and-forget) supaya pemutar tidak tertunda olehnya, dan
  /// kegagalan menyimpan riwayat tidak sampai menggagalkan pemutaran.
  void _catatRiwayat() {
    final d = _detail;
    if (d == null) return;
    // Posisi MINIMAL 1 detik, bukan 0.
    //
    // Posisi 0 dianggap "belum mulai menonton" sehingga barisnya bisa
    // tersaring dari daftar riwayat walau datanya sudah masuk
    // database. Satu detik sudah cukup untuk menandai "sudah dibuka
    // dan sedang ditonton"; posisi sungguhannya diperbarui lagi saat
    // halaman ditutup (lihat dispose()).
    Api.saveHistory(
      type: 'movie',
      contentId: widget.url,
      title: d.title,
      poster: d.image,
      position: _lastPositionSec > 0 ? _lastPositionSec : 1,
      duration: _lastDurationSec > 0 ? _lastDurationSec : null,
    ).catchError((_) => null);
  }

  @override
  void dispose() {
    // Simpan riwayat tontonan (detik terakhir) begitu user keluar dari halaman ini.
    // Fire-and-forget -- gak perlu ditunggu karena widget sudah/segera dibuang.
    if (_detail != null && _lastPositionSec >= 3) {
      Api.saveHistory(
        type: 'movie',
        contentId: widget.url,
        title: _detail!.title,
        poster: _detail!.image,
        position: _lastPositionSec,
        duration: _lastDurationSec > 0 ? _lastDurationSec : null,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.red)));
    }
    final detail = _detail;
    if (detail == null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg),
        body: const Center(child: Text('Film tidak ditemukan', style: TextStyle(color: AppColors.textMuted))));
    }

    final infoChips = [
      detail.year, detail.duration, detail.country,
      if (detail.release.isNotEmpty) 'Rilis: ${detail.release}',
      if (detail.votes.isNotEmpty) '${detail.votes} votes',
    ].where((e) => e.isNotEmpty).toList();
    final contentId = widget.url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final firstGenre = detail.genre.isNotEmpty ? detail.genre.split(',').first.trim() : 'action';

    // ── Tinggi banner ──────────────────────────────────────────────
    // Banner memakai rasio 16:9, tapi kalau dihitung apa adanya dari lebar
    // layar hasilnya tinggi sekali sehingga mendorong pemutar jauh ke bawah.
    // Tingginya dibatasi (maks. 62% layar & tidak lebih tinggi dari 16:9).
    final lebarLayar = MediaQuery.of(context).size.width;
    final tinggiLayar = MediaQuery.of(context).size.height;
    final padAtas = MediaQuery.of(context).padding.top;
    final tinggiBanner = (lebarLayar * 9 / 16).clamp(0.0, tinggiLayar * 0.62);

    // ── Gradasi banner ─────────────────────────────────────────────
    // Tiga fungsi dari SATU warna dasar (AppColors.bg) sehingga tepi mana
    // pun gradasinya mendarat tepat di warna latar halaman AppColors.bg —
    // tidak ada lagi "kotak" yang beda warna dari latar aplikasi.
    //
    // (jam/baterai) tetap terbaca di atas gambar yang terang.

    // DESKTOP: banner dibatasi tingginya supaya tidak menelan seluruh
    // layar 1280x720. Di HP (lebar < 900) hitungan aslinya dipakai —
    // tidak berubah.
    final desktop = lebarLayar >= 900;
    final tinggiBannerFinal = desktop
        ? (tinggiLayar * 0.42).clamp(240.0, 420.0)
        : tinggiBanner;

    final banner = SizedBox(
      height: tinggiBannerFinal,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gambar LEBAR (backdrop TMDB, rasio 16:9) ──
          // Kalau backdrop kosong, jatuh ke poster tegak supaya kepala
          // halaman tidak jadi kotak polos.
          Image.network(
            Api.imgProxy(
              detail.backdrop.isNotEmpty ? detail.backdrop : detail.image,
            ),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppColors.surfaceAlt),
          ),


          // ── GRADASI PENYATU LATAR ──
          //
          // Ditumpuk di ATAS gambar tetapi di BAWAH logo, supaya logo
          // tidak ikut memudar.
          //
          // ATAS  = hitam tipis saja (25%). Gambar backdrop tetap jelas
          //         kelihatan dan tulisan bilah status masih terbaca.
          //         (Dulu stop pertama memakai AppColors.bg yang nyaris
          //          hitam pekat, sehingga bagian atas banner tertutup
          //          total dan gambarnya tidak kelihatan.)
          // TENGAH = mulai menggelap, tempat logo berdiri biar kontras.
          // BAWAH  = AppColors.bg pekat, sama persis dengan warna latar
          //          halaman -> tepi banner menyatu, tidak ada garis.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.45),
                    AppColors.bg,
                  ],
                  stops: const [0.0, 0.62, 1.0],
                ),
              ),
            ),
          ),

          // Gelap tambahan di sisi kiri supaya kalau gambarnya terang,
          // bagian kiri tidak menyilaukan.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.bg.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── LOGO tulisan judul: DI TENGAH-TENGAH BAWAH ──
          //
          // Yang dimaksud "logo" bukan font, melainkan gambar PNG
          // transparan berisi tulisan judul yang sudah jadi seni
          // filmnya (TMDB `images.logos`). Kalau TMDB tidak punya logo
          // untuk judul ini, teks judul dipakai sebagai cadangan
          // (fallback) di posisi yang sama.
          //
          // Ditaruh di TENGAH mendatar dan di bagian BAWAH banner.
          // Lebarnya dibatasi 66% supaya logo yang aslinya sangat lebar
          // (mis. logo Moana 4311x1027) tidak melebar keluar layar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 26,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FractionallySizedBox(
                widthFactor: 0.66,
                child: _logoAtauJudul(detail),
              ),
            ),
          ),

          // ── Tombol kembali ──
          // Ikut mengambang di atas banner karena SliverAppBar di halaman
          // ini sengaja tinggi-nya nol (lihat "SliverAppBar penanda").
          Positioned(
            left: 8,
            top: padAtas + 4,
            child: _tombolKembali(context),
          ),
        ],
      ),
    );

    return AppBackground(
      image: AppBg.main,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Padding bawaan MediaQuery (bilah status) DIBUANG untuk isi halaman
        // ini saja: tanpa itu sliver pertama selalu didorong turun sejauh
        // tinggi bilah status dan banner tidak akan pernah menyentuh
        // langit-langit layar. Tombol kembali & logo mengambil ulang jarak
        // amannya sendiri lewat `padAtas` di atas.
        body: MediaQuery.removePadding(
          removeTop: true,
          context: context,
          child: CustomScrollView(
            slivers: [
          // ── SliverAppBar penanda ──
          // Tinggi NOL & tanpa isi: tujuannya cuma supaya bilah status
          // Android tetap MENGAMBANG (transparan) dan tidak disaput
          // warna pekat — dengan begitu banner terlihat sampai ke
          // langit-langit layar. Tombol kembalinya sendiri digambar
          // di dalam banner.
          const SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
          ),

          // ── BANNER: dua sudut BAWAH membulat, sudut atas siku ──
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: banner,
            ),
          ),

          // Judul ditulis ulang sebagai teks di bawah banner: logo
          // bergaya film kadang sulit dibaca (huruf sangat tipis atau
          // berbahasa asing), jadi teks ini yang jadi acuan jelas.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              // Judul di kiri (melebar mengisi ruang), tombol favorit di
              // kanan. Sebaris supaya tombolnya tidak pernah tertutup
              // atau terdorong keluar oleh baris chip di bawahnya, dan
              // tidak menambah tinggi halaman.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      detail.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _tombolFavorit(),
                ],
              ),
            ),
          ),

          // ── Sisa isi halaman (punya jarak tepi sendiri) ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const SizedBox(height: 10),

              // (Judul filmnya sendiri sudah ditulis tepat di bawah banner
              //  oleh sliver di atas — tidak diulang lagi di sini.)

              Wrap(spacing: 6, runSpacing: 6, children: [
                if (detail.rating.isNotEmpty) _chip('★ ${detail.rating}', AppColors.gold),
                ...infoChips.map((c) => _chip(c, AppColors.textMuted)),
              ]),

              if (detail.genre.isNotEmpty) ...[const SizedBox(height: 10),
                Text(detail.genre, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5))],
              if (detail.synopsis.isNotEmpty) ...[const SizedBox(height: 12),
                Text(detail.synopsis, maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.45))],
              if (detail.pemeran.isNotEmpty) ...[
                const SizedBox(height: 16),
                PemeranGeser(pemeran: detail.pemeran),
              ],

              const SizedBox(height: 20),

              // ── Pilihan penyedia pemutar ──
              // Muncul HANYA kalau backend mengirim daftar penyedia
              // (saat ini cuma vidsrc). Kalau cuma satu URL, tidak ada
              // yang perlu dipilih → baris ini tidak tampil.
              if (_daftarServer.length > 1) ...[
                Row(children: [
                  for (final p in _daftarServer) _serverButton(p),
                ]),
                const SizedBox(height: 10),
              ],

              // ── Player inline ──
              //
              // PENTING: pakai IsanBackgroundWebView (PlatformView native
              // "isan_background_webview"), BUKAN WebViewWidget biasa.
              //
              // Kenapa: WebViewWidget dari webview_flutter pakai WebView
              // Android biasa, yang otomatis MEM-PAUSE audio/video begitu
              // Chromium menganggap window-nya "hidden" -- dan itu terjadi
              // PERSIS saat video DIKLIK (klik memicu perubahan visibility
              // pada surface video). Akibatnya video mati dan yang tersisa
              // hanya permukaan kosong bawaan Android = "logo Android".
              //
              // BackgroundWebView.java sengaja memblokir sinyal
              // onWindowVisibilityChanged() itu, jadi video TIDAK
              // auto-pause. Ini cara yang sama yang dipakai pemutar Hydrax
              // dulu (lihat movie_webview_screen.dart) dan terbukti jalan.
              AspectRatio(aspectRatio: 16 / 9, child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(color: Colors.black,
                  child: _streamLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                      : (_streamUrl ?? '').isNotEmpty
                          ? Stack(children: [
                              IsanBackgroundWebView(
                                url: _streamUrl,
                                controller: _webNativeCtrl,
                              ),
                              if (_streamError != null)
                                Positioned(left: 0, right: 0, bottom: 0, child: Container(
                                  color: Colors.black.withOpacity(0.82),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_streamError!,
                                        style: const TextStyle(color: Colors.white, fontSize: 11.5))),
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _streamError = null);
                                        _webNativeCtrl.reload();
                                      },
                                      child: const Text('Coba lagi',
                                          style: TextStyle(color: AppColors.red, fontSize: 11.5)),
                                    ),
                                  ]),
                                )),
                            ])
                          : Center(child: _streamError != null
                              ? Text(_streamError!, style: const TextStyle(color: AppColors.textFaint), textAlign: TextAlign.center)
                              : const Icon(Icons.play_circle_outline, color: AppColors.border, size: 50)),                ),
              )),

              const SizedBox(height: 20),

              // ── "Episode" — 1 tombol lebar menutupi scroll (karena movie cuma 1) ──
              const Text('EPISODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              SizedBox(height: 44, child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: [
                  GestureDetector(
                        onTap: _streamLoading ? null : _play,
                    child: Container(
                      width: MediaQuery.of(context).size.width - 32,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red),
                      ),
                      alignment: Alignment.center,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_streamUrl != null ? Icons.replay : Icons.play_arrow, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ),
                ],
              )),

              const SizedBox(height: 28),
              _KomentarSection(contentId: contentId),
              _RekomendasiMovie(genre: firstGenre, excludeUrl: widget.url),
              const SizedBox(height: 24),
            ])),
          ),
        ],
          ),
        ),
      ),
    );
  }

  // ── LOGO tulisan judul (dengan cadangan teks judul) ────────────────
  //
  // Dipisah jadi method sendiri supaya banner tetap mudah dibaca: yang
  // dipakai adalah gambar LOGO dari TMDB (`detail.logo`), dan kalau
  // gambar itu kosong — atau gagal diunduh — teks judul filmnya yang
  // dipakai, di posisi dan ukuran yang sama persis.
  //
  // Dulu cabang gambar dan cabang teks ditulis dua kali terpisah
  // (satu di dalam errorBuilder, satu di luar) dengan gaya yang sama;
  // sekarang cuma ada SATU tempat yang mengurus tampilan logo.
  Widget _logoAtauJudul(MovieDetail detail) {
    // Teks cadangan. Warnanya dibuat putih PEKAT + garis bayangan hitam
    // supaya tetap terbaca di atas bagian banner yang masih terang.
    final teksJudul = Text(
      detail.title,
      textAlign: TextAlign.right,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.15,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 8),
        ],
      ),
    );

    // Gagal unduh logo → jangan tampilkan kotak putih "gambar rusak",
    // langsung jatuh ke teks judul.
    if (detail.logo.isEmpty) return teksJudul;

    return Image.network(
      Api.imgProxy(detail.logo),
      fit: BoxFit.contain,
      alignment: Alignment.centerRight,
      errorBuilder: (_, __, ___) => teksJudul,
    );
  }

  // ── Tombol kembali ────────────────────────────────────────────────
  // Digambar manual di dalam banner (bukan lewat leading SliverAppBar)
  // karena SliverAppBar-nya sengaja bertinggi nol supaya banner bisa
  // menyentuh langit-langit layar. Lingkaran gelap semi-transparan
  // dipakai agar ikonnya tetap terlihat di atas gambar apa pun.
  Widget _tombolKembali(BuildContext context) => ClipOval(
    child: Material(
      color: AppColors.bg.withOpacity(0.45),
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    ),
  );

  /// Tombol tambah / hapus favorit.
  ///
  /// Bentuknya sengaja dibuat seperti chip lain (bukan tombol besar)
  /// supaya menyatu dengan baris informasi di atasnya dan tidak
  /// menambah tinggi halaman.
  Widget _tombolFavorit() {
    final sudah = _favoritId != null;
    return GestureDetector(
      onTap: _favoritSibuk ? null : _togelFavorit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sudah ? AppColors.red.withOpacity(0.22) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sudah ? AppColors.red : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_favoritSibuk)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              sudah ? Icons.favorite : Icons.favorite_border,
              size: 13,
              color: sudah ? AppColors.red : AppColors.textMuted,
            ),
          const SizedBox(width: 5),
          Text(
            'Favorit',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: sudah ? AppColors.red : AppColors.textMuted,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
  );
}
