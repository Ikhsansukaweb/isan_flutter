
// ──────────────────────────────────────────────────────────────
//  Backend mengirim genres sebagai [{id, nama}, ...] atau ["Drama"].
//  .toString() pada Map menghasilkan "{id: 18, nama: Drama}" sehingga
//  chip genre menampilkan teks kotor itu. Ambil nama-nya saja.
// ──────────────────────────────────────────────────────────────
List<String> daftarGenreAnime(dynamic v) {
  if (v == null) return const [];
  if (v is String) {
    return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  if (v is List) {
    return v.map((e) {
      if (e == null) return '';
      if (e is Map) {
        for (final k in ['nama', 'name', 'genre', 'title']) {
          final x = e[k];
          if (x != null && x.toString().isNotEmpty) return x.toString();
        }
        return '';
      }
      return e.toString();
    }).where((x) => x.isNotEmpty).toList();
  }
  if (v is Map) {
    for (final k in ['nama', 'name']) {
      final x = v[k];
      if (x != null) return [x.toString()];
    }
    return const [];
  }
  return [v.toString()];
}

List<Map<String, dynamic>> daftarPetaAnime(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class AnimeItem {
  final String title;
  final String url;
  final String? status;
  final String? poster;

  AnimeItem({required this.title, required this.url, this.status, this.poster});

  factory AnimeItem.fromJson(Map<String, dynamic> j) => AnimeItem(
        title: j['title'] ?? '',
        url: j['url'] ?? '',
        status: j['status'],
        poster: j['poster'],
      );

  AnimeItem copyWith({String? poster}) => AnimeItem(
        title: title,
        url: url,
        status: status,
        poster: poster ?? this.poster,
      );
}

class AnimeEpisodeRef {
  final String title;
  final String episodeId;
  final String? releaseDate;

  AnimeEpisodeRef({required this.title, required this.episodeId, this.releaseDate});

  // Backend bisa mengirim 'title' (Inggris) atau 'judul' (Indonesia),
  // begitu juga 'episodeId' vs 'id'. Menerima keduanya supaya daftar
  // episode tidak tampil kosong.
  factory AnimeEpisodeRef.fromJson(Map<String, dynamic> j) => AnimeEpisodeRef(
        title: (j['title'] ?? j['judul'] ?? '').toString(),
        episodeId: (j['episodeId'] ?? j['id'] ?? '').toString(),
        releaseDate: j['releaseDate'] ?? j['tanggal'],
      );
}

class AnimeOtakuDetail {
  final String title;
  final String? poster;
  final String? synopsis;
  final List<AnimeEpisodeRef> episodes;
  final Map<String, dynamic> info;

  AnimeOtakuDetail({
    required this.title,
    this.poster,
    this.synopsis,
    required this.episodes,
    required this.info,
  });

  // Backend mengirim 'episode' (tunggal, dari lib/anime.js) dan juga
  // 'episodes' (jamak). Keduanya dibaca; kalau kosong, daftar episode
  // tidak akan muncul walau datanya sudah dikirim server.
  factory AnimeOtakuDetail.fromJson(Map<String, dynamic> j) {
    final mentah = (j['episodes'] as List?) ?? (j['episode'] as List?) ?? (j['episodeList'] as List?) ?? [];
    return AnimeOtakuDetail(
      title: (j['title'] ?? j['judul'] ?? '').toString(),
      poster: j['poster'],
      synopsis: j['synopsis'] ?? j['sinopsis'],
      episodes: mentah.map((e) => AnimeEpisodeRef.fromJson(Map<String, dynamic>.from(e))).toList(),
      info: Map<String, dynamic>.from(j['info'] ?? {}),
    );
  }
}

class AnimeJikanDetail {
  final String title;
  final String? titleJapanese;
  final String? poster;
  final String? synopsis;
  final double? score;
  final String? studio;
  final String? status;
  final String? episodes;
  final String? season;
  final List<String> genres;
  final List<AnimeEpisodeRef> episodeList;

  AnimeJikanDetail({
    required this.title,
    this.titleJapanese,
    this.poster,
    this.synopsis,
    this.score,
    this.studio,
    this.status,
    this.episodes,
    this.season,
    required this.genres,
    required this.episodeList,
  });

  factory AnimeJikanDetail.fromJson(Map<String, dynamic> j) => AnimeJikanDetail(
        title: j['title'] ?? '',
        titleJapanese: j['titleJapanese'],
        poster: j['poster'],
        synopsis: j['synopsis'],
        score: (j['score'] as num?)?.toDouble(),
        studio: j['studio'],
        status: j['status'],
        episodes: j['episodes']?.toString(),
        season: j['season'],
        // Dulu: ((j['genres'] as List?) ?? []).map((e) => e.toString())
        // Map di-toString() jadi "{id: 18, nama: Drama}" -> chip kotor.
        genres: daftarGenreAnime(j['genres'] ?? j['genre']),
        episodeList: daftarPetaAnime(j['episodeList'] ?? j['episodes'] ?? j['episode'])
            .map((e) => AnimeEpisodeRef.fromJson(e))
            .toList(),
      );
}
