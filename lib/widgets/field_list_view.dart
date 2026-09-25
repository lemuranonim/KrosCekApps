// lib/widgets/field_list_view.dart
// ── PERUBAHAN dari versi sebelumnya ──────────────────────
//  • Tambah parameter `activePhase` (ActivePhaseView)
//  • AuditPhaseFilterBar menjadi satu-satunya filter fase di sheet
//  • Pilihan fase yang sama memfilter DAP list sekaligus mengubah status audit
//    aktif di QA Map
//  • _sheetPhase local state di showSheet memakai closure variable pattern
//    → klik filter di sheet sekarang berdampak langsung ke tampilan list
//  • Setiap card: left border + progress dots + badge status
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../providers/master_fields_provider.dart';
import '../theme/app_theme.dart';
import '../utils/audit_status_helper.dart';
import '../utils/active_phase_filter.dart';
import '../utils/dap_helper.dart';
import 'audit_status_widgets.dart';

List<ParsedFieldData> filterFieldListByActivePhase(
  List<ParsedFieldData> fields, {
  required ActivePhaseView activePhase,
  required int deltaDays,
}) {
  return fields
      .where((field) {
        final projectedDap = field.dap + deltaDays;
        return DapHelper.isDapInPhaseView(
          projectedDap,
          activePhase,
          hybrid: field.raw['hybrid']?.toString(),
          district: field.raw['district_kab']?.toString(),
          region: field.raw['region']?.toString(),
          subDistrict: field.raw['sub_district_kec']?.toString(),
        );
      })
      .toList(growable: false);
}

class FieldListView extends StatefulWidget {
  final List<ParsedFieldData> fieldsData;
  final LatLng? userLocation;
  final double topPadding;
  final Color Function(int dap, {String? hybrid}) getMarkerColor;
  final void Function(List<Map<String, dynamic>> uncoordFields)
  onUncoordBannerTap;
  final void Function(double lat, double lng) onNavigateTap;

  final bool isMassMode;
  final Set<String> selectedFieldNumbers;
  final void Function(ParsedFieldData field) onFieldTap;

  final ScrollController? scrollController;

  final ActivePhaseView activePhase;

  /// Selisih hari untuk proyeksi DAP (Time Traveller)
  final int deltaDays;

  const FieldListView({
    super.key,
    required this.fieldsData,
    required this.userLocation,
    required this.topPadding,
    required this.getMarkerColor,
    required this.onUncoordBannerTap,
    required this.onNavigateTap,
    required this.isMassMode,
    required this.selectedFieldNumbers,
    required this.onFieldTap,
    required this.activePhase,
    this.deltaDays = 0,
    this.scrollController,
  });

