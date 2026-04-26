// lib/screens/coverage/coverage_dashboard_screen.dart
//
// Coverage Dashboard — Konsep Role-Based (Manager / QA SPV / QA FI)
// Struktur:
//   Manager  → FI Rating (kiri) + Regional Structure (kanan, accordion)
//   QA SPV   → FI Rating tim (kiri) + Coverage Structure area (kanan)
//   QA FI    → Village Coverage List (full panel, operasional)
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/master_fields_provider.dart';
// ignore: unused_import
import '../../providers/filter_data_provider.dart';
import '../../utils/audit_status_helper.dart';
import '../../utils/dap_helper.dart';
import '../../utils/active_phase_filter.dart';
import '../../widgets/field_list_view.dart';
import '../../widgets/field_detail_bottom_sheet.dart';

// ============================================================
// THEME — Advanta Seeds Indonesia
// ============================================================
const _kBg      = Color(0xFFF0F4F8);
const _kCard    = Color(0xFFFFFFFF);
const _kCard2   = Color(0xFFEAF2FF);
const _kBorder  = Color(0xFFCBDAEE);
const _kGreen   = Color(0xFF2DB34A);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFEF4444);
const _kBlue    = Color(0xFF1B3D8F);
const _kBlueMid = Color(0xFF2E5FC2);
const _kPurple  = Color(0xFF7C3AED);
const _kTextPri = Color(0xFF0F1F3D);
const _kTextSec = Color(0xFF4A6280);
const _kTextDim = Color(0xFF94A9BF);

// ============================================================
// PHASE CONFIG
// ============================================================
class _PhaseConfig {
  final String label, key;
  final Color color;
  final IconData icon;
  final double targetPct;
  const _PhaseConfig({required this.label, required this.key,
    required this.color, required this.icon, required this.targetPct});
}

const _phaseVeg  = _PhaseConfig(label: 'Vegetative',   key: 'veg',  color: Color(0xFF78909C), icon: Icons.grass_rounded,                targetPct: 100);
const _phaseGen1 = _PhaseConfig(label: 'Generative 1', key: 'gen1', color: Color(0xFFFFCA28), icon: Icons.wb_sunny_rounded,             targetPct: 100);
const _phaseGen2 = _PhaseConfig(label: 'Generative 2', key: 'gen2', color: Color(0xFFFF7043), icon: Icons.local_fire_department_rounded, targetPct: 100);
const _phaseGen3 = _PhaseConfig(label: 'Generative 3', key: 'gen3', color: Color(0xFFE53935), icon: Icons.whatshot_rounded,             targetPct: 100);
const _phasePreh = _PhaseConfig(label: 'Pre-Harvest',  key: 'preh', color: Color(0xFF795548), icon: Icons.agriculture_rounded,          targetPct: 50);
const _phaseHarv = _PhaseConfig(label: 'Harvest',      key: 'harv', color: Color(0xFF43A047), icon: Icons.inventory_2_rounded,          targetPct: 50);
const _allPhases = [_phaseVeg, _phaseGen1, _phaseGen2, _phaseGen3, _phasePreh, _phaseHarv];

// ============================================================
// ROLE ENUM
// ============================================================
enum _Role { manager, qaSPV, qaFI }

extension _RoleExt on _Role {
  String get label {
    switch (this) {
      case _Role.manager: return 'Manager';
      case _Role.qaSPV:   return 'QA SPV';
      case _Role.qaFI:    return 'QA FI';
    }
  }
  IconData get icon {
    switch (this) {
      case _Role.manager: return Icons.business_center_rounded;
      case _Role.qaSPV:   return Icons.supervisor_account_rounded;
      case _Role.qaFI:    return Icons.person_pin_circle_rounded;
    }
  }
}

/// Derive _Role dari string role Supabase user.
/// DEV & ADMIN diperlakukan sama seperti MANAGER (bird-eye view).
_Role _roleFromUserRole(String? userRole) {
  switch ((userRole ?? '').toUpperCase()) {
    case 'MANAGER':
    case 'DEV':
    case 'ADMIN':
      return _Role.manager;
    case 'SPV':
      return _Role.qaSPV;
    case 'FI':
    default:
      return _Role.qaFI;
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final _coverageProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    Map<String, String?>>((ref, filters) async {
  final supabase = Supabase.instance.client;
  final all = <Map<String, dynamic>>[];
  const pageSize = 1000;
  int from = 0;
  try {
    while (true) {
      var q = supabase.from('coverage_dashboard_mat').select();
      PostgrestFilterBuilder fq = q;
      if (filters['region']   != null) fq = fq.eq('region',       filters['region']!);
      if (filters['district'] != null) fq = fq.eq('district_kab', filters['district']!);
      if (filters['qa_spv']   != null) fq = fq.eq('qa_spv',       filters['qa_spv']!);
      if (filters['qa_fi']    != null) fq = fq.ilike('qa_fi_list', '%${filters['qa_fi']!}%');
      final res = await fq.range(from, from + pageSize - 1);
      all.addAll(List<Map<String, dynamic>>.from(res));
      if (res.length < pageSize) break;
      from += pageSize;
    }
  } catch (e, st) {
    debugPrint('[Coverage] ERROR: $e\n$st');
    rethrow;
  }
  return all;
});

final _coverageFilterProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('coverage_dashboard_mat')
      .select('region, district_kab, qa_spv, qa_fi_list');
  return List<Map<String, dynamic>>.from(res);
});

// ============================================================
// SCREEN
// ============================================================
class CoverageDashboardScreen extends ConsumerStatefulWidget {
  const CoverageDashboardScreen({super.key});
  @override
  ConsumerState<CoverageDashboardScreen> createState() => _State();
}

class _State extends ConsumerState<CoverageDashboardScreen> {
  String? _region, _district, _qaSPV, _qaFI;
  bool    _sortAsc = true, _refreshing = false;
  late Map<String, String?> _filters;

  bool _isInitDefault = false;

  @override
  void initState() {
    super.initState();
    _filters = {'region': null, 'district': null, 'qa_spv': null, 'qa_fi': null};
  }

  void _updateFilters() => setState(() {
    _filters = {'region': _region, 'district': _district, 'qa_spv': _qaSPV, 'qa_fi': _qaFI};
  });

