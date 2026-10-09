import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../state/device_id.dart';

/// Ambil daftar dari balasan backend tanpa bergantung pada nama kuncinya.
///
/// Backend mengirim daftar di kunci `hasil`, sementara versi lama aplikasi
/// membaca `results`. Beda nama itu membuat daftar film/series/anime tampil
/// KOSONG walau backend sudah mengirim datanya (galatnya juga ditelan catch,
/// jadi tidak ada pesan apa pun). Helper ini menerima SEMUA nama yang mungkin
/// supaya aplikasi tetap jalan walau backend berganti-ganti nama kunci.
///
/// Urutan pemeriksaan: hasil -> results -> items -> data -> list,
/// ditambah kunci bawaan beranda (trending/top/terbaru).
List<dynamic> daftarDari(dynamic d) {
  if (d == null) return const [];
  if (d is List) return d;
  if (d is! Map) return const [];

  const kunciUtama = ['hasil', 'results', 'items', 'data', 'list', 'daftar'];
  for (final k in kunciUtama) {
    final v = d[k];
    if (v is List) return v;
  }

  // beranda: { trending, top, terbaru } -> gabungkan semuanya
  final gabung = <dynamic>[];
  for (final k in ['trending', 'top', 'terbaru', 'latest', 'popular', 'now_playing']) {
    final v = d[k];
    if (v is List) gabung.addAll(v);
  }
  if (gabung.isNotEmpty) return gabung;

  // kalau ada nilai tunggal (detail), bungkus jadi list satu isi
  for (final k in ['hasil', 'results']) {
    final v = d[k];
    if (v is Map) return [v];
  }
  return const [];
}

/// Ambil daftar penyedia pemutar dari balasan backend.
///
/// Backend (lib/player.js) mengirim field `daftar` berisi semua penyedia
/// embed yang tersedia untuk judul ini — misalnya:
///
///   daftar: [
///     { id: 'vidsrc',   label: 'VidSrc (utama)',     embed: 'https://vidsrc.sbs/embed/movie/550' },
///     { id: 'vidsrc', label: 'VidSrc (utama)', embed: 'https://vidsrc.sbs/embed/movie/550' },
///   ]
///
/// Dipakai layar pemutar untuk menampilkan tombol ganti-server tanpa
/// memanggil backend lagi. Kalau backend versi lama (tanpa `daftar`),
/// hasilnya kosong dan layar memakai 'embed' tunggal seperti sebelumnya.
/// Baca daftar item dari balasan backend, apa pun nama kolomnya.
///
/// Backend yang berbeda memakai nama kunci berbeda untuk hal yang sama:
/// `hasil`, `results`, `items`, `film`. Dulu tiap layar memilih sendiri,
/// sehingga satu layar jalan dan layar lain kosong padahal datanya ada.
/// Fungsi ini menyatukan pembacaannya.
List<dynamic> bacaDaftar(dynamic d) {
  if (d is List) return d;
  if (d is! Map) return const [];
  for (final kunci in const ['hasil', 'results', 'items', 'film', 'data']) {
    final v = d[kunci];
    if (v is List && v.isNotEmpty) return v;
  }
  // Kalau semuanya kosong, kembalikan yang ada (biar jelas "kosong",
  // bukan "salah kunci").
  for (final kunci in const ['hasil', 'results', 'items', 'film', 'data']) {
    final v = d[kunci];
    if (v is List) return v;
  }
  return const [];
}

List<dynamic> daftarPenyediaDari(dynamic d) {
  if (d is! Map) return const [];
  final v = d['daftar'];
  if (v is! List) return const [];
  return v.where((e) {
    if (e is! Map) return false;
    final embed = e['embed']?.toString() ?? '';
    final id = e['id']?.toString() ?? '';
    return id.isNotEmpty && embed.isNotEmpty;
  }).toList();
}

