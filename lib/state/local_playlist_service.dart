import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class LocalPlaylistService {
  static const String _storageKey = 'isan_offline_playlists_v1';

  static Future<List<Map<String, dynamic>>> getPlaylists() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePlaylists(List<Map<String, dynamic>> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_storageKey, jsonEncode(list));
  }

  static Future<Map<String, dynamic>> createPlaylist(String name) async {
    final list = await getPlaylists();
    final newPl = <String, dynamic>{
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'username': 'Offline / Lokal',
      'songs': <dynamic>[],
    };
    list.insert(0, newPl);
    await savePlaylists(list);
    return newPl;
  }

  static Future<void> deletePlaylist(String id) async {
    final list = await getPlaylists();
    list.removeWhere((item) => item['id'] == id);
    await savePlaylists(list);
  }

  /// Impor playlist dari YouTube / YouTube Music
  static Future<Map<String, dynamic>?> importYoutubePlaylist(String url) async {
    print('[LOCAL PLAYLIST] Mengimpor URL YouTube playlist: $url');
    final res = await Process.run(
      '/home/linuxbrew/.linuxbrew/bin/yt-dlp',
      ['--no-warnings', '--flat-playlist', '-J', url],
    );

    if (res.exitCode != 0 || res.stdout.toString().isEmpty) {
      throw Exception('Gagal membaca playlist YouTube. Pastikan URL valid.');
    }

    final data = jsonDecode(res.stdout.toString());
    final playlistTitle = (data['title'] ?? 'Playlist YouTube').toString();
    final entries = (data['entries'] as List?) ?? [];

    final List<Map<String, dynamic>> songs = [];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final videoId = (e['id'] ?? '').toString();
      if (videoId.isEmpty) continue;

      final title = (e['title'] ?? 'Tanpa Judul').toString();
      final artist = (e['uploader'] ?? e['channel'] ?? 'YouTube Music').toString();
      final duration = (e['duration'] is int) ? e['duration'] as int : int.tryParse('${e['duration']}') ?? 0;
      
      String thumb = '';
      if (e['thumbnails'] is List && (e['thumbnails'] as List).isNotEmpty) {
        thumb = (e['thumbnails'] as List).last['url'] ?? '';
      }
      if (thumb.isEmpty) {
        thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      }

      songs.add({
        'id': 'song_${DateTime.now().millisecondsSinceEpoch}_$i',
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumb,
        'durationSeconds': duration,
      });
    }

    final list = await getPlaylists();
    final newPl = <String, dynamic>{
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'name': playlistTitle,
      'username': 'YouTube (${songs.length} lagu)',
      'songs': songs,
    };
    list.insert(0, newPl);
    await savePlaylists(list);
    return newPl;
  }

  /// Impor playlist dari Spotify (Instan via Embed Next.js Data)
  static Future<Map<String, dynamic>?> importSpotifyPlaylist(String url) async {
    print('[LOCAL PLAYLIST] Mengimpor URL Spotify playlist: $url');
    final reg = RegExp(r'playlist[/:]+([a-zA-Z0-9]+)');
    final match = reg.firstMatch(url);
    if (match == null) {
      throw Exception('URL Spotify Playlist tidak valid.');
    }
    final playlistId = match.group(1);
    final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';

    final resp = await http.get(Uri.parse(embedUrl), headers: {
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64)',
    });

    if (resp.statusCode != 200) {
      throw Exception('Gagal membuka embed Spotify (HTTP ${resp.statusCode}).');
    }

    final scriptReg = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true);
    final scriptMatch = scriptReg.firstMatch(resp.body);
    if (scriptMatch == null) {
      throw Exception('Gagal membaca struktur playlist Spotify.');
    }

    final data = jsonDecode(scriptMatch.group(1)!);
    final entity = data['props']?['pageProps']?['state']?['data']?['entity'] ?? {};
    final playlistTitle = (entity['name'] ?? entity['title'] ?? 'Spotify Playlist').toString();
    final trackList = (entity['trackList'] as List?) ?? [];

    if (trackList.isEmpty) {
      throw Exception('Playlist Spotify tidak memiliki track.');
    }

    final List<Map<String, dynamic>> songs = [];

    // Langsung simpan metadata instan tanpa blocking network
    for (var i = 0; i < trackList.length; i++) {
      final t = trackList[i];
      final title = (t['title'] ?? '').toString();
      final artist = (t['subtitle'] ?? '').toString();
      if (title.isEmpty) continue;

      final durMs = t['duration'] is int ? t['duration'] as int : int.tryParse('${t['duration']}') ?? 0;
      
      // Gunakan query search sebagai identifier instan
      final searchQuery = 'ytsearch1:$title $artist audio';

      songs.add({
        'id': 'spotify_${DateTime.now().millisecondsSinceEpoch}_$i',
        'videoId': searchQuery,
        'title': title,
        'artist': artist,
        'thumbnailUrl': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=200',
        'durationSeconds': durMs ~/ 1000,
      });
    }

    final list = await getPlaylists();
    final newPl = <String, dynamic>{
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'name': playlistTitle,
      'username': 'Spotify (${songs.length} lagu)',
      'songs': songs,
    };
    list.insert(0, newPl);
    await savePlaylists(list);
    return newPl;
  }

  static Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final list = await getPlaylists();
    final idx = list.indexWhere((item) => item['id'] == playlistId);
    if (idx != -1) {
      final songs = List<dynamic>.from(list[idx]['songs'] ?? []);
      songs.removeWhere((s) => s['id'] == songId || s['videoId'] == songId);
      list[idx]['songs'] = songs;
      await savePlaylists(list);
    }
  }
}