  Future<void> _doRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Supabase.instance.client.rpc('refresh_coverage_dashboard');
      ref.invalidate(_coverageProvider);
      ref.invalidate(_coverageFilterProvider);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _showOverdueDetails(WidgetRef ref) {
    final allFieldsAsync = ref.read(parsedMapFieldsProvider);
    allFieldsAsync.whenData((allFields) {
      final filteredByDashboard = allFields.where((f) {
        if (_region != null && f.raw['region'] != _region) return false;
        if (_district != null && f.raw['district_kab'] != _district) return false;
        if (_qaSPV != null && f.raw['qa_spv'] != _qaSPV) return false;
        if (_qaFI != null) {
          final fiList = f.raw['qa_fi_list']?.toString() ?? '';
          if (!fiList.contains(_qaFI!)) return false;
        }
        return true;
      });

      final overdueFields = filteredByDashboard.where((f) {
        final auditStatus = AuditStatusHelper.fromRaw(f.raw);
        final isNotAudited = auditStatus.vegetative != SingleAuditStatus.sampun;
        final isOverdueDap = f.dap > 35;
        return isNotAudited && isOverdueDap;
      }).toList();

      if (overdueFields.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada lahan yang terlewat (overdue)')),
        );
        return;
      }

      FieldListView.showSheet(
        context,
        fieldsData: overdueFields,
        userLocation: null,
        getMarkerColor: DapHelper.getDapMarkerColor,
        onUncoordBannerTap: (_) {},
        onNavigateTap: (lat, lng) {},
        activePhase: ActivePhaseView.vegetative,
        onFieldTap: (f) {
          Navigator.pop(context);
          FieldDetailBottomSheet.show(context, f.raw);
        },
        isMassMode: false,
        selectedFieldNumbers: {},
        onPhaseChanged: (phase) {},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Derive role dari user yang login
    final user = ref.watch(currentUserProvider).value;
    final role = _roleFromUserRole(user?.role);

    // 2. LOGIKA INISIALISASI DEFAULT (Hanya dijalankan 1x saat data user siap)
    if (!_isInitDefault && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (role == _Role.qaFI) {
              _region = user.region;
              _district = user.district;
            } else if (role == _Role.qaSPV) {
              _region = user.region;
            }
            _isInitDefault = true;
            _updateFilters();
          });
        }
      });
    }

    // Provider akan bereaksi terhadap _filters yang sudah diupdate
    final async      = ref.watch(_coverageProvider(_filters));
    final filterData = ref.watch(_coverageFilterProvider).when(
        data: (v) => v,
        loading: () => <Map<String, dynamic>>[],
        error: (_, __) => <Map<String, dynamic>>[]);

    // 3. WATERFALL FILTER OPTIONS (Kuncian area dihapus agar dropdown bebas dipilih)
    var regions = filterData
        .map((e) => e['region']?.toString() ?? '')
        .where((e) => e.isNotEmpty).toSet().toList()..sort();

    var districts = filterData
        .where((e) => _region == null || e['region'] == _region)
        .map((e) => e['district_kab']?.toString() ?? '')
        .where((e) => e.isNotEmpty).toSet().toList()..sort();

    final qaSPVs = filterData
        .where((e) => _region == null || e['region'] == _region)
        .where((e) => _district == null || e['district_kab'] == _district)
        .map((e) => e['qa_spv']?.toString() ?? '')
        .where((e) => e.isNotEmpty).toSet().toList()..sort();

    final rawFIs = filterData
        .where((e) => _region == null || e['region'] == _region)
        .where((e) => _district == null || e['district_kab'] == _district)
        .where((e) => _qaSPV == null || e['qa_spv'] == _qaSPV)
        .map((e) => e['qa_fi_list']?.toString() ?? '');
    final fiSet = <String>{};
    for (final raw in rawFIs) {
      for (final fi in raw.split(',')) {
        final t = fi.trim();
        if (t.isNotEmpty) fiSet.add(t);
      }
    }
    final qaFIs = fiSet.toList()..sort();

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _AppBar(
          async: async, sortAsc: _sortAsc, refreshing: _refreshing, role: role,
          onSort: () => setState(() => _sortAsc = !_sortAsc),
          onRefresh: _doRefresh,
        ),
        _FilterStrip(
          region: _region, district: _district, qaSPV: _qaSPV, qaFI: _qaFI,
          regions: regions, districts: districts, qaSPVs: qaSPVs, qaFIs: qaFIs,
          role: role,
          onRegion:  (v) { _region = v; _district = null; _qaSPV = null; _qaFI = null; _updateFilters(); },
          onDistrict:(v) { _district = v; _qaSPV = null; _qaFI = null; _updateFilters(); },
          onQASPV:   (v) { _qaSPV = v; _qaFI = null; _updateFilters(); },
          onQAFI:    (v) { _qaFI = v; _updateFilters(); },
          onReset:   () { _region = null; _district = null; _qaSPV = null; _qaFI = null; _updateFilters(); },
        ),
        Expanded(child: async.when(
          data: (raw) {
            if (raw.isEmpty) return const _Empty();
            final data = _sort(raw);
            return _RoleView(
              role: role,
              data: data,
              sortAsc: _sortAsc,
              onOverdueTap: () => _showOverdueDetails(ref),
            );
          },
          loading: () => const _Loading(),
          error: (e, _) => _Error(msg: e.toString(), onRetry: () => ref.invalidate(_coverageProvider)),
        )),
      ]),
    );
  }

  List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> raw) {
    final list = [...raw];
    list.sort((a, b) {
      final av = a['qa_spv']?.toString() ?? '';
      final bv = b['qa_spv']?.toString() ?? '';
      return _sortAsc ? av.compareTo(bv) : bv.compareTo(av);
    });
    return list;
  }
}

// ============================================================
// ROLE-BASED VIEW DISPATCHER
// ============================================================
class _RoleView extends StatelessWidget {
  final _Role role;
  final List<Map<String, dynamic>> data;
  final bool sortAsc;
  final VoidCallback onOverdueTap;
  const _RoleView({required this.role, required this.data, required this.sortAsc, required this.onOverdueTap});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case _Role.manager:
        return _ManagerView(data: data, onOverdueTap: onOverdueTap);
      case _Role.qaSPV:
        return _QaSPVView(data: data, onOverdueTap: onOverdueTap);
      case _Role.qaFI:
      // --- UBAH BARIS INI ---
        return _QaFiVillageList(data: data);
    // ----------------------
    }
  }
}

