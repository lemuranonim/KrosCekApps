// lib/widgets/audit_status_widgets.dart
//
// Kumpulan widget untuk menampilkan status audit:
//   • AuditProgressDots   — deretan titik per sub-fase
//   • AuditStatusBadge    — badge "Sampun" / "Dereng" / dll
//   • AuditStatusBorder   — left border warna sesuai status
//   • AuditPhaseFilterBar — tombol pilih fase aktif (di map/listview)
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/audit_status_helper.dart';
import '../utils/active_phase_filter.dart';
import '../utils/dap_helper.dart';

// ═══════════════════════════════════════════════════════════
// BAGIAN 1 — WARNA & LABEL STATUS
// ═══════════════════════════════════════════════════════════

class AuditStatusColors {
  static const sampun = Color(0xFF43A047); // hijau
  static const derengJangkep = Color(0xFFFFA726); // oranye
  static const dereng = Color(0xFFEF5350); // merah
  static const unknown = Color(0xFF607D8B); // abu-abu slate
}

// ═══════════════════════════════════════════════════════════
// BAGIAN 2 — PROGRESS DOTS
// Menampilkan 6 titik: Veg · Gen1 · Gen2 · Gen3 · Pre-H · HV
// ═══════════════════════════════════════════════════════════

class AuditProgressDots extends StatelessWidget {
  final FieldAuditStatus status;

  /// Jika true, tampilkan hanya fase yang relevan dengan DAP
  final bool compact;

