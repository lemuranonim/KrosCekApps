// lib/screens/coverage/coverage_screen.dart
//
// COVERAGE MONITORING SCREEN
// ──────────────────────────────────────────────────────────
// Tampilan coverage adaptif berdasarkan role:
//   • Manager  → Bird's-eye: FI Rating (global) + Regional Structure
//   • QA SPV   → Supervisory: FI Tim Rating + Coverage Structure area tim
//   • QA FI    → Operational: Village Coverage List + Route Planning
//
// Data source: masterFieldsProvider (master_fields + semua audit join)
// ──────────────────────────────────────────────────────────

// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/master_fields_provider.dart';
import '../../services/session_manager.dart';
import '../../utils/dap_helper.dart';

// PENTING: Sesuaikan path import ini dengan struktur project-mu
import '../../widgets/field_detail_bottom_sheet.dart';
import '../../theme/app_theme.dart';

// ============================================================
// SECTION A — DATA MODELS
// ============================================================

/// Status coverage untuk satu field, dihitung dari data audit.
class FieldCoverageStatus {
  final Map<String, dynamic> raw; // DISIMPAN UNTUK MENGIRIM KE DETAIL SHEET
  final String fieldNumber;
  final String qaFi;
  final String qaSpv;
  final String region;
  final String district;
  final String village;
  final String subDistrict;
  final double effectiveAreaHa;
  final int dap;

  final bool vegetativeDone;
  final bool gen1Done;
  final bool gen2Done;
  final bool gen3Done;
  final bool preHarvestDone;
  final bool harvestDone;

  /// Apakah ada fase yang seharusnya On Going tapi belum diaudit
  final bool isOverdue;

  const FieldCoverageStatus({
    required this.raw,
    required this.fieldNumber,
    required this.qaFi,
    required this.qaSpv,
    required this.region,
    required this.district,
    required this.village,
    required this.subDistrict,
    required this.effectiveAreaHa,
    required this.dap,
    required this.vegetativeDone,
    required this.gen1Done,
    required this.gen2Done,
    required this.gen3Done,
    required this.preHarvestDone,
    required this.harvestDone,
    required this.isOverdue,
  });

  /// Jumlah fase yang sudah selesai dari fase yang relevan DAP
  int get donePhasesCount {
    int count = 0;
    if (vegetativeDone) count++;
    if (gen1Done) count++;
    if (gen2Done) count++;
    if (gen3Done) count++;
    if (preHarvestDone) count++;
    if (harvestDone) count++;
    return count;
  }

  /// Coverage score 0-100 berdasarkan fase yang sudah On Going / Overdue
  double get coverageScore {
    final relevantPhases = _getRelevantPhases();
    if (relevantPhases.isEmpty) return 100.0;
    int done = 0;
    for (final phase in relevantPhases) {
      if (_isPhaseComplete(phase)) done++;
    }
    return (done / relevantPhases.length) * 100;
  }

  List<String> _getRelevantPhases() {
    final phases = <String>[];
    final badge = DapHelper.getDapBadgeLabel(dap, 'vegetative');
    if (badge == 'On Going' || badge == 'Overdue') phases.add('vegetative');
    final g1badge = DapHelper.getDapBadgeLabel(dap, 'generative_1');
    if (g1badge == 'On Going' || g1badge == 'Overdue') phases.add('generative_1');
    final g2badge = DapHelper.getDapBadgeLabel(dap, 'generative_2');
    if (g2badge == 'On Going' || g2badge == 'Overdue') phases.add('generative_2');
    final g3badge = DapHelper.getDapBadgeLabel(dap, 'generative_3');
    if (g3badge == 'On Going' || g3badge == 'Overdue') phases.add('generative_3');
    final phbadge = DapHelper.getDapBadgeLabel(dap, 'pre_harvest');
    if (phbadge == 'On Going' || phbadge == 'Overdue') phases.add('pre_harvest');
    final hvbadge = DapHelper.getDapBadgeLabel(dap, 'harvest');
    if (hvbadge == 'On Going' || hvbadge == 'Overdue') phases.add('harvest');
    return phases;
  }

  bool _isPhaseComplete(String phase) {
    switch (phase) {
      case 'vegetative': return vegetativeDone;
      case 'generative_1': return gen1Done;
      case 'generative_2': return gen2Done;
      case 'generative_3': return gen3Done;
      case 'pre_harvest': return preHarvestDone;
      case 'harvest': return harvestDone;
      default: return false;
    }
  }

  String get statusLabel {
    final score = coverageScore;
    if (score >= 85) return 'On Track';
    if (score >= 50) return 'At Risk';
    return 'Behind';
  }

  Color get statusColor {
    switch (statusLabel) {
      case 'On Track': return AdvantaColors.success;
      case 'At Risk': return const Color(0xFFD4A017);
      default: return AdvantaColors.error;
    }
  }

  factory FieldCoverageStatus.fromRaw(Map<String, dynamic> raw) {
    final dap = DapHelper.calculateDAP(raw['planting_date_pdn']?.toString());

    Map<String, dynamic>? firstOf(dynamic val) {
      if (val is List && val.isNotEmpty) return val[0] as Map<String, dynamic>?;
      if (val is Map) return Map<String, dynamic>.from(val);
      return null;
    }

    // FUNGSI BARU: Mengecek apakah tanggal benar-benar ada (tidak null dan tidak kosong)
    bool hasDate(dynamic val) {
      return val != null && val.toString().trim().isNotEmpty;
    }

    // 1. Cek Fase Vegetatif
    final veg = firstOf(raw['audit_vegetative']);
    final vegDone = hasDate(veg?['date_of_audit']);

    // 2. Cek Fase Generatif (PERBAIKAN NAMA KOLOM DI SINI)
    final gen = firstOf(raw['audit_generative']);
    final gen1Done = hasDate(gen?['date_of_audit_1']);
    final gen2Done = hasDate(gen?['date_of_audit_2']);
    final gen3Done = hasDate(gen?['date_of_audit_3']);

    // 3. Cek Fase Pre-Harvest
    final ph = firstOf(raw['audit_pre_harvest']);
    final phDone = hasDate(ph?['audit_date']);

    // 4. Cek Fase Harvest
    final hv = firstOf(raw['audit_harvest']);
    final hvDone = hasDate(hv?['date_of_audit']);

    bool overdue = false;
    final phaseKeys = ['vegetative', 'generative_1', 'generative_2', 'generative_3', 'pre_harvest', 'harvest'];
    final phaseDone = [vegDone, gen1Done, gen2Done, gen3Done, phDone, hvDone];
    for (int i = 0; i < phaseKeys.length; i++) {
      final badge = DapHelper.getDapBadgeLabel(dap, phaseKeys[i]);
      if (badge == 'Overdue' && !phaseDone[i]) {
        overdue = true;
        break;
      }
    }

    return FieldCoverageStatus(
      raw: raw,
      fieldNumber: raw['field_number']?.toString() ?? '',
      qaFi: raw['qa_fi']?.toString().trim() ?? '',
      qaSpv: raw['qa_spv']?.toString().trim() ?? '',
      region: raw['region']?.toString().trim() ?? '',
      district: raw['district_kab']?.toString().trim() ?? '',
      village: raw['village_desa']?.toString().trim() ?? '',
      subDistrict: raw['sub_district_kec']?.toString().trim() ?? '',
      effectiveAreaHa: (raw['effective_area_ha'] as num?)?.toDouble() ?? 0.0,
      dap: dap,
      vegetativeDone: vegDone,
      gen1Done: gen1Done,
      gen2Done: gen2Done,
      gen3Done: gen3Done,
      preHarvestDone: phDone,
      harvestDone: hvDone,
      isOverdue: overdue,
    );
  }
}

/// Ringkasan coverage per FI
class FICoverage {
  final String name;
  final String region;
  final String qaSpv;
  final double totalAreaHa;
  final int totalFields;
  final double coverageScore;
  final int overdueFields;
  final List<FieldCoverageStatus> fields;

  const FICoverage({
    required this.name,
    required this.region,
    required this.qaSpv,
    required this.totalAreaHa,
    required this.totalFields,
    required this.coverageScore,
    required this.overdueFields,
    required this.fields,
  });

  String get statusLabel {
    if (coverageScore >= 85) return 'On Track';
    if (coverageScore >= 50) return 'At Risk';
    return 'Behind';
  }

  Color get statusColor {
    switch (statusLabel) {
      case 'On Track': return AdvantaColors.success;
      case 'At Risk': return const Color(0xFFD4A017);
      default: return AdvantaColors.error;
    }
  }