// ============================================================
// MANAGER VIEW  — Split: FI Rating (kiri) + Regional Structure (kanan)
// Layout: karena mobile = Tab (kiri/kanan), bukan side-by-side split
// ============================================================
class _ManagerView extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final VoidCallback onOverdueTap;
  const _ManagerView({required this.data, required this.onOverdueTap});

  @override
  State<_ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends State<_ManagerView> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Aggregate per FI for FI Rating panel
    final fiRating = _buildFiRating(widget.data);
    // Aggregate per region for Regional Structure panel
    final regionData = _buildRegionData(widget.data);

    return Column(children: [
      _SummaryBar(data: widget.data, onOverdueTap: widget.onOverdueTap),
      Container(
        color: _kCard,
        child: TabBar(
          controller: _tab,
          indicatorColor: _kGreen,
          labelColor: _kGreen,
          unselectedLabelColor: _kTextSec,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'FI Rating'),
            Tab(icon: Icon(Icons.account_tree_rounded, size: 16), text: 'Regional Structure'),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _tab, children: [
        // Tab 1: FI Rating
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _PanelHeader(
            icon: Icons.bar_chart_rounded, title: 'FI Rating',
            subtitle: '${fiRating.length} QA FI aktif',
          )),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.separated(
              itemCount: fiRating.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _FiRatingCard(rank: i + 1, item: fiRating[i]),
            ),
          ),
        ]),
        // Tab 2: Regional Structure
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _PanelHeader(
            icon: Icons.account_tree_rounded, title: 'Regional Structure',
            subtitle: '${regionData.length} region',
          )),
          SliverToBoxAdapter(child: _TargetLegend()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.separated(
              itemCount: regionData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _RegionAccordionCard(region: regionData[i]),
            ),
          ),
        ]),
      ])),
    ]);
  }

  /// Build FI rating list: flatten qa_fi_list per row, aggregate per FI
  List<Map<String, dynamic>> _buildFiRating(List<Map<String, dynamic>> data) {
    final fiMap = <String, Map<String, dynamic>>{};
    for (final d in data) {
      final fiRaw = d['qa_fi_list']?.toString() ?? '';
      final fiList = fiRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final fi in fiList) {
        final existing = fiMap.putIfAbsent(fi, () => {
          'fi_name': fi,
          'region': d['region'] ?? '',
          'qa_spv': d['qa_spv'] ?? '',
          'total_fields': 0,
          'total_ha': 0.0,
          'veg_actual': 0, 'veg_target': 0,
          'gen1_actual': 0, 'gen1_target': 0,
          'preh_actual': 0, 'preh_target': 0,
          'harv_actual': 0, 'harv_target': 0,
          'veg_overdue': 0,
        });
        // Distribute evenly if multiple FI in a row
        final fiCount = fiList.length.clamp(1, 999);
        existing['total_fields'] = (existing['total_fields'] as int) + (_toInt(d['total_fields']) ~/ fiCount);
        existing['total_ha']     = (existing['total_ha'] as double) + (_toDouble(d['total_ha']) / fiCount);
        existing['veg_actual']   = (existing['veg_actual'] as int) + (_toInt(d['veg_actual']) ~/ fiCount);
        existing['veg_target']   = (existing['veg_target'] as int) + (_toInt(d['veg_target']) ~/ fiCount);
        existing['gen1_actual']  = (existing['gen1_actual'] as int) + (_toInt(d['gen1_actual']) ~/ fiCount);
        existing['gen1_target']  = (existing['gen1_target'] as int) + (_toInt(d['gen1_target']) ~/ fiCount);
        existing['preh_actual']  = (existing['preh_actual'] as int) + (_toInt(d['preh_actual']) ~/ fiCount);
        existing['preh_target']  = (existing['preh_target'] as int) + (_toInt(d['preh_target']) ~/ fiCount);
        existing['harv_actual']  = (existing['harv_actual'] as int) + (_toInt(d['harv_actual']) ~/ fiCount);
        existing['harv_target']  = (existing['harv_target'] as int) + (_toInt(d['harv_target']) ~/ fiCount);
        existing['veg_overdue']  = (existing['veg_overdue'] as int) + (_toInt(d['veg_overdue']) ~/ fiCount);
      }
    }
    // Compute coverage % per FI and sort best → worst
    final list = fiMap.values.toList();
    for (final fi in list) {
      double s = 0; int c = 0;
      for (final key in ['veg', 'gen1', 'preh', 'harv']) {
        final tgt = fi['${key}_target'] as int;
        final act = fi['${key}_actual'] as int;
        if (tgt > 0) { s += (act / tgt) * 100; c++; }
      }
      fi['coverage_pct'] = c > 0 ? s / c : 0.0;
    }
    list.sort((a, b) => (b['coverage_pct'] as double).compareTo(a['coverage_pct'] as double));
    return list;
  }

  /// Aggregate per region from raw MV rows
  List<Map<String, dynamic>> _buildRegionData(List<Map<String, dynamic>> data) {
    final regionMap = <String, Map<String, dynamic>>{};
    for (final d in data) {
      final region = d['region']?.toString() ?? 'Unknown';
      final r = regionMap.putIfAbsent(region, () => {
        'region': region,
        'spv_set': <String>{},
        'total_fields': 0, 'total_ha': 0.0,
        'veg_actual': 0, 'veg_target': 0,
        'gen1_actual': 0, 'gen1_target': 0,
        'gen_actual': 0, 'gen_target': 0,
        'preh_actual': 0, 'preh_target': 0,
        'harv_actual': 0, 'harv_target': 0,
        'veg_overdue': 0,
        'rows': <Map<String, dynamic>>[],
      });
      (r['spv_set'] as Set<String>).add(d['qa_spv']?.toString() ?? '');
      r['total_fields'] = (r['total_fields'] as int) + _toInt(d['total_fields']);
      r['total_ha']     = (r['total_ha'] as double) + _toDouble(d['total_ha']);
      r['veg_actual']   = (r['veg_actual'] as int) + _toInt(d['veg_actual']);
      r['veg_target']   = (r['veg_target'] as int) + _toInt(d['veg_target']);
      r['gen1_actual']  = (r['gen1_actual'] as int) + _toInt(d['gen1_actual']);
      r['gen1_target']  = (r['gen1_target'] as int) + _toInt(d['gen1_target']);
      r['gen_actual']   = (r['gen_actual'] as int) + _toInt(d['gen_actual']);
      r['gen_target']   = (r['gen_target'] as int) + _toInt(d['gen_target']);
      r['preh_actual']  = (r['preh_actual'] as int) + _toInt(d['preh_actual']);
      r['preh_target']  = (r['preh_target'] as int) + _toInt(d['preh_target']);
      r['harv_actual']  = (r['harv_actual'] as int) + _toInt(d['harv_actual']);
      r['harv_target']  = (r['harv_target'] as int) + _toInt(d['harv_target']);
      r['veg_overdue']  = (r['veg_overdue'] as int) + _toInt(d['veg_overdue']);
      (r['rows'] as List<Map<String, dynamic>>).add(d);
    }
    return regionMap.values.toList()..sort((a, b) => (a['region'] as String).compareTo(b['region'] as String));
  }
}

// ============================================================
// QA SPV VIEW — FI Rating tim (tab) + Coverage Structure area
// ============================================================
class _QaSPVView extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final VoidCallback onOverdueTap;
  const _QaSPVView({required this.data, required this.onOverdueTap});

  @override
  State<_QaSPVView> createState() => _QaSPVViewState();
}

class _QaSPVViewState extends State<_QaSPVView> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // SPV needs: on track vs needs attention stats
    int onTrack = 0, needsAttention = 0, spvCount = 0;
    final spvSeen = <String>{};
    for (final d in widget.data) {
      final spv = d['qa_spv']?.toString() ?? '';
      if (spv.isNotEmpty && !spvSeen.contains(spv)) {
        spvSeen.add(spv);
        spvCount++;
        // Simple heuristic: avg coverage >= 70% = on track
        double s = 0; int c = 0;
        for (final key in ['veg', 'gen', 'preh', 'harv']) {
          final pct = _toDouble(d['${key}_percent']);
          if (_toInt(d['${key}_target']) > 0) { s += pct; c++; }
        }
        final avg = c > 0 ? s / c : 0.0;
        if (avg >= 70) {
          onTrack++;
        } else {
          needsAttention++;
        }
      }
    }

    // Sort rows by coverage ascending (needs attention first for SPV)
    final sortedData = [...widget.data];
    sortedData.sort((a, b) {
      double avgA = _rowAvg(a), avgB = _rowAvg(b);
      return avgA.compareTo(avgB); // lowest coverage first
    });

    // Aggregate per kabupaten for coverage structure
    final kabData = _buildKabData(widget.data);

    return Column(children: [
      // Header stats strip
      Container(
        color: _kCard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          _StatPill(label: 'QA SPV', value: '$spvCount', icon: Icons.people_alt_rounded, color: _kBlue),
          const SizedBox(width: 8),
          _StatPill(label: 'On Track', value: '$onTrack', icon: Icons.check_circle_rounded, color: _kGreen),
          const SizedBox(width: 8),
          _StatPill(label: 'Needs Attention', value: '$needsAttention', icon: Icons.warning_amber_rounded,
              color: needsAttention > 0 ? _kRed : _kGreen),
        ]),
      ),
      Container(
        color: _kCard,
        child: TabBar(
          controller: _tab,
          indicatorColor: _kPurple,
          labelColor: _kPurple,
          unselectedLabelColor: _kTextSec,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Rating Tim FI'),
            Tab(icon: Icon(Icons.map_rounded, size: 16), text: 'Coverage Area'),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _tab, children: [
        // Tab 1: FI Rating (sorted by coverage asc = bawah dulu untuk SPV follow-up)
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _PanelHeader(
            icon: Icons.bar_chart_rounded, title: 'Rating FI Tim',
            subtitle: 'Terendah tampil paling atas',
          )),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.separated(
              itemCount: sortedData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _CoverageCard(item: sortedData[i]),
            ),
          ),
        ]),
        // Tab 2: Coverage per Kabupaten
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _PanelHeader(
            icon: Icons.map_rounded, title: 'Coverage Area',
            subtitle: '${kabData.length} kabupaten',
          )),
          SliverToBoxAdapter(child: _TargetLegend()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.separated(
              itemCount: kabData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _KabCard(item: kabData[i]),
            ),
          ),
        ]),
      ])),
    ]);
  }

  double _rowAvg(Map<String, dynamic> d) {
    double s = 0; int c = 0;
    for (final key in ['veg', 'gen', 'preh', 'harv']) {
      if (_toInt(d['${key}_target']) > 0) { s += _toDouble(d['${key}_percent']); c++; }
    }
    return c > 0 ? s / c : 0.0;
  }

  List<Map<String, dynamic>> _buildKabData(List<Map<String, dynamic>> data) {
    final map = <String, Map<String, dynamic>>{};
    for (final d in data) {
      final kab = d['district_kab']?.toString() ?? 'Unknown';
      final r = map.putIfAbsent(kab, () => {
        'district_kab': kab,
        'region': d['region'] ?? '',
        'total_fields': 0, 'total_ha': 0.0,
        'veg_actual': 0, 'veg_target': 0,
        'gen1_actual': 0, 'gen1_target': 0,
        'preh_actual': 0, 'preh_target': 0,
        'harv_actual': 0, 'harv_target': 0,
        'veg_overdue': 0,
      });
      r['total_fields'] = (r['total_fields'] as int) + _toInt(d['total_fields']);
      r['total_ha']     = (r['total_ha'] as double) + _toDouble(d['total_ha']);
      r['veg_actual']   = (r['veg_actual'] as int) + _toInt(d['veg_actual']);
      r['veg_target']   = (r['veg_target'] as int) + _toInt(d['veg_target']);
      r['gen1_actual']  = (r['gen1_actual'] as int) + _toInt(d['gen1_actual']);
      r['gen1_target']  = (r['gen1_target'] as int) + _toInt(d['gen1_target']);
      r['preh_actual']  = (r['preh_actual'] as int) + _toInt(d['preh_actual']);
      r['preh_target']  = (r['preh_target'] as int) + _toInt(d['preh_target']);
      r['harv_actual']  = (r['harv_actual'] as int) + _toInt(d['harv_actual']);
      r['harv_target']  = (r['harv_target'] as int) + _toInt(d['harv_target']);
      r['veg_overdue']  = (r['veg_overdue'] as int) + _toInt(d['veg_overdue']);
    }
    return map.values.toList()..sort((a, b) => (a['district_kab'] as String).compareTo(b['district_kab'] as String));
  }
}

