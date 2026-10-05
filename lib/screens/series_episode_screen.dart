import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/embed_penyedia.dart';
import '../theme.dart';
import '../widgets/auth_guard.dart';
// Pemutar: PlatformView native "isan_background_webview" (BackgroundWebView.java),
// bukan WebViewWidget-nya webview_flutter — lihat movie_detail_screen.dart.
import '../widgets/isan_background_webview.dart';

/// Pilihan penyedia pemutar dari backend (field `daftar`).
/// Lihat penjelasan lengkap di movie_detail_screen.dart.
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
      label: (map['label']?.toString() ?? id)
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .trim()
          .toUpperCase(),
      embed: map['embed']?.toString() ?? '',
    );
  }

  bool get berguna => id.isNotEmpty && embed.isNotEmpty;
}

class SeriesEpisodeScreen extends StatefulWidget {
  final String slug;
  final int season;
  final int episode;
  final String title;

  const SeriesEpisodeScreen({
    super.key,
    required this.slug,
    required this.season,
    required this.episode,
    required this.title,
  });

  @override
  State<SeriesEpisodeScreen> createState() => _SeriesEpisodeScreenState();
}

class _SeriesEpisodeScreenState extends State<SeriesEpisodeScreen> {
  /// Controller pemutar native (isan_background_webview).
  final IsanWebViewController _webNativeCtrl = IsanWebViewController();
  String? _embedUrl;
  bool _loading = true;
  String? _error;
  bool _hasStream = false;
  late int _season;
  late int _episode;

  /// Daftar penyedia pemutar dari backend (saat ini: vidsrc).
  List<_PilihanServer> _daftarServer = const [];
  String? _serverId;

