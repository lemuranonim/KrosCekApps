// lib/screens/coverage/coverage_screen.dart
//
// COVERAGE MONITORING SCREEN
// ──────────────────────────────────────────────────────────
// Tampilan coverage adaptif berdasarkan role:
//   • Manager  → Bird's-eye: FI Rating (global) + Regional Structure
//   • QA SPV   → Supervisory: FI Tim Rating + Coverage Structure area tim
//   • QA FI    → Operational: Village Coverage List + Route Planning
//
// Data source: masterFieldCoverageScopedProvider (kolom coverage ringkas)
// ──────────────────────────────────────────────────────────

// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/master_fields_provider.dart';
import '../../providers/audit_filter_provider.dart';
import '../../services/session_manager.dart';
import 'package:go_router/go_router.dart';
import '../../utils/weekly_audit.dart';
import '../../utils/qa_name_helper.dart';
import '../../widgets/weekly_audit_widgets.dart';
import '../../utils/dap_helper.dart';

// PENTING: Sesuaikan path import ini dengan struktur project-mu
import '../../widgets/field_detail_bottom_sheet.dart';
import '../../widgets/advanta_loading_state.dart';
import '../../theme/app_theme.dart';

// ============================================================
// SECTION A — DATA MODELS
// ============================================================

String _cleanText(dynamic val) => val?.toString().trim() ?? '';

bool _isExcludedCoverageRegion(String? region) =>
    region?.trim().toLowerCase() == 'region tester';

List<FieldCoverageStatus> _projectCoverageWeeks(
  List<FieldCoverageStatus> fields, {
  required Set<DateTime> weeks,
  required Set<String> flags,
}) {
  final selected = weeks.isEmpty ? {auditWeekStart(DateTime.now())} : weeks;
  return [
    for (final week in selected)
      ...fields
          .where((field) => !_isExcludedCoverageRegion(field.region))
          .map((field) => FieldCoverageStatus.fromRaw(field.raw,
              weekStart: auditWeekStart(week)))
          .where((field) => flags.contains(field.weekly.flag)),
  ];
}

List<FieldCoverageStatus> _filterAllCoverage(
        List<FieldCoverageStatus> fields, Set<String> flags) =>
    fields
        .where((field) =>
            !_isExcludedCoverageRegion(field.region) &&
            flags.contains(field.weekly.flag))
        .toList(growable: false);

double _coverageArea(Iterable<FieldCoverageStatus> fields) =>
    fields.fold(0.0, (sum, field) => sum + field.effectiveAreaHa);

/// Status coverage untuk satu field, dihitung dari data audit.
class FieldCoverageStatus {
  final WeeklyAuditField weekly;
  final Map<String, dynamic> raw; // DISIMPAN UNTUK MENGIRIM KE DETAIL SHEET
  final String fieldNumber;
  final String qaFi;
  final String qaSpv;
  final String farmerName;
  final String hybrid;
  final String region;
  final String district;
  final String village;
  final String subDistrict;
  final double registeredAreaHa;
  final double auditAreaHa;
  final double effectiveAreaHa;
  final int dap;
  final bool isSweetCorn;
  final bool isPsp;

  final bool vegetativeDone;
  final int vegetativeAuditDoneCount;
  final int vegetativeAuditTotalCount;
  final bool gen1Done;
  final bool gen2Done;
  final bool gen3Done;
  final bool gen4Done;
  final bool gen5Done;
  final bool preHarvestDone;
  final bool harvestDone;

  final String activePhaseKey;
  final String activePhaseLabel;
  final String activePhaseBadge;
  final String? latestAuditDate;
  final String? latestAuditWeek;
  final String? latestAuditor;
  final String? actionCode;
  final String? actionPhase;
  final bool hasCorrectionTagging;
  final bool hasPldDiscardValue;

  /// Apakah ada fase yang seharusnya On Going / Overdue tapi belum diaudit.
  final bool isOverdue;

  const FieldCoverageStatus({
    required this.weekly,
    required this.raw,
    required this.fieldNumber,
    required this.qaFi,
    required this.qaSpv,
    required this.farmerName,
    required this.hybrid,
    required this.region,
    required this.district,
    required this.village,
    required this.subDistrict,
    required this.registeredAreaHa,
    required this.auditAreaHa,
    required this.effectiveAreaHa,
    required this.dap,
    required this.isSweetCorn,
    required this.isPsp,
    required this.vegetativeDone,
    required this.vegetativeAuditDoneCount,
    required this.vegetativeAuditTotalCount,
    required this.gen1Done,
    required this.gen2Done,
    required this.gen3Done,
    required this.gen4Done,
    required this.gen5Done,
    required this.preHarvestDone,
    required this.harvestDone,
    required this.activePhaseKey,
    required this.activePhaseLabel,
    required this.activePhaseBadge,
    required this.latestAuditDate,
    required this.latestAuditWeek,
    required this.latestAuditor,
    required this.actionCode,
    required this.actionPhase,
    required this.hasCorrectionTagging,
    required this.hasPldDiscardValue,
    required this.isOverdue,
  });

  List<String> get phaseKeys => DapHelper.getPhaseRules(
          hybrid: hybrid,
          district: district,
          region: region,
          subDistrict: subDistrict)
      .map((r) => r.key)
      .toList();

  List<String> get duePhaseKeys => weekly.targets.map((t) => t.phase).toList();
  List<String> get overduePhaseKeys =>
      weekly.targets.where((t) => t.overdue).map((t) => t.phase).toList();

  bool get isAuditTarget => duePhaseKeys.isNotEmpty;

  bool get hasActionRequired => actionCode != null;

  bool get needsAttention => isOverdue || hasActionRequired;

  bool get hasAuditAreaOverride =>
      auditAreaHa > 0 && (auditAreaHa - registeredAreaHa).abs() > 0.001;

  String get areaSourceLabel => auditAreaHa > 0 ? 'Audit area' : 'Master area';

  bool get anyGenerativeDone =>
      gen1Done || gen2Done || gen3Done || gen4Done || gen5Done;

  int get generativeDoneCount => [
        gen1Done,
        gen2Done,
        gen3Done,
        if (isSweetCorn) gen4Done,
        if (isSweetCorn) gen5Done
      ].where((done) => done).length;

  int get generativeTotalCount => isSweetCorn ? 5 : 3;

  int get targetPhaseCount => duePhaseKeys.length;

  int get completedTargetPhaseCount =>
      duePhaseKeys.where(_isPhaseComplete).length;

  double get completedTargetPhaseWeight => duePhaseKeys.fold(
      0.0, (sum, phase) => sum + _phaseCompletionWeight(phase));

  int get overdueTargetCount => overduePhaseKeys.length;

  /// Jumlah fase yang sudah selesai dari seluruh rule audit field.
  int get donePhasesCount {
    int count = 0;
    for (final phase in phaseKeys) {
      if (_isPhaseComplete(phase)) count++;
    }
    return count;
  }

  bool get allRequiredPhasesDone =>
      phaseKeys.isNotEmpty && donePhasesCount == phaseKeys.length;

  /// Coverage score 0-100 berdasarkan fase yang sudah On Going / Overdue.
  double get coverageScore {
    if (targetPhaseCount == 0) return 0.0;
    return (completedTargetPhaseWeight / targetPhaseCount) * 100;
  }

