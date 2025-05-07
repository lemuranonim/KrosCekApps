import 'package:cloud_firestore/cloud_firestore.dart';

class QaSupervisor {
  final String name; // Nama QA SPV sebagai key
  final List<String> districts;

  QaSupervisor({
    required this.name,
    required this.districts,
  });

  factory QaSupervisor.fromMap(Map<String, dynamic> data) {
    return QaSupervisor(
      name: '', // Diisi dari key Map (name)
      districts: List<String>.from(data['districts'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'districts': districts,
    };
  }
}

class Region {
  final String id;
  final Map<String, QaSupervisor> qaSupervisors;

  Region({
    required this.id,
    required this.qaSupervisors,
  });

  factory Region.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final qaSpvData = data['qa_spv'] as Map<String, dynamic>? ?? {};

    final qaSupervisors = qaSpvData.map((name, districtData) {
      return MapEntry(
        name,
        QaSupervisor(
          name: name,
          districts: List<String>.from(districtData['districts'] ?? []),
        ),
      );
    });

    return Region(
      id: doc.id,
      qaSupervisors: qaSupervisors,
    );
  }
}