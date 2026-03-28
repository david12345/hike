import 'package:flutter/services.dart';

import 'hike_recording_controller.dart';
import 'tracking_state.dart';

/// Bridges live GPS and compass data from [TrackingState] and
/// [HikeRecordingController.headingNotifier] to the native Android Auto
/// screen via a [MethodChannel].
///
/// The Kotlin side ([HikeCarScreen]) registers a handler on the same channel
/// to receive position/heading/altitude updates whenever they change.
///
/// Usage:
/// ```dart
/// // In _HomePageState.initState():
/// AutoDataBridgeService.instance.init(_recordingController);
///
/// // In _HomePageState.dispose():
/// AutoDataBridgeService.instance.dispose(_recordingController);
/// ```
class AutoDataBridgeService {
  AutoDataBridgeService._();

  static final instance = AutoDataBridgeService._();

  static const _channel = MethodChannel('com.dealmeida.hike/auto_data');

  HikeRecordingController? _controller;

  /// Subscribes to [TrackingState] and [hikeController.headingNotifier]
  /// and forwards updates to the native Android Auto screen.
  void init(HikeRecordingController hikeController) {
    _controller = hikeController;
    TrackingState.instance.addListener(_onTrackingChanged);
    hikeController.headingNotifier.addListener(_onHeadingChanged);
  }

  /// Removes all listeners registered in [init].
  ///
  /// Must be called with the same [hikeController] instance that was passed
  /// to [init].
  void dispose(HikeRecordingController hikeController) {
    TrackingState.instance.removeListener(_onTrackingChanged);
    hikeController.headingNotifier.removeListener(_onHeadingChanged);
    _controller = null;
  }

  void _onTrackingChanged() {
    final controller = _controller;
    if (controller == null) return;
    _send(TrackingState.instance, controller);
  }

  void _onHeadingChanged() {
    final controller = _controller;
    if (controller == null) return;
    _send(TrackingState.instance, controller);
  }

  Future<void> _send(
    TrackingState ts,
    HikeRecordingController hikeController,
  ) async {
    final pos = ts.ambientPosition;
    try {
      await _channel.invokeMethod<void>('update', {
        'lat': pos?.latitude ?? 0.0,
        'lon': pos?.longitude ?? 0.0,
        'alt': ts.ambientAltitude,
        'heading': hikeController.headingNotifier.value ?? -1.0,
        'hasPosition': pos != null,
      });
    } catch (_) {
      // Android Auto not connected — ignore silently.
    }
  }
}
