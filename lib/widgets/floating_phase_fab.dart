// lib/widgets/floating_phase_fab.dart
//
// FLOATING PHASE FAB — Mass Inspect only
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/dap_helper.dart';
import 'phase_asset_icon.dart';

// ── Phase definitions ────────────────────────────────────────
enum InspectionPhase {
  vegetative,
  generative1,
  generative2,
  generative3,
  generative4,
  generative5,
  preHarvest,
  harvest,
}

extension InspectionPhaseExt on InspectionPhase {
  String get label {
    switch (this) {
      case InspectionPhase.vegetative:  return 'Vegetatif';
      case InspectionPhase.generative1: return 'Generatif CP1';
      case InspectionPhase.generative2: return 'Generatif CP2';
      case InspectionPhase.generative3: return 'Generatif CP3 (Final)';
      case InspectionPhase.generative4: return 'Generatif CP4 (SC)';
      case InspectionPhase.generative5: return 'Generatif CP5 (SC)';
      case InspectionPhase.preHarvest:  return 'Pre-Harvest';
      case InspectionPhase.harvest:     return 'Harvest';
    }
  }

  String get routeKey {
    switch (this) {
      case InspectionPhase.vegetative:  return 'vegetative';
      case InspectionPhase.generative1: return 'generative_1';
      case InspectionPhase.generative2: return 'generative_2';
      case InspectionPhase.generative3: return 'generative_3';
      case InspectionPhase.generative4: return 'generative_4';
      case InspectionPhase.generative5: return 'generative_5';
      case InspectionPhase.preHarvest:  return 'pre_harvest';
      case InspectionPhase.harvest:     return 'harvest';
    }
  }

  // Definisi Icon langsung di dalam extension (Memperbaiki error AdvantaPhase)
  IconData get icon {
    switch (this) {
      case InspectionPhase.vegetative:  return Icons.grass_rounded;
      case InspectionPhase.generative1:
      case InspectionPhase.generative2:
      case InspectionPhase.generative3:
      case InspectionPhase.generative4:
      case InspectionPhase.generative5: return Icons.spa_rounded;
      case InspectionPhase.preHarvest:  return Icons.content_cut_rounded;
      case InspectionPhase.harvest:     return Icons.agriculture_rounded;
    }
  }

  // Definisi Color langsung di dalam extension (Memperbaiki error AdvantaPhase)
  Color get color {
    switch (this) {
      case InspectionPhase.vegetative:  return const Color(0xFF43A047);
      case InspectionPhase.generative1:
      case InspectionPhase.generative2:
      case InspectionPhase.generative3: return const Color(0xFF7B61FF);
      case InspectionPhase.generative4: return const Color(0xFF8E24AA);
      case InspectionPhase.generative5: return const Color(0xFFD81B60);
      case InspectionPhase.preHarvest:  return const Color(0xFFE65100);
      case InspectionPhase.harvest:     return const Color(0xFFD4A017);
    }
  }
}

// ── Widget ──────────────────────────────────────────────────
class FloatingPhaseFab extends ConsumerStatefulWidget {
  final List<String> selectedFieldNumbers;

  const FloatingPhaseFab({
    super.key,
    required this.selectedFieldNumbers,
  });

  @override
  ConsumerState<FloatingPhaseFab> createState() => _FloatingPhaseFabState();
}

class _FloatingPhaseFabState extends ConsumerState<FloatingPhaseFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _anim.forward() : _anim.reverse();
  }

  void _onPhaseSelected(InspectionPhase phase) {
    if (widget.selectedFieldNumbers.isEmpty) {
      final theme = Theme.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pilih lahan di peta terlebih dahulu',
            style: AdvantaText.body2.copyWith(color: theme.colorScheme.onError),
          ),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.all(16.0),
        ),
      );
      return;
    }

    setState(() => _isOpen = false);
    _anim.reverse();

    context.push('/inspect/mass', extra: {
      'fieldNumbers': widget.selectedFieldNumbers,
      'phase': phase.routeKey,
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.selectedFieldNumbers.length;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Phase submenu ──────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _isOpen
              ? Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: InspectionPhase.values.map((phase) {
                final badgeLabel = DapHelper.getDapBadgeLabel(
                  0,
                  phase.routeKey
                      .replaceAll('_', ' ')
                      .split(' ')
                      .first,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: _PhaseItem(
                    phase: phase,
                    badgeLabel: count == 0 ? null : badgeLabel,
                    onTap: () => _onPhaseSelected(phase),
                  ),
                );
              }).toList(),
            ),
          )
              : const SizedBox.shrink(),
        ),

        // ── Main FAB ──────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100.0),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'mass_phase_fab',
                backgroundColor: _isOpen
                    ? (isDark ? theme.colorScheme.surface : AdvantaColors.deepForest)
                    : theme.colorScheme.primary,
                foregroundColor: _isOpen && isDark ? theme.colorScheme.onSurface : Colors.white,
                elevation: 0,
                highlightElevation: 0,
                onPressed: _toggle,
                tooltip: 'Pilih Fase Mass Inspect',
                child: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _anim,
                ),
              ),
            ),

            // Count badge
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: AdvantaText.caption.copyWith(
                        color: theme.colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Phase Item Chip ─────────────────────────────────────────
class _PhaseItem extends StatelessWidget {
  final InspectionPhase phase;
  final String? badgeLabel;
  final VoidCallback onTap;

  const _PhaseItem({
    required this.phase,
    required this.badgeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badgeColor = badgeLabel != null
        ? DapHelper.getDapBadgeColor(badgeLabel!)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // DAP badge
          if (badgeLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isDark ? badgeColor.withAlpha(40) : badgeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(100.0),
                border: Border.all(
                  color: badgeColor.withAlpha(isDark ? 100 : 60),
                  width: 0.8,
                ),
              ),
              child: Text(
                badgeLabel!,
                style: AdvantaText.caption.copyWith(
                  color: isDark ? badgeColor.withAlpha(200) : badgeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8.0), // Memperbaiki error EdgeInsets menjadi SizedBox
          ],

          // Phase button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(100.0),
              border: Border.all(
                color: phase.color.withAlpha(isDark ? 80 : 40),
                width: 1.0,
              ),
              boxShadow: AdvantaShadows.card(isDark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhaseAssetIcon(
                  phaseKey: phase.routeKey,
                  fallbackIcon: phase.icon,
                  fallbackColor: phase.color,
                  size: 22,
                ),
                const SizedBox(width: 8.0),
                Text(
                  phase.label,
                  style: AdvantaText.label.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
