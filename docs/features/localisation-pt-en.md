# localisation-pt-en.md

## User Story

As a hiker whose device is set to Portuguese (Portugal), I want the Hike app to display all labels, buttons, messages, and dialogs in Portuguese so that I can use the app comfortably in my native language. As an English-speaking hiker, I want the app to default to English when the device locale is not Portuguese, so that nothing changes for me.

---

## Background / Problem

The app currently hardcodes `locale: const Locale('en')` in `MaterialApp`, forces `Locale.ENGLISH` inside `MainActivity.attachBaseContext`, and strips all non-English Android resources with `resConfigs("en")` in `build.gradle.kts`. This was a deliberate workaround to keep the SAF file/folder picker in English. It prevents device-locale-aware display entirely.

The project already has `flutter_localizations` (sdk: flutter) and `intl: ^0.20.2` in `pubspec.yaml`. No new package dependencies are needed. The missing pieces are:

- An `l10n.yaml` configuration file
- ARB message catalogues (`app_en.arb`, `app_pt.arb`)
- Externalising all hardcoded UI strings behind generated `AppLocalizations` accessors
- Removing the three English-forcing hacks

---

## Scope

- Supported locales: `en` (English, default) and `pt` (Portuguese — Portugal).
- Locale source: device locale only. If the device language starts with `pt` (any region variant: `pt_PT`, `pt_BR`, etc.), the app renders in Portuguese; otherwise it renders in English.
- No in-app language toggle or settings screen.
- No iOS support.
- No RTL support.
- No other languages beyond `en` and `pt`.

---

## Requirements

### R1 — gen-l10n pipeline

1. Create `l10n.yaml` at the project root with the following content:

   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   output-class: AppLocalizations
   output-dir: lib/l10n
   synthetic-package: false
   nullable-getter: false
   ```

   `synthetic-package: false` places the generated files in `lib/l10n/` rather than the hidden `.dart_tool` location, which is consistent with the project's existing practice of committing generated files (`hike_record.g.dart`).

2. Add `generate: true` under the `flutter:` key in `pubspec.yaml`.

3. Create `lib/l10n/app_en.arb` and `lib/l10n/app_pt.arb` containing all keys listed in R4.

4. Run `flutter gen-l10n` after creating the ARB files. This produces:
   - `lib/l10n/app_localizations.dart` (router)
   - `lib/l10n/app_localizations_en.dart`
   - `lib/l10n/app_localizations_pt.dart`

   Generated files must not be edited manually. Commit them alongside the ARB files.

### R2 — MaterialApp wiring (`lib/main.dart`)

1. Remove `Intl.defaultLocale = 'en'` from `main()`.

2. In `HikeApp.build`, remove the hardcoded `locale: const Locale('en')` and `supportedLocales: const [Locale('en')]`.

3. Set:

   ```dart
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
   ```

   `AppLocalizations.localizationsDelegates` already includes `GlobalMaterialLocalizations.delegate`, `GlobalWidgetsLocalizations.delegate`, and `GlobalCupertinoLocalizations.delegate`, so the existing explicit list in `localizationsDelegates` can be removed.

4. Import `package:hike/l10n/app_localizations.dart`.

### R3 — Android-layer changes

1. **`android/app/build.gradle.kts`**: change `resConfigs("en")` to `resConfigs("en", "pt")`. This stops Gradle from stripping Portuguese string resources from the APK.

2. **`android/app/src/main/kotlin/com/dealmeida/hike/MainActivity.kt`**: remove the entire `attachBaseContext` override. The SAF file/folder picker will render in the device locale, which is acceptable now that English is no longer artificially forced.

### R4 — String externalisation

Every user-visible hardcoded string in every screen and widget must be replaced with `AppLocalizations.of(context).<key>` (non-nullable because `nullable-getter: false`).

#### ARB key naming convention

Keys use `lowerCamelCase` with a screen/component prefix:

| Prefix | Scope |
|--------|-------|
| `nav` | Bottom navigation bar labels |
| `track` | Track screen |
| `log` | Log screen |
| `detail` | Hike detail screen |
| `trails` | Trails screen |
| `stats` | Stats / Analytics screen |
| `about` | About screen and AboutContent widget |
| `splash` | Splash screen / crash-recovery dialog |
| `common` | Strings shared across multiple screens |

#### Navigation bar (`lib/main.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `navTrack` | Track | Rastreio |
| `navMap` | Map | Mapa |
| `navLog` | Log | Registo |
| `navTrails` | Trails | Trilhos |
| `navStats` | Stats | Estatísticas |

