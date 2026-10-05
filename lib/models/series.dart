import 'movie.dart';

// ──────────────────────────────────────────────────────────────
//  Pembantu tipe. Backend kadang mengirim List, kadang Map, kadang
//  string bergabung dengan koma. Tanpa pemeriksaan ini, 'as List?'
//  pada nilai dynamic melempar CastError, dan .where() pada dynamic
//  melempar "dynamic is not subtype of bool of test".
// ──────────────────────────────────────────────────────────────
List<String> daftarKata(dynamic v, {List<String> kunci = const ['nama', 'name', 'title']}) {
  if (v == null) return const [];
  if (v is String) {
    return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  if (v is List) {
    return v.map((e) {
      if (e == null) return '';
      if (e is Map) {
        for (final k in kunci) {
          final x = e[k];
          if (x != null && x.toString().isNotEmpty) return x.toString();
        }
        return '';
      }
      return e.toString();
    }).where((x) => x.isNotEmpty).toList();
  }
  if (v is Map) {
    for (final k in kunci) {
      final x = v[k];
      if (x != null) return [x.toString()];
    }
    return const [];
  }
  return [v.toString()];
}

List<Map<String, dynamic>> daftarPeta(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class SeriesItem {
  final String slug;
  final String title;
  final String? poster;
  final String? rating;
  final int? totalSeasons;
  final String? status;

  SeriesItem({
    required this.slug,
    required this.title,
    this.poster,
    this.rating,
    this.totalSeasons,
    this.status,
  });

  /// Daftar series dari backend mengirim 'tmdbId', bukan 'slug',
  /// sehingga slug kosong -> Api.seriesDetail('') -> detail gagal.
  static String tautanDari(Map<String, dynamic> j) {
    for (final k in ['slug', 'url', 'tmdbId', 'tmdb_id', 'id']) {
      final v = j[k];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return '';
  }

  factory SeriesItem.fromJson(Map<String, dynamic> j) => SeriesItem(
        slug: tautanDari(j),
        title: j['title'] ?? j['judul'] ?? j['name'] ?? '',
        poster: j['poster'],
        rating: j['rating']?.toString(),
        totalSeasons: j['totalSeasons'] is int
            ? j['totalSeasons']
            : int.tryParse('${j['totalSeasons'] ?? ''}'),
        status: j['status'],
      );
}

class SeriesEpisode {
  final int episode;
  final String title;
  final String slug;
  final String url;

  final String poster;
  final String rating;
  final String tayang;
  final String durasi;

  SeriesEpisode({
    required this.episode,
    required this.title,
    required this.slug,
    required this.url,
    this.poster = '',
    this.rating = '',
    this.tayang = '',
    this.durasi = '',
  });

  factory SeriesEpisode.fromJson(Map<String, dynamic> j) {
    // Perhatikan: backend memakai 'masih' untuk ALAMAT GAMBAR episode
    // (bukan 'masih tersedia'). Jangan tertukar.
    final masih = j['masih'] ?? j['poster'] ?? j['gambar'] ?? '';
    return SeriesEpisode(
      episode: j['episode'] is int ? j['episode'] : int.tryParse('${j['episode']}') ?? 0,
      title: (j['title'] ?? j['nama'] ?? '').toString(),
      // backend mengirim 'tmdbId'; tanpa cadangan ini detail series
      // tidak bisa dibuka kalau hanya tmdbId yang tersedia.
      slug: (j['slug'] ?? j['tmdbId'] ?? j['tmdb_id'] ?? j['id'] ?? '').toString(),
      url: (j['url'] ?? j['masih'] ?? '').toString(),
      poster: masih is String ? masih : masih.toString(),
      rating: (j['rating'] ?? j['vote_average'] ?? '').toString(),
      tayang: (j['tayang'] ?? j['air_date'] ?? '').toString(),
      durasi: (j['durasi'] ?? j['runtime'] ?? '').toString(),
    );
  }
}

class SeriesSeason {
  final int season;
  final int totalEpisodes;
  final List<SeriesEpisode> episodes;
  final String nama;
  final String tahun;
  final String poster;

  SeriesSeason({
    required this.season,
    required this.totalEpisodes,
    required this.episodes,
    this.nama = '',
    this.tahun = '',
    this.poster = '',
  });

  factory SeriesSeason.fromJson(Map<String, dynamic> j) => SeriesSeason(
        season: j['season'] is int ? j['season'] : int.tryParse('${j['season']}') ?? 0,
        // Backend mengirim 'episode' sebagai JUMLAH (angka) di daftar musim,
        // mis. {"season":1,"episode":10}. Sebelumnya hanya 'totalEpisodes'
        // yang dibaca, sehingga jumlah episode tidak muncul sama sekali.
        totalEpisodes: _angka(j['totalEpisodes'] ?? j['episode'] ?? j['jumlahEpisode']),
        // Daftar episode TIDAK ikut di balasan detail. Isinya diambil
        // terpisah lewat Api.seriesSeason(id, musim) -> /api/series/:id/season/:n
        episodes: daftarPeta(j['episodes'] ?? j['episodeList'])
            .map((e) => SeriesEpisode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nama: (j['nama'] ?? j['name'] ?? '').toString(),
        tahun: (j['tahun'] ?? j['year'] ?? j['air_date'] ?? '').toString(),
        poster: (j['poster'] ?? j['posterUrl'] ?? '').toString(),
      );

  SeriesSeason salinDengan({List<SeriesEpisode>? episodes, int? totalEpisodes}) => SeriesSeason(
        season: season,
        totalEpisodes: totalEpisodes ?? this.totalEpisodes,
        episodes: episodes ?? this.episodes,
        nama: nama,
        tahun: tahun,
        poster: poster,
      );
}

int _angka(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? 0;
}

/// Ubah genres apa pun bentuknya menjadi daftar nama teks.
/// Backend mengirim [{'id':18,'nama':'Drama'}] — dengan .toString()
/// hasilnya "{id: 18, nama: Drama}", bukan "Drama".
List<String> _namaGenre(dynamic v) {
  if (v is String && v.isNotEmpty) return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (v is List) {
    return v.map((e) {
      if (e is String) return e;
      if (e is Map) return (e['nama'] ?? e['name'] ?? '').toString();
      return '';
    }).where((x) => x.isNotEmpty).toList();
  }
  return const [];
}

class SeriesDetail {
  final String slug;
  final String title;
  final String poster;
  /// Gambar LEBAR 16:9 (backdrop TMDB) — hero halaman detail, menggantikan
  /// poster tegak. 'poster' tetap dipakai kartu daftar & riwayat.
  final String backdrop;
  /// PNG tulisan judul bergaya serialnya sendiri (TMDB `images.logos`).
  /// Kosong kalau TMDB tidak punya — UI jatuh ke teks judul biasa.
  final String logo;
  final String synopsis;
  final String rating;
  final String year;
  final List<String> genres;
  final String country;
  final List<String> cast;
  /// Pemeran lengkap: nama + peran + foto (sama seperti film).
  final List<PemeranItem> pemeran;
  final String votes;
  final String status;
  final int totalSeasons;
  final int totalEpisodes;
  final List<SeriesSeason> seasons;

  SeriesDetail({
    required this.slug,
    required this.title,
    required this.poster,
    this.backdrop = '',
    this.logo = '',
    required this.synopsis,
    required this.rating,
    required this.year,
    required this.genres,
    required this.country,
    required this.cast,
    this.pemeran = const [],
    required this.votes,
    required this.status,
    required this.totalSeasons,
    required this.totalEpisodes,
    required this.seasons,
  });

  factory SeriesDetail.fromJson(Map<String, dynamic> j) => SeriesDetail(
        // backend mengirim judul|title, overview|sinopsis, tahun|year
        slug: (j['slug'] ?? j['tmdbId'] ?? j['tmdb_id'] ?? j['id']?.toString() ?? '').toString(),
        title: (j['judul'] ?? j['title'] ?? '').toString(),
        poster: (j['poster'] ?? j['posterUrl'] ?? j['image'] ?? '').toString(),
        backdrop: MovieItem.backdropDari(j),
        logo: MovieItem.logoDari(j),
        synopsis: (j['sinopsis'] ?? j['overview'] ?? '').toString(),
        rating: (j['rating'] ?? j['vote_average'] ?? '').toString(),
        year: (j['tahun'] ?? j['year'] ?? j['release_date'] ?? '').toString(),
        genres: _namaGenre(j['genres'] ?? j['genre']),
        country: (j['country'] ?? j['negara'] ?? '').toString(),
        // SEBELUMNYA:
        //   ((j['cast'] ?? j['pemain'] as List?) ?? [])
        // 'as' lebih kuat daripada '??' sehingga j['cast'] TIDAK
        // diperiksa tipe -> hasilnya dynamic -> .where((x) => x.isNotEmpty)
        // melempar "type(dynamic) => dynamic is not subtype of
        // type (dynamic) => bool of test".
        cast: daftarKata(j['cast'] ?? j['pemain'], kunci: ['nama', 'name', 'character']),
        pemeran: daftarPemeran(j['pemeran'] ?? j['cast'] ?? j['pemain']),
        votes: (j['votes'] ?? j['vote_count'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        // backend mengirim seasons:[{season, episode}]; kalau kosong,
        // pakai totalSeasons supaya jumlah musim tetap terbaca.
        totalSeasons: daftarPeta(j['seasons']).isNotEmpty
            ? daftarPeta(j['seasons']).length
            : (j['totalSeasons'] is int
                ? j['totalSeasons']
                : int.tryParse('${j['totalSeasons'] ?? ''}') ?? 0),
        totalEpisodes: j['totalEpisodes'] is int
            ? j['totalEpisodes']
            : int.tryParse('${j['totalEpisodes'] ?? ''}') ?? 0,
        seasons: daftarPeta(j['seasons'])
            .map((e) => SeriesSeason.fromJson(e))
            .toList(),
      );
}
