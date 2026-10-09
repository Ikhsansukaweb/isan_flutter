import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/local_playlist_service.dart';
import '../state/music_player_state.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/music_card.dart';
import '../responsive.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String id;
  final String title;
  final List<Song>? localSongs;

  const PlaylistDetailScreen({
    super.key,
    required this.id,
    this.title = 'Playlist',
    this.localSongs,
  });

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

    if (widget.id.startsWith('local_') || widget.localSongs != null) {
      final list = await LocalPlaylistService.getPlaylists();
      final current = list.firstWhere((e) => e['id'] == widget.id, orElse: () => {});
      if (current.isNotEmpty) {
        final songsRaw = (current['songs'] as List?) ?? [];
        setState(() {
          _name = (current['name'] ?? widget.title).toString();
          _username = (current['username'] ?? 'Lokal').toString();
          _songs = songsRaw.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
          _loading = false;
        });
        return;
      } else if (widget.localSongs != null) {
        setState(() {
          _name = widget.title;
          _username = 'Lokal';
          _songs = widget.localSongs!;
          _loading = false;
        });
        return;
      }
    }

    try {
      final d = await Api.playlistGetById(widget.id);
      if (d is Map && d['error'] != null) throw Exception(d['error']);
      final pl = Map<String, dynamic>.from(d['playlist'] ?? d);
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

    if (widget.id.startsWith('local_')) {
      await LocalPlaylistService.removeSongFromPlaylist(widget.id, s.id.isNotEmpty ? s.id : s.videoId);
      _load();
      return;
    }

    setState(() => _songs.removeWhere((x) => x.videoId == s.videoId));
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
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          pinned: true,
                          elevation: 0,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 20, 0, 20, 24),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 600;
                                final headerInfo = Column(
                                  crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _name,
                                      textAlign: isWide ? TextAlign.left : TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _username.isNotEmpty
                                          ? '$_username · ${_songs.length} lagu · ${_formatTotalDuration()}'
                                          : '${_songs.length} lagu · ${_formatTotalDuration()}',
                                      textAlign: isWide ? TextAlign.left : TextAlign.center,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          ),
                                          onPressed: _songs.isEmpty ? null : _playAll,
                                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                          label: const Text('Putar Semua', style: TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton.filledTonal(
                                          style: IconButton.styleFrom(
                                            backgroundColor: _shuffleMode ? AppColors.red : AppColors.surfaceAlt,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(Icons.shuffle_rounded, size: 20),
                                          onPressed: () => setState(() => _shuffleMode = !_shuffleMode),
                                        ),
                                      ],
                                    ),
                                  ],
                                );

                                if (isWide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _PlaylistCoverLarge(songs: _songs),
                                      const SizedBox(width: 24),
                                      Expanded(child: headerInfo),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    _PlaylistCoverLarge(songs: _songs),
                                    const SizedBox(height: 16),
                                    headerInfo,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        if (_songs.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: Text('Playlist ini masih kosong.', style: TextStyle(color: AppColors.textMuted)),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 0, 16, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final s = _songs[i];
                                  final isCurrent = player.current?.videoId == s.videoId;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? AppColors.surfaceAlt : AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent ? AppColors.red.withOpacity(0.5) : AppColors.border,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      onTap: () => _play(s),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: s.thumbnailUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            width: 44,
                                            height: 44,
                                            color: AppColors.surfaceAlt,
                                            child: const Icon(Icons.music_note, color: AppColors.border),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent ? AppColors.red : Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        s.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.textFaint, size: 20),
                                        onPressed: () => _removeSong(s),
                                      ),
                                    ),
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

class _PlaylistCoverLarge extends StatelessWidget {
  final List<Song> songs;
  const _PlaylistCoverLarge({required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.music_note, color: AppColors.border, size: 48),
      );
    }

    final thumbs = songs.map((s) => s.thumbnailUrl).where((t) => t.isNotEmpty).take(4).toList();

    if (thumbs.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: thumbs[0],
          width: 140,
          height: 140,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(width: 140, height: 140, color: AppColors.surfaceAlt),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 140,
        height: 140,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
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
