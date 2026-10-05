import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/music_player_state.dart';
import '../theme.dart';
import '../responsive.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  List<Song> _songs = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = _query.trim().isEmpty
          ? await Api.musicTrending()
          : await Api.musicSearch(_query.trim());
      final items = daftarDari(d)
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _songs = items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _play(Song s) {
    context.read<MusicPlayerState>().play(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Musik', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 4, Layout.desktop(context) ? 28 : 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _query = v;
                _load();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari lagu...',
                hintStyle: const TextStyle(color: AppColors.textFaint),
                prefixIcon: const Icon(Icons.search, color: AppColors.textFaint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _songs.length,
                    itemBuilder: (ctx, i) {
                      final s = _songs[i];
                      return ListTile(
                        onTap: () => _play(s),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            s.thumbnailUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: AppColors.surfaceAlt,
                              child: const Icon(Icons.music_note, color: AppColors.border),
                            ),
                          ),
                        ),
                        title: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(s.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted)),
                        trailing: const Icon(Icons.play_circle_fill, color: AppColors.red, size: 30),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
