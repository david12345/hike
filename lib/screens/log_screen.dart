import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_record.dart';
import '../services/hike_service.dart';
import '../services/imported_trail_service.dart';
import 'hike_detail_screen.dart';

/// Date format for hike start times displayed in the log list.
final _hikeDateFormat = DateFormat('MMM d, y \u2022 HH:mm');

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  Future<void> _saveToTrails(HikeRecord hike) async {
    final controller = TextEditingController(text: hike.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save to Trails'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Trail name'),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (name == null || name.isEmpty) return;
    final trail =
        ImportedTrailService.fromHikeRecord(hike, nameOverride: name);
    await ImportedTrailService.save(trail);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved to Trails as '$name'")),
    );
  }

  Future<void> _delete(HikeRecord hike) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Hike?'),
        content: Text('Delete "${hike.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
    return ListenableBuilder(
      listenable: HikeService.version,
      builder: (context, _) {
        final hikes = HikeService.getAll();
        if (hikes.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hike Log'), centerTitle: true),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hiking, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hikes yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Start tracking your first hike!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Hike Log (${hikes.length})'),
            centerTitle: true,
          ),
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
                    _hikeDateFormat.format(hike.startTime),
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
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                            Text(
                              hike.caloriesFormatted,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                      if (hike.latitudes.length >= 2)
                        IconButton(
                          icon: const Icon(Icons.bookmark_add_outlined,
                              color: Colors.deepOrange),
                          tooltip: 'Save to Trails',
                          onPressed: () => _saveToTrails(hike),
                        ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _delete(hike),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: hike)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
