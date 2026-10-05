import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/api_cache.dart';
import '../models/anime.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/song.dart';
import '../state/music_player_state.dart';
import '../theme.dart';
import '../responsive.dart';
import '../widgets/hero_banner.dart';
import '../widgets/section_widgets.dart';
import '../widgets/beranda_section.dart';
import '../widgets/poster_card.dart';
import '../widgets/music_card.dart';
import 'anime_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import 'anime_list_screen.dart';
import 'movie_list_screen.dart';
import 'series_list_screen.dart';
import 'music_list_screen.dart';
import 'history_screen.dart';

const String _seriesBase = 'https://tv4.nontondrama.my';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Song> _songs = [];
  // Film, series, anime, dan drakor kini dimuat oleh widget
  // sectionnya masing-masing (BerandaCampurSection /
  // BerandaJenisSection), jadi hanya musik yang masih dimuat di sini.
  bool _loadingMusic = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    _loadMusic();
  }

  Future<void> _loadMusic() async {
    try {
      final raw = await ApiCache.fetchRawList(
        key: 'home_music',
        fetcher: () async {
          final d = await Api.musicTrending();
          return daftarDari(d);
        },
        onFresh: (fresh) {
          if (!mounted) return;
          setState(() {
            _songs = fresh.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
          });
        },
      );
      final items = raw.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
      setState(() {
        _songs = items;
        _loadingMusic = false;
      });
    } catch (_) {
      setState(() => _loadingMusic = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingMusic = true;
    });
    await ApiCache.clearAll(); // pull-to-refresh = paksa ambil data baru, bukan cache
    await _loadAll();
  }


  /// Buka halaman detail sesuai JENIS judulnya.
  ///
  /// Beranda mencampur film, series, anime, dan drakor dalam satu baris,
  /// jadi jenisnya HARUS dibaca dari field `jenis` yang dikirim backend —
  /// tidak bisa ditebak dari layar asalnya.
  void _bukaJudul(Map<String, dynamic> x) {
    final jenis = (x['jenis'] ?? 'movie').toString();
    final id = (x['tmdbId'] ?? x['id'] ?? '').toString();
    if (id.isEmpty) return;

    // Film punya layar sendiri. Series, anime, dan drakor SAMA-SAMA
    // memakai layar serial karena ketiganya data TV di TMDB (punya
    // season & episode); bedanya cuma penyaring di backend.
    if (jenis == 'movie') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: id)));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: ListView(
          // Di desktop tepi konten dilebarkan supaya tidak mepet ke pinggir
          // jendela selebar 1280; di HP tetap nol (persis seperti semula).
          padding: EdgeInsets.symmetric(
            horizontal: Layout.desktop(context) ? 8 : 0,
          ),
          children: [
            // Banner: 7 FILM TERBARU, diambil sendiri oleh widgetnya dari
            // backend. `items` sengaja TIDAK dikirim lagi — dulu daftarnya
            // ditulis mati di dalam berkas widget (5 item, gambar aset
            // lokal) sehingga tidak pernah berubah saat ada film baru,
            // dan tap-nya membuka sistem anime lama yang datanya sudah
            // dibuang.
            HeroBannerCarousel(
              onTapItem: (item) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(url: item.url),
                  ),
                );
              },
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            // ── 1. RIWAYAT TONTONAN (section pertama) ──
            const _HistorySection(),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            // ══════════════════════════════════════════════
            //  6 SECTION BERANDA
            //
            //  Dulu ada 12+ section terpisah per jenis (ANIME TERBARU,
            //  FILM TRENDING, SERIES TERBARU, THRILLER, ROMANCE, plus
            //  tujuh section genre acak) sehingga beranda sangat
            //  panjang. Sekarang cukup enam:
            //
            //    1. TERBARU  — film+series+anime+drakor BERCAMPUR
            //    2. POPULER  — film+series+anime+drakor BERCAMPUR
            //    3. MOVIES   — film saja
            //    4. SERIES   — serial saja
            //    5. DRAKOR   — drama Korea saja
            //    6. ANIME    — anime saja
            //
            //  Dua yang pertama sengaja bercampur: maksudnya "apa yang
            //  baru & apa yang sedang ramai" di seluruh katalog, bukan
            //  per jenis. Keempat jenis diselang-seling oleh backend
            //  supaya anime & drakor tetap kebagian tempat di layar
            //  pertama.
            // ══════════════════════════════════════════════

            BerandaCampurSection(
              mode: 'terbaru',
              title: 'TERBARU',
              color: AppColors.red,
              onTapItem: _bukaJudul,
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            BerandaCampurSection(
              mode: 'populer',
              title: 'POPULER',
              color: AppColors.blue,
              onTapItem: _bukaJudul,
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            BerandaJenisSection(
              jenis: 'movie',
              title: 'MOVIES',
              color: AppColors.purple,
              onTapItem: _bukaJudul,
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            BerandaJenisSection(
              jenis: 'tv',
              title: 'SERIES',
              color: AppColors.purple,
              onTapItem: _bukaJudul,
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            BerandaJenisSection(
              jenis: 'drakor',
              title: 'DRAKOR',
              color: const Color(0xFFF97316),
              onTapItem: _bukaJudul,
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            BerandaJenisSection(
              jenis: 'anime',
              title: 'ANIME',
              color: AppColors.red,
              onTapItem: _bukaJudul,
            ),
            SizedBox(height: Layout.desktop(context) ? 30 : 22),

            // ── Musik tetap seperti semula (tidak diubah) ──
            SectionHeader(
              title: 'MUSIK TRENDING',
              color: AppColors.blue,
              onSeeAll: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MusicListScreen())),
            ),
            _MusicRow(songs: _songs, loading: _loadingMusic),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

/// Baris musik horizontal di Beranda — pakai MusicCard (gaya SongCard.tsx
/// di web) dan tap = play LANGSUNG lewat MusicPlayerState (mini player
/// nempel di bawah). Tidak pindah ke page Musik sama sekali.
class _MusicRow extends StatelessWidget {
  final List<Song> songs;
  final bool loading;

  const _MusicRow({required this.songs, required this.loading});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerState>();

    if (!loading && songs.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'Musik trending belum tersedia.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
        ),
      );
    }

    final count = loading ? 8 : (songs.length > 20 ? 20 : songs.length);

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          if (loading) {
            return Container(
              width: 140,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }
          final s = songs[i];
          final isActive = player.current?.videoId == s.videoId;
          return MusicCard(
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
                context.read<MusicPlayerState>().play(s, queue: songs);
              }
            },
          );
        },
      ),
    );
  }
}

