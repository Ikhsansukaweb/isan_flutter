import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/series.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_widgets.dart';
import 'series_detail_screen.dart';
import '../responsive.dart';

const String _seriesBase = 'https://tv4.nontondrama.my';

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});
  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  static const _genres = [
    {'slug': '',             'label': 'Terbaru'},
    {'slug': 'action',      'label': 'Action'},
    {'slug': 'adventure',   'label': 'Adventure'},
    {'slug': 'comedy',      'label': 'Komedi'},
    {'slug': 'drama',       'label': 'Drama'},
    {'slug': 'fantasy',     'label': 'Fantasy'},
    {'slug': 'horror',      'label': 'Horor'},
    {'slug': 'romance',     'label': 'Romance'},
    {'slug': 'thriller',    'label': 'Thriller'},
    {'slug': 'south-korea', 'label': 'Drakor'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Series', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 24, left: Layout.desktop(context) ? 12 : 0, right: Layout.desktop(context) ? 12 : 0),
        itemCount: _genres.length,
        itemBuilder: (ctx, idx) {
          final g = _genres[idx];
          return _SeriesGenreRow(genre: g['slug']!, title: g['label']!);
        },
      ),
    );
  }
}

// ── Satu baris genre (scroll horizontal), dipakai berulang seperti di home page ──
class _SeriesGenreRow extends StatefulWidget {
  final String genre;
  final String title;
  const _SeriesGenreRow({required this.genre, required this.title});
  @override
  State<_SeriesGenreRow> createState() => _SeriesGenreRowState();
}

class _SeriesGenreRowState extends State<_SeriesGenreRow> {
  List<SeriesItem> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = widget.genre.isEmpty
          ? await Api.seriesLatest(page: 1)
          : await Api.seriesGenre(widget.genre, limit: 12);
      final parsed = daftarDari(d)
          .map((e) => SeriesItem.fromJson(Map<String, dynamic>.from(e)))
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
            final s = _items[i];
            return PosterCard(
              title: s.title,
              imageUrl: s.poster != null ? Api.imgProxy(s.poster!, ref: _seriesBase) : null,
              ratingText: s.rating,
              badge: s.totalSeasons != null ? '${s.totalSeasons} Season' : null,
              placeholderIcon: Icons.theaters_outlined,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: s.slug))),
            );
          },
        ),
      ]),
    );
  }
}
