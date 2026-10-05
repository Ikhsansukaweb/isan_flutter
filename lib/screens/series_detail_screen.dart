import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/embed_penyedia.dart';
import '../models/series.dart';
import '../theme.dart';
import '../widgets/pemeran_geser.dart';
import '../widgets/app_background.dart';
import '../widgets/auth_guard.dart';
// Pemutar: PlatformView native "isan_background_webview" (BackgroundWebView.java),
// bukan WebViewWidget-nya webview_flutter — lihat penjelasan di "Player inline".
import '../widgets/isan_background_webview.dart';
import '../responsive.dart';


const String _seriesBase = 'https://tv4.nontondrama.my';

// ── Komentar (sama seperti anime/movie) ─────────────────────────────────────
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
class _RekomendasiSeries extends StatefulWidget {
  final String genre;
  final String excludeSlug;
  const _RekomendasiSeries({required this.genre, required this.excludeSlug});
  @override
  State<_RekomendasiSeries> createState() => _RekomendasiSeriesState();
}
class _RekomendasiSeriesState extends State<_RekomendasiSeries> {
  List<SeriesItem> _items = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await Api.rekomendasiSeries(widget.genre);
      final list = daftarDari(d)
          .map((e) => SeriesItem.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.slug != widget.excludeSlug)
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
          final s = _items[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: s.slug))),
            child: SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 150, width: 110,
                child: s.poster != null
                    ? Image.network(Api.imgProxy(s.poster!, ref: _seriesBase), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt))
                    : Container(color: AppColors.surfaceAlt, child: const Icon(Icons.theaters_outlined, color: AppColors.border)),
              )),
              const SizedBox(height: 5),
              Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ])),
          );
        },
      )),
    ]);
  }
}

// Pemutar iframe embed — satu-satunya sumber stream.
/// Pilihan penyedia pemutar yang dikirim backend (field `daftar`).
///
/// Backend mengirim DAFTAR penyedia, bukan satu URL saja:
///   daftar: [
///     { id: 'vidsrc',   label: 'VidSrc (utama)',     embed: '.../embed/tv/1399/1/1' },
///     { id: 'vidsrc', label: 'VidSrc (utama)', embed: '.../embed/tv/1399/1/1' },
///   ]
/// Tombol ganti-server dibangun dari data itu — tambah penyedia di
/// backend otomatis muncul di sini tanpa ubah Flutter.
class _PilihanServer {
  final String id;
  final String label;
  final String embed;
  const _PilihanServer({required this.id, required this.label, required this.embed});

  factory _PilihanServer.dari(dynamic m) {
    final map = (m is Map) ? m : const {};
    final id = map['id']?.toString() ?? '';
    return _PilihanServer(
      id: id,
      // Buang keterangan "(utama)"/"(cadangan)" supaya tombolnya ringkas.
      label: (map['label']?.toString() ?? id)
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .trim()
          .toUpperCase(),
      embed: map['embed']?.toString() ?? '',
    );
  }

  bool get berguna => id.isNotEmpty && embed.isNotEmpty;
}

// ══════════════════════════════════════════════════════════════════════════════
// SeriesDetailScreen — player inline (embed), episode scroll horizontal
// ══════════════════════════════════════════════════════════════════════════════
class SeriesDetailScreen extends StatefulWidget {
  final String slug;
  final int? resumeSeason;
  final int? resumeEpisode;
  final int? resumePosition;
  const SeriesDetailScreen({
    super.key,
    required this.slug,
    this.resumeSeason,
    this.resumeEpisode,
    this.resumePosition,
  });
  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetail? _detail;
  bool _loading = true;
  String? _error;
  int? _activeSeason;
  // Daftar episode per musim. Backend TIDAK menyertakan daftar episode
  // di /api/series/detail (di sana 'seasons' hanya berisi jumlah episode),
  // jadi tiap musim diambil terpisah dari
  //     GET /api/series/:id/season/:nomor
  final Map<int, List<SeriesEpisode>> _episodeMusim = {};
  final Set<int> _musimSedangDimuat = {};
  // Kalau season pertama sudah diisi otomatis, jangan autoplay dua kali.
  bool _autoplaySudah = false;