/// ── Section Riwayat Tontonan di Beranda ─────────────────────────────────────
/// Nampilin sampai 12 riwayat terakhir (dari GET /api/history), horizontal
/// scroll. Tap = balik ke halaman detail konten yang bersangkutan.
class _HistorySection extends StatefulWidget {
  const _HistorySection();
  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await Api.historyList(limit: 12);
      setState(() {
        _items = ((d['history'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  void _open(Map<String, dynamic> h) {
    final type = h['type']?.toString() ?? '';
    final contentId = h['contentId']?.toString() ?? '';
    final position = (h['position'] as num?)?.toInt();
    if (type == 'movie') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MovieDetailScreen(url: contentId, resumePosition: position)));
    } else if (type == 'series') {
      final season = (h['season'] as num?)?.toInt();
      final episode = (h['episode'] as num?)?.toInt();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
                slug: contentId,
                resumeSeason: season,
                resumeEpisode: episode,
                resumePosition: position,
              )));
    } else if (type == 'anime') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnimeDetailScreen(
                url: contentId,
                resumeEpisodeId: h['episodeId']?.toString(),
                resumeServer: h['server']?.toString(),
              )));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink(); // gak ada riwayat = section disembunyikan

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'RIWAYAT TONTONAN',
          color: AppColors.textMuted,
          onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
        ),
        HScrollSection(
          loading: _loading,
          itemCount: _items.length,
          height: 230,
          itemBuilder: (ctx, i) {
            final h = _items[i];
            final poster = h['poster']?.toString() ?? '';
            final title = h['title']?.toString() ?? '';
            final position = (h['position'] as num?)?.toInt() ?? 0;
            final duration = (h['duration'] as num?)?.toInt() ?? 0;
            final progressPct = duration > 0 ? (position / duration).clamp(0.0, 1.0) : null;
            return GestureDetector(
              onTap: () => _open(h),
              child: SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 130,
                            height: 175,
                            child: poster.isNotEmpty
                                ? Image.network(poster, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt))
                                : Container(color: AppColors.surfaceAlt, child: const Icon(Icons.movie_outlined, color: AppColors.border)),
                          ),
                        ),
                        if (progressPct != null)
                          Positioned(
                            left: 6, right: 6, bottom: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progressPct, minHeight: 4,
                                backgroundColor: Colors.black45,
                                valueColor: const AlwaysStoppedAnimation(AppColors.red),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// ── Section genre acak: Anime ────────────────────────────────────────────────
class _AnimeGenreSection extends StatefulWidget {
  final String genre;
  final String title;
  const _AnimeGenreSection({required this.genre, required this.title});
  @override
  State<_AnimeGenreSection> createState() => _AnimeGenreSectionState();
}
class _AnimeGenreSectionState extends State<_AnimeGenreSection> {
  List<AnimeItem> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await Api.animeGenre(widget.genre);
      setState(() {
        _items = daftarDari(d)
            .map((e) => AnimeItem.fromJson(Map<String, dynamic>.from(e))).take(12).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: widget.title, color: AppColors.red,
        onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnimeListScreen())),
      ),
      HScrollSection(
        loading: _loading, itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final a = _items[i];
          return PosterCard(
            title: a.title, imageUrl: a.poster, placeholderIcon: Icons.live_tv_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnimeDetailScreen(url: a.url))),
          );
        },
      ),
    ]);
  }
}