  @override
  void initState() {
    super.initState();
    // Pemutar memakai IsanBackgroundWebView (PlatformView native), bukan
    // WebViewWidget dari webview_flutter — lihat movie_detail_screen.dart.

    _season = widget.season;
    _episode = widget.episode;



    // Cek login SETELAH frame pertama selesai render -- initState belum
    // "settled" buat nampilin dialog (showDialog butuh context yang udah
    // ke-attach ke Navigator dengan benar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AuthGuard.requireLoginOr(context)) {
        setState(() => _loading = false);
        return;
      }
      _load(_season, _episode);
    });
  }

  // (pemutar <video> lama dihapus — sekarang pakai iframe embed)

  // ── SUMBER EMBED ───────────────────────────────────────────
  // Backend menyusun URL embed: /api/series/stream/{id}/{s}/{e}
  //   -> { embed: "https://vidsrc.sbs/embed/tv/{id}/{s}/{e}" }
  // Diputar di iframe, jadi pakai WebView (bukan <video src=...>).
  /// Catat episode ini ke riwayat tontonan.
  ///
  /// Dipanggil setelah pemutar episode benar-benar berhasil dimuat
  /// (bukan saat masih memuat), supaya episode yang gagal dibuka
  /// tidak ikut tercatat sebagai sudah ditonton.
  ///
  /// Sengaja tidak menunggu balasan (fire-and-forget) supaya pemutar
  /// tidak tertunda dan kegagalan menyimpan riwayat tidak sampai
  /// menggagalkan pemutaran.
  void _catatRiwayat(int season, int episode) {
    Api.saveHistory(
      type: 'series',
      contentId: widget.slug,
      title: widget.title,
      // Posisi MINIMAL 1 detik, bukan 0.
      //
      // Posisi 0 dianggap "belum mulai menonton" sehingga barisnya
      // bisa tersaring dari daftar riwayat walau datanya sudah masuk
      // database. Satu detik sudah cukup untuk menandai "sudah dibuka
      // dan sedang ditonton".
      position: 1,
      season: season,
      episode: episode,
    ).catchError((_) => null);
  }

  Future<void> _load(int season, int episode) async {
    setState(() {
      _loading = true;
      _error = null;
      _hasStream = false;
      _season = season;
      _episode = episode;
    });
    try {
      final d = await Api.seriesStream(widget.slug, season, episode);
      if (d is! Map) throw Exception('Balasan tidak dikenal');

      final galat = d['error']?.toString();
      if (galat == 'unauthorized' || galat == 'token_expired' ||
          galat == 'ip_mismatch' || galat == 'device_mismatch' ||
          galat == 'invalid_token') {
        setState(() => _loading = false);
        if (mounted) {
          AuthGuard.showLoginRequiredDialog(context, message: d['message']?.toString());
        }
        return;
      }
      if (galat != null) throw Exception(galat);

      // ── URL DISUSUN DI APLIKASI ──
      // Musim & episode yang benar-benar ditekan dimasukkan langsung ke
      // URL embed, supaya menekan episode 3 memutar episode 3 — bukan
      // selalu musim 1 episode 1.
      final embedSendiri = embedSerialUrl(widget.slug, season, episode);
      final embedBackend = d['embed']?.toString() ?? '';
      final embed =
          embedSendiri.isNotEmpty ? embedSendiri : embedBackend;
      if (embed.isEmpty) throw Exception('Sumber video tidak tersedia');

      setState(() {
        final daftar = daftarPenyediaDari(d)
            .map((e) => _PilihanServer.dari(e))
            .where((x) => x.berguna)
            .toList();
        final utama = daftar.isNotEmpty ? daftar.first : null;
        _daftarServer = daftar;
        _serverId = utama?.id ?? d['sumber']?.toString();
        // URL susunan aplikasi dipakai lebih dulu (memuat ?s=&e=);
// URL backend hanya cadangan.
      _embedUrl = embedSendiri.isNotEmpty
          ? embedSendiri
          : (utama?.embed.isNotEmpty == true
              ? utama!.embed
              : embedBackend);
        _hasStream = true;
        _loading = false;
      });

      // ── RIWAYAT OTOMATIS ──
      // Pemutar sudah BERHASIL dibuka (bukan sedang memuat, bukan
      // gagal), jadi episode ini dicatat ke riwayat tontonan.
      // Tidak menunggu sampai halaman ditutup, karena kalau pemutar
      // embed tidak melaporkan posisi tonton, riwayat tidak akan
      // pernah tersimpan.
      //
      // Dijalankan TANPA ditunggu (fire-and-forget) supaya pemutar
      // tidak tertunda dan kegagalan menyimpan tidak sampai
      // menggagalkan pemutaran.
      _catatRiwayat(season, episode);
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat player. Coba lagi atau pilih episode lain.';
        _loading = false;
      });
      // ignore: avoid_print
      print('series stream error: $e');
    }
  }

  // Dipanggil dari tombol Sebelumnya/Selanjutnya -- reset state KEDUA server
  // (biar gak nampilin video episode lama pas balik ke server itu), lalu
  // load ulang cuma server yang lagi aktif.
  void _goToEpisode(int season, int episode) {
    setState(() {
      _season = season;
      _episode = episode;
      _hasStream = false;
    });
    _load(season, episode);
  }

  /// Ganti penyedia TANPA memanggil backend lagi.
  void _switchServer(_PilihanServer pilihan) {
    if (_serverId == pilihan.id || pilihan.embed.isEmpty) return;
    setState(() {
      _serverId = pilihan.id;
      _embedUrl = pilihan.embed;
      _error = null;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('${widget.title} — S$_season E$_episode',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      ),
      body: Column(
        children: [
          // ── Pilihan penyedia pemutar ──
          //
          // TIDAK ditampilkan kalau penyedianya cuma satu. Sekarang cuma
          // vidsrc, jadi tulisan "VidSrc" tidak muncul dan ruangnya
          // dipakai videonya. Syaratnya tetap ditulis supaya tombol
          // otomatis muncul kalau nanti ada penyedia kedua.
          if (_daftarServer.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                for (final p in _daftarServer) _serverButton(p),
              ]),
            ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                  : _hasStream
                      ? IsanBackgroundWebView(url: _embedUrl, controller: _webNativeCtrl)
                      : Center(
                          child: Text(_error ?? 'Gagal memuat stream',
                              style: const TextStyle(color: AppColors.textFaint), textAlign: TextAlign.center),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _episode <= 1 ? null : () => _goToEpisode(_season, _episode - 1),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: Colors.white),
                icon: const Icon(Icons.skip_previous, size: 18),
                label: const Text('Sebelumnya'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _goToEpisode(_season, _episode + 1),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: Colors.white),
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Selanjutnya'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
