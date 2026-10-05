import 'package:flutter/material.dart';
import '../api/api_client.dart';

import '../widgets/poster_card.dart';
import '../widgets/section_widgets.dart';

/// Bagian beranda yang isinya SATU daftar berisi film, series, anime, dan
/// drakor BERCAMPUR.
///
/// Dipakai dua kali di beranda: "Terbaru" dan "Populer". Sebelumnya
/// beranda memakai section terpisah per jenis (ANIME TERBARU, FILM
/// TRENDING, SERIES TERBARU, ...) sehingga beranda jadi panjang dan satu
/// jenis memakan satu baris penuh.
///
/// Sumbernya SATU permintaan ke /api/beranda/terbaru atau
/// /api/beranda/populer. Backend yang menyelang-seling keempat jenisnya,
/// jadi anime & drakor pasti kebagian tempat di layar pertama.
class BerandaCampurSection extends StatefulWidget {
  /// 'terbaru' atau 'populer'
  final String mode;
  final String title;
  final Color color;

  /// Dipanggil saat sebuah kartu ditekan, dengan data judulnya.
  final void Function(Map<String, dynamic> item)? onTapItem;

  const BerandaCampurSection({
    super.key,
    required this.mode,
    required this.title,
    required this.color,
    this.onTapItem,
  });

  @override
  State<BerandaCampurSection> createState() => _BerandaCampurSectionState();
}

class _BerandaCampurSectionState extends State<BerandaCampurSection> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      // Satu permintaan, empat jenis sudah dicampur backend.
      final d = await Api.get('/api/beranda/${widget.mode}');
      final mentah = bacaDaftar(d);
      final daftar = mentah
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = daftar;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: widget.title, color: widget.color),
        HScrollSection(
          loading: _loading,
          itemCount: _items.length,
          itemBuilder: (ctx, i) {
            final x = _items[i];
            final jenis = (x['jenis'] ?? '').toString();
            return PosterCard(
              title: (x['title'] ?? '').toString(),
              imageUrl: Api.imgProxy((x['poster'] ?? '').toString()),
              badge: _labelJenis(jenis),
              ratingText: (x['rating'] ?? '').toString(),
              placeholderIcon: _ikonJenis(jenis),
              onTap: () => widget.onTapItem?.call(x),
            );
          },
        ),
      ],
    );
  }

  /// Label kecil di kartu supaya pengguna tahu ini film, series, anime,
  /// atau drakor — penting karena keempatnya bercampur dalam satu baris.
  static String? _labelJenis(String jenis) {
    switch (jenis) {
      case 'anime':
        return 'ANIME';
      case 'drakor':
        return 'DRAKOR';
      case 'tv':
        return 'SERIES';
      case 'movie':
        return 'FILM';
      default:
        return null;
    }
  }

  static IconData _ikonJenis(String jenis) {
    switch (jenis) {
      case 'anime':
        return Icons.animation_outlined;
      case 'drakor':
        return Icons.favorite_outline;
      case 'tv':
        return Icons.theaters_outlined;
      default:
        return Icons.movie_outlined;
    }
  }
}

/// Bagian beranda untuk SATU jenis saja (Movies / Series / Drakor / Anime).
///
/// Berbeda dari BerandaCampurSection yang mencampur keempatnya, ini
/// menyaring satu jenis. Dipakai untuk 4 baris jenis di beranda.
class BerandaJenisSection extends StatefulWidget {
  /// movie | tv | anime | drakor
  final String jenis;
  final String title;
  final Color color;
  final void Function(Map<String, dynamic> item)? onTapItem;

  const BerandaJenisSection({
    super.key,
    required this.jenis,
    required this.title,
    required this.color,
    this.onTapItem,
  });

  @override
  State<BerandaJenisSection> createState() => _BerandaJenisSectionState();
}

class _BerandaJenisSectionState extends State<BerandaJenisSection> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      // Alamat rutenya BEDA dari nama jenisnya: jenis 'tv' (istilah
      // TMDB) berpasangan dengan jalur '/api/series/...'. Ini sumber
      // kesalahan yang gampang terjadi, jadi dipetakan di sini.
      const jalur = <String, String>{
        'movie': 'film',
        'tv': 'series',
        'anime': 'anime',
        'drakor': 'drakor',
      };
      final d = await Api.get('/api/${jalur[widget.jenis] ?? 'film'}/populer');
      final daftar = bacaDaftar(d)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = daftar;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: widget.title, color: widget.color),
        HScrollSection(
          loading: _loading,
          itemCount: _items.length,
          itemBuilder: (ctx, i) {
            final x = _items[i];
            return PosterCard(
              title: (x['title'] ?? '').toString(),
              imageUrl: Api.imgProxy((x['poster'] ?? '').toString()),
              ratingText: (x['rating'] ?? '').toString(),
              placeholderIcon: _ikon(widget.jenis),
              onTap: () => widget.onTapItem?.call(x),
            );
          },
        ),
      ],
    );
  }

  static IconData _ikon(String jenis) {
    switch (jenis) {
      case 'anime':
        return Icons.animation_outlined;
      case 'drakor':
        return Icons.favorite_outline;
      case 'tv':
        return Icons.theaters_outlined;
      default:
        return Icons.movie_outlined;
    }
  }
}