/// ── Section genre acak: Movie ────────────────────────────────────────────────
class _MovieGenreSection extends StatefulWidget {
  final String genre;
  final String title;
  const _MovieGenreSection({required this.genre, required this.title});
  @override
  State<_MovieGenreSection> createState() => _MovieGenreSectionState();
}
class _MovieGenreSectionState extends State<_MovieGenreSection> {
  List<MovieItem> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await Api.movieGenre(widget.genre);
      setState(() {
        _items = daftarDari(d)
            .map((e) => MovieItem.fromJson(Map<String, dynamic>.from(e))).take(12).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: widget.title, color: AppColors.purple,
        onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MovieListScreen())),
      ),
      HScrollSection(
        loading: _loading, itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final m = _items[i];
          return PosterCard(
            title: m.title, imageUrl: Api.imgProxy(m.image), badge: m.quality,
            placeholderIcon: Icons.movie_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: m.url))),
          );
        },
      ),
    ]);
  }
}

/// ── Section genre acak: Series ───────────────────────────────────────────────
class _SeriesGenreSection extends StatefulWidget {
  final String genre;
  final String title;
  const _SeriesGenreSection({required this.genre, required this.title});
  @override
  State<_SeriesGenreSection> createState() => _SeriesGenreSectionState();
}
class _SeriesGenreSectionState extends State<_SeriesGenreSection> {
  List<SeriesItem> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await Api.seriesGenre(widget.genre, limit: 12);
      setState(() {
        _items = daftarDari(d)
            .map((e) => SeriesItem.fromJson(Map<String, dynamic>.from(e))).take(12).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: widget.title, color: const Color(0xFFF97316),
        onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeriesListScreen())),
      ),
      HScrollSection(
        loading: _loading, itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final s = _items[i];
          return PosterCard(
            title: s.title,
            imageUrl: s.poster != null ? Api.imgProxy(s.poster!, ref: _seriesBase) : null,
            ratingText: s.rating,
            badge: s.totalSeasons != null ? '${s.totalSeasons} Season' : null,
            placeholderIcon: Icons.theaters_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: s.slug))),
          );
        },
      ),
    ]);
  }
}

/// ── Section "Pilihan Teratas" ────────────────────────────────────────────────
/// Tab kategori (Drakor / Series / Movie / Anime / Horor) bisa diklik --
/// isi list di bawahnya ganti sesuai tab yang dipilih, ditampilkan sebagai
/// ranking bernomor (1, 2, 3, ...) kayak referensi "Pilihan Teratas".
class _RankedItem {
  final String title;
  final String? poster;
  final VoidCallback onTap;
  _RankedItem({required this.title, required this.poster, required this.onTap});
}

class _PilihanTeratasSection extends StatefulWidget {
  const _PilihanTeratasSection();
  @override
  State<_PilihanTeratasSection> createState() => _PilihanTeratasSectionState();
}

class _PilihanTeratasSectionState extends State<_PilihanTeratasSection> {
  static const _tabs = ['Drakor', 'Series', 'Movie', 'Anime', 'Horor', 'Thriller', 'Romance'];
  int _activeTab = 0;