  static FICoverage fromFields(String name, List<FieldCoverageStatus> fields) {
    final totalArea = fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
    final scores = fields.map((f) => f.coverageScore).toList();
    final avgScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final overdue = fields.where((f) => f.isOverdue).length;
    return FICoverage(
      name: name,
      region: fields.isNotEmpty ? fields.first.region : '',
      qaSpv: fields.isNotEmpty ? fields.first.qaSpv : '',
      totalAreaHa: totalArea,
      totalFields: fields.length,
      coverageScore: avgScore,
      overdueFields: overdue,
      fields: fields,
    );
  }
}

/// Summary statistik phase coverage
class PhaseCoverage {
  final String label;
  final String shortLabel;
  final Color color;
  final int total;
  final int done;
  double get pct => total == 0 ? 0 : (done / total) * 100;

  const PhaseCoverage({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.total,
    required this.done,
  });
}

// ============================================================
// FUNGSI HELPER UNTUK MENGHITUNG FASE DINAMIS (TERFILTER)
// ============================================================
List<PhaseCoverage> calculateFilteredPhases(List<FieldCoverageStatus> filteredFields, {bool includeUpcoming = false}) {
  final colors = [AdvantaColors.lightGreen, AdvantaColors.gold, AdvantaColors.midGreen, AdvantaColors.error];

  int vegTotal = 0, vegDone = 0;
  int genTotal = 0, genDone = 0;
  int phTotal = 0, phDone = 0;
  int hvTotal = 0, hvDone = 0;

  for (final f in filteredFields) {
    // Vegetative
    final vBadge = DapHelper.getDapBadgeLabel(f.dap, 'vegetative');
    if (includeUpcoming || vBadge == 'On Going' || vBadge == 'Overdue') {
      vegTotal++;
      if (f.vegetativeDone) vegDone++;
    }

    // Generative
    bool genRelevant = false;
    bool genAnyDone = false;
    for (final gPhase in ['generative_1', 'generative_2', 'generative_3']) {
      final gBadge = DapHelper.getDapBadgeLabel(f.dap, gPhase);
      if (includeUpcoming || gBadge == 'On Going' || gBadge == 'Overdue') {
        genRelevant = true;
        final done = gPhase == 'generative_1' ? f.gen1Done : gPhase == 'generative_2' ? f.gen2Done : f.gen3Done;
        if (done) genAnyDone = true;
      }
    }
    if (genRelevant) { genTotal++; if (genAnyDone) genDone++; }

    // Pre-Harvest
    final phBadge = DapHelper.getDapBadgeLabel(f.dap, 'pre_harvest');
    if (includeUpcoming || phBadge == 'On Going' || phBadge == 'Overdue') {
      phTotal++;
      if (f.preHarvestDone) phDone++;
    }

    // Harvest
    final hvBadge = DapHelper.getDapBadgeLabel(f.dap, 'harvest');
    if (includeUpcoming || hvBadge == 'On Going' || hvBadge == 'Overdue') {
      hvTotal++;
      if (f.harvestDone) hvDone++;
    }
  }

  return [
    PhaseCoverage(label: 'Vegetative', shortLabel: 'Veg', color: colors[0], total: vegTotal, done: vegDone),
    PhaseCoverage(label: 'Generative', shortLabel: 'Gen', color: colors[1], total: genTotal, done: genDone),
    PhaseCoverage(label: 'Pre-Harvest', shortLabel: 'Pre-H', color: colors[2], total: phTotal, done: phDone),
    PhaseCoverage(label: 'Harvest', shortLabel: 'Harv', color: colors[3], total: hvTotal, done: hvDone),
  ];
}

// ============================================================
// SECTION B — PROVIDERS
// ============================================================

final coverageStatusListProvider = FutureProvider<List<FieldCoverageStatus>>((ref) async {
  final rawFields = await ref.watch(masterFieldsProvider.future);

  if (kDebugMode) {
    print('=== COVERAGE DEBUG ===');
    print('Raw fields count: ${rawFields.length}');
    if (rawFields.isNotEmpty) {
      final f = rawFields.first;
      print('First: ${f['field_number']} | qa_fi: ${f['qa_fi']} | area: ${f['effective_area_ha']} | planting: ${f['planting_date_pdn']}');
      print('audit_vegetative: ${f['audit_vegetative'].runtimeType} = ${f['audit_vegetative']}');
      print('audit_generative: ${f['audit_generative'].runtimeType} = ${f['audit_generative']}');
      print('audit_pre_harvest: ${f['audit_pre_harvest'].runtimeType} = ${f['audit_pre_harvest']}');
      print('audit_harvest: ${f['audit_harvest'].runtimeType} = ${f['audit_harvest']}');
    }
  }

  final parsed = rawFields.map((raw) => FieldCoverageStatus.fromRaw(raw)).toList();

  if (kDebugMode) {
    final totalArea = parsed.fold(0.0, (s, f) => s + f.effectiveAreaHa);
    final overdueCount = parsed.where((f) => f.isOverdue).length;
    final vegDoneCount = parsed.where((f) => f.vegetativeDone).length;
    print('Parsed: ${parsed.length} | Area: ${totalArea.toStringAsFixed(1)} ha | Overdue: $overdueCount | VegDone: $vegDoneCount');
    print('======================');
  }

  return parsed;
});

final phaseSummaryProvider = FutureProvider<List<PhaseCoverage>>((ref) async {
  final fields = await ref.watch(coverageStatusListProvider.future);
  final colors = [AdvantaColors.lightGreen, AdvantaColors.gold, AdvantaColors.midGreen, AdvantaColors.error];

  int vegTotal = 0, vegDone = 0;
  int genTotal = 0, genDone = 0;
  int phTotal = 0, phDone = 0;
  int hvTotal = 0, hvDone = 0;

  for (final f in fields) {
    final vBadge = DapHelper.getDapBadgeLabel(f.dap, 'vegetative');
    if (vBadge == 'On Going' || vBadge == 'Overdue') { vegTotal++; if (f.vegetativeDone) vegDone++; }

    bool genRelevant = false;
    bool genAnyDone = false;
    for (final gPhase in ['generative_1', 'generative_2', 'generative_3']) {
      final gBadge = DapHelper.getDapBadgeLabel(f.dap, gPhase);
      if (gBadge == 'On Going' || gBadge == 'Overdue') {
        genRelevant = true;
        final done = gPhase == 'generative_1' ? f.gen1Done : gPhase == 'generative_2' ? f.gen2Done : f.gen3Done;
        if (done) genAnyDone = true;
      }
    }
    if (genRelevant) { genTotal++; if (genAnyDone) genDone++; }

    final phBadge = DapHelper.getDapBadgeLabel(f.dap, 'pre_harvest');
    if (phBadge == 'On Going' || phBadge == 'Overdue') { phTotal++; if (f.preHarvestDone) phDone++; }

    final hvBadge = DapHelper.getDapBadgeLabel(f.dap, 'harvest');
    if (hvBadge == 'On Going' || hvBadge == 'Overdue') { hvTotal++; if (f.harvestDone) hvDone++; }
  }

  return [
    PhaseCoverage(label: 'Vegetative', shortLabel: 'Veg', color: colors[0], total: vegTotal, done: vegDone),
    PhaseCoverage(label: 'Generative', shortLabel: 'Gen', color: colors[1], total: genTotal, done: genDone),
    PhaseCoverage(label: 'Pre-Harvest', shortLabel: 'Pre-H', color: colors[2], total: phTotal, done: phDone),
    PhaseCoverage(label: 'Harvest', shortLabel: 'Harv', color: colors[3], total: hvTotal, done: hvDone),
  ];
});

final fiCoverageListProvider = FutureProvider<List<FICoverage>>((ref) async {
  final fields = await ref.watch(coverageStatusListProvider.future);
  final grouped = <String, List<FieldCoverageStatus>>{};
  for (final f in fields) {
    if (f.qaFi.isEmpty) continue;
    grouped.putIfAbsent(f.qaFi, () => []).add(f);
  }
  final list = grouped.entries.map((e) => FICoverage.fromFields(e.key, e.value)).toList();
  list.sort((a, b) => b.coverageScore.compareTo(a.coverageScore));
  return list;
});

// ============================================================
// SECTION C — COVERAGE SCREEN (Root)
// ============================================================

class CoverageScreen extends ConsumerStatefulWidget {
  const CoverageScreen({super.key});

  @override
  ConsumerState<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends ConsumerState<CoverageScreen> with SingleTickerProviderStateMixin {
  ActiveSession? _session;
  bool _sessionLoaded = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadSession();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final s = await SessionManager.instance.getActiveSession();
    if (mounted) {
      setState(() { _session = s; _sessionLoaded = true; });
      _fadeCtrl.forward();
    }
  }

