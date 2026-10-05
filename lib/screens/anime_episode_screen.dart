import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/auth_guard.dart';

class _ServerInfo {
  final String serverId;
  final String provider;
  final String resolution;

  _ServerInfo({required this.serverId, required this.provider, required this.resolution});

  factory _ServerInfo.fromJson(Map<String, dynamic> j) => _ServerInfo(
        serverId: j['serverId'] ?? '',
        provider: j['provider'] ?? '',
        resolution: j['resolution']?.toString() ?? '',
      );
}

const Map<String, String> _providerLabel = {
  'mega': 'Mega',
  'vidhide': 'VidHide',
  'filedon': 'FileDon',
  'ondesu3': 'OnDesu',
  'ondesuhd': 'OnDesuHD',
  'zippyshare': 'ZippyShare',
  'otakuwatch': 'OtakuWatch',
};

class AnimeEpisodeScreen extends StatefulWidget {
  final String episodeId;
  final String title;
  const AnimeEpisodeScreen({super.key, required this.episodeId, required this.title});

  @override
  State<AnimeEpisodeScreen> createState() => _AnimeEpisodeScreenState();
}

class _AnimeEpisodeScreenState extends State<AnimeEpisodeScreen> {
  bool _loadingServers = true;
  bool _loadingStream = false;
  String? _error;
  String _streamUrl = '';
  List<_ServerInfo> _servers = [];
  Map<String, dynamic>? _prevEp;
  Map<String, dynamic>? _nextEp;
  late final WebViewController _webCtrl;

  @override
  void initState() {
    super.initState();
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    // FIX CRASH FULLSCREEN: server pihak ketiga yang di-embed di sini bisa
    // juga punya tombol fullscreen video. Lihat penjelasan lengkap di
    // movie_detail_screen.dart.
    final platform = _webCtrl.platform;
    if (platform is AndroidWebViewController) {
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, callback) {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(backgroundColor: Colors.black, body: widget),
            fullscreenDialog: true,
          ));
        },
        onHideCustomWidget: () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        },
      );
    }

    // Cek login SETELAH frame pertama selesai render -- initState belum
    // "settled" buat nampilin dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AuthGuard.requireLoginOr(context)) {
        setState(() => _loadingServers = false);
        return;
      }
      _loadEpisode(widget.episodeId);
    });
  }

  Future<void> _loadEpisode(String episodeId) async {
    setState(() {
      _loadingServers = true;
      _error = null;
      _streamUrl = '';
    });
    try {
      final d = await Api.episode(episodeId);
      if (d['error'] == 'unauthorized' || d['error'] == 'token_expired' ||
          d['error'] == 'ip_mismatch' || d['error'] == 'device_mismatch' || d['error'] == 'invalid_token') {
        setState(() => _loadingServers = false);
        if (mounted) AuthGuard.showLoginRequiredDialog(context, message: d['message']?.toString());
        return;
      }
      if (d['error'] != null) throw Exception(d['error']);
      final servers = ((d['servers'] as List?) ?? [])
          .map((e) => _ServerInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _servers = servers;
        _prevEp = d['prevEpisode'] != null ? Map<String, dynamic>.from(d['prevEpisode']) : null;
        _nextEp = d['nextEpisode'] != null ? Map<String, dynamic>.from(d['nextEpisode']) : null;
        _loadingServers = false;
      });
      final bestId = d['bestServerId']?.toString();
      if (bestId != null && bestId.isNotEmpty) {
        _playServer(bestId);
      } else if (servers.isNotEmpty) {
        _playServer(servers.first.serverId);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingServers = false;
      });
    }
  }

  Future<void> _playServer(String serverId) async {
    setState(() {
      _loadingStream = true;
      _error = null;
    });
    try {
      final d = await Api.resolveServer(serverId);
      if (d['error'] == 'unauthorized' || d['error'] == 'token_expired' ||
          d['error'] == 'ip_mismatch' || d['error'] == 'device_mismatch' || d['error'] == 'invalid_token') {
        setState(() => _loadingStream = false);
        if (mounted) AuthGuard.showLoginRequiredDialog(context, message: d['message']?.toString());
        return;
      }
      final url = d['url']?.toString() ?? '';
      if (url.isEmpty) throw Exception('Server tidak merespon, coba provider lain');
      setState(() {
        _streamUrl = url;
        _loadingStream = false;
      });
      _webCtrl.loadRequest(Uri.parse(url));
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingStream = false;
      });
    }
  }

  String _provLabel(String p) =>
      _providerLabel[p.toLowerCase()] ?? (p.isNotEmpty ? p[0].toUpperCase() + p.substring(1) : 'Server');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _loadingServers || _loadingStream
                  ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                  : _streamUrl.isNotEmpty
                      ? WebViewWidget(controller: _webCtrl)
                      : Center(
                          child: Text(
                            _error ?? 'Streaming tidak tersedia',
                            style: const TextStyle(color: AppColors.textFaint),
                            textAlign: TextAlign.center,
                          ),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _prevEp == null
                        ? null
                        : () => _loadEpisode(_prevEp!['episodeId'].toString()),
                    icon: const Icon(Icons.skip_previous, size: 18),
                    label: const Text('Sebelumnya'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _nextEp == null
                        ? null
                        : () => _loadEpisode(_nextEp!['episodeId'].toString()),
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Selanjutnya'),
                  ),
                ),
              ],
            ),
          ),
          if (_servers.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('PILIH SERVER',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _servers.length,
              itemBuilder: (ctx, i) {
                final s = _servers[i];
                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
                  child: ListTile(
                    onTap: () => _playServer(s.serverId),
                    leading: const Icon(Icons.live_tv, color: AppColors.red, size: 20),
                    title: Text(_provLabel(s.provider),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    trailing: Text('${s.resolution}p',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