// ============================================================
// APP BAR
// ============================================================
class _AppBar extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> async;
  final bool sortAsc, refreshing;
  final _Role role;
  final VoidCallback onSort, onRefresh;

  const _AppBar({required this.async, required this.sortAsc, required this.refreshing,
    required this.role, required this.onSort, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1B3D8F), Color(0xFF2E5FC2)],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        boxShadow: [BoxShadow(color: Color(0x331B3D8F), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
        child: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
              child: const Icon(Icons.area_chart_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Coverage Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            async.when(
              data: (d) {
                final spvs = d.map((r) => r['qa_spv']?.toString() ?? '').toSet();
                return Text('${spvs.length} QA SPV · ${d.length} baris',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11));
              },
              loading: () => Text('Memuat...', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ]),
          const Spacer(),
          // Role indicator — read-only badge, bukan switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(role.icon, color: Colors.white.withValues(alpha: 0.85), size: 12),
              const SizedBox(width: 4),
              Text(role.label, style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 4),
          _IconBtn(icon: sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              tooltip: 'Urutkan', onTap: onSort, light: true),
          _IconBtn(icon: refreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
              tooltip: 'Sync & Refresh', onTap: onRefresh, light: true),
        ]),
      )),
    );
  }
}

// ============================================================
// FILTER STRIP
// ============================================================
class _FilterStrip extends StatelessWidget {
  final String? region, district, qaSPV, qaFI;
  final List<String> regions, districts, qaSPVs, qaFIs;
  final _Role role;
  final ValueChanged<String?> onRegion, onDistrict, onQASPV, onQAFI;
  final VoidCallback onReset;

  const _FilterStrip({
    required this.region, required this.district, required this.qaSPV, required this.qaFI,
    required this.regions, required this.districts, required this.qaSPVs, required this.qaFIs,
    required this.role,
    required this.onRegion, required this.onDistrict, required this.onQASPV, required this.onQAFI,
    required this.onReset,
  });

  bool get _hasFilter => region != null || district != null || qaSPV != null || qaFI != null;

  @override
  Widget build(BuildContext context) {
    // QA FI only sees region + district; SPV sees + QA SPV; Manager sees all
    final showSPV = role == _Role.manager || role == _Role.qaSPV;
    final showFI  = role == _Role.manager || role == _Role.qaSPV;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(bottom: BorderSide(color: _kBorder)),
        boxShadow: [BoxShadow(color: Color(0x0A1B3D8F), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _FilterDrop(
            hint: 'Semua Region',
            value: region,
            items: regions,
            icon: Icons.map_outlined,
            onChanged: onRegion,
            enabled: true, // <-- BUKA KUNCIAN UNTUK SEMUA ROLE
          )),
          const SizedBox(width: 6),
          Expanded(child: _FilterDrop(
            hint: 'Semua Kabupaten',
            value: district,
            items: districts,
            icon: Icons.location_city_outlined,
            onChanged: onDistrict,
            enabled: true, // <-- BUKA KUNCIAN UNTUK SEMUA ROLE
          )),

          // <-- TOMBOL RESET SEKARANG MUNCUL UNTUK SEMUA ROLE JIKA ADA FILTER AKTIF
          if (_hasFilter) ...[
            const SizedBox(width: 6),
            GestureDetector(onTap: onReset,
                child: Container(width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kRed.withValues(alpha: 0.3))),
                    child: const Icon(Icons.close_rounded, color: _kRed, size: 16))),
          ],
        ]),
        if (showSPV || showFI) ...[
          const SizedBox(height: 6),
          Row(children: [
            if (showSPV) Expanded(child: _FilterDrop(hint: 'Semua QA SPV', value: qaSPV, items: qaSPVs, icon: Icons.manage_accounts_outlined, onChanged: onQASPV)),
            if (showSPV && showFI) const SizedBox(width: 6),
            if (showFI) Expanded(child: _FilterDrop(hint: 'Semua QA FI',  value: qaFI,  items: qaFIs,  icon: Icons.person_outline_rounded,   onChanged: onQAFI)),
          ]),
        ],
      ]),
    );
  }
}