  String get _role => _session?.role.toUpperCase() ?? 'FI';

  // Dev & Manager masuk ke Manager View
  bool get _isManager => _role == 'MANAGER' || _role == 'DEV';

  // SPV murni menggunakan role SPV
  bool get _isSpv => _role == 'SPV';

  @override
  Widget build(BuildContext context) {
    if (!_sessionLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isManager
            ? _ManagerView(session: _session!)
            : _isSpv
            ? _SPVView(session: _session!)
            : _FIView(session: _session!),
      ),
    );
  }
}

// ============================================================
// SECTION D — MANAGER VIEW
// ============================================================

class _ManagerView extends ConsumerStatefulWidget {
  final ActiveSession session;
  const _ManagerView({required this.session});
  @override
  ConsumerState<_ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends ConsumerState<_ManagerView> {
  String? _selectedRegion;
  String? _selectedDistrict; // cascade dari region
  String? _selectedSpv;
  int _expandedAreaIndex = -1;
  bool _showAllFI = false;
  bool _showAllRegisteredFields = false; // Default: hanya yang wajib audit

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(coverageStatusListProvider);
    final fiListAsync = ref.watch(fiCoverageListProvider);

    return fieldsAsync.when(
      loading: () => const _SkeletonLoader(),
      error: (e, _) => _CoverageErrorWidget(error: e.toString()),
      data: (allFields) {
        // CASCADING LOGIC — Region → District → SPV
        final regions = allFields.map((f) => f.region).where((r) => r.isNotEmpty).toSet().toList()..sort();
        final districtOptions = allFields
            .where((f) => _selectedRegion == null || f.region == _selectedRegion)
            .map((f) => f.district).where((d) => d.isNotEmpty).toSet().toList()..sort();
        final spvOptions = allFields
            .where((f) {
          if (_selectedRegion != null && f.region != _selectedRegion) return false;
          if (_selectedDistrict != null && f.district != _selectedDistrict) return false;
          return true;
        })
            .map((f) => f.qaSpv).where((s) => s.isNotEmpty).toSet().toList()..sort();

        // Apply filters
        final filtered = allFields.where((f) {
          if (_selectedRegion != null && f.region != _selectedRegion) return false;
          if (_selectedDistrict != null && f.district != _selectedDistrict) return false;
          if (_selectedSpv != null && f.qaSpv != _selectedSpv) return false;
          return true;
        }).toList();

        final filteredFI = fiListAsync.value ?? [];
        final filteredFIList = filteredFI.where((fi) {
          if (_selectedRegion != null && fi.region != _selectedRegion) return false;
          if (_selectedSpv != null && fi.qaSpv != _selectedSpv) return false;
          return true;
        }).toList();

        final totalArea = filtered.fold(0.0, (s, f) => s + f.effectiveAreaHa);
        final uniqueSpv = filtered.map((f) => f.qaSpv).where((s) => s.isNotEmpty).toSet();
        final uniqueFI = filtered.map((f) => f.qaFi).where((s) => s.isNotEmpty).toSet();
        final needsAttention = filtered.where((f) => f.isOverdue).length;

        final regionMap = _buildRegionMap(filtered);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _CoverageHeader(title: 'Coverage Monitoring', subtitle: 'Manager View', session: widget.session)),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: [
                  PremiumFilterChip(
                    label: _selectedRegion ?? 'All Region',
                    options: ['All Region', ...regions],
                    selected: _selectedRegion,
                    icon: Icons.map_rounded,
                    onSelected: (v) => setState(() {
                      _selectedRegion = v == 'All Region' ? null : v;
                      _selectedDistrict = null;
                      _selectedSpv = null;
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedDistrict ?? 'All Kabupaten',
                    options: ['All Kabupaten', ...districtOptions],
                    selected: _selectedDistrict,
                    icon: Icons.location_city_rounded,
                    onSelected: (v) => setState(() {
                      _selectedDistrict = v == 'All Kabupaten' ? null : v;
                      _selectedSpv = null;
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedSpv ?? 'All QA SPV',
                    options: ['All QA SPV', ...spvOptions],
                    selected: _selectedSpv,
                    icon: Icons.supervisor_account_rounded,
                    onSelected: (v) => setState(() => _selectedSpv = v == 'All QA SPV' ? null : v),
                  ),
                  // Di dalam Row filter:
                  PremiumFilterChip(
                    label: _showAllRegisteredFields ? 'Semua Lahan' : 'Target Audit',
                    options: const ['Target Audit', 'Semua Lahan'],
                    selected: _showAllRegisteredFields ? 'Semua Lahan' : 'Target Audit',
                    icon: Icons.visibility_rounded,
                    onSelected: (v) => setState(() => _showAllRegisteredFields = v == 'Semua Lahan'),
                  ),
                ],
                onRefresh: () => ref.refresh(masterFieldsProvider),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsRow(stats: [
                _StatCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AdvantaColors.deepForest,
                  bgColor: Colors.grey[200]!,
                  value: allFields.length.toString(), // Total database
                  label: 'Master Lahan',
                ),
                _StatCard(icon: Icons.landscape_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.paleGreen, value: _formatHa(totalArea), label: 'Coverage Area'),
                _StatCard(icon: Icons.supervisor_account_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.paleGreen, value: uniqueSpv.length.toString(), label: 'Active SPV'),
                _StatCard(icon: Icons.person_rounded, iconColor: AdvantaColors.gold, bgColor: AdvantaColors.goldPale, value: uniqueFI.length.toString(), label: 'Active FI'),
                _StatCard(icon: Icons.warning_amber_rounded, iconColor: AdvantaColors.error, bgColor: AdvantaColors.errorLight, value: needsAttention.toString(), label: 'Needs Attention', highlight: needsAttention > 0),
              ]),
            ),
            SliverToBoxAdapter(
              child: _PhaseProgressSection(
                phases: calculateFilteredPhases(
                    filtered,
                    includeUpcoming: _showAllRegisteredFields // <--- Kirim state toggle di sini
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _FIRatingPanel(
                        fiList: _showAllFI ? filteredFIList : filteredFIList.take(5).toList(),
                        title: 'FI Rating',
                        subtitle: '${filteredFIList.length} FI',
                        showViewAll: filteredFIList.length > 5,
                        onViewAll: () => setState(() => _showAllFI = !_showAllFI),
                        isShowingAll: _showAllFI,
                        // 👇 TAMBAHKAN KODE INI AGAR FI RATING BISA DIKLIK 👇
                        onFiTapped: (fiData) {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => _FIDetailSheet(fi: fiData),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: _RegionalStructurePanel(regionMap: regionMap, expandedIndex: _expandedAreaIndex, onToggle: (i) => setState(() => _expandedAreaIndex = _expandedAreaIndex == i ? -1 : i))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, Map<String, dynamic>> _buildRegionMap(List<FieldCoverageStatus> fields) {
    final map = <String, Map<String, dynamic>>{};
    for (final f in fields) {
      final region = f.region.isEmpty ? 'Unknown' : f.region;
      map.putIfAbsent(region, () => {'fields': <FieldCoverageStatus>[], 'spvSet': <String>{}, 'fiSet': <String>{}});
      (map[region]!['fields'] as List).add(f);
      if (f.qaSpv.isNotEmpty) (map[region]!['spvSet'] as Set).add(f.qaSpv);
      if (f.qaFi.isNotEmpty) (map[region]!['fiSet'] as Set).add(f.qaFi);
    }
    return map;
  }
}

// ============================================================
// SECTION E — QA SPV VIEW
// ============================================================

class _SPVView extends ConsumerStatefulWidget {
  final ActiveSession session;
  const _SPVView({required this.session});
  @override
  ConsumerState<_SPVView> createState() => _SPVViewState();
}

class _SPVViewState extends ConsumerState<_SPVView> {
  String? _selectedDistrict;
  String? _selectedFi;
  bool _showAllFI = false;
  int _expandedDistrictIndex = -1;
  bool _showAllRegisteredFields = false; // Default: hanya yang wajib audit

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(coverageStatusListProvider);

    return fieldsAsync.when(
      loading: () => const _SkeletonLoader(),
      error: (e, _) => _CoverageErrorWidget(error: e.toString()),
      data: (allFields) {

        // 1. FILTER DASAR: Ambil hanya lahan milik SPV yang sedang login
        final String myName = widget.session.name.trim().toLowerCase();
        final mySpvFields = allFields.where((f) =>
        f.qaSpv.trim().toLowerCase() == myName
        ).toList();

        // 2. CASCADING LOGIC SPV (Berdasarkan lahan milik SPV ini saja)
        final districts = mySpvFields.map((f) => f.district).where((d) => d.isNotEmpty).toSet().toList()..sort();
        final fiOptions = mySpvFields
            .where((f) => _selectedDistrict == null || f.district == _selectedDistrict)
            .map((f) => f.qaFi).where((s) => s.isNotEmpty).toSet().toList()..sort();

        // 3. APPLY FILTER DROPDOWN USER
        final fields = mySpvFields.where((f) {
          if (_selectedDistrict != null && f.district != _selectedDistrict) return false;
          if (_selectedFi != null && f.qaFi != _selectedFi) return false;
          return true;
        }).toList();

        // Hitung Statistik
        final totalArea = fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
        final uniqueFI = fields.map((f) => f.qaFi).where((s) => s.isNotEmpty).toSet();
        final onTrack = uniqueFI.where((fi) {
          final fiFields = fields.where((f) => f.qaFi == fi).toList();
          final score = fiFields.isEmpty ? 0.0 : fiFields.map((f) => f.coverageScore).reduce((a, b) => a + b) / fiFields.length;
          return score >= 85;
        }).length;
        final needsAttention = fields.where((f) => f.isOverdue).map((f) => f.qaFi).toSet().length;

        final fiMap = <String, List<FieldCoverageStatus>>{};
        for (final f in fields) { if (f.qaFi.isNotEmpty) fiMap.putIfAbsent(f.qaFi, () => []).add(f); }
        final fiList = fiMap.entries.map((e) => FICoverage.fromFields(e.key, e.value)).toList()..sort((a, b) => b.coverageScore.compareTo(a.coverageScore));

        final districtMap = <String, List<FieldCoverageStatus>>{};
        for (final f in fields) {
          final key = f.district.isEmpty ? 'Unknown' : f.district;
          districtMap.putIfAbsent(key, () => []).add(f);
        }
        final districtEntries = districtMap.entries.toList()..sort((a, b) => _avgScore(b.value).compareTo(_avgScore(a.value)));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _CoverageHeader(title: 'Coverage Monitoring', subtitle: 'QA SPV — ${widget.session.name}', session: widget.session)),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: [
                  PremiumFilterChip(
                    label: _selectedDistrict ?? 'All Kabupaten',
                    options: ['All Kabupaten', ...districts],
                    selected: _selectedDistrict,
                    icon: Icons.location_city_rounded,
                    onSelected: (v) => setState(() {
                      _selectedDistrict = v == 'All Kabupaten' ? null : v;
                      _selectedFi = null; // Reset FI jika Kabupaten berubah
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedFi ?? 'All QA FI',
                    options: ['All QA FI', ...fiOptions],
                    selected: _selectedFi,
                    icon: Icons.person_search_rounded,
                    onSelected: (v) => setState(() => _selectedFi = v == 'All QA FI' ? null : v),
                  ),
                  // Di dalam Row filter:
                  PremiumFilterChip(
                    label: _showAllRegisteredFields ? 'Semua Lahan' : 'Target Audit',
                    options: const ['Target Audit', 'Semua Lahan'],
                    selected: _showAllRegisteredFields ? 'Semua Lahan' : 'Target Audit',
                    icon: Icons.visibility_rounded,
                    onSelected: (v) => setState(() => _showAllRegisteredFields = v == 'Semua Lahan'),
                  ),
                ],
                onRefresh: () => ref.refresh(masterFieldsProvider),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsRow(stats: [
                _StatCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AdvantaColors.deepForest,
                  bgColor: Colors.grey[200]!,
                  value: allFields.length.toString(), // Total database
                  label: 'Master Lahan',
                ),
                _StatCard(icon: Icons.landscape_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.paleGreen, value: _formatHa(totalArea), label: 'Coverage Area'),
                _StatCard(icon: Icons.people_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.paleGreen, value: uniqueFI.length.toString(), label: 'Active FI'),
                _StatCard(icon: Icons.check_circle_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.successLight, value: onTrack.toString(), label: 'On Track FI'),
                _StatCard(icon: Icons.warning_amber_rounded, iconColor: AdvantaColors.error, bgColor: AdvantaColors.errorLight, value: needsAttention.toString(), label: 'Needs Attention', highlight: needsAttention > 0),
              ]),
            ),
            SliverToBoxAdapter(
              child: _PhaseProgressSection(
                phases: calculateFilteredPhases(
                    fields, // <--- Gunakan 'fields', bukan 'filtered'
                    includeUpcoming: _showAllRegisteredFields
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _FIRatingPanel(
                        fiList: _showAllFI ? fiList : fiList.take(5).toList(),
                        title: 'FI Rating Tim',
                        subtitle: '${fiList.length} FI',
                        showViewAll: fiList.length > 5,
                        onViewAll: () => setState(() => _showAllFI = !_showAllFI),
                        isShowingAll: _showAllFI,
                        // 👇 Panggil Skenario 1 dan 2 di sini!
                        onFiTapped: (fiData) {
                          // Skenario 1: Filter layar utama di belakang (Quick Filter)
                          setState(() {
                            _selectedFi = fiData.name;
                          });

                          // Skenario 2: Tampilkan Detail Bottom Sheet di depan
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => _FIDetailSheet(fi: fiData),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: _CoverageStructurePanel(districts: districtEntries, expandedIndex: _expandedDistrictIndex, onToggle: (i) => setState(() => _expandedDistrictIndex = _expandedDistrictIndex == i ? -1 : i))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _avgScore(List<FieldCoverageStatus> fields) {
    if (fields.isEmpty) return 0;
    return fields.map((f) => f.coverageScore).reduce((a, b) => a + b) / fields.length;
  }
}

// ============================================================
// SECTION F — QA FI VIEW
// ============================================================

class _FIView extends ConsumerStatefulWidget {
  final ActiveSession session;
  const _FIView({required this.session});
  @override
  ConsumerState<_FIView> createState() => _FIViewState();
}

class _FIViewState extends ConsumerState<_FIView> {
  String? _selectedDistrict;
  String? _selectedVillage;
  String? _selectedPhase;
  int _expandedVillageIndex = -1;

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(coverageStatusListProvider);

    return fieldsAsync.when(
      loading: () => const _SkeletonLoader(),
      error: (e, _) => _CoverageErrorWidget(error: e.toString()),
      data: (allFields) {

        // 1. FILTER DASAR: Ambil hanya lahan milik QA FI yang sedang login
        final String myName = widget.session.name.trim().toLowerCase();
        final myFiFields = allFields.where((f) =>
        f.qaFi.trim().toLowerCase() == myName
        ).toList();

        // 2. CASCADING LOGIC FI (Gunakan myFiFields)
        final districts = myFiFields.map((f) => f.district).where((d) => d.isNotEmpty).toSet().toList()..sort();
        final villageOptions = myFiFields
            .where((f) => _selectedDistrict == null || f.district == _selectedDistrict)
            .map((f) => f.village).where((v) => v.isNotEmpty).toSet().toList()..sort();

        // 3. APPLY FILTERS DROPDOWN USER
        final fields = myFiFields.where((f) {
          if (_selectedDistrict != null && f.district != _selectedDistrict) return false;
          if (_selectedVillage != null && f.village != _selectedVillage) return false;
          if (_selectedPhase != null && _selectedPhase != 'All Phase') {
            switch (_selectedPhase) {
              case 'Vegetative': return DapHelper.getDapBadgeLabel(f.dap, 'vegetative') == 'On Going' || DapHelper.getDapBadgeLabel(f.dap, 'vegetative') == 'Overdue';
              case 'Generative': return ['generative_1', 'generative_2', 'generative_3'].any((p) {
                final b = DapHelper.getDapBadgeLabel(f.dap, p);
                return b == 'On Going' || b == 'Overdue';
              });
              case 'Pre-Harvest': return DapHelper.getDapBadgeLabel(f.dap, 'pre_harvest') == 'On Going' || DapHelper.getDapBadgeLabel(f.dap, 'pre_harvest') == 'Overdue';
              case 'Harvest': return DapHelper.getDapBadgeLabel(f.dap, 'harvest') == 'On Going' || DapHelper.getDapBadgeLabel(f.dap, 'harvest') == 'Overdue';
            }
          }
          return true;
        }).toList();

        final totalArea = fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
        final villagesCount = fields.map((f) => f.village).where((v) => v.isNotEmpty).toSet().length;
        final overdueFields = fields.where((f) => f.isOverdue).length;

        final villageMap = <String, List<FieldCoverageStatus>>{};
        for (final f in fields) {
          final key = f.village.isEmpty ? 'Unknown' : f.village;
          villageMap.putIfAbsent(key, () => []).add(f);
        }

        final villageEntries = villageMap.entries.toList()..sort((a, b) => _avgScore(a.value).compareTo(_avgScore(b.value))); // Worst first

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _CoverageHeader(title: 'Coverage Monitoring', subtitle: 'QA FI — ${widget.session.name}', session: widget.session)),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: [
                  PremiumFilterChip(
                    label: _selectedDistrict ?? 'All Kabupaten',
                    options: ['All Kabupaten', ...districts],
                    selected: _selectedDistrict,
                    icon: Icons.location_city_rounded,
                    onSelected: (v) => setState(() {
                      _selectedDistrict = v == 'All Kabupaten' ? null : v;
                      _selectedVillage = null;
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedVillage ?? 'All Desa',
                    options: ['All Desa', ...villageOptions],
                    selected: _selectedVillage,
                    icon: Icons.holiday_village_rounded,
                    onSelected: (v) => setState(() => _selectedVillage = v == 'All Desa' ? null : v),
                  ),
                  PremiumFilterChip(
                    label: _selectedPhase ?? 'All Phase',
                    options: const ['All Phase', 'Vegetative', 'Generative', 'Pre-Harvest', 'Harvest'],
                    selected: _selectedPhase,
                    icon: Icons.grass_rounded,
                    onSelected: (v) => setState(() => _selectedPhase = v == 'All Phase' ? null : v),
                  ),
                ],
                onRefresh: () => ref.refresh(masterFieldsProvider),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsRow(stats: [
                _StatCard(icon: Icons.landscape_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.paleGreen, value: _formatHa(totalArea), label: 'Assigned Area'),
                _StatCard(icon: Icons.location_city_rounded, iconColor: AdvantaColors.midGreen, bgColor: AdvantaColors.paleGreen, value: villagesCount.toString(), label: 'Villages'),
                _StatCard(icon: Icons.checklist_rounded, iconColor: AdvantaColors.gold, bgColor: AdvantaColors.goldPale, value: '${fields.where((f) => f.donePhasesCount > 0).length}', label: 'Fields Today'),
                _StatCard(icon: Icons.running_with_errors_rounded, iconColor: AdvantaColors.error, bgColor: AdvantaColors.errorLight, value: overdueFields.toString(), label: 'Overdue', highlight: overdueFields > 0),
              ]),
            ),
            SliverToBoxAdapter(
              child: _PhaseProgressSection(
                phases: calculateFilteredPhases(fields), // <-- GUNAKAN DATA FIELDS
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Text('Village Coverage List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
                    const Spacer(),
                    Text('${villageEntries.length} desa', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                  final entry = villageEntries[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _VillageCard(
                      villageName: entry.key,
                      fields: entry.value,
                      isExpanded: _expandedVillageIndex == i,
                      onTap: () => setState(() => _expandedVillageIndex = _expandedVillageIndex == i ? -1 : i),
                    ),
                  );
                },
                childCount: villageEntries.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _OpenRouteButton(fields: fields),
              ),
            ),
          ],
        );
      },
    );
  }

  double _avgScore(List<FieldCoverageStatus> fields) {
    if (fields.isEmpty) return 0;
    return fields.map((f) => f.coverageScore).reduce((a, b) => a + b) / fields.length;
  }
}

// ============================================================
// SECTION G — SHARED WIDGETS & PREMIUM UI
// ============================================================

/// WIDGET FILTER PREMIUM BARU
class PremiumFilterChip extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final IconData icon;
  final ValueChanged<String> onSelected;

  const PremiumFilterChip({
    required this.label,
    required this.options,
    required this.selected,
    required this.icon,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selected != null;
    return GestureDetector(
      onTap: () => _showPremiumPicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(colors: [AdvantaColors.deepForest, AdvantaColors.midGreen])
              : const LinearGradient(colors: [Colors.white, Colors.white]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.transparent : AdvantaColors.dividerGrey,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? AdvantaColors.deepForest.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
              blurRadius: isActive ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : AdvantaColors.mutedGrey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? Colors.white : AdvantaColors.charcoal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isActive ? Colors.white : AdvantaColors.mutedGrey),
          ],
        ),
      ),
    );
  }

  void _showPremiumPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PremiumFilterModal(
        title: 'Pilih Filter',
        options: options,
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}

class _PremiumFilterModal extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _PremiumFilterModal({required this.title, required this.options, required this.selected, required this.onSelected});

  @override
  State<_PremiumFilterModal> createState() => _PremiumFilterModalState();
}

class _PremiumFilterModalState extends State<_PremiumFilterModal> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredOptions = widget.options.where((opt) => opt.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: AdvantaColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
            const SizedBox(height: 16),

            // Search Bar
            if (widget.options.length > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AdvantaColors.softGrey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari data...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

            // List Options
            Expanded(
              child: filteredOptions.isEmpty
                  ? Center(child: Text('Tidak ditemukan', style: TextStyle(color: Colors.grey[400])))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filteredOptions.length,
                itemBuilder: (ctx, i) {
                  final opt = filteredOptions[i];
                  final isSelected = widget.selected == opt || (widget.selected == null && opt.startsWith('All'));

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelected(opt);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AdvantaColors.paleGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AdvantaColors.deepForest.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  opt,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AdvantaColors.deepForest : AdvantaColors.charcoal
                                  )
                              )
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AdvantaColors.deepForest, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Komponen Header dan Utilities Lainnya tetap sama
class _CoverageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final ActiveSession session;

  const _CoverageHeader({required this.title, required this.subtitle, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AdvantaColors.deepForest, AdvantaColors.primaryGreen]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(session.name.isNotEmpty ? session.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12))])),
              Stack(children: [IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}), Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFB300), shape: BoxShape.circle)))])
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<Widget> filters;
  final VoidCallback onRefresh;

  const _FilterBar({required this.filters, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdvantaColors.deepForest,
      child: Container(
        decoration: const BoxDecoration(color: AdvantaColors.softGrey, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              ...filters,
              _RefreshButton(onRefresh: onRefresh),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;
  const _RefreshButton({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRefresh,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AdvantaColors.dividerGrey), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]),
        child: const Icon(Icons.refresh_rounded, size: 16, color: AdvantaColors.charcoal),
      ),
    );
  }
}

// StatsRow, StatCard, PhaseProgress, FIRating, RegionalStructure persis seperti yang lama.
class _StatsRow extends StatelessWidget {
  final List<_StatCard> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: stats.map((s) => Expanded(child: Padding(padding: EdgeInsets.only(right: s == stats.last ? 0 : 8), child: s))).toList()));
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color iconColor; final Color bgColor; final String value; final String label; final bool highlight;
  const _StatCard({required this.icon, required this.iconColor, required this.bgColor, required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: highlight ? Border.all(color: iconColor.withValues(alpha: 0.4)) : null, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 28, height: 28, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: iconColor)), const SizedBox(height: 6), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: highlight ? iconColor : AdvantaColors.deepForest)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 9, color: AdvantaColors.mutedGrey, fontWeight: FontWeight.w500), maxLines: 2)]),
    );
  }
}

