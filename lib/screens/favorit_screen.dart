import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import '../responsive.dart';

/// Halaman FAVORIT — daftar judul yang sengaja disimpan pengguna.
///
/// Bedanya dengan Riwayat:
///   Riwayat  — terisi SENDIRI setiap kali menonton, urut waktu tonton.
///   Favorit  — HANYA terisi kalau pengguna menekan tombol favorit di
///              halaman detail, urut waktu disimpan.
///
/// Datanya disimpan di SERVER (lewat /api/favorit), bukan di HP, jadi
/// daftarnya sama di perangkat mana pun setelah masuk.
class FavoritScreen extends StatefulWidget {
  const FavoritScreen({super.key});

  @override
  State<FavoritScreen> createState() => _FavoritScreenState();
}

class _FavoritScreenState extends State<FavoritScreen> {
  List<Map<String, dynamic>> _daftar = const [];
  bool _loading = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _pesan = null;
    });
    try {
      final d = await Api.favoritList(batas: 200);
      if (!mounted) return;
      setState(() {
        _daftar = d;
        _loading = false;
        if (d.isEmpty) _pesan = 'Belum ada judul favorit';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Pesan login dipisahkan supaya pengguna tahu harus masuk dulu,
        // bukan mengira daftarnya rusak.
        final t = e.toString();
        _pesan = t.contains('401') || t.toLowerCase().contains('login')
            ? 'Masuk dulu untuk melihat favorit'
            : 'Gagal memuat favorit';
      });
    }
  }

  void _buka(Map<String, dynamic> x) {
    final id = (x['contentId'] ?? x['tmdbId'] ?? x['id'] ?? '').toString();
    if (id.isEmpty) return;
    final kind = (x['kind'] ?? '').toString();
    // Anime & drakor juga data TV di TMDB, jadi selain 'movie' semuanya
    // memakai layar serial.
    if (kind == 'movie') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: id)));
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: id)));
    }
  }

  /// Konfirmasi lalu bersihkan seluruh favorit.
  Future<void> _bersihkan() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Bersihkan favorit?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Semua judul favorit akan dihapus.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await Api.favoritBersihkan();
      if (!mounted) return;
      setState(() {
        _daftar = const [];
        _pesan = 'Belum ada judul favorit';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('FAVORIT',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_daftar.isNotEmpty)
            IconButton(
              tooltip: 'Bersihkan',
              onPressed: _bersihkan,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_daftar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border_rounded,
                  color: AppColors.textMuted, size: 46),
              const SizedBox(height: 14),
              Text(
                _pesan ?? 'Belum ada judul favorit',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tekan tombol hati di halaman detail film untuk menyimpannya.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          Layout.desktop(context) ? 28 : 14, 6,
          Layout.desktop(context) ? 28 : 14, 120,
        ),
        // Kolom: HP tetap 3; desktop lebih banyak (lewat Layout.kolom).
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Layout.of(context).kolom(3),
          childAspectRatio: 0.52,
          crossAxisSpacing: Layout.desktop(context) ? 16 : 10,
          mainAxisSpacing: Layout.desktop(context) ? 20 : 14,
        ),
        itemCount: _daftar.length,
        itemBuilder: (ctx, i) {
          final x = _daftar[i];
          return PosterCard(
            title: (x['title'] ?? '').toString(),
            imageUrl: Api.imgProxy((x['poster'] ?? '').toString()),
            ratingText: (x['rating'] ?? '').toString(),
            width: double.infinity,
            onTap: () => _buka(x),
          );
        },
      ),
    );
  }
}