  double get vegetativeCompletionFraction {
    if (!isPsp) return vegetativeDone ? 1.0 : 0.0;
    if (vegetativeAuditTotalCount <= 0) return 0.0;
    return (vegetativeAuditDoneCount / vegetativeAuditTotalCount)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _phaseCompletionWeight(String phase) {
    return weekly.phaseCompletions[phase] ?? 0.0;
  }

  bool _isPhaseComplete(String phase) {
    switch (phase) {
      case 'vegetative':
        return vegetativeDone;
      case 'generative_1':
        return gen1Done;
      case 'generative_2':
        return gen2Done;
      case 'generative_3':
        return gen3Done;
      case 'generative_4':
        return gen4Done;
      case 'generative_5':
        return gen5Done;
      case 'pre_harvest':
        return preHarvestDone;
      case 'harvest':
        return harvestDone;
      default:
        return false;
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
      case 'On Track':
        return AdvantaColors.success;
      case 'At Risk':
        return const Color(0xFFD4A017);
      default:
        return AdvantaColors.error;
    }
  }

  factory FieldCoverageStatus.fromRaw(Map<String, dynamic> raw,
      {DateTime? weekStart, DateTime? now}) {
    final weekly = WeeklyAuditField.fromRaw(raw,
        weekStart: weekStart ?? auditWeekStart(now ?? DateTime.now()),
        now: now);
    final veg = auditRow(raw['audit_vegetative']);
    final hybrid = _cleanText(raw['hybrid']);
    final psp = DapHelper.isPsp(hybrid);
    bool complete(String phase) => (weekly.phaseCompletions[phase] ?? 0) >= 1;
    final activePhase = DapHelper.getRecommendedPhase(weekly.dap,
        hybrid: hybrid,
        district: raw['district_kab']?.toString(),
        region: raw['region']?.toString(),
        subDistrict: raw['sub_district_kec']?.toString());
    final last = weekly.observations.isEmpty ? null : weekly.observations.last;
    final actions = <String>[
      if (weekly.roguingNegative) 'Roguing',
      if (weekly.lsvNegative) 'LSV',
      if (weekly.isolationNegative) 'Isolasi',
      if (const {'RFI', 'RFD', 'BF', 'OF', 'RF', 'PLD'}.contains(weekly.flag))
        weekly.flag,
    ];
    return FieldCoverageStatus(
      weekly: weekly,
      raw: raw,
      fieldNumber: _cleanText(raw['field_number']),
      qaFi: _cleanText(raw['qa_fi']),
      qaSpv: _cleanText(raw['qa_spv']),
      farmerName: _cleanText(raw['farmer_name']),
      hybrid: hybrid,
      region: _cleanText(raw['region']),
      district: _cleanText(raw['district_kab']),
      village: _cleanText(raw['village_desa']),
      subDistrict: _cleanText(raw['sub_district_kec']),
      registeredAreaHa: weekly.areaHa,
      auditAreaHa: auditArea(veg['field_size_by_audit_ha']),
      effectiveAreaHa: weekly.areaHa,
      dap: weekly.dap,
      isSweetCorn: DapHelper.isSweetCorn(hybrid),
      isPsp: psp,
      vegetativeDone: complete('vegetative'),
      vegetativeAuditDoneCount:
          ((weekly.phaseCompletions['vegetative'] ?? 0) * (psp ? 4 : 1))
              .round(),
      vegetativeAuditTotalCount: psp ? 4 : 1,
      gen1Done: complete('generative_1'),
      gen2Done: complete('generative_2'),
      gen3Done: complete('generative_3'),
      gen4Done: complete('generative_4'),
      gen5Done: complete('generative_5'),
      preHarvestDone: complete('pre_harvest'),
      harvestDone: complete('harvest'),
      activePhaseKey: activePhase,
      activePhaseLabel: auditStageLabels[weekly.stage]!,
      activePhaseBadge: DapHelper.getDapBadgeLabel(weekly.dap, activePhase,
          hybrid: hybrid,
          district: raw['district_kab']?.toString(),
          region: raw['region']?.toString(),
          subDistrict: raw['sub_district_kec']?.toString(),
          isDone: complete(activePhase)),
      latestAuditDate:
          last == null ? null : DateFormat('yyyy-MM-dd').format(last.date),
      latestAuditWeek: null,
      latestAuditor: _cleanText(raw['qa_fi']),
      actionCode: actions.isEmpty ? null : actions.join(', '),
      actionPhase:
          last == null ? null : auditStageLabels[auditStage(last.phase)],
      hasCorrectionTagging:
          _cleanText(veg['correction_tagging'] ?? raw['correction_tagging'])
              .isNotEmpty,
      hasPldDiscardValue: weekly.flag == 'PLD',
      isOverdue: weekly.overdue,
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
  final int targetFields;
  final int completedTargets;
  final int totalTargets;
  final double coverageScore;
  final int overdueFields;
  final int actionFields;
  final List<FieldCoverageStatus> fields;

  const FICoverage({
    required this.name,
    required this.region,
    required this.qaSpv,
    required this.totalAreaHa,
    required this.totalFields,
    required this.targetFields,
    required this.completedTargets,
    required this.totalTargets,
    required this.coverageScore,
    required this.overdueFields,
    required this.actionFields,
    required this.fields,
  });

  String get statusLabel {
    if (coverageScore >= 85) return 'On Track';
    if (coverageScore >= 50) return 'At Risk';
    return 'Behind';
  }

  Color get statusColor {
    switch (statusLabel) {
      case 'On Track':
        return AdvantaColors.success;
      case 'At Risk':
        return const Color(0xFFD4A017);
      default:
        return AdvantaColors.error;
    }
  }

  static FICoverage fromFields(String name, List<FieldCoverageStatus> fields) {
    final totalArea = fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
    final totalTargets = fields.where((field) => field.isAuditTarget).length;
    final completedTargets = fields.where((field) => field.weekly.done).length;
    final avgScore =
        WeeklyAuditSummary(fields.map((f) => f.weekly)).achievementPercent;
    final overdue = fields.where((f) => f.isOverdue).length;
    final action = fields.where((f) => f.hasActionRequired).length;
    return FICoverage(
      name: name,
      region: fields.isNotEmpty ? fields.first.region : '',
      qaSpv: fields.isNotEmpty ? fields.first.qaSpv : '',
      totalAreaHa: totalArea,
      totalFields: fields.length,
      targetFields: fields.where((f) => f.isAuditTarget).length,
      completedTargets: completedTargets,
      totalTargets: totalTargets,
      coverageScore: avgScore,
      overdueFields: overdue,
      actionFields: action,
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
  final int overdue;
  final double totalHa;
  final double doneHa;
  final double overdueHa;
  double get pct => total == 0 ? 0 : (done / total) * 100;

  const PhaseCoverage({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.total,
    required this.done,
    required this.overdue,
    required this.totalHa,
    required this.doneHa,
    required this.overdueHa,
  });
}

class PhaseSummary {
  final double targetAreaHa;
  final double achievedAreaHa;
  final double overdueAreaHa;
  final List<PhaseCoverage> phases;
  final int totalFields;
  final int targetFields;
  final int upcomingFields;
  final int completedTargets;
  final int totalTargets;
  final int overdueTargets;
  final int actionFields;
  final int correctedFields;
  final int auditAreaOverrides;
  final double registeredAreaHa;
  final double effectiveAreaHa;

  const PhaseSummary({
    required this.targetAreaHa,
    required this.achievedAreaHa,
    required this.overdueAreaHa,
    required this.phases,
    required this.totalFields,
    required this.targetFields,
    required this.upcomingFields,
    required this.completedTargets,
    required this.totalTargets,
    required this.overdueTargets,
    required this.actionFields,
    required this.correctedFields,
    required this.auditAreaOverrides,
    required this.registeredAreaHa,
    required this.effectiveAreaHa,
  });

  double get targetCompletionPct =>
      totalTargets == 0 ? 0 : completedTargets / totalTargets * 100;
}

// ============================================================
// FUNGSI HELPER UNTUK MENGHITUNG FASE DINAMIS (TERFILTER)
// ============================================================
PhaseSummary calculateFilteredPhases(List<FieldCoverageStatus> filteredFields) {
  final fields = filteredFields.where((f) => f.isAuditTarget).toList();
  final weekly = WeeklyAuditSummary(fields.map((f) => f.weekly));
  final colors = [
    AdvantaColors.lightGreen,
    AdvantaColors.gold,
    AdvantaColors.midGreen,
    AdvantaColors.error
  ];
  final phases = <PhaseCoverage>[];
  var index = 0;
  for (final entry in auditStageLabels.entries) {
    final phaseFields = fields
        .where((f) =>
            f.weekly.targets.any((t) => auditStage(t.phase) == entry.key))
        .toList();
    bool done(FieldCoverageStatus f) => f.weekly.targets
        .where((t) => auditStage(t.phase) == entry.key)
        .every((t) => t.done);
    bool overdue(FieldCoverageStatus f) => f.weekly.targets
        .any((t) => auditStage(t.phase) == entry.key && t.overdue);
    phases.add(PhaseCoverage(
        label: entry.value,
        shortLabel: entry.value,
        color: colors[index++],
        total: phaseFields.length,
        done: phaseFields.where(done).length,
        overdue: phaseFields.where(overdue).length,
        totalHa: phaseFields.fold(0.0, (sum, f) => sum + f.effectiveAreaHa),
        doneHa: phaseFields
            .where(done)
            .fold(0.0, (sum, f) => sum + f.effectiveAreaHa),
        overdueHa: phaseFields
            .where(overdue)
            .fold(0.0, (sum, f) => sum + f.effectiveAreaHa)));
  }
  return PhaseSummary(
      phases: phases,
      totalFields: fields.length,
      targetFields: fields.length,
      upcomingFields: 0,
      completedTargets: fields.where((field) => field.weekly.done).length,
      totalTargets: fields.length,
      overdueTargets: fields.where((field) => field.weekly.overdue).length,
      actionFields: fields.where((f) => f.hasActionRequired).length,
      correctedFields: fields.where((f) => f.hasCorrectionTagging).length,
      auditAreaOverrides: fields.where((f) => f.hasAuditAreaOverride).length,
      registeredAreaHa: weekly.targetHa,
      effectiveAreaHa: weekly.targetHa,
      targetAreaHa: weekly.targetHa,
      achievedAreaHa: weekly.achievedHa,
      overdueAreaHa: weekly.overdueHa);
}

final coverageStatusListProvider =
    FutureProvider<List<FieldCoverageStatus>>((ref) async {
  return ref.watch(
    coverageStatusListScopedProvider(const MasterFieldMapScope.all()).future,
  );
});

final coverageStatusListScopedProvider =
    FutureProvider.family<List<FieldCoverageStatus>, MasterFieldMapScope>(
        (ref, scope) async {
  final rawFields =
      await ref.watch(masterFieldCoverageScopedProvider(scope).future);

  final parsed =
      rawFields.map((raw) => FieldCoverageStatus.fromRaw(raw)).toList();

  return parsed;
});

final phaseSummaryProvider = FutureProvider<PhaseSummary>((ref) async {
  final fields = await ref.watch(coverageStatusListProvider.future);
  return calculateFilteredPhases(fields);
});

List<FICoverage> buildFiCoverageList(List<FieldCoverageStatus> fields) {
  final grouped = <String, List<FieldCoverageStatus>>{};
  for (final f in fields) {
    final owner = f.qaFi.isEmpty ? 'Unmapped / Need Mapping' : f.qaFi;
    grouped.putIfAbsent(owner, () => []).add(f);
  }
  final list = grouped.entries
      .map((e) => FICoverage.fromFields(e.key, e.value))
      .toList();
  list.sort((a, b) => b.coverageScore.compareTo(a.coverageScore));
  return list;
}

double aggregateCoverageScore(List<FieldCoverageStatus> fields) {
  if (fields.any((field) => field.isAuditTarget)) {
    return WeeklyAuditSummary(fields.map((field) => field.weekly))
        .achievementPercent;
  }
  if (fields.isEmpty) return 0;
  return fields.where((field) => field.allRequiredPhasesDone).length /
      fields.length *
      100;
}

final fiCoverageListProvider = FutureProvider<List<FICoverage>>((ref) async {
  final fields = await ref.watch(coverageStatusListProvider.future);
  return buildFiCoverageList(fields);
});

Future<void> _refreshCoverage(
  WidgetRef ref, [
  MasterFieldMapScope scope = const MasterFieldMapScope.all(),
]) async {
  ref.invalidate(masterFieldCoverageScopedProvider(scope));
  ref.invalidate(coverageStatusListScopedProvider(scope));
  ref.invalidate(coverageStatusListProvider);
  ref.invalidate(phaseSummaryProvider);
  ref.invalidate(fiCoverageListProvider);
  await ref.read(coverageStatusListScopedProvider(scope).future);
  ref.read(auditDashboardFilterProvider.notifier).markUpdated();
}

// ============================================================
// SECTION C — COVERAGE SCREEN (Root)
// ============================================================

class CoverageScreen extends ConsumerStatefulWidget {
  const CoverageScreen({super.key});

  @override
  ConsumerState<CoverageScreen> createState() => _CoverageScreenState();
}

enum _CoverageViewRole { manager, spv, fi }

extension _CoverageViewRoleX on _CoverageViewRole {
  String get label {
    switch (this) {
      case _CoverageViewRole.manager:
        return 'Manager';
      case _CoverageViewRole.spv:
        return 'QA SPV';
      case _CoverageViewRole.fi:
        return 'QA FI';
    }
  }

  IconData get icon {
    switch (this) {
      case _CoverageViewRole.manager:
        return Icons.business_center_rounded;
      case _CoverageViewRole.spv:
        return Icons.supervisor_account_rounded;
      case _CoverageViewRole.fi:
        return Icons.person_search_rounded;
    }
  }
}

class _CoverageScreenState extends ConsumerState<CoverageScreen>
    with SingleTickerProviderStateMixin {
  ActiveSession? _session;
  bool _sessionLoaded = false;
  _CoverageViewRole _devPreviewRole = _CoverageViewRole.manager;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
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
      setState(() {
        _session = s;
        _sessionLoaded = true;
      });
      _fadeCtrl.forward();
    }
  }

  String get _role => _session?.role.toUpperCase() ?? 'FI';

  bool get _isDev => _role == 'DEV';

  // Dev & Manager masuk ke Manager View
  bool get _isManager => _role == 'MANAGER' || _role == 'DEV';

  // SPV murni menggunakan role SPV
  bool get _isSpv => _role == 'SPV';

  @override
  Widget build(BuildContext context) {
    if (!_sessionLoaded) {
      return const _SkeletonLoader(
        title: 'Membuka Coverage',
        subtitle: 'Membaca sesi dan hak akses pengguna',
        icon: Icons.verified_user_rounded,
      );
    }
    return Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _buildRoleView(),
      ),
    );
  }

  Widget _buildRoleView() {
    if (_isDev) {
      switch (_devPreviewRole) {
        case _CoverageViewRole.manager:
          return _ManagerView(
            session: _session!,
            isDevPreview: true,
            previewRole: _devPreviewRole,
            onPreviewRoleChanged: _setDevPreviewRole,
          );
        case _CoverageViewRole.spv:
          return _SPVView(
            session: _session!,
            isDevPreview: true,
            previewRole: _devPreviewRole,
            onPreviewRoleChanged: _setDevPreviewRole,
          );
        case _CoverageViewRole.fi:
          return _FIView(
            session: _session!,
            isDevPreview: true,
            previewRole: _devPreviewRole,
            onPreviewRoleChanged: _setDevPreviewRole,
          );
      }
    }

    if (_isManager) return _ManagerView(session: _session!);
    if (_isSpv) return _SPVView(session: _session!);
    return _FIView(session: _session!);
  }

  void _setDevPreviewRole(_CoverageViewRole role) {
    setState(() => _devPreviewRole = role);
  }
}

// ============================================================
// SECTION D — MANAGER VIEW
// ============================================================

class _ManagerView extends ConsumerStatefulWidget {
  final ActiveSession session;
  final bool isDevPreview;
  final _CoverageViewRole? previewRole;
  final ValueChanged<_CoverageViewRole>? onPreviewRoleChanged;

  const _ManagerView({
    required this.session,
    this.isDevPreview = false,
    this.previewRole,
    this.onPreviewRoleChanged,
  });