class _PhaseProgressSection extends StatelessWidget {
  final List<PhaseCoverage> phases;
  const _PhaseProgressSection({required this.phases});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Coverage Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
            const Spacer(),
            Text('(All Phases)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDetailSheet(context),
              child: const Text('Lihat Detail', style: TextStyle(fontSize: 11, color: AdvantaColors.deepForest, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: phases.map((p) => Expanded(child: Padding(padding: EdgeInsets.only(right: p == phases.last ? 0 : 12), child: _PhaseBar(phase: p)))).toList()),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: AdvantaColors.softGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            const Text('Statistik Cakupan per Fase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
            const SizedBox(height: 4),
            Text('Berdasarkan filter wilayah & personel aktif', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 24),

            ...phases.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 10),
                        Text(p.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
                      ]),
                      // 👇 MENAMPILKAN PERSENTASE BESAR
                      Text('${p.pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: p.color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: p.pct / 100,
                        backgroundColor: p.color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(p.color),
                        minHeight: 12
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 👇 MENAMPILKAN JUMLAH LAHAN DENGAN TEKS DESKRIPTIF
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${p.done} dari ${p.total} lahan selesai diaudit',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AdvantaColors.charcoal)),
                      if (p.total - p.done > 0)
                        Text('${p.total - p.done} Menunggak',
                            style: const TextStyle(fontSize: 11, color: AdvantaColors.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _PhaseBar extends StatelessWidget {
  final PhaseCoverage phase;
  const _PhaseBar({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label Fase (Veg, Gen, dst)
          Text(phase.shortLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AdvantaColors.charcoal)),
          const SizedBox(height: 2),

          // Persentase
          Text('${phase.pct.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: phase.color)),
          const SizedBox(height: 4),

          // Progress Bar
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: phase.pct / 100,
                  backgroundColor: phase.color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(phase.color),
                  minHeight: 6
              )
          ),
          const SizedBox(height: 3),

          // 👇 JUMLAH LAHAN (RIIL)
          Text('${phase.done}/${phase.total} Lahan',
              style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        ]
    );
  }
}

class _FIRatingPanel extends StatelessWidget {
  final List<FICoverage> fiList;
  final String title;
  final String subtitle;
  final bool showViewAll;
  final VoidCallback onViewAll;
  final bool isShowingAll;
  // 👇 1. Ubah String menjadi FICoverage
  final ValueChanged<FICoverage>? onFiTapped;

  const _FIRatingPanel({
    required this.fiList,
    required this.title,
    required this.subtitle,
    required this.showViewAll,
    required this.onViewAll,
    required this.isShowingAll,
    this.onFiTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)), const Spacer(), if (showViewAll) GestureDetector(onTap: onViewAll, child: Text(isShowingAll ? 'Ringkas' : 'Lihat Semua', style: const TextStyle(fontSize: 10, color: AdvantaColors.deepForest, fontWeight: FontWeight.w600)))]),
          const SizedBox(height: 8),
          if (fiList.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('Tidak ada data', style: TextStyle(color: Colors.grey[400], fontSize: 12))))
          else
          // 👇 2. Kirim seluruh objek `e.value` (yang berisi FICoverage)
            ...fiList.asMap().entries.map((e) => _FIRatingItem(
              rank: e.key + 1,
              fi: e.value,
              onTap: onFiTapped != null ? () => onFiTapped!(e.value) : null,
            )),
        ],
      ),
    );
  }
}

