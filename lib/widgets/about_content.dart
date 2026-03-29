import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

/// Shared visual content widget used by both [SplashScreen] and [AboutScreen].
///
/// Displays the app icon, name, tagline, contact info, and version string
/// centered vertically and horizontally. The parent is responsible for
/// providing the black background (via `Scaffold.backgroundColor`).
class AboutContent extends StatelessWidget {
  /// The version string to display (e.g., "v1.0.0").
  final String version;

  const AboutContent({
    super.key,
    required this.version,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Builds the shared info block: icon, app name, tagline, contact, version.
  ///
  /// Returned as a shrink-wrapped [Column] so [Center] can place it at the
  /// exact visual center of the screen.
  Widget _buildInfoBlock(String tagline) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 160,
            height: 160,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Hike',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tagline,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 32),
        RichText(
          text: TextSpan(
            text: 'github.com/david12345/hike/issues',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: Colors.lightBlueAccent,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchUrl('https://github.com/david12345/hike/issues'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          version,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: 'david.a.ferreira@protonmail.com',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: Colors.lightBlueAccent,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchUrl('mailto:david.a.ferreira@protonmail.com'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagline = AppLocalizations.of(context).aboutTagline;
    return Center(child: _buildInfoBlock(tagline));
  }
}