// ============================================================
// SUMMARY BAR (used by Manager view)
// ============================================================
class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final VoidCallback onOverdueTap;
  const _SummaryBar({required this.data, required this.onOverdueTap});

  @override
  Widget build(BuildContext context) {
    final spvSeen = <String>{};
    int totalFields = 0, overdue = 0;
    double totalHa = 0;
    int vegTgt = 0, vegAct = 0, gen1Tgt = 0, gen1Act = 0, prehTgt = 0, prehAct = 0, harvTgt = 0, harvAct = 0;
    double vegSum = 0, gen1Sum = 0, prehSum = 0, harvSum = 0;
    int    vegCnt = 0, gen1Cnt = 0, prehCnt = 0, harvCnt = 0;

    for (final d in data) {
      totalFields += _toInt(d['total_fields']);
      totalHa     += _toDouble(d['total_ha']);
      overdue     += _toInt(d['veg_overdue']);
      vegTgt  += _toInt(d['veg_target']);   vegAct  += _toInt(d['veg_actual']);
      gen1Tgt += _toInt(d['gen1_target']);  gen1Act += _toInt(d['gen1_actual']);
      prehTgt += _toInt(d['preh_target']);  prehAct += _toInt(d['preh_actual']);
      harvTgt += _toInt(d['harv_target']);  harvAct += _toInt(d['harv_actual']);
      if (_toInt(d['veg_target'])  > 0) { vegSum  += _toDouble(d['veg_percent']);  vegCnt++;  }
      if (_toInt(d['gen1_target']) > 0) { gen1Sum += _toDouble(d['gen1_percent']); gen1Cnt++; }
      if (_toInt(d['preh_target']) > 0) { prehSum += _toDouble(d['preh_percent']); prehCnt++; }
      if (_toInt(d['harv_target']) > 0) { harvSum += _toDouble(d['harv_percent']); harvCnt++; }
      spvSeen.add(d['qa_spv']?.toString() ?? '');
    }

    final vegAvg  = vegCnt  > 0 ? vegSum  / vegCnt  : 0.0;
    final genAvg  = gen1Cnt > 0 ? gen1Sum / gen1Cnt : 0.0;
    final prehAvg = prehCnt > 0 ? prehSum / prehCnt : 0.0;
    final harvAvg = harvCnt > 0 ? harvSum / harvCnt : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(children: [
        Row(children: [
          _StatTile(label: 'Total Lahan', value: '$totalFields', sub: '${totalHa.toStringAsFixed(1)} ha',
              icon: Icons.grid_view_rounded, color: _kBlue),
          const SizedBox(width: 8),
          _StatTile(label: 'Overdue Veg', value: '$overdue',
              icon: Icons.warning_amber_rounded,
              color: overdue > 0 ? _kRed : _kGreen,
              onTap: overdue > 0 ? onOverdueTap : null),
          const SizedBox(width: 8),
          _StatTile(label: 'QA SPV', value: '${spvSeen.length}',
              icon: Icons.people_alt_rounded, color: _kAmber),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
            boxShadow: const [BoxShadow(color: Color(0x0A1B3D8F), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('PROGRESS COVERAGE',
                  style: TextStyle(color: _kTextDim, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kBorder)),
                child: const Text('actual / target', style: TextStyle(color: _kTextSec, fontSize: 9)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _GaugeTile(label: 'Veg\n100%',  pct: vegAvg,  actual: vegAct,  target: vegTgt,  color: _phaseVeg.color),
              _GaugeTile(label: 'Gen\nG-1 %', pct: genAvg,  actual: gen1Act, target: gen1Tgt, color: const Color(0xFFFF7043)),
              _GaugeTile(label: 'Pre-H\n50%', pct: prehAvg, actual: prehAct, target: prehTgt, color: _phasePreh.color),
              _GaugeTile(label: 'Harv\n50%',  pct: harvAvg, actual: harvAct, target: harvTgt, color: _phaseHarv.color),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================
// FI RATING CARD (Manager panel kiri)
// ============================================================
class _FiRatingCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  const _FiRatingCard({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final pct     = _toDouble(item['coverage_pct']);
    final overdue = _toInt(item['veg_overdue']);
    final color   = _coverColor(pct);

    // Status badge
    String statusLabel;
    Color  statusColor;
    if (pct >= 80) { statusLabel = 'On Track'; statusColor = _kGreen; }
    else if (pct >= 50) { statusLabel = 'Progress'; statusColor = _kAmber; }
    else { statusLabel = 'Perlu Perhatian'; statusColor = _kRed; }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D1B3D8F), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        // Rank
        Container(width: 28, height: 28,
            decoration: BoxDecoration(
              color: rank <= 3 ? _kAmber.withValues(alpha: 0.15) : _kBorder.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: Text('#$rank', style: TextStyle(
                color: rank <= 3 ? _kAmber : _kTextSec, fontSize: 11, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 10),
        _QAAvatar(name: item['fi_name']?.toString() ?? '?'),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['fi_name']?.toString() ?? '—',
              style: const TextStyle(color: _kTextPri, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            _Chip(icon: Icons.map_outlined, label: item['region']?.toString() ?? '—', color: _kBlue),
            const SizedBox(width: 6),
            _Chip(icon: Icons.manage_accounts_rounded, label: item['qa_spv']?.toString() ?? '—', color: _kPurple),
          ]),
          const SizedBox(height: 4),
          // Phase progress mini bar
          _PhaseMiniBar(item: item),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _Badge(value: '${pct.toStringAsFixed(0)}%', color: color),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
          if (overdue > 0) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: _kRed, size: 11),
              const SizedBox(width: 2),
              Text('$overdue overdue', style: const TextStyle(color: _kRed, fontSize: 9)),
            ]),
          ],
          const SizedBox(height: 3),
          Text('${_toInt(item['total_fields'])} lahan',
              style: const TextStyle(color: _kTextSec, fontSize: 10)),
          Text('${_toDouble(item['total_ha']).toStringAsFixed(1)} ha',
              style: const TextStyle(color: _kTextDim, fontSize: 9)),
        ]),
      ]),
    );
  }
}

// ============================================================
// PHASE MINI BAR (for FI Rating card)
// ============================================================
class _PhaseMiniBar extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PhaseMiniBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final phases = [
      ('V', _toInt(item['veg_actual']), _toInt(item['veg_target']), _phaseVeg.color),
      ('G', _toInt(item['gen1_actual']), _toInt(item['gen1_target']), _phaseGen1.color),
      ('P', _toInt(item['preh_actual']), _toInt(item['preh_target']), _phasePreh.color),
      ('H', _toInt(item['harv_actual']), _toInt(item['harv_target']), _phaseHarv.color),
    ];
    return Row(children: phases.map((p) {
      final tgt = p.$3;
      final act = p.$2;
      final pct = tgt > 0 ? (act / tgt).clamp(0.0, 1.0) : 0.0;
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(children: [
          ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(_coverColor(pct * 100)),
            ),
          ),
          const SizedBox(height: 2),
          Text(p.$1, style: TextStyle(color: p.$4.withValues(alpha: 0.7), fontSize: 7, fontWeight: FontWeight.w700)),
        ]),
      ));
    }).toList());
  }
}

// ============================================================
// REGION ACCORDION CARD (Manager Regional Structure panel)
// ============================================================
class _RegionAccordionCard extends StatefulWidget {
  final Map<String, dynamic> region;
  const _RegionAccordionCard({required this.region});

  @override
  State<_RegionAccordionCard> createState() => _RegionAccordionCardState();
}

class _RegionAccordionCardState extends State<_RegionAccordionCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.region;
    final spvSet = r['spv_set'] as Set<String>;
    final rows   = r['rows'] as List<Map<String, dynamic>>;
    final totalF = _toInt(r['total_fields']);
    final totalH = _toDouble(r['total_ha']);
    final overdue = _toInt(r['veg_overdue']);

    double s = 0; int c = 0;
    for (final key in ['veg', 'gen1', 'preh', 'harv']) {
      final tgt = _toInt(r['${key}_target']);
      final act = _toInt(r['${key}_actual']);
      if (tgt > 0) { s += (act / tgt) * 100; c++; }
    }
    final avg = c > 0 ? s / c : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D1B3D8F), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        InkWell(
          onTap: _toggle, borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1B3D8F), Color(0xFF2E5FC2)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map_rounded, color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['region']?.toString() ?? '—',
                    style: const TextStyle(color: _kTextPri, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Row(children: [
                  _Chip(icon: Icons.supervisor_account_rounded, label: '${spvSet.length} QA SPV', color: _kBlue),
                  const SizedBox(width: 6),
                  _Chip(icon: Icons.grid_view_rounded, label: '$totalF lahan', color: _kBlueMid),
                  const SizedBox(width: 6),
                  _Chip(icon: Icons.landscape_rounded, label: '${totalH.toStringAsFixed(1)} ha', color: _kTextSec),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _Badge(value: '${avg.toStringAsFixed(0)}%', color: _coverColor(avg)),
                if (overdue > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: _kRed, size: 11),
                    const SizedBox(width: 2),
                    Text('$overdue overdue', style: const TextStyle(color: _kRed, fontSize: 10)),
                  ]),
                ],
              ]),
              const SizedBox(width: 6),
              RotationTransition(turns: _rotate,
                  child: const Icon(Icons.expand_more_rounded, color: _kTextSec, size: 18)),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: Column(children: rows.map((row) => _SpvSubRow(item: row)).toList()),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// Sub-row per QA SPV inside region accordion
