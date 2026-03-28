import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'models/hike_record.dart';
import 'models/osm_trail.dart';
import 'screens/track_screen.dart';
import 'screens/map_screen.dart';
import 'screens/log_screen.dart';
import 'screens/trails_screen.dart';
import 'screens/about_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auto_data_bridge_service.dart';
import 'services/foreground_tracking_service.dart';
import 'services/hike_recording_controller.dart';
import 'services/intent_handler_service.dart';
import 'services/tile_preference_service.dart';
import 'services/tracking_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en';
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
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
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
  late final AppLifecycleListener _lifecycleListener;
  final ValueNotifier<OsmTrail?> _pendingGuideTrail = ValueNotifier(null);

  void _onAboutTap() {
    setState(() => _currentIndex = 0);
  }

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
    _recordingController.init();
    AutoDataBridgeService.instance.init(_recordingController);
    _pendingGuideTrail.addListener(_onPendingGuideTrail);

    if (widget.unfinishedHike != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordingController.resumeFromRecord(
          widget.unfinishedHike!,
          onError: _showError,
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
    ];
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
      _showError('Stop the current hike before starting a new one.');
      return;
    }

    TrackingState.instance.setGuideTrail(trail);
    await _recordingController.startRecording(onError: _showError);
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
    TrackingState.instance.cancelStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ..._screens,
          AboutScreen(onTap: _onAboutTap),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Trails',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'About',
          ),
        ],
      ),
    );
  }
}