  // Cache hasil per tab biar gak fetch ulang tiap ganti tab.
  final Map<int, List<_RankedItem>> _cache = {};
  final Map<int, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    _loadTab(0);
  }

  Future<void> _loadTab(int tabIdx) async {
    if (_cache.containsKey(tabIdx)) return;
    setState(() => _loadingMap[tabIdx] = true);
    try {
      List<_RankedItem> items = [];
      switch (tabIdx) {
        case 0: // Drakor
          final d = await Api.seriesGenre('south-korea', limit: 10);
          items = daftarDari(d).map((e) {
            final s = SeriesItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: s.title,
              poster: s.poster != null ? Api.imgProxy(s.poster!, ref: _seriesBase) : null,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: s.slug))),
            );
          }).toList();
          break;
        case 1: // Series (umum)
          final d = await Api.seriesHome();
          items = daftarDari(d).take(10).map((e) {
            final s = SeriesItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: s.title,
              poster: s.poster != null ? Api.imgProxy(s.poster!, ref: _seriesBase) : null,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: s.slug))),
            );
          }).toList();
          break;
        case 2: // Movie
          final d = await Api.movieTrending();
          items = daftarDari(d).take(10).map((e) {
            final m = MovieItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: m.title,
              poster: Api.imgProxy(m.image),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: m.url))),
            );
          }).toList();
          break;
        case 3: // Anime
          final d = await Api.animeList(page: 1, limit: 10);
          items = daftarDari(d).map((e) {
            final a = AnimeItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: a.title,
              poster: a.poster,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => AnimeDetailScreen(url: a.url))),
            );
          }).toList();
          break;
        case 4: // Horor (movie)
          final d = await Api.movieGenre('horror');
          items = daftarDari(d).take(10).map((e) {
            final m = MovieItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: m.title,
              poster: Api.imgProxy(m.image),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: m.url))),
            );
          }).toList();
          break;
        case 5: // Thriller (movie)
          final d = await Api.movieGenre('thriller');
          items = daftarDari(d).take(10).map((e) {
            final m = MovieItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: m.title,
              poster: Api.imgProxy(m.image),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: m.url))),
            );
          }).toList();
          break;
        case 6: // Romance (series)
          final d = await Api.seriesGenre('romance', limit: 10);
          items = daftarDari(d).map((e) {
            final s = SeriesItem.fromJson(Map<String, dynamic>.from(e));
            return _RankedItem(
              title: s.title,
              poster: s.poster != null ? Api.imgProxy(s.poster!, ref: _seriesBase) : null,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: s.slug))),
            );
          }).toList();
          break;
      }
      if (!mounted) return;
      setState(() { _cache[tabIdx] = items; _loadingMap[tabIdx] = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _cache[tabIdx] = []; _loadingMap[tabIdx] = false; });
    }
  }

  void _selectTab(int i) {
    setState(() => _activeTab = i);
    _loadTab(i);
  }

  @override
  Widget build(BuildContext context) {
    final items = _cache[_activeTab] ?? [];
    final loading = _loadingMap[_activeTab] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('PILIHAN TERATAS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6)),
        ),
        // ── Tab kategori (bisa diklik) ──
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final active = i == _activeTab;
              return GestureDetector(
                onTap: () => _selectTab(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.red : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AppColors.red : AppColors.border),
                  ),
                  child: Text(_tabs[i],
                      style: TextStyle(
                          color: active ? Colors.white : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // ── List ranking bernomor ──
        SizedBox(
          height: 190,
          child: loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => Container(
                    width: 110,
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  ),
                )
              : items.isEmpty
                  ? const Center(child: Text('Belum ada data', style: TextStyle(color: AppColors.textFaint)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final it = items[i];
                        return GestureDetector(
                          onTap: it.onTap,
                          child: SizedBox(
                            width: 110,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 110,
                                        height: 150,
                                        child: (it.poster != null && it.poster!.isNotEmpty)
                                            ? Image.network(it.poster!, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt))
                                            : Container(color: AppColors.surfaceAlt,
                                                child: const Icon(Icons.image_outlined, color: AppColors.border)),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6, left: 6,
                                      child: Container(
                                        width: 22, height: 22,
                                        decoration: BoxDecoration(
                                          color: i < 3 ? AppColors.red : Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text('${i + 1}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