#### Track screen (`lib/screens/track_screen.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `trackAppBarTitle` | Track Hike | Rastrear Caminhada |
| `trackTileLat` | LAT | LAT |
| `trackTileLon` | LON | LON |
| `trackTileAlt` | ALT | ALT |
| `trackTileTime` | TIME | TEMPO |
| `trackTileDist` | DIST | DIST |
| `trackTilePts` | PTS | PTS |
| `trackTileTemp` | TEMP | TEMP |
| `trackTileWeather` | WEATHER | TEMPO |
| `trackTilePressure` | PRESSURE | PRESSÃO |
| `trackTileSteps` | STEPS | PASSOS |
| `trackTileKcal` | KCAL | KCAL |
| `trackTileSpeed` | SPEED | VEL. |
| `trackTileGps` | GPS | GPS |
| `trackStartHike` | Start Hike | Iniciar Caminhada |
| `trackStopAndSave` | Stop & Save | Parar e Guardar |
| `trackSaving` | Saving... | A guardar... |
| `trackRecording` | Recording... | A gravar... |
| `trackHikeSaved` | Hike saved! | Caminhada guardada! |
| `trackNotAvailable` | N/A | N/D |

Note: technical abbreviations LAT, LON, ALT, PTS, KCAL are widely understood and may remain identical in both locales. Portuguese translations are provided as suggestions; the implementer may adjust at their discretion.

#### Log screen (`lib/screens/log_screen.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `logAppBarTitle` | Hike Log | Registo de Caminhadas |
| `logAppBarTitleCount` | Hike Log ({count}) | Registo ({count}) |
| `logSortOldestFirst` | Oldest first | Mais antigo primeiro |
| `logSortNewestFirst` | Newest first | Mais recente primeiro |
| `logEmptyTitle` | No hikes yet | Ainda sem caminhadas |
| `logEmptySubtitle` | Start tracking your first hike! | Comece a registar a sua primeira caminhada! |
| `logSaveToTrailsDialogTitle` | Save to Trails | Guardar em Trilhos |
| `logSaveToTrailsFieldLabel` | Trail name | Nome do trilho |
| `logSavedToTrails` | Saved to Trails as '{name}' | Guardado em Trilhos como '{name}' |
| `logDeleteDialogTitle` | Delete Hike? | Eliminar Caminhada? |
| `logDeleteDialogContent` | Delete "{name}"? | Eliminar "{name}"? |
| `logSaveToTrailsTooltip` | Save to Trails | Guardar em Trilhos |

`logAppBarTitleCount` uses an ICU placeholder `{count}` (integer).

`logSavedToTrails` and `logDeleteDialogContent` use an ICU placeholder `{name}` (string).

#### Hike detail screen (`lib/screens/hike_detail_screen.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `detailNoRoute` | No route recorded | Sem rota registada |

#### Trails screen (`lib/screens/trails_screen.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `trailsAppBarTitle` | Trail Browser | Navegador de Trilhos |
| `trailsSelectionCount` | {count} selected | {count} selecionados |
| `trailsSortAtoZ` | A → Z | A → Z |
| `trailsSortZtoA` | Z → A | Z → A |
| `trailsCancelSelection` | Cancel selection | Cancelar seleção |
| `trailsSelectAll` | Select all | Selecionar tudo |
| `trailsDeselectAll` | Deselect all | Desmarcar tudo |
| `trailsExportTooltip` | Export trails | Exportar trilhos |
| `trailsImportTooltip` | Import GPX / KML / XML | Importar GPX / KML / XML |
| `trailsShareMenuItem` | Share | Partilhar |
| `trailsSaveToDeviceMenuItem` | Save to device | Guardar no dispositivo |
| `trailsEmptyState` | No trails imported. Tap + to import a GPX, KML, or XML file. | Sem trilhos importados. Toque em + para importar um ficheiro GPX, KML ou XML. |
| `trailsDeleteDialogTitle` | Delete trail? | Eliminar trilho? |
| `trailsDeleteDialogContent` | Remove "{name}"? This cannot be undone. | Remover "{name}"? Esta ação não pode ser desfeita. |
| `trailsStartHikeTooltip` | Start hike on this trail | Iniciar caminhada neste trilho |
| `trailsFullScreenTooltip` | Full screen | Ecrã completo |
| `trailsCloseTooltip` | Close | Fechar |
| `trailsImportSuccess` | Imported {count} trail(s) from {files} file(s) | Importados {count} trilho(s) de {files} ficheiro(s) |
| `trailsNoTrailsSelected` | No trails selected. | Nenhum trilho selecionado. |
| `trailsNoTrailsToExport` | No trails to export. | Sem trilhos para exportar. |
| `trailsStoragePermissionRequired` | Storage permission required to save files | Permissão de armazenamento necessária para guardar ficheiros |
| `trailsSavedToPath` | Saved to {path} | Guardado em {path} |

