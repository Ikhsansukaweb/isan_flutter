import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../theme.dart';

/// Bottom sheet "Tambah ke Playlist" -- dipanggil dari tombol + di MusicCard.
/// Nampilin daftar playlist yang ada (bisa add lagu ke situ), plus opsi
/// bikin playlist baru langsung dari sini.
class AddToPlaylistSheet extends StatefulWidget {
  final Song song;
  const AddToPlaylistSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddToPlaylistSheet(song: song),
    );
  }

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _playlists = [];
  final Set<String> _busyIds = {}; // playlist yang sedang proses tambah

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await Api.playlistGetAll();
      // Backend mengirim {hasil:[...], results:[...], items:[...]} dan
      // TIDAK mengirim 'playlists'. Sebelumnya hanya 'playlists' dibaca
      // sehingga daftar playlist selalu kosong dan layar ini menampilkan
      // "Belum ada playlist" walau playlist sudah ada.
      final list = (d is List) ? d : daftarDari(d);
      setState(() {
        _playlists = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addTo(String playlistId, String playlistName) async {
    setState(() => _busyIds.add(playlistId));
    try {
      final d = await Api.playlistAddSong(playlistId, widget.song);
      if (mounted) {
        if (d['error'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(d['error'].toString())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ditambahkan ke "$playlistName"')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menambahkan lagu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(playlistId));
    }
  }

  Future<void> _createAndAdd() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['error'].toString())));
      }
      return;
    }
    // Backend mengembalikan {id, name} TANPA bungkus 'playlist'.
    // Map<String,dynamic>.from(null) melempar exception, sehingga
    // "Buat Playlist Baru" selalu gagal.
    final mentah = (d['playlist'] ?? d['hasil'] ?? d);
    final pl = Map<String, dynamic>.from(mentah is Map ? mentah : {});
    final idBaru = pl['id']?.toString() ?? '';
    final namaBaru = (pl['name'] ?? pl['nama'] ?? name).toString();
    if (idBaru.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist dibuat, tapi id tidak terbaca.')),
        );
      }
      return;
    }
    await _addTo(idBaru, namaBaru);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tambah "${widget.song.title}" ke Playlist',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: _createAndAdd,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceAlt,
                  child: Icon(Icons.add, color: AppColors.red),
                ),
                title: const Text('Buat Playlist Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                    : _playlists.isEmpty
                        ? const Center(
                            child: Text('Belum ada playlist. Buat dulu di atas.',
                                style: TextStyle(color: AppColors.textMuted)),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _playlists.length,
                            itemBuilder: (ctx, i) {
                              final p = _playlists[i];
                              final id = p['id'].toString();
                              final name = (p['name'] ?? 'Playlist').toString();
                              // Daftar playlist tidak memuat 'songs'
                              // (itu ada di /api/playlist/:id), dan backend
                              // memakai 'video_id'. Tanpa padanan ini
                              // subtitle selalu "0 lagu" dan lagu yang sudah
                              // ada bisa ditambahkan berulang.
                              final songs = (p['songs'] ?? p['lagu'] ?? p['hasil'] ?? p['items']) as List? ?? [];
                              final sudahAda = songs.any((s) {
                                final m = s is Map ? s : const {};
                                return (m['videoId'] ?? m['video_id']) == widget.song.videoId;
                              });
                              final jumlahLagu = p['jumlahLagu'] ?? p['songCount'] ?? songs.length;
                              final alreadyIn = sudahAda;
                              final busy = _busyIds.contains(id);
                              return ListTile(
                                onTap: (alreadyIn || busy) ? null : () => _addTo(id, name),
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.surfaceAlt,
                                  child: Icon(Icons.playlist_play, color: AppColors.textMuted),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text('$jumlahLagu lagu', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                trailing: busy
                                    ? const SizedBox(
                                        width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red),
                                      )
                                    : alreadyIn
                                        ? const Icon(Icons.check_circle, color: AppColors.red, size: 20)
                                        : const Icon(Icons.add_circle_outline, color: AppColors.textFaint, size: 20),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