class _SpvSubRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _SpvSubRow({required this.item});

  @override
  Widget build(BuildContext context) {
    double s = 0; int c = 0;
    for (final key in ['veg', 'gen', 'preh', 'harv']) {
      if (_toInt(item['${key}_target']) > 0) { s += _toDouble(item['${key}_percent']); c++; }
    }
    final avg = c > 0 ? s / c : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder))),
      child: Row(children: [
        const SizedBox(width: 4),
        _QAAvatar(name: item['qa_spv']?.toString() ?? '?'),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['qa_spv']?.toString() ?? '—',
              style: const TextStyle(color: _kTextPri, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(children: [
            _Chip(icon: Icons.location_city_outlined, label: item['district_kab']?.toString() ?? '—', color: _kBlueMid),
            const SizedBox(width: 6),
            _Chip(icon: Icons.grid_view_rounded, label: '${_toInt(item['total_fields'])} lahan', color: _kTextSec),
          ]),
          const SizedBox(height: 6),
          _MiniStrip(item: item),
        ])),
        const SizedBox(width: 10),
        _Badge(value: '${avg.toStringAsFixed(0)}%', color: _coverColor(avg)),
      ]),
    );
  }
}

// ============================================================
// KABUPATEN CARD (QA SPV Coverage Area tab)
// ============================================================
class _KabCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _KabCard({required this.item});

  @override
  Widget build(BuildContext context) {
    double s = 0; int c = 0;
    for (final key in ['veg', 'gen1', 'preh', 'harv']) {
      final tgt = _toInt(item['${key}_target']);
      final act = _toInt(item['${key}_actual']);
      if (tgt > 0) { s += (act / tgt) * 100; c++; }
    }
    final avg = c > 0 ? s / c : 0.0;
    final overdue = _toInt(item['veg_overdue']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D1B3D8F), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['district_kab']?.toString() ?? '—',
                style: const TextStyle(color: _kTextPri, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              _Chip(icon: Icons.map_outlined, label: item['region']?.toString() ?? '—', color: _kBlue),
              const SizedBox(width: 6),
              _Chip(icon: Icons.grid_view_rounded, label: '${_toInt(item['total_fields'])} lahan', color: _kTextSec),
              const SizedBox(width: 6),
              _Chip(icon: Icons.landscape_rounded, label: '${_toDouble(item['total_ha']).toStringAsFixed(1)} ha', color: _kTextSec),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _Badge(value: '${avg.toStringAsFixed(0)}%', color: _coverColor(avg)),
            if (overdue > 0) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: _kRed, size: 11),
                const SizedBox(width: 2),
                Text('$overdue overdue', style: const TextStyle(color: _kRed, fontSize: 10)),
              ]),
            ],
          ]),
        ]),
        const SizedBox(height: 8),
        _MiniStrip(item: {
          'veg_percent':  _toInt(item['veg_target'])  > 0 ? (_toInt(item['veg_actual'])  / _toInt(item['veg_target']))  * 100 : 0.0,
          'gen_percent':  _toInt(item['gen1_target']) > 0 ? (_toInt(item['gen1_actual']) / _toInt(item['gen1_target'])) * 100 : 0.0,
          'preh_percent': _toInt(item['preh_target']) > 0 ? (_toInt(item['preh_actual']) / _toInt(item['preh_target'])) * 100 : 0.0,
          'harv_percent': _toInt(item['harv_target']) > 0 ? (_toInt(item['harv_actual']) / _toInt(item['harv_target'])) * 100 : 0.0,
        }),
      ]),
    );
  }
}

// ============================================================
// QA FI FIELD CARD (per baris MV — operasional)
// ============================================================
class _FiFieldCard extends StatefulWidget {
  final Map<String, dynamic> item;
  const _FiFieldCard({required this.item});

  @override
  State<_FiFieldCard> createState() => _FiFieldCardState();
}

class _FiFieldCardState extends State<_FiFieldCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double>   _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rotate = Tween<double>(begin: 0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final d       = widget.item;
    final overdue = _toInt(d['veg_overdue']);
    final totalFields = _toInt(d['total_fields']);
    final totalHa     = _toDouble(d['total_ha']);

    double sum = 0; int cnt = 0;
    for (final key in ['veg', 'gen', 'preh', 'harv']) {
      if (_toInt(d['${key}_target']) > 0) { sum += _toDouble(d['${key}_percent']); cnt++; }
    }
    final avg = cnt > 0 ? sum / cnt : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D1B3D8F), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(12),
          splashColor: _kGreen.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              _QAAvatar(name: d['qa_spv']?.toString() ?? '?'),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['qa_spv']?.toString() ?? '—',
                    style: const TextStyle(color: _kTextPri, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, children: [
                  _Chip(icon: Icons.map_outlined,        label: d['region']?.toString() ?? '—',       color: _kBlue),
                  _Chip(icon: Icons.location_on_rounded, label: d['district_kab']?.toString() ?? '—', color: _kBlueMid),
                  if ((d['qa_fi_list']?.toString() ?? '').isNotEmpty)
                    _Chip(icon: Icons.person_search_rounded,
                        label: d['qa_fi_list']!.toString().split(',').length == 1
                            ? d['qa_fi_list']!.toString().trim()
                            : '${d['qa_fi_list']!.toString().split(',').length} FI',
                        color: _kPurple),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _Badge(value: '${avg.toStringAsFixed(0)}%', color: _coverColor(avg)),
                const SizedBox(height: 4),
                Text('$totalFields lahan',
                    style: const TextStyle(color: _kTextSec, fontSize: 10, fontWeight: FontWeight.w600)),
                Text('${totalHa.toStringAsFixed(1)} ha',
                    style: const TextStyle(color: _kTextDim, fontSize: 10)),
                if (overdue > 0) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: _kRed, size: 11),
                    const SizedBox(width: 3),
                    Text('$overdue overdue', style: const TextStyle(color: _kRed, fontSize: 10)),
                  ]),
                ],
              ]),
              const SizedBox(width: 8),
              RotationTransition(turns: _rotate,
                  child: const Icon(Icons.expand_more_rounded, color: _kTextSec, size: 18)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: _MiniStrip(item: d)),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: _DetailTable(item: d),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ============================================================
// COVERAGE CARD (QA SPV rating tab — existing card, kept intact)
// ============================================================
class _CoverageCard extends StatefulWidget {
  final Map<String, dynamic> item;
  const _CoverageCard({required this.item});
  @override
  State<_CoverageCard> createState() => _CoverageCardState();
}

class _CoverageCardState extends State<_CoverageCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double>   _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rotate = Tween<double>(begin: 0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final d           = widget.item;
    final overdue     = _toInt(d['veg_overdue']);
    final totalFields = _toInt(d['total_fields']);
    final totalHa     = _toDouble(d['total_ha']);

    double sum = 0; int cnt = 0;
    for (final key in ['veg', 'gen', 'preh', 'harv']) {
      if (_toInt(d['${key}_target']) > 0) {
        sum += _toDouble(d['${key}_percent']);
        cnt++;
      }
    }
    final avg = cnt > 0 ? sum / cnt : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D1B3D8F), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(12),
          splashColor: _kGreen.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              _QAAvatar(name: d['qa_spv']?.toString() ?? '?'),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['qa_spv']?.toString() ?? '—',
                    style: const TextStyle(color: _kTextPri, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, children: [
                  _Chip(icon: Icons.map_outlined,        label: d['region']?.toString() ?? '—',       color: _kBlue),
                  _Chip(icon: Icons.location_on_rounded, label: d['district_kab']?.toString() ?? '—', color: _kBlueMid),
                  if ((d['qa_fi_list']?.toString() ?? '').isNotEmpty)
                    _Chip(icon: Icons.person_search_rounded,
                        label: d['qa_fi_list']!.toString().split(',').length == 1
                            ? d['qa_fi_list']!.toString().trim()
                            : '${d['qa_fi_list']!.toString().split(',').length} FI',
                        color: _kPurple),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _Badge(value: '${avg.toStringAsFixed(0)}%', color: _coverColor(avg)),
                const SizedBox(height: 4),
                Text('$totalFields lahan',
                    style: const TextStyle(color: _kTextSec, fontSize: 10, fontWeight: FontWeight.w600)),
                Text('${totalHa.toStringAsFixed(1)} ha',
                    style: const TextStyle(color: _kTextDim, fontSize: 10)),
                if (overdue > 0) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: _kRed, size: 11),
                    const SizedBox(width: 3),
                    Text('$overdue overdue', style: const TextStyle(color: _kRed, fontSize: 10)),
                  ]),
                ],
              ]),
              const SizedBox(width: 8),
              RotationTransition(turns: _rotate,
                  child: const Icon(Icons.expand_more_rounded, color: _kTextSec, size: 18)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: _MiniStrip(item: d)),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: _DetailTable(item: d),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ============================================================
