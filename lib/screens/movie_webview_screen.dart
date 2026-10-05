import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../state/playback_native.dart';
import '../theme.dart';
import '../widgets/isan_background_webview.dart';

class MovieWebViewScreen extends StatefulWidget {
  final String sourceUrl;
  final String title;
  const MovieWebViewScreen({super.key, required this.sourceUrl, required this.title});

  @override
  State<MovieWebViewScreen> createState() => _MovieWebViewScreenState();
}

class _MovieWebViewScreenState extends State<MovieWebViewScreen> {
  final _controller = IsanWebViewController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PlaybackNative.start();
    PlaybackNative.update(title: widget.title, subtitle: 'Nonton film di ISAN', isPlaying: true);
  }

  @override
  void dispose() {
    PlaybackNative.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        children: [
          IsanBackgroundWebView(
            url: Api.movieWebUrl(widget.sourceUrl),
            controller: _controller,
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.red)),
        ],
      ),
    );
  }
}
