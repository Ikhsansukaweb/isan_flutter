import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_widgets.dart';
import 'movie_detail_screen.dart';
import '../responsive.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});
  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _genres = [
    {'slug': '',            'label': 'Terbaru'},
    {'slug': 'action',     'label': 'Action'},
    {'slug': 'adventure',  'label': 'Adventure'},
    {'slug': 'animation',  'label': 'Animasi'},
    {'slug': 'comedy',     'label': 'Komedi'},
    {'slug': 'drama',      'label': 'Drama'},
    {'slug': 'fantasy',    'label': 'Fantasy'},
    {'slug': 'horror',     'label': 'Horor'},
    {'slug': 'romance',    'label': 'Romance'},
    {'slug': 'sci-fi',     'label': 'Sci-Fi'},
    {'slug': 'thriller',   'label': 'Thriller'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Film', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 24, left: Layout.desktop(context) ? 12 : 0, right: Layout.desktop(context) ? 12 : 0),
        itemCount: _genres.length,
        itemBuilder: (ctx, idx) {
          final g = _genres[idx];
          return _MovieGenreRow(genre: g['slug']!, title: g['label']!);
        },
      ),
    );
  }
}

// ── Satu baris genre (scroll horizontal), dipakai berulang seperti di home page ──
class _MovieGenreRow extends StatefulWidget {
  final String genre;
  final String title;
  const _MovieGenreRow({required this.genre, required this.title});
  @override
  State<_MovieGenreRow> createState() => _MovieGenreRowState();
}

class _MovieGenreRowState extends State<_MovieGenreRow> {
  List<MovieItem> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = widget.genre.isEmpty
          ? await Api.movieLatest()
          : await Api.movieGenre(widget.genre);
      final parsed = daftarDari(d)
          .map((e) => MovieItem.fromJson(Map<String, dynamic>.from(e)))
          .take(12).toList();
      if (mounted) setState(() { _items = parsed; _loading = false; });
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
        SectionHeader(title: widget.title.toUpperCase(), color: AppColors.purple),
        HScrollSection(
          loading: _loading,
          itemCount: _items.length,
          itemBuilder: (ctx, i) {
            final m = _items[i];
            return PosterCard(
              title: m.title,
              imageUrl: Api.imgProxy(m.image),
              badge: m.quality,
              placeholderIcon: Icons.movie_outlined,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MovieDetailScreen(url: m.url))),
            );
          },
        ),
      ]),
    );
  }
}