  const AuditProgressDots({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dots = status.isPsp
        ? <_DotConfig>[
            _DotConfig(
              done: status.vegetative == SingleAuditStatus.sampun,
              partial: false,
              tooltip: 'Vegetatif PSP',
            ),
            _DotConfig(
              done: status.gen5Done,
              partial: false,
              tooltip: 'Generatif PSP',
            ),
            _DotConfig(
              done: status.harvest == SingleAuditStatus.sampun,
              partial: false,
              tooltip: 'Harvest PSP',
            ),
          ]
        : <_DotConfig>[
            _DotConfig(
              done: status.vegetative == SingleAuditStatus.sampun,
              partial: false,
              tooltip: 'Vegetatif',
            ),
            _DotConfig(
              done: status.gen1Done,
              partial: false,
              tooltip: 'Generatif CP1',
            ),
            _DotConfig(
              done: status.gen2Done,
              partial: false,
              tooltip: 'Generatif CP2',
            ),
            _DotConfig(
              done: status.gen3Done,
              partial: false,
              tooltip: 'Generatif CP3',
            ),
            if (status.isSweetCorn)
              _DotConfig(
                done: status.gen4Done,
                partial: false,
                tooltip: 'Generatif CP4',
              ),
            if (status.isSweetCorn)
              _DotConfig(
                done: status.gen5Done,
                partial: false,
                tooltip: 'Generatif CP5',
              ),
            _DotConfig(
              done: status.preHarvest == SingleAuditStatus.sampun,
              partial: false,
              tooltip: 'Pre-Harvest',
            ),
            _DotConfig(
              done: status.harvest == SingleAuditStatus.sampun,
              partial: false,
              tooltip: 'Harvest',
            ),
          ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dots.asMap().entries.map((e) {
        final i = e.key;
        final dot = e.value;
        return Padding(
          // Sedikit spasi lebih setelah Veg dan setelah Gen3
          padding: EdgeInsets.only(right: (i == 0 || i == 3) ? 5 : 3),
          child: Tooltip(
            message: dot.tooltip,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dot.done
                    ? AuditStatusColors.sampun
                    : AuditStatusColors.dereng.withAlpha(120),
                shape: BoxShape.circle,
                border: Border.all(
                  color: dot.done ? AuditStatusColors.sampun : Colors.white24,
                  width: 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DotConfig {
  final bool done;
  final bool partial;
  final String tooltip;
  const _DotConfig(
      {required this.done, required this.partial, required this.tooltip});
}

// ═══════════════════════════════════════════════════════════
// BAGIAN 3 — STATUS BADGE
// Tampil sebagai pill kecil dengan teks + warna
// ═══════════════════════════════════════════════════════════

class AuditStatusBadge extends StatelessWidget {
  /// Status untuk fase tunggal (veg, pre-harvest, harvest)
  final SingleAuditStatus? singleStatus;

  /// Status untuk generatif
  final GenerativeAuditStatus? genStatus;

  /// Ukuran kecil (untuk card) vs normal
  final bool small;

  const AuditStatusBadge.single({
    super.key,
    required this.singleStatus,
    this.small = true,
  }) : genStatus = null;

  const AuditStatusBadge.generative({
    super.key,
    required this.genStatus,
    this.small = true,
  }) : singleStatus = null;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (singleStatus != null) {
      if (singleStatus == SingleAuditStatus.sampun) {
        label = 'Sampun';
        color = AuditStatusColors.sampun;
      } else {
        label = 'Dereng';
        color = AuditStatusColors.dereng;
      }
    } else if (genStatus != null) {
      switch (genStatus!) {
        case GenerativeAuditStatus.sampun:
          label = 'Sampun';
          color = AuditStatusColors.sampun;
          break;
        case GenerativeAuditStatus.derengJangkep:
          label = 'Dereng Jangkep';
          color = AuditStatusColors.derengJangkep;
          break;
        case GenerativeAuditStatus.derengBlas:
          label = 'Dereng Blas';
          color = AuditStatusColors.dereng;
          break;
      }
    } else {
      label = '—';
      color = AuditStatusColors.unknown;
    }

    final fontSize = small ? 9.0 : 11.0;
    final hPad = small ? 6.0 : 10.0;
    final vPad = small ? 2.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(180), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
          height: 1.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// BAGIAN 4 — AUDIT STATUS LEFT BORDER (dipakai di card)
// Wrap child dengan left border berwarna
// ═══════════════════════════════════════════════════════════

class AuditStatusLeftBorder extends StatelessWidget {
  final FieldAuditStatus auditStatus;
  final int dap;
  final ActivePhaseView activePhase;
  final Widget child;
  final BorderRadius borderRadius;

  const AuditStatusLeftBorder({
    super.key,
    required this.auditStatus,
    required this.dap,
    required this.activePhase,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  Color _resolveColor() {
    final phase =
        activePhase == ActivePhaseView.auto ? _dapToPhase(dap) : activePhase;

    final bool isDone = auditStatus.isAuditDoneFor(phase, dap);

    if (isDone) return AuditStatusColors.sampun;

    // Untuk Generative, kita beri warna oranye jika ada progress tapi belum jangkep
    if (phase == ActivePhaseView.generative &&
        auditStatus.generative == GenerativeAuditStatus.derengJangkep) {
      return AuditStatusColors.derengJangkep;
    }

    return AuditStatusColors.dereng;
  }

  ActivePhaseView _dapToPhase(int d) {
    return DapHelper.getActivePhaseView(
      d,
      hybrid: auditStatus.isSweetCorn ? 'AX01' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _resolveColor();
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          child,
          // Left border strip
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// BAGIAN 5 — PHASE FILTER BAR
// Row tombol horizontal untuk memilih fase aktif
// Diletakkan di bawah header / di atas list
// ═══════════════════════════════════════════════════════════

class AuditPhaseFilterBar extends StatelessWidget {
  final ActivePhaseView activePhase;
  final ValueChanged<ActivePhaseView> onChanged;

  // Tampilkan sebagai compact (icon only) atau full (icon + label)
  final bool compact;

  const AuditPhaseFilterBar({
    super.key,
    required this.activePhase,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: ActivePhaseView.values.map((phase) {
          final isSelected = activePhase == phase;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PhaseChip(
              phase: phase,
              isSelected: isSelected,
              compact: compact,
              onTap: () => onChanged(phase),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final ActivePhaseView phase;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _PhaseChip({
    required this.phase,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AdvantaColors.primaryGreen
              : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AdvantaColors.lightGreen
                : Colors.white.withAlpha(30),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AdvantaColors.primaryGreen.withAlpha(100),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              phase.icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                phase.shortLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// BAGIAN 6 — MARKER AUDIT INDICATOR (untuk map)
//
// 4 STATE VISUAL di pojok KIRI ATAS marker:
//
//   ① Belum audit (Dereng Blas)
//      → Dot merah solid 12×12
//
//   ② Generatif sebagian (Dereng Jangkep)
//      → Dot oranye 14×14 + teks "X/3" di tengah
//         sehingga jelas sudah berapa CP selesai
//
//   ③ Sudah audit, koordinat ASLI (tidak ada correction_tagging)
//      → Badge hijau kecil berisi ikon ✓
//
//   ④ Sudah audit, koordinat sudah DIKOREKSI (isCorrected = true)
//      → Badge hijau + tanda ✓ (badge C emas tetap di kanan atas,
//         dihandle di qa_screen.dart seperti sebelumnya)
//         → State ini SAMA dengan ③ di kiri atas, bedanya ada "C"
//            di kanan atas (tidak berubah dari sebelumnya)
//
// CATATAN: isCorrected bukan bagian dari AuditStatus, jadi dikirim
// sebagai parameter terpisah dari qa_screen._buildMarkers().
// ═══════════════════════════════════════════════════════════

class MarkerAuditDot extends StatelessWidget {
  final FieldAuditStatus auditStatus;
  final int dap;
  final ActivePhaseView activePhase;

  /// True jika field sudah ada correction_tagging — dipakai untuk
  /// memastikan badge ✓ tampil bahkan saat isCorrected=true
  /// (badge C di kanan atas tetap dihandle di qa_screen.dart)
  final bool isCorrected;

  const MarkerAuditDot({
    super.key,
    required this.auditStatus,
    required this.dap,
    required this.activePhase,
    this.isCorrected = false,
  });

  // Resolve status fase aktif → enum 3 nilai untuk rendering
  _MarkerAuditState _resolveState() {
    final phase =
        activePhase == ActivePhaseView.auto ? _dapToPhase(dap) : activePhase;

    // GUNAKAN HELPER BARU: mengecek apakah audit sudah selesai untuk
    // sub-fase yang sedang aktif (terutama di Generatif).
    final bool isDone = auditStatus.isAuditDoneFor(phase, dap);

    if (isDone) return _MarkerAuditState.sampun;

    // Jika belum selesai, cek apakah ada progress sebagian (khusus generatif)
    if (phase == ActivePhaseView.generative &&
        auditStatus.generative == GenerativeAuditStatus.derengJangkep) {
      return _MarkerAuditState.derengJangkep;
    }

    return _MarkerAuditState.derengBlas;
  }

  ActivePhaseView _dapToPhase(int d) {
    return DapHelper.getActivePhaseView(
      d,
      hybrid: auditStatus.isSweetCorn ? 'AX01' : null,
    );
  }

  // Hitung berapa CP generatif yang selesai (untuk label X/3)
  int get _genDoneCount {
    final cps = auditStatus.isSweetCorn
        ? [
            auditStatus.gen1Done,
            auditStatus.gen2Done,
            auditStatus.gen3Done,
            auditStatus.gen4Done,
            auditStatus.gen5Done,
          ]
        : [auditStatus.gen1Done, auditStatus.gen2Done, auditStatus.gen3Done];
    return cps.where((v) => v).length;
  }

  int get _genTotalCount => auditStatus.isSweetCorn ? 5 : 3;

  @override
  Widget build(BuildContext context) {
    final state = _resolveState();

    // ── ① & ② : Belum / Sebagian ───────────────────────────
    if (state == _MarkerAuditState.derengBlas) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: AuditStatusColors.dereng,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: AuditStatusColors.dereng.withAlpha(180), blurRadius: 5),
          ],
        ),
      );
    }

    if (state == _MarkerAuditState.derengJangkep) {
      final done = _genDoneCount;
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AuditStatusColors.derengJangkep,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: AuditStatusColors.derengJangkep.withAlpha(180),
                blurRadius: 5),
          ],
        ),
        child: Center(
          child: Text(
            '$done/$_genTotalCount',
            style: const TextStyle(
              fontSize: 6,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    // ── ③ & ④ : Sampun (dengan atau tanpa koreksi) ─────────
    // Tampilkan badge ✓ hijau. Badge C di kanan atas tetap ada
    // karena dihandle terpisah di qa_screen.dart.
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AuditStatusColors.sampun,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AuditStatusColors.sampun.withAlpha(180), blurRadius: 5),
        ],
      ),
      child: const Center(
        child: Icon(Icons.check_rounded, color: Colors.white, size: 8),
      ),
    );
  }
}

enum _MarkerAuditState { sampun, derengJangkep, derengBlas }
