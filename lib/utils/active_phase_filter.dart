// lib/utils/active_phase_filter.dart
import 'package:flutter/material.dart';
//
// Enum untuk "Fase Aktif" yang ditampilkan di home map & list view.
// User bisa memilih mau melihat status audit fase mana yang
// di-highlight pada marker dan card.
// ─────────────────────────────────────────────────────────

/// Fase yang sedang di-highlight untuk tampilan status audit
enum ActivePhaseView {
  /// Otomatis — tampilkan status fase yang sesuai DAP field
  auto,

  vegetative,
  generative,
  preHarvest,
  harvest,
}

extension ActivePhaseViewExt on ActivePhaseView {
  String get label {
    switch (this) {
      case ActivePhaseView.auto:        return 'Auto (DAP)';
      case ActivePhaseView.vegetative:  return 'Vegetatif';
      case ActivePhaseView.generative:  return 'Generatif';
      case ActivePhaseView.preHarvest:  return 'Pre-Harvest';
      case ActivePhaseView.harvest:     return 'Harvest';
    }
  }

  String get shortLabel {
    switch (this) {
      case ActivePhaseView.auto:        return 'Auto';
      case ActivePhaseView.vegetative:  return 'Veg';
      case ActivePhaseView.generative:  return 'Gen';
      case ActivePhaseView.preHarvest:  return 'Pre-H';
      case ActivePhaseView.harvest:     return 'HV';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivePhaseView.auto:        return Icons.auto_awesome_rounded;
      case ActivePhaseView.vegetative:  return Icons.grass_rounded;
      case ActivePhaseView.generative:  return Icons.spa_rounded;
      case ActivePhaseView.preHarvest:  return Icons.content_cut_rounded;
      case ActivePhaseView.harvest:     return Icons.agriculture_rounded;
    }
  }
}