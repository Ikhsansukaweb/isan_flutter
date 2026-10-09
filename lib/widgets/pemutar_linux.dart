import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class IsanWebViewControllerLinux {
  void Function(String code)? onError;
  VoidCallback? onEnded;
  void Function(String message)? onLog;
  void Function()? onPopupBlocked;
  void Function(String host)? onRedirectBlocked;
  void Function(String url)? pageFinished;

  void attach(dynamic _) {}
  void laporPageFinished(String url) => pageFinished?.call(url);

  Future<void> runJs(String code) async {}
  void loadUrl(String url) {}
  Future<void> reload() async {}
  void stop() {}
}

class PemutarLinux extends StatefulWidget {
  final String? url;
  final String? html;
  final String? userAgent;
  final IsanWebViewControllerLinux controller;

  const PemutarLinux({
    super.key,
    this.url,
    this.html,
    this.userAgent,
    required this.controller,
  });

  @override
  State<PemutarLinux> createState() => _PemutarLinuxState();
}

class _PemutarLinuxState extends State<PemutarLinux> {
  Process? _browserProcess;

  @override
  void initState() {
    super.initState();
    _launchInlinePlayer();
  }

  @override
  void didUpdateWidget(covariant PemutarLinux oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _launchInlinePlayer();
    }
  }

  void _launchInlinePlayer() {
    _stopPlayer();
    final targetUrl = widget.url;
    if (targetUrl == null || targetUrl.isEmpty) return;

    print('[LINUX MOVIE PLAYER] Launch target: $targetUrl');

    // Buka target embed URL di browser engine lokal (Brave/Chromium/Firefox)
    Process.start(
      'bash',
      [
        '-c',
        'if which brave >/dev/null 2>&1; then exec brave --app="$targetUrl"; elif which firefox >/dev/null 2>&1; then exec firefox --new-window "$targetUrl"; fi'
      ],
    ).then((p) {
      _browserProcess = p;
    }).catchError((e) {
      print('[LINUX MOVIE ERROR] $e');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.laporPageFinished(targetUrl);
    });
  }

  void _stopPlayer() {
    try {
      _browserProcess?.kill(ProcessSignal.sigkill);
      _browserProcess = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_creation_rounded, size: 54, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Memutar film di player embed...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              widget.url ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
