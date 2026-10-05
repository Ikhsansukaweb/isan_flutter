import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Device ID permanen buat ISAN -- di-generate SEKALI (UUID v4) dan
/// disimpan di flutter_secure_storage (Android Keystore-backed, gak ikut
/// adb backup, gak gampang dibaca walau device di-root pakai cara biasa).
///
/// Ini dipakai sebagai "Device ID Binding": dikirim ke backend lewat
/// header X-Device-Id di SETIAP request, dan backend nyimpen device ID
/// itu di JWT payload pas login. Request selanjutnya WAJIB datang dengan
/// X-Device-Id yang sama, kalau gak match (misal token dicopy ke HP lain)
/// backend nolak dengan 401 device_mismatch.
class DeviceId {
  static const _key = 'isan_device_id';
  static const _storage = FlutterSecureStorage();
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    String? existing = await _storage.read(key: _key);
    if (existing == null || existing.isEmpty) {
      existing = const Uuid().v4();
      await _storage.write(key: _key, value: existing);
    }
    _cached = existing;
    return existing;
  }
}
