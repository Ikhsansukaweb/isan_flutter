import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// Tombol Instagram ISAN -- pakai path SVG asli (bukan emoji/icon font),
/// gambar logo kamera IG standar, digambar manual sebagai path vector biar
/// gak butuh file asset tambahan. Tap = buka profil IG di app/browser.
class InstagramButton extends StatelessWidget {
  static const String igUrl = 'https://www.instagram.com/muhammad_ikhsan_setiawan';

  final double size;
  final Color color;
  final Color background;

  const InstagramButton({
    super.key,
    this.size = 38,
    this.color = Colors.white,
    this.background = const Color(0x33FFFFFF),
  });

  static const String _svg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="2.5" y="2.5" width="19" height="19" rx="5.5" stroke="{color}" stroke-width="1.7" fill="none"/>
  <circle cx="12" cy="12" r="4.4" stroke="{color}" stroke-width="1.7" fill="none"/>
  <circle cx="17.35" cy="6.65" r="1.15" fill="{color}"/>
</svg>
''';

  Future<void> _open() async {
    final uri = Uri.parse(igUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorHex = '#${color.toARGB32().toRadixString(16).substring(2)}';
    return Tooltip(
      message: '@muhammad_ikhsan_setiawan',
      child: InkWell(
        onTap: _open,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: AppColors.border),
          ),
          child: SvgPicture.string(
            _svg.replaceAll('{color}', colorHex),
            width: size * 0.5,
            height: size * 0.5,
          ),
        ),
      ),
    );
  }
}
