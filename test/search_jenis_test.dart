// Uji logika pencarian terhadap BALASAN ASLI backend /api/cari.
//
// Fixture di test/fixtures/*.json disimpan apa adanya dari
//     GET https://isanim.web.id/api/cari?q=...
// sehingga uji ini mengunci (A) label jenis dari field `jenis` backend,
// (B) id yang dipakai untuk membuka halaman detail, dan (C) rute /api/cari.
//
// Logika yang diuji adalah SALINAN dari lib/screens/search_screen.dart.
// Kalau kamu mengubah logika di sana, ubah juga di sini — kalau tidak,
// uji ini akan tetap hijau padahal perilakunya sudah berbeda.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ── Salinan helper dari search_screen.dart ────────────────────────────

String samakanJenis(String j) {
  switch (j) {
    case 'movie':
    case 'film':
    case 'movies':
      return 'movie';
    case 'series':
    case 'serial':
    case 'tv':
    case 'tvshow':
    case 'tv_show':
      return 'series';
    case 'anime':
      return 'anime';
    case 'drakor':
    case 'drama':
    case 'drama-korea':
    case 'drama_korea':
    case 'korea':
      return 'drakor';
    case 'music':
    case 'musik':
    case 'song':
    case 'lagu':
      return 'music';
    default:
      return j;
  }
}

String jenisDari(Map e) {
  final mentah = (e['jenis'] ?? '').toString().trim().toLowerCase();
  if (mentah.isNotEmpty && mentah != 'null') return samakanJenis(mentah);
  final kind =
      (e['kind'] ?? e['mediaType'] ?? e['tipe'] ?? '').toString().trim().toLowerCase();
  if (kind == 'movie' || kind == 'film') return 'movie';
  if (kind == 'tv' || kind == 'series' || kind == 'serial') return 'series';
  return 'lainnya';
}

String? tautan(Map j, String jenis) {
  final kunci = <String>['tmdbId', 'tmdb_id', 'contentId', 'id'];
  if (jenis == 'series' || jenis == 'drakor') {
    kunci.addAll(['slug', 'url']);
  } else if (jenis == 'anime') {
    kunci.add('url');
  } else {
    kunci.addAll(['url', 'slug']);
  }
  for (final k in kunci) {
    final v = j[k];
    if (v == null) continue;
    final t = v.toString().trim();
    if (t.isNotEmpty && t != 'null') return t;
  }
  return null;
}

