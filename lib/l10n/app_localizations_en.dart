// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navTrack => 'Track';

  @override
  String get navMap => 'Map';

  @override
  String get navLog => 'Log';

  @override
  String get navTrails => 'Trails';

  @override
  String get navStats => 'Stats';

  @override
  String get trackAppBarTitle => 'Track Hike';

  @override
  String get trackTileLat => 'LAT';

  @override
  String get trackTileLon => 'LON';

  @override
  String get trackTileAlt => 'ALT';

  @override
  String get trackTileTime => 'TIME';

  @override
  String get trackTileDist => 'DIST';

  @override
  String get trackTilePts => 'PTS';

  @override
  String get trackTileTemp => 'TEMP';

  @override
  String get trackTileWeather => 'WEATHER';

  @override
  String get trackTilePressure => 'PRESSURE';

  @override
  String get trackTileSteps => 'STEPS';

  @override
  String get trackTileKcal => 'KCAL';

  @override
  String get trackTileSpeed => 'SPEED';

  @override
  String get trackTileGps => 'GPS';

  @override
  String get trackStartHike => 'Start Hike';

  @override
  String get trackStopAndSave => 'Stop & Save';

  @override
  String get trackSaving => 'Saving...';

  @override
  String get trackRecording => 'Recording...';

  @override
  String get trackPause => 'Pause';

  @override
  String get trackResume => 'Resume';

  @override
  String get trackPaused => 'Paused';

  @override
  String get trackHikeSaved => 'Hike saved!';

  @override
  String get trackNotAvailable => 'N/A';

  @override
  String get logAppBarTitle => 'Hike Log';

  @override
  String logAppBarTitleCount(int count) {
    return 'Hike Log ($count)';
  }

  @override
  String get logSortOldestFirst => 'Oldest first';

  @override
  String get logSortNewestFirst => 'Newest first';

  @override
  String get logEmptyTitle => 'No hikes yet';

  @override
  String get logEmptySubtitle => 'Start tracking your first hike!';

  @override
  String get logSaveToTrailsDialogTitle => 'Save to Trails';

  @override
  String get logSaveToTrailsFieldLabel => 'Trail name';

  @override
  String logSavedToTrails(String name) {
    return 'Saved to Trails as \'$name\'';
  }

  @override
  String get logDeleteDialogTitle => 'Delete Hike?';

  @override
  String logDeleteDialogContent(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get logSaveToTrailsTooltip => 'Save to Trails';

  @override
  String get detailNoRoute => 'No route recorded';

  @override
  String get trailsAppBarTitle => 'Trail Browser';

  @override
  String trailsSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get trailsSortAtoZ => 'A → Z';

  @override
  String get trailsSortZtoA => 'Z → A';

  @override
  String get trailsCancelSelection => 'Cancel selection';

  @override
  String get trailsSelectAll => 'Select all';

  @override
  String get trailsDeselectAll => 'Deselect all';

  @override
  String get trailsExportTooltip => 'Export trails';

  @override
  String get trailsImportTooltip => 'Import GPX / KML / XML';

  @override
  String get trailsShareMenuItem => 'Share';

  @override
  String get trailsSaveToDeviceMenuItem => 'Save to device';

  @override
  String get trailsEmptyState =>
      'No trails imported. Tap + to import a GPX, KML, or XML file.';

  @override
  String get trailsDeleteDialogTitle => 'Delete trail?';

  @override
  String trailsDeleteDialogContent(String name) {
    return 'Remove \"$name\"? This cannot be undone.';
  }

  @override
  String get trailsStartHikeTooltip => 'Start hike on this trail';

  @override
  String get trailsFullScreenTooltip => 'Full screen';

  @override
  String get trailsCloseTooltip => 'Close';

  @override
  String trailsImportSuccess(int count, int files) {
    return 'Imported $count trail(s) from $files file(s)';
  }

  @override
  String get trailsNoTrailsSelected => 'No trails selected.';

  @override
  String get trailsNoTrailsToExport => 'No trails to export.';

  @override
  String get trailsStoragePermissionRequired =>
      'Storage permission required to save files';

  @override
  String trailsSavedToPath(String path) {
    return 'Saved to $path';
  }

  @override
  String get statsAppBarTitle => 'Stats';

  @override
  String get statsAboutMenuItem => 'About';

  @override
  String get statsSectionSummary => 'Summary';

  @override
  String get statsSectionPersonalBests => 'Personal Bests';

  @override
  String get statsSectionStreaks => 'Streaks';

  @override
  String get statsSectionDistanceByMonth => 'Distance by Month';

  @override
  String get statsSectionActivityByDay => 'Activity by Day of Week';

  @override
  String get statsSectionDistributionTitle => 'Distance Distribution';

  @override
  String get statsMetricTotalHikes => 'Total Hikes';

  @override
  String get statsMetricTotalDistance => 'Total Distance';

  @override
  String get statsMetricTotalTime => 'Total Time';

  @override
  String get statsMetricAvgDistance => 'Avg Distance';

  @override
  String get statsMetricAvgDuration => 'Avg Duration';

  @override
  String get statsMetricAvgPace => 'Avg Pace';

  @override
  String get statsMetricLongestDistance => 'Longest (distance)';

  @override
  String get statsMetricLongestDuration => 'Longest (duration)';

  @override
  String get statsMetricTotalSteps => 'Total Steps';

  @override
  String get statsMetricBestDistance => 'Best Distance';

  @override
  String get statsMetricBestPace => 'Best Pace';

  @override
  String get statsMetricMostActiveWeek => 'Most Active Week';

  @override
  String statsMetricMostActiveWeekValue(int count) {
    return '$count hikes';
  }

  @override
  String get statsMetricMostSteps => 'Most Steps';

  @override
  String get statsMetricCurrentStreak => 'Current Streak';

  @override
  String get statsMetricLongestStreak => 'Longest Streak';

  @override
  String statsStreakDays(int count) {
    return '$count days';
  }

  @override
  String get statsEmptyPeriod => 'No hikes in this period';

  @override
  String get statsEmptyNoHikes => 'No hikes recorded yet';

  @override
  String get statsNoData => 'No data for this period';

  @override
  String get statsRetry => 'Retry';

  @override
  String get statsDistributionAxisLabel => 'km per hike';

  @override
  String get statsFilterPreset7d => '7 d';

  @override
  String get statsFilterPreset30d => '30 d';

  @override
  String get statsFilterPreset3mo => '3 mo';

  @override
  String get statsFilterPresetAll => 'All';

  @override
  String get statsDateStart => 'Start';

  @override
  String get statsDateToday => 'Today';

  @override
  String get splashRecoveryDialogTitle => 'Unfinished Hike Found';

  @override
  String splashRecoveryName(String name) {
    return 'Name: $name';
  }

  @override
  String splashRecoveryStarted(String time) {
    return 'Started: $time';
  }

  @override
  String splashRecoveryPoints(int count) {
    return 'GPS points: $count';
  }

  @override
  String get splashRecoveryQuestion =>
      'Would you like to resume or discard this hike?';

  @override
  String get splashRecoveryResume => 'Resume';

  @override
  String get splashRecoveryDiscard => 'Discard';

  @override
  String get aboutTagline => 'Essential tools for hiking.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String get commonErrorStopCurrentHike =>
      'Stop the current hike before starting a new one.';
}