class _FIRatingItem extends StatelessWidget {
  final int rank;
  final FICoverage fi;
  final VoidCallback? onTap; // 👈 1. Tambahkan onTap

  const _FIRatingItem({required this.rank, required this.fi, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell( // 👈 2. Bungkus dengan InkWell agar ada efek klik (ripple)
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), // Sesuaikan padding
        child: Row(children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: rank <= 3 ? AdvantaColors.paleGreen : Colors.grey[100], borderRadius: BorderRadius.circular(6)), child: Center(child: Text('$rank', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: rank <= 3 ? AdvantaColors.deepForest : Colors.grey[500])))), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fi.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdvantaColors.deepForest), maxLines: 1, overflow: TextOverflow.ellipsis), if (fi.region.isNotEmpty || fi.qaSpv.isNotEmpty) Text([if (fi.region.isNotEmpty) fi.region, if (fi.qaSpv.isNotEmpty) fi.qaSpv].join(' • '), style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)])), const SizedBox(width: 4), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${fi.coverageScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fi.statusColor)), Text(fi.statusLabel, style: TextStyle(fontSize: 9, color: fi.statusColor, fontWeight: FontWeight.w600))]), const SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey[300])]),
      ),
    );
  }
}

class _FIDetailSheet extends StatelessWidget {
  final FICoverage fi;

