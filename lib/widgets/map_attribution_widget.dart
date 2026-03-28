import 'package:flutter/material.dart';
import '../services/tile_preference_service.dart';

/// Displays the correct tile attribution text for the currently active
/// tile layer, rebuilding automatically when [TilePreferenceService] changes.
///
/// Intended to be placed inside a [Stack] at [Positioned(top: 8, left: 8)].
class MapAttributionWidget extends StatelessWidget {
  const MapAttributionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TilePreferenceService.instance,
      builder: (context, _) {
        final String text;
        switch (TilePreferenceService.instance.mode) {
          case TileMode.osm:
            text = '© OpenStreetMap contributors';
          case TileMode.topo:
            text = '© OpenStreetMap contributors, © OpenTopoMap';
          case TileMode.satellite:
            text =
                'Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics';
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        );
      },
    );
  }
}
