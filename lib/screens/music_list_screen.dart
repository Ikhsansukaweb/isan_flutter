import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/music_player_state.dart';
import '../theme.dart';
import '../widgets/music_card.dart';
import '../responsive.dart';

/// Page Musik. Saat TIDAK lagi cari (lagi nampilin trending): 12 kartu
/// pertama ditampilin sebagai grid kotak 3 kolom, SISANYA di bawah grid
/// itu ditampilin sebagai list panjang (baris horizontal, kayak daftar
/// lagu biasa). Saat user lagi nyari (ada query): SEMUA hasil pencarian
/// ditampilin sebagai list panjang, gak ada grid kotak sama sekali.
///
/// Tap kartu/baris = play langsung lewat MusicPlayerState (mini player
/// nempel di bawah), BUKAN pindah halaman. Tombol + di tiap kartu buka
/// AddToPlaylistSheet.
class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  static const int _gridCount = 12;

  List<Song> _items = [];
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _failed = false;
  final String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final d = _query.trim().isEmpty
          ? await Api.musicTrending()
          : await Api.musicSearch(_query.trim());
      if (d is Map && d['error'] != null) throw Exception(d['error']);
      final items = daftarDari(d)
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
        // Backend balikin results: [] tanpa error eksplisit kalau sumber
        // musiknya (muse/YouTube Music) gagal — tetap kita anggap gagal
        // biar kelihatan "Gagal memuat", bukan diam-diam kosong.
        _failed = items.isEmpty;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _failed = true;
        _items = [];
      });
    }
  }

  void _play(Song s) {
    context.read<MusicPlayerState>().play(s, queue: _items);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerState>();
    final isSearching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Musik', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _failed ? Icons.cloud_off_rounded : Icons.search_off_rounded,
                              size: 40,
                              color: AppColors.textFaint,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _failed
                                  ? 'Gagal memuat data musik dari server.'
                                  : 'Tidak ada hasil untuk "$_query"',
                              style: const TextStyle(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                            if (_failed) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Coba lagi'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : isSearching
                        ? _buildAllList(player)
                        : _buildGridPlusList(player),
          ),
        ],
      ),
    );
  }

  /// Saat ada query pencarian: SEMUA hasil jadi list panjang.
  Widget _buildAllList(MusicPlayerState player) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      itemCount: _items.length,
      itemBuilder: (ctx, i) => _listRow(_items[i], player),
    );
  }

  /// Saat trending (gak ada query): 12 kartu pertama jadi grid kotak,
  /// sisanya di bawah grid itu jadi list panjang.
  Widget _buildGridPlusList(MusicPlayerState player) {
    final gridItems = _items.take(_gridCount).toList();
    final restItems = _items.skip(_gridCount).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Kolom: HP tetap 3; desktop lebih banyak (lewat Layout.kolom).
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Layout.of(context).kolom(3),
            mainAxisSpacing: 16,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemCount: gridItems.length,
          itemBuilder: (ctx, i) => _gridCard(gridItems[i], player),
        ),
        if (restItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'LEBIH BANYAK',
            style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          ...restItems.map((s) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: _listRow(s, player),
              )),
        ],
      ],
    );
  }

  Widget _gridCard(Song s, MusicPlayerState player) {
    final isActive = player.current?.videoId == s.videoId;
    return MusicCard(
      title: s.title,
      artist: s.artist,
      imageUrl: s.thumbnailUrl,
      width: double.infinity,
      isActive: isActive,
      isPlaying: isActive && player.isPlaying,
      song: s,
      showAddButton: true,
      onTap: () {
        if (isActive) {
          player.togglePlaying();
        } else {
          _play(s);
        }
      },
    );
  }

  Widget _listRow(Song s, MusicPlayerState player) {
    final isActive = player.current?.videoId == s.videoId;
    return MusicCard(
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
          _play(s);
        }
      },
    );
  }
}