  const _FIDetailSheet({required this.fi});

  @override
  Widget build(BuildContext context) {
    // Kelompokkan lahan berdasarkan desa
    final villageMap = <String, List<FieldCoverageStatus>>{};
    for (final f in fi.fields) {
      final key = f.village.isEmpty ? 'Unknown' : f.village;
      villageMap.putIfAbsent(key, () => []).add(f);
    }
    final villageEntries = villageMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length)); // Urutkan dari lahan terbanyak

    final avatarLetter = fi.name.isNotEmpty ? fi.name[0].toUpperCase() : '?';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(), // Menutup saat tap di luar
      child: GestureDetector(
        onTap: () {}, // Menahan tap agar tidak tertutup saat konten diklik
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AdvantaColors.softGrey,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle Bar
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                ),

                // Header Profile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: AdvantaColors.deepForest, borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(avatarLetter, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fi.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
                            const SizedBox(height: 2),
                            Text('${fi.totalFields} Lahan · ${villageEntries.length} Desa', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: fi.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text('${fi.coverageScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fi.statusColor)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Info Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildInfoCard('Area Assigned', _formatHa(fi.totalAreaHa), Icons.landscape_rounded, AdvantaColors.midGreen)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInfoCard('Overdue', fi.overdueFields.toString(), Icons.warning_amber_rounded, fi.overdueFields > 0 ? AdvantaColors.error : Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // List Desa yang ditangani
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      itemCount: villageEntries.length,
                      separatorBuilder: (_, __) => Divider(height: 24, color: Colors.grey[100]),
                      itemBuilder: (_, i) {
                        final vName = villageEntries[i].key;
                        final vFields = villageEntries[i].value;
                        final vScore = vFields.isEmpty ? 0.0 : vFields.map((f) => f.coverageScore).reduce((a, b) => a + b) / vFields.length;
                        final vColor = vScore >= 85 ? AdvantaColors.success : vScore >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error;
                        final vOverdue = vFields.where((f) => f.isOverdue).length;

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AdvantaColors.paleGreen, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.holiday_village_rounded, size: 16, color: AdvantaColors.deepForest),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdvantaColors.deepForest)),
                                  const SizedBox(height: 2),
                                  Text('${vFields.length} lahan${vOverdue > 0 ? ' · $vOverdue overdue' : ''}', style: TextStyle(fontSize: 12, color: vOverdue > 0 ? AdvantaColors.error : Colors.grey[500])),
                                ],
                              ),
                            ),
                            Text('${vScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: vColor)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdvantaColors.dividerGrey)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
            ],
          )
        ],
      ),
    );
  }
}

class _RegionalStructurePanel extends StatefulWidget {
  final Map<String, Map<String, dynamic>> regionMap;
  final int expandedIndex;
  final ValueChanged<int> onToggle;
  const _RegionalStructurePanel({required this.regionMap, required this.expandedIndex, required this.onToggle});

  @override
  State<_RegionalStructurePanel> createState() => _RegionalStructurePanelState();
}

class _RegionalStructurePanelState extends State<_RegionalStructurePanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.regionMap.entries.toList()
      ..sort((a, b) => _avgScore(b.value['fields']).compareTo(_avgScore(a.value['fields'])));
    final visible = _showAll ? entries : entries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Regional Structure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
            const Spacer(),
            if (entries.length > 5)
              GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? 'Ringkas' : 'Lihat Semua', style: const TextStyle(fontSize: 10, color: AdvantaColors.deepForest, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 8),
          ...visible.asMap().entries.map((entry) {
            final regionName = entry.value.key;
            final data = entry.value.value;
            final fields = data['fields'] as List<FieldCoverageStatus>;
            final score = _avgScore(fields);
            final area = fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
            return _RegionAccordion(
              name: regionName,
              score: score,
              area: area,
              spvCount: (data['spvSet'] as Set).length,
              fiCount: (data['fiSet'] as Set).length,
              fieldCount: fields.length,
              isExpanded: widget.expandedIndex == entry.key,
              onToggle: () => widget.onToggle(entry.key),
              fields: fields,
            );
          }),
        ],
      ),
    );
  }

  double _avgScore(List<FieldCoverageStatus> fields) =>
      fields.isEmpty ? 0 : fields.map((f) => f.coverageScore).reduce((a, b) => a + b) / fields.length;
}