  @override
  ConsumerState<_ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends ConsumerState<_ManagerView> {
  String? _selectedRegion;
  bool _showAllRegions = false;
  String? _selectedDistrict; // cascade dari region
  String? _selectedSpv;
  int _expandedAreaIndex = -1;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(auditDashboardFilterProvider);
    _selectedRegion = filters.region;
    _selectedDistrict = filters.district;
    _showAllRegions = filters.region == null;
  }

  @override
  Widget build(BuildContext context) {
    final sharedFilters = ref.watch(auditDashboardFilterProvider);
    final regionOptionsAsync = ref.watch(
      activeMasterFieldRegionsProvider(const MasterFieldMapScope.all()),
    );
    final regionOptions = (regionOptionsAsync.value ?? const <String>[])
        .where((region) => !_isExcludedCoverageRegion(region))
        .toList(growable: false);
    final needsRegionScope =
        !_showAllRegions && _selectedRegion == null && regionOptions.isNotEmpty;

    if (!_showAllRegions && _isExcludedCoverageRegion(_selectedRegion)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _showAllRegions ||
            !_isExcludedCoverageRegion(_selectedRegion)) {
          return;
        }
        setState(() {
          _selectedRegion = null;
          _selectedDistrict = null;
          _selectedSpv = null;
        });
      });
    }
    if (!_showAllRegions &&
        _selectedRegion != null &&
        regionOptions.isNotEmpty &&
        !regionOptions.contains(_selectedRegion)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _showAllRegions ||
            _selectedRegion == null ||
            regionOptions.contains(_selectedRegion)) {
          return;
        }
        setState(() {
          _selectedRegion = null;
          _selectedDistrict = null;
          _selectedSpv = null;
        });
      });
    }
    if (needsRegionScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showAllRegions || _selectedRegion != null) return;
        setState(() {
          _selectedRegion = regionOptions.first;
          _selectedDistrict = null;
          _selectedSpv = null;
        });
      });
    }

    final coverageScope = MasterFieldMapScope(
      region: _showAllRegions ? null : _selectedRegion,
    );
    final waitingForRegionScope =
        regionOptionsAsync is AsyncLoading || needsRegionScope;
    final AsyncValue<List<FieldCoverageStatus>> fieldsAsync =
        waitingForRegionScope
            ? const AsyncValue.loading()
            : ref.watch(coverageStatusListScopedProvider(coverageScope));

    return fieldsAsync.when(
      loading: () => const _SkeletonLoader(),
      error: (e, _) => _CoverageErrorWidget(error: e.toString()),
      data: (allFields) {
        final allCoverageFields =
            _filterAllCoverage(allFields, sharedFilters.flags);
        final weeklyFields = _projectCoverageWeeks(allFields,
            weeks: sharedFilters.weeks, flags: sharedFilters.flags);

        // CASCADING LOGIC — Region → District → SPV
        final regions = regionOptions.isNotEmpty
            ? regionOptions
            : (allCoverageFields
                .map((f) => f.region)
                .where((r) => r.isNotEmpty)
                .toSet()
                .toList()
              ..sort());
        final districtOptions = allCoverageFields
            .where(
                (f) => _selectedRegion == null || f.region == _selectedRegion)
            .map((f) => f.district)
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final spvOptions = allCoverageFields
            .where((f) {
              if (_selectedRegion != null && f.region != _selectedRegion) {
                return false;
              }
              if (_selectedDistrict != null &&
                  f.district != _selectedDistrict) {
                return false;
              }
              return true;
            })
            .map((f) => f.qaSpv)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        bool matchesScope(FieldCoverageStatus f) {
          if (_selectedRegion != null && f.region != _selectedRegion) {
            return false;
          }
          if (_selectedDistrict != null && f.district != _selectedDistrict) {
            return false;
          }
          if (_selectedSpv != null && f.qaSpv != _selectedSpv) return false;
          return true;
        }

        final coverageFields =
            allCoverageFields.where(matchesScope).toList(growable: false);
        final targetFields = weeklyFields
            .where(matchesScope)
            .where((field) => field.isAuditTarget)
            .toList(growable: false);
        final dashboardFields =
            sharedFilters.coverageMode == CoverageDisplayMode.allCoverage
                ? coverageFields
                : targetFields;

        final filteredFIList = buildFiCoverageList(targetFields);

        final summary = calculateFilteredPhases(
          targetFields,
        );
        final regionMap = _buildRegionMap(dashboardFields);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _CoverageHeader(
                    title: 'Coverage Monitoring', session: widget.session)),
            if (widget.isDevPreview)
              SliverToBoxAdapter(
                child: _DevRolePreviewBar(
                  selected: widget.previewRole ?? _CoverageViewRole.manager,
                  onSelected: widget.onPreviewRoleChanged ?? (_) {},
                ),
              ),
            SliverToBoxAdapter(child: const _WeeklyCoverageControls()),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: [
                  PremiumFilterChip(
                    label: _showAllRegions
                        ? 'All Region'
                        : _selectedRegion ?? 'Region',
                    options: ['All Region', ...regions],
                    selected: _showAllRegions ? 'All Region' : _selectedRegion,
                    icon: Icons.map_rounded,
                    onSelected: (v) => setState(() {
                      _showAllRegions = v == 'All Region';
                      _selectedRegion = v == 'All Region' ? null : v;
                      _selectedDistrict = null;
                      _selectedSpv = null;
                      ref
                          .read(auditDashboardFilterProvider.notifier)
                          .setRegion(_selectedRegion);
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
                      ref
                          .read(auditDashboardFilterProvider.notifier)
                          .setDistrict(_selectedDistrict);
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedSpv ?? 'All QA SPV',
                    options: ['All QA SPV', ...spvOptions],
                    selected: _selectedSpv,
                    icon: Icons.supervisor_account_rounded,
                    onSelected: (v) => setState(
                        () => _selectedSpv = v == 'All QA SPV' ? null : v),
                  ),
                ],
                onRefresh: () => _refreshCoverage(ref, coverageScope),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsRow(stats: [
                _StatCard(
                  icon: Icons.landscape_rounded,
                  iconColor: AdvantaColors.deepForest,
                  bgColor: Colors.grey[200]!,
                  value: auditWorkload(
                      _coverageArea(coverageFields), coverageFields.length),
                  label: 'Total Coverage',
                ),
                _StatCard(
                    icon: Icons.fact_check_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.paleGreen,
                    value: auditWorkload(
                        summary.targetAreaHa, summary.totalTargets),
                    label: 'Target Audit'),
                _StatCard(
                    icon: Icons.task_alt_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.successLight,
                    value:
                        '${summary.completedTargets} / ${summary.totalTargets} FN · ${summary.targetCompletionPct.toStringAsFixed(0)}%',
                    label: 'Achieved'),
                _StatCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AdvantaColors.error,
                    bgColor: AdvantaColors.errorLight,
                    value: summary.overdueTargets.toString(),
                    label: 'Overdue Target',
                    onTap: () => _showWeeklyFields(
                        context,
                        'Overdue',
                        targetFields
                            .where((f) => f.isOverdue)
                            .map((f) => f.weekly)
                            .toList(),
                        onChanged: () => _refreshCoverage(ref, coverageScope)),
                    highlight: summary.overdueTargets > 0),
              ]),
            ),
            SliverToBoxAdapter(
              child: _PhaseProgressSection(
                  summary: summary,
                  fields: targetFields,
                  onChanged: () => _refreshCoverage(ref, coverageScope)),
            ),
            SliverToBoxAdapter(
                child: WeeklyAuditCards(
              summary: WeeklyAuditSummary(targetFields.map((f) => f.weekly)),
              onDetail: (title, fields) => _showWeeklyFields(
                  context, title, fields,
                  onChanged: () => _refreshCoverage(ref, coverageScope)),
            )),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FIRatingPanel(
                      fiList: filteredFIList,
                      title: 'FI Rating',
                      subtitle: '${filteredFIList.length} FI',
                      showViewAll: filteredFIList.length > 5,
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
                    const SizedBox(height: 12),
                    _RegionalStructurePanel(
                        regionMap: regionMap,
                        expandedIndex: _expandedAreaIndex,
                        onToggle: (i) => setState(() => _expandedAreaIndex =
                            _expandedAreaIndex == i ? -1 : i)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, Map<String, dynamic>> _buildRegionMap(
      List<FieldCoverageStatus> fields) {
    final map = <String, Map<String, dynamic>>{};
    for (final f in fields) {
      final region = f.region.isEmpty ? 'Unknown' : f.region;
      map.putIfAbsent(
          region,
          () => {
                'fields': <FieldCoverageStatus>[],
                'spvSet': <String>{},
                'fiSet': <String>{}
              });
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
  final bool isDevPreview;
  final _CoverageViewRole? previewRole;
  final ValueChanged<_CoverageViewRole>? onPreviewRoleChanged;

  const _SPVView({
    required this.session,
    this.isDevPreview = false,
    this.previewRole,
    this.onPreviewRoleChanged,
  });

  @override
  ConsumerState<_SPVView> createState() => _SPVViewState();
}

class _SPVViewState extends ConsumerState<_SPVView> {
  String? _selectedSpv;
  String? _selectedDistrict;
  String? _selectedFi;
  int _expandedDistrictIndex = -1;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = ref.read(auditDashboardFilterProvider).district;
  }

  @override
  Widget build(BuildContext context) {
    final sharedFilters = ref.watch(auditDashboardFilterProvider);
    final fieldsAsync = ref.watch(coverageStatusListProvider);

    return fieldsAsync.when(
      loading: () => const _SkeletonLoader(),
      error: (e, _) => _CoverageErrorWidget(error: e.toString()),
      data: (allFields) {
        // 1. FILTER DASAR: Ambil hanya lahan milik SPV yang sedang login
        final String myName = widget.session.name.trim().toLowerCase();
        final mySpvFields = widget.isDevPreview
            ? allFields
            : allFields
                .where((f) => QaNameHelper.containsExactName(f.qaSpv, myName))
                .toList();
        final allCoverageFields =
            _filterAllCoverage(mySpvFields, sharedFilters.flags);
        final weeklyFields = _projectCoverageWeeks(mySpvFields,
            weeks: sharedFilters.weeks, flags: sharedFilters.flags);

        // 2. CASCADING LOGIC SPV (Berdasarkan lahan milik SPV ini saja)
        final spvOptions = allCoverageFields
            .map((f) => f.qaSpv)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final spvScopedFields = allCoverageFields
            .where((f) => _selectedSpv == null || f.qaSpv == _selectedSpv)
            .toList();
        final districts = allCoverageFields
            .where((f) => _selectedSpv == null || f.qaSpv == _selectedSpv)
            .map((f) => f.district)
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final fiOptions = spvScopedFields
            .where((f) =>
                _selectedDistrict == null || f.district == _selectedDistrict)
            .map((f) => f.qaFi)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        // 3. APPLY FILTER DROPDOWN USER
        bool matchesScope(FieldCoverageStatus f) {
          if (_selectedSpv != null && f.qaSpv != _selectedSpv) return false;
          if (_selectedDistrict != null && f.district != _selectedDistrict) {
            return false;
          }
          if (_selectedFi != null && f.qaFi != _selectedFi) return false;
          return true;
        }

        final coverageFields =
            allCoverageFields.where(matchesScope).toList(growable: false);
        final targetFields = weeklyFields
            .where(matchesScope)
            .where((field) => field.isAuditTarget)
            .toList(growable: false);
        final dashboardFields =
            sharedFilters.coverageMode == CoverageDisplayMode.allCoverage
                ? coverageFields
                : targetFields;

        // Hitung Statistik
        final summary = calculateFilteredPhases(
          targetFields,
        );
        final needsAttention =
            targetFields.where((f) => f.needsAttention).length;

        final fiList = buildFiCoverageList(targetFields);

        final districtMap = <String, List<FieldCoverageStatus>>{};
        for (final f in dashboardFields) {
          final key = f.district.isEmpty ? 'Unknown' : f.district;
          districtMap.putIfAbsent(key, () => []).add(f);
        }
        final districtEntries = districtMap.entries.toList()
          ..sort((a, b) => _avgScore(b.value).compareTo(_avgScore(a.value)));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _CoverageHeader(
                    title: 'Coverage Monitoring', session: widget.session)),
            if (widget.isDevPreview)
              SliverToBoxAdapter(
                child: _DevRolePreviewBar(
                  selected: widget.previewRole ?? _CoverageViewRole.spv,
                  onSelected: widget.onPreviewRoleChanged ?? (_) {},
                ),
              ),
            SliverToBoxAdapter(child: const _WeeklyCoverageControls()),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: [
                  PremiumFilterChip(
                    label: _selectedSpv ?? 'All QA SPV',
                    options: ['All QA SPV', ...spvOptions],
                    selected: _selectedSpv,
                    icon: Icons.supervisor_account_rounded,
                    onSelected: (v) => setState(() {
                      _selectedSpv = v == 'All QA SPV' ? null : v;
                      _selectedDistrict = null;
                      _selectedFi = null;
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedDistrict ?? 'All Kabupaten',
                    options: ['All Kabupaten', ...districts],
                    selected: _selectedDistrict,
                    icon: Icons.location_city_rounded,
                    onSelected: (v) => setState(() {
                      _selectedDistrict = v == 'All Kabupaten' ? null : v;
                      _selectedFi = null; // Reset FI jika Kabupaten berubah
                      ref
                          .read(auditDashboardFilterProvider.notifier)
                          .setDistrict(_selectedDistrict);
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedFi ?? 'All QA FI',
                    options: ['All QA FI', ...fiOptions],
                    selected: _selectedFi,
                    icon: Icons.person_search_rounded,
                    onSelected: (v) => setState(
                        () => _selectedFi = v == 'All QA FI' ? null : v),
                  ),
                ],
                onRefresh: () => _refreshCoverage(ref),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsRow(stats: [
                _StatCard(
                  icon: Icons.landscape_rounded,
                  iconColor: AdvantaColors.deepForest,
                  bgColor: Colors.grey[200]!,
                  value: auditWorkload(
                      _coverageArea(coverageFields), coverageFields.length),
                  label: 'Total Coverage',
                ),
                _StatCard(
                    icon: Icons.fact_check_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.paleGreen,
                    value: auditWorkload(
                        summary.targetAreaHa, summary.totalTargets),
                    label: 'Target Audit'),
                _StatCard(
                    icon: Icons.task_alt_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.successLight,
                    value:
                        '${summary.completedTargets} / ${summary.totalTargets} FN · ${summary.targetCompletionPct.toStringAsFixed(0)}%',
                    label: 'Achieved'),
                _StatCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AdvantaColors.error,
                    bgColor: AdvantaColors.errorLight,
                    value: needsAttention.toString(),
                    label: 'Needs Attention',
                    onTap: () => _showWeeklyFields(
                        context,
                        'Needs Attention',
                        targetFields
                            .where((f) => f.needsAttention)
                            .map((f) => f.weekly)
                            .toList(),
                        onChanged: () => _refreshCoverage(ref)),
                    highlight: needsAttention > 0),
              ]),
            ),
            SliverToBoxAdapter(
              child: _PhaseProgressSection(
                  summary: summary,
                  fields: targetFields,
                  onChanged: () => _refreshCoverage(ref)),
            ),
            SliverToBoxAdapter(
                child: WeeklyAuditCards(
              summary: WeeklyAuditSummary(targetFields.map((f) => f.weekly)),
              onDetail: (title, fields) => _showWeeklyFields(
                  context, title, fields,
                  onChanged: () => _refreshCoverage(ref)),
            )),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FIRatingPanel(
                      fiList: fiList,
                      title: 'FI Rating Tim',
                      subtitle: '${fiList.length} FI',
                      showViewAll: fiList.length > 5,
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
                    const SizedBox(height: 12),
                    _CoverageStructurePanel(
                        districts: districtEntries,
                        expandedIndex: _expandedDistrictIndex,
                        onToggle: (i) => setState(() => _expandedDistrictIndex =
                            _expandedDistrictIndex == i ? -1 : i)),
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
    return aggregateCoverageScore(fields);
  }
}

// ============================================================
// SECTION F — QA FI VIEW
// ============================================================

class _FIView extends ConsumerStatefulWidget {
  final ActiveSession session;
  final bool isDevPreview;
  final _CoverageViewRole? previewRole;
  final ValueChanged<_CoverageViewRole>? onPreviewRoleChanged;

  const _FIView({
    required this.session,
    this.isDevPreview = false,
    this.previewRole,
    this.onPreviewRoleChanged,
  });

  @override
  ConsumerState<_FIView> createState() => _FIViewState();
}

class _FIViewState extends ConsumerState<_FIView> {
  String? _selectedFi;
  String? _selectedDistrict;
  String? _selectedVillage;
  String? _selectedPhase;
  int _expandedVillageIndex = -1;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(auditDashboardFilterProvider);
    _selectedDistrict = filters.district;
    _selectedVillage = filters.village;
  }

  @override
  Widget build(BuildContext context) {
    final sharedFilters = ref.watch(auditDashboardFilterProvider);
    final fieldsAsync = ref.watch(coverageStatusListProvider);

    return fieldsAsync.when(
      loading: () => const _SkeletonLoader(),
      error: (e, _) => _CoverageErrorWidget(error: e.toString()),
      data: (allFields) {
        // 1. FILTER DASAR: Ambil hanya lahan milik QA FI yang sedang login
        final String myName = widget.session.name.trim().toLowerCase();
        final myFiFields = widget.isDevPreview
            ? allFields
            : allFields
                .where((f) => QaNameHelper.containsExactName(f.qaFi, myName))
                .toList();
        final allCoverageFields =
            _filterAllCoverage(myFiFields, sharedFilters.flags);
        final weeklyFields = _projectCoverageWeeks(myFiFields,
            weeks: sharedFilters.weeks, flags: sharedFilters.flags);

        // 2. CASCADING LOGIC FI (Gunakan myFiFields)
        final fiOptions = allCoverageFields
            .map((f) => f.qaFi)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final fiScopedFields = allCoverageFields
            .where((f) => _selectedFi == null || f.qaFi == _selectedFi)
            .toList();
        final districts = fiScopedFields
            .map((f) => f.district)
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final villageOptions = fiScopedFields
            .where((f) =>
                _selectedDistrict == null || f.district == _selectedDistrict)
            .map((f) => f.village)
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        // 3. APPLY FILTERS DROPDOWN USER
        bool matchesScope(FieldCoverageStatus f) {
          if (_selectedFi != null && f.qaFi != _selectedFi) return false;
          if (_selectedDistrict != null && f.district != _selectedDistrict) {
            return false;
          }
          if (_selectedVillage != null && f.village != _selectedVillage) {
            return false;
          }
          if (_selectedPhase != null) {
            final selected =
                _selectedPhase == 'Pre-Harvest' ? 'PreHarvest' : _selectedPhase;
            return auditStageLabels[f.weekly.stage] == selected;
          }
          return true;
        }

        final coverageFields =
            allCoverageFields.where(matchesScope).toList(growable: false);
        final targetFields = weeklyFields
            .where(matchesScope)
            .where((field) => field.isAuditTarget)
            .toList(growable: false);
        final dashboardFields =
            sharedFilters.coverageMode == CoverageDisplayMode.allCoverage
                ? coverageFields
                : targetFields;

        final summary = calculateFilteredPhases(
          targetFields,
        );
        final overdueFields = targetFields.where((f) => f.isOverdue).length;

        final villageMap = <String, List<FieldCoverageStatus>>{};
        for (final f in dashboardFields) {
          final key = f.weekly.villageKey;
          villageMap.putIfAbsent(key, () => []).add(f);
        }

        final villageEntries = villageMap.entries.toList()
          ..sort((a, b) =>
              _avgScore(a.value).compareTo(_avgScore(b.value))); // Worst first

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _CoverageHeader(
                    title: 'Coverage Monitoring', session: widget.session)),
            if (widget.isDevPreview)
              SliverToBoxAdapter(
                child: _DevRolePreviewBar(
                  selected: widget.previewRole ?? _CoverageViewRole.fi,
                  onSelected: widget.onPreviewRoleChanged ?? (_) {},
                ),
              ),
            SliverToBoxAdapter(child: const _WeeklyCoverageControls()),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: [
                  if (widget.isDevPreview)
                    PremiumFilterChip(
                      label: _selectedFi ?? 'All QA FI',
                      options: ['All QA FI', ...fiOptions],
                      selected: _selectedFi,
                      icon: Icons.person_search_rounded,
                      onSelected: (v) => setState(() {
                        _selectedFi = v == 'All QA FI' ? null : v;
                        _selectedDistrict = null;
                        _selectedVillage = null;
                      }),
                    ),
                  PremiumFilterChip(
                    label: _selectedDistrict ?? 'All Kabupaten',
                    options: ['All Kabupaten', ...districts],
                    selected: _selectedDistrict,
                    icon: Icons.location_city_rounded,
                    onSelected: (v) => setState(() {
                      _selectedDistrict = v == 'All Kabupaten' ? null : v;
                      _selectedVillage = null;
                      ref
                          .read(auditDashboardFilterProvider.notifier)
                          .setDistrict(_selectedDistrict);
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedVillage ?? 'All Desa',
                    options: ['All Desa', ...villageOptions],
                    selected: _selectedVillage,
                    icon: Icons.holiday_village_rounded,
                    onSelected: (v) => setState(() {
                      _selectedVillage = v == 'All Desa' ? null : v;
                      ref
                          .read(auditDashboardFilterProvider.notifier)
                          .setVillage(_selectedVillage);
                    }),
                  ),
                  PremiumFilterChip(
                    label: _selectedPhase ?? 'All Phase',
                    options: const [
                      'All Phase',
                      'Vegetative',
                      'Generative',
                      'Pre-Harvest',
                      'Harvest'
                    ],
                    selected: _selectedPhase,
                    icon: Icons.grass_rounded,
                    onSelected: (v) => setState(
                        () => _selectedPhase = v == 'All Phase' ? null : v),
                  ),
                ],
                onRefresh: () => _refreshCoverage(ref),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsRow(stats: [
                _StatCard(
                    icon: Icons.landscape_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.paleGreen,
                    value: auditWorkload(
                        _coverageArea(coverageFields), coverageFields.length),
                    label: 'Coverage'),
                _StatCard(
                    icon: Icons.fact_check_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.paleGreen,
                    value: auditWorkload(
                        summary.targetAreaHa, summary.totalTargets),
                    label: 'Target'),
                _StatCard(
                    icon: Icons.task_alt_rounded,
                    iconColor: AdvantaColors.midGreen,
                    bgColor: AdvantaColors.successLight,
                    value:
                        '${summary.completedTargets} / ${summary.totalTargets} FN · ${summary.targetCompletionPct.toStringAsFixed(0)}%',
                    label: 'Achieved'),
                _StatCard(
                    icon: Icons.assignment_late_rounded,
                    iconColor: AdvantaColors.error,
                    bgColor: AdvantaColors.errorLight,
                    value: '${summary.actionFields + overdueFields} FN',
                    label: 'Need Attention / Overdue',
                    onTap: () => _showWeeklyFields(
                        context,
                        'Need Attention / Overdue',
                        targetFields
                            .where((f) => f.needsAttention)
                            .map((f) => f.weekly)
                            .toList(),
                        onChanged: () => _refreshCoverage(ref)),
                    highlight: summary.actionFields + overdueFields > 0),
              ]),
            ),
            SliverToBoxAdapter(
              child: _PhaseProgressSection(
                  summary: summary,
                  fields: targetFields,
                  onChanged: () => _refreshCoverage(ref)),
            ),
            SliverToBoxAdapter(
                child: WeeklyAuditCards(
              summary: WeeklyAuditSummary(targetFields.map((f) => f.weekly)),
              onDetail: (title, fields) => _showWeeklyFields(
                  context, title, fields,
                  onChanged: () => _refreshCoverage(ref)),
            )),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                        child: Text('Village Coverage List',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AdvantaColors.deepForest))),
                    const SizedBox(width: 8),
                    Text('${villageEntries.length} desa',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                      villageName:
                          '${entry.value.first.village} · ${entry.value.first.subDistrict}',
                      fields: entry.value,
                      isExpanded: _expandedVillageIndex == i,
                      onTap: () => setState(() => _expandedVillageIndex =
                          _expandedVillageIndex == i ? -1 : i),
                    ),
                  );
                },
                childCount: villageEntries.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _OpenRouteButton(fields: dashboardFields),
              ),
            ),
          ],
        );
      },
    );
  }

  double _avgScore(List<FieldCoverageStatus> fields) {
    return aggregateCoverageScore(fields);
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
              ? const LinearGradient(
                  colors: [AdvantaColors.deepForest, AdvantaColors.midGreen])
              : const LinearGradient(colors: [Colors.white, Colors.white]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.transparent : AdvantaColors.dividerGrey,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AdvantaColors.deepForest.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isActive ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? Colors.white : AdvantaColors.mutedGrey),
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
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? Colors.white : AdvantaColors.mutedGrey),
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

  const _PremiumFilterModal(
      {required this.title,
      required this.options,
      required this.selected,
      required this.onSelected});

  @override
  State<_PremiumFilterModal> createState() => _PremiumFilterModalState();
}

