import 'package:package_info_plus/package_info_plus.dart';

/// Provides cached app version information resolved once at launch.
///
/// Follows the singleton pattern used by other services in the project
/// ([TilePreferenceService], [TrackingState]).
class AppInfoService {
  AppInfoService._();

  static final AppInfoService instance = AppInfoService._();

  String _version = '';

  /// The app version string (e.g. "v1.27.0"). Empty string before [init].
  String get version => _version;

  /// Resolves app version from the platform. Called once from [SplashScreen].
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _version = 'v${info.version}';
  }
}
