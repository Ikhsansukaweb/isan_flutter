import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache generik buat data API (list anime/movie/series/musik/home feed, dll)
/// pakai shared_preferences, biar pas keluar-masuk app / pindah tab gak nembak
/// backend mulu. Pola: "stale-while-revalidate" — kalau ada cache (walau udah
/// kelewat TTL), langsung balikin itu duluan biar UI cepet keisi, SAMBIL
/// nge-fetch data baru di background dan nyimpen ulang ke cache + manggil
/// [onFresh] kalau ada data baru yang beda dari cache.
///
/// TTL cuma nentuin kapan dianggap "kadaluarsa" buat keperluan auto-refresh
/// di background; data lama tetap dipake dulu daripada nge-blank/spinner.
class ApiCache {
  static const String _prefix = 'isan_cache_';
  static const Duration defaultTtl = Duration(minutes: 10);

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Ambil data: cache-first kalau ada & dipanggil [fetcher] di background
  /// buat refresh. Kalau gak ada cache sama sekali, tunggu [fetcher] selesai.
  static Future<T> fetch<T>({
    required String key,
    required Future<T> Function() fetcher,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
    Duration ttl = defaultTtl,
    void Function(T fresh)? onFresh,
  }) async {
    final prefs = await _prefs;
    final cachedRaw = prefs.getString('$_prefix$key');
    final cachedAtMs = prefs.getInt('$_prefix${key}_at');

    T? cached;
    if (cachedRaw != null) {
      try {
        cached = fromJson(jsonDecode(cachedRaw) as Map<String, dynamic>);
      } catch (_) {
        cached = null;
      }
    }

    final isStale = cachedAtMs == null ||
        DateTime.now().millisecondsSinceEpoch - cachedAtMs > ttl.inMilliseconds;

    if (cached != null && !isStale) {
      return cached; // masih fresh, gak usah nembak backend sama sekali
    }

    if (cached != null && isStale) {
      // Balikin yang lama dulu biar UI gak nge-blank, refresh di belakang.
      _refreshInBackground(key, fetcher, toJson, onFresh);
      return cached;
    }

    // Gak ada cache sama sekali -> wajib fetch sekarang.
    final fresh = await fetcher();
    await _save(key, toJson(fresh));
    return fresh;
  }

  static void _refreshInBackground<T>(
    String key,
    Future<T> Function() fetcher,
    Map<String, dynamic> Function(T value) toJson,
    void Function(T fresh)? onFresh,
  ) {
    fetcher().then((fresh) async {
      await _save(key, toJson(fresh));
      onFresh?.call(fresh);
    }).catchError((_) {
      // gagal refresh diem-diem aja, cache lama masih dipake
    });
  }

  static Future<void> _save(String key, Map<String, dynamic> json) async {
    final prefs = await _prefs;
    await prefs.setString('$_prefix$key', jsonEncode(json));
    await prefs.setInt('$_prefix${key}_at', DateTime.now().millisecondsSinceEpoch);
  }

  /// Versi simpel buat list mentah (List<dynamic> langsung dari JSON API),
  /// gak butuh fromJson/toJson model — dipakai di layar-layar list biar gak
  /// perlu nambah method toJson() ke tiap model cuma buat caching.
  static Future<List<dynamic>> fetchRawList({
    required String key,
    required Future<List<dynamic>> Function() fetcher,
    Duration ttl = defaultTtl,
    void Function(List<dynamic> fresh)? onFresh,
  }) async {
    final prefs = await _prefs;
    final cachedRaw = prefs.getString('$_prefix$key');
    final cachedAtMs = prefs.getInt('$_prefix${key}_at');

    List<dynamic>? cached;
    if (cachedRaw != null) {
      try {
        cached = (jsonDecode(cachedRaw) as Map<String, dynamic>)['items'] as List<dynamic>;
      } catch (_) {
        cached = null;
      }
    }

    final isStale = cachedAtMs == null ||
        DateTime.now().millisecondsSinceEpoch - cachedAtMs > ttl.inMilliseconds;

    if (cached != null && !isStale) return cached;

    if (cached != null && isStale) {
      fetcher().then((fresh) async {
        await _save(key, {'items': fresh});
        onFresh?.call(fresh);
      }).catchError((_) {});
      return cached;
    }

    final fresh = await fetcher();
    await _save(key, {'items': fresh});
    return fresh;
  }

  /// Buat list (List<Map>) tinggal bungkus dengan key 'items'.
  static Future<List<T>> fetchList<T>({
    required String key,
    required Future<List<T>> Function() fetcher,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
    Duration ttl = defaultTtl,
    void Function(List<T> fresh)? onFresh,
  }) {
    return fetch<List<T>>(
      key: key,
      fetcher: fetcher,
      ttl: ttl,
      fromJson: (json) =>
          (json['items'] as List).map((e) => fromJson(Map<String, dynamic>.from(e))).toList(),
      toJson: (list) => {'items': list.map(toJson).toList()},
      onFresh: onFresh,
    );
  }

  /// Hapus semua cache (dipanggil pas user pull-to-refresh manual / logout).
  static Future<void> clearAll() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static Future<void> clear(String key) async {
    final prefs = await _prefs;
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_prefix${key}_at');
  }
}