class _PremiumFilterModalState extends State<_PremiumFilterModal> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredOptions = widget.options
        .where((opt) => opt.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

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
            Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AdvantaColors.deepForest)),
            const SizedBox(height: 16),

            // Search Bar
            if (widget.options.length > 5)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AdvantaColors.softGrey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari data...',
                      hintStyle:
                          TextStyle(color: Colors.grey[500], fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

            // List Options
            Expanded(
              child: filteredOptions.isEmpty
                  ? Center(
                      child: Text('Tidak ditemukan',
                          style: TextStyle(color: Colors.grey[400])))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: filteredOptions.length,
                      itemBuilder: (ctx, i) {
                        final opt = filteredOptions[i];
                        final isSelected = widget.selected == opt ||
                            (widget.selected == null && opt.startsWith('All'));

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelected(opt);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AdvantaColors.paleGreen
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isSelected
                                      ? AdvantaColors.deepForest
                                          .withValues(alpha: 0.3)
                                      : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(opt,
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? AdvantaColors.deepForest
                                                : AdvantaColors.charcoal))),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AdvantaColors.deepForest,
                                      size: 22),
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
  final ActiveSession session;

  const _CoverageHeader({required this.title, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AdvantaColors.deepForest, AdvantaColors.primaryGreen]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(
                          session.name.isNotEmpty
                              ? session.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700))),
              Stack(children: [
                IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                    onPressed: () {}),
                Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFFFFB300), shape: BoxShape.circle)))
              ])
            ],
          ),
        ),
      ),
    );
  }
}

