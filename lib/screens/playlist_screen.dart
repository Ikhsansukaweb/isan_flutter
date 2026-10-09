import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../state/local_playlist_service.dart';
import '../theme.dart';
import 'playlist_detail_screen.dart';
import '../responsive.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await LocalPlaylistService.getPlaylists();
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _importUrlDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: AppColors.red, size: 24),
            SizedBox(width: 8),
            Text('Impor Playlist (YT / Spotify)', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan link playlist YouTube atau Spotify:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://open.spotify.com/playlist/... atau YouTube',
                hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Ambil Lagu'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sedang mengimpor playlist & data lagu...'),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      Map<String, dynamic>? res;
      if (url.contains('spotify.com')) {
        res = await LocalPlaylistService.importSpotifyPlaylist(url);
      } else {
        res = await LocalPlaylistService.importYoutubePlaylist(url);
      }

      if (res != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mengimpor: ${res['name']}')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal impor playlist: $e')),
        );
      }
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Playlist Baru (Offline)', style: TextStyle(color: Colors.white, fontSize: 16)),
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

    await LocalPlaylistService.createPlaylist(name);
    _load();
  }

  Future<void> _deletePlaylist(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Playlist?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Playlist "$name" akan dihapus dari penyimpanan offline.', style: const TextStyle(color: AppColors.textMuted)),
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

    await LocalPlaylistService.deletePlaylist(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Playlist Offline (Linux)', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Impor Playlist YouTube / Spotify',
            icon: const Icon(Icons.link_rounded, color: Colors.white),
            onPressed: _importUrlDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importUrlDialog,
        backgroundColor: AppColors.red,
        icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
        label: const Text('Impor Playlist (YT/Spotify)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.red))
            : _items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.queue_music_rounded, size: 64, color: AppColors.textFaint),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Belum ada playlist offline tersimpan.\nKlik tombol "Impor Playlist" untuk mengambil lagu dari YouTube / Spotify.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          onPressed: _createPlaylist,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Buat Playlist Kosong'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 16, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final p = _items[i];
                      final name = (p['name'] ?? 'Playlist').toString();
                      final songs = (p['songs'] is List) ? (p['songs'] as List) : const [];
                      final jumlahLagu = songs.length;
                      final username = (p['username'] ?? '').toString();
                      final id = (p['id'] ?? '').toString();
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
                                  builder: (_) => PlaylistDetailScreen(
                                    id: id,
                                    title: name,
                                    localSongs: songs.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList(),
                                  ))).then((_) => _load()),
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

class _PlaylistCover extends StatelessWidget {
  final List songs;
  const _PlaylistCover({required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.music_note, color: AppColors.border, size: 24),
      );
    }

    final thumbs = songs
        .map((s) => (s is Map ? (s['thumbnailUrl'] ?? s['thumb'] ?? '') : '').toString())
        .where((t) => t.isNotEmpty)
        .take(4)
        .toList();

    if (thumbs.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: thumbs[0],
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: AppColors.surfaceAlt),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 50,
        height: 50,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: 4,
          itemBuilder: (ctx, i) {
            if (i < thumbs.length) {
              return CachedNetworkImage(
                imageUrl: thumbs[i],
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppColors.surfaceAlt),
              );
            }
            return Container(color: AppColors.surfaceAlt);
          },
        ),
      ),
    );
  }
}
