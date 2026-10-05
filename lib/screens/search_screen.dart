import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/music_player_state.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/music_card.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import '../responsive.dart';

/// Satu baris hasil pencarian, apa pun jenis kontennya.
///
/// Dulu hasil dipecah jadi beberapa `List<_SearchResult>` + satu daftar
/// `Song` terpisah, lalu ditampilkan sebagai blok "ANIME", "FILM",
/// "SERIES", "MUSIK". Sekarang SEMUA jenis memakai satu tipe item ini
/// sehingga bisa ditampilkan dalam SATU daftar gabungan yang urut
/// berdasarkan peringkat relevansi dari backend.
class _HasilCari {
  /// movie | series | anime | drakor — DIAMBIL DARI FIELD `jenis` backend.
  ///
  /// ⚠️ JANGAN menebak jenis dari field `kind` (backend mengirim 'tv'
  /// untuk series, anime, dan drakor sekaligus) dan JANGAN menebaknya
  /// dari nama rute pencarian. Lihat penjelasan panjang di
  /// `Api.searchGabungan`, lib/api/api_client.dart.
  final String jenis;

  final String judul;
  final String? gambar;

  /// Nilai yang dipakai halaman DETAIL — isinya tergantung jenis:
  ///
  ///   * `movie`  -> id TMDB (angka), mis. "557"
  ///   * `series` -> id TMDB (angka), mis. "1399"
  ///   * `anime`  -> id TMDB (angka), mis. "99618"
  ///
  /// Backend `/api/cari` mengirim `tmdbId` untuk ketiganya (TIDAK ADA
  /// `url` atau `slug` sama sekali), jadi id inilah yang harus diteruskan.
  final String? tautan;

  /// Hanya terisi kalau backend benar-benar mengirim data musik
  /// (rute /api/cari saat ini belum mengirim jenis 'music').
  final Song? lagu;

  const _HasilCari({
    required this.jenis,
    required this.judul,
    this.gambar,
    this.tautan,
    this.lagu,
  });
}

const Map<String, Color> _jenisWarna = {
  'anime': AppColors.red,
  'movie': AppColors.purple,
  'series': Color(0xFFF97316),
  // Drakor: teal, satu-satunya jenis yang belum punya warna di AppColors.
  'drakor': Color(0xFF14B8A6),
  'music': AppColors.blue,
};

const Map<String, String> _jenisLabel = {
  'anime': 'Anime',
  'movie': 'Film',
  'series': 'Series',
  'drakor': 'Drakor',
  'music': 'Musik',
};

const Map<String, IconData> _jenisIkon = {
  'anime': Icons.animation,
  'movie': Icons.movie_outlined,
  'series': Icons.live_tv_outlined,
  'drakor': Icons.video_library_outlined,
  'music': Icons.music_note_outlined,
};

const String _seriesBase = 'https://tv4.nontondrama.my';

/// Berapa banyak hasil yang diminta sekali ambil.
///
/// Backend `/api/cari` menghormati `limit` per jenis (movie & series
/// diambil dari beberapa halaman TMDB sekaligus), jadi 60 di sini berarti
/// sampai 60 film + 60 serial + semua anime/drakor yang cocok.
const int _kSearchLimit = 60;

