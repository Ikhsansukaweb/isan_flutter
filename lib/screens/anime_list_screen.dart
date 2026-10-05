import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/anime.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_widgets.dart';
import 'anime_detail_screen.dart';
import '../responsive.dart';

class AnimeListScreen extends StatefulWidget {
  const AnimeListScreen({super.key});
  @override
  State<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends State<AnimeListScreen> {
  static const _genres = [
    {'slug': '',              'label': 'Terbaru'},
    {'slug': 'action',       'label': 'Action'},
    {'slug': 'adventure',    'label': 'Adventure'},
    {'slug': 'comedy',       'label': 'Komedi'},
    {'slug': 'drama',        'label': 'Drama'},
    {'slug': 'fantasy',      'label': 'Fantasy'},
    {'slug': 'horror',       'label': 'Horor'},
    {'slug': 'romance',      'label': 'Romance'},
    {'slug': 'school',       'label': 'School'},
    {'slug': 'sci-fi',       'label': 'Sci-Fi'},
    {'slug': 'slice-of-life','label': 'Slice of Life'},
    {'slug': 'supernatural', 'label': 'Supernatural'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Anime', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 24, left: Layout.desktop(context) ? 12 : 0, right: Layout.desktop(context) ? 12 : 0),
        itemCount: _genres.length,
        itemBuilder: (ctx, idx) {
          final g = _genres[idx];
          return _AnimeGenreRow(genre: g['slug']!, title: g['label']!);
        },
      ),
    );
  }
}

// ── Satu baris genre (scroll horizontal), dipakai berulang seperti di home page ──
class _AnimeGenreRow extends StatefulWidget {
  final String genre;
  final String title;
  const _AnimeGenreRow({required this.genre, required this.title});
  @override
  State<_AnimeGenreRow> createState() => _AnimeGenreRowState();
}

class _AnimeGenreRowState extends State<_AnimeGenreRow> {
  List<AnimeItem> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = widget.genre.isEmpty
          ? await Api.animeList(page: 1, limit: 12)
          : await Api.animeGenre(widget.genre);
      // Backend mengirim judul + poster langsung dari halaman genre,
      // jadi tidak perlu dipotong-potong: ambil 15 supaya baris terisi penuh.
      var parsed = daftarDari(d)
          .map((e) => AnimeItem.fromJson(Map<String, dynamic>.from(e)))
          .take(15).toList();
      if (mounted) setState(() { _items = parsed; _loading = false; });

      // Lengkapi poster yang masih kosong.
      // Sebelumnya bagian ini HANYA dijalankan untuk baris "Terbaru",
      // padahal halaman genre otakudesu sering tidak memuat gambar.
      final belumAda = parsed.where((a) => a.poster == null || a.poster!.isEmpty);
      if (belumAda.isNotEmpty) {
        final urls = belumAda.map((a) => a.url).where((u) => u.isNotEmpty).toList();
        if (urls.isNotEmpty) {
          try {
            final r = await Api.animePostersBatch(urls);
            final posters = Map<String, dynamic>.from(r['posters'] ?? {});
            if (posters.isNotEmpty && mounted) {
              setState(() {
                for (var i = 0; i < _items.length; i++) {
                  final a = _items[i];
                  if ((a.poster == null || a.poster!.isEmpty) && posters.containsKey(a.url)) {
                    _items[i] = a.copyWith(poster: posters[a.url]);
                  }
                }
              });
            }
          } catch (_) {
            // rute /api/anime/posters mungkin belum ada di backend;
            // poster dari backend sudah cukup, jadi jangan ditampilkan
            // sebagai kegagalan.
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: widget.title.toUpperCase(), color: AppColors.red),
        HScrollSection(
          loading: _loading,
          itemCount: _items.length,
          itemBuilder: (ctx, i) {
            final a = _items[i];
            return PosterCard(
              title: a.title,
              imageUrl: a.poster,
              placeholderIcon: Icons.live_tv_outlined,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AnimeDetailScreen(url: a.url))),
            );
          },
        ),
      ]),
    );
  }
}