  /// Episode untuk sebuah musim: pakai yang sudah diambil, kalau belum
  /// ada pakai yang menempel di detail (kalau backend suatu saat mengirim).
  List<SeriesEpisode> _episodeUntuk(int? nomor) {
    if (nomor == null) return const [];
    final sudah = _episodeMusim[nomor];
    if (sudah != null) return sudah;
    final d = _detail;
    if (d != null) {
      for (final s in d.seasons) {
        if (s.season == nomor) return s.episodes;
      }
    }
    return const [];
  }

  /// Ambil daftar episode satu musim dari backend, lalu simpan.
  /// Boleh autoplay atau tidak.
  ///
  /// Autoplay HANYA untuk pembukaan pertama halaman. Kalau pengguna
  /// sudah memilih episode (atau sedang menonton), autoplay tidak
  /// boleh menimpa pilihannya — dulu itu penyebab episode selalu
  /// balik ke episode 1.
  ///
  /// Syaratnya:
  ///   • belum pernah autoplay di halaman ini, DAN
  ///   • belum ada episode yang sedang diputar.
  bool _bolehAutoplay() {
    if (_autoplaySudah) return false;
    if (_hasStream) return false;
    if (_activeEpisode > 0 && _activeEpisode != 1) return false;
    return true;
  }

