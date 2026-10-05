import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../api/api_client.dart';
import '../models/anime.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/auth_guard.dart';

// ── Widget komentar ─────────────────────────────────────────────────────────
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
class _RekomendasiAnime extends StatefulWidget {
  final String genre;
  final String excludeUrl;
  const _RekomendasiAnime({required this.genre, required this.excludeUrl});
  @override
  State<_RekomendasiAnime> createState() => _RekomendasiAnimeState();
}
class _RekomendasiAnimeState extends State<_RekomendasiAnime> {
  List<AnimeItem> _items = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await Api.rekomendasiAnime(widget.genre);
      final list = daftarDari(d)
          .map((e) => AnimeItem.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.url != widget.excludeUrl)
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
          final a = _items[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnimeDetailScreen(url: a.url))),
            child: SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 150, width: 110,
                child: (a.poster != null && a.poster!.isNotEmpty)
                    ? Image.network(a.poster!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt))
                    : Container(color: AppColors.surfaceAlt, child: const Icon(Icons.live_tv_outlined, color: AppColors.border)),
              )),
              const SizedBox(height: 5),
              Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ])),
          );
        },
      )),
    ]);
  }
}

// ── Server dropdown untuk anime ─────────────────────────────────────────────
class _ServerInfo { final String serverId, provider, resolution;
  _ServerInfo({required this.serverId, required this.provider, required this.resolution});
  // Backend mengirim {nama, resolusi, url} sedangkan aplikasi membaca
  // {serverId, provider, resolution}. Tanpa padanan ini semua nilai jadi
  // kosong sehingga daftar server tidak pernah muncul.
  factory _ServerInfo.fromJson(Map<String, dynamic> j) => _ServerInfo(
    serverId: (j['serverId'] ?? j['id'] ?? j['url'] ?? j['nama'] ?? '').toString(),
    provider: (j['provider'] ?? j['nama'] ?? j['server'] ?? '').toString(),
    resolution: (j['resolution'] ?? j['resolusi'] ?? j['kualitas'] ?? '').toString(),
  );
}
const Map<String, String> _provLabel = {
  'mega': 'Mega', 'vidhide': 'VidHide', 'filedon': 'FileDon',
  'ondesu3': 'OnDesu', 'ondesuhd': 'OnDesuHD', 'otakuwatch': 'OtakuWatch',
};
String _prov(String p) => _provLabel[p.toLowerCase()] ?? (p.isNotEmpty ? p[0].toUpperCase() + p.substring(1) : 'Server');

// ══════════════════════════════════════════════════════════════════════════════
// AnimeDetailScreen — player inline, episode scroll horizontal, komentar, rekomendasi
// ══════════════════════════════════════════════════════════════════════════════
class AnimeDetailScreen extends StatefulWidget {
  final String url;
  final String? resumeEpisodeId; // dari riwayat: lanjut ke episode ini
  final String? resumeServer;    // dari riwayat: provider server terakhir (mis. "Mega")
  const AnimeDetailScreen({super.key, required this.url, this.resumeEpisodeId, this.resumeServer});
  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  AnimeOtakuDetail? _otaku;
  AnimeJikanDetail? _jikan;
  bool _loadingOtaku = true;
  bool _loadingJikan = false;
  String? _error;

  // Player state
  late final WebViewController _webCtrl;
  bool _loadingServers = false;
  bool _loadingStream = false;
  String _streamUrl = '';
  List<_ServerInfo> _servers = [];
  _ServerInfo? _activeServer;
  String? _activeEpId;
  int _activeEpIdx = 0;  // index episode aktif

