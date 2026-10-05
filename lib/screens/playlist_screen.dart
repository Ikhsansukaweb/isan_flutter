import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_client.dart';
import '../theme.dart';
import 'playlist_detail_screen.dart';
import '../responsive.dart';

/// Daftar playlist — parsing response disesuaikan dengan backend asli:
/// GET /api/playlist mengembalikan { playlists: [{ id, name, userId,
/// username, songs: [...] }] }.
///
/// Cover playlist ditampilin sebagai grid 2x2 dari 4 thumbnail lagu
/// pertama di playlist itu (kayak cover playlist Spotify/YouTube Music).
/// Kalau lagunya kurang dari 4, slot yang kosong diisi placeholder icon.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final d = await Api.playlistGetAll();
      if (d is Map && d['error'] != null) throw Exception(d['error']);
      // Jangan bergantung nama kunci: backend bisa mengirim 'hasil',
      // 'results', 'playlists', dsb. daftarDari() menerima semuanya.
      // Ambil dari kunci mana pun yang berisi data. Kalau 'playlists'
      // ada tapi kosong sementara 'hasil' berisi, yang dipakai 'hasil'.
      List<dynamic> list;
      if (d is List) {
        list = d;
      } else {
        final kandidat = <List<dynamic>>[
          if (d['playlists'] is List) d['playlists'] as List<dynamic>,
          if (d['hasil'] is List) d['hasil'] as List<dynamic>,
          if (d['results'] is List) d['results'] as List<dynamic>,
          if (d['items'] is List) d['items'] as List<dynamic>,
        ];
        list = kandidat.firstWhere((x) => x.isNotEmpty, orElse: () => daftarDari(d));
      }
      setState(() {
        _items = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat playlist.';
        _loading = false;
      });
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Playlist Baru', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nama playlist',
            hintStyle: const TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final d = await Api.playlistCreate(name);
    if (d['error'] != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['error'].toString())));
      return;
    }
    _load();
  }

  Future<void> _deletePlaylist(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Playlist?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Playlist "$name" akan dihapus permanen.', style: const TextStyle(color: AppColors.textMuted)),
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

    final d = await Api.playlistDelete(id);
    if (d['error'] != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['error'].toString())));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Playlist Saya', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        backgroundColor: AppColors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.red))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textMuted)))
                : _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text('Belum ada playlist tersimpan.\nKetuk + untuk membuat baru.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 16, 16, 100),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final p = _items[i];
                          final name = (p['name'] ?? p['title'] ?? 'Playlist').toString();
                          // Backend mengirim songs/lagu + songCount/jumlahLagu di daftar
                          // playlist. Sebelumnya hanya 'songs' yang dibaca, padahal
                          // daftar tidak pernah memuatnya -> selalu tertulis "0 lagu".
                          final songs = ((p['songs'] ?? p['lagu'] ?? p['items'] ?? p['hasil']) is List)
                              ? ((p['songs'] ?? p['lagu'] ?? p['items'] ?? p['hasil']) as List)
                              : const [];
                          final jumlahLagu = (p['songCount'] ?? p['jumlahLagu'] ?? p['totalSongs'] ?? songs.length);
                          final username = (p['username'] ?? '').toString();
                          final id = (p['id'] ?? p['_id'] ?? '').toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              onTap: id.isEmpty
                                  ? null
                                  : () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => PlaylistDetailScreen(id: id, title: name))).then((_) => _load()),
                              leading: _PlaylistCover(songs: songs),
                              title: Text(name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                username.isNotEmpty ? '$jumlahLagu lagu · $username' : '$jumlahLagu lagu',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppColors.textFaint, size: 20),
                                color: AppColors.surfaceAlt,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onSelected: (v) {
                                  if (v == 'delete') _deletePlaylist(id, name);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                                        SizedBox(width: 8),
                                        Text('Hapus Playlist', style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Cover playlist 2x2 grid dari 4 thumbnail lagu pertama (kayak cover
/// playlist Spotify/YouTube Music). Slot kosong (playlist < 4 lagu) diisi
/// placeholder icon musik.
class _PlaylistCover extends StatelessWidget {
  final List songs;
  const _PlaylistCover({required this.songs});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 52,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
          itemCount: 4,
          itemBuilder: (ctx, i) {
            final url = i < songs.length ? (songs[i]['thumbnailUrl']?.toString() ?? '') : '';
            return Container(
              color: AppColors.surfaceAlt,
              child: url.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: AppColors.border, size: 12),
                      placeholder: (_, __) => const SizedBox.shrink(),
                    )
                  : const Icon(Icons.music_note, color: AppColors.border, size: 12),
            );
          },
        ),
      ),
    );
  }
}
