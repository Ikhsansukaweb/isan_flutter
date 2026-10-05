import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../state/playback_native.dart';
import '../theme.dart';
import '../widgets/isan_background_webview.dart';

class SeriesWebViewScreen extends StatefulWidget {
  final String slug;
  final String title;
  final int? season;
  final int? episode;
  const SeriesWebViewScreen({
    super.key,
    required this.slug,
    required this.title,
    this.season,
    this.episode,
  });

  @override
  State<SeriesWebViewScreen> createState() => _SeriesWebViewScreenState();
}

class _SeriesWebViewScreenState extends State<SeriesWebViewScreen> {
  final _controller = IsanWebViewController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PlaybackNative.start();
    PlaybackNative.update(title: widget.title, subtitle: 'Nonton series di ISAN', isPlaying: true);
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
            url: Api.seriesWebUrl(widget.slug, season: widget.season, episode: widget.episode),
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
