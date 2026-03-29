import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @navTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get navTrack;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get navLog;

  /// No description provided for @navTrails.
  ///
  /// In en, this message translates to:
  /// **'Trails'**
  String get navTrails;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @trackAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Track Hike'**
  String get trackAppBarTitle;

  /// No description provided for @trackTileLat.
  ///
  /// In en, this message translates to:
  /// **'LAT'**
  String get trackTileLat;

  /// No description provided for @trackTileLon.
  ///
  /// In en, this message translates to:
  /// **'LON'**
  String get trackTileLon;

  /// No description provided for @trackTileAlt.
  ///
  /// In en, this message translates to:
  /// **'ALT'**
  String get trackTileAlt;

  /// No description provided for @trackTileTime.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get trackTileTime;

  /// No description provided for @trackTileDist.
  ///
  /// In en, this message translates to:
  /// **'DIST'**
  String get trackTileDist;

  /// No description provided for @trackTilePts.
  ///
  /// In en, this message translates to:
  /// **'PTS'**
  String get trackTilePts;

  /// No description provided for @trackTileTemp.
  ///
  /// In en, this message translates to:
  /// **'TEMP'**
  String get trackTileTemp;

  /// No description provided for @trackTileWeather.
  ///
  /// In en, this message translates to:
  /// **'WEATHER'**
  String get trackTileWeather;

  /// No description provided for @trackTilePressure.
  ///
  /// In en, this message translates to:
  /// **'PRESSURE'**
  String get trackTilePressure;

  /// No description provided for @trackTileSteps.
  ///
  /// In en, this message translates to:
  /// **'STEPS'**
  String get trackTileSteps;

  /// No description provided for @trackTileKcal.
  ///
  /// In en, this message translates to:
  /// **'KCAL'**
  String get trackTileKcal;

  /// No description provided for @trackTileSpeed.
  ///
  /// In en, this message translates to:
  /// **'SPEED'**
  String get trackTileSpeed;

  /// No description provided for @trackTileGps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get trackTileGps;

  /// No description provided for @trackStartHike.
  ///
  /// In en, this message translates to:
  /// **'Start Hike'**
  String get trackStartHike;

  /// No description provided for @trackStopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop & Save'**
  String get trackStopAndSave;

  /// No description provided for @trackSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get trackSaving;

  /// No description provided for @trackRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get trackRecording;

  /// No description provided for @trackPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get trackPause;

  /// No description provided for @trackResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get trackResume;

  /// No description provided for @trackPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get trackPaused;

  /// No description provided for @trackHikeSaved.
  ///
  /// In en, this message translates to:
  /// **'Hike saved!'**
  String get trackHikeSaved;

  /// No description provided for @trackNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get trackNotAvailable;

  /// No description provided for @logAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Hike Log'**
  String get logAppBarTitle;

  /// No description provided for @logAppBarTitleCount.
  ///
  /// In en, this message translates to:
  /// **'Hike Log ({count})'**
  String logAppBarTitleCount(int count);

  /// No description provided for @logSortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get logSortOldestFirst;

  /// No description provided for @logSortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get logSortNewestFirst;

  /// No description provided for @logEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No hikes yet'**
  String get logEmptyTitle;

  /// No description provided for @logEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start tracking your first hike!'**
  String get logEmptySubtitle;

  /// No description provided for @logSaveToTrailsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to Trails'**
  String get logSaveToTrailsDialogTitle;

  /// No description provided for @logSaveToTrailsFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Trail name'**
  String get logSaveToTrailsFieldLabel;

  /// No description provided for @logSavedToTrails.
  ///
  /// In en, this message translates to:
  /// **'Saved to Trails as \'{name}\''**
  String logSavedToTrails(String name);

  /// No description provided for @logDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Hike?'**
  String get logDeleteDialogTitle;

  /// No description provided for @logDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String logDeleteDialogContent(String name);

  /// No description provided for @logSaveToTrailsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save to Trails'**
  String get logSaveToTrailsTooltip;

  /// No description provided for @detailNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No route recorded'**
  String get detailNoRoute;

  /// No description provided for @detailLabelDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get detailLabelDate;

  /// No description provided for @detailLabelStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get detailLabelStart;

  /// No description provided for @detailLabelEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get detailLabelEnd;

  /// No description provided for @detailLabelDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get detailLabelDuration;

  /// No description provided for @detailLabelDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get detailLabelDistance;

  /// No description provided for @detailLabelGpsPoints.
  ///
  /// In en, this message translates to:
  /// **'GPS Points'**
  String get detailLabelGpsPoints;

  /// No description provided for @detailLabelNoGpsPoints.
  ///
  /// In en, this message translates to:
  /// **'No GPS points'**
  String get detailLabelNoGpsPoints;

  /// No description provided for @detailLabelSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get detailLabelSteps;

  /// No description provided for @detailLabelCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get detailLabelCalories;

  /// No description provided for @trailsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Trail Browser'**
  String get trailsAppBarTitle;

  /// No description provided for @trailsSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String trailsSelectionCount(int count);

  /// No description provided for @trailsSortAtoZ.
  ///
  /// In en, this message translates to:
  /// **'A → Z'**
  String get trailsSortAtoZ;

  /// No description provided for @trailsSortZtoA.
  ///
  /// In en, this message translates to:
  /// **'Z → A'**
  String get trailsSortZtoA;

  /// No description provided for @trailsCancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get trailsCancelSelection;

  /// No description provided for @trailsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get trailsSelectAll;

  /// No description provided for @trailsDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get trailsDeselectAll;

  /// No description provided for @trailsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export trails'**
  String get trailsExportTooltip;

  /// No description provided for @trailsImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import GPX / KML / XML'**
  String get trailsImportTooltip;

  /// No description provided for @trailsShareMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get trailsShareMenuItem;

  /// No description provided for @trailsSaveToDeviceMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get trailsSaveToDeviceMenuItem;

  /// No description provided for @trailsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No trails imported. Tap + to import a GPX, KML, or XML file.'**
  String get trailsEmptyState;

  /// No description provided for @trailsDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete trail?'**
  String get trailsDeleteDialogTitle;

  /// No description provided for @trailsDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? This cannot be undone.'**
  String trailsDeleteDialogContent(String name);

  /// No description provided for @trailsStartHikeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start hike on this trail'**
  String get trailsStartHikeTooltip;

  /// No description provided for @trailsFullScreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get trailsFullScreenTooltip;

  /// No description provided for @trailsCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get trailsCloseTooltip;

  /// No description provided for @trailsImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} trail(s) from {files} file(s)'**
  String trailsImportSuccess(int count, int files);

  /// No description provided for @trailsNoTrailsSelected.
  ///
  /// In en, this message translates to:
  /// **'No trails selected.'**
  String get trailsNoTrailsSelected;

  /// No description provided for @trailsNoTrailsToExport.
  ///
  /// In en, this message translates to:
  /// **'No trails to export.'**
  String get trailsNoTrailsToExport;

  /// No description provided for @trailsStoragePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Storage permission required to save files'**
  String get trailsStoragePermissionRequired;

  /// No description provided for @trailsSavedToPath.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String trailsSavedToPath(String path);

  /// No description provided for @statsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsAppBarTitle;

  /// No description provided for @statsAboutMenuItem.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get statsAboutMenuItem;

  /// No description provided for @statsSectionSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get statsSectionSummary;

  /// No description provided for @statsSectionPersonalBests.
  ///
  /// In en, this message translates to:
  /// **'Personal Bests'**
  String get statsSectionPersonalBests;

  /// No description provided for @statsSectionStreaks.
  ///
  /// In en, this message translates to:
  /// **'Streaks'**
  String get statsSectionStreaks;

  /// No description provided for @statsSectionDistanceByMonth.
  ///
  /// In en, this message translates to:
  /// **'Distance by Month'**
  String get statsSectionDistanceByMonth;

  /// No description provided for @statsSectionActivityByDay.
  ///
  /// In en, this message translates to:
  /// **'Activity by Day of Week'**
  String get statsSectionActivityByDay;

  /// No description provided for @statsSectionDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance Distribution'**
  String get statsSectionDistributionTitle;

  /// No description provided for @statsMetricTotalHikes.
  ///
  /// In en, this message translates to:
  /// **'Total Hikes'**
  String get statsMetricTotalHikes;

  /// No description provided for @statsMetricTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get statsMetricTotalDistance;

  /// No description provided for @statsMetricTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get statsMetricTotalTime;

  /// No description provided for @statsMetricAvgDistance.
  ///
  /// In en, this message translates to:
  /// **'Avg Distance'**
  String get statsMetricAvgDistance;

  /// No description provided for @statsMetricAvgDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg Duration'**
  String get statsMetricAvgDuration;

  /// No description provided for @statsMetricAvgPace.
  ///
  /// In en, this message translates to:
  /// **'Avg Pace'**
  String get statsMetricAvgPace;

  /// No description provided for @statsMetricLongestDistance.
  ///
  /// In en, this message translates to:
  /// **'Longest (distance)'**
  String get statsMetricLongestDistance;

  /// No description provided for @statsMetricLongestDuration.
  ///
  /// In en, this message translates to:
  /// **'Longest (duration)'**
  String get statsMetricLongestDuration;

  /// No description provided for @statsMetricTotalSteps.
  ///
  /// In en, this message translates to:
  /// **'Total Steps'**
  String get statsMetricTotalSteps;

  /// No description provided for @statsMetricBestDistance.
  ///
  /// In en, this message translates to:
  /// **'Best Distance'**
  String get statsMetricBestDistance;

  /// No description provided for @statsMetricBestPace.
  ///
  /// In en, this message translates to:
  /// **'Best Pace'**
  String get statsMetricBestPace;

  /// No description provided for @statsMetricMostActiveWeek.
  ///
  /// In en, this message translates to:
  /// **'Most Active Week'**
  String get statsMetricMostActiveWeek;

  /// No description provided for @statsMetricMostActiveWeekValue.
  ///
  /// In en, this message translates to:
  /// **'{count} hikes'**
  String statsMetricMostActiveWeekValue(int count);

  /// No description provided for @statsMetricMostSteps.
  ///
  /// In en, this message translates to:
  /// **'Most Steps'**
  String get statsMetricMostSteps;

  /// No description provided for @statsMetricCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get statsMetricCurrentStreak;

  /// No description provided for @statsMetricLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get statsMetricLongestStreak;

  /// No description provided for @statsStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String statsStreakDays(int count);

  /// No description provided for @statsEmptyPeriod.
  ///
  /// In en, this message translates to:
  /// **'No hikes in this period'**
  String get statsEmptyPeriod;

  /// No description provided for @statsEmptyNoHikes.
  ///
  /// In en, this message translates to:
  /// **'No hikes recorded yet'**
  String get statsEmptyNoHikes;

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get statsNoData;

  /// No description provided for @statsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get statsRetry;

  /// No description provided for @statsDistributionAxisLabel.
  ///
  /// In en, this message translates to:
  /// **'km per hike'**
  String get statsDistributionAxisLabel;

  /// No description provided for @statsFilterPreset7d.
  ///
  /// In en, this message translates to:
  /// **'7 d'**
  String get statsFilterPreset7d;

  /// No description provided for @statsFilterPreset30d.
  ///
  /// In en, this message translates to:
  /// **'30 d'**
  String get statsFilterPreset30d;

  /// No description provided for @statsFilterPreset3mo.
  ///
  /// In en, this message translates to:
  /// **'3 mo'**
  String get statsFilterPreset3mo;

  /// No description provided for @statsFilterPresetAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statsFilterPresetAll;

  /// No description provided for @statsDateStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get statsDateStart;

  /// No description provided for @statsDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsDateToday;

  /// No description provided for @splashRecoveryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfinished Hike Found'**
  String get splashRecoveryDialogTitle;

  /// No description provided for @splashRecoveryName.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String splashRecoveryName(String name);

  /// No description provided for @splashRecoveryStarted.
  ///
  /// In en, this message translates to:
  /// **'Started: {time}'**
  String splashRecoveryStarted(String time);

  /// No description provided for @splashRecoveryPoints.
  ///
  /// In en, this message translates to:
  /// **'GPS points: {count}'**
  String splashRecoveryPoints(int count);

  /// No description provided for @splashRecoveryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Would you like to resume or discard this hike?'**
  String get splashRecoveryQuestion;

  /// No description provided for @splashRecoveryResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get splashRecoveryResume;

  /// No description provided for @splashRecoveryDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get splashRecoveryDiscard;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Essential tools for hiking.'**
  String get aboutTagline;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonErrorStopCurrentHike.
  ///
  /// In en, this message translates to:
  /// **'Stop the current hike before starting a new one.'**
  String get commonErrorStopCurrentHike;

  /// No description provided for @trackBgLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'For screen-off tracking, allow location access \"All the time\" in Settings.'**
  String get trackBgLocationDenied;

  /// No description provided for @trailsImportSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped: unsupported format'**
  String trailsImportSkipped(int count);

  /// No description provided for @trailsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed to parse'**
  String trailsImportFailed(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