String judul(Map j) {
  for (final k in ['title', 'judul', 'name', 'nama', 'trackName']) {
    final v = j[k];
    if (v != null) {
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
  }
  return '';
}

/// Halaman detail yang dibuka untuk satu hasil.
String halamanTujuan(String jenis) {
  switch (jenis) {
    case 'movie':
      return 'MovieDetailScreen(url: tmdbId) -> GET /api/movie/detail?id=';
    case 'series':
    case 'drakor':
    case 'anime':
      return 'SeriesDetailScreen(slug: tmdbId) -> GET /api/series/detail/';
    default:
      return 'tidak ada halaman detail';
  }
}

/// Salinan `Api.searchGabungan` (kelompokkan per jenis + baca `hasil`).
Map<String, dynamic> searchGabunganDari(String body) {
  final d = jsonDecode(body);
  final peta = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  final hasil = (peta['hasil'] ?? peta['results'] ?? peta['items'] ?? peta['daftar']) as List? ?? const [];
  final per = <String, List<dynamic>>{
    'movie': [],
    'series': [],
    'anime': [],
    'drakor': [],
  };
  for (final e in hasil) {
    if (e is! Map) continue;
    final jenis = (e['jenis'] ?? e['type'] ?? '').toString().trim();
    per[jenis]?.add(e);
  }
  return {
    'q': peta['q'],
    'total': peta['total'] ?? hasil.length,
    'jumlah': peta['jumlah'] ?? const {},
    'hasil': hasil,
    'anime': per['anime']!,
    'movie': per['movie']!,
    'series': per['series']!,
    'drakor': per['drakor']!,
  };
}

List<Map<String, dynamic>> itemsDari(String body) {
  final data = searchGabunganDari(body);
  final entri = (data['hasil'] as List).whereType<Map>();
  final keluar = <Map<String, dynamic>>[];
  for (final e in entri) {
    final m = Map<String, dynamic>.from(e);
    final jenis = jenisDari(m);
    final j = judul(m);
    if (j.isEmpty) continue;
    keluar.add({
      'jenis': jenis,
      'judul': j,
      'id': tautan(m, jenis),
      'halaman': halamanTujuan(jenis),
    });
  }
  return keluar;
}

String bacaFixture(String nama) =>
    File('test/fixtures/$nama').readAsStringSync();

void main() {
  group('(C) rute /api/cari — bentuk balasan', () {
    test('q=naruto: memakai kunci hasil + jumlah per jenis', () {
      final d = searchGabunganDari(bacaFixture('cari_naruto.json'));
      expect(d['q'], 'naruto');
      expect(d['hasil'], isNotEmpty);
      expect((d['jumlah'] as Map)['anime'], 4);
      // Keranjang per jenis harus terisi konsisten dengan daftar gabungan.
      expect(
        (d['anime'] as List).length + (d['movie'] as List).length +
            (d['series'] as List).length + (d['drakor'] as List).length,
        (d['hasil'] as List).length,
      );
    });

    test('hasil tidak difilter diam-diam: jumlah baris == jumlah total', () {
      for (final f in ['cari_spider.json', 'cari_naruto.json', 'cari_dilan.json', 'cari_one.json']) {
        final items = itemsDari(bacaFixture(f));
        final d = searchGabunganDari(bacaFixture(f));
        expect(items.length, (d['hasil'] as List).length, reason: '$f kehilangan baris');
      }
    });
  });

  group('(A) label jenis SELALU dari field `jenis` backend', () {
    test('naruto: tidak ada satu pun baris ditandai anime oleh tebakan rute', () {
      // /api/cari?q=naruto mengirim jumlah.anime = 4, TAPI daftar `hasil`
      // hari ini tidak memuat satu pun baris berjenis 'anime'. Versi lama
      // memakai /api/anime/search yang MENGEMBALIKAN 4 judul (semuanya
      // serial TV TMDB hasil /discover genre 16) lalu menandainya "Anime"
      // padahal backend menyebutnya series.
      final items = itemsDari(bacaFixture('cari_naruto.json'));
      final anime = items.where((i) => i['jenis'] == 'anime').toList();
      expect(anime, isEmpty, reason: 'tidak boleh ada anime karangan');

      // Yang benar: semuanya film atau serial, sesuai field `jenis`.
      final j = items.map((i) => i['jenis']).toSet();
      expect(j.difference({'movie', 'series'}), isEmpty, reason: 'jenis di luar movie/series: $j');
    });

    test('film animasi TIDAK ditandai Anime (inti keluhan)', () {
      // Spider-Verse & One Piece Film Red adalah film animasi. Backend
      // menyebutnya `jenis: "movie"`. Versi lama salah menandainya Anime
      // karena ikut terdaftar di /api/anime/search.
      final spider = itemsDari(bacaFixture('cari_spider.json'));
      final sv = spider.firstWhere((i) => i['judul'].contains('Into the Spider-Verse'));
      expect(sv['jenis'], 'movie');

      final one = itemsDari(bacaFixture('cari_one.json'));
      final red = one.firstWhere((i) => i['judul'] == 'ONE PIECE FILM RED');
      expect(red['jenis'], 'movie');
    });

    test('jenis asli backend dipertahankan apa adanya (movie/series/anime/drakor)', () {
      final one = itemsDari(bacaFixture('cari_one.json'));
      final asli = <String, int>{};
      for (final i in one) {
        asli[i['jenis'] as String] = (asli[i['jenis'] as String] ?? 0) + 1;
      }
      // Fixture ini punya keempat jenis sekaligus — bukti tidak ada yang hilang.
      expect(asli.keys.toSet(), {'movie', 'series', 'anime', 'drakor'});

      final d = searchGabunganDari(bacaFixture('cari_one.json'));
      expect((d['anime'] as List).length, asli['anime']);
      expect((d['movie'] as List).length, asli['movie']);
      expect((d['series'] as List).length, asli['series']);
      expect((d['drakor'] as List).length, asli['drakor']);
    });

    test('`kind` tidak pernah dipakai sebagai sumber utama', () {
      // Semua baris `tv` dari backend punya jenis 'series' ATAU 'anime'
      // ATAU 'drakor'. Kalau kode menebak dari kind, semuanya jadi 'series'
      // dan anime/drakor lenyap.
      final one = itemsDari(bacaFixture('cari_one.json'));
      final tv = one.where((i) => i['jenis'] == 'anime' || i['jenis'] == 'drakor');
      expect(tv, isNotEmpty, reason: 'fixture harus punya anime/drakor ber-kind tv');
    });

    test('jenis yang tidak dikenal tidak dibuang', () {
      final d = searchGabunganDari(jsonEncode({
        'hasil': [
          {'tmdbId': 1, 'jenis': 'novel', 'title': 'Judul Novel'},
        ]
      }));
      expect((d['hasil'] as List).length, 1);
      final items = itemsDari(jsonEncode({
        'hasil': [
          {'tmdbId': 1, 'jenis': 'novel', 'title': 'Judul Novel'},
        ]
      }));
      // `jenis` mentah dipakai sebagai label, barisnya tetap tampil.
      expect(items.single['jenis'], 'novel');
    });
  });

  group('(B) id + halaman tujuan detail', () {
    test('setiap baris punya id dari tmdbId, tidak ada yang kosong', () {
      for (final f in ['cari_spider.json', 'cari_naruto.json', 'cari_dilan.json', 'cari_one.json']) {
        final items = itemsDari(bacaFixture(f));
        final kosong = items.where((i) => (i['id'] as String?) == null || (i['id'] as String).isEmpty);
        expect(kosong, isEmpty, reason: '$f: baris tanpa id -> detail tidak bisa dibuka');
      }
    });

    test('id berupa id TMDB numerik untuk movie, series, anime, dan drakor', () {
      final one = itemsDari(bacaFixture('cari_one.json'));
      for (final i in one) {
        expect(RegExp(r'^\d+$').hasMatch(i['id'] as String), isTrue,
            reason: '${i['judul']} (${i['jenis']}) id bukan angka: ${i['id']}');
      }
    });

    test('halaman tujuan sesuai jenis: movie -> MovieDetail, sisanya SeriesDetail', () {
      final one = itemsDari(bacaFixture('cari_one.json'));
      for (final i in one) {
        final tujuan = i['halaman'] as String;
        if (i['jenis'] == 'movie') {
          expect(tujuan, contains('/api/movie/detail?id='));
        } else {
          expect(tujuan, contains('/api/series/detail/'));
        }
      }
    });

    test('anime TIDAK diarahkan ke AnimeDetailScreen (rutenya sudah tidak ada)', () {
      // AnimeDetailScreen memanggil /api/anime/detail yang di backend baru
      // membalas {"error":"Rute tidak ditemukan"} -> halaman detail anime
      // gagal dibuka.
      final one = itemsDari(bacaFixture('cari_one.json'));
      final anime = one.where((i) => i['jenis'] == 'anime').toList();
      expect(anime, isNotEmpty, reason: 'fixture harus punya anime');
      for (final a in anime) {
        expect(a['halaman'], contains('/api/series/detail/'));
      }
    });

    test('id yang dipakai persis tmdbId yang dikirim backend, bukan turunannya', () {
      final raw = jsonDecode(bacaFixture('cari_spider.json')) as Map;
      final hasil = (raw['hasil'] as List).whereType<Map>();
      final items = itemsDari(bacaFixture('cari_spider.json'));
      for (var n = 0; n < items.length; n++) {
        expect(items[n]['id'], hasil.elementAt(n)['tmdbId'].toString());
      }
    });
  });

  group('(E) bukti bug lama yang diperbaiki (fixture rute lama)', () {
    // test/fixtures/anime_search_naruto.json = balasan ASLI
    //     GET /api/anime/search?q=naruto&limit=20
    // yang dulu dipakai layar pencarian dan SELALU ditandai "Anime".
    // Backend, lewat /api/cari, menyebut keempat judul itu `jenis: "series"`.
    // Bandingkan kedua balasan asli supaya bug-nya tidak bisa kembali diam-diam.
    test('4 judul dari /api/anime/search sebenarnya `series` menurut /api/cari', () {
      final lama = jsonDecode(bacaFixture('anime_search_naruto.json')) as Map;
      final idLama = (lama['hasil'] as List)
          .whereType<Map>()
          .map((e) => e['tmdbId'].toString())
          .toSet();
      expect(idLama.length, 4, reason: 'fixture lama harus berisi 4 judul');

      final baru = itemsDari(bacaFixture('cari_naruto.json'));
      final menurutBackend = {
        for (final i in baru) i['id'] as String: i['jenis'] as String,
      };

      for (final id in idLama) {
        // Kode lama akan menuliskan "Anime" di sini, apa pun jenis aslinya.
        expect(menurutBackend[id], 'series',
            reason: 'id $id ditandai Anime oleh kode lama, backend bilang bukan');
      }
    });

    test('kode baru tidak menghasilkan satu pun anime dari pencarian itu', () {
      final items = itemsDari(bacaFixture('cari_naruto.json'));
      expect(items.where((i) => i['jenis'] == 'anime'), isEmpty);
    });
  });

  group('(D) pemetaan penulisan nama jenis', () {
    test('bentuk lain tetap dipetakan ke bentuk aplikasi', () {
      expect(samakanJenis('film'), 'movie');
      expect(samakanJenis('serial'), 'series');
      expect(samakanJenis('tv'), 'series');
      expect(samakanJenis('drama-korea'), 'drakor');
      expect(samakanJenis('musik'), 'music');
    });

    test('jenis kosong jatuh ke kind, dan kind tv TIDAK pernah jadi anime', () {
      expect(jenisDari({'kind': 'movie'}), 'movie');
      expect(jenisDari({'kind': 'tv'}), 'series');
      expect(jenisDari({'kind': 'tv'}), isNot('anime'));
      expect(jenisDari({}), 'lainnya');
    });
  });
}