  // ── Riwayat tontonan: anime pakai server pihak ketiga (embed iframe), jadi
  // gak bisa baca currentTime video secara akurat lewat JS injection kayak di
  // movie/series. Sebagai gantinya, posisi diestimasi dari lama waktu nonton
  // (stopwatch berjalan) sejak stream berhasil dimuat.
  final Stopwatch _watchStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);
    final platform = _webCtrl.platform;
    if (platform is AndroidWebViewController) {
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, callback) {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(backgroundColor: Colors.black, body: widget),
            fullscreenDialog: true,
          ));
        },
        onHideCustomWidget: () { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); },
      );
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.animeDetail(widget.url);
      if (d['error'] != null) throw Exception(d['error']);
      final otaku = AnimeOtakuDetail.fromJson(Map<String, dynamic>.from(d));
      setState(() { _otaku = otaku; _loadingOtaku = false; });
      // Auto-play episode 1 (episodes sudah urut ascending dari API: index 0 = episode 1)
      // Kecuali kalau dibuka dari Riwayat Tontonan -- lanjut ke episode terakhir ditonton.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (otaku.episodes.isEmpty) return;
        if (widget.resumeEpisodeId != null) {
          final idx = otaku.episodes.indexWhere((e) => e.episodeId == widget.resumeEpisodeId);
          if (idx != -1) {
            _loadEpisode(otaku.episodes[idx], idx, preferServerProvider: widget.resumeServer);
            return;
          }
        }
        _loadEpisode(otaku.episodes.first, 0);
      });
      // Jikan untuk info tambahan
      if (otaku.title.isNotEmpty) {
        setState(() => _loadingJikan = true);
        try {
          final jSearch = await Api.jikanSearch(otaku.title);
          final malId = jSearch['data']?[0]?['mal_id'];
          if (malId != null) {
            final full = await Api.animeJikan(malId.toString());
            if (full['error'] == null) setState(() => _jikan = AnimeJikanDetail.fromJson(Map<String, dynamic>.from(full)));
          }
        } catch (_) {}
        setState(() => _loadingJikan = false);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loadingOtaku = false; });
    }
  }

  // Simpan riwayat episode yang sedang aktif (estimasi posisi dari stopwatch)
  // sebelum pindah ke episode lain atau saat keluar halaman.
  void _saveCurrentProgress() {
    final otaku = _otaku;
    if (otaku == null || _activeEpId == null) return;
    _watchStopwatch.stop();
    final elapsedSec = _watchStopwatch.elapsed.inSeconds;
    _watchStopwatch.reset();
    if (elapsedSec < 3) return;
    final epNumber = _activeEpIdx + 1; // urut ascending, indeks 0 = episode 1
    final title = _jikan?.title.isNotEmpty == true ? _jikan!.title : otaku.title;
    final poster = _jikan?.poster ?? otaku.poster;
    Api.saveHistory(
      type: 'anime',
      contentId: widget.url,
      title: title,
      poster: poster,
      position: elapsedSec,
      episodeId: _activeEpId,
      episodeNumber: epNumber,
      server: _activeServer?.provider,
    );
  }

  Future<void> _loadEpisode(AnimeEpisodeRef ep, int idx, {String? preferServerProvider}) async {
    if (!AuthGuard.requireLoginOr(context)) return;
    // Catat dulu progres episode sebelumnya sebelum pindah.
    _saveCurrentProgress();
    setState(() {
      _activeEpId = ep.episodeId;
      _activeEpIdx = idx;
      _loadingServers = true;
      _streamUrl = '';
      _servers = [];
      _activeServer = null;
    });
    try {
      final d = await Api.episode(ep.episodeId);
      if (d['error'] != null) { setState(() => _loadingServers = false); return; }
      // backend mengirim kunci 'server' (tunggal), bukan 'servers'
      final serversMentah = (d['servers'] as List?) ?? (d['server'] as List?) ?? (d['items'] as List?) ?? [];
      final servers = serversMentah
          .map((e) => _ServerInfo.fromJson(Map<String, dynamic>.from(e))).toList();
      setState(() { _servers = servers; _loadingServers = false; });
      // Kalau lagi resume dari riwayat & ada server yang sama providernya, pakai itu.
      String? useId;
      if (preferServerProvider != null) {
        final match = servers.where((s) => s.provider == preferServerProvider);
        if (match.isNotEmpty) useId = match.first.serverId;
      }
      if (useId == null) {
        final bestId = d['bestServerId']?.toString();
        useId = (bestId != null && bestId.isNotEmpty) ? bestId : (servers.isNotEmpty ? servers.first.serverId : null);
      }
      if (useId != null) _playServer(useId);
    } catch (_) { setState(() => _loadingServers = false); }
  }

  Future<void> _playServer(String serverId) async {
    setState(() { _loadingStream = true; });
    try {
      final d = await Api.resolveServer(serverId);
      if (d['error'] != null) { setState(() => _loadingStream = false); return; }
      final url = d['url']?.toString() ?? '';
      if (url.isEmpty) { setState(() => _loadingStream = false); return; }
      final srv = _servers.firstWhere((s) => s.serverId == serverId, orElse: () => _servers.first);
      setState(() { _streamUrl = url; _activeServer = srv; _loadingStream = false; });
      _webCtrl.loadRequest(Uri.parse(url));
      // Mulai hitung waktu tonton dari sini (estimasi posisi tontonan).
      _watchStopwatch
        ..reset()
        ..start();
    } catch (_) { setState(() => _loadingStream = false); }
  }

  @override
  void dispose() {
    _saveCurrentProgress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOtaku) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.red)));
    }
    if (_error != null || _otaku == null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg),
        body: Center(child: Text(_error ?? 'Gagal memuat', style: const TextStyle(color: AppColors.textMuted))));
    }

    final otaku = _otaku!;
    final poster = _jikan?.poster ?? otaku.poster;
    final title = _jikan?.title.isNotEmpty == true ? _jikan!.title : otaku.title;
    final synopsis = _jikan?.synopsis ?? otaku.synopsis ?? '';
    final score = _jikan?.score;
    final genres = (_jikan?.genres.isNotEmpty == true) ? _jikan!.genres : [];
    final genreStr = genres.isNotEmpty ? genres.join(', ') : (otaku.info['genre']?.toString() ?? '');
    final studio = _jikan?.studio ?? otaku.info['studio']?.toString() ?? '';
    final status = _jikan?.status ?? otaku.info['status']?.toString() ?? '';
    final episodes = otaku.episodes; // urut ascending: index 0 = episode 1
    final contentId = widget.url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final firstGenre = genres.isNotEmpty ? genres.first.toString().toLowerCase() : 'action';

    return AppBackground(
      image: AppBg.main,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.transparent,
            pinned: true,
            elevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ── Info header ──
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 100, height: 150,
                  child: (poster != null && poster.isNotEmpty)
                      ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt))
                      : Container(color: AppColors.surfaceAlt, child: const Icon(Icons.live_tv_outlined, color: AppColors.border)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (score != null) _chip('★ ${score.toStringAsFixed(1)}', AppColors.gold),
                    if (status.isNotEmpty) _chip(status, AppColors.textMuted),
                    if (studio.isNotEmpty) _chip(studio, AppColors.textMuted),
                  ]),
                  if (genreStr.isNotEmpty) ...[const SizedBox(height: 6),
                    Text(genreStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5))],
                ])),
              ]),
              if (synopsis.isNotEmpty) ...[const SizedBox(height: 12),
                Text(synopsis, maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.45))],

              const SizedBox(height: 20),

              // ── Player inline ──
              AspectRatio(aspectRatio: 16 / 9, child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(color: Colors.black,
                  child: (_loadingServers || _loadingStream)
                      ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                      : _streamUrl.isNotEmpty
                          ? WebViewWidget(controller: _webCtrl)
                          : const Center(child: Icon(Icons.play_circle_outline, color: AppColors.border, size: 50)),
                ),
              )),

              // ── Dropdown server ──
              if (_servers.isNotEmpty) ...[const SizedBox(height: 10),
                Row(children: [
                  const Text('Server:', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    isDense: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    value: _activeServer?.serverId,
                    items: _servers.map((s) => DropdownMenuItem(
                      value: s.serverId,
                      child: Text('${_prov(s.provider)}${s.resolution.isNotEmpty ? ' · ${s.resolution}p' : ''}'),
                    )).toList(),
                    onChanged: (v) { if (v != null) _playServer(v); },
                  ))),
                ]),
              ],

              const SizedBox(height: 20),

              // ── Daftar episode (scroll horizontal) ──
              Row(children: [
                const Text('EPISODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
                if (_loadingJikan) ...[const SizedBox(width: 8), const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red))],
              ]),
              const SizedBox(height: 10),
              if (episodes.isEmpty)
                const Text('Episode belum tersedia', style: TextStyle(color: AppColors.textFaint))
              else
                SizedBox(height: 44, child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final ep = episodes[i];
                    final epNumber = i + 1; // urut ascending, indeks 0 = episode 1
                    final active = _activeEpIdx == i;
                    return GestureDetector(
                      onTap: () => _loadEpisode(ep, i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: active ? AppColors.red : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? AppColors.red : AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text('$epNumber', style: TextStyle(color: active ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ),
                    );
                  },
                )),

              const SizedBox(height: 28),
              // ── Komentar ──
              _KomentarSection(contentId: contentId),

              // ── Rekomendasi ──
              _RekomendasiAnime(genre: firstGenre, excludeUrl: widget.url),
              const SizedBox(height: 24),
            ])),
          ),
        ],
      ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
  );
}