class _RegionAccordion extends StatelessWidget {
  final String name; final double score; final double area; final int spvCount; final int fiCount; final int fieldCount; final bool isExpanded; final VoidCallback onToggle; final List<FieldCoverageStatus> fields;
  const _RegionAccordion({required this.name, required this.score, required this.area, required this.spvCount, required this.fiCount, required this.fieldCount, required this.isExpanded, required this.onToggle, required this.fields});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85 ? AdvantaColors.success : score >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error;
    return Column(children: [
      GestureDetector(onTap: onToggle, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdvantaColors.deepForest)), Text('$spvCount SPV · $fiCount FI · ${_formatHa(area)}', style: TextStyle(fontSize: 9, color: Colors.grey[500]))])), SizedBox(width: 50, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)), const SizedBox(height: 2), ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: score / 100, minHeight: 4, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation<Color>(color)))])), const SizedBox(width: 4), AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey[400]))]))),

      // 👇 PERUBAHAN: Meneruskan `context` ke _buildBreakdown
      if (isExpanded) ..._buildBreakdown(context),

      Divider(height: 1, color: Colors.grey[100])
    ]);
  }

  // 👇 PERUBAHAN: Menambahkan fitur klik dan Bottom Sheet Daftar Field
  List<Widget> _buildBreakdown(BuildContext context) {
    final map = <String, List<FieldCoverageStatus>>{};
    for (final f in fields) { map.putIfAbsent(f.district.isEmpty ? 'Unknown' : f.district, () => []).add(f); }

    return map.entries.map((e) {
      final s = e.value.isEmpty ? 0.0 : e.value.map((f) => f.coverageScore).reduce((a, b) => a + b) / e.value.length;
      return InkWell(
        onTap: () => _showDistrictFieldsSheet(context, e.key, e.value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(children: [
              Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.key, style: const TextStyle(fontSize: 10, color: AdvantaColors.charcoal, fontWeight: FontWeight.w700)),
                Text('${e.value.length} fields', style: TextStyle(fontSize: 8, color: Colors.grey[500]))
              ])),
              Text('${s.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: s >= 85 ? AdvantaColors.success : s >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 12, color: Colors.grey[300])
            ])
        ),
      );
    }).toList();
  }

  // Fungsi baru untuk memunculkan Bottom Sheet persis seperti QA FI View
  void _showDistrictFieldsSheet(BuildContext context, String districtName, List<FieldCoverageStatus> distFields) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.4,
            builder: (_, ctrl) => Container(
              decoration: const BoxDecoration(color: AdvantaColors.softGrey, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 16),
                        Text('Fields — $districtName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
                        const SizedBox(height: 4),
                        Text('${distFields.length} field · ${distFields.where((f) => f.isOverdue).length} overdue', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: distFields.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final f = distFields[i];
                        final score = f.coverageScore;
                        final sc = score >= 85 ? AdvantaColors.success : score >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error;

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Tutup list
                            FieldDetailBottomSheet.show(context, f.raw); // Buka detail
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: f.isOverdue ? AdvantaColors.error : sc, shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.fieldNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
                                      const SizedBox(height: 2),
                                      Text('DAP ${f.dap}${f.isOverdue ? ' · ⚠ Overdue' : ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: f.isOverdue ? AdvantaColors.error : Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: sc)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      _PhaseDot(done: f.vegetativeDone, label: 'V'),
                                      _PhaseDot(done: f.gen1Done || f.gen2Done || f.gen3Done, label: 'G'),
                                      _PhaseDot(done: f.preHarvestDone, label: 'P'),
                                      _PhaseDot(done: f.harvestDone, label: 'H'),
                                    ]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverageStructurePanel extends StatefulWidget {
  final List<MapEntry<String, List<FieldCoverageStatus>>> districts;
  final int expandedIndex;
  final ValueChanged<int> onToggle;
  const _CoverageStructurePanel({required this.districts, required this.expandedIndex, required this.onToggle});

  @override
  State<_CoverageStructurePanel> createState() => _CoverageStructurePanelState();
}

class _CoverageStructurePanelState extends State<_CoverageStructurePanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final visible = _showAll ? widget.districts : widget.districts.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Coverage Structure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
            const Spacer(),
            if (widget.districts.length > 4)
              GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? 'Ringkas' : 'Lihat Semua', style: const TextStyle(fontSize: 10, color: AdvantaColors.deepForest, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 8),
          ...visible.asMap().entries.map((entry) {
            final dFields = entry.value.value;
            final score = dFields.isEmpty ? 0.0 : dFields.map((f) => f.coverageScore).reduce((a, b) => a + b) / dFields.length;
            final color = score >= 85 ? AdvantaColors.success : score >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error;
            final isExpanded = widget.expandedIndex == entry.key;

            return Column(children: [
              GestureDetector(
                onTap: () => widget.onToggle(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(entry.value.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('${dFields.map((f) => f.qaFi).where((s) => s.isNotEmpty).toSet().length} FI · ${dFields.length} Lahan', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                    ])),
                    SizedBox(width: 55, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                      const SizedBox(height: 2),
                      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: score / 100, minHeight: 4, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation<Color>(color))),
                    ])),
                    const SizedBox(width: 4),
                    AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.grey[300])),
                  ]),
                ),
              ),
              if (isExpanded) _buildVillageBreakdown(dFields),
              Divider(height: 1, color: Colors.grey[100]),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _buildVillageBreakdown(List<FieldCoverageStatus> fields) {
    final map = <String, List<FieldCoverageStatus>>{};
    for (final f in fields) { map.putIfAbsent(f.village.isEmpty ? 'Unknown' : f.village, () => []).add(f); }
    return Column(children: map.entries.map((e) {
      final s = e.value.isEmpty ? 0.0 : e.value.map((f) => f.coverageScore).reduce((a, b) => a + b) / e.value.length;
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 4, 5),
        child: Row(children: [
          Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 9, color: AdvantaColors.charcoal))),
          Text('${e.value.length} field', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
          const SizedBox(width: 8),
          Text('${s.toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: s >= 85 ? AdvantaColors.success : s >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error)),
        ]),
      );
    }).toList());
  }
}


// ============================================================
// VILLAGE CARD & INTEGRASI KE DETAIL BOTTOM SHEET
// ============================================================

class _VillageCard extends StatelessWidget {
  final String villageName; final List<FieldCoverageStatus> fields; final bool isExpanded; final VoidCallback onTap;
  const _VillageCard({required this.villageName, required this.fields, required this.isExpanded, required this.onTap});

  void _showFieldList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // UBAH BAGIAN BUILDER INI:
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.4,
            builder: (_, ctrl) => Container(
              decoration: const BoxDecoration(color: AdvantaColors.softGrey, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 16),
                        Text('Fields — $villageName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
                        const SizedBox(height: 4),
                        Text('${fields.length} field · ${fields.where((f) => f.isOverdue).length} overdue', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: fields.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final f = fields[i];
                        final score = f.coverageScore;
                        final sc = score >= 85 ? AdvantaColors.success : score >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error;

                        return GestureDetector(
                          // KONEKSI KE FIELD DETAIL BOTTOM SHEET
                          onTap: () {
                            // Tutup list terlebih dahulu (opsional, tergantung preferensi UX)
                            Navigator.pop(context);
                            // Buka Detail
                            FieldDetailBottomSheet.show(context, f.raw);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: f.isOverdue ? AdvantaColors.error : sc, shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.fieldNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
                                      const SizedBox(height: 2),
                                      Text('DAP ${f.dap}${f.isOverdue ? ' · ⚠ Overdue' : ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: f.isOverdue ? AdvantaColors.error : Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: sc)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      _PhaseDot(done: f.vegetativeDone, label: 'V'),
                                      _PhaseDot(done: f.gen1Done || f.gen2Done || f.gen3Done, label: 'G'),
                                      _PhaseDot(done: f.preHarvestDone, label: 'P'),
                                      _PhaseDot(done: f.harvestDone, label: 'H'),
                                    ]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalArea = fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
    final overdueCount = fields.where((f) => f.isOverdue).length;
    final score = fields.isEmpty ? 0.0 : fields.map((f) => f.coverageScore).reduce((a, b) => a + b) / fields.length;
    final scoreColor = score >= 85 ? AdvantaColors.success : score >= 60 ? const Color(0xFFD4A017) : AdvantaColors.error;
    final district = fields.isNotEmpty ? fields.first.district : '';
    final subDistrict = fields.isNotEmpty ? fields.first.subDistrict : '';

    final letter = villageName.isNotEmpty ? villageName[0].toUpperCase() : '?';
    final avatarColors = [AdvantaColors.deepForest, AdvantaColors.midGreen, AdvantaColors.gold, AdvantaColors.error, AdvantaColors.lightGreen];
    final avatarColor = avatarColors[villageName.hashCode.abs() % avatarColors.length];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: isExpanded ? Border.all(color: AdvantaColors.deepForest.withValues(alpha: 0.3)) : null, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: avatarColor, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(villageName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)), Text([if (subDistrict.isNotEmpty) subDistrict, if (district.isNotEmpty) district].join(', '), style: TextStyle(fontSize: 12, color: Colors.grey[500]))])),
                  Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scoreColor)),
                  const SizedBox(width: 6),
                  AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400])),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _MicroStat(label: _formatHa(totalArea), icon: Icons.landscape_rounded, color: AdvantaColors.mutedGrey), const SizedBox(width: 12),
                _MicroStat(label: '${fields.length} Lahan', icon: Icons.grid_view_rounded, color: AdvantaColors.lightGreen), const SizedBox(width: 12),
                _MicroStat(label: 'Overdue $overdueCount', icon: Icons.warning_amber_rounded, color: overdueCount > 0 ? AdvantaColors.error : Colors.grey),
                const Spacer(),
                GestureDetector(onTap: () => _showFieldList(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AdvantaColors.paleGreen, borderRadius: BorderRadius.circular(10)), child: const Text('View Fields', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)))),
              ],
            ),
          ),
          if (isExpanded) ...[Divider(height: 1, color: Colors.grey[100]), ...fields.map((f) => _FieldMiniRow(field: f, onTap: () => FieldDetailBottomSheet.show(context, f.raw))), const SizedBox(height: 6)],
        ],
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  const _MicroStat({required this.label, required this.icon, required this.color});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))]);
}

