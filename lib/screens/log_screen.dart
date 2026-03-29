import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/hike_record.dart';
import '../services/hike_service.dart';
import '../services/imported_trail_service.dart';
import '../services/user_preferences_service.dart';
import 'hike_detail_screen.dart';

/// Returns a localised date format for hike start times.
DateFormat _hikeDateFormat(String locale) =>
    DateFormat('MMM d, y \u2022 HH:mm', locale);

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPreferencesService.instance,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: HikeService.version,
          builder: (context, _) {
            final prefs = UserPreferencesService.instance;
            final sortDescending =
                prefs.logSortOrder == LogSortOrder.descending;
            final hikes = HikeService.getAll()
              ..sort((a, b) => sortDescending
                  ? b.startTime.compareTo(a.startTime)
                  : a.startTime.compareTo(b.startTime));

            return _LogScaffold(
              hikes: hikes,
              sortDescending: sortDescending,
            );
          },
        );
      },
    );
  }
}

class _LogScaffold extends StatelessWidget {
  final List<HikeRecord> hikes;
  final bool sortDescending;

  const _LogScaffold({required this.hikes, required this.sortDescending});

  AppBar _buildAppBar(BuildContext context, int hikeCount) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      title: Text(hikeCount == 0
          ? l10n.logAppBarTitle
          : l10n.logAppBarTitleCount(hikeCount)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
              sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
          tooltip: sortDescending
              ? l10n.logSortOldestFirst
              : l10n.logSortNewestFirst,
          onPressed: UserPreferencesService.instance.toggleLogSortOrder,
        ),
      ],
    );
  }

  Future<void> _saveToTrails(BuildContext context, HikeRecord hike) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: hike.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logSaveToTrailsDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(labelText: l10n.logSaveToTrailsFieldLabel),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted) return;
    if (name == null || name.isEmpty) return;
    final trail =
        ImportedTrailService.fromHikeRecord(hike, nameOverride: name);
    await ImportedTrailService.save(trail);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.logSavedToTrails(name))),
    );
  }

  Future<void> _delete(BuildContext context, HikeRecord hike) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.logDeleteDialogTitle),
        content: Text(l10n.logDeleteDialogContent(hike.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await HikeService.delete(hike.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    if (hikes.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(context, 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hiking, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(l10n.logEmptyTitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 18)),
              const SizedBox(height: 8),
              Text(l10n.logEmptySubtitle,
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context, hikes.length),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: hikes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final hike = hikes[i];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.terrain)),
              title: Text(hike.name),
              subtitle: Text(
                _hikeDateFormat(locale).format(hike.startTime),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(hike.distanceFormatted,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(hike.durationFormatted,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      if (hike.steps > 0) ...[
                        Text(
                          hike.stepsFormatted,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                        Text(
                          hike.caloriesFormatted,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  if (hike.latitudes.length >= 2)
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined,
                          color: Colors.deepOrange),
                      tooltip: l10n.logSaveToTrailsTooltip,
                      onPressed: () => _saveToTrails(context, hike),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(context, hike),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => HikeDetailScreen(hike: hike)),
              ),
            ),
          );
        },
      ),
    );
  }
}