/// Urutan prioritas jenis saat mengurutkan hasil gabungan.
///
/// Backend mengirim skor relevansi, tapi tidak semua sumber memakainya,
/// jadi pengurutan dilakukan di sisi aplikasi: dalam satu jenis, judul
/// yang paling cocok dengan kata kunci (prefix > mengandung > lainnya)
/// naik ke atas. `_prioritasJenis` jadi kunci kedua supaya anime/film/
/// series/musik yang sama-sama cocok tidak saling mengacak.
const Map<String, int> _prioritasJenis = {
  'anime': 0,
  'movie': 1,
  'series': 2,
  'drakor': 3,
  'music': 4,
};

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  /// Dipakai untuk membuang hasil dari pencarian yang sudah kedaluwarsa.
  ///
  /// Tanpa ini, mengetik cepat bisa membuat respons lambat dari kata kunci
  /// lama menimpa hasil kata kunci terbaru.
  int _generasi = 0;

  bool _loading = false;
  String _kataKunciTerakhir = '';

  /// SATU daftar gabungan — bukan lagi dikelompokkan per jenis.
  List<_HasilCari> _hasil = [];
  List<Song> _antreanMusik = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      _generasi++;
      setState(() {
        _hasil = [];
        _antreanMusik = [];
        _loading = false;
        _kataKunciTerakhir = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _cari(q));
  }

  /// Satu panggilan ke `Api.searchGabungan` (rute `/api/cari`) — bukan lagi
  /// empat permintaan terpisah yang masing-masing ditampilkan di blok sendiri.
  ///
  /// Yang penting di sini: JENIS setiap baris diambil apa adanya dari field
  /// `jenis` balasan backend. Tidak ada lagi tebakan "hasil dari
  /// /api/anime/search berarti anime" — tebakan itulah yang membuat film
  /// animasi seperti "Spider-Man: Into the Spider-Verse" salah ditandai
  /// Anime padahal backend menyebutnya movie.
  Future<void> _cari(String q) async {
    final generasi = ++_generasi;
    setState(() => _loading = true);

    Map<String, dynamic> data = const {};
    try {
      data = await Api.searchGabungan(q, limit: _kSearchLimit);
    } catch (_) {
      data = const {};
    }

    final gabungan = <_HasilCari>[];
    final musik = <Song>[];

    // Daftar gabungan berurutan dari backend. Kalau (karena versi backend
    // lama) kunci itu tidak ada, susun ulang dari empat keranjang supaya
    // hasil tetap tampil — urutannya tetap mengikuti `jenis` backend.
    var entri = (data['hasil'] as List?) ?? const [];
    if (entri.isEmpty) {
      for (final jenis in const ['anime', 'movie', 'series', 'drakor', 'music']) {
        final l = data[jenis];
        if (l is List) entri = [...entri, ...l];
      }
    }

    for (final e in entri) {
      if (e is! Map) continue;

      // (A) JENIS: pakai field `jenis` dari backend.
      final jenis = _jenisDari(e);

      // Jenis yang tidak dikenal tetap ditampilkan (labelnya memakai teks
      // `jenis` mentah), bukan dibuang diam-diam.
      final judul = _judul(e);
      if (jenis == 'music') {
        final s = Song.fromJson(Map<String, dynamic>.from(e));
        if (s.videoId.isEmpty && s.title.isEmpty) continue;
        musik.add(s);
        gabungan.add(_HasilCari(
          jenis: 'music',
          judul: s.title.isNotEmpty ? s.title : judul,
          gambar: s.thumbnailUrl.isEmpty ? null : s.thumbnailUrl,
          lagu: s,
        ));
        continue;
      }

      if (judul.isEmpty) continue;
      gabungan.add(_HasilCari(
        jenis: jenis,
        judul: judul,
        tautan: _tautan(e, jenis),
        gambar: _gambar(e),
      ));
    }

    gabungan.sort((a, b) => _banding(a, b, q));

    // Buang kalau sudah ada kata kunci yang lebih baru.
    if (!mounted || generasi != _generasi) return;
    setState(() {
      _hasil = gabungan;
      _antreanMusik = musik;
      _kataKunciTerakhir = q;
      _loading = false;
    });
  }

  /// (A) Jenis konten — SELALU dari field `jenis` yang dikirim backend.
  ///
  /// Backend `/api/cari` mengirim `jenis` bernilai salah satu dari
  /// 'movie' | 'series' | 'anime' | 'drakor'. Field `kind` TIDAK dipakai
  /// sebagai sumber utama karena isinya 'tv' untuk series, anime, dan
  /// drakor sekaligus — menebak dari sana akan mengembalikan bug lama
  /// (anime/series tertukar). `kind` hanya dipakai sebagai cadangan
  /// terakhir kalau `jenis` benar-benar tidak ada.
  static String _jenisDari(Map e) {
    final mentah = (e['jenis'] ?? '').toString().trim().toLowerCase();
    if (mentah.isNotEmpty && mentah != 'null') {
      return _samakanJenis(mentah);
    }
    final kind = (e['kind'] ?? e['mediaType'] ?? e['tipe'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    // 'tv' ambigu (series / anime / drakor). Pakai 'series' sebagai
    // cadangan yang paling umum, TIDAK PERNAH 'anime'.
    if (kind == 'movie' || kind == 'film') return 'movie';
    if (kind == 'tv' || kind == 'series' || kind == 'serial') return 'series';
    return 'lainnya';
  }

  /// Samakan penulisan nama jenis ke bentuk yang dipakai aplikasi.
  ///
  /// Backend bisa menulis 'movie'/'film', 'series'/'serial'/'tv',
  /// 'anime', 'drakor'/'drama-korea'/'korea'. Semuanya dipetakan ke satu
  /// bentuk supaya label, ikon, dan halaman tujuan tidak salah pilih.
  static String _samakanJenis(String j) {
    switch (j) {
      case 'movie':
      case 'film':
      case 'movies':
        return 'movie';
      case 'series':
      case 'serial':
      case 'tv':
      case 'tvshow':
      case 'tv_show':
        return 'series';
      case 'anime':
        return 'anime';
      case 'drakor':
      case 'drama':
      case 'drama-korea':
      case 'drama_korea':
      case 'korea':
        return 'drakor';
      case 'music':
      case 'musik':
      case 'song':
      case 'lagu':
        return 'music';
      default:
        return j;
    }
  }

  /// Skor relevansi judul terhadap kata kunci (kecil = lebih relevan).
  static int _skorJudul(String judul, String q) {
    final j = judul.toLowerCase().trim();
    final k = q.toLowerCase().trim();
    if (k.isEmpty) return 1;
    if (j == k) return 0;
    if (j.startsWith(k)) return 1;
    if (j.contains(k)) return 2;
    return 3;
  }

  static int _banding(_HasilCari a, _HasilCari b, String q) {
    final sa = _skorJudul(a.judul, q);
    final sb = _skorJudul(b.judul, q);
    if (sa != sb) return sa.compareTo(sb);

    final pa = _prioritasJenis[a.jenis] ?? 99;
    final pb = _prioritasJenis[b.jenis] ?? 99;
    if (pa != pb) return pa.compareTo(pb);

    return a.judul.toLowerCase().compareTo(b.judul.toLowerCase());
  }

  static String _judul(Map j) {
    for (final k in ['title', 'judul', 'name', 'nama', 'trackName']) {
      final v = j[k];
      if (v != null) {
        final t = v.toString().trim();
        if (t.isNotEmpty && t != 'null') return t;
      }
    }
    return '';
  }

  /// (B) Nilai id untuk membuka halaman DETAIL.
  ///
  /// Backend `/api/cari` mengirim `tmdbId` (angka) untuk movie, series,
  /// anime, DAN drakor — tidak ada `url` maupun `slug`. Urutan kunci di
  /// bawah menaruh `tmdbId` lebih dulu supaya id yang dipakai pasti id
  /// TMDB yang benar, bukan kunci lain yang kebetulan ada.
  ///
  /// `jenis` ikut dipakai untuk memastikan hanya kunci yang masuk akal
  /// yang dibaca: untuk series/drakor, `slug` masih diterima karena rute
  /// detail serial menerima slug ATAU id; untuk anime, rute detail tidak
  /// menerima slug sama sekali sehingga `slug` sengaja dilewati.
  static String? _tautan(Map j, String jenis) {
    final kunci = <String>['tmdbId', 'tmdb_id', 'contentId', 'id'];
    if (jenis == 'series' || jenis == 'drakor') {
      kunci.addAll(['slug', 'url']);
    } else if (jenis == 'anime') {
      kunci.add('url');
    } else {
      kunci.addAll(['url', 'slug']);
    }
    for (final k in kunci) {
      final v = j[k];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return null;
  }

  /// Ambil alamat gambar. Backend mengirim 'poster'; sebagian rute 'image'.
  static String? _gambar(Map j) {
    for (final k in ['poster', 'image', 'posterUrl', 'poster_url', 'gambar', 'thumbnail']) {
      final v = j[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// URL gambar siap pakai.
  ///
  /// Poster `/api/cari` sudah berupa URL utuh dari TMDB (lewat image CDN),
  /// jadi anime/drakor dibuka langsung. Film & serial dilewatkan proxy
  /// backend supaya tetap tampil walau CDN-nya tidak bisa diakses langsung
  /// dari jaringan pengguna.
  String? _urlGambar(_HasilCari r) {
    final g = r.gambar;
    if (g == null || g.isEmpty) return null;
    switch (r.jenis) {
      case 'movie':
        return Api.imgProxy(g);
      case 'series':
        return Api.imgProxy(g, ref: _seriesBase);
      default:
        return g;
    }
  }

  /// (B) Buka halaman detail sesuai jenis.
  ///
  /// Setiap jenis punya rute detail sendiri dan semuanya BUTUH id berbeda:
  ///
  ///   * movie  -> MovieDetailScreen(url: id)    -> Api.movieDetail(id)
  ///   * series -> SeriesDetailScreen(slug: id)  -> Api.seriesDetail(id)
  ///   * anime  -> SeriesDetailScreen(slug: id)  -> Api.seriesDetail(id)
  ///
  /// Anime dari `/api/cari` adalah serial TV TMDB (backend memberi
  /// `jenis: 'anime'` untuk serial dengan genre 16). Rute detailnya sama
  /// dengan serial, jadi AnimeDetailScreen TIDAK dipakai di sini: layar
  /// itu memanggil /api/anime/detail yang di backend baru sudah tidak ada
  /// ("Rute tidak ditemukan") sehingga halaman detail anime gagal dibuka.
  void _buka(_HasilCari r) {
    final t = r.tautan;
    if (t == null || t.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_jenisLabel[r.jenis] ?? r.jenis} ini tidak punya id untuk dibuka')),
      );
      return;
    }
    final id = t.trim();
    switch (r.jenis) {
      case 'movie':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailScreen(url: id)),
        );
        break;
      case 'series':
      case 'drakor':
      case 'anime':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: id)),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jenis "${r.jenis}" belum punya halaman detail')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerState>();
    final kosong = _hasil.isEmpty;

    return AppBackground(
      image: AppBg.main,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: _onChanged,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari film, series, anime, atau drakor...',
                hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search, color: AppColors.textFaint, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textFaint, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.red))
            : kosong
                ? Center(
                    child: Text(
                      _ctrl.text.trim().isEmpty ? 'Mulai ketik untuk mencari' : 'Tidak ada hasil',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : _daftarGabungan(player),
      ),
    );
  }

  /// SATU daftar ratar tanpa judul kelompok: anime, film, series, dan
  /// musik bercampur mengikuti relevansi, hanya dibedakan lewat lencana
  /// kecil di tiap baris.
  Widget _daftarGabungan(MusicPlayerState player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 6, Layout.desktop(context) ? 28 : 16, 0),
          child: Text(
            '${_hasil.length} hasil untuk "$_kataKunciTerakhir"',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 12, 8, Layout.desktop(context) ? 28 : 12, 20),
            itemCount: _hasil.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = _hasil[i];
              if (r.jenis == 'music' && r.lagu != null) {
                return _kartuMusik(r, player);
              }
              return _kartuKonten(r);
            },
          ),
        ),
      ],
    );
  }

  /// Baris untuk anime / film / series — satu gaya seragam, jenisnya
  /// ditandai lencana kecil di kanan judul.
  Widget _kartuKonten(_HasilCari r) {
    final warna = _jenisWarna[r.jenis] ?? AppColors.red;
    final gambar = _urlGambar(r);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _buka(r),
        child: Padding(
          padding: EdgeInsets.all(Layout.desktop(context) ? 16 : 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.surfaceAlt,
                  child: gambar != null
                      ? Image.network(
                          gambar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            _jenisIkon[r.jenis] ?? Icons.image_outlined,
                            color: AppColors.border,
                            size: 18,
                          ),
                        )
                      : Icon(
                          _jenisIkon[r.jenis] ?? Icons.image_outlined,
                          color: AppColors.border,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    _lencana(r.jenis, warna),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Baris musik: tetap bisa diputar langsung + tombol tambah ke playlist.
  Widget _kartuMusik(_HasilCari r, MusicPlayerState player) {
    final s = r.lagu!;
    final warna = _jenisWarna['music']!;
    final isActive = player.current?.videoId == s.videoId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: _lencana('music', warna),
        ),
        MusicCard(
          layout: MusicCardLayout.list,
          title: s.title,
          artist: s.artist,
          imageUrl: s.thumbnailUrl,
          isActive: isActive,
          isPlaying: isActive && player.isPlaying,
          song: s,
          showAddButton: true,
          onTap: () {
            if (isActive) {
              player.togglePlaying();
            } else {
              player.play(s, queue: _antreanMusik);
            }
          },
        ),
      ],
    );
  }

  Widget _lencana(String jenis, Color warna) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_jenisIkon[jenis] ?? Icons.circle, size: 10, color: warna),
          const SizedBox(width: 4),
          Text(
            _jenisLabel[jenis] ?? jenis,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: warna),
          ),
        ],
      ),
    );
  }
}
