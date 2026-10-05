import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/music_player_state.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/music_card.dart';
import '../responsive.dart';

/// Detail playlist — diambil LANGSUNG dari API (GET /api/playlist/:id →
/// { playlist: { ..., songs: [...] } }) dan dirender native sebagai LIST
/// PANJANG (bukan grid kotak) pakai MusicCard layout list. Tap baris =
/// play langsung lewat MusicPlayerState (mini player di bawah). Tombol
/// minus di tiap baris buat hapus lagu dari playlist ini.
///
/// PERUBAHAN: header sekarang lebih detail — cover 2x2 grid besar (160x160),
/// nama playlist, username, jumlah lagu, total durasi, dan tombol Putar Semua
/// + Shuffle.
class PlaylistDetailScreen extends StatefulWidget {
  final String id;
  final String title;
  const PlaylistDetailScreen({super.key, required this.id, this.title = 'Playlist'});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _loading = true;
  String? _error;
  String _name = '';
  String _username = '';
  List<Song> _songs = [];
  bool _shuffleMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Api.playlistGetById(widget.id);
      if (d is Map && d['error'] != null) throw Exception(d['error']);
      final pl = Map<String, dynamic>.from(d['playlist'] ?? d);
      // Backend mengirim lagu dengan kunci 'hasil'/'results'/'items'.
      // Sebelumnya hanya 'songs' dibaca, sehingga playlist yang sudah
      // berisi lagu tetap tampil kosong di aplikasi.
      final songsRaw = (pl['songs'] as List?)
          ?? (pl['hasil'] as List?)
          ?? (pl['results'] as List?)
          ?? (pl['items'] as List?)
          ?? daftarDari(d);
      if (d is Map && d['name'] != null) _name = d['name'].toString();
      setState(() {
        _name = (pl['name'] ?? widget.title).toString();
        _username = (pl['username'] ?? '').toString();
        _songs = songsRaw.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat playlist.';
        _loading = false;
      });
    }
  }

  void _play(Song s) {
    context.read<MusicPlayerState>().play(s, queue: _songs);
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    if (_shuffleMode) {
      final shuffled = List<Song>.from(_songs)..shuffle();
      context.read<MusicPlayerState>().play(shuffled.first, queue: shuffled);
    } else {
      context.read<MusicPlayerState>().play(_songs.first, queue: _songs);
    }
  }

  Future<void> _removeSong(Song s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Lagu?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('"${s.title}" akan dihapus dari playlist ini.', style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _songs.removeWhere((x) => x.videoId == s.videoId));
    // Backend menghapus dengan WHERE id = ? AND playlist_id = ?,
    // jadi yang dikirim harus KOLOM id (angka), bukan videoId.
    // Kalau id tidak ada (mis. balasan lama), baru pakai videoId.
    final d = await Api.playlistRemoveSong(widget.id, s.id.isNotEmpty ? s.id : s.videoId);
    if (d['error'] != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['error'].toString())));
      _load();
    }
  }

  String _formatTotalDuration() {
    final total = _songs.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h > 0) return '${h}j ${m}m';
    return '$m menit';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerState>();
    return AppBackground(
      image: AppBg.main,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.red))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textMuted)))
                : CustomScrollView(
                    slivers: [
                      // ── AppBar polos (banner besar dihapus) ──
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        pinned: true,
                        elevation: 0,
                        title: Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),

                      // ── Info playlist ringkas (cover kecil + nama + jumlah lagu) ──
                      SliverToBoxAdapter(
                        child: _PlaylistCompactHeader(
                          name: _name,
                          username: _username,
                          songs: _songs,
                          totalDuration: _songs.isEmpty ? '' : _formatTotalDuration(),
                        ),
                      ),

                      // ── Tombol aksi (Putar Semua + Shuffle) ──
                      if (_songs.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 16, Layout.desktop(context) ? 28 : 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _playAll,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                    label: const Text('Putar Semua', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => setState(() => _shuffleMode = !_shuffleMode),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _shuffleMode ? AppColors.red.withValues(alpha: 0.15) : AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _shuffleMode ? AppColors.red : AppColors.border,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.shuffle_rounded,
                                      color: _shuffleMode ? AppColors.red : AppColors.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Daftar lagu ──
                      _songs.isEmpty
                          ? const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: Center(
                                  child: Text('Playlist ini masih kosong.',
                                      style: TextStyle(color: AppColors.textMuted)),
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 24 : 12, 8, Layout.desktop(context) ? 24 : 12, 100),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final s = _songs[i];
                                    final isActive = player.current?.videoId == s.videoId;
                                    return MusicCard(
                                      layout: MusicCardLayout.list,
                                      title: s.title,
                                      artist: s.artist,
                                      imageUrl: s.thumbnailUrl,
                                      isActive: isActive,
                                      isPlaying: isActive && player.isPlaying,
                                      onRemove: () => _removeSong(s),
                                      onTap: () {
                                        if (isActive) {
                                          player.togglePlaying();
                                        } else {
                                          _play(s);
                                        }
                                      },
                                    );
                                  },
                                  childCount: _songs.length,
                                ),
                              ),
                            ),
                    ],
                  ),
      ),
      ),
    );
  }
}

/// Hero header playlist — cover 2x2 grid besar, nama, username, info.
class _PlaylistCompactHeader extends StatelessWidget {
  final String name;
  final String username;
  final List<Song> songs;
  final String totalDuration;

  const _PlaylistCompactHeader({
    required this.name,
    required this.username,
    required this.songs,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cover kecil (1 gambar saja, bukan banner besar)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: songs.isNotEmpty && songs.first.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: songs.first.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: const Icon(Icons.music_note, color: AppColors.border, size: 18)),
                      placeholder: (_, __) => Container(color: AppColors.surfaceAlt),
                    )
                  : Container(color: AppColors.surfaceAlt, child: const Icon(Icons.music_note, color: AppColors.border, size: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (username.isNotEmpty)
                  Text(username, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.library_music_outlined, color: AppColors.textFaint, size: 12),
                  const SizedBox(width: 4),
                  Text('${songs.length} lagu', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  if (totalDuration.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.access_time, color: AppColors.textFaint, size: 12),
                    const SizedBox(width: 4),
                    Text(totalDuration, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
