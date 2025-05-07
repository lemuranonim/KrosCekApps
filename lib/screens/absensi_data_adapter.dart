import 'package:hive/hive.dart';
import 'absensi_dashboard.dart'; // Import your main file

class AbsensiDataAdapter extends TypeAdapter<AbsensiData> {
  @override
  final int typeId = 0;

  @override
  AbsensiData read(BinaryReader reader) {
    final map = reader.readMap().cast<String, dynamic>();
    return AbsensiData.fromMap(map);
  }

  @override
  void write(BinaryWriter writer, AbsensiData obj) {
    writer.writeMap(obj.toMap());
  }
}