#### Stats / Analytics screen (`lib/screens/analytics_screen.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `statsAppBarTitle` | Stats | Estatísticas |
| `statsAboutMenuItem` | About | Sobre |
| `statsSectionSummary` | Summary | Resumo |
| `statsSectionPersonalBests` | Personal Bests | Melhores Marcas |
| `statsSectionStreaks` | Streaks | Sequências |
| `statsSectionDistanceByMonth` | Distance by Month | Distância por Mês |
| `statsSectionActivityByDay` | Activity by Day of Week | Atividade por Dia da Semana |
| `statsSectionDistributionTitle` | Distance Distribution | Distribuição de Distância |
| `statsMetricTotalHikes` | Total Hikes | Total de Caminhadas |
| `statsMetricTotalDistance` | Total Distance | Distância Total |
| `statsMetricTotalTime` | Total Time | Tempo Total |
| `statsMetricAvgDistance` | Avg Distance | Distância Média |
| `statsMetricAvgDuration` | Avg Duration | Duração Média |
| `statsMetricAvgPace` | Avg Pace | Ritmo Médio |
| `statsMetricLongestDistance` | Longest (distance) | Mais Longa (distância) |
| `statsMetricLongestDuration` | Longest (duration) | Mais Longa (duração) |
| `statsMetricTotalSteps` | Total Steps | Total de Passos |
| `statsMetricBestDistance` | Best Distance | Melhor Distância |
| `statsMetricBestPace` | Best Pace | Melhor Ritmo |
| `statsMetricMostActiveWeek` | Most Active Week | Semana Mais Ativa |
| `statsMetricMostActiveWeekValue` | {count} hikes | {count} caminhadas |
| `statsMetricMostSteps` | Most Steps | Mais Passos |
| `statsMetricCurrentStreak` | Current Streak | Sequência Atual |
| `statsMetricLongestStreak` | Longest Streak | Maior Sequência |
| `statsStreakDays` | {count} days | {count} dias |
| `statsEmptyPeriod` | No hikes in this period | Sem caminhadas neste período |
| `statsEmptyNoHikes` | No hikes recorded yet | Ainda sem caminhadas registadas |
| `statsNoData` | No data for this period | Sem dados para este período |
| `statsDistributionAxisLabel` | km per hike | km por caminhada |
| `statsFilterPreset7d` | 7 d | 7 d |
| `statsFilterPreset30d` | 30 d | 30 d |
| `statsFilterPreset3mo` | 3 mo | 3 meses |
| `statsFilterPresetAll` | All | Todos |
| `statsDateStart` | Start | Início |
| `statsDateToday` | Today | Hoje |

`statsStreakDays` and `statsMetricMostActiveWeekValue` use ICU plural syntax where appropriate (see ARB `@statsStreakDays` metadata with `placeholders`).

#### Splash screen / crash-recovery dialog (`lib/screens/splash_screen.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `splashRecoveryDialogTitle` | Unfinished Hike Found | Caminhada Inacabada Encontrada |
| `splashRecoveryName` | Name: {name} | Nome: {name} |
| `splashRecoveryStarted` | Started: {time} | Iniciada: {time} |
| `splashRecoveryPoints` | GPS points: {count} | Pontos GPS: {count} |
| `splashRecoveryQuestion` | Would you like to resume or discard this hike? | Deseja retomar ou descartar esta caminhada? |
| `splashRecoveryResume` | Resume | Retomar |
| `splashRecoveryDiscard` | Discard | Descartar |

#### About screen / AboutContent widget (`lib/widgets/about_content.dart`)

| Key | English | Portuguese |
|-----|---------|-----------|
| `aboutTagline` | Essential tools for hiking. | Ferramentas essenciais para caminhadas. |

The app name `'Hike'`, the GitHub URL, and the contact email address are not translated.

#### Common / shared strings

| Key | English | Portuguese |
|-----|---------|-----------|
| `commonCancel` | Cancel | Cancelar |
| `commonSave` | Save | Guardar |
| `commonDelete` | Delete | Eliminar |
| `commonClose` | Close | Fechar |
| `commonOk` | OK | OK |
| `commonErrorStopCurrentHike` | Stop the current hike before starting a new one. | Pare a caminhada atual antes de iniciar uma nova. |

### R5 — Date and number formatting

1. All `DateFormat` instances that produce UI-visible output must pass the resolved locale string. The resolved locale is available from `Localizations.localeOf(context).toString()` or by reading `Intl.defaultLocale` (which is kept in sync by `localeResolutionCallback` per R2).

2. The log screen date format `DateFormat('MMM d, y \u2022 HH:mm')` must become `DateFormat('MMM d, y \u2022 HH:mm', locale)`.

3. `pt_PT` uses a comma as the decimal separator and `dd/MM/yyyy` for dates. `DateFormat` and `NumberFormat` from `package:intl` handle this automatically when the correct locale string is passed.

