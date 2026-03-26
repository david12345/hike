// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hike_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HikeRecordAdapter extends TypeAdapter<HikeRecord> {
  @override
  final int typeId = 0;

  @override
  HikeRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HikeRecord(
      id: fields[0] as String,
      name: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      distanceMeters: fields[4] as double,
      latitudes: (fields[5] as List?)?.cast<double>(),
      longitudes: (fields[6] as List?)?.cast<double>(),
      steps: fields[7] == null ? 0 : fields[7] as int,
      calories: fields[8] == null ? 0.0 : fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, HikeRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.distanceMeters)
      ..writeByte(5)
      ..write(obj.latitudes)
      ..writeByte(6)
      ..write(obj.longitudes)
      ..writeByte(7)
      ..write(obj.steps)
      ..writeByte(8)
      ..write(obj.calories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HikeRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