class _FieldMiniRow extends StatelessWidget {
  final FieldCoverageStatus field;
  final VoidCallback onTap;
  const _FieldMiniRow({required this.field, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: field.isOverdue ? AdvantaColors.error : field.coverageScore > 0 ? AdvantaColors.success : Colors.grey[300], shape: BoxShape.circle)), const SizedBox(width: 10),
            Expanded(child: Text(field.fieldNumber, style: const TextStyle(fontSize: 12, color: AdvantaColors.charcoal, fontWeight: FontWeight.w600))),
            Row(children: [_PhaseDot(done: field.vegetativeDone, label: 'V'), _PhaseDot(done: field.gen1Done || field.gen2Done || field.gen3Done, label: 'G'), _PhaseDot(done: field.preHarvestDone, label: 'P'), _PhaseDot(done: field.harvestDone, label: 'H')]),
            const SizedBox(width: 10),
            Text('DAP ${field.dap}', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey[300])
          ],
        ),
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  final bool done; final String label;
  const _PhaseDot({required this.done, required this.label});
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(right: 3), width: 18, height: 18, decoration: BoxDecoration(color: done ? AdvantaColors.success : Colors.grey[200], borderRadius: BorderRadius.circular(6)), child: Center(child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: done ? Colors.white : Colors.grey[400]))));
}

// ============================================================
// WIDGET SMART ROUTE PLANNER
// ============================================================

class _OpenRouteButton extends StatelessWidget {
  final List<FieldCoverageStatus> fields;
  const _OpenRouteButton({required this.fields});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 1. Ubah onTap untuk menampilkan Smart Route Sheet
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _SmartRouteSheet(fields: fields),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AdvantaColors.deepForest, AdvantaColors.midGreen],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AdvantaColors.deepForest.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Rekomendasi Rute (Smart Route)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartRouteSheet extends StatefulWidget {
  final List<FieldCoverageStatus> fields;
  const _SmartRouteSheet({required this.fields});

  @override
  State<_SmartRouteSheet> createState() => _SmartRouteSheetState();
}

class _SmartRouteSheetState extends State<_SmartRouteSheet> {
  Position? _currentPosition;
  bool _isLoadingGps = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  /// Fungsi untuk mendapatkan lokasi GPS saat ini
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingGps = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingGps = false);
        return;
      }
    }

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingGps = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. FILTER: Hanya lahan belum selesai & punya koordinat untuk rute
    final pendingFields = widget.fields.where((f) {
      final coordStr = f.raw['correction_tagging']?.toString() ?? f.raw['coordinate']?.toString() ?? '';
      return f.coverageScore < 100 && coordStr.contains(',');
    }).toList();

    // 2. HITUNG JARAK & SORTING
    if (_currentPosition != null) {
      pendingFields.sort((a, b) {
        // Prioritas 1: Overdue tetap di atas
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;

        // Prioritas 2: Jarak terdekat dari GPS
        double distA = _getDistance(a);
        double distB = _getDistance(b);
        return distA.compareTo(distB);
      });
    }

    final recommendedRoute = pendingFields.take(8).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: GestureDetector(
        onTap: () {},
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AdvantaColors.softGrey,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _buildHandleBar(),
                _buildHeader(recommendedRoute),

                if (_isLoadingGps)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (recommendedRoute.isEmpty)
                  _buildEmptyState()
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      itemCount: recommendedRoute.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildRouteCard(recommendedRoute[i], i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getDistance(FieldCoverageStatus f) {
    if (_currentPosition == null) return 0.0;
    final coordStr = f.raw['correction_tagging']?.toString() ?? f.raw['coordinate']?.toString() ?? '';
    final parts = coordStr.split(',');
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      double.parse(parts[0]),
      double.parse(parts[1]),
    );
  }

  Widget _buildRouteCard(FieldCoverageStatus f, int index) {
    double distanceInMeters = _getDistance(f);
    String distanceLabel = distanceInMeters >= 1000
        ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km'
        : '${distanceInMeters.toInt()} m';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: f.isOverdue ? AdvantaColors.error.withValues(alpha: 0.2) : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AdvantaColors.deepForest, shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.fieldNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${f.village} · DAP ${f.dap}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(distanceLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
              if (f.isOverdue)
                const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AdvantaColors.error)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // WIDGET PENDUKUNG SMART ROUTE SHEET
  // ==========================================================

  Widget _buildHandleBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Center(
        child: Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildHeader(List<FieldCoverageStatus> recommendedRoute) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AdvantaColors.paleGreen, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.assistant_direction_rounded, color: AdvantaColors.deepForest),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rekomendasi Rute Harian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
                    SizedBox(height: 2),
                    Text('Prioritas: Overdue & Jarak Terdekat', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tombol Buka Maps Multi-stop (Memanggil _openMultiStopMaps)
          if (recommendedRoute.isNotEmpty && !_isLoadingGps)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openMultiStopMaps(context, recommendedRoute),
                icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                label: Text('Mulai Perjalanan (${recommendedRoute.length} Titik)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdvantaColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AdvantaColors.success, size: 56),
            SizedBox(height: 16),
            Text('Luar biasa!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
            SizedBox(height: 8),
            Text(
                'Semua lahan prioritas sudah diaudit atau tidak ada lahan tertunda yang memiliki koordinat GPS valid.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)
            ),
          ],
        ),
      ),
    );
  }

  // LOGIKA MULTI-STOP GOOGLE MAPS
  Future<void> _openMultiStopMaps(BuildContext context, List<FieldCoverageStatus> routeFields) async {
    final coords = <String>[];

    // Kumpulkan koordinat yang valid
    for (final f in routeFields) {
      final coordStr = f.raw['correction_tagging']?.toString() ?? f.raw['coordinate']?.toString() ?? '';
      if (coordStr.contains(',')) {
        final parts = coordStr.split(',');
        final lat = parts[0].trim();
        final lng = parts[1].trim();
        if (lat.isNotEmpty && lng.isNotEmpty) {
          coords.add('$lat,$lng');
        }
      }
    }

    if (coords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada koordinat valid pada rute ini.')));
      return;
    }

    // Google Maps Multi-stop URL format:
    // https://www.google.com/maps/dir/?api=1&destination={titik_akhir}&waypoints={titik1}|{titik2}|{titik3}
    final destination = coords.last;
    final waypoints = coords.length > 1 ? coords.sublist(0, coords.length - 1).join('|') : '';

    var url = 'https://www.google.com/maps/dir/?api=1&destination=$destination';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=$waypoints';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka Google Maps.')));
      }
    }
  }
}

class _CoverageErrorWidget extends StatelessWidget {
  final String error; const _CoverageErrorWidget({required this.error});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline_rounded, size: 56, color: AdvantaColors.error), const SizedBox(height: 16), const Text('Gagal memuat data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(error, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)]))));
}

class _SkeletonLoader extends StatefulWidget { const _SkeletonLoader(); @override State<_SkeletonLoader> createState() => _SkeletonLoaderState(); }
class _SkeletonLoaderState extends State<_SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(); _anim = Tween<double>(begin: -1.5, end: 2.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _anim, builder: (_, __) => CustomScrollView(slivers: [SliverToBoxAdapter(child: _shimmerBox(height: 80)), SliverToBoxAdapter(child: _shimmerBox(height: 48)), SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: List.generate(4, (_) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _shimmerBox(height: 80))))))), SliverToBoxAdapter(child: _shimmerBox(height: 120)), SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _shimmerBox(height: 280)), const SizedBox(width: 12), Expanded(child: _shimmerBox(height: 280))])))]));
  Widget _shimmerBox({required double height}) => Container(height: height, margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, stops: [math.max(0.0, _anim.value - 0.3), _anim.value.clamp(0.0, 1.0), math.min(1.0, _anim.value + 0.3)], colors: [AdvantaColors.paleGreen, AdvantaColors.softGrey, AdvantaColors.paleGreen])));
}

String _formatHa(double ha) {
  if (ha >= 1000) return '${(ha / 1000).toStringAsFixed(2)} K ha';
  if (ha == ha.truncateToDouble()) return '${ha.toInt()} ha';
  return '${ha.toStringAsFixed(1)} ha';
}