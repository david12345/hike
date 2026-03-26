import 'package:flutter/material.dart';
import '../services/app_info_service.dart';
import '../widgets/about_content.dart';

/// Full-screen About screen displaying app identity, version, and contact info.
///
/// Tapping anywhere on the screen triggers [onTap], which navigates back to
/// the Track tab via a callback from `main.dart`.
///
/// Reads the cached version string from [AppInfoService].
class AboutScreen extends StatelessWidget {
  /// Called when the user taps anywhere on the screen.
  final VoidCallback onTap;

  const AboutScreen({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AboutContent(version: AppInfoService.instance.version),
      ),
    );
  }
}