/// Versi peta: ambil satu objek (bukan daftar).
Map<String, dynamic> petaDari(dynamic d) {
  if (d is Map<String, dynamic>) {
    final h = d['hasil'];
    if (h is Map) return Map<String, dynamic>.from(h);
    final r = d['results'];
    if (r is Map) return Map<String, dynamic>.from(r);
    return d;
  }
  if (d is Map) return Map<String, dynamic>.from(d);
  return <String, dynamic>{};
}


/// Base URL backend ISAN. Sama seperti yang dipakai frontend Next.js,
/// tapi di Flutter kita selalu nembak langsung ke domain backend
/// (tidak ada proxy /api/proxy seperti di web).
///
/// PROTEKSI YANG DITERAPKAN DI SINI:
/// 1. Token (access + refresh) disimpan di flutter_secure_storage
///    (Android Keystore), BUKAN shared_preferences -- gak ikut adb backup,
///    gak gampang dibaca walau device di-root pakai cara biasa.
/// 2. Setiap request kirim header X-Device-Id (Device ID Binding) --
///    backend simpen device ID itu di JWT pas login, request berikutnya
///    WAJIB datang dari device yang sama.
/// 3. SSL Pinning -- koneksi HTTPS cuma dipercaya kalau sertifikat server
///    fingerprint-nya cocok dengan yang sudah dipasang manual di sini.
///    Ini nyegah Man-in-the-Middle (misal orang nyoba intercept traffic
///    pakai Charles Proxy / mitmproxy buat ngintip endpoint API).
/// 4. Auto-refresh token: kalau access token (1 jam) expired, otomatis
///    coba refresh pakai refresh token (30 hari) sekali, baru retry
///    request asli -- user gak perlu login ulang tiap 1 jam selama masih
///    aktif & IP/device-nya konsisten.
class Api {
  static const String base = 'https://isanim.web.id';

  static const _kToken = 'isan_token';
  static const _kRefreshToken = 'isan_refresh_token';

  static String? _token;
  static String? _refreshToken;

