import 'package:flutter_test/flutter_test.dart';
import 'package:hike/parsers/kml_parser.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const _minimalKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>My KML Trail</name>
      <LineString>
        <coordinates>
          -8.4103,40.2033,0
          -8.4110,40.2040,0
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>''';

const _kmlMultiplePlacemarks = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Route A</name>
      <LineString>
        <coordinates>
          -8.0,40.0,0
          -8.01,40.01,0
        </coordinates>
      </LineString>
    </Placemark>
    <Placemark>
      <name>Route B</name>
      <LineString>
        <coordinates>
          -9.0,41.0,0
          -9.01,41.01,0
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>''';

const _kmlExtraWhitespace = '''<?xml version="1.0" encoding="UTF-8"?>
<kml>
  <Placemark>
    <name>Whitespace Trail</name>
    <LineString>
      <coordinates>
        -8.4103,40.2033,100
          -8.4110,40.2040,105
        -8.4120,40.2050,110
      </coordinates>
    </LineString>
  </Placemark>
</kml>''';

const _kmlWithAltitude = '''<?xml version="1.0" encoding="UTF-8"?>
<kml>
  <Placemark>
    <name>Alt Trail</name>
    <LineString>
      <coordinates>
        -8.4103,40.2033,500
        -8.4110,40.2040,510
      </coordinates>
    </LineString>
  </Placemark>
</kml>''';

const _kmlNoName = '''<?xml version="1.0" encoding="UTF-8"?>
<kml>
  <Placemark>
    <LineString>
      <coordinates>
        -8.0,40.0,0
        -8.01,40.01,0
      </coordinates>
    </LineString>
  </Placemark>
</kml>''';

const _kmlPointPlacemark = '''<?xml version="1.0" encoding="UTF-8"?>
<kml>
  <Placemark>
    <name>Just a Point</name>
    <Point>
      <coordinates>-8.0,40.0,0</coordinates>
    </Point>
  </Placemark>
</kml>''';

const _kmlSinglePoint = '''<?xml version="1.0" encoding="UTF-8"?>
<kml>
  <Placemark>
    <name>Only One</name>
    <LineString>
      <coordinates>-8.0,40.0,0</coordinates>
    </LineString>
  </Placemark>
</kml>''';

void main() {
  const parser = KmlParser();

  // ---------------------------------------------------------------------------
  group('KmlParser – minimal valid KML', () {
    test('returns one trail with correct name', () {
      final trails = parser.parse(_minimalKml, 'mytrail.kml');
      expect(trails.length, equals(1));
      expect(trails.first.name, equals('My KML Trail'));
    });

    test('lat/lon extracted in correct order (KML is lon,lat,alt)', () {
      final trail = parser.parse(_minimalKml, 'mytrail.kml').first;
      expect(trail.latitudes.length, equals(2));
      expect(trail.longitudes.length, equals(2));
      // KML coordinate string: -8.4103,40.2033,0 → lon=-8.4103, lat=40.2033
      expect(trail.latitudes[0], closeTo(40.2033, 1e-6));
      expect(trail.longitudes[0], closeTo(-8.4103, 1e-6));
      expect(trail.latitudes[1], closeTo(40.2040, 1e-6));
      expect(trail.longitudes[1], closeTo(-8.4110, 1e-6));
    });

    test('distance is positive', () {
      final trail = parser.parse(_minimalKml, 'mytrail.kml').first;
      expect(trail.distanceKm, greaterThan(0.0));
    });

    test('sourceFilename is stored', () {
      final trail = parser.parse(_minimalKml, 'mytrail.kml').first;
      expect(trail.sourceFilename, equals('mytrail.kml'));
    });
  });

  // ---------------------------------------------------------------------------
  group('KmlParser – multiple Placemarks', () {
    test('two Placemarks with LineString → two trails', () {
      final trails = parser.parse(_kmlMultiplePlacemarks, 'multi.kml');
      expect(trails.length, equals(2));
    });

    test('each trail has the correct name', () {
      final trails = parser.parse(_kmlMultiplePlacemarks, 'multi.kml');
      expect(trails[0].name, equals('Route A'));
      expect(trails[1].name, equals('Route B'));
    });

    test('each trail has its own coordinates', () {
      final trails = parser.parse(_kmlMultiplePlacemarks, 'multi.kml');
      expect(trails[0].latitudes[0], closeTo(40.0, 1e-6));
      expect(trails[1].latitudes[0], closeTo(41.0, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  group('KmlParser – whitespace handling', () {
    test('extra whitespace in coordinates is handled correctly', () {
      final trails = parser.parse(_kmlExtraWhitespace, 'ws.kml');
      expect(trails.length, equals(1));
      expect(trails.first.latitudes.length, equals(3));
    });

    test('correct lat/lon with extra whitespace', () {
      final trail = parser.parse(_kmlExtraWhitespace, 'ws.kml').first;
      expect(trail.latitudes[0], closeTo(40.2033, 1e-6));
      expect(trail.longitudes[0], closeTo(-8.4103, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  group('KmlParser – altitude in coordinates', () {
    test('lon,lat,alt format extracts lat and lon correctly', () {
      final trail = parser.parse(_kmlWithAltitude, 'alt.kml').first;
      expect(trail.latitudes[0], closeTo(40.2033, 1e-6));
      expect(trail.longitudes[0], closeTo(-8.4103, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  group('KmlParser – malformed / empty data', () {
    test('malformed XML throws an Exception', () {
      expect(
        () => parser.parse('<not valid xml', 'bad.kml'),
        throwsA(isA<Exception>()),
      );
    });

    test('empty string throws an Exception', () {
      // An empty string is not valid XML; XmlDocument.parse() throws.
      expect(
        () => parser.parse('', 'empty.kml'),
        throwsA(isA<Exception>()),
      );
    });

    test('KML with no <Placemark> elements returns empty list', () {
      const noPlacemarks = '''<?xml version="1.0"?>
<kml><Document/></kml>''';
      final trails = parser.parse(noPlacemarks, 'empty.kml');
      expect(trails, isEmpty);
    });

    test('Placemark with <Point> (no LineString) is skipped', () {
      final trails = parser.parse(_kmlPointPlacemark, 'point.kml');
      expect(trails, isEmpty);
    });

    test('LineString with only one coordinate tuple is skipped', () {
      final trails = parser.parse(_kmlSinglePoint, 'onepoint.kml');
      expect(trails, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('KmlParser – name fallback', () {
    test('Placemark with no <name> uses filename without extension', () {
      final trails = parser.parse(_kmlNoName, 'unnamed_trail.kml');
      expect(trails.first.name, equals('unnamed_trail'));
    });
  });

  // ---------------------------------------------------------------------------
  group('KmlParser – unique IDs', () {
    test('each call to parse() produces a different id', () {
      final trails1 = parser.parse(_minimalKml, 'mytrail.kml');
      final trails2 = parser.parse(_minimalKml, 'mytrail.kml');
      expect(trails1.first.id, isNot(equals(trails2.first.id)));
    });
  });
}
