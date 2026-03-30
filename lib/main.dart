import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'models/hike_record.dart';
import 'models/osm_trail.dart';
import 'screens/track_screen.dart';
import 'screens/map_screen.dart';
import 'screens/log_screen.dart';
import 'screens/trails_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auto_data_bridge_service.dart';
import 'services/foreground_tracking_service.dart';
import 'services/hike_recording_controller.dart';
import 'services/intent_handler_service.dart';
import 'services/tile_preference_service.dart';
import 'services/tracking_state.dart';
import 'viewmodels/analytics_view_model.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundTrackingService.init();
  await TilePreferenceService.instance.init();
  runApp(const HikeApp());
}

class HikeApp extends StatelessWidget {
  const HikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hike',
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale?.languageCode == 'pt') {
          Intl.defaultLocale = 'pt';
          return const Locale('pt');
        }
        Intl.defaultLocale = 'en';
        return const Locale('en');
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandGreen,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandGreen,
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  /// An interrupted [HikeRecord] to resume, or `null` for normal startup.
  final HikeRecord? unfinishedHike;

  const HomePage({super.key, this.unfinishedHike});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  late final HikeRecordingController _recordingController;
  late final AnalyticsViewModel _analyticsViewModel;
  late final AppLifecycleListener _lifecycleListener;
  final ValueNotifier<OsmTrail?> _pendingGuideTrail = ValueNotifier(null);

  void _onTabChanged(int index) {
    if (index == 0) {
      _recordingController.resumeCompass();
    } else if (_currentIndex == 0) {
      _recordingController.pauseCompass();
    }
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();

    _recordingController = HikeRecordingController();
    _analyticsViewModel = AnalyticsViewModel();
    _analyticsViewModel.init();
    AutoDataBridgeService.instance.init(_recordingController);
    _pendingGuideTrail.addListener(_onPendingGuideTrail);

    // Await init on first frame so ScaffoldMessenger is available for errors.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRecordingController());

    if (widget.unfinishedHike != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordingController.resumeFromRecord(
          widget.unfinishedHike!,
          onError: _showError,
          resumeFailedMessage:
              AppLocalizations.of(context).trackErrorCouldNotResume,
        );
      });
    }

    _lifecycleListener = AppLifecycleListener(
      onHide: () {
        if (_recordingController.isRecording) {
          unawaited(ForegroundTrackingService.setWakeLock(true));
        }
      },
      onPause: () {
        if (_recordingController.isRecording) {
          unawaited(ForegroundTrackingService.setWakeLock(true));
        }
      },
      onResume: () => unawaited(ForegroundTrackingService.setWakeLock(false)),
    );

    IntentHandlerService.onTrailsImported = () {
      setState(() => _currentIndex = 3); // navigate to Trails tab only
    };
    IntentHandlerService.onError = _showError;
    IntentHandlerService.init();
    _screens = [
      TrackScreen(controller: _recordingController),
      const MapScreen(),
      const LogScreen(),
      TrailsScreen(onStartHike: _pendingGuideTrail),
      AnalyticsScreen(viewModel: _analyticsViewModel),
    ];
  }

  Future<void> _initRecordingController() async {
    try {
      await _recordingController.init();
    } catch (e) {
      debugPrint('[HomePage] HikeRecordingController.init() failed: $e');
      if (mounted) {
        _showError('Sensor initialisation failed. GPS tracking may be unavailable.');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onPendingGuideTrail() async {
    final trail = _pendingGuideTrail.value;
    if (trail == null) return;
    _pendingGuideTrail.value = null;

    if (_recordingController.isRecording) {
      if (mounted) {
        _showError(AppLocalizations.of(context).commonErrorStopCurrentHike);
      }
      return;
    }

    TrackingState.instance.setGuideTrail(trail);
    await _recordingController.startRecording(
      onError: _showError,
      bgLocationDeniedMessage:
          AppLocalizations.of(context).trackBgLocationDenied,
      startFailedMessage: (detail) =>
          AppLocalizations.of(context).trackErrorCouldNotStart(detail),
    );
    if (mounted) {
      _onTabChanged(0);
    }
  }

  @override
  void dispose() {
    _pendingGuideTrail.removeListener(_onPendingGuideTrail);
    _pendingGuideTrail.dispose();
    IntentHandlerService.onTrailsImported = null;
    IntentHandlerService.onError = null;
    _lifecycleListener.dispose();
    AutoDataBridgeService.instance.dispose(_recordingController);
    _recordingController.dispose();
    _analyticsViewModel.dispose();
    TrackingState.instance.cancelStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabChanged,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.play_circle_outline),
                selectedIcon: const Icon(Icons.play_circle),
                label: l10n.navTrack,
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map),
                label: l10n.navMap,
              ),
              NavigationDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt),
                label: l10n.navLog,
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: l10n.navTrails,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart),
                label: l10n.navStats,
              ),
            ],
          );
        },
      ),
    );
  }
}
