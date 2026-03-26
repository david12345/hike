import 'package:flutter/material.dart';

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

  /// Builds the shared info block: icon, app name, tagline, contact, version.
  ///
  /// Returned as a shrink-wrapped [Column] so [Center] can place it at the
  /// exact visual center of the screen.
  Widget _buildInfoBlock() {
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
        const Text(
          'Essential features for hiking',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'github.com/david12345/hike/issues',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: _buildInfoBlock());
  }
}
