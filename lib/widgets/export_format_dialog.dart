import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/export_format.dart';

/// Shows a dialog asking the user to choose an export format.
///
/// Returns [ExportFormat.gpx] or [ExportFormat.kml] when the user picks a
/// format, or `null` if the user dismisses the dialog.
Future<ExportFormat?> showExportFormatDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<ExportFormat>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.exportFormatDialogTitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ExportFormat.gpx),
          child: Text(l10n.exportFormatGpx),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ExportFormat.kml),
          child: Text(l10n.exportFormatKml),
        ),
      ],
    ),
  );
}
