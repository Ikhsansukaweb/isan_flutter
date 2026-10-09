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
  static String? _cached;

  static Future<String> get() async {
    _cached ??= 'desktop-linux-isan-device';
    return _cached!;
  }
}
