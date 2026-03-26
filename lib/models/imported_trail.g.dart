// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imported_trail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImportedTrailAdapter extends TypeAdapter<ImportedTrail> {
  @override
  final int typeId = 1;

  @override
  ImportedTrail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImportedTrail(
      id: fields[0] as String,
      name: fields[1] as String,
      latitudes: (fields[2] as List).cast<double>(),
      longitudes: (fields[3] as List).cast<double>(),
      distanceKm: fields[4] as double,
      importedAt: fields[5] as DateTime,
      sourceFilename: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ImportedTrail obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.latitudes)
      ..writeByte(3)
      ..write(obj.longitudes)
      ..writeByte(4)
      ..write(obj.distanceKm)
      ..writeByte(5)
      ..write(obj.importedAt)
      ..writeByte(6)
      ..write(obj.sourceFilename);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportedTrailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