  // =======================================================================
  // FUNGSI HELPER UNTUK MENAMPILKAN SEBAGAI BOTTOM SHEET
  // =======================================================================
  static void showSheet(
    BuildContext context, {
    required List<ParsedFieldData> fieldsData,
    required LatLng? userLocation,
    required Color Function(int dap, {String? hybrid}) getMarkerColor,
    required void Function(List<Map<String, dynamic>> uncoordFields)
    onUncoordBannerTap,
    required void Function(double lat, double lng) onNavigateTap,
    required bool isMassMode,
    required Set<String> selectedFieldNumbers,
    required void Function(ParsedFieldData field) onFieldTap,
    required ActivePhaseView activePhase,
    required ValueChanged<ActivePhaseView> onPhaseChanged,
    required List<ParsedFieldData> Function(ActivePhaseView phase)
    fieldsForPhase,
    int deltaDays = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        // ─────────────────────────────────────────────────────────────────
        // FIX: _sheetPhase dideklarasikan di sini (luar StatefulBuilder),
        // sehingga nilainya PERSISTEN antar rebuild StatefulBuilder.
        //
        // Sebelumnya: activePhase dikirim langsung sebagai parameter →
        // setSheetState(() {}) rebuild tapi nilai tidak berubah (tertangkap
        // saat showSheet dipanggil).
        //
        // Sekarang: _sheetPhase = variabel closure yang bisa dimutasi,
        // lalu setSheetState(() => _sheetPhase = phase) mengupdate nilai
        // dan trigger rebuild dengan nilai yang benar.
        // ─────────────────────────────────────────────────────────────────
        ActivePhaseView sheetPhase = activePhase;
        List<ParsedFieldData> sheetFields = fieldsData;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.70,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollCtrl) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AdvantaColors.deepForest,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── Drag Handle ──
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Header ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.format_list_bulleted_rounded,
                              color: AdvantaColors.lightGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Daftar Lahan',
                                style: AdvantaText.heading3.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Satu-satunya filter fase di List View. Pilihannya
                      // diteruskan ke QA Map dan dipakai untuk rentang DAP list.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'FASE & STATUS AUDIT',
                                style: AdvantaText.caption.copyWith(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AuditPhaseFilterBar(
                              activePhase: sheetPhase,
                              onChanged: (phase) {
                                // Satu pilihan fase mengendalikan QA Map,
                                // status audit card, dan subset DAP pada list.
                                onPhaseChanged(phase);
                                final nextFields = fieldsForPhase(phase);
                                setSheetState(() {
                                  sheetPhase = phase;
                                  sheetFields = nextFields;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white12, height: 1),

                      Expanded(
                        child: FieldListView(
                          fieldsData: sheetFields,
                          userLocation: userLocation,
                          topPadding: 8.0,
                          getMarkerColor: getMarkerColor,
                          onUncoordBannerTap: onUncoordBannerTap,
                          onNavigateTap: onNavigateTap,
                          isMassMode: isMassMode,
                          selectedFieldNumbers: selectedFieldNumbers,
                          scrollController: scrollCtrl,
                          // Pakai phase lokal yang tersinkron dengan QA Map.
                          activePhase: sheetPhase,
                          onFieldTap: (f) {
                            onFieldTap(f);
                            setSheetState(() {});
                          },
                          deltaDays: deltaDays,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  State<FieldListView> createState() => _FieldListViewState();
}

class _FieldListViewState extends State<FieldListView> {
  @override
  Widget build(BuildContext context) {
    // Satu filter fase untuk status audit dan rentang DAP. DapHelper menjaga
    // perbedaan rentang FC, SC (termasuk highland), dan PSP tetap konsisten.
    final filteredData = filterFieldListByActivePhase(
      widget.fieldsData,
      activePhase: widget.activePhase,
      deltaDays: widget.deltaDays,
    );

    // 2. Pisahkan lahan tanpa koordinat
    final uncoordFields = filteredData
        .where((f) => f.isDefault)
        .map((f) => f.raw)
        .toList();

    // 3. Hitung jarak
    final List<({ParsedFieldData data, double distance})> withDistance =
        filteredData.where((f) => !f.isDefault).map((f) {
          double dist = 0;
          if (widget.userLocation != null) {
            dist = Geolocator.distanceBetween(
              widget.userLocation!.latitude,
              widget.userLocation!.longitude,
              f.lat,
              f.lng,
            );
          }
          return (data: f, distance: dist);
        }).toList();

    if (widget.userLocation != null) {
      withDistance.sort((a, b) => a.distance.compareTo(b.distance));
    }

    return Column(
      children: [
        SizedBox(height: widget.topPadding),

        // ── LIST VIEW ──
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(top: 0, bottom: 120),
            itemCount: withDistance.length + (uncoordFields.isNotEmpty ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (uncoordFields.isNotEmpty && i == 0) {
                return _buildUncoordBanner(uncoordFields);
              }

              final idx = uncoordFields.isNotEmpty ? i - 1 : i;
              final item = withDistance[idx];
              final f = item.data;
              final fn = f.raw['field_number'] ?? '-';
              final projectedDap = f.dap + widget.deltaDays;

              final isSelected = widget.selectedFieldNumbers.contains(fn);
              final distKm = (item.distance / 1000).toStringAsFixed(1);
              final distM = item.distance.toInt();

              // Parse audit status dari raw data
              final auditStatus = AuditStatusHelper.fromRaw(f.raw);

              return _buildFieldCard(
                f: f,
                fn: fn,
                isSelected: isSelected,
                distKm: distKm,
                distM: distM,
                distance: item.distance,
                auditStatus: auditStatus,
                projectedDap: projectedDap,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── CARD DENGAN AUDIT STATUS ────────────────────────────
  Widget _buildFieldCard({
    required ParsedFieldData f,
    required String fn,
    required bool isSelected,
    required String distKm,
    required int distM,
    required double distance,
    required FieldAuditStatus auditStatus,
    required int projectedDap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AdvantaColors.primaryGreen.withAlpha(60)
              : AdvantaColors.deepForest.withAlpha(180),
          borderRadius: AdvantaRadius.cardRadius,
          border: Border.all(
            color: isSelected ? AdvantaColors.primaryGreen : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        // Left Border warna sesuai status audit fase aktif (Gunakan projectedDap)
        child: AuditStatusLeftBorder(
          auditStatus: auditStatus,
          dap: projectedDap,
          activePhase: widget.activePhase,
          borderRadius: AdvantaRadius.cardRadius,
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: () => widget.onFieldTap(f),
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              leading: _buildDapAvatar(
                projectedDap,
                f.raw['hybrid']?.toString(),
                isSelected,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      fn,
                      style: AdvantaText.bodyBold.copyWith(
                        color: isSelected
                            ? AdvantaColors.lightGreen
                            : Colors.white,
                      ),
                    ),
                  ),
                  // Badge status fase aktif — pakai widget.activePhase
                  // yang sudah sinkron dengan _sheetPhase dari showSheet
                  _buildActivePhaseBadge(auditStatus, projectedDap),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.raw['farmer_name'] ?? '-',
                    style: AdvantaText.caption.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  // Progress Dots
                  Row(
                    children: [
                      AuditProgressDots(status: auditStatus),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.near_me_rounded,
                        size: 11,
                        color: isSelected
                            ? AdvantaColors.lightGreen
                            : AdvantaColors.goldLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        distance > 1000 ? '$distKm km' : '$distM m',
                        style: AdvantaText.caption.copyWith(
                          color: isSelected
                              ? AdvantaColors.lightGreen
                              : AdvantaColors.goldLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: widget.isMassMode
                  ? Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? AdvantaColors.lightGreen
                          : Colors.white24,
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.directions_outlined,
                        color: AdvantaColors.lightGreen,
                      ),
                      onPressed: () => widget.onNavigateTap(f.lat, f.lng),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Badge status fase aktif sesuai pilihan user (dari widget.activePhase)
  Widget _buildActivePhaseBadge(FieldAuditStatus auditStatus, int dap) {
    final phase = widget.activePhase;
    final resolvedPhase = phase == ActivePhaseView.auto
        ? _dapToPhase(dap, auditStatus)
        : phase;

    if (resolvedPhase == ActivePhaseView.generative) {
      return AuditStatusBadge.generative(
        genStatus: auditStatus.generative,
        small: true,
      );
    } else if (resolvedPhase == ActivePhaseView.vegetative &&
        auditStatus.hasVegetativePartialProgress) {
      return AuditStatusBadge.progress(
        progressLabel: auditStatus.vegetativeProgressPercentLabel,
        small: true,
      );
    } else {
      final status = _getSingleStatus(auditStatus, resolvedPhase);
      return AuditStatusBadge.single(singleStatus: status, small: true);
    }
  }

  ActivePhaseView _dapToPhase(int dap, FieldAuditStatus status) {
    return DapHelper.getActivePhaseView(
      dap,
      hybrid: status.isPsp ? 'ASF' : (status.isSweetCorn ? 'AX01' : null),
    );
  }

  SingleAuditStatus? _getSingleStatus(
    FieldAuditStatus s,
    ActivePhaseView phase,
  ) {
    switch (phase) {
      case ActivePhaseView.vegetative:
        return s.vegetative;
      case ActivePhaseView.preHarvest:
        return s.preHarvest;
      case ActivePhaseView.harvest:
        return s.harvest;
      default:
        return null;
    }
  }

  Widget _buildDapAvatar(int dap, String? hybrid, bool isSelected) {
    final color = isSelected
        ? AdvantaColors.lightGreen
        : widget.getMarkerColor(dap, hybrid: hybrid);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: isSelected
            ? Icon(Icons.check_rounded, color: color, size: 20)
            : Text(
                '$dap',
                style: AdvantaText.label.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildUncoordBanner(List<Map<String, dynamic>> uncoordFields) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: GestureDetector(
        onTap: () => widget.onUncoordBannerTap(uncoordFields),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AdvantaColors.error.withAlpha(220),
                const Color(0xFFB71C1C).withAlpha(200),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_off_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${uncoordFields.length} Lahan Tanpa Koordinat',
                  style: AdvantaText.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