class _DevRolePreviewBar extends StatelessWidget {
  final _CoverageViewRole selected;
  final ValueChanged<_CoverageViewRole> onSelected;

  const _DevRolePreviewBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdvantaColors.deepForest,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
        decoration: const BoxDecoration(
          color: AdvantaColors.softGrey,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final buttons = _CoverageViewRole.values.map((role) {
              final active = role == selected;
              return _DevRoleButton(
                role: role,
                active: active,
                compact: compact,
                onTap: () => onSelected(role),
              );
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dev role preview',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                compact
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: buttons),
                      )
                    : Row(
                        children: buttons
                            .map((button) => Expanded(child: button))
                            .toList(),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DevRoleButton extends StatelessWidget {
  final _CoverageViewRole role;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _DevRoleButton({
    required this.role,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(
            minWidth: compact ? 116 : 0,
            minHeight: 42,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AdvantaColors.deepForest : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  active ? AdvantaColors.deepForest : AdvantaColors.dividerGrey,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: active ? 0.08 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                role.icon,
                size: 16,
                color: active ? Colors.white : AdvantaColors.deepForest,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : AdvantaColors.deepForest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<Widget> filters;
  final Future<void> Function() onRefresh;

  const _FilterBar({required this.filters, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdvantaColors.deepForest,
      child: Container(
        decoration: const BoxDecoration(
            color: AdvantaColors.softGrey,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20))),
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

class _RefreshButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const _RefreshButton({required this.onRefresh});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _isRefreshing = false;

  Future<void> _handleTap() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } catch (_) {
      // Error state is rendered by the provider watcher.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isRefreshing ? null : _handleTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AdvantaColors.dividerGrey),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
        child: _isRefreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdvantaColors.charcoal,
                ),
              )
            : const Icon(Icons.refresh_rounded,
                size: 16, color: AdvantaColors.charcoal),
      ),
    );
  }
}

// StatsRow, StatCard, PhaseProgress, FIRating, RegionalStructure persis seperti yang lama.
class _StatsRow extends StatelessWidget {
  final List<_StatCard> stats;
  const _StatsRow({required this.stats});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? stats.length
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats
                .map((card) => SizedBox(
                    width: (constraints.maxWidth - (columns - 1) * 8) / columns,
                    height: 114,
                    child: card))
                .toList());
      }));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;
  const _StatCard(
      {required this.icon,
      required this.iconColor,
      required this.bgColor,
      required this.value,
      required this.label,
      this.highlight = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? iconColor.withValues(alpha: 0.35)
                  : AdvantaColors.dividerGrey.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: AdvantaColors.deepForest.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: highlight ? iconColor : AdvantaColors.deepForest),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 9,
                  color: AdvantaColors.mutedGrey,
                  fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ));
  }
}

class _PhaseProgressSection extends StatelessWidget {
  final PhaseSummary summary;
  final List<FieldCoverageStatus> fields;
  final VoidCallback onChanged;
  const _PhaseProgressSection(
      {required this.summary, required this.fields, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Target achievement per phase',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdvantaColors.deepForest)),
              TextButton(
                  onPressed: () => _showWeeklyFields(
                      context,
                      'Target audit minggu terpilih',
                      fields.map((f) => f.weekly).toList(),
                      onChanged: onChanged),
                  child: const Text('Lihat detail')),
            ]),
        Text('${summary.targetCompletionPct.toStringAsFixed(1)}%',
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AdvantaColors.midGreen)),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _value('Target audit', summary.targetAreaHa, summary.totalTargets),
          _value(
              'Achievement', summary.achievedAreaHa, summary.completedTargets),
          _value('Overdue', summary.overdueAreaHa, summary.overdueTargets),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(
            builder: (context, box) => Wrap(
                spacing: 16,
                runSpacing: 16,
                children: summary.phases
                    .map((phase) => SizedBox(
                        width:
                            (box.maxWidth - (box.maxWidth >= 720 ? 48 : 16)) /
                                (box.maxWidth >= 720 ? 4 : 2),
                        child: _PhaseBar(
                            phase: phase,
                            onTap: () => _showWeeklyFields(
                                context,
                                phase.label,
                                fields
                                    .where((field) => field.weekly.targets.any(
                                        (target) =>
                                            auditStage(target.phase) == auditStageLabels.entries.firstWhere((entry) => entry.value == phase.label).key))
                                    .map((field) => field.weekly)
                                    .toList(),
                                onChanged: onChanged))))
                    .toList())),
      ]));
  Widget _value(String label, double area, int fn) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(auditWorkload(area, fn),
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AdvantaColors.mutedGrey)),
      ]);
}

class _PhaseBar extends StatelessWidget {
  final PhaseCoverage phase;
  final VoidCallback onTap;
  const _PhaseBar({required this.phase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
            padding: const EdgeInsets.all(4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Label Fase (Veg, Gen, dst)
              Text(phase.shortLabel,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AdvantaColors.charcoal)),
              const SizedBox(height: 2),

              // Persentase
              Text('${phase.pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: phase.color)),
              const SizedBox(height: 4),

              // Progress Bar
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: phase.pct / 100,
                      backgroundColor: phase.color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(phase.color),
                      minHeight: 6)),
              const SizedBox(height: 3),

              // 👇 JUMLAH LAHAN (RIIL)
              Text(
                  '${phase.done} / ${phase.total} FN · ${_formatHa(phase.totalHa)}',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600)),
            ])));
  }
}

class _FIRatingPanel extends StatelessWidget {
  final List<FICoverage> fiList;
  final String title;
  final String subtitle;
  final bool showViewAll;
  // 👇 1. Ubah String menjadi FICoverage
  final ValueChanged<FICoverage>? onFiTapped;

  const _FIRatingPanel({
    required this.fiList,
    required this.title,
    required this.subtitle,
    required this.showViewAll,
    this.onFiTapped,
  });

  void _showAllFi(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FIRatingListSheet(
        title: title,
        subtitle: subtitle,
        fiList: fiList,
        onFiTapped: onFiTapped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleList = fiList.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdvantaColors.deepForest)),
            const Spacer(),
            if (showViewAll)
              _ViewAllIconButton(
                tooltip: 'Lihat semua $title',
                onTap: () => _showAllFi(context),
              ),
          ]),
          const SizedBox(height: 8),
          if (visibleList.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('Tidak ada data',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 12))))
          else
            // 👇 2. Kirim seluruh objek `e.value` (yang berisi FICoverage)
            ...visibleList.asMap().entries.map((e) => _FIRatingItem(
                  rank: e.key + 1,
                  fi: e.value,
                  onTap: onFiTapped != null ? () => onFiTapped!(e.value) : null,
                )),
        ],
      ),
    );
  }
}

class _ViewAllIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _ViewAllIconButton({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AdvantaColors.paleGreen,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdvantaColors.dividerGrey),
          ),
          child: const Icon(
            Icons.visibility_rounded,
            size: 16,
            color: AdvantaColors.deepForest,
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SheetHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AdvantaColors.deepForest)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FIRatingListSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<FICoverage> fiList;
  final ValueChanged<FICoverage>? onFiTapped;

  const _FIRatingListSheet({
    required this.title,
    required this.subtitle,
    required this.fiList,
    this.onFiTapped,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AdvantaColors.softGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AdvantaColors.deepForest)),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: fiList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final fi = fiList[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdvantaColors.dividerGrey),
                    ),
                    child: _FIRatingItem(
                      rank: i + 1,
                      fi: fi,
                      onTap: onFiTapped == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onFiTapped!(fi);
                            },
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

class _FIRatingItem extends StatelessWidget {
  final int rank;
  final FICoverage fi;
  final VoidCallback? onTap; // 👈 1. Tambahkan onTap