// MINI STRIP
// ============================================================
class _MiniStrip extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MiniStrip({required this.item});

  @override
  Widget build(BuildContext context) {
    final cols = [
      ('VEG',  _toDouble(item['veg_percent']),  _phaseVeg.color),
      ('GEN',  _toDouble(item['gen_percent']),  const Color(0xFFFF7043)),
      ('PREH', _toDouble(item['preh_percent']), _phasePreh.color),
      ('HARV', _toDouble(item['harv_percent']), _phaseHarv.color),
    ];
    return Row(children: cols.map((c) {
      final pct = c.$2.clamp(0.0, 100.0);
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(children: [
          ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct / 100, minHeight: 5,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(_coverColor(pct)),
            ),
          ),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(c.$1, style: TextStyle(color: c.$3.withValues(alpha: 0.7), fontSize: 8, fontWeight: FontWeight.w600)),
            Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: _coverColor(pct), fontSize: 8, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ));
    }).toList());
  }
}

// ============================================================
// DETAIL TABLE (expand per card)
// ============================================================
class _DetailTable extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DetailTable({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TableHeader(),
        const SizedBox(height: 8),
        const Divider(color: _kBorder, height: 1),
        const SizedBox(height: 6),

        _PhaseRow(phase: _phaseVeg,
            target: _toInt(item['veg_target']), actual: _toInt(item['veg_actual']),
            eligible: _toInt(item['total_fields']), pct: _toDouble(item['veg_percent']),
            extra: _toInt(item['veg_overdue']) > 0 ? '${_toInt(item['veg_overdue'])} overdue' : null,
            extraColor: _kRed),

        _PhaseRow(phase: _phaseGen1,
            target: _toInt(item['gen1_target']), actual: _toInt(item['gen1_actual']),
            eligible: _toInt(item['gen_eligible']), pct: _toDouble(item['gen1_percent']),
            extra: 'audit ke-1', extraColor: _phaseGen1.color),
        _PhaseRow(phase: _phaseGen2,
            target: _toInt(item['gen2_target']), actual: _toInt(item['gen2_actual']),
            eligible: _toInt(item['gen_eligible']), pct: _toDouble(item['gen2_percent']),
            extra: 'audit ke-2', extraColor: _phaseGen2.color),
        _PhaseRow(phase: _phaseGen3,
            target: _toInt(item['gen3_target']), actual: _toInt(item['gen3_actual']),
            eligible: _toInt(item['gen_eligible']), pct: _toDouble(item['gen3_percent']),
            extra: 'audit ke-3', extraColor: _phaseGen3.color),

        _PhaseRow(phase: _phasePreh,
            target: _toInt(item['preh_target']), actual: _toInt(item['preh_actual']),
            eligible: _toInt(item['total_fields']), pct: _toDouble(item['preh_percent']),
            extra: 'sampling 50% dari total lahan', extraColor: _kTextSec),
        _PhaseRow(phase: _phaseHarv,
            target: _toInt(item['harv_target']), actual: _toInt(item['harv_actual']),
            eligible: _toInt(item['total_fields']), pct: _toDouble(item['harv_percent']),
            extra: 'sampling 50% dari total lahan', extraColor: _kTextSec),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Row(children: [
    Expanded(flex: 3, child: Text('FASE',    style: _hStyle)),
    SizedBox(width: 44, child: Text('ELIG.',  textAlign: TextAlign.right, style: _hStyle)),
    SizedBox(width: 44, child: Text('TARGET', textAlign: TextAlign.right, style: _hStyle)),
    SizedBox(width: 44, child: Text('AKTUAL', textAlign: TextAlign.right, style: _hStyle)),
    SizedBox(width: 52, child: Text('COVER',  textAlign: TextAlign.right, style: _hStyle)),
  ]);
  static const _hStyle = TextStyle(color: _kTextDim, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0);
}

class _PhaseRow extends StatelessWidget {
  final _PhaseConfig phase;
  final int target, actual, eligible;
  final double pct;
  final String? extra;
  final Color? extraColor;
  const _PhaseRow({required this.phase, required this.target, required this.actual,
    required this.eligible, required this.pct, this.extra, this.extraColor});

  @override
  Widget build(BuildContext context) {
    final p = pct.clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(phase.icon, color: phase.color, size: 12),
            const SizedBox(width: 5),
            Text(phase.label, style: const TextStyle(color: _kTextPri, fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: p / 100, minHeight: 5,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(_coverColor(p)),
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 2),
            Text(extra!, style: TextStyle(color: extraColor ?? _kTextSec, fontSize: 8)),
          ],
        ])),
        const SizedBox(width: 6),
        SizedBox(width: 44, child: Text('$eligible', textAlign: TextAlign.right,
            style: const TextStyle(color: _kTextDim, fontSize: 11))),
        SizedBox(width: 44, child: Text('$target', textAlign: TextAlign.right,
            style: const TextStyle(color: _kTextSec, fontSize: 11))),
        SizedBox(width: 44, child: Text('$actual', textAlign: TextAlign.right,
            style: const TextStyle(color: _kTextPri, fontSize: 11, fontWeight: FontWeight.w600))),
        SizedBox(width: 52, child: Align(
          alignment: Alignment.centerRight,
          child: _Badge(value: '${p.toStringAsFixed(0)}%', color: _coverColor(p), small: true),
        )),
      ]),
    );
  }
}

// ============================================================
// TARGET LEGEND
// ============================================================
class _TargetLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
    child: Wrap(spacing: 6, runSpacing: 4, children: [
      for (final p in _allPhases)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: p.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: p.color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(p.icon, color: p.color, size: 10),
            const SizedBox(width: 4),
            Text('${p.label} — target ${p.targetPct.toInt()}%',
                style: TextStyle(color: p.color, fontSize: 9, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]),
  );
}

// ============================================================
// PANEL HEADER (section title for each view panel)
// ============================================================
class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _PanelHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    child: Row(children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder)),
          child: Icon(icon, color: _kBlue, size: 16)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _kTextPri, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(color: _kTextSec, fontSize: 10)),
      ]),
      const Spacer(),
    ]),
  );
}

// ============================================================
// STAT PILL (compact horizontal stat chip)
// ============================================================
class _StatPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: _kTextSec, fontSize: 9)),
        ]),
      ]),
    ),
  );
}