  static http.Client get _client => _httpClientBiasa;
  static final http.Client _httpClientBiasa = http.Client();

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kToken);
      _refreshToken = prefs.getString(_kRefreshToken);
    } catch (_) {
      _token = null;
      _refreshToken = null;
    }
  }

  static String? get token => _token;

  static Future<void> setTokens({required String token, String? refreshToken}) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token);
      if (refreshToken != null) {
        _refreshToken = refreshToken;
        await prefs.setString(_kRefreshToken, refreshToken);
      }
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kRefreshToken);
    } catch (_) {}
  }

  static String? _cachedAppVersion;

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    try {
      h['X-Device-Id'] = await DeviceId.get();
    } catch (_) {
      h['X-Device-Id'] = 'desktop-linux';
    }
    // WAJIB dikirim -- backend nge-block request mobile yang gak punya
    // header ini sama sekali (itu cara nge-block app versi LAMA yang
    // sudah beredar publik sebelum sistem versioning ini ada, lihat
    // middleware app.use di server.js).
    h['X-App-Version'] = await _appVersion();
    return h;
  }

  static Future<String> _appVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = info.version;
    } catch (_) {
      _cachedAppVersion = '0.0.0';
    }
    return _cachedAppVersion!;
  }

  static Uri _uri(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('$base$path');
    if (params == null || params.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  /// Coba refresh access token pakai refresh token tersimpan. Return true
  /// kalau berhasil (token baru udah ke-set), false kalau gagal (refresh
  /// token juga invalid/habis/IP-device gak match -- user harus login ulang).
  static Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final res = await _client.post(
        _uri('/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Id': await DeviceId.get(),
          'X-App-Version': await _appVersion(),
        },
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      final d = _decode(res);
      if (res.statusCode == 200 && d['token'] != null) {
        await setTokens(token: d['token'], refreshToken: d['refreshToken']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Dipanggil setelah request manapun balas 401 dengan error token_expired.
  /// Kalau refresh sukses, request ASLI di-retry sekali pakai token baru.
  /// Kalau refresh gagal, token lokal dibersihkan -- AuthState bakal
  /// menganggap user logout (lihat auth_state.dart).
  static Future<http.Response> _withAutoRefresh(Future<http.Response> Function() doRequest) async {
    var res = await doRequest();
    if (res.statusCode == 401) {
      final body = _decode(res);
      if (body['error'] == 'token_expired') {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          res = await doRequest();
        } else {
          await clearToken();
        }
      }
    }
    return res;
  }

  static Future<dynamic> get(String path, [Map<String, String>? params]) async {
    final res = await _withAutoRefresh(
      () async => _client.get(_uri(path, params), headers: await _headers()),
    );
    return _decode(res);
  }

  static Future<dynamic> post(String path, Object? body) async {
    final res = await _withAutoRefresh(
      () async => _client.post(
        _uri(path),
        headers: await _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  static Future<dynamic> delete(String path, [Object? body]) async {
    final res = await _withAutoRefresh(
      () async => _client.delete(
        _uri(path),
        headers: await _headers(json: true),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _decode(res);
  }

  static Future<dynamic> _patch(String path, Object? body) async {
    final res = await _withAutoRefresh(
      () async => _client.patch(
        _uri(path),
        headers: await _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  static dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return {'error': 'Respons tidak valid dari server'};
    }
  }

  /// Proxy image url lewat backend (untuk gambar movie/series dari sumber luar).
  static String imgProxy(String url, {String? ref}) {
    if (url.isEmpty) return '';
    if (url.startsWith('$base/')) return url;
    final q = ref != null
        ? 'url=${Uri.encodeComponent(url)}&ref=${Uri.encodeComponent(ref)}'
        : 'url=${Uri.encodeComponent(url)}';
    return '$base/api/img-proxy?$q';
  }

  static String streamFullUrl(String proxyUrl) {
    if (proxyUrl.startsWith('http')) return proxyUrl;
    return '$base$proxyUrl';
  }

  static String get bannerUrl => '$base/banner.mp4';

  /// Domain frontend Next.js ISAN (web), dipakai buat layar Movie/Series/Music
  /// yang sekarang main lewat WebView langsung ke web, bukan player native lagi.
  /// Kalau path route di Next.js kalian beda, tinggal ganti di sini aja —
  /// semua pemanggil (movieWebUrl/seriesWebUrl/musicWebUrl) ngikut otomatis.
  static const String webBase = 'https://isanim.web.id';

  /// ⚠️ PENTING — layar pemutar memuat URL APA ADANYA ke WebView native.
  ///
  /// Sebelumnya movieWebUrl() membungkus sumbernya jadi
  ///   https://isanim.web.id/movie?url=<sumber>
  /// padahal sekarang isanim.web.id hanya melayani API (/api/...), TIDAK ada
  /// halaman web di /movie. Akibatnya WebView memuat halaman 404 kosong dan
  /// yang terlihat cuma latar bawaan Android (ikon di sudut kiri atas) —
  /// inilah keluhan "pas player diklik muncul logo Android".
  ///
  /// Jadi sekarang sumber player (mis. https://vidsrc.sbs/embed/movie/550)
  /// dibuka LANGSUNG. Kedua bentuk di bawah menghasilkan URL yang sama supaya
  /// pemanggil lama tidak perlu diubah.
  static String movieWebUrl(String sourceUrl) {
    final s = sourceUrl.trim();
    // Sudah URL lengkap -> pakai langsung.
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    // Selain itu, anggap path relatif ke webBase (perilaku lama kalau
    // memang halaman web-nya sudah ada lagi di kemudian hari).
    return '$webBase/${s.startsWith('/') ? s.substring(1) : s}';
  }

  static String seriesWebUrl(String slug, {int? season, int? episode}) {
    final s = slug.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final q = (season != null && episode != null) ? '?s=$season&e=$episode' : '';
    return '$webBase/series/$slug$q';
  }

  static String musicWebUrl({String? query}) =>
      (query != null && query.trim().isNotEmpty)
          ? '$webBase/music?q=${Uri.encodeComponent(query.trim())}'
          : '$webBase/music';

  static String playlistWebUrl(String id) => '$webBase/playlist/$id';





  // ── Auth ──────────────────────────────────────────────────────────────
  static Future<dynamic> register(String username, String email, String password) =>
      post('/api/auth/register', {'username': username, 'email': email, 'password': password});

  /// Kirim DUA-DUANYA (username & email) supaya cocok dengan backend
  /// apa pun versinya — backend mencari WHERE username = ? OR email = ?.
  static Future<dynamic> login(String usernameAtauEmail, String password) =>
      post('/api/auth/login', {
        'username': usernameAtauEmail,
        'email': usernameAtauEmail,
        'password': password,
      });

  static Future<dynamic> logout() => post('/api/auth/logout', {});

  static Future<dynamic> me() => get('/api/auth/me');

  // ── Anime ─────────────────────────────────────────────────────────────
  static Future<dynamic> animeList({int page = 1, int limit = 24, String q = ''}) =>
      get('/api/anime/list', {'page': '$page', 'limit': '$limit', 'q': q});

  static Future<dynamic> animeSearch(String q, {int limit = 24}) =>
      get('/api/anime/search', {'q': q, 'limit': '$limit'});

  static Future<dynamic> animePostersBatch(List<String> urls) =>
      post('/api/anime/posters', {'urls': urls});

  /// Backend baru minta ?slug= (bukan ?url=).
  /// Terima URL penuh atau slug langsung — ambil slug terakhir dari URL.
  static Future<dynamic> animeDetail(String urlAtauSlug) {
    final slug = _ambilSlug(urlAtauSlug);
    return get('/api/anime/detail', {'slug': slug});
  }

  /// Ambil slug dari URL otakudesu: .../anime/borot-sub-indo/ -> borot-sub-indo
  static String _ambilSlug(String urlAtauSlug) {
    final t = urlAtauSlug.trim();
    if (!t.contains('/')) return t;
    final bersih = t.replaceAll(RegExp(r'/+\$'), '');
    final bagian = bersih.split('/').where((x) => x.isNotEmpty).toList();
    return bagian.isEmpty ? t : bagian.last;
  }

  /// Jikan TIDAK dipakai di backend baru (data anime sudah lengkap di
  /// otakudesu). Dipetakan ke pencarian anime lokal supaya tetap jalan.
  static Future<dynamic> jikanSearch(String q) =>
      get('/api/anime/search', {'q': q, 'limit': '24'});

  /// Jikan tidak dipakai. Kembalikan data kosong supaya UI tidak error.
  static Future<dynamic> animeJikan(String malId) async => <String, dynamic>{};

  // Endpoint ini WAJIB login di backend (requireAuth) -- panggil
  // AuthGuard.requireLoginOr(context) di sisi UI sebelum manggil ini,
  // biar popup "belum login" muncul dulu daripada nembak API dan
  // ngandelin 401 doang.
  /// Backend baru: /api/anime/episode/:episodeId
  static Future<dynamic> episode(String episodeId) =>
      get('/api/anime/episode/$episodeId');

  static Future<dynamic> resolveServer(String serverId) => post('/api/server/$serverId', {});

  // ── Movie ─────────────────────────────────────────────────────────────
  /// Daftar beranda yang sudah DICAMPUR (film + series + anime + drakor).
  ///
  /// `mode`: 'terbaru' atau 'populer'. Satu permintaan saja untuk satu
  /// baris di beranda — backend yang menyelang-seling keempat jenisnya.
  static Future<dynamic> beranda(String mode) => get('/api/beranda/$mode');

  /// Daftar beranda CAMPUR sekaligus dua mode dalam satu permintaan.
  static Future<dynamic> berandaSemua() => get('/api/beranda');

  /// Katalog satu jenis: populer atau terbaru.
  /// `jenis`: movie | tv | anime | drakor (nama rutenya disesuaikan).
  static Future<dynamic> katalog(String jenis, {String mode = 'populer'}) {
    const jalur = {
      'movie': 'film',
      'tv': 'series',
      'anime': 'anime',
      'drakor': 'drakor',
    };
    return get('/api/${jalur[jenis] ?? 'film'}/$mode');
  }

  static Future<dynamic> movieTrending() => get('/api/movie/trending');

  static Future<dynamic> movieLatest() => get('/api/movie/latest');

  /// Pencarian film.
  ///
  /// `limit` DIHORMATI backend: nilai >20 membuat backend mengambil
  /// beberapa halaman TMDB sekaligus (TMDB sendiri cuma kirim 20 per
  /// halaman, sedangkan "Spider" punya 508 hasil). Sebelumnya `limit`
  /// dikirim tapi diabaikan backend, dan aplikasi memotong lagi jadi 12.
  static Future<dynamic> movieSearch(String q, {int limit = 60, int halaman = 1}) =>
      get('/api/movie/search', {'q': q, 'limit': '$limit', 'halaman': '$halaman'});

  /// Backend baru minta ?id= (TMDB id), bukan ?url=.
  static Future<dynamic> movieDetail(dynamic idAtauUrl) =>
      get('/api/movie/detail', {'id': _ambilId(idAtauUrl)});

  // WAJIB login di backend.
  /// Backend minta ?id=. Balasannya sudah berisi URL embed.
  static Future<dynamic> movieStream(dynamic idAtauUrl) =>
      get('/api/movie/stream', {'id': _ambilId(idAtauUrl)});

  /// Ambil id TMDB dari input apa pun (angka, atau URL yang mengandung angka).
  /// Ambil id numerik TMDB dari nilai apa pun yang dikirim layar.
  /// Layar bisa mengirim id ("550"), URL TMDB, URL web sendiri
  /// ("/movie/550-fight-club"), atau slug. Sebelumnya hanya angka yang
  /// dikenali, sehingga halaman detail film/series dibalas
  /// "tidak ditemukan" walau datanya ada.
  static String _ambilId(dynamic idAtauUrl) {
    if (idAtauUrl == null) return '';
    final t = idAtauUrl.toString().trim();
    if (t.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(t)) return t;
    // ambil deretan angka pertama yang berdiri sendiri
    final m = RegExp(r'(?:^|[/?=&-])(\d{1,9})(?:[/?=&-]|$)').firstMatch(t);
    if (m != null) return m.group(1)!;
    // cari angka di mana saja sebagai usaha terakhir
    final m2 = RegExp(r'(\d{2,9})').firstMatch(t);
    return m2?.group(1) ?? t;
  }

  // ── Music ─────────────────────────────────────────────────────────────
  static Future<dynamic> musicTrending() => get('/api/music/trending');

  static Future<dynamic> musicSearch(String q, {int limit = 24}) =>
      get('/api/music/search', {'q': q, 'limit': '$limit'});

  // ── Series ────────────────────────────────────────────────────────────
  static Future<dynamic> seriesHome() => get('/api/series/home');

  static Future<dynamic> seriesTrending({int page = 1}) =>
      get('/api/series/trending', {'page': '$page'});

  static Future<dynamic> seriesLatest({int page = 1}) =>
      get('/api/series/latest', {'page': '$page'});

  /// Pencarian serial. Lihat catatan pada movieSearch soal `limit`.
  static Future<dynamic> seriesSearch(String q, {int limit = 60, int halaman = 1}) =>
      get('/api/series/search', {'q': q, 'limit': '$limit', 'halaman': '$halaman'});

  // ── Pencarian GABUNGAN ────────────────────────────────────────────────
  //
  // Backend punya SATU rute pencarian lintas jenis:
  //
  //   GET /api/cari?q=<kata>&halaman=<n>&limit=<n>
  //
  // Balasannya:
  //   {
  //     q, halaman,
  //     jumlah: { movie: 60, series: 13, anime: 6, drakor: 1 },
  //     total: 80,
  //     hasil: [
  //       { tmdbId: 37854, kind: 'tv', jenis: 'anime',
  //         title, originalTitle, year, rating, poster, backdrop, overview, ... },
  //       ...
  //     ]
  //   }
  //
  // ⚠️ `jenis` adalah SATU-SATUNYA penanda jenis yang benar. Field `kind`
  // TIDAK bisa dipakai untuk menebak jenis: backend mengirim kind 'tv'
  // untuk series, anime, DAN drakor sekaligus. Versi lama tidak memakai
  // rute ini sama sekali; ia menembak empat rute terpisah lalu menempelkan
  // label jenis dari nama rutenya sendiri. Cara itu salah karena
  // /api/anime/search sebenarnya memakai katalog /discover tv TMDB dengan
  // penyaring genre 16 (animation), dan /api/movie/search TIDAK menyaring
  // genre 16. Akibatnya judul seperti "Spider-Man: Into the Spider-Verse"
  // dan "ONE PIECE FILM RED" (film animasi) ikut terdaftar di
  // /api/anime/search dan ditandai "Anime" — padahal backend menyebutnya
  // movie (jenis: 'movie'). Satu rute /api/cari tidak punya masalah itu:
  // label jenis selalu datang dari backend.
  //
  // `halaman` di rute ini TIDAK seperti halaman biasa. Backend memakai
  // satu halaman TMDB PER JENIS (movie/series) pada setiap nilai halaman,
  // jadi halaman 2 berisi hal. 61..120 untuk movie SEDANGKAN series/dan
  // lainnya kosong. Karena itu layar pencarian selalu memakai halaman 1
  // dan mengambil lebih banyak lewat `limit`.
  static Future<Map<String, dynamic>> searchGabungan(
    String q, {
    int limit = 60,
    int halaman = 1,
  }) async {
    final d = await get('/api/cari', {
      'q': q,
      'halaman': '$halaman',
      'limit': '$limit',
    });

    // Rute ini mengirim beberapa nama kunci sekaligus (hasil/results/
    // items/daftar) yang semuanya berisi daftar yang sama. `daftarDari`
    // menerima semuanya, jadi aplikasi tetap jalan kalau nama kuncinya
    // berubah lagi.
    final hasil = daftarDari(d);

    final peta = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    final jumlah = peta['jumlah'] is Map
        ? Map<String, dynamic>.from(peta['jumlah'] as Map)
        : const <String, dynamic>{};

    // Kelompokkan per `jenis` supaya bentuk balasan lama (yang memisah
    // anime/movie/series/music) tetap terpenuhi untuk pemanggil lain.
    final per = <String, List<dynamic>>{
      'movie': <dynamic>[],
      'series': <dynamic>[],
      'anime': <dynamic>[],
      'drakor': <dynamic>[],
    };
    for (final e in hasil) {
      if (e is! Map) continue;
      final jenis = (e['jenis'] ?? e['type'] ?? '').toString().trim();
      final keranjang = per[jenis];
      if (keranjang != null) keranjang.add(e);
    }

    return {
      'q': q,
      'halaman': peta['halaman'] ?? halaman,
      'total': peta['total'] ?? hasil.length,
      'jumlah': jumlah,
      // `hasil`: daftar gabungan berurutan dari backend — inilah yang
      // dibaca layar pencarian supaya urutannya persis seperti backend.
      'hasil': hasil,
      'anime': per['anime']!,
      'movie': per['movie']!,
      'series': per['series']!,
      'drakor': per['drakor']!,
    };
  }

  static Future<dynamic> seriesDetail(String slug) => get('/api/series/detail/$slug');

  // WAJIB login di backend.
  static Future<dynamic> seriesStream(String slug, dynamic season, dynamic episode) =>
      get('/api/series/stream/$slug/$season/$episode');

  /// AMBIL DAFTAR EPISODE SATU MUSIM.
  ///
  /// Backend tidak menyertakan daftar episode di /api/series/detail;
  /// di sana 'seasons' hanya berisi {season, nama, episode(jumlah),
  /// tahun, poster}. Daftar episode yang sebenarnya ada di
  ///     GET /api/series/:id/season/:nomor
  /// yang mengembalikan [{episode, nama, sinopsis, masih(poster),
  /// rating, tayang, durasi}, ...].
  ///
  /// id di sini boleh id TMDB ("1399") ATAU slug ("game-of-thrones").
  static Future<dynamic> seriesSeason(dynamic id, int nomorMusim) =>
      get('/api/series/$id/season/$nomorMusim');

  // ── Playlist ──────────────────────────────────────────────────────────
  static Future<dynamic> playlistGetAll() => get('/api/playlist');

  static Future<dynamic> playlistGetById(String id) => get('/api/playlist/$id');

  static Future<dynamic> playlistCreate(String name) => post('/api/playlist', {'name': name});

  static Future<dynamic> playlistRename(String id, String name) =>
      _patch('/api/playlist/$id', {'name': name});

  static Future<dynamic> playlistDelete(String id) => delete('/api/playlist/$id');

  static Future<dynamic> playlistAddSong(String playlistId, Song song) =>
      post('/api/playlist/$playlistId/songs', {'song': song.toJson()});

  static Future<dynamic> playlistRemoveSong(String playlistId, String videoId) =>
      delete('/api/playlist/$playlistId/songs/$videoId');

  // ── App version (force update) ──────────────────────────────────────────
  static Future<dynamic> appVersion() => get('/api/app/version');

  // ── App integrity / anti-tamper ─────────────────────────────────────────
  static Future<dynamic> appIntegrity(String sig) => get('/api/app/integrity', {'sig': sig});

  // ── Global chat / broadcast dari developer ──────────────────────────────
  static Future<dynamic> broadcastLatest({int? since}) =>
      get('/api/broadcast/latest', since != null ? {'since': '$since'} : null);

  // ── FCM push notification token ──────────────────────────────────────────
  static Future<dynamic> registerFcmToken(String token) =>
      post('/api/fcm/register', {'token': token});

  // ── Genre endpoints ────────────────────────────────────────────────────
  static Future<dynamic> movieGenre(String genre, {int page = 1}) =>
      get('/api/movie/genre/$genre', {'page': '$page'});

  static Future<dynamic> seriesGenre(String genre, {int page = 1, int limit = 30}) =>
      get('/api/series/genre/$genre', {'page': '$page', 'limit': '$limit'});

  static Future<dynamic> animeGenre(String genre, {int page = 1}) =>
      get('/api/anime/genre/$genre', {'page': '$page'});

  // ── Komentar film ─────────────────────────────────────────────────────
  static Future<dynamic> komentarList(String contentId, {int page = 1}) =>
      get('/api/komentar/$contentId', {'page': '$page'});
  static Future<dynamic> komentarPost(String contentId, String teks) =>
      post('/api/komentar/$contentId', {'teks': teks});

  // ── Rekomendasi serupa ───────────────────────────────────────────────
  static Future<dynamic> rekomendasiMovie(String genre, {String? excludeUrl}) =>
      get('/api/movie/rekomendasi', {'genre': genre, if (excludeUrl != null) 'exclude': excludeUrl});
  static Future<dynamic> rekomendasiSeries(String genre) =>
      get('/api/series/rekomendasi', {'genre': genre});
  static Future<dynamic> rekomendasiAnime(String genre) =>
      get('/api/anime/rekomendasi', {'genre': genre});

  // ── Riwayat tontonan ────────────────────────────────────────────────────
  static Future<dynamic> saveHistory({
    required String type, // 'movie' | 'series' | 'anime'
    required String contentId,
    String? title,
    String? poster,
    required int position, // detik terakhir ditonton
    int? duration,
    int? season,
    int? episode,
    String? episodeId,
    int? episodeNumber,
    String? server, // khusus anime: label provider (mis. "Mega")
  }) =>
      post('/api/history', {
        // `kind` adalah nama field yang DIBACA backend.
        // `type` dulu ikut dikirim untuk kompatibilitas, tapi backend
        // mengabaikannya — itulah sebabnya jenis konten tidak pernah
        // tersimpan dengan benar (series & anime tercatat sebagai
        // 'movie'). Sekarang keduanya dikirim.
        'kind': type,
        'type': type,
        'contentId': contentId,
        'title': title,
        'poster': poster,
        'position': position,
        'duration': duration,
        'season': season,
        'episode': episode,
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'server': server,
      });

  static Future<dynamic> historyList({int limit = 20}) =>
      // Backend membaca `batas`, bukan `limit`. Keduanya dikirim supaya
      // batasnya benar-benar diterapkan, apa pun versi backendnya.
      get('/api/history', {'limit': '$limit', 'batas': '$limit'});

  static Future<dynamic> historyDelete(String historyId) =>
      delete('/api/history/$historyId');

  static Future<dynamic> historyClear() => delete('/api/history');

  // ── Favorit ─────────────────────────────────────────────────────────────
  //
  // Favorit DISIMPAN DI SERVER (bukan di HP), jadi daftar yang sama muncul
  // di perangkat mana pun setelah pengguna masuk. Rutenya butuh login.

  /// Daftar favorit pengguna.
  ///
  /// Balasan backend menyediakan banyak padanan kunci
  /// (favorit/favorite/favorites/hasil/results/items); pakai `bacaDaftar`
  /// supaya tidak bergantung pada satu nama saja.
  static Future<List<Map<String, dynamic>>> favoritList({int batas = 100}) async {
    final d = await get('/api/favorit', {'batas': '$batas'});
    return bacaDaftar(d)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Tambah ATAU hapus favorit.
  ///
  /// Server memakai satu rute yang sama untuk dua arah: kalau judulnya
  /// sudah ada, permintaan ini MENGHAPUSNYA. Balasan berisi
  /// `{ favorit: true|false }` yang menyebut keadaan barunya.
  static Future<bool> favoritToggle({
    required String contentId,
    required String kind, // 'movie' | 'tv'
    String? jenis, // 'movie' | 'series' | 'anime' | 'drakor'
    String? title,
    String? poster,
    String? tahun,
    String? rating,
  }) async {
    final d = await post('/api/favorit', {
      'contentId': contentId,
      'kind': kind,
      'jenis': jenis,
      'title': title,
      'poster': poster,
      'tahun': tahun,
      'rating': rating,
    });
    if (d is Map) return d['favorit'] == true;
    return false;
  }

  /// Cek apakah satu judul sudah ada di favorit.
  ///
  /// Dipakai halaman detail untuk menentukan tombol favorit tampil
  /// terisi atau kosong saat halaman dibuka.
  static Future<bool> favoritCek(String contentId, String kind) async {
    try {
      final daftar = await favoritList(batas: 300);
      return daftar.any((x) =>
          x['contentId']?.toString() == contentId &&
          (x['kind']?.toString() ?? '') == kind);
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> favoritHapus(String id) => delete('/api/favorit/$id');

  static Future<dynamic> favoritBersihkan() => delete('/api/favorit');
}