  const _FIRatingItem({required this.rank, required this.fi, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // 👈 2. Bungkus dengan InkWell agar ada efek klik (ripple)
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 6, horizontal: 4), // Sesuaikan padding
        child: Row(children: [
          Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  color: rank <= 3 ? AdvantaColors.paleGreen : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6)),
              child: Center(
                  child: Text('$rank',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: rank <= 3
                              ? AdvantaColors.deepForest
                              : Colors.grey[500])))),
          const SizedBox(width: 6),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(fi.name,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdvantaColors.deepForest),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    '${fi.targetFields} target field · ${fi.completedTargets}/${fi.totalTargets} target${fi.actionFields > 0 ? ' · ${fi.actionFields} action' : ''}',
                    style: TextStyle(
                        fontSize: 9,
                        color: fi.actionFields > 0
                            ? AdvantaColors.gold
                            : Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)
              ])),
          const SizedBox(width: 4),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fi.coverageScore.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: fi.statusColor)),
            Text(fi.statusLabel,
                style: TextStyle(
                    fontSize: 9,
                    color: fi.statusColor,
                    fontWeight: FontWeight.w600))
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey[300])
        ]),
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
      final key = f.weekly.villageKey;
      villageMap.putIfAbsent(key, () => []).add(f);
    }
    final villageEntries = villageMap.entries.toList()
      ..sort((a, b) => b.value.length
          .compareTo(a.value.length)); // Urutkan dari lahan terbanyak

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
                  child: Center(
                      child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4)))),
                ),

                // Header Profile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: AdvantaColors.deepForest,
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(
                            child: Text(avatarLetter,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fi.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AdvantaColors.deepForest)),
                            const SizedBox(height: 2),
                            Text(
                                '${fi.totalFields} Lahan · ${villageEntries.length} Desa',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: fi.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${fi.coverageScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: fi.statusColor)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Info Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                            width: 150,
                            child: _buildInfoCard(
                                'Area Assigned',
                                _formatHa(fi.totalAreaHa),
                                Icons.landscape_rounded,
                                AdvantaColors.midGreen)),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 140,
                            child: _buildInfoCard(
                                'Target Done',
                                '${fi.completedTargets}/${fi.totalTargets}',
                                Icons.fact_check_rounded,
                                AdvantaColors.success)),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 128,
                            child: _buildInfoCard(
                                'Action',
                                fi.actionFields.toString(),
                                Icons.assignment_late_rounded,
                                fi.actionFields > 0
                                    ? AdvantaColors.gold
                                    : Colors.grey)),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 128,
                            child: _buildInfoCard(
                                'Overdue',
                                fi.overdueFields.toString(),
                                Icons.warning_amber_rounded,
                                fi.overdueFields > 0
                                    ? AdvantaColors.error
                                    : Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // List Desa yang ditangani
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      itemCount: villageEntries.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 24, color: Colors.grey[100]),
                      itemBuilder: (_, i) {
                        final vName = villageEntries[i].key;
                        final vFields = villageEntries[i].value;
                        final vScore = aggregateCoverageScore(vFields);
                        final vColor = vScore >= 85
                            ? AdvantaColors.success
                            : vScore >= 60
                                ? const Color(0xFFD4A017)
                                : AdvantaColors.error;
                        final vOverdue =
                            vFields.where((f) => f.isOverdue).length;

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AdvantaColors.paleGreen,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.holiday_village_rounded,
                                  size: 16, color: AdvantaColors.deepForest),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vName,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AdvantaColors.deepForest)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${vFields.length} lahan${vOverdue > 0 ? ' · $vOverdue overdue' : ''}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: vOverdue > 0
                                              ? AdvantaColors.error
                                              : Colors.grey[500])),
                                ],
                              ),
                            ),
                            Text('${vScore.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: vColor)),
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

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdvantaColors.dividerGrey)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AdvantaColors.deepForest)),
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
  const _RegionalStructurePanel(
      {required this.regionMap,
      required this.expandedIndex,
      required this.onToggle});

  @override
  State<_RegionalStructurePanel> createState() =>
      _RegionalStructurePanelState();
}

class _RegionalStructurePanelState extends State<_RegionalStructurePanel> {
  void _showAllRegions(BuildContext context,
      List<MapEntry<String, Map<String, dynamic>>> entries) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RegionalStructureListSheet(entries: entries),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.regionMap.entries.toList()
      ..sort((a, b) =>
          _avgScore(b.value['fields']).compareTo(_avgScore(a.value['fields'])));
    final visible = entries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Regional Structure',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdvantaColors.deepForest)),
            const Spacer(),
            if (entries.length > 5)
              _ViewAllIconButton(
                tooltip: 'Lihat semua regional',
                onTap: () => _showAllRegions(context, entries),
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
      aggregateCoverageScore(fields);
}

class _RegionalStructureListSheet extends StatefulWidget {
  final List<MapEntry<String, Map<String, dynamic>>> entries;

  const _RegionalStructureListSheet({required this.entries});

  @override
  State<_RegionalStructureListSheet> createState() =>
      _RegionalStructureListSheetState();
}

class _RegionalStructureListSheetState
    extends State<_RegionalStructureListSheet> {
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AdvantaColors.softGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _SheetHeader(
              title: 'Regional Structure',
              subtitle: '${widget.entries.length} regional',
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: widget.entries.asMap().entries.map((entry) {
                  final regionName = entry.value.key;
                  final data = entry.value.value;
                  final fields = data['fields'] as List<FieldCoverageStatus>;
                  final score = aggregateCoverageScore(fields);
                  final area =
                      fields.fold(0.0, (s, f) => s + f.effectiveAreaHa);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RegionAccordion(
                      name: regionName,
                      score: score,
                      area: area,
                      spvCount: (data['spvSet'] as Set).length,
                      fiCount: (data['fiSet'] as Set).length,
                      fieldCount: fields.length,
                      isExpanded: _expandedIndex == entry.key,
                      onToggle: () => setState(() => _expandedIndex =
                          _expandedIndex == entry.key ? -1 : entry.key),
                      fields: fields,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionAccordion extends StatelessWidget {
  final String name;
  final double score;
  final double area;
  final int spvCount;
  final int fiCount;
  final int fieldCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<FieldCoverageStatus> fields;
  const _RegionAccordion(
      {required this.name,
      required this.score,
      required this.area,
      required this.spvCount,
      required this.fiCount,
      required this.fieldCount,
      required this.isExpanded,
      required this.onToggle,
      required this.fields});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? AdvantaColors.success
        : score >= 60
            ? const Color(0xFFD4A017)
            : AdvantaColors.error;
    return Column(children: [
      GestureDetector(
          onTap: onToggle,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AdvantaColors.deepForest)),
                      Text('$spvCount SPV · $fiCount FI · ${_formatHa(area)}',
                          style:
                              TextStyle(fontSize: 9, color: Colors.grey[500]))
                    ])),
                SizedBox(
                    width: 50,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${score.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                          const SizedBox(height: 2),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                  value: score / 100,
                                  minHeight: 4,
                                  backgroundColor:
                                      color.withValues(alpha: 0.15),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color)))
                        ])),
                const SizedBox(width: 4),
                AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Colors.grey[400]))
              ]))),

      // 👇 PERUBAHAN: Meneruskan `context` ke _buildBreakdown
      if (isExpanded) ..._buildBreakdown(context),

      Divider(height: 1, color: Colors.grey[100])
    ]);
  }

  // 👇 PERUBAHAN: Menambahkan fitur klik dan Bottom Sheet Daftar Field
  List<Widget> _buildBreakdown(BuildContext context) {
    final map = <String, List<FieldCoverageStatus>>{};
    for (final f in fields) {
      map
          .putIfAbsent(f.district.isEmpty ? 'Unknown' : f.district, () => [])
          .add(f);
    }

    return map.entries.map((e) {
      final s = aggregateCoverageScore(e.value);
      return InkWell(
        onTap: () => _showDistrictFieldsSheet(context, e.key, e.value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                      color: Colors.grey[400], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(e.key,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AdvantaColors.charcoal,
                            fontWeight: FontWeight.w700)),
                    Text('${e.value.length} fields',
                        style: TextStyle(fontSize: 8, color: Colors.grey[500]))
                  ])),
              Text('${s.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: s >= 85
                          ? AdvantaColors.success
                          : s >= 60
                              ? const Color(0xFFD4A017)
                              : AdvantaColors.error)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 12, color: Colors.grey[300])
            ])),
      );
    }).toList();
  }

  // Fungsi baru untuk memunculkan Bottom Sheet persis seperti QA FI View
  void _showDistrictFieldsSheet(BuildContext context, String districtName,
      List<FieldCoverageStatus> distFields) {
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
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, ctrl) => Container(
              decoration: const BoxDecoration(
                  color: AdvantaColors.softGrey,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 16),
                        Text('Fields — $districtName',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AdvantaColors.deepForest)),
                        const SizedBox(height: 4),
                        Text(
                            '${distFields.length} field · ${distFields.where((f) => f.isOverdue).length} overdue',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500])),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: distFields.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final f = distFields[i];
                        final score = f.coverageScore;
                        final sc = score >= 85
                            ? AdvantaColors.success
                            : score >= 60
                                ? const Color(0xFFD4A017)
                                : AdvantaColors.error;
                        final leadColor = f.isOverdue
                            ? AdvantaColors.error
                            : f.hasActionRequired
                                ? AdvantaColors.gold
                                : sc;

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Tutup list
                            FieldDetailBottomSheet.show(
                                context, f.raw); // Buka detail
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: leadColor,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f.fieldNumber,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AdvantaColors.deepForest)),
                                      const SizedBox(height: 2),
                                      if (f.farmerName.isNotEmpty ||
                                          f.hybrid.isNotEmpty)
                                        Text(
                                          [f.farmerName, f.hybrid]
                                              .where(
                                                  (value) => value.isNotEmpty)
                                              .join(' · '),
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[700]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (f.farmerName.isNotEmpty ||
                                          f.hybrid.isNotEmpty)
                                        const SizedBox(height: 1),
                                      Text(
                                        '${f.activePhaseLabel} - DAP ${f.dap}${f.isOverdue ? ' - Overdue' : ''}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: f.isOverdue
                                                ? AdvantaColors.error
                                                : Colors.grey[500]),
                                      ),
                                      if (f.latestAuditDate != null)
                                        Text(
                                          'Last audit ${f.latestAuditDate}${f.latestAuditWeek == null ? '' : ' - ${f.latestAuditWeek}'}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[500]),
                                        ),
                                      if (f.hasActionRequired)
                                        Text(
                                          'Action ${f.actionPhase}-${f.actionCode}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AdvantaColors.gold),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${score.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: sc)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      _PhaseDot(
                                          done: f.vegetativeDone, label: 'V'),
                                      _PhaseDot(
                                          done: f.anyGenerativeDone,
                                          label: 'G'),
                                      _PhaseDot(
                                          done: f.preHarvestDone, label: 'P'),
                                      _PhaseDot(
                                          done: f.harvestDone, label: 'H'),
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
  const _CoverageStructurePanel(
      {required this.districts,
      required this.expandedIndex,
      required this.onToggle});

  @override
  State<_CoverageStructurePanel> createState() =>
      _CoverageStructurePanelState();
}

class _CoverageStructurePanelState extends State<_CoverageStructurePanel> {
  void _showAllDistricts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CoverageStructureListSheet(districts: widget.districts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.districts.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Coverage Structure',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdvantaColors.deepForest)),
            const Spacer(),
            if (widget.districts.length > 4)
              _ViewAllIconButton(
                tooltip: 'Lihat semua coverage structure',
                onTap: () => _showAllDistricts(context),
              ),
          ]),
          const SizedBox(height: 8),
          ...visible.asMap().entries.map((entry) {
            final dFields = entry.value.value;
            final score = aggregateCoverageScore(dFields);
            final color = score >= 85
                ? AdvantaColors.success
                : score >= 60
                    ? const Color(0xFFD4A017)
                    : AdvantaColors.error;
            final isExpanded = widget.expandedIndex == entry.key;

            return Column(children: [
              GestureDetector(
                onTap: () => widget.onToggle(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(entry.value.key,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(
                              '${dFields.map((f) => f.qaFi).where((s) => s.isNotEmpty).toSet().length} FI · ${dFields.length} Lahan',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[500])),
                        ])),
                    SizedBox(
                        width: 55,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${score.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: color)),
                              const SizedBox(height: 2),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                      value: score / 100,
                                      minHeight: 4,
                                      backgroundColor:
                                          color.withValues(alpha: 0.15),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          color))),
                            ])),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: Colors.grey[300])),
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
    for (final f in fields) {
      map
          .putIfAbsent(f.village.isEmpty ? 'Unknown' : f.village, () => [])
          .add(f);
    }
    return Column(
        children: map.entries.map((e) {
      final s = aggregateCoverageScore(e.value);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 4, 5),
        child: Row(children: [
          Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                  color: Colors.grey[300], shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(e.key,
                  style: const TextStyle(
                      fontSize: 9, color: AdvantaColors.charcoal))),
          Text('${e.value.length} field',
              style: TextStyle(fontSize: 9, color: Colors.grey[400])),
          const SizedBox(width: 8),
          Text('${s.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: s >= 85
                      ? AdvantaColors.success
                      : s >= 60
                          ? const Color(0xFFD4A017)
                          : AdvantaColors.error)),
        ]),
      );
    }).toList());
  }
}

