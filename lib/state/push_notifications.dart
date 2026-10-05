import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/api_client.dart';

/// Push notification (FCM) buat broadcast dari developer (lewat Telegram)
/// yang tetap muncul WALAU APP DITUTUP TOTAL -- beda dari GlobalChatNotifier
/// (polling) yang cuma jalan kalau app/Dart isolate masih hidup.
///
/// Dipanggil SETELAH user login (token FCM dikaitkan ke userId di backend),
/// bukan di main() langsung -- karena endpoint /api/fcm/register WAJIB
/// login (requireAuth).
class PushNotifications {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) {
      await Api.registerFcmToken(token).catchError((_) {});
    }

    // Kalau token berubah (reinstall app, dll), daftarkan ulang otomatis.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      Api.registerFcmToken(newToken).catchError((_) {});
    });
  }
}
