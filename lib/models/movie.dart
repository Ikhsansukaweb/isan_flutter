
// ──────────────────────────────────────────────────────────────
//  Pembantu tipe (sama seperti di series.dart).
//  'as' di Dart lebih kuat daripada '??', jadi
//      (j['cast'] ?? j['pemain'] as List?)
//  TIDAK memeriksa tipe j['cast']. Kalau backend mengirim List<Map>,
//  hasilnya dynamic -> .map().toList() melempar CastError -> halaman
//  detail menampilkan "tidak ditemukan" padahal datanya ada.
// ──────────────────────────────────────────────────────────────
List<String> daftarKataNama(dynamic v, {List<String> kunci = const ['nama', 'name', 'title']}) {
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

/// Satu pemeran: nama, peran yang dimainkan, dan URL foto.
///
/// SEBELUMNYA hanya nama yang dibaca (detail.cast = List<String>),
/// sehingga peran dan foto yang sudah dikirim backend dibuang begitu
/// saja. Akibatnya baris "Pemeran" cuma menampilkan nama berjajar
/// dipisah koma, tanpa foto.
class PemeranItem {
  final String nama;
  final String peran;
  final String foto; // URL lengkap, kosong kalau TMDB tidak punya

  const PemeranItem({
    required this.nama,
    this.peran = '',
    this.foto = '',
  });

  bool get adaFoto => foto.isNotEmpty;

  factory PemeranItem.fromJson(Map<String, dynamic> j) => PemeranItem(
        nama: (j['nama'] ?? j['name'] ?? '').toString().trim(),
        peran: (j['peran'] ?? j['character'] ?? j['role'] ?? '').toString().trim(),
        foto: (j['foto'] ?? j['photo'] ?? j['profile'] ?? '').toString().trim(),
      );
}

/// Baca daftar pemeran dari JSON, apa pun bentuk yang dikirim backend:
///   [{'nama':..,'peran':..,'foto':..}]   <- bentuk sekarang
///   ['Nama Satu', 'Nama Dua']            <- bentuk lama (tanpa foto)
List<PemeranItem> daftarPemeran(dynamic v) {
  if (v is! List) return const [];
  final hasil = <PemeranItem>[];
  for (final e in v) {
    if (e is Map) {
      final p = PemeranItem.fromJson(Map<String, dynamic>.from(e));
      if (p.nama.isNotEmpty) hasil.add(p);
    } else if (e is String && e.trim().isNotEmpty) {
      // bentuk lama: cuma nama
      hasil.add(PemeranItem(nama: e.trim()));
    }
  }
  return hasil;
}

class MovieItem {
  final String title;
  final String url;
  final String image;
  final String? quality;

  MovieItem({required this.title, required this.url, required this.image, this.quality});

  /// Backend bisa mengirim 'poster' (nama utama), 'image' (nama lama),
  /// atau 'posterUrl'/'poster_path'. Sebelumnya hanya 'image' dibaca
  /// sehingga poster film selalu kosong.
  static String gambarDari(Map<String, dynamic> j) {
    for (final k in ['poster', 'image', 'posterUrl', 'poster_url', 'gambar', 'thumbnail']) {
      final v = j[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// URL gambar LEBAR 16:9 (backdrop) — bentuk gambar yang dipakai sebagai
  /// HERO di halaman detail, BUKAN poster tegak.
  ///
  /// Backend mengirim 'backdrop' (w1280 siap pakai) dan 'backdropHd'
  /// (original). Nama lain tetap diterima supaya rute lama jalan. Kalau
  /// semuanya kosong, jatuh ke poster — lebih baik hero menampilkan poster
  /// daripada kotak kosong.
  ///
  /// Ditaruh di MovieItem (bukan MovieDetail) karena SeriesDetail juga
  /// memakainya lewat `MovieItem.backdropDari`.
  static String backdropDari(Map<String, dynamic> j) {
    for (final k in ['backdropHd', 'backdrop', 'backdropUrl', 'backdrop_path', 'backdropPath', 'gambarLatar']) {
      final v = j[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return gambarDari(j);
  }

  /// URL PNG tulisan judul bergaya filmnya sendiri (TMDB `images.logos`).
  ///
  /// Inilah yang dimaksud "logo" pada permintaan — bukan font, melainkan
  /// gambar tulisan judul yang sudah jadi seni filmnya (mis. huruf "MOANA"
  /// yang terbuat dari air). Kosong kalau TMDB tidak punya; UI memakai teks
  /// judul biasa sebagai cadangan.
  static String logoDari(Map<String, dynamic> j) {
    for (final k in ['logoBesar', 'logo', 'logoUrl']) {
      final v = j[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// Nilai yang dipakai layar untuk membuka halaman detail.
  /// Daftar film dari backend mengirim 'tmdbId' (BUKAN 'url'), sehingga
  /// url selalu kosong -> Api.movieDetail('') -> "detail tidak ditemukan".
  static String tautanDari(Map<String, dynamic> j) {
    for (final k in ['url', 'tmdbId', 'tmdb_id', 'id', 'slug']) {
      final v = j[k];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return '';
  }

  factory MovieItem.fromJson(Map<String, dynamic> j) => MovieItem(
        title: j['title'] ?? j['judul'] ?? j['name'] ?? '',
        url: tautanDari(j),
        image: gambarDari(j),
        quality: j['quality'] ?? j['kualitas'],
      );
}

class MovieDetail {
  final String title;
  final String synopsis;
  final String year;
  final String genre;
  final String image;
  /// Gambar LEBAR 16:9 (backdrop TMDB) — dipakai sebagai hero halaman detail,
  /// bukan poster tegak. Backend mengirim 'backdrop'/'backdropUrl';
  /// 'image' (poster tegak) tetap dipertahankan untuk kartu & riwayat.
  final String backdrop;
  /// PNG tulisan judul bergaya filmnya sendiri (TMDB `images.logos`).
  /// Kosong kalau TMDB tidak punya — UI jatuh ke teks judul biasa.
  final String logo;
  final String quality;
  final String rating;
  final String duration;
  final String country;
  final String votes;
  final String release;
  final List<String> directors;
  final List<String> cast;
  /// Pemeran lengkap: nama + peran + foto.
  ///
  /// Dibedakan dari `cast` (yang cuma daftar nama) supaya tampilan bisa
  /// memakai foto bulat dan digeser ke kanan. `cast` tetap dipertahankan
  /// untuk kode lama yang belum memakai foto.
  final List<PemeranItem> pemeran;
  final String url;

  MovieDetail({
    required this.title,
    required this.synopsis,
    required this.year,
    required this.genre,
    required this.image,
    this.backdrop = '',
    this.logo = '',
    required this.quality,
    required this.rating,
    required this.duration,
    required this.country,
    required this.votes,
    required this.release,
    required this.directors,
    required this.cast,
    this.pemeran = const [],
    required this.url,
  });

  /// Ubah daftar genre apa pun bentuknya menjadi teks dipisah koma.
  /// Backend mengirim genres: [{'id':18,'nama':'Drama'}, ...] sedangkan
  /// aplikasi mengharapkan teks; tanpa ini baris genre di halaman detail
  /// selalu kosong dan jatuh ke nilai bawaan 'action'.
  static String genreTeks(Map<String, dynamic> j) {
    final v = j['genre'] ?? j['genres'] ?? j['genreTeks'];
    if (v is String && v.isNotEmpty) return v;
    if (v is List) {
      final nama = v.map((e) {
        if (e is String) return e;
        if (e is Map) return (e['nama'] ?? e['name'] ?? '').toString();
        return '';
      }).where((x) => x.isNotEmpty);
      return nama.join(', ');
    }
    return '';
  }

  factory MovieDetail.fromJson(Map<String, dynamic> j) => MovieDetail(
        // backend mengirim judul|title, tahun|year, durasi|duration,
        // sinopsis|overview — terima keduanya.
        title: (j['judul'] ?? j['title'] ?? '').toString(),
        synopsis: (j['sinopsis'] ?? j['overview'] ?? '').toString(),
        year: (j['tahun'] ?? j['year'] ?? '').toString(),
        genre: genreTeks(j),
        image: MovieItem.gambarDari(j),
        backdrop: MovieItem.backdropDari(j),
        logo: MovieItem.logoDari(j),
        quality: (j['quality'] ?? j['kualitas'] ?? '').toString(),
        rating: (j['rating'] ?? j['vote_average'] ?? '').toString(),
        duration: (j['durasi'] ?? j['duration'] ?? '').toString(),
        country: (j['country'] ?? j['negara'] ?? '').toString(),
        votes: (j['votes'] ?? j['vote_count'] ?? '').toString(),
        release: (j['release'] ?? j['tanggalRilis'] ?? j['release_date'] ?? '').toString(),
        // 'as' lebih kuat daripada '??' -> j['directors'] tidak diperiksa
        // tipe. Kalau backend kirim List<Map>, hasilnya dynamic mentah ->
        // CastError -> halaman detail menulis "tidak ditemukan".
        directors: daftarKataNama(j['directors'] ?? j['sutradara'], kunci: ['nama', 'name']),
        cast: daftarKataNama(j['cast'] ?? j['pemain'], kunci: ['nama', 'name', 'character']),
        pemeran: daftarPemeran(j['pemeran'] ?? j['cast'] ?? j['pemain']),
        // backend mengirim 'tmdbId' pada daftar & pencarian.
        url: (j['url'] ?? j['tmdbId'] ?? j['tmdb_id'] ?? j['slug'] ?? j['id']?.toString() ?? '').toString(),
      );
}