4. **`MonthlyBucket.shortLabel` in `lib/services/analytics_service.dart`**: the current hardcoded English month abbreviation array must be replaced. At the chart render site in `analytics_screen.dart`, use `DateFormat('MMM', resolvedLocale).format(DateTime(bucket.year, bucket.month))` to produce locale-aware short month names.

5. **Day-of-week chart labels** in `_DayOfWeekChart`: the hardcoded `['Mon','Tue','Wed','Thu','Fri','Sat','Sun']` array must be replaced with locale-aware names generated via `DateFormat('E', resolvedLocale)`. Use a reference Monday (e.g. `DateTime(2024, 1, 1)`) and step through the week to build the label list, so `intl` supplies the correct abbreviations for both locales.

6. **`AnalyticsFilterPreset.label`** getter (values `'7 d'`, `'30 d'`, `'3 mo'`, `'All'`) must be replaced with a `localizedLabel(AppLocalizations l10n)` method that returns the corresponding ARB key value (`statsFilterPreset7d`, etc.).

### R6 — Strings that must NOT be translated

- Hike names auto-generated at recording start (e.g. `'Hike 2026-03-28'`) are stored in Hive and must stay in English regardless of locale so that historical records remain consistent.
- GPS/sensor unit labels used in formatted values (m, km, km/h, hPa, °C) are universal and do not require translation.
- Error messages from third-party libraries (Geolocator, Hive, file_picker, etc.) are not translated.
- The app name `'Hike'` in `MaterialApp.title` and `AboutContent` is not translated.

---

## Migration Notes

### `resConfigs` Gradle line

The `resConfigs("en")` line in `android/app/build.gradle.kts` `defaultConfig` was added (in the `force-english-locale.md` spec) to strip non-English Android system resources from the APK and make the SAF picker render in English. Changing it to `resConfigs("en", "pt")` allows Portuguese Android string tables to be included in the APK. The SAF picker will now render in the device locale, which is acceptable — the file types the app imports (GPX, KML, XML) have no locale-specific naming that would cause confusion.

### `MainActivity.attachBaseContext` removal

The `attachBaseContext` override in `MainActivity.kt` forces `Locale.ENGLISH` on the Android `Context` before Flutter starts. Removing it means the system locale is used for any Android-native UI (the SAF folder picker, share sheet). This is a deliberate regression of the force-english-locale feature, accepted as the price of Portuguese support.

### Existing `app-bilingual-localisation.md` spec

`docs/features/app-bilingual-localisation.md` covers the same feature with an added in-app language-override toggle. That spec is a superset of this one. This spec (`localisation-pt-en.md`) is the minimal, device-locale-only version. If the in-app toggle is later desired, the override mechanism described in the bilingual spec can be layered on top.

---

## Implementation Checklist

- [ ] `l10n.yaml` created at project root.
- [ ] `generate: true` added to `pubspec.yaml` under `flutter:`.
- [ ] `lib/l10n/app_en.arb` created with all keys from R4.
- [ ] `lib/l10n/app_pt.arb` created with Portuguese translations for all keys.
- [ ] `flutter gen-l10n` runs without errors and produces `lib/l10n/app_localizations*.dart`.
- [ ] `Intl.defaultLocale = 'en'` removed from `main()`.
- [ ] `locale: const Locale('en')` removed from `MaterialApp`.
- [ ] `supportedLocales`, `localizationsDelegates`, and `localeResolutionCallback` wired as specified in R2.
- [ ] `attachBaseContext` override removed from `MainActivity.kt`.
- [ ] `resConfigs("en")` replaced with `resConfigs("en", "pt")` in `build.gradle.kts`.
- [ ] All hardcoded strings in every screen and widget replaced with `AppLocalizations.of(context).<key>`.
- [ ] `DateFormat` instances in Log and Analytics screens pass the resolved locale.
- [ ] `MonthlyBucket.shortLabel` replaced with locale-aware formatting at the call site.
- [ ] Day-of-week chart labels generated via `DateFormat('E', resolvedLocale)`.
- [ ] `AnalyticsFilterPreset.label` replaced with `localizedLabel(AppLocalizations)`.
- [ ] `flutter analyze` reports no new warnings or errors.
- [ ] With device locale `pt-PT`: all five tabs, all dialogs, and the crash-recovery dialog display Portuguese strings.
- [ ] With device locale `en-US`: all five tabs, all dialogs, and the crash-recovery dialog display English strings.
- [ ] Month names in the Distance by Month chart render in the active locale.
- [ ] Day-of-week labels in the Activity chart render in the active locale.
- [ ] Hike names auto-generated at recording start remain in English regardless of locale.
- [ ] The About screen tagline changes with locale.
