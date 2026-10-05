import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../models/song.dart';

/// Data user (isan_user) juga dipindah ke flutter_secure_storage, konsisten
/// dengan token -- field ini gak terlalu sensitif (cuma username/email/id),
/// tapi tetap baik dipisah dari shared_preferences biasa supaya gak ikut
/// adb backup bersama data lain.
class AuthState extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _kUser = 'isan_user';

  IsanUser? user;
  bool loaded = false;

  Future<void> loadFromStorage() async {
    await Api.init();
    final userStr = await _storage.read(key: _kUser);
    if (Api.token != null && userStr != null) {
      try {
        user = IsanUser.fromJson(jsonDecode(userStr));
      } catch (_) {}
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> setAuth(IsanUser u, String token, {String? refreshToken}) async {
    await Api.setTokens(token: token, refreshToken: refreshToken);
    await _storage.write(key: _kUser, value: jsonEncode(u.toJson()));
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await Api.logout(); // clear cookie/refresh token record di backend juga
    } catch (_) {}
    await Api.clearToken();
    await _storage.delete(key: _kUser);
    user = null;
    notifyListeners();
  }

  bool get isLoggedIn => user != null;
}
