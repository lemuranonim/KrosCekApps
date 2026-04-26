// lib/providers/mass_inspection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State untuk menyimpan field yang dipilih dalam mode mass inspect
class MassInspectionState {
  final bool isActive;
  final List<Map<String, dynamic>> selectedFields; // list dari master_fields
  final String? targetPhase; // fase yang dipilih untuk semua field ini

  const MassInspectionState({
    this.isActive = false,
    this.selectedFields = const [],
    this.targetPhase,
  });

  MassInspectionState copyWith({
    bool? isActive,
    List<Map<String, dynamic>>? selectedFields,
    String? targetPhase,
  }) {
    return MassInspectionState(
      isActive: isActive ?? this.isActive,
      selectedFields: selectedFields ?? this.selectedFields,
      targetPhase: targetPhase ?? this.targetPhase,
    );
  }

  bool get hasSelection => selectedFields.isNotEmpty;
  int get selectionCount => selectedFields.length;
}

class MassInspectionNotifier extends Notifier<MassInspectionState> {
  @override
  MassInspectionState build() => const MassInspectionState();

  void activateMassMode() {
    state = state.copyWith(isActive: true, selectedFields: []);
  }

  void deactivateMassMode() {
    state = const MassInspectionState();
  }

  void toggleFieldSelection(Map<String, dynamic> field) {
    final fieldNum = field['field_number'];
    final existing = state.selectedFields
        .any((f) => f['field_number'] == fieldNum);
    if (existing) {
      state = state.copyWith(
        selectedFields: state.selectedFields
            .where((f) => f['field_number'] != fieldNum)
            .toList(),
      );
    } else {
      state = state.copyWith(
        selectedFields: [...state.selectedFields, field],
      );
    }
  }

  void removeField(String fieldNumber) {
    state = state.copyWith(
      selectedFields: state.selectedFields
          .where((f) => f['field_number'] != fieldNumber)
          .toList(),
    );
  }

  void setTargetPhase(String phase) {
    state = state.copyWith(targetPhase: phase);
  }

  void clearAll() {
    state = const MassInspectionState(isActive: true);
  }
}

final massInspectionProvider =
    NotifierProvider<MassInspectionNotifier, MassInspectionState>(
  MassInspectionNotifier.new,
);
