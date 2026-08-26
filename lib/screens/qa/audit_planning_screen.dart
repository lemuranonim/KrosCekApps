import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/audit_plan_provider.dart';
import '../../providers/master_fields_provider.dart';
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
  String _crop = 'All Crop';
  String _status = 'Semua Status';
  String _search = '';
  Set<String> _flags = {...defaultAuditFlags};
  bool _showMap = true;
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
    final scope = MasterFieldMapScope(region: _region);
    ref.invalidate(masterFieldCoverageScopedProvider(scope));
    await ref.read(
        auditPlanningProvider((weekStart: _week, region: _region)).future);
  }

  @override
  Widget build(BuildContext context) {
    final regions = (ref
                .watch(activeMasterFieldRegionsProvider(
                    const MasterFieldMapScope.all()))
                .value ??
            <String>[])
        .where((r) => r.trim().toLowerCase() != 'region tester')
        .toList();
    final plan =
        ref.watch(auditPlanningProvider((weekStart: _week, region: _region)));
    return Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      appBar: AppBar(
          title: const Text('Planning Audit'),
          backgroundColor: AdvantaColors.deepForest,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
                tooltip: 'Muat ulang',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh))
          ]),
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Target audit per desa',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdvantaColors.deepForest)),
            const SizedBox(height: 4),
            const Text('Planning berdasarkan jendela DAP pada minggu terpilih.',
                style: TextStyle(color: AdvantaColors.mutedGrey)),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ['vegetative', 'pre_harvest', 'harvest']
                    .map((phase) => ChoiceChip(
                        label: Text(auditStageLabels[phase]!),
                        selected: _phase == phase,
                        onSelected: (_) => setState(() => _phase = phase)))
                    .toList()),
            AuditWeekSelector(
                weekStart: _week,
                onChanged: (week) => setState(() => _week = week)),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _filter(
                      _region ?? 'All Region',
                      ['All Region', ...regions],
                      (value) =>
                          _region = value == 'All Region' ? null : value),
                  _filter(_crop, const ['All Crop', 'FC', 'SC', 'PSP'],
                      (value) => _crop = value),
                  _filter(_status, const ['Semua Status', 'Pending', 'Done'],
                      (value) => _status = value),
                  AuditFlagFilter(
                      selected: _flags,
                      onChanged: (flags) => setState(() => _flags = flags)),
                ]),
            const SizedBox(height: 12),
            TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
                decoration: InputDecoration(
                    hintText: 'Cari desa, lahan, petani, atau QA FI',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            plan.when(
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator())),
                error: (_, __) => Column(children: [
                      const Text('Data planning belum dapat dimuat.'),
                      TextButton(
                          onPressed: _refresh, child: const Text('Coba lagi'))
                    ]),
                data: (all) => _content(all)),
          ])),
    );
  }

  Widget _filter(
          String selected, List<String> options, ValueChanged<String> change) =>
      PopupMenuButton<String>(
          initialValue: selected,
          onSelected: (value) => setState(() => change(value)),
          itemBuilder: (_) => options
              .map((value) => PopupMenuItem(value: value, child: Text(value)))
              .toList(),
          child: Chip(
              label: Text(selected),
              avatar: const Icon(Icons.expand_more, size: 18)));

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
    final mappedGroups =
        groups.where((g) => g.any((f) => !f.parsed.isDefault)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AdvantaColors.deepForest,
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${auditStageLabels[_phase]} · ${groups.length} desa · ${fields.length} lahan',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Target ${auditHa(targetHa)}',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text(
                'Achievement ${auditHa(doneHa)} · ${targetHa == 0 ? '0' : (doneHa / targetHa * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white)),
          ])),
      const SizedBox(height: 8),
      Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () => setState(() => _showMap = !_showMap),
              icon: const Icon(Icons.map_outlined),
              label: Text(
                  _showMap ? 'Sembunyikan peta desa' : 'Tampilkan peta desa'))),
      if (_showMap && mappedGroups.isNotEmpty)
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                height: 260,
                child: FlutterMap(
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
                                                  color:
                                                      AdvantaColors.deepForest,
                                                  border: Border.all(
                                                      color: Colors.white,
                                                      width: 2),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Text(
                                                  group.first.weekly.village,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700))))))
                                  .toList(),
                              builder: (_, markers) =>
                                  CircleAvatar(backgroundColor: AdvantaColors.gold, child: Text('${markers.length}')))),
                    ]))),
      if (_showMap && fields.any((f) => f.parsed.isDefault))
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                '${fields.where((f) => f.parsed.isDefault).length} lahan tanpa koordinat valid tetap masuk target.',
                style: const TextStyle(fontSize: 11))),
      if (fields.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Tidak ada target audit untuk fase, minggu, dan filter ini.',
                textAlign: TextAlign.center)),
      const SizedBox(height: 12),
      ...groups.map((group) => Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
              title: Text(group.first.weekly.village,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  '${group.first.weekly.raw['sub_district_kec'] ?? ''} · ${group.first.weekly.raw['district_kab'] ?? ''}\n'
                  '${group.length} lahan · ${auditHa(group.fold(0.0, (sum, f) => sum + f.weekly.areaHa))}'),
              children: group.map(_fieldTile).toList()))),
      const Text(
          'Target: jendela On Going DAP beririsan dengan minggu terpilih. Audit fase yang selesai sebelum minggu ini tidak ditargetkan ulang.',
          style: TextStyle(fontSize: 11, color: AdvantaColors.mutedGrey)),
    ]);
  }

  LatLng _center(List<AuditPlanField> group) {
    final valid = group.where((f) => !f.parsed.isDefault).toList();
    return LatLng(
        valid.fold(0.0, (sum, f) => sum + f.parsed.lat) / valid.length,
        valid.fold(0.0, (sum, f) => sum + f.parsed.lng) / valid.length);
  }

  Widget _fieldTile(AuditPlanField field) {
    final target = _target(field);
    final f = field.weekly;
    return ListTile(
        isThreeLine: true,
        leading: Icon(
            target.done
                ? Icons.check_circle
                : target.overdue
                    ? Icons.warning_amber
                    : Icons.schedule,
            color: target.done
                ? AdvantaColors.midGreen
                : target.overdue
                    ? AdvantaColors.error
                    : AdvantaColors.gold),
        title: Text('${f.raw['field_number']} · ${f.raw['farmer_name'] ?? ''}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${auditHa(f.areaHa)} · ${f.flag} · ${target.done ? 'Done' : 'Pending'}\n'
            '${DateFormat('d MMM', 'id_ID').format(target.plannedDate)} – ${DateFormat('d MMM', 'id_ID').format(target.deadline)} · ${f.raw['qa_fi'] ?? ''}'),
        onTap: () => FieldDetailBottomSheet.show(context, f.raw,
            dapReferenceDate: target.plannedDate,
            onInspectDone: (_) => _refresh()));
  }

  void _showVillage(List<AuditPlanField> group) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(group.first.weekly.village,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800))),
            Expanded(child: ListView(children: group.map(_fieldTile).toList()))
          ])));
}
