import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../theme.dart';

/// Polling pesan broadcast dari developer (dikirim lewat chat Telegram biasa
/// ke bot admin) dan nampilin sebagai notifikasi banner di atas layar.
///
/// PENDEKATAN: pakai Stack + Positioned langsung di build() (BUKAN
/// Overlay.of(context) manual) -- itu lebih robust karena gak depend
/// sama sekali ke posisi widget ini di tree relatif terhadap MaterialApp
/// (Overlay.of(context) bisa gagal/dapet overlay yang salah kalau widget
/// ini dipasang di builder: MaterialApp, yang posisinya di LUAR Navigator).
class GlobalChatNotifier extends StatefulWidget {
  final Widget child;
  const GlobalChatNotifier({super.key, required this.child});

  @override
  State<GlobalChatNotifier> createState() => _GlobalChatNotifierState();
}

class _GlobalChatNotifierState extends State<GlobalChatNotifier> {
  static const _kLastSeenKey = 'isan_broadcast_last_seen';
  Timer? _timer;
  int _lastSeen = 0;
  String? _current;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    // PENTING: default 0 (BUKAN waktu sekarang) kalau belum pernah nyimpen
    // last-seen sama sekali. Kalau default-nya "waktu sekarang", broadcast
    // yang udah dikirim SEBELUM app pertama kali dibuka bakal kelewat
    // selamanya (since=now bikin backend filter b.at > now, yang otomatis
    // exclude semua broadcast lama).
    _lastSeen = prefs.getInt(_kLastSeenKey) ?? 0;
    // ignore: avoid_print
    print('[ISAN BROADCAST] init, lastSeen=$_lastSeen');
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _poll());
  }

  Future<void> _poll() async {
    // ignore: avoid_print
    print('[ISAN BROADCAST] polling, since=$_lastSeen');
    try {
      final d = await Api.broadcastLatest(since: _lastSeen);
      // ignore: avoid_print
      print('[ISAN BROADCAST] response = $d');
      final list = (d['broadcasts'] as List?) ?? [];
      if (list.isEmpty) {
        // ignore: avoid_print
        print('[ISAN BROADCAST] tidak ada broadcast baru');
        return;
      }

      int maxAt = _lastSeen;
      String? lastText;
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw);
        final at = (m['at'] as num?)?.toInt() ?? 0;
        if (at > maxAt) maxAt = at;
        lastText = m['text']?.toString() ?? '';
      }
      _lastSeen = maxAt;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSeenKey, _lastSeen);

      // ignore: avoid_print
      print('[ISAN BROADCAST] nampilin pesan: $lastText');
      if (mounted && lastText != null && lastText.isNotEmpty) {
        setState(() => _current = lastText);
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _current = null);
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ISAN BROADCAST] error polling: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () => setState(() => _current = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ISAN',
                                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(_current!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
