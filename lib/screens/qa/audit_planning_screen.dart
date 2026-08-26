import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/audit_plan_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/dap_helper.dart';
import '../../utils/weekly_audit.dart';
import '../../widgets/field_detail_bottom_sheet.dart';
import '../../widgets/weekly_audit_widgets.dart';

class AuditPlanningScreen extends ConsumerStatefulWidget {
  final DateTime? initialWeek;
  const AuditPlanningScreen({super.key, this.initialWeek});
  @override
  ConsumerState<AuditPlanningScreen> createState() =>
      _AuditPlanningScreenState();
}

class _AuditPlanningScreenState extends ConsumerState<AuditPlanningScreen> {
  late DateTime _week;
  String _phase = 'vegetative';
  String? _region;
  bool _showAllRegions = false;
  String _crop = 'All Crop';
  String _status = 'Semua Status';
  String _search = '';
  Set<String> _flags = {...defaultAuditFlags};
  bool _showMap = false;
  final Set<String> _expandedVillages = {};
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _week = auditWeekStart(
        widget.initialWeek ?? DateTime.now().add(const Duration(days: 7)));
  }

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
        final params = (weekStart: _week, region: _region);
        ref.invalidate(auditPlanningIndexProvider(_region));
        ref.invalidate(auditPlanningProvider(params));
        await ref.read(auditPlanningProvider(params).future);
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
    final AsyncValue<List<AuditPlanField>> plan = canLoadPlan
        ? ref.watch(auditPlanningProvider((weekStart: _week, region: _region)))
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _intro(),
                const SizedBox(height: 18),
                _phaseSelector(),
                const SizedBox(height: 12),
                AuditWeekSelector(
                    weekStart: _week,
                    onChanged: (week) => setState(() => _week = week)),
                const SizedBox(height: 18),
                _filterBar(regions),
                const SizedBox(height: 12),
                _searchBox(),
                const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                              borderRadius: BorderRadius.circular(12)),
                          labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _phase == phase
                                  ? AdvantaColors.deepForest
                                  : AdvantaColors.mutedGrey),
                          onSelected: (_) => setState(() => _phase = phase)))))
              .toList()));

  bool get _hasActiveFilters =>
      _crop != 'All Crop' ||
      _status != 'Semua Status' ||
      !_flags.containsAll(defaultAuditFlags) ||
      _flags.length != defaultAuditFlags.length ||
      _search.isNotEmpty;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _crop = 'All Crop';
      _status = 'Semua Status';
      _flags = {...defaultAuditFlags};
      _search = '';
    });
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
            _expandedVillages.clear();
          }),
          _filter(_crop, const ['All Crop', 'FC', 'SC', 'PSP'],
              Icons.eco_outlined, (value) => _crop = value),
          _filter(_status, const ['Semua Status', 'Pending', 'Done'],
              Icons.task_alt_rounded, (value) => _status = value),
          AuditFlagFilter(
              selected: _flags,
              onChanged: (flags) => setState(() => _flags = flags)),
        ]),
      ]);

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

  WeeklyAuditTarget _target(AuditPlanField field) =>
      field.weekly.targets.firstWhere((t) => t.phase == _phase);

  Widget _content(List<AuditPlanField> all) {
    final fields = all.where((field) {
      final f = field.weekly;
      if (!f.targets.any((t) => t.phase == _phase) ||
          !_flags.contains(f.flag)) {
        return false;
      }
      final hybrid = f.raw['hybrid']?.toString();
      final crop = DapHelper.isPsp(hybrid)
          ? 'PSP'
          : DapHelper.isSweetCorn(hybrid)
              ? 'SC'
              : 'FC';
      if (_crop != 'All Crop' && crop != _crop) return false;
      if (_status == 'Done' && !_target(field).done) return false;
      if (_status == 'Pending' && _target(field).done) return false;
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
    final doneHa = fields
        .where((f) => _target(f).done)
        .fold(0.0, (sum, f) => sum + f.weekly.areaHa);
    final achievement = targetHa == 0 ? 0.0 : doneHa / targetHa * 100;
    final pendingHa = (targetHa - doneHa).clamp(0.0, double.infinity);
    final mappedGroups =
        groups.where((g) => g.any((f) => !f.parsed.isDefault)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AdvantaColors.deepForest,
                    AdvantaColors.primaryGreen
                  ]),
              borderRadius: BorderRadius.circular(22),
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
                      '${auditStageLabels[_phase]} · ${groups.length} desa · ${fields.length} lahan',
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
            const SizedBox(height: 20),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                  child: _summaryMetric(
                      'TARGET AREA', auditHa(targetHa), Colors.white)),
              Container(
                  width: 1,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white.withValues(alpha: .18)),
              Expanded(
                  child: _summaryMetric(
                      'ACHIEVED', auditHa(doneHa), AdvantaColors.goldLight))
            ]),
            const SizedBox(height: 18),
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                    value: (achievement / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .14),
                    color: AdvantaColors.goldLight)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${achievement.toStringAsFixed(1)}% selesai',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: .8),
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${auditHa(pendingHa)} pending',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withValues(alpha: .8)))
            ])
          ])),
      const SizedBox(height: 14),
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
      const SizedBox(height: 12),
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

  Widget _summaryMetric(String label, String value, Color valueColor) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                letterSpacing: .8,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: .65))),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: valueColor))
      ]);

  Widget _villageCard(List<AuditPlanField> group) {
    final first = group.first.weekly;
    final key = first.villageKey;
    final expanded = _expandedVillages.contains(key);
    final totalArea = group.fold(0.0, (sum, f) => sum + f.weekly.areaHa);
    final done = group.where((field) => _target(field).done).length;
    final overdue = group.where((field) => _target(field).overdue).length;
    final letter = first.village.isEmpty ? '?' : first.village[0].toUpperCase();
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                                Icons.grid_view_rounded,
                                '${group.length} lahan',
                                AdvantaColors.midGreen),
                            _microBadge(Icons.landscape_outlined,
                                auditHa(totalArea), AdvantaColors.mutedGrey),
                            if (done > 0)
                              _microBadge(Icons.check_circle_outline_rounded,
                                  '$done done', AdvantaColors.success),
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
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color))
      ]));

  LatLng _center(List<AuditPlanField> group) {
    final valid = group.where((f) => !f.parsed.isDefault).toList();
    return LatLng(
        valid.fold(0.0, (sum, f) => sum + f.parsed.lat) / valid.length,
        valid.fold(0.0, (sum, f) => sum + f.parsed.lng) / valid.length);
  }

  Widget _fieldTile(AuditPlanField field) {
    final target = _target(field);
    final f = field.weekly;
    final statusColor = target.done
        ? AdvantaColors.success
        : target.overdue
            ? AdvantaColors.error
            : AdvantaColors.gold;
    final statusIcon = target.done
        ? Icons.check_rounded
        : target.overdue
            ? Icons.priority_high_rounded
            : Icons.schedule_rounded;
    final statusLabel = target.done
        ? 'Done'
        : target.overdue
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
                dapReferenceDate: target.plannedDate,
                onInspectDone: (_) => _refresh()),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12)),
                          child:
                              Icon(statusIcon, size: 20, color: statusColor)),
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
                              _microBadge(
                                  Icons.flag_outlined,
                                  f.flag,
                                  f.flag == 'GF'
                                      ? AdvantaColors.success
                                      : f.flag == 'Belum ada'
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
                                          '${DateFormat('d MMM', 'id_ID').format(target.plannedDate)} – ${DateFormat('d MMM', 'id_ID').format(target.deadline)} · ${f.raw['qa_fi'] ?? ''}',
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
