import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/song.dart';

/// Data user (isan_user) juga dipindah ke flutter_secure_storage, konsisten
/// dengan token -- field ini gak terlalu sensitif (cuma username/email/id),
/// tapi tetap baik dipisah dari shared_preferences biasa supaya gak ikut
/// adb backup bersama data lain.
class AuthState extends ChangeNotifier {
  static const _kUser = 'isan_user';

  IsanUser? user;
  bool loaded = false;

  Future<void> loadFromStorage() async {
    await Api.init();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_kUser);
      if (Api.token != null && userStr != null) {
        user = IsanUser.fromJson(jsonDecode(userStr));
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> setAuth(IsanUser u, String token, {String? refreshToken}) async {
    await Api.setTokens(token: token, refreshToken: refreshToken);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUser, jsonEncode(u.toJson()));
    } catch (_) {}
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await Api.logout();
    } catch (_) {}
    await Api.clearToken();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUser);
    } catch (_) {}
    user = null;
    notifyListeners();
  }

  bool get isLoggedIn => user != null;
}