// ============================================================
// GAUGE TILE
// ============================================================
class _GaugeTile extends StatelessWidget {
  final String label;
  final double pct;
  final int actual, target;
  final Color color;
  const _GaugeTile({required this.label, required this.pct,
    required this.actual, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = _coverColor(pct);
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 58, height: 58,
            child: CircularProgressIndicator(
              value: (pct / 100).clamp(0, 1),
              strokeWidth: 6,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
          Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextSec, fontSize: 9, height: 1.4)),
        const SizedBox(height: 3),
        RichText(textAlign: TextAlign.center, text: TextSpan(
          children: [
            TextSpan(text: '$actual', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
            TextSpan(text: ' / $target', style: const TextStyle(color: _kTextDim, fontSize: 9)),
          ],
        )),
      ]),
    ));
  }
}

// ============================================================
// REUSABLE WIDGETS
// ============================================================
class _StatTile extends StatelessWidget {
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatTile({required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 16),
            if (onTap != null) Icon(Icons.open_in_new_rounded, color: color.withAlpha(100), size: 12),
          ]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          if (sub != null)
            Text(sub!, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _kTextSec, fontSize: 9)),
        ]),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String value;
  final Color  color;
  final bool   small;
  const _Badge({required this.value, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 5 : 8, vertical: small ? 2 : 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(5)),
    child: Text(value, style: TextStyle(
        color: color, fontSize: small ? 10 : 12, fontWeight: FontWeight.w800)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color.withValues(alpha: 0.7), size: 10),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(color: _kTextSec, fontSize: 10), overflow: TextOverflow.ellipsis),
  ]);
}

class _QAAvatar extends StatelessWidget {
  final String name;
  const _QAAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    const palette = [
      Color(0xFF1B3D8F), Color(0xFF2DB34A), Color(0xFF0D6B8E),
      Color(0xFF1E8035), Color(0xFF2E5FC2), Color(0xFF156B3A),
    ];
    final bg = palette[name.length % palette.length];
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.15), shape: BoxShape.circle,
          border: Border.all(color: bg.withValues(alpha: 0.4), width: 1.5)),
      child: Center(child: Text(initials,
          style: TextStyle(color: bg, fontSize: 13, fontWeight: FontWeight.w800))),
    );
  }
}

// ============================================================
// FILTER DROPDOWN
// ============================================================
class _FilterDrop extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final bool enabled; // <-- Tambahkan ini

  const _FilterDrop({
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.enabled = true, // Default true
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? () => _show(context) : null, // Matikan fungsi klik jika not enabled
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: !enabled ? _kBg : (value != null ? _kGreen.withValues(alpha: 0.08) : _kCard),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value != null ? _kGreen : _kBorder, width: value != null ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(icon, color: !enabled ? _kTextDim : (value != null ? _kGreen : _kTextSec), size: 13),
        const SizedBox(width: 6),
        Expanded(child: Text(value ?? hint,
            style: TextStyle(color: !enabled ? _kTextDim : (value != null ? _kGreen : _kTextSec),
                fontSize: 11, fontWeight: value != null ? FontWeight.w600 : FontWeight.normal))),
        if (enabled) // Sembunyikan tanda panah jika terkunci
          Icon(Icons.expand_more_rounded, color: value != null ? _kGreen : _kTextDim, size: 14),
      ]),
    ),
  );

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(title: hint, items: items, selected: value,
          onSelect: (v) { Navigator.pop(context); onChanged(v); }),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _PickerSheet({required this.title, required this.items,
    required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
        decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
    const SizedBox(height: 12),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
      Text(title, style: const TextStyle(color: _kTextPri, fontSize: 14, fontWeight: FontWeight.w700)),
      const Spacer(),
      if (selected != null)
        TextButton(onPressed: () => onSelect(null),
            child: const Text('Reset', style: TextStyle(color: _kRed, fontSize: 12, fontWeight: FontWeight.w600))),
    ])),
    const Divider(color: _kBorder, height: 1),
    ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(color: _kBorder, height: 1, indent: 16),
        itemBuilder: (_, i) {
          final active = selected == items[i];
          return InkWell(
            onTap: () => onSelect(items[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(children: [
                if (active) Container(width: 3, height: 16, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(2))),
                Expanded(child: Text(items[i], style: TextStyle(
                    color: active ? _kGreen : _kTextPri, fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal))),
                if (active) const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
              ]),
            ),
          );
        },
      ),
    ),
    SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
  ]);
}

// ============================================================
// UTILITY WIDGETS
// ============================================================
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool light;
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap, this.light = false});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 36, height: 36,
          child: Icon(icon, color: light ? Colors.white.withValues(alpha: 0.85) : _kTextSec, size: 20)),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.search_off_rounded, color: _kTextDim, size: 52),
      const SizedBox(height: 12),
      const Text('Tidak ada data ditemukan', style: TextStyle(color: _kTextSec, fontSize: 14)),
    ],
  ));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
      SizedBox(height: 14),
      Text('Memuat data coverage…', style: TextStyle(color: _kTextSec, fontSize: 13)),
    ],
  ));
}

class _Error extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _Error({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.cloud_off_rounded, color: _kRed, size: 48),
      const SizedBox(height: 12),
      const Text('Gagal memuat coverage',
          style: TextStyle(color: _kTextPri, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: _kTextSec, fontSize: 12)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Coba Lagi'),
        style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]),
  ));
}

// ============================================================
// HELPERS
// ============================================================
Color _coverColor(double pct) {
  if (pct >= 80) return _kGreen;
  if (pct >= 50) return _kAmber;
  return _kRed;
}

int    _toInt(dynamic v)    => (v is num) ? v.toInt()    : int.tryParse(v?.toString() ?? '') ?? 0;
double _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

// ============================================================\r
// WIDGET KHUSUS QA FI (VILLAGE COVERAGE LIST)
// ============================================================\r
class _QaFiVillageList extends ConsumerWidget {
  final List<Map<String, dynamic>> data;

  const _QaFiVillageList({required this.data});

  // Fungsi popup lahan dipindah ke dalam widget ini agar mandiri
  void _showVillageFields(BuildContext context, WidgetRef ref, String village) {
    final allFieldsAsync = ref.read(parsedMapFieldsProvider);

    allFieldsAsync.whenData((allFields) {

      // 1. Bersihkan nama desa dari spasi berlebih dan jadikan huruf kecil
      final targetVillage = village.trim().toLowerCase();

      final villageFields = allFields.where((f) {
        // 2. Ambil nama desa dari raw data, bersihkan juga spasinya
        final v = f.raw['village_desa']?.toString().trim().toLowerCase() ?? '';
        return v == targetVillage;
      }).toList();

      if (villageFields.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada lahan di desa: $village')), // Tambahkan nama desa biar ketahuan kalau error
        );
        return;
      }

      FieldListView.showSheet(
        context,
        fieldsData: villageFields,
        userLocation: null,
        getMarkerColor: DapHelper.getDapMarkerColor,
        onUncoordBannerTap: (_) {},
        onNavigateTap: (lat, lng) {},
        activePhase: ActivePhaseView.vegetative,
        onFieldTap: (f) {
          Navigator.pop(context);
          FieldDetailBottomSheet.show(context, f.raw);
        },
        isMassMode: false,
        selectedFieldNumbers: {},
        onPhaseChanged: (phase) {},
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Tidak ada data desa', style: TextStyle(color: _kTextSec)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (_, i) {
        final row = data[i];
        final village = row['village_desa']?.toString() ?? 'Desa Tidak Diketahui';
        final district = row['district_kab']?.toString() ?? '';

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            village.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _kTextPri,
                            ),
                          ),
                          Text(
                            'Kec. $district',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kTextSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showVillageFields(context, ref, village),
                      icon: const Icon(Icons.location_on_rounded, size: 14, color: _kBlueMid),
                      label: const Text(
                        'Lihat Lahan',
                        style: TextStyle(color: _kBlueMid, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: _kBlueMid.withAlpha(20),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  ]
              ),
              const SizedBox(height: 10),
              // Panggil DetailTable yang sudah ada
              _DetailTable(item: row),
            ]
        );
      },
    );
  }
}