  Future<void> _ambilEpisode(int nomor, {bool autoplay = false}) async {
    if (_musimSedangDimuat.contains(nomor)) return;
    final sudahAda = _episodeMusim[nomor];
    if (sudahAda != null && sudahAda.isNotEmpty) {
      if (autoplay && _bolehAutoplay()) {
        _autoplaySudah = true;
        _playEpisode(nomor, sudahAda.first.episode);
      }
      return;
    }
    setState(() => _musimSedangDimuat.add(nomor));
    try {
      final d = await Api.seriesSeason(widget.slug, nomor);
      final mentah = daftarDari(d);
      final list = mentah
          .map((e) => SeriesEpisode.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.episode.compareTo(b.episode));
      if (!mounted) return;
      setState(() {
        _episodeMusim[nomor] = list;
        _musimSedangDimuat.remove(nomor);
      });
      if (autoplay && _bolehAutoplay() && list.isNotEmpty) {
        _autoplaySudah = true;
        _playEpisode(nomor, list.first.episode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _musimSedangDimuat.remove(nomor));
    }
  }


  // Player state
  /// Controller pemutar native (isan_background_webview).
  final IsanWebViewController _webNativeCtrl = IsanWebViewController();
  bool _streamLoading = false;
  String? _streamError;
  bool _hasStream = false;

  /// URL embed pemutar yang sedang aktif (diteruskan ke PlatformView native).
  String? _embedUrl;
  int _activeEpisode = 1;

  /// Daftar penyedia pemutar dari backend (saat ini: vidsrc).
  /// Kosong = backend kirim satu URL saja -> tombol ganti-server disembunyikan.
  List<_PilihanServer> _daftarServer = const [];

  // ── FAVORIT ────────────────────────────────────────────────────
  // `_favoritId` diisi kalau serial ini SUDAH ada di daftar favorit
  // (dipakai untuk menghapus). Kosong = belum difavoritkan.
  String? _favoritId;
  bool _favoritSibuk = false;
  String? _serverId;

  // ── KATEGORI EPISODE ───────────────────────────────────────────
  // Indeks kelompok episode yang sedang dipilih pada dropdown.
  // Hanya dipakai kalau jumlah episode dalam satu musim lebih dari
  // [_batasKelompok]. 0 = kelompok pertama (1-50).
  int _kelompokEpisode = 0;

  // ── Riwayat tontonan: posisi terakhir dilaporkan lewat JS channel ──
  int _lastPositionSec = 0;
  int _lastDurationSec = 0;

  @override
  void initState() {
    super.initState();
    // Pemutar memakai IsanBackgroundWebView (PlatformView native), bukan
    // WebViewWidget dari webview_flutter — lihat penjelasan di bagian
    // "Player inline" pada build().
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.seriesDetail(widget.slug);
      if (d['error'] != null) throw Exception(d['error']);
      final detail = SeriesDetail.fromJson(Map<String, dynamic>.from(d));
      setState(() {
        _detail = detail;
        _activeSeason = detail.seasons.isNotEmpty ? detail.seasons.first.season : null;
        _loading = false;
      });
      // Periksa apakah serial ini sudah difavoritkan, supaya tombolnya
      // tampil terisi sejak halaman dibuka (bukan kosong lalu berubah).
      _muatFavorit();
      // Backend tidak mengirim daftar episode di rute detail, jadi ambil
      // episode musim pertama lewat /api/series/:id/season/:n.
      if (detail.seasons.isNotEmpty) {
        await _ambilEpisode(detail.seasons.first.season, autoplay: true);
      }
      // Auto-play: kalau dibuka dari Riwayat, lanjut ke season/episode terakhir
      // ditonton; kalau tidak, mulai dari episode 1 season pertama.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.resumeSeason != null && widget.resumeEpisode != null) {
          final seasonExists = detail.seasons.any((s) => s.season == widget.resumeSeason);
          if (seasonExists) {
            // Penyedia embed tidak melacak posisi tonton (iframe lintas domain)
            _playEpisode(widget.resumeSeason!, widget.resumeEpisode!);
            return;
          }
        }
        // Autoplay episode pertama sudah ditangani _ambilEpisode()
        // (daftar episode diambil dari rute season, bukan dari detail).
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // (pemutar <video> lama dihapus — sekarang pakai iframe embed)

  // Simpan riwayat episode yang SEDANG aktif sebelum pindah ke episode lain
  // atau saat keluar halaman -- posisi & durasi terakhir didapat dari JS channel.
  void _saveCurrentProgress() {
    final detail = _detail;
    if (detail == null || _lastPositionSec < 3) return;
    Api.saveHistory(
      type: 'series',
      contentId: detail.slug,
      title: detail.title,
      poster: detail.poster,
      position: _lastPositionSec,
      duration: _lastDurationSec > 0 ? _lastDurationSec : null,
      season: _activeSeason,
      episode: _activeEpisode,
    );
    _lastPositionSec = 0;
    _lastDurationSec = 0;
  }

  Future<void> _playEpisode(int season, int episode) async {
    if (!AuthGuard.requireLoginOr(context)) return;
    // Sebelum ganti episode, catat dulu progres episode yang sedang ditonton.
    if (_hasStream) _saveCurrentProgress();
    setState(() {
      _activeSeason = season;
      _activeEpisode = episode;
      _streamLoading = false;
      _streamError = null;
      _hasStream = false;
    });
    _loadStream(season, episode);
  }

  // ── SUMBER EMBED ────────────────────────────────────────────
  // Backend menyusun URL embed: /api/series/stream/{id}/{s}/{e}
  //   -> { embed: "https://vidsrc.sbs/embed/tv/{id}/{s}/{e}" }
  // Diputar di iframe -> pakai WebView, bukan <video src=...>.
  Future<void> _loadStream(int season, int episode) async {
    if (!AuthGuard.requireLoginOr(context)) return;
    setState(() {
      _streamLoading = true;
      _streamError = null;
      _hasStream = false;
    });
    try {
      final d = await Api.seriesStream(widget.slug, season, episode);
      if (d is! Map) throw Exception('Balasan tidak dikenal');

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

      // ── URL DISUSUN DI APLIKASI ──
      // Musim & episode yang benar-benar ditekan dimasukkan langsung ke
      // URL embed. Ini yang membuat menekan episode 3 memutar episode 3,
      // bukan selalu musim 1 episode 1 — dan tidak bergantung pada versi
      // backend yang sedang terpasang.
      //
      // Daftar penyedia juga disusun di sini, untuk mengisi tombol
      // ganti-penyedia dengan musim & episode yang sama.
      final embedSendiri =
          embedSerialUrl(widget.slug, season, episode);
      final embedBackend = d['embed']?.toString() ?? '';
      final embed =
          embedSendiri.isNotEmpty ? embedSendiri : embedBackend;
      if (embed.isEmpty) throw Exception('Sumber video tidak tersedia');

      // URL diteruskan ke PlatformView native lewat creationParams
      // (lihat isan_background_webview.dart) — native yang memuatnya.
      // Backend mengirim DAFTAR penyedia; kalau tidak ada, pakai
      // 'embed' tunggal seperti cara lama.
      final daftar = daftarPenyediaDari(d)
          .map((e) => _PilihanServer.dari(e))
          .where((p) => p.berguna)
          .toList();
      // ── URL YANG DIPAKAI: SUSUNAN APLIKASI ──
      //
      // Wajib memakai `embed` (yang sudah memuat ?s=<musim>&e=<episode>),
      // BUKAN `daftar.first.embed` dari backend. Dulu daftar backend
      // yang dipakai, sehingga musim & episode yang ditekan tidak pernah
      // sampai ke pemutar dan videonya selalu mulai dari musim 1
      // episode 1.
      final utama = daftar.isNotEmpty ? daftar.first : null;
      final urlPakai = embed.isNotEmpty
          ? embed
          : (utama?.embed.isNotEmpty == true
              ? utama!.embed
              : embedBackend);
      setState(() {
        _daftarServer = daftar;
        _serverId = utama?.id ?? d['sumber']?.toString();
        _embedUrl = urlPakai;
        _hasStream = true;
        _streamLoading = false;
      });
    } catch (e) {
      setState(() {
        _streamError = 'Gagal memuat player. Coba lagi atau pilih episode lain.';
        _streamLoading = false;
      });
    }
  }

  /// Ganti penyedia TANPA memanggil backend lagi — semua URL sudah
  /// dikirim sekaligus di `daftar`.
  void _switchServer(_PilihanServer pilihan) {
    if (_serverId == pilihan.id || pilihan.embed.isEmpty) return;
    setState(() {
      _serverId = pilihan.id;
      _embedUrl = pilihan.embed;
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

  @override
  void dispose() {
    _saveCurrentProgress();
    super.dispose();
  }

  // ── FAVORIT: muat keadaan & tombol ─────────────────────────────
  Future<void> _muatFavorit() async {
    try {
      final daftar = await Api.favoritList(batas: 300);
      if (!mounted) return;
      for (final x in daftar) {
        if (x['contentId']?.toString() == widget.slug &&
            (x['kind']?.toString() ?? 'tv') == 'tv') {
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
        await Api.favoritHapus(_favoritId!);
        if (!mounted) return;
        setState(() => _favoritId = null);
        _pesan('Dihapus dari favorit');
      } else {
        final d = _detail;
        final ok = await Api.favoritToggle(
          contentId: widget.slug,
          kind: 'tv',
          jenis: 'series',
          title: d?.title,
          poster: d?.poster,
        );
        if (!mounted) return;
        if (ok) {
          setState(() => _favoritId = 'ada');
          _pesan('Ditambahkan ke favorit');
          _muatFavorit();
        } else {
          _pesan('Gagal menyimpan favorit');
        }
      }
    } catch (e) {
      if (mounted) {
        _pesan('Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
      }
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

  /// Tombol tambah / hapus favorit.
  ///
  /// Bentuknya sengaja dibuat seperti chip lain supaya menyatu dengan
  /// baris informasi, dan TIDAK menambah tinggi halaman.
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

  // ── KATEGORI EPISODE ───────────────────────────────────────────
  /// Batas kelompok episode: 1-50, 51-100, 101-150, ...
  static const int _batasKelompok = 50;

  /// Jumlah kelompok episode untuk sejumlah episode.
  static int _jumlahKelompok(int total) {
    if (total <= _batasKelompok) return 1;
    return (total + _batasKelompok - 1) ~/ _batasKelompok;
  }

  /// Tulis rentang kelompok, mis. "1-50", "51-100", "151-200".
  static String _labelKelompok(int indeks, int total) {
    final awal = indeks * _batasKelompok + 1;
    final akhir = ((indeks + 1) * _batasKelompok).clamp(0, total);
    return '$awal-$akhir';
  }

  /// Ambil potongan episode untuk kelompok ke-`indeks`.
  ///
  /// Kalau kelompoknya cuma satu (episode 50 atau kurang), seluruh
  /// daftar dikembalikan apa adanya — jadi tampilan untuk serial
  /// pendek tidak berubah sama sekali.
  static List<SeriesEpisode> _potongKelompok(
      List<SeriesEpisode> semua, int indeks) {
    if (semua.length <= _batasKelompok) return semua;
    final awal = indeks * _batasKelompok;
    if (awal >= semua.length) return const [];
    final akhir = (awal + _batasKelompok).clamp(0, semua.length);
    return semua.sublist(awal, akhir);
  }

  /// Dropdown pemilih kategori episode.
  ///
  /// Hanya ditampilkan kalau episode dalam musim ini LEBIH DARI 50 —
  /// kalau tidak, deretan tombolnya pendek dan dropdown hanya
  /// memakan tempat.
  Widget _dropdownKelompok(List<SeriesEpisode> semua) {
    final jumlah = _jumlahKelompok(semua.length);
    if (jumlah <= 1) return const SizedBox.shrink();
    // Jaga-jaga: kelompok yang dipilih bisa di luar jangkauan waktu
    // pindah musim dengan jumlah episode berbeda.
    final pilih = _kelompokEpisode.clamp(0, jumlah - 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: pilih,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            icon: const Icon(Icons.expand_more,
                color: AppColors.textMuted, size: 20),
            style: const TextStyle(
                color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
            items: [
              for (var i = 0; i < jumlah; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text('Episode ${_labelKelompok(i, semua.length)}'),
                ),
            ],
            onChanged: (i) {
              if (i == null) return;
              setState(() => _kelompokEpisode = i);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.red)));
    }
    final detail = _detail;
    if (_error != null || detail == null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg),
        body: Center(child: Text(_error ?? 'Series tidak ditemukan', style: const TextStyle(color: AppColors.textMuted))));
    }

    final currentSeason = detail.seasons.where((s) => s.season == _activeSeason).isNotEmpty
        ? detail.seasons.firstWhere((s) => s.season == _activeSeason) : null;
    // Daftar episode diambil terpisah dari /api/series/:id/season/:n
    // karena rute detail tidak menyertakannya.
    final episodeAktif = _episodeUntuk(_activeSeason);
    final sedangMemuatEpisode = _activeSeason != null && _musimSedangDimuat.contains(_activeSeason);

    final infoChips = [detail.year, detail.country,
      if (detail.votes.isNotEmpty) '${detail.votes} votes'].where((e) => e.isNotEmpty).toList();
    final contentId = detail.slug.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final firstGenre = detail.genres.isNotEmpty ? detail.genres.first : 'drama';

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

    final banner = SizedBox(
      height: tinggiBanner,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gambar LEBAR (backdrop TMDB, rasio 16:9) ──
          // Kalau backdrop kosong, jatuh ke poster tegak supaya kepala
          // halaman tidak jadi kotak polos.
          Image.network(
            Api.imgProxy(
              detail.backdrop.isNotEmpty ? detail.backdrop : detail.poster,
              ref: _seriesBase,
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
          // serialnya (TMDB `images.logos`). Kalau TMDB tidak punya logo
          // untuk judul ini, teks judul dipakai sebagai cadangan
          // (fallback) di posisi yang sama.
          //
          // Ditaruh di TENGAH mendatar dan di bagian BAWAH banner.
          // Lebarnya dibatasi 66% supaya logo yang aslinya sangat lebar
          // tidak melebar keluar layar.
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
          // Dibungkus ClipRRect supaya hanya sudut bawah yang membulat —
          // sudut atas tetap siku sampai menyentuh tepi atas layar.
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: banner,
            ),
          ),

          // ── JUDUL + TOMBOL FAVORIT ──
          //
          // Judul di kiri (melebar mengisi ruang), tombol favorit di
          // kanan. Sebaris supaya tombolnya tidak pernah tertutup atau
          // terdorong keluar oleh baris chip di bawahnya, dan tidak
          // menambah tinggi halaman.
          //
          // Sliver tersendiri (bukan di dalam SliverList): di dalam
          // SliverList, tinggi tiap anak dihitung satu per satu dan
          // perhitungannya meleset begitu ada `Wrap` yang jumlah
          // barisnya berubah-ubah — anak berikutnya lalu ikut
          // terpotong. Itu sebabnya tombol favorit dulu hilang waktu
          // chip informasinya 2 baris atau lebih.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 14, 16, 0),
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

          SliverPadding(
            padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 0, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const SizedBox(height: 10),
              // (Judul serialnya sendiri sudah ditulis tepat di bawah
              //  banner oleh sliver di atas — tidak diulang lagi di sini.)

              Wrap(spacing: 6, runSpacing: 6, children: [
                if (detail.rating.isNotEmpty) _chip('★ ${detail.rating}', AppColors.gold),
                if (detail.totalSeasons > 0) _chip('${detail.totalSeasons} Season', AppColors.purple),
                if (detail.status.isNotEmpty) _chip(detail.status, AppColors.textMuted),
              ]),
              if (detail.genres.isNotEmpty || infoChips.isNotEmpty) ...[const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ...detail.genres.map((g) => _chip(g, AppColors.textMuted)),
                  ...infoChips.map((c) => _chip(c, AppColors.textMuted)),
                ])],
              if (detail.synopsis.isNotEmpty) ...[const SizedBox(height: 12),
                Text(detail.synopsis, maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.45))],
              if (detail.pemeran.isNotEmpty) ...[
                const SizedBox(height: 16),
                PemeranGeser(pemeran: detail.pemeran),
              ],

              const SizedBox(height: 20),

              // ── Pilihan penyedia pemutar ──
              //
              // TIDAK ditampilkan kalau penyedianya cuma satu. Sekarang
              // aplikasi cuma memakai vidsrc, jadi baris ini tidak
              // muncul dan tulisan "VidSrc" tidak lagi terlihat.
              //
              // Syaratnya sengaja tetap ditulis (bukan dihapus) supaya
              // kalau nanti ada penyedia kedua ditambahkan di backend,
              // tombol pilihnya langsung muncul lagi tanpa perlu ubah
              // berkas ini.
              if (_daftarServer.length > 1) ...[
                Row(children: [
                  for (final p in _daftarServer) _serverButton(p),
                ]),
                const SizedBox(height: 10),
              ],

              // ── Player inline ──
              AspectRatio(aspectRatio: 16 / 9, child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(color: Colors.black,
                  child: _streamLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                      : _hasStream
                          // WebView tetap ditampilkan walau halaman pemutar
                          // melaporkan error, supaya pemutarnya sendiri bisa
                          // mencoba memulihkan diri; pesannya muncul di bawah.
                          ? Stack(children: [
                              IsanBackgroundWebView(
                                url: _embedUrl,
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

              // ── Season selector ──
              if (detail.seasons.length > 1) ...[
                const Row(children: [
                  Text('SEASON', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
                ]),
                const SizedBox(height: 10),
                SizedBox(height: 36, child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: detail.seasons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final s = detail.seasons[i];
                    final active = s.season == _activeSeason;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeSeason = s.season;
                          // Kembali ke kelompok pertama: jumlah episode
                          // musim baru bisa berbeda, jadi kelompok lama
                          // bisa menunjuk di luar jangkauan.
                          _kelompokEpisode = 0;
                        });
                        _ambilEpisode(s.season);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.red : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? AppColors.red : AppColors.border),
                        ),
                        child: Text('Season ${s.season}',
                            style: TextStyle(color: active ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ),
                    );
                  },
                )),
                const SizedBox(height: 16),
              ],

              // ── Episode scroll horizontal ──
              const Text('EPISODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              if (episodeAktif.isEmpty && sedangMemuatEpisode)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Memuat episode...', style: TextStyle(color: AppColors.textFaint)),
                )
              else if (episodeAktif.isEmpty)
                const Text('Episode belum tersedia untuk season ini', style: TextStyle(color: AppColors.textFaint))
              else
                // Dropdown kategori episode — hanya muncul kalau
                // episode musim ini lebih dari 50.
                _dropdownKelompok(episodeAktif),
                SizedBox(height: 44, child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount:
                      _potongKelompok(episodeAktif, _kelompokEpisode).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final ep =
                        _potongKelompok(episodeAktif, _kelompokEpisode)[i];
                    final active = _activeSeason == (currentSeason?.season ?? _activeSeason) && _activeEpisode == ep.episode;
                    return GestureDetector(
                      onTap: () {
                        final sn = currentSeason?.season ?? _activeSeason;
                        if (sn != null) _playEpisode(sn, ep.episode);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: active ? AppColors.red : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? AppColors.red : AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text('${ep.episode}',
                            style: TextStyle(color: active ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ),
                    );
                  },
                )),

              const SizedBox(height: 28),
              _KomentarSection(contentId: contentId),
              _RekomendasiSeries(genre: firstGenre, excludeSlug: detail.slug),
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
  // gambar itu kosong — atau gagal diunduh — teks judul serialnya yang
  // dipakai, di posisi dan ukuran yang sama persis.
  //
  // Dulu cabang gambar dan cabang teks ditulis dua kali terpisah
  // (satu di dalam errorBuilder, satu di luar) dengan gaya yang sama;
  // sekarang cuma ada SATU tempat yang mengurus tampilan logo.
  Widget _logoAtauJudul(SeriesDetail detail) {
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
      Api.imgProxy(detail.logo, ref: _seriesBase),
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

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
  );
}
