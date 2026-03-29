import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/hike_record.dart';
import '../repositories/imported_trail_repository.dart';
import '../services/app_info_service.dart';
import '../services/hike_service.dart';
import '../services/tile_cache_service.dart';
import '../services/tracking_state.dart';
import '../services/user_preferences_service.dart';
import '../widgets/about_content.dart';

/// Splash screen shown on app launch before the main [HomePage].
///
/// Displays the app icon, name, tagline, contact info, and build version.
/// Runs [HikeService.init] and a minimum 2-second delay in parallel,
/// then auto-navigates to [HomePage] via [Navigator.pushReplacement].
///
/// If an unfinished [HikeRecord] is found (crashed/killed during recording),
/// a modal recovery dialog is shown before navigation.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // Hive must be initialised before any box is opened.
    await Hive.initFlutter();

    // Run all initialisations in parallel with a minimum 2s splash delay.
    await Future.wait([
      HikeService.init(),
      ImportedTrailRepository.init(),
      TrackingState.init(),
      TileCacheService.init(),
      AppInfoService.instance.init(),
      UserPreferencesService.instance.init(),
      Future.delayed(const Duration(seconds: 2)),
    ]);

    if (!mounted) return;
    setState(() {}); // version is now available; repaint before navigating

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    // Check for an interrupted recording.
    final unfinished = HikeService.findUnfinished();
    if (unfinished != null && mounted) {
      final resume = await _showRecoveryDialog(unfinished);
      if (!mounted) return;
      if (resume) {
        unawaited(Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(unfinishedHike: unfinished),
          ),
        ));
        return;
      } else {
        await HikeService.delete(unfinished.id);
      }
    }

    if (!mounted) return;
    unawaited(Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    ));
  }

  /// Shows a modal dialog offering to resume or discard an interrupted hike.
  ///
  /// Returns `true` if the user chose Resume, `false` for Discard.
  Future<bool> _showRecoveryDialog(HikeRecord record) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final startFormatted =
        DateFormat('d MMM yyyy, HH:mm', locale).format(record.startTime);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.splashRecoveryDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.splashRecoveryName(record.name)),
            Text(l10n.splashRecoveryStarted(startFormatted)),
            Text(l10n.splashRecoveryPoints(record.latitudes.length)),
            const SizedBox(height: 12),
            Text(l10n.splashRecoveryQuestion),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.splashRecoveryDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.splashRecoveryResume),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AboutContent(version: AppInfoService.instance.version),
    );
  }
}
