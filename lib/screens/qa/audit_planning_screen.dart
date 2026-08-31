import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../models/audit_planning_filters.dart';
import '../../providers/audit_plan_provider.dart';
import '../../providers/audit_filter_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/dap_helper.dart';
import '../../utils/qa_name_helper.dart';
import '../../utils/weekly_audit.dart';
import '../../widgets/field_detail_bottom_sheet.dart';
import '../../widgets/weekly_audit_widgets.dart';

class AuditPlanningScreen extends ConsumerStatefulWidget {
  final DateTime? initialWeek;
  final AuditPlanningInitialFilters? initialFilters;
  const AuditPlanningScreen({
    super.key,
    this.initialWeek,
    this.initialFilters,
  });
  @override
  ConsumerState<AuditPlanningScreen> createState() =>
      _AuditPlanningScreenState();
}

class _AuditPlanningScreenState extends ConsumerState<AuditPlanningScreen> {
  late DateTime _week;
  late Set<DateTime> _weeks;
  late bool _allWeeks;
  String _phase = 'vegetative';
  String? _region;
  String? _district;
  String? _season;
  bool _showAllRegions = false;
  String _crop = 'All Crop';
  String _status = 'Pending';
  String _search = '';
  Set<String> _flags = {...defaultAuditFlags};
  List<AuditPlanningTextFilter> _textFilters = [];
  bool _showMap = false;
  int? _selectedWeekday;
  final Set<String> _selectedFieldNumbers = {};
  final Set<String> _expandedVillages = {};
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final shared = ref.read(auditDashboardFilterProvider);
    _week = auditWeekStart(widget.initialWeek ?? shared.primaryWeek);
    _weeks = widget.initialWeek == null ? {...shared.weeks} : {_week};
    _allWeeks = widget.initialWeek == null && shared.allWeeks;
    if (_weeks.isEmpty) _weeks = {_week};
    _region = shared.region;
    _district = shared.district;
    _showAllRegions = shared.region == null;
    _status = shared.status;
    _flags = {...shared.flags};
    final initial = widget.initialFilters;
    if (initial != null) {
      _showAllRegions = initial.allRegions;
      _region = initial.allRegions ? null : initial.region;
      _district = initial.allRegions ? null : initial.district;
      _season = initial.allSeasons ? null : initial.season;
      if (initial.phase != null &&
          auditPlanningPhases.contains(initial.phase)) {
        _phase = initial.phase!;
      }
      if (const {'All', 'Pending', 'Completed', 'Overdue'}
          .contains(initial.status)) {
        _status = initial.status!;
      }
      if (initial.showPld) _flags.add('PLD');
      _textFilters = initial.textFilters
          .where((filter) => filter.value.trim().isNotEmpty)
          .toList(growable: true);
    }
  }

  AuditPlanningParams _paramsFor(DateTime week) => (
        weekStart: week,
        region: _region,
        district: _district,
        season: _season,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      if (!_showAllRegions && _region == null) {
        ref.invalidate(auditPlanningRegionsProvider);
        await ref.read(auditPlanningRegionsProvider.future);
      } else {
        final scope = (
          region: _region,
          district: _district,
          season: _season,
        );
        ref.invalidate(auditPlanningIndexProvider(scope));
        for (final week in _weeks) {
          ref.invalidate(auditPlanningProvider(_paramsFor(week)));
        }
        await Future.wait(_weeks.map((week) =>
            ref.read(auditPlanningProvider(_paramsFor(week)).future)));
        ref.read(auditDashboardFilterProvider.notifier).markUpdated();
      }
    } catch (_) {
      // The provider renders the error and retry button; do not leave an
      // unhandled future from the refresh icon or pull-to-refresh gesture.
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(auditPlanningRegionsProvider);
    final regions = regionsAsync.value ?? const <String>[];
    final needsDefaultRegion =
        !_showAllRegions && _region == null && regions.isNotEmpty;
    if (needsDefaultRegion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showAllRegions || _region != null) return;
        setState(() => _region = regions.first);
      });
    }
    // Do not start an All Region fetch while the region list is still loading.
    final canLoadPlan = _showAllRegions || _region != null;
    final planParts = canLoadPlan
        ? _weeks
            .map((week) => ref.watch(auditPlanningProvider(_paramsFor(week))))
            .toList(growable: false)
        : const <AsyncValue<List<AuditPlanField>>>[];
    final AsyncValue<List<AuditPlanField>> plan = canLoadPlan
        ? planParts.any((part) => part.hasError)
            ? AsyncError(
                planParts.firstWhere((part) => part.hasError).error!,
                planParts.firstWhere((part) => part.hasError).stackTrace ??
                    StackTrace.current)
            : planParts.any((part) => part.isLoading)
                ? const AsyncLoading()
                : AsyncData(planParts
                    .expand((part) => part.value ?? const <AuditPlanField>[])
                    .toList(growable: false))
        : regionsAsync.when(
            loading: () => const AsyncLoading(),
            error: (error, stack) => AsyncError(error, stack),
            data: (_) => needsDefaultRegion
                ? const AsyncLoading()
                : const AsyncData([]));
    return Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      appBar: AppBar(
          title: const Text('Planning Audit'),
          backgroundColor: AdvantaColors.deepForest,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
                tooltip: 'Muat ulang',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded))
          ]),
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                _intro(),
                const SizedBox(height: 10),
                _phaseSelector(),
                const SizedBox(height: 8),
                _planningWeekControl(),
                const SizedBox(height: 10),
                _filterBar(regions),
                const SizedBox(height: 8),
                _searchBox(),
                const SizedBox(height: 10),
                plan.when(
                    loading: () => _loadingState(canLoadPlan),
                    error: (_, __) => _errorState(),
                    data: (all) => _content(all)),
              ])),
    );
  }

  Widget _intro() =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AdvantaColors.paleGreen,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.route_rounded,
                color: AdvantaColors.primaryGreen, size: 24)),
        const SizedBox(width: 12),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Target audit per desa',
              style: TextStyle(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AdvantaColors.deepForest)),
          SizedBox(height: 4),
          Text('Planning dari target DAP pada minggu terpilih.',
              style: TextStyle(
                  fontSize: 13, color: AdvantaColors.mutedGrey, height: 1.4)),
        ]))
      ]);

  Widget _phaseSelector() => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdvantaColors.dividerGrey),
          boxShadow: AdvantaShadows.card(false)),
      child: Row(
          children: auditPlanningPhases
              .map((phase) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                          label: SizedBox(
                              width: double.infinity,
                              child: Text(auditStageLabels[phase]!,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          selected: _phase == phase,
                          showCheckmark: false,
                          selectedColor: AdvantaColors.gold,
                          backgroundColor: Colors.transparent,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelStyle: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _phase == phase
                                  ? AdvantaColors.deepForest
                                  : AdvantaColors.mutedGrey),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() {
                                _phase = phase;
                                _selectedFieldNumbers.clear();
                              })),
                    ),
                  ))
              .toList()));

  Widget _planningWeekControl() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdvantaColors.dividerGrey)),
      child: Row(children: [
        IconButton(
            tooltip: 'Minggu sebelumnya',
            visualDensity: VisualDensity.compact,
            onPressed: () => _shiftPlanningWeeks(-7),
            icon: const Icon(Icons.chevron_left_rounded,
                color: AdvantaColors.primaryGreen)),
        Expanded(
            child: Center(
                child: AuditWeekFilter(
                    selectedWeeks: _weeks,
                    allWeeks: _allWeeks,
                    allLabel: 'All Weeks',
                    allDescription:
                        'Target 6 minggu sebelum dan sesudah week aktif',
                    onChanged: _setPlanningWeeks))),
        IconButton(
            tooltip: 'Minggu berikutnya',
            visualDensity: VisualDensity.compact,
            onPressed: () => _shiftPlanningWeeks(7),
            icon: const Icon(Icons.chevron_right_rounded,
                color: AdvantaColors.primaryGreen)),
      ]));

  void _setPlanningWeeks(Set<DateTime> weeks, bool all) {
    final selected = all
        ? List.generate(
            13, (index) => _week.add(Duration(days: (index - 6) * 7))).toSet()
        : weeks.map(auditWeekStart).toSet();
    if (selected.isEmpty) return;
    final sorted = selected.toList()..sort();
    setState(() {
      _weeks = selected;
      _allWeeks = all;
      _week = all ? auditWeekStart(_week) : sorted.last;
      _selectedFieldNumbers.clear();
    });
    ref
        .read(auditDashboardFilterProvider.notifier)
        .setWeeks(selected, all: all);
  }

  void _shiftPlanningWeeks(int days) {
    final shifted =
        _weeks.map((week) => week.add(Duration(days: days))).toSet();
    setState(() {
      _weeks = shifted;
      _week = _week.add(Duration(days: days));
      _selectedFieldNumbers.clear();
    });
    ref
        .read(auditDashboardFilterProvider.notifier)
        .setWeeks(shifted, all: _allWeeks);
  }

  bool get _hasActiveFilters =>
      _district != null ||
      _season != null ||
      _crop != 'All Crop' ||
      _status != 'All' ||
      !_flags.containsAll(defaultAuditFlags) ||
      _flags.length != defaultAuditFlags.length ||
      _textFilters.isNotEmpty ||
      _search.isNotEmpty;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _district = null;
      _season = null;
      _crop = 'All Crop';
      _status = 'All';
      _flags = {...defaultAuditFlags};
      _textFilters.clear();
      _search = '';
    });
    final notifier = ref.read(auditDashboardFilterProvider.notifier);
    notifier.setDistrict(null);
    notifier.setStatus('All');
    notifier.setFlags(defaultAuditFlags);
  }

  Widget _filterBar(List<String> regions) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Filter data',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AdvantaColors.deepForest)),
          const Spacer(),
          if (_hasActiveFilters)
            TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AdvantaColors.primaryGreen,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)))
        ]),
        const SizedBox(height: 7),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _filter(_showAllRegions ? 'All Region' : _region ?? 'Region',
              ['All Region', ...regions], Icons.location_on_outlined, (value) {
            _showAllRegions = value == 'All Region';
            _region = _showAllRegions ? null : value;
            _district = null;
            _expandedVillages.clear();
            ref.read(auditDashboardFilterProvider.notifier).setRegion(_region);
          }),
          if (_district != null)
            _removableFilter(Icons.location_city_outlined, _district!,
                () => _district = null),
          if (_season != null)
            _removableFilter(
                Icons.calendar_today_outlined, _season!, () => _season = null),
          _filter(_crop, const ['All Crop', 'FC', 'SC', 'PSP'],
              Icons.eco_outlined, (value) => _crop = value),
          _filter(_status, const ['All', 'Pending', 'Completed', 'Overdue'],
              Icons.task_alt_rounded, (value) {
            _status = value;
            ref.read(auditDashboardFilterProvider.notifier).setStatus(value);
          }),
          AuditFlagFilter(
              selected: _flags,
              onChanged: (flags) {
                setState(() => _flags = flags);
                ref.read(auditDashboardFilterProvider.notifier).setFlags(flags);
              }),
        ]),
        if (_textFilters.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _textFilters
                  .map((filter) => InputChip(
                      avatar: const Icon(Icons.manage_search_rounded,
                          size: 16, color: AdvantaColors.primaryGreen),
                      label: Text('${filter.label}: ${filter.value}'),
                      labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AdvantaColors.deepForest),
                      backgroundColor: AdvantaColors.paleGreen,
                      side: BorderSide.none,
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () =>
                          setState(() => _textFilters.remove(filter))))
                  .toList()),
        ],
      ]);

  Widget _removableFilter(IconData icon, String label, VoidCallback remove) =>
      InputChip(
          avatar: Icon(icon, size: 17, color: AdvantaColors.primaryGreen),
          label: Text(label),
          labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdvantaColors.deepForest),
          backgroundColor: AdvantaColors.paleGreen,
          side: BorderSide.none,
          deleteIcon: const Icon(Icons.close_rounded, size: 17),
          onDeleted: () => setState(remove));

  Widget _filter(String selected, List<String> options, IconData icon,
          ValueChanged<String> change) =>
      PopupMenuButton<String>(
          initialValue: selected,
          onSelected: (value) => setState(() => change(value)),
          color: Colors.white,
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (_) => options
              .map((value) => PopupMenuItem(value: value, child: Text(value)))
              .toList(),
          child: Chip(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              side: BorderSide(
                  color: AdvantaColors.deepForest.withValues(alpha: .16)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              avatar: Icon(icon, size: 17, color: AdvantaColors.primaryGreen),
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(selected,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdvantaColors.deepForest)),
                const SizedBox(width: 5),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AdvantaColors.mutedGrey)
              ])));

  Widget _searchBox() => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AdvantaShadows.card(false)),
      child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) =>
              setState(() => _search = value.trim().toLowerCase()),
          decoration: InputDecoration(
              hintText: 'Cari desa, lahan, petani, atau QA FI',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AdvantaColors.primaryGreen),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 19)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none))));

  Widget _loadingState(bool canLoadPlan) => Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdvantaColors.dividerGrey)),
      child: Column(children: [
        const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 14),
        Text(
            canLoadPlan
                ? 'Memuat target audit minggu terpilih…'
                : 'Memuat daftar region…',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AdvantaColors.deepForest)),
        const SizedBox(height: 4),
        const Text('Menyiapkan data berdasarkan target DAP.',
            style: TextStyle(fontSize: 12, color: AdvantaColors.mutedGrey))
      ]));

  Widget _errorState() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdvantaColors.error.withValues(alpha: .2))),
      child: Column(children: [
        Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AdvantaColors.errorLight, shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded,
                color: AdvantaColors.error)),
        const SizedBox(height: 12),
        const Text('Data planning belum dapat dimuat.',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AdvantaColors.deepForest)),
        const SizedBox(height: 5),
        const Text('Periksa koneksi atau pilih satu region, lalu coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AdvantaColors.mutedGrey)),
        const SizedBox(height: 10),
        FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'))
      ]));

  List<WeeklyAuditTarget> _phaseTargets(AuditPlanField field) =>
      field.weekly.targets
          .where((target) => auditStage(target.phase) == _phase)
          .toList(growable: false);

  bool _targetDone(AuditPlanField field) {
    final targets = _phaseTargets(field);
    return targets.isNotEmpty && targets.every((target) => target.done);
  }

  bool _targetOverdue(AuditPlanField field) =>
      _phaseTargets(field).any((target) => target.overdue);

  DateTime _targetPlannedDate(AuditPlanField field) => _phaseTargets(field)
      .map((target) => target.plannedDate)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime _targetDeadline(AuditPlanField field) => _phaseTargets(field)
      .map((target) => target.deadline)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  bool _matchesTextFilters(Map<String, dynamic> raw) {
    for (final filter in _textFilters) {
      final query = filter.value.trim().toLowerCase();
      if (query.isEmpty) continue;
      if (filter.fieldKey == 'qa_fi') {
        if (!QaNameHelper.fieldMatchesFiSearch(raw, query)) return false;
        continue;
      }
      final value = raw[filter.fieldKey]?.toString().trim().toLowerCase() ?? '';
      if (!value.contains(query)) return false;
    }
    return true;
  }

  Widget _content(List<AuditPlanField> all) {
    final fields = all.where((field) {
      final f = field.weekly;
      if (!f.targets.any((t) => auditStage(t.phase) == _phase) ||
          !_flags.contains(f.flag)) {
        return false;
      }
      if (_district != null &&
          f.raw['district_kab']?.toString().trim().toLowerCase() !=
              _district!.trim().toLowerCase()) {
        return false;
      }
      if (_season != null &&
          f.raw['season']?.toString().trim().toLowerCase() !=
              _season!.trim().toLowerCase()) {
        return false;
      }
      if (!_matchesTextFilters(f.raw)) return false;
      final hybrid = f.raw['hybrid']?.toString();
      final crop = DapHelper.isPsp(hybrid)
          ? 'PSP'
          : DapHelper.isSweetCorn(hybrid)
              ? 'SC'
              : 'FC';
      if (_crop != 'All Crop' && crop != _crop) return false;
      if (_status == 'Completed' && !_targetDone(field)) return false;
      if (_status == 'Pending' && _targetDone(field)) return false;
      if (_status == 'Overdue' && !_targetOverdue(field)) return false;
      if (_selectedWeekday != null &&
          !_phaseTargets(field).any(
              (target) => target.plannedDate.weekday == _selectedWeekday)) {
        return false;
      }
      return _search.isEmpty ||
          ['village_desa', 'field_number', 'farmer_name', 'qa_fi'].any((key) =>
              f.raw[key]?.toString().toLowerCase().contains(_search) ?? false);
    }).toList();
    final grouped = <String, List<AuditPlanField>>{};
    for (final field in fields) {
      grouped.putIfAbsent(field.weekly.villageKey, () => []).add(field);
    }
    final groups = grouped.values.toList()
      ..sort(
          (a, b) => a.first.weekly.village.compareTo(b.first.weekly.village));
    final targetHa = fields.fold(0.0, (sum, f) => sum + f.weekly.areaHa);
    final doneHa =
        fields.where(_targetDone).fold(0.0, (sum, f) => sum + f.weekly.areaHa);
    final targetFn = fields.length;
    final doneFn = fields.where(_targetDone).length;
    final achievement = targetFn == 0 ? 0.0 : doneFn / targetFn * 100;
    final mappedGroups =
        groups.where((g) => g.any((f) => !f.parsed.isDefault)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _daySelector(),
      const SizedBox(height: 8),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AdvantaColors.deepForest,
                    AdvantaColors.primaryGreen
                  ]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AdvantaColors.deepForest.withValues(alpha: .2),
                    blurRadius: 18,
                    offset: const Offset(0, 8))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(
                      '${_planningPeriodLabel()} · ${auditStageLabels[_phase]}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w800))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_graph_rounded,
                        size: 14, color: AdvantaColors.goldLight),
                    const SizedBox(width: 4),
                    Text('${achievement.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w800))
                  ]))
            ]),
            const SizedBox(height: 10),
            Text(auditWorkload(targetHa, targetFn),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text('$doneFn / $targetFn Audited',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AdvantaColors.goldLight)),
            const SizedBox(height: 12),
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                    value: (achievement / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .14),
                    color: AdvantaColors.goldLight)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${achievement.toStringAsFixed(0)}% selesai',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: .8),
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Expanded(
                  child: Text(
                      '${targetFn - doneFn} FN pending · ${auditHa(doneHa)} done',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: .8))))
            ])
          ])),
      _selectionActions(fields, all),
      const SizedBox(height: 10),
      Row(children: [
        const Expanded(
            child: Text('Daftar desa',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AdvantaColors.deepForest))),
        TextButton.icon(
            onPressed: () => setState(() => _showMap = !_showMap),
            style: TextButton.styleFrom(
                backgroundColor:
                    _showMap ? AdvantaColors.paleGreen : Colors.white,
                foregroundColor: AdvantaColors.primaryGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            icon: Icon(_showMap ? Icons.map_rounded : Icons.map_outlined,
                size: 18),
            label: Text(_showMap ? 'Tutup peta' : 'Lihat peta',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))
      ]),
      if (_showMap && mappedGroups.isNotEmpty)
        Container(
            height: 270,
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AdvantaColors.dividerGrey),
                boxShadow: AdvantaShadows.card(false)),
            child: Stack(children: [
              FlutterMap(
                  key: ValueKey(
                      '${_week.toIso8601String()}|$_region|$_phase|$_crop|$_status|$_search|${_flags.join(',')}'),
                  options: MapOptions(
                      initialCenter: _center(mappedGroups.first),
                      initialZoom: 10,
                      maxZoom: 18),
                  children: [
                    TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.kroscek.app',
                        maxNativeZoom: 18),
                    MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                            maxClusterRadius: 40,
                            size: const Size(44, 44),
                            markers: mappedGroups
                                .map((group) => Marker(
                                    point: _center(group),
                                    width: 110,
                                    height: 48,
                                    child: GestureDetector(
                                        onTap: () => _showVillage(group),
                                        child: Container(
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                                color: AdvantaColors.deepForest,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Text(
                                                group.first.weekly.village,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w700))))))
                                .toList(),
                            builder: (_, markers) => CircleAvatar(
                                backgroundColor: AdvantaColors.gold,
                                child: Text('${markers.length}')))),
                  ]),
              Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: AdvantaColors.deepForest.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${mappedGroups.length} desa terpetakan',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700))))
            ])),
      if (_showMap && fields.any((f) => f.parsed.isDefault))
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AdvantaColors.mutedGrey),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                      '${fields.where((f) => f.parsed.isDefault).length} lahan tanpa koordinat valid tetap masuk target.',
                      style: const TextStyle(
                          fontSize: 11, color: AdvantaColors.mutedGrey)))
            ])),
      if (fields.isEmpty)
        Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AdvantaColors.dividerGrey)),
            child: const Column(children: [
              Icon(Icons.inbox_outlined,
                  size: 38, color: AdvantaColors.mutedGrey),
              SizedBox(height: 10),
              Text('Belum ada target audit',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AdvantaColors.deepForest)),
              SizedBox(height: 3),
              Text('Tidak ada target untuk fase, minggu, dan filter ini.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: AdvantaColors.mutedGrey))
            ])),
      const SizedBox(height: 8),
      ...groups.map(_villageCard),
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AdvantaColors.paleGreen.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(14)),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: AdvantaColors.primaryGreen),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Target mengikuti jendela On Going DAP pada minggu terpilih. Audit yang selesai sebelumnya tidak ditargetkan ulang.',
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: AdvantaColors.primaryGreen)))
              ])),
    ]);
  }

  String _planningPeriodLabel() {
    if (_selectedWeekday == null) {
      return _weeks.length == 1 ? 'ALL Week' : 'ALL · ${_weeks.length} Weeks';
    }
    const labels = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    if (_weeks.length == 1) {
      final date = _week.add(Duration(days: _selectedWeekday! - 1));
      return '${labels[_selectedWeekday! - 1]} ${date.day}';
    }
    return '${labels[_selectedWeekday! - 1]} · ${_weeks.length} Weeks';
  }

  Widget _daySelector() {
    const labels = ['ALL', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: List.generate(labels.length, (index) {
          final weekday = index == 0 ? null : index;
          return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                  label: Text(labels[index]),
                  selected: _selectedWeekday == weekday,
                  showCheckmark: false,
                  selectedColor: AdvantaColors.gold,
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                  onSelected: (_) => setState(() {
                        _selectedWeekday = weekday;
                        _selectedFieldNumbers.clear();
                      })));
        })));
  }

  Widget _selectionActions(
      List<AuditPlanField> visible, List<AuditPlanField> all) {
    final allTargets = all
        .where((field) => _phaseTargets(field).isNotEmpty)
        .where((field) => _flags.contains(field.weekly.flag))
        .toList(growable: false);
    final visibleNumbers = visible
        .map((field) => field.weekly.raw['field_number']?.toString() ?? '')
        .where((number) => number.isNotEmpty)
        .toSet();
    final allNumbers = allTargets
        .map((field) => field.weekly.raw['field_number']?.toString() ?? '')
        .where((number) => number.isNotEmpty)
        .toSet();
    return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdvantaColors.dividerGrey)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed: visibleNumbers.isEmpty
                    ? null
                    : () => setState(
                        () => _selectedFieldNumbers.addAll(visibleNumbers)),
                icon: const Icon(Icons.select_all_rounded, size: 17),
                label: Text('Select visible (${visibleNumbers.length})')),
            OutlinedButton.icon(
                onPressed: allNumbers.isEmpty
                    ? null
                    : () => setState(
                        () => _selectedFieldNumbers.addAll(allNumbers)),
                icon: const Icon(Icons.done_all_rounded, size: 17),
                label: Text('Select all target (${allNumbers.length})')),
          ]),
          if (_selectedFieldNumbers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text('${_selectedFieldNumbers.length} FN selected',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AdvantaColors.deepForest))),
              TextButton(
                  onPressed: () =>
                      setState(() => _selectedFieldNumbers.clear()),
                  child: const Text('Clear')),
            ]),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: () => _startMassInspection(allTargets),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Mass Inspection')),
            )
          ]
        ]));
  }

  Future<void> _startMassInspection(List<AuditPlanField> candidates) async {
    final selected = candidates.where((field) {
      final number = field.weekly.raw['field_number']?.toString() ?? '';
      return _selectedFieldNumbers.contains(number);
    }).toList(growable: false);
    final phases = selected
        .expand(_phaseTargets)
        .map((target) => target.phase)
        .toSet()
        .toList()
      ..sort();
    if (phases.isEmpty) return;
    String? phase;
    if (phases.length == 1) {
      phase = phases.single;
    } else {
      phase = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const ListTile(
                    title: Text('Pilih checkpoint',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                        'Hanya FN yang memiliki target checkpoint terpilih yang dieksekusi.')),
                ...phases.map((value) => ListTile(
                    title: Text(value.replaceAll('_', ' ').toUpperCase()),
                    trailing: Text(
                        '${selected.where((field) => _phaseTargets(field).any((target) => target.phase == value)).length} FN'),
                    onTap: () => Navigator.pop(context, value))),
              ])));
    }
    if (phase == null || !mounted) return;
    final numbers = selected
        .where((field) =>
            _phaseTargets(field).any((target) => target.phase == phase))
        .map((field) => field.weekly.raw['field_number']?.toString() ?? '')
        .where((number) => number.isNotEmpty)
        .toSet()
        .toList();
    if (numbers.isEmpty) return;
    await context.push('/inspect/mass',
        extra: {'fieldNumbers': numbers, 'phase': phase});
    if (mounted) {
      setState(() => _selectedFieldNumbers.clear());
      await _refresh();
    }
  }

  Widget _villageCard(List<AuditPlanField> group) {
    final first = group.first.weekly;
    final key = first.villageKey;
    final expanded = _expandedVillages.contains(key);
    final totalArea = group.fold(0.0, (sum, f) => sum + f.weekly.areaHa);
    final done = group.where(_targetDone).length;
    final overdue = group.where(_targetOverdue).length;
    final achievement = group.isEmpty ? 0.0 : done / group.length * 100;
    final letter = first.village.isEmpty ? '?' : first.village[0].toUpperCase();
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: expanded
                    ? AdvantaColors.primaryGreen.withValues(alpha: .28)
                    : AdvantaColors.dividerGrey),
            boxShadow: AdvantaShadows.card(false)),
        clipBehavior: Clip.antiAlias,
        child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
                key: ValueKey(key),
                initiallyExpanded: expanded,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                onExpansionChanged: (isExpanded) => setState(() {
                      isExpanded
                          ? _expandedVillages.add(key)
                          : _expandedVillages.remove(key);
                    }),
                leading: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          AdvantaColors.primaryGreen,
                          AdvantaColors.midGreen
                        ]),
                        borderRadius: BorderRadius.circular(13)),
                    child: Text(letter,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900))),
                title: Text(first.village,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AdvantaColors.deepForest)),
                subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${first.raw['sub_district_kec'] ?? ''} · ${first.raw['district_kab'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AdvantaColors.mutedGrey)),
                          const SizedBox(height: 7),
                          Wrap(spacing: 6, runSpacing: 5, children: [
                            _microBadge(
                                Icons.landscape_outlined,
                                auditWorkload(totalArea, group.length),
                                AdvantaColors.mutedGrey),
                            _microBadge(
                                Icons.check_circle_outline_rounded,
                                '$done / ${group.length} Audited · ${achievement.toStringAsFixed(0)}%',
                                AdvantaColors.success),
                            if (overdue > 0)
                              _microBadge(Icons.warning_amber_rounded,
                                  '$overdue overdue', AdvantaColors.error),
                          ])
                        ])),
                trailing: AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AdvantaColors.primaryGreen)),
                children: expanded
                    ? [
                        const Divider(height: 12),
                        ...group.map(_fieldTile),
                      ]
                    : const [])));
  }

  Widget _microBadge(IconData icon, String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)))
      ]));

  LatLng _center(List<AuditPlanField> group) {
    final valid = group.where((f) => !f.parsed.isDefault).toList();
    return LatLng(
        valid.fold(0.0, (sum, f) => sum + f.parsed.lat) / valid.length,
        valid.fold(0.0, (sum, f) => sum + f.parsed.lng) / valid.length);
  }

  Widget _fieldTile(AuditPlanField field) {
    final f = field.weekly;
    final done = _targetDone(field);
    final overdue = _targetOverdue(field);
    final plannedDate = _targetPlannedDate(field);
    final deadline = _targetDeadline(field);
    final fieldNumber = f.raw['field_number']?.toString() ?? '';
    final selected = _selectedFieldNumbers.contains(fieldNumber);
    final statusColor = done
        ? AdvantaColors.success
        : overdue
            ? AdvantaColors.error
            : AdvantaColors.gold;
    final statusIcon = done
        ? Icons.check_rounded
        : overdue
            ? Icons.priority_high_rounded
            : Icons.schedule_rounded;
    final statusLabel = done
        ? 'Completed'
        : overdue
            ? 'Overdue'
            : 'Pending';
    return Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
            color: AdvantaColors.softGrey.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AdvantaColors.dividerGrey)),
        child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => FieldDetailBottomSheet.show(context, f.raw,
                dapReferenceDate: DateTime.now(),
                onInspectDone: (_) => _refresh()),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                          value: selected,
                          onChanged: (checked) => setState(() {
                                checked == true
                                    ? _selectedFieldNumbers.add(fieldNumber)
                                    : _selectedFieldNumbers.remove(fieldNumber);
                              })),
                      const SizedBox(width: 11),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                '${f.raw['field_number']} · ${f.raw['farmer_name'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800,
                                    color: AdvantaColors.deepForest)),
                            const SizedBox(height: 7),
                            Wrap(spacing: 6, runSpacing: 5, children: [
                              _microBadge(Icons.landscape_outlined,
                                  auditHa(f.areaHa), AdvantaColors.mutedGrey),
                              if ((f.raw['hybrid']?.toString().trim() ?? '')
                                  .isNotEmpty)
                                _microBadge(
                                    Icons.eco_outlined,
                                    f.raw['hybrid'].toString().trim(),
                                    AdvantaColors.primaryGreen),
                              _microBadge(
                                  Icons.flag_outlined,
                                  f.flag,
                                  f.flag == 'GF'
                                      ? AdvantaColors.success
                                      : f.flag == auditNotYetFlagging
                                          ? AdvantaColors.mutedGrey
                                          : AdvantaColors.gold),
                              _microBadge(statusIcon, statusLabel, statusColor),
                            ]),
                            const SizedBox(height: 8),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 13, color: AdvantaColors.mutedGrey),
                                  const SizedBox(width: 5),
                                  Expanded(
                                      child: Text(
                                          '${DateFormat('d MMM', 'id_ID').format(plannedDate)} – ${DateFormat('d MMM', 'id_ID').format(deadline)} · ${f.raw['qa_fi'] ?? 'Unmapped / Need Mapping'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.35,
                                              color: AdvantaColors.mutedGrey)))
                                ])
                          ])),
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(Icons.chevron_right_rounded,
                              size: 20, color: AdvantaColors.mutedGrey))
                    ]))));
  }

  void _showVillage(List<AuditPlanField> group) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
          height: MediaQuery.sizeOf(context).height * .72,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          decoration: const BoxDecoration(
              color: AdvantaColors.softGrey,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                        color: AdvantaColors.dividerGrey,
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 16),
            Text(group.first.weekly.village,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AdvantaColors.deepForest)),
            const SizedBox(height: 3),
            Text(
                '${group.length} lahan · ${auditHa(group.fold(0.0, (sum, field) => sum + field.weekly.areaHa))}',
                style: const TextStyle(
                    fontSize: 12, color: AdvantaColors.mutedGrey)),
            const SizedBox(height: 8),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: group.map(_fieldTile).toList()))
          ])));
}
