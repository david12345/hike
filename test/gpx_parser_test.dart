import 'package:flutter_test/flutter_test.dart';
import 'package:hike/parsers/gpx_parser.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const _minimalGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>My Trail</name>
    <trkseg>
      <trkpt lat="40.2033" lon="-8.4103"/>
      <trkpt lat="40.2040" lon="-8.4110"/>
    </trkseg>
  </trk>
</gpx>''';

const _gpxWithElevation = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Elevation Trail</name>
    <trkseg>
      <trkpt lat="40.2033" lon="-8.4103"><ele>120.5</ele></trkpt>
      <trkpt lat="40.2040" lon="-8.4110"><ele>135.0</ele></trkpt>
      <trkpt lat="40.2050" lon="-8.4120"><ele>140.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>''';

const _multiTrackGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Track One</name>
    <trkseg>
      <trkpt lat="40.0000" lon="-8.0000"/>
      <trkpt lat="40.0010" lon="-8.0010"/>
    </trkseg>
  </trk>
  <trk>
    <name>Track Two</name>
    <trkseg>
      <trkpt lat="41.0000" lon="-9.0000"/>
      <trkpt lat="41.0010" lon="-9.0010"/>
    </trkseg>
  </trk>
</gpx>''';

const _gpxMissingLatLon = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <name>Bad Points</name>
    <trkseg>
      <trkpt lat="notanumber" lon="-8.0"/>
      <trkpt lon="-8.0"/>
      <trkpt lat="40.0"/>
      <trkpt lat="40.0" lon="-8.0"/>
      <trkpt lat="40.1" lon="-8.1"/>
    </trkseg>
  </trk>
</gpx>''';

const _gpxNoName = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="40.0" lon="-8.0"/>
      <trkpt lat="40.1" lon="-8.1"/>
    </trkseg>
  </trk>
</gpx>''';

const _gpxFewerThanTwoPoints = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <name>Single Point</name>
    <trkseg>
      <trkpt lat="40.0" lon="-8.0"/>
    </trkseg>
  </trk>
</gpx>''';

const _gpxSpecialCharsName = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <name>Trilho &amp; Caminho &lt;Bom&gt;</name>
    <trkseg>
      <trkpt lat="40.0" lon="-8.0"/>
      <trkpt lat="40.1" lon="-8.1"/>
    </trkseg>
  </trk>
</gpx>''';

void main() {
  const parser = GpxParser();

  // ---------------------------------------------------------------------------
  group('GpxParser – minimal valid GPX', () {
    test('returns one trail with correct name', () {
      final trails = parser.parse(_minimalGpx, 'mytrail.gpx');
      expect(trails.length, equals(1));
      expect(trails.first.name, equals('My Trail'));
    });

    test('coordinates are parsed correctly', () {
      final trail = parser.parse(_minimalGpx, 'mytrail.gpx').first;
      expect(trail.latitudes.length, equals(2));
      expect(trail.longitudes.length, equals(2));
      expect(trail.latitudes[0], closeTo(40.2033, 1e-6));
      expect(trail.longitudes[0], closeTo(-8.4103, 1e-6));
      expect(trail.latitudes[1], closeTo(40.2040, 1e-6));
      expect(trail.longitudes[1], closeTo(-8.4110, 1e-6));
    });

    test('distance is positive', () {
      final trail = parser.parse(_minimalGpx, 'mytrail.gpx').first;
      expect(trail.distanceKm, greaterThan(0.0));
    });

    test('each trail has a unique id', () {
      final trails1 = parser.parse(_minimalGpx, 'mytrail.gpx');
      final trails2 = parser.parse(_minimalGpx, 'mytrail.gpx');
      expect(trails1.first.id, isNot(equals(trails2.first.id)));
    });
  });

  // ---------------------------------------------------------------------------
  group('GpxParser – multiple tracks', () {
    test('two <trk> elements → two ImportedTrail objects', () {
      final trails = parser.parse(_multiTrackGpx, 'multi.gpx');
      expect(trails.length, equals(2));
    });

    test('each trail has the correct name', () {
      final trails = parser.parse(_multiTrackGpx, 'multi.gpx');
      expect(trails[0].name, equals('Track One'));
      expect(trails[1].name, equals('Track Two'));
    });

    test('each trail has its own coordinates', () {
      final trails = parser.parse(_multiTrackGpx, 'multi.gpx');
      expect(trails[0].latitudes[0], closeTo(40.0, 1e-6));
      expect(trails[1].latitudes[0], closeTo(41.0, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  group('GpxParser – elevation tag', () {
    test('GPX with <ele> parses without throwing', () {
      expect(
        () => parser.parse(_gpxWithElevation, 'elevation.gpx'),
        returnsNormally,
      );
    });

    test('elevation GPX produces one trail with 3 points', () {
      final trails = parser.parse(_gpxWithElevation, 'elevation.gpx');
      expect(trails.length, equals(1));
      expect(trails.first.latitudes.length, equals(3));
    });
  });

  // ---------------------------------------------------------------------------
  group('GpxParser – malformed / missing data', () {
    test('trkpt missing lat or lon is skipped without throwing', () {
      // The fixture has 5 trkpt elements but only 2 have valid lat+lon.
      final trails = parser.parse(_gpxMissingLatLon, 'bad.gpx');
      expect(trails.length, equals(1));
      expect(trails.first.latitudes.length, equals(2));
    });

    test('track with only one valid point is skipped', () {
      final trails = parser.parse(_gpxFewerThanTwoPoints, 'singlept.gpx');
      expect(trails, isEmpty);
    });

    test('malformed XML throws FormatException', () {
      expect(
        () => parser.parse('<not valid xml', 'bad.gpx'),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty string throws FormatException', () {
      // An empty string is not valid XML — the parser should propagate
      // the XmlDocument.parse() FormatException rather than return an empty list.
      expect(
        () => parser.parse('', 'empty.gpx'),
        throwsA(isA<Exception>()),
      );
    });

    test('GPX with no <trk> elements returns empty list', () {
      const noTracks = '''<?xml version="1.0"?>
<gpx version="1.1"/>''';
      final trails = parser.parse(noTracks, 'notrack.gpx');
      expect(trails, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('GpxParser – name fallback and special characters', () {
    test('track with no <name> element uses filename without extension', () {
      final trails = parser.parse(_gpxNoName, 'unnamed.gpx');
      expect(trails.first.name, equals('unnamed'));
    });

    test('XML entity references in name are decoded correctly', () {
      final trails = parser.parse(_gpxSpecialCharsName, 'special.gpx');
      expect(trails.first.name, equals('Trilho & Caminho <Bom>'));
    });
  });
}
