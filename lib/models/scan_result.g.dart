// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      content: fields[0] as String,
      scannedAt: fields[1] as DateTime,
      type: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.scannedAt)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