class _CoverageStructureListSheet extends StatefulWidget {
  final List<MapEntry<String, List<FieldCoverageStatus>>> districts;

  const _CoverageStructureListSheet({required this.districts});

  @override
  State<_CoverageStructureListSheet> createState() =>
      _CoverageStructureListSheetState();
}

class _CoverageStructureListSheetState
    extends State<_CoverageStructureListSheet> {
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AdvantaColors.softGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _SheetHeader(
              title: 'Coverage Structure',
              subtitle: '${widget.districts.length} kabupaten',
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: widget.districts.asMap().entries.map((entry) {
                  final dFields = entry.value.value;
                  final score = aggregateCoverageScore(dFields);
                  final color = score >= 85
                      ? AdvantaColors.success
                      : score >= 60
                          ? const Color(0xFFD4A017)
                          : AdvantaColors.error;
                  final isExpanded = _expandedIndex == entry.key;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdvantaColors.dividerGrey),
                    ),
                    child: Column(children: [
                      GestureDetector(
                        onTap: () => setState(() => _expandedIndex =
                            _expandedIndex == entry.key ? -1 : entry.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.value.key,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AdvantaColors.deepForest)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${dFields.map((f) => f.qaFi).where((s) => s.isNotEmpty).toSet().length} FI · ${dFields.length} Lahan',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: 62,
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${score.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: color)),
                                      const SizedBox(height: 3),
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                              value: score / 100,
                                              minHeight: 4,
                                              backgroundColor:
                                                  color.withValues(alpha: 0.15),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      color))),
                                    ])),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 18, color: Colors.grey[400])),
                          ]),
                        ),
                      ),
                      if (isExpanded) _buildVillageBreakdown(dFields),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVillageBreakdown(List<FieldCoverageStatus> fields) {
    final map = <String, List<FieldCoverageStatus>>{};
    for (final f in fields) {
      map
          .putIfAbsent(f.village.isEmpty ? 'Unknown' : f.village, () => [])
          .add(f);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
          children: map.entries.map((e) {
        final s = aggregateCoverageScore(e.value);
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 7),
          child: Row(children: [
            Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(e.key,
                    style: const TextStyle(
                        fontSize: 11, color: AdvantaColors.charcoal))),
            Text('${e.value.length} field',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(width: 10),
            Text('${s.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: s >= 85
                        ? AdvantaColors.success
                        : s >= 60
                            ? const Color(0xFFD4A017)
                            : AdvantaColors.error)),
          ]),
        );
      }).toList()),
    );
  }
}

// ============================================================
// VILLAGE CARD & INTEGRASI KE DETAIL BOTTOM SHEET
// ============================================================

class _VillageCard extends StatelessWidget {
  final String villageName;
  final List<FieldCoverageStatus> fields;
  final bool isExpanded;
  final VoidCallback onTap;
  const _VillageCard(
      {required this.villageName,
      required this.fields,
      required this.isExpanded,
      required this.onTap});

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
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, ctrl) => Container(
              decoration: const BoxDecoration(
                  color: AdvantaColors.softGrey,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 16),
                        Text('Fields — $villageName',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AdvantaColors.deepForest)),
                        const SizedBox(height: 4),
                        Text(
                            '${fields.length} field · ${fields.where((f) => f.isOverdue).length} overdue',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500])),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: fields.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final f = fields[i];
                        final score = f.coverageScore;
                        final sc = score >= 85
                            ? AdvantaColors.success
                            : score >= 60
                                ? const Color(0xFFD4A017)
                                : AdvantaColors.error;
                        final leadColor = f.isOverdue
                            ? AdvantaColors.error
                            : f.hasActionRequired
                                ? AdvantaColors.gold
                                : sc;

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
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: leadColor,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f.fieldNumber,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AdvantaColors.deepForest)),
                                      const SizedBox(height: 2),
                                      if (f.farmerName.isNotEmpty ||
                                          f.hybrid.isNotEmpty)
                                        Text(
                                          [f.farmerName, f.hybrid]
                                              .where(
                                                  (value) => value.isNotEmpty)
                                              .join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[700]),
                                        ),
                                      Text(
                                        '${f.activePhaseLabel} - DAP ${f.dap}${f.isOverdue ? ' - Overdue' : ''}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: f.isOverdue
                                                ? AdvantaColors.error
                                                : Colors.grey[500]),
                                      ),
                                      if (f.latestAuditDate != null)
                                        Text(
                                          'Last audit ${f.latestAuditDate}${f.latestAuditWeek == null ? '' : ' - ${f.latestAuditWeek}'}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[500]),
                                        ),
                                      if (f.hasActionRequired)
                                        Text(
                                          'Action ${f.actionPhase}-${f.actionCode}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AdvantaColors.gold),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${score.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: sc)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      _PhaseDot(
                                          done: f.vegetativeDone, label: 'V'),
                                      _PhaseDot(
                                          done: f.anyGenerativeDone,
                                          label: 'G'),
                                      _PhaseDot(
                                          done: f.preHarvestDone, label: 'P'),
                                      _PhaseDot(
                                          done: f.harvestDone, label: 'H'),
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
    final score = aggregateCoverageScore(fields);
    final scoreColor = score >= 85
        ? AdvantaColors.success
        : score >= 60
            ? const Color(0xFFD4A017)
            : AdvantaColors.error;
    final district = fields.isNotEmpty ? fields.first.district : '';
    final subDistrict = fields.isNotEmpty ? fields.first.subDistrict : '';

    final letter = villageName.isNotEmpty ? villageName[0].toUpperCase() : '?';
    final avatarColors = [
      AdvantaColors.deepForest,
      AdvantaColors.midGreen,
      AdvantaColors.gold,
      AdvantaColors.error,
      AdvantaColors.lightGreen
    ];
    final avatarColor =
        avatarColors[villageName.hashCode.abs() % avatarColors.length];

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isExpanded
              ? Border.all(
                  color: AdvantaColors.deepForest.withValues(alpha: 0.3))
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: avatarColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text(letter,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(villageName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AdvantaColors.deepForest)),
                        Text(
                            [
                              if (subDistrict.isNotEmpty) subDistrict,
                              if (district.isNotEmpty) district
                            ].join(', '),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]))
                      ])),
                  Text('${score.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: scoreColor)),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[400])),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                    child: Wrap(spacing: 10, runSpacing: 5, children: [
                  _MicroStat(
                      label: _formatHa(totalArea),
                      icon: Icons.landscape_rounded,
                      color: AdvantaColors.mutedGrey),
                  _MicroStat(
                      label: '${fields.length} FN',
                      icon: Icons.grid_view_rounded,
                      color: AdvantaColors.lightGreen),
                  _MicroStat(
                      label: 'Overdue $overdueCount',
                      icon: Icons.warning_amber_rounded,
                      color:
                          overdueCount > 0 ? AdvantaColors.error : Colors.grey),
                ])),
                const SizedBox(width: 6),
                GestureDetector(
                    onTap: () => _showFieldList(context),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AdvantaColors.paleGreen,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Text('View Fields',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AdvantaColors.deepForest)))),
              ],
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey[100]),
            ...fields.map((f) => _FieldMiniRow(
                field: f,
                onTap: () => FieldDetailBottomSheet.show(context, f.raw))),
            const SizedBox(height: 6)
          ],
        ],
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MicroStat(
      {required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600))
      ]);
}

class _FieldMiniRow extends StatelessWidget {
  final FieldCoverageStatus field;
  final VoidCallback onTap;
  const _FieldMiniRow({required this.field, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dotColor = field.isOverdue
        ? AdvantaColors.error
        : field.hasActionRequired
            ? AdvantaColors.gold
            : field.coverageScore > 0
                ? AdvantaColors.success
                : Colors.grey[300]!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                    color: dotColor, borderRadius: BorderRadius.circular(999))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.fieldNumber,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AdvantaColors.charcoal,
                            fontWeight: FontWeight.w700)),
                    if (field.farmerName.isNotEmpty || field.hybrid.isNotEmpty)
                      Text(
                          [field.farmerName, field.hybrid]
                              .where((value) => value.isNotEmpty)
                              .join(' · '),
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Text(
                        '${field.activePhaseLabel} - ${field.activePhaseBadge}${field.latestAuditDate == null ? '' : ' - ${field.latestAuditDate}'}',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            Row(children: [
              _PhaseDot(
                done: field.vegetativeDone,
                partial: field.isPsp &&
                    !field.vegetativeDone &&
                    field.vegetativeAuditDoneCount > 0,
                label: 'V',
              ),
              _PhaseDot(done: field.anyGenerativeDone, label: 'G'),
              _PhaseDot(done: field.preHarvestDone, label: 'P'),
              _PhaseDot(done: field.harvestDone, label: 'H')
            ]),
            const SizedBox(width: 10),
            Text('DAP ${field.dap}',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey[300])
          ],
        ),
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  final bool done;
  final bool partial;
  final String label;
  const _PhaseDot({
    required this.done,
    required this.label,
    this.partial = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AdvantaColors.success
        : (partial ? const Color(0xFFFFA726) : Colors.grey[200]);
    return Container(
      margin: const EdgeInsets.only(right: 3),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: done || partial ? Colors.white : Colors.grey[400],
          ),
        ),
      ),
    );
  }
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
            Expanded(
                child: Text(
              'Rekomendasi Rute (Smart Route)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            )),
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
      final coordStr = f.raw['correction_tagging']?.toString() ??
          f.raw['coordinate']?.toString() ??
          '';
      return (f.coverageScore < 100 || f.hasActionRequired) &&
          coordStr.contains(',');
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
                  const Expanded(
                    child: AdvantaLoadingState.compact(
                      title: 'Mencari GPS',
                      subtitle: 'Mengurutkan rute terdekat',
                      icon: Icons.my_location_rounded,
                    ),
                  )
                else if (recommendedRoute.isEmpty)
                  _buildEmptyState()
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      itemCount: recommendedRoute.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildRouteCard(recommendedRoute[i], i),
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
    final coordStr = f.raw['correction_tagging']?.toString() ??
        f.raw['coordinate']?.toString() ??
        '';
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
    final farmerName = f.farmerName.isEmpty ? '-' : f.farmerName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: f.isOverdue
                ? AdvantaColors.error.withValues(alpha: 0.2)
                : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: AdvantaColors.deepForest, shape: BoxShape.circle),
            child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.fieldNumber,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AdvantaColors.deepForest),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${f.village} · ${f.hybrid.isEmpty ? '-' : f.hybrid} · ${f.activePhaseLabel} · DAP ${f.dap}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              farmerName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdvantaColors.deepForest),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(distanceLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdvantaColors.deepForest)),
              if (f.isOverdue)
                const Text('OVERDUE',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AdvantaColors.error)),
              if (!f.isOverdue && f.hasActionRequired)
                Text('ACT ${f.actionCode}',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AdvantaColors.gold)),
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
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
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
                decoration: BoxDecoration(
                    color: AdvantaColors.paleGreen,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.assistant_direction_rounded,
                    color: AdvantaColors.deepForest),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rekomendasi Rute Harian',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AdvantaColors.deepForest)),
                    SizedBox(height: 2),
                    Text('Prioritas: Overdue & Jarak Terdekat',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                icon: const Icon(Icons.map_rounded,
                    color: Colors.white, size: 20),
                label:
                    Text('Mulai Perjalanan (${recommendedRoute.length} Titik)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdvantaColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
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
            Text('Luar biasa!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdvantaColors.deepForest)),
            SizedBox(height: 8),
            Text(
                'Semua lahan prioritas sudah diaudit atau tidak ada lahan tertunda yang memiliki koordinat GPS valid.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  // LOGIKA MULTI-STOP GOOGLE MAPS
  Future<void> _openMultiStopMaps(
      BuildContext context, List<FieldCoverageStatus> routeFields) async {
    final coords = <String>[];

    // Kumpulkan koordinat yang valid
    for (final f in routeFields) {
      final coordStr = f.raw['correction_tagging']?.toString() ??
          f.raw['coordinate']?.toString() ??
          '';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak ada koordinat valid pada rute ini.')));
      return;
    }

    // Google Maps Multi-stop URL format:
    // https://www.google.com/maps/dir/?api=1&destination={titik_akhir}&waypoints={titik1}|{titik2}|{titik3}
    final destination = coords.last;
    final waypoints =
        coords.length > 1 ? coords.sublist(0, coords.length - 1).join('|') : '';

    var url = 'https://www.google.com/maps/dir/?api=1&destination=$destination';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=$waypoints';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membuka Google Maps.')));
      }
    }
  }
}

