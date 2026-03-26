import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/constants.dart';

class ForegroundTrackingService {
  static DateTime? _lastNotificationUpdate;

  /// Initialize the foreground task plugin. Call once from main().
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hike_tracking_channel',
        channelName: 'Hike Tracking',
        channelImportance: NotificationChannelImportance.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
  }

  /// Request background location + notification permissions.
  /// Returns true if background location is granted (non-fatal if notification denied).
  static Future<bool> requestPermissions() async {
    // Request notification permission (Android 13+, non-fatal if denied)
    await Permission.notification.request();

    // Request background location permission (must be done after foreground location)
    final bgStatus = await Permission.locationAlways.request();
    return bgStatus == PermissionStatus.granted;
  }

  /// Start the foreground service with an initial notification.
  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      serviceId: kForegroundServiceId,
      notificationTitle: 'Hike — Recording',
      notificationText: '00:00:00 — 0 m',
      callback: null,
    );
  }

  /// Update the notification content (throttled to max once per second).
  static Future<void> updateNotification({
    required Duration elapsed,
    required double distanceMeters,
  }) async {
    final now = DateTime.now();
    if (_lastNotificationUpdate != null &&
        now.difference(_lastNotificationUpdate!).inMilliseconds < 1000) {
      return;
    }
    _lastNotificationUpdate = now;

    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final distText = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
        : '${distanceMeters.toStringAsFixed(0)} m';

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Hike — Recording',
      notificationText: '$h:$m:$s — $distText',
    );
  }

  /// Acquires or releases the CPU wake lock.
  ///
  /// Called by [HikeRecordingController] and the lifecycle listener in
  /// [_HomePageState] to manage power state around screen-on/off transitions.
  static Future<void> setWakeLock(bool enabled) async {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  /// Stop the foreground service, dismiss the notification, and release
  /// the wake lock.
  static Future<void> stop() async {
    _lastNotificationUpdate = null;
    await WakelockPlus.disable();
    await FlutterForegroundTask.stopService();
  }
}
