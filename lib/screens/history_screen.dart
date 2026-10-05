import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import 'anime_detail_screen.dart';
import '../responsive.dart';

/// Halaman Riwayat Tontonan — daftar film/series/anime yang terakhir
/// ditonton user, lengkap dengan detik & episode/season terakhir.
/// Data diambil dari GET /api/history (server.js, disimpan di history.json).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await Api.historyList(limit: 50);
      setState(() {
        _items = _bacaDaftar(d);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _deleteItem(String historyId) async {
    setState(() => _items.removeWhere((h) => (_ambil(h, const ['historyId', 'id']) ?? '') == historyId));
    try { await Api.historyDelete(historyId); } catch (_) {}
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Semua Riwayat?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Seluruh riwayat tontonan kamu akan dihapus.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _items = []);
    try { await Api.historyClear(); } catch (_) {}
  }

  String _formatDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h}j ${m}m';
    return '${m}m ${s}d';
  }

  String _formatWaktu(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  void _openItem(Map<String, dynamic> h) {
    final type = (_ambil(h, const ['kind', 'type']) ?? '').toString();
    final contentId =
        (_ambil(h, const ['contentId', 'content_id']) ?? '').toString();
    final position =
        (_ambil(h, const ['position', 'posisi']) as num?)?.toInt();
    if (type == 'movie') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MovieDetailScreen(url: contentId, resumePosition: position)));
    } else if (type == 'series') {
      final season = (h['season'] as num?)?.toInt();
      final episode = (h['episode'] as num?)?.toInt();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
                slug: contentId,
                resumeSeason: season,
                resumeEpisode: episode,
                resumePosition: position,
              )));
    } else if (type == 'anime') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnimeDetailScreen(
                url: contentId,
                resumeEpisodeId: h['episodeId']?.toString(),
                resumeServer: h['server']?.toString(),
              )));
    }
  }

  /// Ambil daftar riwayat dari balasan backend.
  ///
  /// Nama kunci di backend beberapa kali berubah (`history`, `hasil`,
  /// `results`, `items`). Dulu layar ini hanya membaca `history`,
  /// sehingga begitu backend berganti nama, daftarnya SELALU kosong
  /// walaupun datanya sudah masuk database. Sekarang semua kunci yang
  /// mungkin dicoba, dan kalau semuanya tidak ada, dipakai array
  /// pertama yang ditemukan di dalam balasan.
  static List<Map<String, dynamic>> _bacaDaftar(dynamic d) {
    if (d is List) {
      return d
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (d is! Map) return [];

    for (final kunci in const [
      'hasil', 'results', 'items', 'history', 'historyList', 'data',
    ]) {
      final v = d[kunci];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    // Cadangan terakhir: array pertama yang ditemukan di dalam balasan.
    for (final v in d.values) {
      if (v is List && v.isNotEmpty && v.first is Map) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  /// Baca sebuah nilai dari baris riwayat, apa pun penamaannya.
  ///
  /// Backend mengirim penamaan ganda (mis. `historyId` dan `id`,
  /// `updatedAt` dan `watched_at`) supaya cocok dengan aplikasi versi
  /// mana pun. Pembaca ini menerima keduanya.
  static dynamic _ambil(Map<String, dynamic> h, List<String> kunci) {
    for (final k in kunci) {
      final v = h[k];
      if (v != null) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      image: AppBg.main,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Riwayat Tontonan', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 22),
              onPressed: _clearAll,
              tooltip: 'Hapus semua',
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.red))
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.history, color: AppColors.border, size: 48),
                            SizedBox(height: 12),
                            Text('Belum ada riwayat tontonan', style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(Layout.desktop(context) ? 28 : 16, 12, Layout.desktop(context) ? 28 : 16, 24),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => _HistoryTile(
                      data: _items[i],
                      formatDuration: _formatDuration,
                      formatWaktu: _formatWaktu,
                      onTap: () => _openItem(_items[i]),
                      onDelete: () => _deleteItem(_items[i]['historyId'].toString()),
                    ),
                  ),
      ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(int) formatDuration;
  final String Function(String?) formatWaktu;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.data,
    required this.formatDuration,
    required this.formatWaktu,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Tanpa judul';
    final poster = data['poster']?.toString() ?? '';
    final position = (data['position'] as num?)?.toInt() ?? 0;
    final duration = (data['duration'] as num?)?.toInt() ?? 0;
    final season = data['season'];
    final episode = data['episode'];
    final episodeNumber = data['episodeNumber'];
    final server = data['server']?.toString();
    final waktu = formatWaktu(data['updatedAt']?.toString());

    String subtitle;
    if (type == 'series' && season != null && episode != null) {
      subtitle = 'Season $season · Episode $episode';
    } else if (type == 'anime' && episodeNumber != null) {
      subtitle = 'Episode $episodeNumber';
      if (server != null && server.isNotEmpty) subtitle += ' · Server $server';
    } else {
      subtitle = 'Film';
    }

    final progressPct = duration > 0 ? (position / duration).clamp(0.0, 1.0) : null;
    final icon = type == 'movie' ? Icons.movie_outlined : type == 'series' ? Icons.theaters_outlined : Icons.live_tv_outlined;

    return Dismissible(
      key: ValueKey(data['historyId']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: Layout.desktop(context) ? 32 : 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 90,
                  child: poster.isNotEmpty
                      ? Image.network(poster, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: Icon(icon, color: AppColors.border, size: 18)))
                      : Container(color: AppColors.surfaceAlt, child: Icon(icon, color: AppColors.border, size: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.play_circle_outline, size: 13, color: AppColors.red),
                      const SizedBox(width: 4),
                      Text('Ditonton ${formatDuration(position)}',
                          style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                      if (waktu.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text('·', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                        const SizedBox(width: 8),
                        Text(waktu, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                      ],
                    ]),
                    if (progressPct != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          minHeight: 4,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(AppColors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