class _CoverageErrorWidget extends StatelessWidget {
  final String error;
  const _CoverageErrorWidget({required this.error});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 56, color: AdvantaColors.error),
                    const SizedBox(height: 16),
                    const Text('Gagal memuat data',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(error,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center)
                  ]))));
}

class _SkeletonLoader extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SkeletonLoader({
    this.title = 'Menyiapkan dashboard',
    this.subtitle = 'Menghitung target, achievement, dan coverage area',
    this.icon = Icons.analytics_rounded,
  });
  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      body: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => CustomScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _loadingHeader(context)),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                            child: AdvantaLoadingState(
                                title: widget.title,
                                subtitle: widget.subtitle,
                                icon: widget.icon,
                                accentColor: AdvantaColors.primaryGreen,
                                padding: EdgeInsets.zero))),
                    const SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                            child: Text('MENYIAPKAN RINGKASAN',
                                style: TextStyle(
                                    color: AdvantaColors.mutedGrey,
                                    fontSize: 10,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800)))),
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: 92,
                            child: ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: 3,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (_, index) => SizedBox(
                                    width: 116,
                                    child: _shimmerBox(height: 92))))),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _shimmerBox(height: 124))),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _shimmerBox(height: 190))),
                  ])));

  Widget _loadingHeader(BuildContext context) => Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AdvantaColors.deepForest, AdvantaColors.primaryGreen])),
      child: SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 18, 22),
              child: Row(children: [
                IconButton(
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white)),
                const SizedBox(width: 4),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Coverage Monitoring',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Sinkronisasi data audit lapangan',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))
                    ])),
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .2))),
                    child: const Icon(Icons.monitor_heart_rounded,
                        color: AdvantaColors.goldLight, size: 20))
              ]))));

  Widget _shimmerBox({required double height}) {
    final pulse = (math.sin(_ctrl.value * math.pi * 2) + 1) / 2;
    return Container(
        height: height,
        decoration: BoxDecoration(
            color: Color.lerp(Colors.white, AdvantaColors.paleGreen, pulse),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AdvantaColors.primaryGreen
                    .withValues(alpha: .08 + (pulse * .07))),
            boxShadow: [
              BoxShadow(
                  color: AdvantaColors.deepForest
                      .withValues(alpha: .035 + (pulse * .025)),
                  blurRadius: 18,
                  offset: const Offset(0, 8))
            ]),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 34,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AdvantaColors.primaryGreen
                          .withValues(alpha: .10 + (pulse * .08)),
                      borderRadius: BorderRadius.circular(20))),
              const Spacer(),
              Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                      color: AdvantaColors.deepForest
                          .withValues(alpha: .05 + (pulse * .04)),
                      borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 7),
              FractionallySizedBox(
                  widthFactor: .62,
                  child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: AdvantaColors.deepForest
                              .withValues(alpha: .04 + (pulse * .035)),
                          borderRadius: BorderRadius.circular(20))))
            ])));
  }
}

final _idWholeNumber = NumberFormat('#,##0', 'id_ID');
final _idDecimalNumber = NumberFormat('#,##0.0', 'id_ID');

String _formatHa(double ha) {
  final value = ha == ha.truncateToDouble()
      ? _idWholeNumber.format(ha)
      : _idDecimalNumber.format(ha);
  return '$value ha';
}

class _WeeklyCoverageControls extends ConsumerWidget {
  const _WeeklyCoverageControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(auditDashboardFilterProvider);
    final notifier = ref.read(auditDashboardFilterProvider.notifier);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AdvantaColors.dividerGrey)),
              child: Row(children: [
                for (final mode in CoverageDisplayMode.values)
                  Expanded(
                      child: ChoiceChip(
                    label: SizedBox(
                        width: double.infinity,
                        child: Text(
                            mode == CoverageDisplayMode.allCoverage
                                ? 'All Coverage'
                                : 'Target Audit',
                            textAlign: TextAlign.center)),
                    selected: filters.coverageMode == mode,
                    showCheckmark: false,
                    selectedColor: AdvantaColors.gold,
                    side: BorderSide.none,
                    onSelected: (_) => notifier.setCoverageMode(mode),
                  )),
              ])),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AuditWeekFilter(
                    selectedWeeks: filters.weeks,
                    allWeeks:
                        filters.coverageMode == CoverageDisplayMode.allCoverage,
                    onChanged: (weeks, all) {
                      notifier.setWeeks(weeks, all: all);
                      notifier.setCoverageMode(all
                          ? CoverageDisplayMode.allCoverage
                          : CoverageDisplayMode.targetAudit);
                    }),
                AuditFlagFilter(
                    selected: filters.flags, onChanged: notifier.setFlags),
                TextButton.icon(
                    icon: const Icon(Icons.event_note_rounded, size: 18),
                    label: const Text('Planning Semua Fase'),
                    onPressed: () => context.push(
                        '/audit-planning?weekStart=${Uri.encodeComponent(filters.primaryWeek.toIso8601String())}')),
              ]),
        ]));
  }
}

void _showWeeklyFields(
    BuildContext context, String title, List<WeeklyAuditField> fields,
    {VoidCallback? onChanged}) {
  showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WeeklyFieldSelectionSheet(
          title: title, fields: fields, onChanged: onChanged));
}

class _WeeklyFieldSelectionSheet extends StatefulWidget {
  final String title;
  final List<WeeklyAuditField> fields;
  final VoidCallback? onChanged;

  const _WeeklyFieldSelectionSheet(
      {required this.title, required this.fields, this.onChanged});

  @override
  State<_WeeklyFieldSelectionSheet> createState() =>
      _WeeklyFieldSelectionSheetState();
}

class _WeeklyFieldSelectionSheetState
    extends State<_WeeklyFieldSelectionSheet> {
  final Set<String> _selected = {};
  String _status = 'All';
  String _search = '';

  List<WeeklyAuditField> get _visible => widget.fields.where((field) {
        if (_status == 'Pending' && field.done) return false;
        if (_status == 'Completed' && !field.done) return false;
        if (_status == 'Overdue' && !field.overdue) return false;
        if (_search.isEmpty) return true;
        final haystack = [
          field.raw['field_number'],
          field.raw['farmer_name'],
          field.raw['village_desa'],
          field.raw['qa_fi'],
        ].join(' ').toLowerCase();
        return haystack.contains(_search);
      }).toList(growable: false);

  String _number(WeeklyAuditField field) =>
      field.raw['field_number']?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.title} · ${widget.fields.length} FN',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    TextField(
                        onChanged: (value) => setState(
                            () => _search = value.trim().toLowerCase()),
                        decoration: const InputDecoration(
                            isDense: true,
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Cari FN, petani, desa, atau FI')),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: ['All', 'Pending', 'Completed', 'Overdue']
                                .map((status) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                        label: Text(status),
                                        selected: _status == status,
                                        onSelected: (_) =>
                                            setState(() => _status = status))))
                                .toList())),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      TextButton(
                          onPressed: visible.isEmpty
                              ? null
                              : () => setState(() => _selected.addAll(visible
                                  .map(_number)
                                  .where((value) => value.isNotEmpty))),
                          child: Text('Select visible (${visible.length})')),
                      TextButton(
                          onPressed: widget.fields.isEmpty
                              ? null
                              : () => setState(() => _selected.addAll(widget
                                  .fields
                                  .map(_number)
                                  .where((value) => value.isNotEmpty))),
                          child: Text(
                              'Select all target (${widget.fields.length})')),
                      if (_selected.isNotEmpty)
                        TextButton(
                            onPressed: () => setState(_selected.clear),
                            child: const Text('Clear')),
                    ]),
                    if (_selected.isNotEmpty)
                      Row(children: [
                        Expanded(
                            child: Text('${_selected.length} FN selected',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))),
                        FilledButton.icon(
                            onPressed: _startMassInspection,
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Mass Inspection')),
                      ])
                  ])),
          const Divider(height: 1),
          if (visible.isEmpty)
            const Expanded(
                child: Center(child: Text('Tidak ada FN untuk filter ini.')))
          else
            Expanded(
                child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, index) {
                      final field = visible[index];
                      final number = _number(field);
                      final fi = field.raw['qa_fi']?.toString().trim() ?? '';
                      final farmer =
                          field.raw['farmer_name']?.toString().trim() ?? '';
                      final hybrid =
                          field.raw['hybrid']?.toString().trim() ?? '';
                      return CheckboxListTile(
                          value: _selected.contains(number),
                          onChanged: (checked) => setState(() {
                                checked == true
                                    ? _selected.add(number)
                                    : _selected.remove(number);
                              }),
                          title: Text([
                            number,
                            if (farmer.isNotEmpty) farmer,
                            if (hybrid.isNotEmpty) hybrid,
                          ].join(' · ')),
                          subtitle: Text(
                              '${field.village} · ${fi.isEmpty ? 'Unmapped / Need Mapping' : fi}\n${auditWorkload(field.areaHa, 1)} · ${field.flag} · ${field.done ? 'Completed' : field.overdue ? 'Overdue' : 'Pending'}'),
                          isThreeLine: true,
                          secondary: IconButton(
                              tooltip: 'Detail dan single inspection',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => FieldDetailBottomSheet.show(
                                  context, field.raw,
                                  dapReferenceDate: field.weekStart
                                      .add(const Duration(days: 6)),
                                  onInspectDone: (_) =>
                                      widget.onChanged?.call())));
                    })),
        ]));
  }

  Future<void> _startMassInspection() async {
    final selectedFields = widget.fields
        .where((field) => _selected.contains(_number(field)))
        .toList(growable: false);
    final phases = selectedFields
        .expand((field) => field.targets.map((target) => target.phase))
        .toSet()
        .toList()
      ..sort();
    if (widget.title.contains(auditNotYetFlagging) &&
        !phases.any((phase) => phase.startsWith('generative'))) {
      phases.add('generative_1');
    }
    if (phases.isEmpty) return;
    final phase = phases.length == 1
        ? phases.single
        : await showModalBottomSheet<String>(
            context: context,
            builder: (context) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const ListTile(
                      title: Text('Pilih fase Mass Inspection',
                          style: TextStyle(fontWeight: FontWeight.w900))),
                  ...phases.map((phase) => ListTile(
                      title: Text(phase.replaceAll('_', ' ').toUpperCase()),
                      onTap: () => Navigator.pop(context, phase))),
                ])));
    if (phase == null || !mounted) return;
    await context.push('/inspect/mass', extra: {
      'fieldNumbers': selectedFields.map(_number).toSet().toList(),
      'phase': phase,
    });
    widget.onChanged?.call();
  }
}
