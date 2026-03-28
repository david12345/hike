# trails-import-export-service.md

## User Story

As a developer maintaining the Hike app, I want all file I/O and platform interaction on the Trails screen to live in a dedicated service, so that the widget is a pure View and the import/export logic can be tested and reused without a running Flutter widget.

## Background / Problem

Analysis report item **H1b**.

`lib/screens/trails_screen.dart` is 1 015 lines long. Approximately 150+ of those lines are platform I/O wired directly into widget `State`: file picker calls, ZIP archive creation, share sheet invocation, `DeviceInfoPlugin` SDK-version checks, and storage-permission negotiation. None of this logic is testable without a full widget test. The screen also has no testable seam for mocking platform responses.

## Requirements

1. Create `lib/services/trails_import_export_service.dart` containing `TrailsImportExportService`.
2. The service must own the following responsibilities currently in `TrailsScreen`:
   - `importFile()` — file picker invocation, GPX/KML/XML dispatch to parsers, deduplication check, `ImportedTrailRepository` save.
   - `exportTrails(List<ImportedTrail>)` — ZIP creation, `share_plus` invocation.
   - `saveTrailsToDevice(List<ImportedTrail>, String folderPath)` — folder picker, permission check, `DeviceInfoPlugin` SDK check, ZIP write to device storage.
3. The service exposes a result type (sealed class or enum) for each operation so the caller can show appropriate snack bars without knowing platform details.
4. `DeviceInfoPlugin` SDK check for Android storage permission is encapsulated inside the service and not duplicated in the widget.
5. `TrailsScreen` calls service methods and handles only the result enum to drive UI feedback.
6. The service has no direct dependency on `BuildContext` — any required scaffolding (e.g. scaffold messenger) is communicated through the result type to the widget.
7. Error paths (file not found, parse error, permission denied) are communicated through the result type and also logged with `debugPrint`.

## Non-Goals

- Extracting `ImportedTrailService` or `ImportedTrailRepository` (already done in `split-imported-trail-service.md`).
- Implementing a full ViewModel for `TrailsScreen` (deferred — see `trails-viewmodel-extraction.md`).
- Changing the GPX/KML parsers themselves.

## Design / Implementation Notes

**New file:** `lib/services/trails_import_export_service.dart`

**Files to touch:**
- `lib/screens/trails_screen.dart` — replace inline I/O with service calls; keep only UI logic.

**Result type sketch:**

```dart
sealed class ImportResult {
  const ImportResult();
}
class ImportSuccess extends ImportResult {
  final int count;
  const ImportSuccess(this.count);
}
class ImportDuplicate extends ImportResult {
  final String name;
  const ImportDuplicate(this.name);
}
class ImportFailure extends ImportResult {
  final String message;
  const ImportFailure(this.message);
}
```

Similar sealed classes for export and save-to-device results.

**Dependency:** `TrailsImportExportService` may depend on `ImportedTrailService` (already injected or accessed via singleton) and `GpxExporter`.

## Acceptance Criteria

- [ ] `lib/services/trails_import_export_service.dart` exists.
- [ ] `TrailsScreen` contains no direct `FilePicker`, `ZipEncoder`, `SharePlus`, `DeviceInfoPlugin`, or permission-plugin calls.
- [ ] `TrailsImportExportService.importFile()` can be called in a unit test with a mock file path and returns an `ImportResult` without a widget tree.
- [ ] Error paths (parse failure, permission denied) return typed result values and emit a `debugPrint` log.
- [ ] Existing import/export behaviour (file picker, ZIP, share, folder picker, SDK check) is functionally identical after the refactor.
- [ ] `flutter analyze` reports zero issues.
