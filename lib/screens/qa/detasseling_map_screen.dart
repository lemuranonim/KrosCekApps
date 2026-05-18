import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../providers/detasseling_plan_provider.dart';
import '../../providers/filter_data_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/field_detail_bottom_sheet.dart';

class DetasselingMapScreen extends ConsumerStatefulWidget {
  const DetasselingMapScreen({super.key});

  @override
  ConsumerState<DetasselingMapScreen> createState() =>
      _DetasselingMapScreenState();
}

class _DetasselingMapScreenState extends ConsumerState<DetasselingMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _planningCardKey = GlobalKey();

  late final List<DetasselingWeekOption> _weeks;
  late DetasselingWeekOption _selectedWeek;

  String? _selectedRegion;
  DetasselingCropFilter _selectedCrop = DetasselingCropFilter.all;
  DetasselingStatusFilter _selectedStatus = DetasselingStatusFilter.all;
  String _searchQuery = '';
  DateTime? _selectedPlanningDate;
  String? _selectedGroupKey;
  bool _isExportingPicture = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _weeks = generateDetasselingWeeks();
    final defaultStart = defaultDetasselingWeekStart();
    _selectedWeek = _weeks.firstWhere(
      (week) => week.startDate == defaultStart,
      orElse: () => DetasselingWeekOption(
        label: 'W${isoWeekNumber(defaultStart)}',
        startDate: defaultStart,
        endDate: defaultStart.add(const Duration(days: 6)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(uniqueRegionsProvider);
    final params = DetasselingPlanningParams(
      weekStart: _selectedWeek.startDate,
      region: _selectedRegion,
      crop: _selectedCrop,
      status: _selectedStatus,
      searchQuery: _searchQuery,
    );
    final planAsync = ref.watch(detasselingPlanningProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          planAsync.when(
            data: _buildMap,
            loading: () => _buildMap(null),
            error: (error, _) => _buildError(error.toString()),
          ),
          _buildTopOverlay(regions),
          planAsync.when(
            data: (plan) => _buildBottomPlanningCard(plan),
            loading: () => _buildLoadingCard(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(DetasselingPlanningData? plan) {
    final filteredPlan =
        plan == null ? null : _planForDateFilter(plan, _selectedPlanningDate);
    final groups = filteredPlan?.groups ?? const <DetasselingPlanGroup>[];
    final selectedGroup = _selectedGroup(plan);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(-7.5, 112.5),
        initialZoom: 8,
        maxZoom: 18,
        onTap: (_, __) => setState(() => _selectedGroupKey = null),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.kroscek.app',
          maxNativeZoom: 18,
        ),
        if (selectedGroup != null) _buildSelectedPolygonLayer(selectedGroup),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 44,
            size: const Size(46, 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(52),
            animationsOptions: const AnimationsOptions(
              zoom: Duration.zero,
              fitBound: Duration.zero,
              centerMarker: Duration.zero,
              spiderfy: Duration.zero,
            ),
            markers: groups.map(_buildGroupMarker).toList(),
            builder: (_, markers) => _ClusterMarker(count: markers.length),
          ),
        ),
      ],
    );
  }

  PolygonLayer _buildSelectedPolygonLayer(DetasselingPlanGroup group) {
    final polygons = <Polygon>[];
    for (final field in group.fields) {
      final points = field.parsed.polygonPoints;
      if (points == null || points.length < 3) continue;
      polygons.add(
        Polygon(
          points: points,
          color: AdvantaColors.gold.withAlpha(52),
          borderColor: AdvantaColors.goldLight,
          borderStrokeWidth: 2.4,
        ),
      );
    }
    return PolygonLayer(polygons: polygons);
  }

  Marker _buildGroupMarker(DetasselingPlanGroup group) {
    final isSelected = group.key == _selectedGroupKey;
    return Marker(
      point: group.center,
      width: 68,
      height: 68,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedGroupKey = group.key);
          _fitGroup(group);
        },
        child: _CodetMarker(group: group, isSelected: isSelected),
      ),
    );
  }

  Widget _buildTopOverlay(List<String> regions) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AdvantaColors.deepForest.withAlpha(245),
              AdvantaColors.deepForest.withAlpha(185),
              Colors.transparent,
            ],
            stops: const [0, 0.72, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _IconPill(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                      tooltip: 'Kembali',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detasseling Map',
                            style: AdvantaText.heading2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_selectedWeek.label} • ${_selectedWeek.rangeLabel}',
                            style: AdvantaText.caption.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _IconPill(
                      icon: Icons.fit_screen_outlined,
                      tooltip: 'Fit planning',
                      onTap: _fitCurrentPlan,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSearchBar(),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildWeekFilter(),
                      const SizedBox(width: 8),
                      _buildRegionFilter(regions),
                      const SizedBox(width: 8),
                      _buildCropFilter(),
                      const SizedBox(width: 8),
                      _buildStatusFilter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: AdvantaText.body2.copyWith(color: Colors.white),
        cursorColor: AdvantaColors.goldLight,
        decoration: InputDecoration(
          hintText: 'Cari lahan / petani...',
          hintStyle: AdvantaText.body2.copyWith(color: Colors.white54),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white.withAlpha(15),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withAlpha(24)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                BorderSide(color: AdvantaColors.goldLight.withAlpha(150)),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekFilter() {
    return PopupMenuButton<DetasselingWeekOption>(
      color: AdvantaColors.deepForest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (week) => setState(() {
        _selectedWeek = week;
        _selectedPlanningDate = null;
        _selectedGroupKey = null;
      }),
      itemBuilder: (_) => _weeks.map((week) {
        final selected = week.startDate == _selectedWeek.startDate;
        return PopupMenuItem(
          value: week,
          child: _PopupRow(
            label: '${week.label} • ${week.compactRangeLabel}',
            selected: selected,
          ),
        );
      }).toList(),
      child: _FilterChip(
        icon: Icons.calendar_month_outlined,
        label: _selectedWeek.label,
        isActive: true,
      ),
    );
  }

  Widget _buildRegionFilter(List<String> regions) {
    return PopupMenuButton<String>(
      color: AdvantaColors.deepForest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => setState(() {
        _selectedRegion = value == '__all__' ? null : value;
        _selectedGroupKey = null;
      }),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '__all__',
          child: _PopupRow(
              label: 'Semua Region', selected: _selectedRegion == null),
        ),
        ...regions.map(
          (region) => PopupMenuItem(
            value: region,
            child:
                _PopupRow(label: region, selected: region == _selectedRegion),
          ),
        ),
      ],
      child: _FilterChip(
        icon: Icons.map_outlined,
        label: _selectedRegion ?? 'Region',
        isActive: _selectedRegion != null,
      ),
    );
  }

  Widget _buildCropFilter() {
    String label(DetasselingCropFilter crop) {
      switch (crop) {
        case DetasselingCropFilter.all:
          return 'Crop';
        case DetasselingCropFilter.fc:
          return 'FC';
        case DetasselingCropFilter.sc:
          return 'SC';
      }
    }

    return PopupMenuButton<DetasselingCropFilter>(
      color: AdvantaColors.deepForest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => setState(() {
        _selectedCrop = value;
        _selectedGroupKey = null;
      }),
      itemBuilder: (_) => DetasselingCropFilter.values.map((crop) {
        return PopupMenuItem(
          value: crop,
          child: _PopupRow(
            label: crop == DetasselingCropFilter.all ? 'All Crop' : label(crop),
            selected: crop == _selectedCrop,
          ),
        );
      }).toList(),
      child: _FilterChip(
        icon: Icons.grass_rounded,
        label: label(_selectedCrop),
        isActive: _selectedCrop != DetasselingCropFilter.all,
      ),
    );
  }

  Widget _buildStatusFilter() {
    String label(DetasselingStatusFilter status) {
      switch (status) {
        case DetasselingStatusFilter.all:
          return 'Status';
        case DetasselingStatusFilter.pending:
          return 'Pending';
        case DetasselingStatusFilter.done:
          return 'Done';
      }
    }

    return PopupMenuButton<DetasselingStatusFilter>(
      color: AdvantaColors.deepForest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => setState(() {
        _selectedStatus = value;
        _selectedGroupKey = null;
      }),
      itemBuilder: (_) => DetasselingStatusFilter.values.map((status) {
        return PopupMenuItem(
          value: status,
          child: _PopupRow(
            label: status == DetasselingStatusFilter.all
                ? 'All Status'
                : label(status),
            selected: status == _selectedStatus,
          ),
        );
      }).toList(),
      child: _FilterChip(
        icon: Icons.checklist_rtl_rounded,
        label: label(_selectedStatus),
        isActive: _selectedStatus != DetasselingStatusFilter.all,
      ),
    );
  }

  Widget _buildBottomPlanningCard(DetasselingPlanningData plan) {
    final visiblePlan = _planForDateFilter(plan, _selectedPlanningDate);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 14,
      child: RepaintBoundary(
        key: _planningCardKey,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.48,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(180)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(95),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanningHeader(
                plan: visiblePlan,
                dateLabel: _dateFilterLabel(_selectedPlanningDate),
                exportingPicture: _isExportingPicture,
                exportingPdf: _isExportingPdf,
                onPicture: () => unawaited(_downloadPicture(plan)),
                onPdf: () => unawaited(_downloadPdf(plan)),
              ),
              _buildDailyStrip(plan),
              Divider(
                  height: 1, color: AdvantaColors.dividerGrey.withAlpha(180)),
              Expanded(child: _buildGroupList(plan, visiblePlan)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 14,
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AdvantaColors.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildDailyStrip(DetasselingPlanningData plan) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 7.0;
          const tileCount = 8;
          final tileWidth =
              (constraints.maxWidth - (gap * (tileCount - 1))) / tileCount;
          final fitsColumns = tileWidth >= 72;

          if (fitsColumns) {
            return SizedBox(
              height: 98,
              child: Row(
                children: [
                  Expanded(
                    child: _AllDayTile(
                      plan: plan,
                      selected: _selectedPlanningDate == null,
                      onTap: () => _setPlanningDateFilter(plan, null),
                    ),
                  ),
                  const SizedBox(width: gap),
                  for (var i = 0; i < plan.dailySummaries.length; i++) ...[
                    Expanded(
                      child: _DayTile(
                        summary: plan.dailySummaries[i],
                        selected: _isPlanningDateSelected(
                          plan.dailySummaries[i].date,
                        ),
                        onTap: () => _setPlanningDateFilter(
                          plan,
                          plan.dailySummaries[i].date,
                        ),
                      ),
                    ),
                    if (i != plan.dailySummaries.length - 1)
                      const SizedBox(width: gap),
                  ],
                ],
              ),
            );
          }

          return SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tileCount,
              separatorBuilder: (_, __) => const SizedBox(width: gap),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SizedBox(
                    width: 84,
                    child: _AllDayTile(
                      plan: plan,
                      selected: _selectedPlanningDate == null,
                      onTap: () => _setPlanningDateFilter(plan, null),
                    ),
                  );
                }
                final summary = plan.dailySummaries[index - 1];
                return SizedBox(
                  width: 84,
                  child: _DayTile(
                    summary: summary,
                    selected: _isPlanningDateSelected(summary.date),
                    onTap: () => _setPlanningDateFilter(plan, summary.date),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupList(
    DetasselingPlanningData sourcePlan,
    DetasselingPlanningData visiblePlan,
  ) {
    if (visiblePlan.groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            _selectedPlanningDate == null
                ? 'Tidak ada Codet yang masuk planning DT untuk filter ini.'
                : 'Tidak ada Codet pada ${_dateFilterLabel(_selectedPlanningDate)}.',
            textAlign: TextAlign.center,
            style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      itemCount: visiblePlan.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = visiblePlan.groups[index];
        final sourceGroup = _sourceGroupForKey(sourcePlan, group.key) ?? group;
        return _CodetSummaryRow(
          group: group,
          isSelected: group.key == _selectedGroupKey,
          onTap: () {
            setState(() => _selectedGroupKey = group.key);
            _fitGroup(group);
          },
          onDetail: () => _showGroupDetail(sourcePlan, sourceGroup),
        );
      },
    );
  }

  Widget _buildError(String message) {
    return Container(
      color: AdvantaColors.deepForest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: AdvantaBanner.error(message: message),
    );
  }

  bool _isPlanningDateSelected(DateTime date) {
    final selectedDate = _selectedPlanningDate;
    return selectedDate != null &&
        normalizeDate(date) == normalizeDate(selectedDate);
  }

  void _setPlanningDateFilter(
    DetasselingPlanningData plan,
    DateTime? date,
  ) {
    final selectedDate = date == null ? null : normalizeDate(date);
    final visiblePlan = _planForDateFilter(plan, selectedDate);
    setState(() {
      _selectedPlanningDate = selectedDate;
      if (_selectedGroupKey != null &&
          !visiblePlan.groups.any((group) => group.key == _selectedGroupKey)) {
        _selectedGroupKey = null;
      }
    });
  }

  DetasselingPlanningData _planForDateFilter(
    DetasselingPlanningData plan,
    DateTime? selectedDate,
  ) {
    if (selectedDate == null) return plan;
    final date = normalizeDate(selectedDate);
    final groups = <DetasselingPlanGroup>[];
    var fieldCount = 0;

    for (final group in plan.groups) {
      final filteredGroup = _groupForDateFilter(group, date);
      if (filteredGroup.fields.isEmpty) continue;
      fieldCount += filteredGroup.fieldCount;
      groups.add(filteredGroup);
    }

    return DetasselingPlanningData(
      week: plan.week,
      groups: List.unmodifiable(groups),
      dailySummaries: List.unmodifiable(
        _dailySummariesForGroups(plan.week, groups),
      ),
      sourceFieldCount: plan.sourceFieldCount,
      plannedFieldCount: fieldCount,
      roleScope: plan.roleScope,
    );
  }

  DetasselingPlanGroup? _sourceGroupForKey(
    DetasselingPlanningData plan,
    String key,
  ) {
    for (final group in plan.groups) {
      if (group.key == key) return group;
    }
    return null;
  }

  List<DetasselingPlanField> _fieldsForDate(
    DetasselingPlanGroup group,
    DateTime date,
  ) {
    final normalized = normalizeDate(date);
    return group.fields
        .where((field) => normalizeDate(field.plannedDate) == normalized)
        .toList(growable: false);
  }

  DetasselingPlanGroup _groupForDateFilter(
    DetasselingPlanGroup group,
    DateTime? selectedDate,
  ) {
    if (selectedDate == null) return group;
    final fields = _fieldsForDate(group, selectedDate);
    return DetasselingPlanGroup(
      key: group.key,
      codet: group.codet,
      village: group.village,
      hybrid: group.hybrid,
      crop: group.crop,
      fields: List.unmodifiable(fields),
      center: _centerForFields(fields, group.center),
    );
  }

  List<DetasselingDailySummary> _dailySummariesForGroups(
    DetasselingWeekOption week,
    List<DetasselingPlanGroup> groups,
  ) {
    return List.generate(7, (index) {
      final date = week.startDate.add(Duration(days: index));
      final codets = <String>{};
      double area = 0;
      for (final group in groups) {
        for (final field in group.fields) {
          if (normalizeDate(field.plannedDate) == date) {
            codets.add(group.key);
            area += field.areaHa;
          }
        }
      }
      return DetasselingDailySummary(
        date: date,
        codetCount: codets.length,
        areaHa: area,
      );
    });
  }

  LatLng _centerForFields(
    List<DetasselingPlanField> fields,
    LatLng fallback,
  ) {
    if (fields.isEmpty) return fallback;
    var lat = 0.0;
    var lng = 0.0;
    for (final field in fields) {
      lat += field.parsed.lat;
      lng += field.parsed.lng;
    }
    return LatLng(lat / fields.length, lng / fields.length);
  }

  String _dateFilterLabel(DateTime? date) {
    if (date == null) return 'All Date';
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  String _dateFilterSuffix(DateTime? date) {
    if (date == null) return 'all_date';
    return DateFormat('yyyyMMdd').format(date);
  }

  DetasselingPlanGroup? _selectedGroup(DetasselingPlanningData? plan) {
    if (plan == null || _selectedGroupKey == null) return null;
    final visiblePlan = _planForDateFilter(plan, _selectedPlanningDate);
    for (final group in visiblePlan.groups) {
      if (group.key == _selectedGroupKey) return group;
    }
    return null;
  }

  void _fitCurrentPlan() {
    final params = DetasselingPlanningParams(
      weekStart: _selectedWeek.startDate,
      region: _selectedRegion,
      crop: _selectedCrop,
      status: _selectedStatus,
      searchQuery: _searchQuery,
    );
    final value = ref.read(detasselingPlanningProvider(params)).value;
    if (value == null) return;
    final visiblePlan = _planForDateFilter(value, _selectedPlanningDate);
    if (visiblePlan.groups.isEmpty) return;
    _fitPoints(visiblePlan.groups.map((group) => group.center).toList());
  }

  void _fitGroup(DetasselingPlanGroup group) {
    final points = <LatLng>[];
    for (final field in group.fields) {
      final polygon = field.parsed.polygonPoints;
      if (polygon != null && polygon.length >= 3) {
        points.addAll(polygon);
      } else {
        points.add(LatLng(field.parsed.lat, field.parsed.lng));
      }
    }
    _fitPoints(points);
  }

  void _fitPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(58, 150, 58, 260),
      ),
    );
  }

  Future<void> _downloadPicture(DetasselingPlanningData plan) async {
    if (_isExportingPicture) return;
    setState(() => _isExportingPicture = true);
    try {
      final bytes = await _buildWeeklySummaryPng(
        plan,
        selectedDate: _selectedPlanningDate,
      );
      final destination = await _saveBytes(
        bytes: bytes,
        fileName: _exportFileName(
          plan,
          'png',
          selectedDate: _selectedPlanningDate,
        ),
        mimeType: 'image/png',
      );
      _snack('Picture weekly planning tersimpan di $destination.');
    } catch (e) {
      _snack('Gagal download picture: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingPicture = false);
    }
  }

  Future<void> _downloadPdf(DetasselingPlanningData plan) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final reportImage = await _buildWeeklySummaryPng(
        plan,
        selectedDate: _selectedPlanningDate,
      );
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(reportImage),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
      final destination = await _saveBytes(
        bytes: await doc.save(),
        fileName: _exportFileName(
          plan,
          'pdf',
          selectedDate: _selectedPlanningDate,
        ),
        mimeType: 'application/pdf',
      );
      _snack('PDF weekly planning tersimpan di $destination.');
    } catch (e) {
      _snack('Gagal download PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _downloadCodetPicture(
    DetasselingPlanningData plan,
    DetasselingPlanGroup group, {
    DateTime? selectedDate,
  }) async {
    if (_isExportingPicture) return;
    setState(() => _isExportingPicture = true);
    try {
      final bytes = await _buildCodetDetailPng(
        plan,
        group,
        selectedDate: selectedDate,
      );
      final destination = await _saveBytes(
        bytes: bytes,
        fileName: _exportCodetFileName(
          plan,
          group,
          'png',
          selectedDate: selectedDate,
        ),
        mimeType: 'image/png',
      );
      _snack('Picture detail Codet tersimpan di $destination.');
    } catch (e) {
      _snack('Gagal download picture detail Codet: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingPicture = false);
    }
  }

  Future<void> _downloadCodetPdf(
    DetasselingPlanningData plan,
    DetasselingPlanGroup group, {
    DateTime? selectedDate,
  }) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final reportImage = await _buildCodetDetailPng(
        plan,
        group,
        selectedDate: selectedDate,
      );
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(reportImage),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
      final destination = await _saveBytes(
        bytes: await doc.save(),
        fileName: _exportCodetFileName(
          plan,
          group,
          'pdf',
          selectedDate: selectedDate,
        ),
        mimeType: 'application/pdf',
      );
      _snack('PDF detail Codet tersimpan di $destination.');
    } catch (e) {
      _snack('Gagal download PDF detail Codet: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<Uint8List> _buildCodetDetailPng(
    DetasselingPlanningData plan,
    DetasselingPlanGroup group, {
    DateTime? selectedDate,
  }) async {
    const width = 1200.0;
    const height = 1600.0;
    const margin = 44.0;
    const deep = Color(0xFF003B24);
    const green = Color(0xFF006B3E);
    const softGreen = Color(0xFFEAF4EC);
    const line = Color(0xFFDCE3DD);
    const ink = Color(0xFF092817);
    final reportGroup = _groupForDateFilter(group, selectedDate);
    final reportFields = reportGroup.fields;
    final dateScopeLabel = _dateFilterLabel(selectedDate);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    void drawRound(
      Rect rect,
      Color color, {
      double radius = 12,
      Color? border,
      double borderWidth = 1,
    }) {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, Paint()..color = color);
      if (border != null) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );
      }
    }

    Size drawText(
      String text,
      Offset offset, {
      required double maxWidth,
      double fontSize = 18,
      Color color = ink,
      FontWeight weight = FontWeight.w600,
      TextAlign align = TextAlign.left,
      int maxLines = 1,
      double height = 1.2,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: 'Nunito',
            fontSize: fontSize,
            fontWeight: weight,
            height: height,
          ),
        ),
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == 1 ? '...' : null,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, offset);
      return painter.size;
    }

    void drawCenteredText(
      String text,
      Rect rect, {
      double fontSize = 18,
      Color color = ink,
      FontWeight weight = FontWeight.w700,
      int maxLines = 1,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: 'Nunito',
            fontSize: fontSize,
            fontWeight: weight,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == 1 ? '...' : null,
      )..layout(maxWidth: rect.width);
      painter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - painter.width) / 2,
          rect.top + (rect.height - painter.height) / 2,
        ),
      );
    }

    void drawIcon(IconData icon, Rect rect, Color color) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            color: color,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: rect.height,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - painter.width) / 2,
          rect.top + (rect.height - painter.height) / 2,
        ),
      );
    }

    void drawBadge(
      Rect rect,
      String label, {
      Color fill = softGreen,
      Color color = green,
    }) {
      drawRound(rect, fill, radius: 8, border: color.withAlpha(80));
      drawCenteredText(
        label,
        rect,
        fontSize: 16,
        color: color,
        weight: FontWeight.w900,
      );
    }

    void drawPanelTitle(Rect rect, String title) {
      drawRound(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 42),
        deep,
        radius: 9,
      );
      drawCenteredText(
        title,
        Rect.fromLTWH(rect.left + 12, rect.top, rect.width - 24, 42),
        fontSize: 18,
        color: Colors.white,
        weight: FontWeight.w900,
      );
    }

    final raw = group.fields.isEmpty ? null : group.fields.first.parsed.raw;
    final season = _rawText(
      raw,
      const ['season', 'season_code', 'planting_season'],
    );
    final region = _rawText(raw, const ['region']);
    final generatedAt =
        DateFormat('d MMM yyyy | HH:mm', 'id_ID').format(DateTime.now());

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final logo = Rect.fromLTWH(margin, 34, 86, 86);
    drawRound(logo, deep, radius: 12);
    drawIcon(Icons.yard_rounded, logo.deflate(17), AdvantaColors.goldLight);
    drawBadge(
      Rect.fromLTWH(logo.left + 48, logo.top + 56, 30, 22),
      group.cropLabel,
      fill: green,
      color: Colors.white,
    );
    drawText(
      'WEEKLY DETASSELLING DETAIL BY CODET',
      const Offset(150, 42),
      maxWidth: 880,
      fontSize: 31,
      color: ink,
      weight: FontWeight.w900,
    );
    drawText(
      'Kroscek - ${plan.week.label} - ${group.codet} - $dateScopeLabel',
      const Offset(152, 88),
      maxWidth: 760,
      fontSize: 20,
      color: const Color(0xFF2F3C34),
      weight: FontWeight.w700,
    );
    drawText(
      plan.roleScope.displayLabel,
      const Offset(870, 92),
      maxWidth: 280,
      fontSize: 14,
      color: green,
      weight: FontWeight.w900,
      align: TextAlign.right,
    );

    final infoRect = Rect.fromLTWH(margin, 154, width - margin * 2, 170);
    drawRound(infoRect, Colors.white, radius: 12, border: line);
    final kpis = [
      (Icons.tag_rounded, 'Codet', group.codet, null),
      (Icons.location_city_rounded, 'Desa', group.village, null),
      (Icons.grass_rounded, 'Hybrid', group.hybrid, null),
      (Icons.eco_rounded, 'Crop', group.cropLabel, green),
      (
        Icons.area_chart_rounded,
        'Total DT Week',
        '${_formatHa(reportGroup.totalAreaHa)} Ha',
        green
      ),
      (Icons.spa_rounded, 'Season', season, null),
      (Icons.location_on_rounded, 'Region', region, null),
      (Icons.groups_2_rounded, 'FN', '${reportGroup.fieldCount} FN', null),
      (Icons.calendar_month_rounded, 'Week', plan.week.label, null),
      (Icons.flag_rounded, 'Pass Rule', _groupPassRule(group), green),
    ];
    final kpiW = infoRect.width / 5;
    for (var i = 0; i < kpis.length; i++) {
      final row = i ~/ 5;
      final col = i % 5;
      final left = infoRect.left + kpiW * col;
      final top = infoRect.top + 20 + row * 72;
      if (col > 0) {
        canvas.drawLine(
          Offset(left, top - 2),
          Offset(left, top + 52),
          Paint()
            ..color = line
            ..strokeWidth = 1,
        );
      }
      final accent = kpis[i].$4;
      drawIcon(kpis[i].$1, Rect.fromLTWH(left + 24, top + 8, 32, 32), deep);
      drawText(
        kpis[i].$2,
        Offset(left + 70, top),
        maxWidth: kpiW - 84,
        fontSize: 12,
        color: const Color(0xFF4B5B50),
        weight: FontWeight.w800,
      );
      drawText(
        kpis[i].$3,
        Offset(left + 70, top + 22),
        maxWidth: kpiW - 84,
        fontSize: 19,
        color: accent ?? ink,
        weight: FontWeight.w900,
      );
    }

    final dayRect = Rect.fromLTWH(margin, 350, width - margin * 2, 230);
    drawRound(dayRect, Colors.white, radius: 12, border: line);
    drawPanelTitle(
      dayRect,
      selectedDate == null
          ? 'FN BY DAY - ${plan.week.rangeLabel}'
          : 'FN BY DAY - $dateScopeLabel',
    );
    final dayW = (dayRect.width - 26) / 7;
    for (var i = 0; i < 7; i++) {
      final date = plan.week.startDate.add(Duration(days: i));
      final fields = reportFields
          .where((field) => normalizeDate(field.plannedDate) == date)
          .toList();
      final area = fields.fold(0.0, (sum, field) => sum + field.areaHa);
      final active = fields.isNotEmpty;
      final rect = Rect.fromLTWH(
        dayRect.left + 13 + dayW * i,
        dayRect.top + 60,
        dayW,
        150,
      );
      if (active) drawRound(rect.deflate(3), deep, radius: 12);
      if (i > 0) {
        canvas.drawLine(
          Offset(rect.left, rect.top + 14),
          Offset(rect.left, rect.bottom - 10),
          Paint()
            ..color = line
            ..strokeWidth = 1,
        );
      }
      final color = active ? Colors.white : ink;
      drawCenteredText(
        DateFormat('d', 'id_ID').format(date),
        Rect.fromLTWH(rect.left + 8, rect.top + 10, rect.width - 16, 30),
        fontSize: 24,
        color: color,
        weight: FontWeight.w900,
      );
      drawCenteredText(
        DateFormat('MMM', 'id_ID').format(date),
        Rect.fromLTWH(rect.left + 8, rect.top + 42, rect.width - 16, 22),
        fontSize: 14,
        color: active ? Colors.white.withAlpha(220) : ink,
        weight: FontWeight.w700,
      );
      drawCenteredText(
        fields.isEmpty
            ? '-'
            : _passLabelForDate(plan.week.startDate, date, group.crop),
        Rect.fromLTWH(rect.left + 18, rect.top + 76, rect.width - 36, 28),
        fontSize: 15,
        color: active ? Colors.white : green,
        weight: FontWeight.w900,
      );
      drawCenteredText(
        '${fields.length} FN',
        Rect.fromLTWH(rect.left + 8, rect.top + 104, rect.width - 16, 24),
        fontSize: 14,
        color: color,
        weight: FontWeight.w800,
      );
      drawCenteredText(
        '${_formatHa(area)} Ha',
        Rect.fromLTWH(rect.left + 8, rect.top + 126, rect.width - 16, 22),
        fontSize: 12,
        color: active ? AdvantaColors.lightGreen : const Color(0xFF5A665E),
        weight: FontWeight.w900,
      );
    }

    final tableRect = Rect.fromLTWH(margin, 606, width - margin * 2, 700);
    drawRound(tableRect, Colors.white, radius: 12, border: line);
    drawPanelTitle(tableRect, 'FN LIST BY CODET');
    final headers = [
      'FN Code',
      'Farmer',
      'Area',
      'Plan Date',
      'DAP',
      'Pass',
      'Status',
    ];
    final widths = [160.0, 210.0, 104.0, 134.0, 110.0, 90.0, 130.0];
    final tableLeft = tableRect.left + 24;
    final headerTop = tableRect.top + 58;
    var x = tableLeft;
    for (var i = 0; i < headers.length; i++) {
      drawText(
        headers[i],
        Offset(x + 6, headerTop),
        maxWidth: widths[i] - 12,
        fontSize: 13,
        color: ink,
        weight: FontWeight.w900,
      );
      if (i > 0) {
        canvas.drawLine(
          Offset(x, headerTop - 6),
          Offset(x, tableRect.bottom - 40),
          Paint()
            ..color = line
            ..strokeWidth = 1,
        );
      }
      x += widths[i];
    }

    final rows = reportFields.take(13).toList();
    const rowHeight = 42.0;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final field = rows[rowIndex];
      final top = headerTop + 31 + rowHeight * rowIndex;
      canvas.drawLine(
        Offset(tableRect.left + 24, top - 8),
        Offset(tableRect.right - 24, top - 8),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );
      final values = [
        field.fieldNumber.isEmpty ? '-' : field.fieldNumber,
        field.farmerName.isEmpty ? '-' : field.farmerName,
        '${_formatHa(field.areaHa)} Ha',
        DateFormat('d MMM', 'id_ID').format(field.plannedDate),
        field.dtDapRangeLabel.replaceFirst('DT ', ''),
        _passLabelForDate(plan.week.startDate, field.plannedDate, group.crop),
        field.isAssessmentDone ? 'Done' : 'Planned',
      ];
      x = tableLeft;
      for (var i = 0; i < values.length; i++) {
        if (i == 5) {
          drawBadge(
            Rect.fromLTWH(x + 14, top - 2, 56, 25),
            values[i],
            fill: group.crop == DetasselingCropFilter.sc
                ? const Color(0xFFE2E9FF)
                : const Color(0xFFDDEEE3),
            color: group.crop == DetasselingCropFilter.sc
                ? const Color(0xFF175CFF)
                : green,
          );
        } else if (i == 6) {
          canvas.drawCircle(
              Offset(x + 16, top + 10), 5, Paint()..color = green);
          drawText(
            values[i],
            Offset(x + 30, top),
            maxWidth: widths[i] - 36,
            fontSize: 13,
            color: ink,
            weight: FontWeight.w800,
          );
        } else {
          drawText(
            values[i],
            Offset(x + 8, top),
            maxWidth: widths[i] - 16,
            fontSize: 13,
            color: i == 2 ? green : ink,
            weight: i == 2 || i == 4 ? FontWeight.w900 : FontWeight.w700,
          );
        }
        x += widths[i];
      }
    }

    if (reportFields.length > rows.length) {
      drawCenteredText(
        '+${reportFields.length - rows.length} FN lainnya',
        Rect.fromLTWH(tableRect.left + 24, tableRect.bottom - 38,
            tableRect.width - 48, 24),
        fontSize: 13,
        color: const Color(0xFF5E6A62),
        weight: FontWeight.w900,
      );
    }

    final noteRect = Rect.fromLTWH(margin, 1330, width - margin * 2, 110);
    drawRound(noteRect, const Color(0xFFF0F5F1), radius: 10, border: line);
    drawIcon(
      Icons.info_outline_rounded,
      Rect.fromLTWH(noteRect.left + 24, noteRect.top + 30, 42, 42),
      green,
    );
    drawText(
      'Detail export ini hanya untuk Codet ${group.codet} ($dateScopeLabel). Overview seluruh Codet tetap tersedia dari Weekly DT Planning card.',
      Offset(noteRect.left + 82, noteRect.top + 28),
      maxWidth: noteRect.width - 112,
      fontSize: 16,
      color: ink,
      weight: FontWeight.w700,
      maxLines: 2,
      height: 1.35,
    );
    drawText(
      'Pass rule: FC P1-P3, SC P1-P5. Status Planned berarti assessment DT belum lengkap untuk semua FN.',
      Offset(noteRect.left + 82, noteRect.top + 74),
      maxWidth: noteRect.width - 112,
      fontSize: 13,
      color: const Color(0xFF516158),
      weight: FontWeight.w600,
    );

    final footerRect = Rect.fromLTWH(0, 1518, width, 82);
    canvas.drawRect(footerRect, Paint()..color = deep);
    drawText(
      'Generated by KROSCEK',
      Offset(margin, footerRect.top + 30),
      maxWidth: 290,
      fontSize: 14,
      color: Colors.white,
      weight: FontWeight.w800,
    );
    drawText(
      'Generated on: $generatedAt WIB',
      Offset(420, footerRect.top + 30),
      maxWidth: 360,
      fontSize: 14,
      color: Colors.white,
      weight: FontWeight.w600,
    );
    drawText(
      'System-generated Codet detail report.',
      Offset(840, footerRect.top + 30),
      maxWidth: 310,
      fontSize: 14,
      color: Colors.white,
      weight: FontWeight.w600,
      align: TextAlign.right,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) throw Exception('Gagal membuat report detail Codet.');
    return bytes;
  }

  Future<Uint8List> _buildWeeklySummaryPng(
    DetasselingPlanningData plan, {
    DateTime? selectedDate,
  }) async {
    const width = 1600.0;
    const height = 1120.0;
    const margin = 46.0;
    const deep = Color(0xFF003B24);
    const green = Color(0xFF006B3E);
    const softGreen = Color(0xFFEAF4EC);
    const line = Color(0xFFDCE3DD);
    const ink = Color(0xFF092817);
    final reportPlan = _planForDateFilter(plan, selectedDate);
    final dateScopeLabel = _dateFilterLabel(selectedDate);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    void drawRound(
      Rect rect,
      Color color, {
      double radius = 12,
      Color? border,
      double borderWidth = 1,
    }) {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, Paint()..color = color);
      if (border != null) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );
      }
    }

    Size drawText(
      String text,
      Offset offset, {
      required double maxWidth,
      double fontSize = 18,
      Color color = ink,
      FontWeight weight = FontWeight.w600,
      TextAlign align = TextAlign.left,
      int maxLines = 1,
      double height = 1.2,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: 'Nunito',
            fontSize: fontSize,
            fontWeight: weight,
            height: height,
          ),
        ),
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == 1 ? '...' : null,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, offset);
      return painter.size;
    }

    void drawCenteredText(
      String text,
      Rect rect, {
      double fontSize = 18,
      Color color = ink,
      FontWeight weight = FontWeight.w700,
      int maxLines = 1,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: 'Nunito',
            fontSize: fontSize,
            fontWeight: weight,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == 1 ? '...' : null,
      )..layout(maxWidth: rect.width);
      painter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - painter.width) / 2,
          rect.top + (rect.height - painter.height) / 2,
        ),
      );
    }

    void drawIcon(IconData icon, Rect rect, Color color) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            color: color,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: rect.height,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - painter.width) / 2,
          rect.top + (rect.height - painter.height) / 2,
        ),
      );
    }

    void drawPanelTitle(Rect rect, String title) {
      drawRound(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 42),
        deep,
        radius: 8,
      );
      drawCenteredText(
        title,
        Rect.fromLTWH(rect.left + 12, rect.top, rect.width - 24, 42),
        fontSize: 18,
        color: Colors.white,
        weight: FontWeight.w900,
      );
    }

    void drawBadge(
      Rect rect,
      String label, {
      Color fill = softGreen,
      Color color = green,
    }) {
      drawRound(rect, fill, radius: 7, border: color.withAlpha(80));
      drawCenteredText(
        label,
        rect,
        fontSize: 16,
        color: color,
        weight: FontWeight.w900,
      );
    }

    final season = _reportSingleValue(
      reportPlan,
      const ['season', 'season_code', 'planting_season'],
      fallback: '-',
    );
    final region = _selectedRegion ??
        _reportSingleValue(
          reportPlan,
          const ['region'],
          fallback: 'All Region',
        );
    final generatedAt =
        DateFormat('d MMM yyyy | HH:mm', 'id_ID').format(DateTime.now());
    final reportRange = selectedDate == null
        ? _reportRangeLabel(plan.week)
        : DateFormat('d MMM yyyy', 'id_ID')
            .format(normalizeDate(selectedDate))
            .toUpperCase();

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final logo = Rect.fromLTWH(margin, 28, 88, 88);
    drawRound(logo, deep, radius: 12);
    drawIcon(Icons.yard_rounded, logo.deflate(17), AdvantaColors.goldLight);
    drawBadge(
      Rect.fromLTWH(logo.left + 50, logo.top + 58, 30, 22),
      'FC',
      fill: green,
      color: Colors.white,
    );
    drawText(
      'WEEKLY DETASSELLING PLANNING SUMMARY',
      const Offset(150, 35),
      maxWidth: 1180,
      fontSize: 34,
      color: ink,
      weight: FontWeight.w900,
    );
    drawText(
      'Kroscek - Planning Week ${plan.week.label} - $dateScopeLabel',
      const Offset(152, 82),
      maxWidth: 820,
      fontSize: 20,
      color: const Color(0xFF2F3C34),
      weight: FontWeight.w600,
    );
    drawText(
      plan.roleScope.displayLabel,
      const Offset(1220, 84),
      maxWidth: 330,
      fontSize: 15,
      color: green,
      weight: FontWeight.w800,
      align: TextAlign.right,
    );

    final kpiRect = Rect.fromLTWH(margin, 132, width - margin * 2, 106);
    drawRound(kpiRect, Colors.white, radius: 10, border: line);
    final kpiW = kpiRect.width / 6;
    final kpis = [
      (Icons.calendar_month_rounded, 'Week', plan.week.label, null),
      (Icons.grass_rounded, 'Season', season, null),
      (Icons.location_on_rounded, 'Region', region, null),
      (
        Icons.description_outlined,
        'Total Plan',
        '${_formatHa(reportPlan.totalAreaHa)} Ha',
        green
      ),
      (Icons.eco_rounded, 'FC Pass Rule', 'P1-P3', green),
      (Icons.eco_rounded, 'SC Pass Rule', 'P1-P5', const Color(0xFF175CFF)),
    ];
    for (var i = 0; i < kpis.length; i++) {
      final left = kpiRect.left + kpiW * i;
      if (i > 0) {
        canvas.drawLine(
          Offset(left, kpiRect.top + 18),
          Offset(left, kpiRect.bottom - 18),
          Paint()
            ..color = line
            ..strokeWidth = 1.5,
        );
      }
      final icon = kpis[i].$1;
      final label = kpis[i].$2;
      final value = kpis[i].$3;
      final accent = kpis[i].$4;
      drawIcon(
        icon,
        Rect.fromLTWH(left + 36, kpiRect.top + 30, 42, 42),
        deep,
      );
      drawText(
        label,
        Offset(left + 92, kpiRect.top + 28),
        maxWidth: kpiW - 110,
        fontSize: 13,
        color: const Color(0xFF4B5B50),
        weight: FontWeight.w800,
      );
      if (i >= 4) {
        drawBadge(
          Rect.fromLTWH(left + 92, kpiRect.top + 58, 112, 36),
          value,
          fill: i == 4 ? const Color(0xFFDDEEE3) : const Color(0xFFE2E9FF),
          color: accent ?? green,
        );
      } else {
        drawText(
          value,
          Offset(left + 92, kpiRect.top + 50),
          maxWidth: kpiW - 110,
          fontSize: 22,
          color: accent ?? ink,
          weight: FontWeight.w900,
        );
      }
    }

    final weeklyRect = Rect.fromLTWH(margin, 258, 1000, 304);
    drawRound(weeklyRect, Colors.white, radius: 10, border: line);
    drawPanelTitle(weeklyRect, 'WEEKLY DETASSELLING PLAN ($reportRange)');
    final dayTop = weeklyRect.top + 60;
    final dayW = (weeklyRect.width - 26) / 7;
    for (var i = 0; i < reportPlan.dailySummaries.length; i++) {
      final day = reportPlan.dailySummaries[i];
      final rect = Rect.fromLTWH(
        weeklyRect.left + 13 + dayW * i,
        dayTop,
        dayW,
        weeklyRect.height - 74,
      );
      final active = selectedDate == null
          ? i == 0
          : normalizeDate(day.date) == normalizeDate(selectedDate);
      if (active) {
        drawRound(rect.deflate(2), deep, radius: 12);
      }
      if (i > 0) {
        canvas.drawLine(
          Offset(rect.left, rect.top + 24),
          Offset(rect.left, rect.bottom - 18),
          Paint()
            ..color = line
            ..strokeWidth = 1,
        );
      }
      final textColor = active ? Colors.white : ink;
      drawCenteredText(
        DateFormat('d', 'id_ID').format(day.date),
        Rect.fromLTWH(rect.left + 8, rect.top + 12, rect.width - 16, 34),
        fontSize: 26,
        color: textColor,
        weight: FontWeight.w900,
      );
      drawCenteredText(
        DateFormat('MMM', 'id_ID').format(day.date),
        Rect.fromLTWH(rect.left + 8, rect.top + 48, rect.width - 16, 24),
        fontSize: 17,
        color: active ? Colors.white.withAlpha(230) : ink,
        weight: FontWeight.w600,
      );
      drawIcon(
        Icons.yard_rounded,
        Rect.fromLTWH(rect.left + 28, rect.top + 112, 22, 22),
        active ? Colors.white : deep,
      );
      drawText(
        '${day.codetCount} Codet',
        Offset(rect.left + 58, rect.top + 111),
        maxWidth: rect.width - 66,
        fontSize: 16,
        color: textColor,
        weight: FontWeight.w700,
      );
      drawIcon(
        Icons.eco_rounded,
        Rect.fromLTWH(rect.left + 28, rect.top + 164, 22, 22),
        active ? Colors.white : deep,
      );
      drawText(
        '${_formatHa(day.areaHa)} Ha',
        Offset(rect.left + 58, rect.top + 163),
        maxWidth: rect.width - 66,
        fontSize: 16,
        color: textColor,
        weight: FontWeight.w700,
      );
    }

    final mapRect = Rect.fromLTWH(1070, 258, 484, 400);
    _drawExportMapSnapshot(
      canvas,
      mapRect,
      reportPlan,
      drawRound: drawRound,
      drawText: drawText,
      drawCenteredText: drawCenteredText,
      drawPanelTitle: drawPanelTitle,
    );

    final tableRect = Rect.fromLTWH(margin, 586, 1000, 310);
    _drawExportCodetTable(
      canvas,
      tableRect,
      reportPlan,
      drawRound: drawRound,
      drawText: drawText,
      drawCenteredText: drawCenteredText,
      drawPanelTitle: drawPanelTitle,
      drawBadge: drawBadge,
    );

    final noteRect = Rect.fromLTWH(1070, 682, 484, 214);
    drawRound(noteRect, Colors.white, radius: 10, border: line);
    drawText(
      'KETERANGAN',
      Offset(noteRect.left + 22, noteRect.top + 22),
      maxWidth: noteRect.width - 44,
      fontSize: 18,
      color: ink,
      weight: FontWeight.w900,
    );
    drawText(
      'Plan berdasarkan akumulasi Total DT berikutnya per Codet sesuai pass rule.',
      Offset(noteRect.left + 22, noteRect.top + 58),
      maxWidth: noteRect.width - 44,
      fontSize: 14,
      color: const Color(0xFF2D3C34),
      weight: FontWeight.w600,
      maxLines: 2,
      height: 1.35,
    );
    drawText(
      '• FC : Pass P1, P2, P3\n• SC : Pass P1, P2, P3, P4, P5',
      Offset(noteRect.left + 30, noteRect.top + 116),
      maxWidth: noteRect.width - 60,
      fontSize: 15,
      color: ink,
      weight: FontWeight.w700,
      maxLines: 3,
      height: 1.5,
    );

    final exportRect = Rect.fromLTWH(margin, 918, width - margin * 2, 96);
    drawRound(exportRect, const Color(0xFFF0F5F1), radius: 10, border: line);
    final iconCircle =
        Rect.fromLTWH(exportRect.left + 36, exportRect.top + 19, 58, 58);
    canvas.drawCircle(
      iconCircle.center,
      29,
      Paint()
        ..color = const Color(0xFFE1F0E6)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      iconCircle.center,
      29,
      Paint()
        ..color = green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    drawIcon(Icons.download_rounded, iconCircle.deflate(13), green);
    drawText(
      'Export your weekly plan anytime',
      Offset(exportRect.left + 118, exportRect.top + 26),
      maxWidth: 530,
      fontSize: 20,
      color: ink,
      weight: FontWeight.w900,
    );
    drawText(
      'Download this weekly DT planning summary as an image or PDF for sharing and reporting.',
      Offset(exportRect.left + 118, exportRect.top + 58),
      maxWidth: 650,
      fontSize: 13,
      color: const Color(0xFF516158),
      weight: FontWeight.w600,
    );
    void drawExportButton(Rect rect, IconData icon, String title, String sub) {
      drawRound(rect, deep, radius: 8, border: const Color(0xFF0D7A4E));
      drawIcon(icon, Rect.fromLTWH(rect.left + 24, rect.top + 24, 34, 34),
          Colors.white);
      drawText(
        title,
        Offset(rect.left + 74, rect.top + 24),
        maxWidth: rect.width - 90,
        fontSize: 16,
        color: Colors.white,
        weight: FontWeight.w900,
      );
      drawText(
        sub,
        Offset(rect.left + 74, rect.top + 50),
        maxWidth: rect.width - 90,
        fontSize: 12,
        color: Colors.white.withAlpha(205),
        weight: FontWeight.w600,
      );
    }

    drawExportButton(
      Rect.fromLTWH(exportRect.right - 670, exportRect.top + 14, 315, 68),
      Icons.image_outlined,
      'Download Picture (PNG)',
      'Export as image',
    );
    drawExportButton(
      Rect.fromLTWH(exportRect.right - 340, exportRect.top + 14, 315, 68),
      Icons.picture_as_pdf_outlined,
      'Download PDF',
      'Export as PDF document',
    );

    final footerRect = Rect.fromLTWH(0, 1042, width, 78);
    canvas.drawRect(footerRect, Paint()..color = deep);
    drawText(
      'Generated by KROSCEK',
      Offset(margin, footerRect.top + 28),
      maxWidth: 360,
      fontSize: 15,
      color: Colors.white,
      weight: FontWeight.w700,
    );
    drawText(
      'Generated on:  $generatedAt WIB',
      Offset(545, footerRect.top + 28),
      maxWidth: 430,
      fontSize: 15,
      color: Colors.white,
      weight: FontWeight.w600,
    );
    drawText(
      'This is a system-generated report. No signature required.',
      Offset(1070, footerRect.top + 28),
      maxWidth: 480,
      fontSize: 15,
      color: Colors.white,
      weight: FontWeight.w600,
      align: TextAlign.right,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) throw Exception('Gagal membuat report PNG.');
    return bytes;
  }

  void _drawExportCodetTable(
    ui.Canvas canvas,
    Rect rect,
    DetasselingPlanningData plan, {
    required void Function(
      Rect rect,
      Color color, {
      double radius,
      Color? border,
      double borderWidth,
    }) drawRound,
    required Size Function(
      String text,
      Offset offset, {
      required double maxWidth,
      double fontSize,
      Color color,
      FontWeight weight,
      TextAlign align,
      int maxLines,
      double height,
    }) drawText,
    required void Function(
      String text,
      Rect rect, {
      double fontSize,
      Color color,
      FontWeight weight,
      int maxLines,
    }) drawCenteredText,
    required void Function(Rect rect, String title) drawPanelTitle,
    required void Function(
      Rect rect,
      String label, {
      Color fill,
      Color color,
    }) drawBadge,
  }) {
    const green = Color(0xFF006B3E);
    const line = Color(0xFFDCE3DD);
    const ink = Color(0xFF092817);

    drawRound(rect, Colors.white, radius: 10, border: line);
    drawPanelTitle(rect, 'DETASSELLING PLAN BY CODET');
    final headerTop = rect.top + 54;
    final tableLeft = rect.left + 18;
    final colWidths = [128.0, 150.0, 96.0, 156.0, 206.0, 120.0, 104.0];
    final headers = [
      'Codet',
      'Desa',
      'Crop',
      'Hybrid',
      'Total DT Next Week (Ha)',
      'Pass Rule',
      'Status',
    ];

    var x = tableLeft;
    for (var i = 0; i < headers.length; i++) {
      drawText(
        headers[i],
        Offset(x + 6, headerTop),
        maxWidth: colWidths[i] - 12,
        fontSize: 12,
        color: ink,
        weight: FontWeight.w900,
        align: i >= 4 ? TextAlign.center : TextAlign.left,
      );
      if (i > 0) {
        canvas.drawLine(
          Offset(x, rect.top + 52),
          Offset(x, rect.bottom - 16),
          Paint()
            ..color = line
            ..strokeWidth = 1,
        );
      }
      x += colWidths[i];
    }

    final rows = plan.groups.take(5).toList();
    const rowHeight = 42.0;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final group = rows[rowIndex];
      final top = headerTop + 28 + rowHeight * rowIndex;
      canvas.drawLine(
        Offset(rect.left + 18, top - 8),
        Offset(rect.right - 18, top - 8),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );

      x = tableLeft;
      drawText(
        group.codet,
        Offset(x + 6, top + 3),
        maxWidth: colWidths[0] - 44,
        fontSize: 13,
        color: ink,
        weight: FontWeight.w800,
      );
      drawBadge(
        Rect.fromLTWH(x + colWidths[0] - 38, top, 32, 22),
        group.cropLabel,
        fill: group.crop == DetasselingCropFilter.sc
            ? const Color(0xFFE2E9FF)
            : const Color(0xFFDDEEE3),
        color: group.crop == DetasselingCropFilter.sc
            ? const Color(0xFF175CFF)
            : green,
      );
      x += colWidths[0];
      drawText(
        group.village,
        Offset(x + 8, top + 3),
        maxWidth: colWidths[1] - 16,
        fontSize: 13,
        color: ink,
        weight: FontWeight.w700,
      );
      x += colWidths[1];
      drawBadge(
        Rect.fromLTWH(x + 28, top, 44, 24),
        group.cropLabel,
        fill: group.crop == DetasselingCropFilter.sc
            ? const Color(0xFFE2E9FF)
            : const Color(0xFFDDEEE3),
        color: group.crop == DetasselingCropFilter.sc
            ? const Color(0xFF175CFF)
            : green,
      );
      x += colWidths[2];
      drawText(
        group.hybrid,
        Offset(x + 8, top + 3),
        maxWidth: colWidths[3] - 16,
        fontSize: 13,
        color: ink,
        weight: FontWeight.w700,
      );
      x += colWidths[3];
      drawCenteredText(
        '${_formatHa(group.totalAreaHa)} Ha',
        Rect.fromLTWH(x, top - 2, colWidths[4], 30),
        fontSize: 16,
        color: green,
        weight: FontWeight.w900,
      );
      x += colWidths[4];
      drawBadge(
        Rect.fromLTWH(x + 12, top - 1, 86, 26),
        _groupPassRule(group),
        fill: group.crop == DetasselingCropFilter.sc
            ? const Color(0xFFE2E9FF)
            : const Color(0xFFDDEEE3),
        color: group.crop == DetasselingCropFilter.sc
            ? const Color(0xFF175CFF)
            : green,
      );
      x += colWidths[5];
      final status = _exportStatusLabel(group.status);
      canvas.drawCircle(
        Offset(x + 18, top + 12),
        5,
        Paint()..color = green,
      );
      drawText(
        status,
        Offset(x + 32, top + 3),
        maxWidth: colWidths[6] - 38,
        fontSize: 13,
        color: ink,
        weight: FontWeight.w800,
      );
    }

    if (plan.groups.length > rows.length) {
      drawCenteredText(
        '+${plan.groups.length - rows.length} Codet lainnya',
        Rect.fromLTWH(rect.left + 20, rect.bottom - 34, rect.width - 40, 22),
        fontSize: 12,
        color: const Color(0xFF5E6A62),
        weight: FontWeight.w800,
      );
    }
  }

  void _drawExportMapSnapshot(
    ui.Canvas canvas,
    Rect rect,
    DetasselingPlanningData plan, {
    required void Function(
      Rect rect,
      Color color, {
      double radius,
      Color? border,
      double borderWidth,
    }) drawRound,
    required Size Function(
      String text,
      Offset offset, {
      required double maxWidth,
      double fontSize,
      Color color,
      FontWeight weight,
      TextAlign align,
      int maxLines,
      double height,
    }) drawText,
    required void Function(
      String text,
      Rect rect, {
      double fontSize,
      Color color,
      FontWeight weight,
      int maxLines,
    }) drawCenteredText,
    required void Function(Rect rect, String title) drawPanelTitle,
  }) {
    const green = Color(0xFF0E8F57);
    const line = Color(0xFFDCE3DD);

    drawRound(rect, Colors.white, radius: 10, border: line);
    drawPanelTitle(rect, 'PLANNING AREA SNAPSHOT');
    final map =
        Rect.fromLTWH(rect.left, rect.top + 42, rect.width, rect.height - 42);
    final clip = RRect.fromRectAndRadius(map, const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(map, Paint()..color = const Color(0xFF174B22));

    for (var i = 0; i < 22; i++) {
      final y = map.top + i * (map.height / 21);
      canvas.drawLine(
        Offset(map.left, y),
        Offset(map.right, y + 28),
        Paint()
          ..color = Colors.white.withAlpha(18)
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < 16; i++) {
      final x = map.left + i * (map.width / 15);
      canvas.drawLine(
        Offset(x, map.top),
        Offset(x - 30, map.bottom),
        Paint()
          ..color = const Color(0xFF9DC16E).withAlpha(36)
          ..strokeWidth = 1,
      );
    }
    canvas.drawPath(
      ui.Path()
        ..moveTo(map.right - 92, map.top)
        ..quadraticBezierTo(
            map.right - 35, map.top + 94, map.right - 88, map.bottom)
        ..lineTo(map.right, map.bottom)
        ..lineTo(map.right, map.top)
        ..close(),
      Paint()..color = const Color(0xFF1E88B6).withAlpha(205),
    );

    final groups = plan.groups;
    if (groups.isNotEmpty) {
      var minLat = groups.first.center.latitude;
      var maxLat = minLat;
      var minLng = groups.first.center.longitude;
      var maxLng = minLng;
      for (final group in groups) {
        minLat = math.min(minLat, group.center.latitude);
        maxLat = math.max(maxLat, group.center.latitude);
        minLng = math.min(minLng, group.center.longitude);
        maxLng = math.max(maxLng, group.center.longitude);
      }
      final latRange = (maxLat - minLat).abs() < 0.0001 ? 1.0 : maxLat - minLat;
      final lngRange = (maxLng - minLng).abs() < 0.0001 ? 1.0 : maxLng - minLng;
      final insetMap = map.deflate(52);

      final largest = groups.reduce(
        (a, b) => a.fieldCount >= b.fieldCount ? a : b,
      );
      final largestX = insetMap.left +
          ((largest.center.longitude - minLng) / lngRange).clamp(0.12, 0.88) *
              insetMap.width;
      final largestY = insetMap.bottom -
          ((largest.center.latitude - minLat) / latRange).clamp(0.12, 0.88) *
              insetMap.height;
      canvas.drawPath(
        ui.Path()
          ..moveTo(largestX - 48, largestY - 8)
          ..lineTo(largestX - 4, largestY - 52)
          ..lineTo(largestX + 58, largestY - 18)
          ..lineTo(largestX + 40, largestY + 54)
          ..lineTo(largestX - 36, largestY + 34)
          ..close(),
        Paint()
          ..color = Colors.white.withAlpha(48)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        ui.Path()
          ..moveTo(largestX - 48, largestY - 8)
          ..lineTo(largestX - 4, largestY - 52)
          ..lineTo(largestX + 58, largestY - 18)
          ..lineTo(largestX + 40, largestY + 54)
          ..lineTo(largestX - 36, largestY + 34)
          ..close(),
        Paint()
          ..color = Colors.white.withAlpha(190)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      for (var i = 0; i < math.min(groups.length, 8); i++) {
        final group = groups[i];
        final x = insetMap.left +
            ((group.center.longitude - minLng) / lngRange).clamp(0.08, 0.92) *
                insetMap.width;
        final y = insetMap.bottom -
            ((group.center.latitude - minLat) / latRange).clamp(0.08, 0.92) *
                insetMap.height;
        final markerColor = i == 0
            ? green
            : i % 4 == 0
                ? AdvantaColors.gold
                : i % 3 == 0
                    ? const Color(0xFFFF7D1C)
                    : const Color(0xFF155E37);
        canvas.drawCircle(
          Offset(x, y),
          20,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          17,
          Paint()
            ..color = markerColor
            ..style = PaintingStyle.fill,
        );
        drawCenteredText(
          group.fieldCount.toString(),
          Rect.fromCenter(center: Offset(x, y), width: 34, height: 24),
          fontSize: 14,
          color: Colors.white,
          weight: FontWeight.w900,
        );
      }
    } else {
      drawCenteredText(
        'No planning area',
        map,
        fontSize: 18,
        color: Colors.white,
        weight: FontWeight.w800,
      );
    }
    canvas.restore();
  }

  String _reportSingleValue(
    DetasselingPlanningData plan,
    List<String> keys, {
    String fallback = '-',
    String multipleLabel = 'Multiple',
  }) {
    final values = <String>{};
    for (final group in plan.groups) {
      for (final field in group.fields) {
        for (final key in keys) {
          final value = field.parsed.raw[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) values.add(value);
        }
      }
    }
    if (values.isEmpty) return fallback;
    if (values.length == 1) return values.first;
    return multipleLabel;
  }

  String _reportRangeLabel(DetasselingWeekOption week) {
    if (week.startDate.month == week.endDate.month) {
      return '${week.startDate.day}-${DateFormat('d MMM yyyy', 'id_ID').format(week.endDate)}'
          .toUpperCase();
    }
    return '${DateFormat('d MMM', 'id_ID').format(week.startDate)}-${DateFormat('d MMM yyyy', 'id_ID').format(week.endDate)}'
        .toUpperCase();
  }

  String _groupPassRule(DetasselingPlanGroup group) {
    return group.crop == DetasselingCropFilter.sc ? 'P1-P5' : 'P1-P3';
  }

  String _exportStatusLabel(DetasselingGroupStatus status) {
    return status == DetasselingGroupStatus.done ? 'Done' : 'Planned';
  }

  Future<String> _saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = io.File(p.join(tempDir.path, fileName));
    await tempFile.writeAsBytes(bytes, flush: true);

    if (io.Platform.isAndroid) {
      try {
        MediaStore.appFolder = 'Kroscek';
        await MediaStore.ensureInitialized();
        final saved = await MediaStore().saveFile(
          tempFilePath: tempFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        if (saved == null) {
          throw Exception('MediaStore tidak mengembalikan lokasi file.');
        }
        return 'Download/Kroscek/$fileName';
      } catch (e) {
        final fallback = await _saveToAppDocuments(bytes, fileName);
        await OpenFile.open(fallback.path);
        return 'Documents/${fallback.uri.pathSegments.last} ($mimeType)';
      }
    }

    final downloadDir = await _downloadDirectory();
    final outputFile = io.File(p.join(downloadDir.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    await OpenFile.open(outputFile.path);
    return outputFile.path;
  }

  Future<io.File> _saveToAppDocuments(Uint8List bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDir = io.Directory(p.join(directory.path, 'exports'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    final outputFile = io.File(p.join(outputDir.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  Future<io.Directory> _downloadDirectory() async {
    if (io.Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  String _exportFileName(
    DetasselingPlanningData plan,
    String extension, {
    DateTime? selectedDate,
  }) {
    final stamp = _dateFilterSuffix(selectedDate);
    return 'weekly_dt_summary_${plan.week.label}_$stamp.$extension';
  }

  String _exportCodetFileName(
    DetasselingPlanningData plan,
    DetasselingPlanGroup group,
    String extension, {
    DateTime? selectedDate,
  }) {
    final stamp = _dateFilterSuffix(selectedDate);
    final codet = _safeFilePart(group.codet);
    return 'weekly_dt_codet_${plan.week.label}_${codet}_$stamp.$extension';
  }

  String _safeFilePart(String value) {
    final safe = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'codet' : safe;
  }

  void _showGroupDetail(
    DetasselingPlanningData plan,
    DetasselingPlanGroup group,
  ) {
    setState(() => _selectedGroupKey = group.key);
    _fitGroup(group);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CodetDetailSheet(
        week: plan.week,
        group: group,
        initialDate: _selectedPlanningDate,
        onFieldTap: _openFieldDetail,
        onOpenInspection: (fields) => _openCodetMassInspection(
          group,
          fieldsOverride: fields,
        ),
        onDownloadPicture: (date) => _downloadCodetPicture(
          plan,
          group,
          selectedDate: date,
        ),
        onDownloadPdf: (date) => _downloadCodetPdf(
          plan,
          group,
          selectedDate: date,
        ),
      ),
    );
  }

  void _openCodetMassInspection(
    DetasselingPlanGroup group, {
    List<DetasselingPlanField>? fieldsOverride,
  }) {
    final fields = fieldsOverride ?? group.fields;
    final fieldNumbers = fields
        .map((field) => field.fieldNumber.trim())
        .where((fieldNumber) => fieldNumber.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (fieldNumbers.isEmpty) {
      _snack('Tidak ada FN valid untuk mass inspection.', isError: true);
      return;
    }

    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      context.push(
        '/inspect/mass',
        extra: {
          'fieldNumbers': fieldNumbers,
          'phase': _massInspectionPhaseForCodet(group),
        },
      );
    });
  }

  String _massInspectionPhaseForCodet(DetasselingPlanGroup group) {
    return group.crop == DetasselingCropFilter.sc
        ? 'generative_5'
        : 'generative_3';
  }

  void _openFieldDetail(DetasselingPlanField field) {
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      FieldDetailBottomSheet.show(
        context,
        field.parsed.raw,
        onInspectDone: _handleInspectDone,
      );
    });
  }

  void _handleInspectDone(Map<String, dynamic> fieldData) {
    ref.invalidate(masterFieldsProvider);
    ref.invalidate(parsedMapFieldsProvider);
    setState(() {});
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AdvantaColors.error : AdvantaColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _PlanningHeader extends StatelessWidget {
  final DetasselingPlanningData plan;
  final String dateLabel;
  final bool exportingPicture;
  final bool exportingPdf;
  final VoidCallback onPicture;
  final VoidCallback onPdf;

  const _PlanningHeader({
    required this.plan,
    required this.dateLabel,
    required this.exportingPicture,
    required this.exportingPdf,
    required this.onPicture,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AdvantaColors.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.yard_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly DT Planning',
                  style: AdvantaText.bodyBold.copyWith(
                    color: AdvantaColors.deepForest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$dateLabel • ${plan.codetCount} Codet • ${plan.plannedFieldCount} FN • ${_formatHa(plan.totalAreaHa)} Ha',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.mutedGrey,
                  ),
                ),
                Text(
                  plan.roleScope.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.primaryGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _ExportIconButton(
            icon: Icons.image_outlined,
            tooltip: 'Download Picture',
            busy: exportingPicture,
            onTap: onPicture,
          ),
          const SizedBox(width: 4),
          _ExportIconButton(
            icon: Icons.picture_as_pdf_outlined,
            tooltip: 'Download PDF',
            busy: exportingPdf,
            onTap: onPdf,
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DetasselingDailySummary summary;
  final bool selected;
  final VoidCallback onTap;

  const _DayTile({
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlan = summary.codetCount > 0;
    final primaryText = selected
        ? Colors.white
        : hasPlan
            ? AdvantaColors.primaryGreen
            : AdvantaColors.mutedGrey;
    final bodyText = selected ? Colors.white : AdvantaColors.deepForest;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          decoration: BoxDecoration(
            gradient: selected
                ? null
                : hasPlan
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFEAF7F0),
                          Color(0xFFFFF8E1),
                        ],
                      )
                    : null,
            color: selected
                ? AdvantaColors.primaryGreen
                : (hasPlan ? null : Colors.white),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? AdvantaColors.goldLight
                  : hasPlan
                      ? AdvantaColors.primaryGreen.withAlpha(105)
                      : AdvantaColors.dividerGrey,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEE', 'id_ID')
                          .format(summary.date)
                          .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.caption.copyWith(
                        color:
                            selected ? Colors.white70 : AdvantaColors.mutedGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withAlpha(30)
                          : hasPlan
                              ? AdvantaColors.primaryGreen.withAlpha(22)
                              : AdvantaColors.softGrey,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      DateFormat('d', 'id_ID').format(summary.date),
                      style: AdvantaText.caption.copyWith(
                        color: bodyText,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Text(
                  summary.codetCount.toString(),
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 24,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Codet',
                textAlign: TextAlign.center,
                style: AdvantaText.caption.copyWith(
                  color: bodyText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withAlpha(selected ? 34 : (hasPlan ? 180 : 120)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_formatHa(summary.areaHa)} Ha',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AdvantaText.caption.copyWith(
                    color: selected ? Colors.white : AdvantaColors.charcoal,
                    fontSize: 10,
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

class _AllDayTile extends StatelessWidget {
  final DetasselingPlanningData plan;
  final bool selected;
  final VoidCallback onTap;

  const _AllDayTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bodyText = selected ? Colors.white : AdvantaColors.deepForest;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          decoration: BoxDecoration(
            color: selected ? AdvantaColors.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? AdvantaColors.goldLight
                  : AdvantaColors.dividerGrey,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ALL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdvantaText.caption.copyWith(
                  color: selected ? Colors.white70 : AdvantaColors.mutedGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  plan.codetCount.toString(),
                  style: TextStyle(
                    color: selected ? Colors.white : AdvantaColors.primaryGreen,
                    fontSize: 24,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Codet',
                textAlign: TextAlign.center,
                style: AdvantaText.caption.copyWith(
                  color: bodyText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(selected ? 34 : 150),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_formatHa(plan.totalAreaHa)} Ha',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AdvantaText.caption.copyWith(
                    color: selected ? Colors.white : AdvantaColors.charcoal,
                    fontSize: 10,
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

class _CodetSummaryRow extends StatelessWidget {
  final DetasselingPlanGroup group;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  const _CodetSummaryRow({
    required this.group,
    required this.isSelected,
    required this.onTap,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = group.status == DetasselingGroupStatus.done
        ? AdvantaColors.success
        : AdvantaColors.gold;
    return Material(
      color: isSelected ? AdvantaColors.goldPale : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AdvantaColors.gold.withAlpha(180)
                  : AdvantaColors.dividerGrey,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.codet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdvantaText.bodyBold.copyWith(
                              color: AdvantaColors.deepForest,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _MiniBadge(
                          label: group.cropLabel,
                          color: group.crop == DetasselingCropFilter.sc
                              ? AdvantaColors.gold
                              : AdvantaColors.primaryGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.village} • ${group.hybrid}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.caption.copyWith(
                        color: AdvantaColors.mutedGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _InfoBadge(
                          label: '${_formatHa(group.totalAreaHa)} Ha',
                          icon: Icons.area_chart_rounded,
                        ),
                        _InfoBadge(
                          label: '${group.fieldCount} FN',
                          icon: Icons.tag_rounded,
                        ),
                        _MiniBadge(
                            label: group.statusLabel, color: statusColor),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open Weekly Detail',
                onPressed: onDetail,
                icon: const Icon(Icons.open_in_new_rounded),
                color: AdvantaColors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodetDetailSheet extends StatefulWidget {
  final DetasselingWeekOption week;
  final DetasselingPlanGroup group;
  final DateTime? initialDate;
  final ValueChanged<DetasselingPlanField> onFieldTap;
  final ValueChanged<List<DetasselingPlanField>> onOpenInspection;
  final Future<void> Function(DateTime? selectedDate)? onDownloadPicture;
  final Future<void> Function(DateTime? selectedDate)? onDownloadPdf;

  const _CodetDetailSheet({
    required this.week,
    required this.group,
    required this.initialDate,
    required this.onFieldTap,
    required this.onOpenInspection,
    required this.onDownloadPicture,
    required this.onDownloadPdf,
  });

  @override
  State<_CodetDetailSheet> createState() => _CodetDetailSheetState();
}

class _CodetDetailSheetState extends State<_CodetDetailSheet> {
  DateTime? _selectedDate;
  bool _exportingPicture = false;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _initialSelectedDate();
  }

  @override
  void didUpdateWidget(covariant _CodetDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.key != widget.group.key ||
        oldWidget.week.startDate != widget.week.startDate) {
      _selectedDate = _initialSelectedDate();
    }
  }

  DateTime? _initialSelectedDate() {
    final initial = widget.initialDate;
    if (initial == null) return null;
    final normalized = normalizeDate(initial);
    final start = normalizeDate(widget.week.startDate);
    final end = normalizeDate(widget.week.endDate);
    if (normalized.isBefore(start) || normalized.isAfter(end)) return null;
    return normalized;
  }

  List<DateTime> get _weekDays => List.generate(
        7,
        (index) => widget.week.startDate.add(Duration(days: index)),
      );

  List<DetasselingPlanField> _fieldsFor(DateTime? day) {
    if (day == null) return widget.group.fields;
    final date = normalizeDate(day);
    return widget.group.fields
        .where((field) => normalizeDate(field.plannedDate) == date)
        .toList();
  }

  bool _isSelectedDay(DateTime day) {
    final selectedDate = _selectedDate;
    return selectedDate != null && normalizeDate(day) == selectedDate;
  }

  String get _selectedDateLabel {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return 'All Date';
    return DateFormat('d MMM', 'id_ID').format(selectedDate);
  }

  double _areaFor(List<DetasselingPlanField> fields) =>
      fields.fold(0, (sum, field) => sum + field.areaHa);

  Future<void> _handlePictureExport() async {
    final callback = widget.onDownloadPicture;
    if (callback == null || _exportingPicture) return;
    setState(() => _exportingPicture = true);
    try {
      await callback(_selectedDate);
    } finally {
      if (mounted) setState(() => _exportingPicture = false);
    }
  }

  Future<void> _handlePdfExport() async {
    final callback = widget.onDownloadPdf;
    if (callback == null || _exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      await callback(_selectedDate);
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFields = _fieldsFor(_selectedDate);
    final raw = widget.group.fields.isEmpty
        ? null
        : widget.group.fields.first.parsed.raw;
    final season = _rawText(
      raw,
      const ['season', 'season_code', 'planting_season'],
    );
    final region = _rawText(raw, const ['region']);

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF032B1D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: _buildTopBar(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildSummaryCard(season: season, region: region),
                      const SizedBox(height: 12),
                      _buildDaySelector(),
                      const SizedBox(height: 12),
                      _buildDayMetric(selectedFields),
                      const SizedBox(height: 12),
                      _buildFnTable(selectedFields),
                      const SizedBox(height: 12),
                      _buildInfoNote(),
                      const SizedBox(height: 16),
                      _buildActions(selectedFields),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Kembali',
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Detail',
                style: AdvantaText.heading2.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.group.codet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdvantaText.body2.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Action',
          color: const Color(0xFF073A28),
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            if (value == 'picture') _handlePictureExport();
            if (value == 'pdf') _handlePdfExport();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'picture',
              child: Text(
                'Download Picture',
                style: AdvantaText.body2.copyWith(color: Colors.white),
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: Text(
                'Download PDF',
                style: AdvantaText.body2.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String season,
    required String region,
  }) {
    return _DetailPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(22)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.yard_rounded,
                      color: AdvantaColors.goldLight,
                      size: 42,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _MiniBadge(
                        label: widget.group.cropLabel,
                        color: AdvantaColors.lightGreen,
                        dark: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.codet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailSummaryMetric(
                            label: 'Desa',
                            value: widget.group.village,
                          ),
                        ),
                        _DetailDivider(),
                        Expanded(
                          child: _DetailSummaryMetric(
                            label: 'Hybrid',
                            value: widget.group.hybrid,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailSummaryMetric(
                  label: 'Crop',
                  value: widget.group.cropLabel,
                ),
              ),
              _DetailDivider(),
              Expanded(
                child: _DetailSummaryMetric(
                  label: 'Total DT Week',
                  value: '${_formatHa(widget.group.totalAreaHa)} Ha',
                  valueColor: AdvantaColors.lightGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailSummaryMetric(label: 'Season', value: season),
              ),
              _DetailDivider(),
              Expanded(
                child: _DetailSummaryMetric(label: 'Region', value: region),
              ),
              _DetailDivider(),
              Expanded(
                child: _DetailSummaryMetric(
                  label: 'Week',
                  value: widget.week.label,
                ),
              ),
              _DetailDivider(),
              Expanded(
                child: _DetailSummaryMetric(
                  label: 'Status',
                  value: _detailStatusLabel(widget.group.status),
                  valueColor: widget.group.status == DetasselingGroupStatus.done
                      ? AdvantaColors.lightGreen
                      : Colors.white,
                  chip: widget.group.status != DetasselingGroupStatus.done,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return _DetailPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'FN by Day',
                  style: AdvantaText.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(24)),
                ),
                child: Text(
                  widget.week.label,
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.lightGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final useCompactCarousel = constraints.maxWidth < 560;
              final cardWidth = useCompactCarousel
                  ? 92.0
                  : (constraints.maxWidth - gap * 7) / 8;
              final allFields = _fieldsFor(null);

              return SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _weekDays.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: gap),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return SizedBox(
                        width: cardWidth,
                        child: _DetailAllDayChip(
                          selected: _selectedDate == null,
                          fnCount: allFields.length,
                          areaHa: _areaFor(allFields),
                          onTap: () => setState(() => _selectedDate = null),
                        ),
                      );
                    }
                    final day = _weekDays[index - 1];
                    final fields = _fieldsFor(day);
                    return SizedBox(
                      width: cardWidth,
                      child: _DetailDayChip(
                        date: day,
                        selected: _isSelectedDay(day),
                        passLabel: fields.isEmpty
                            ? '-'
                            : _passLabelForDate(
                                widget.week.startDate,
                                day,
                                widget.group.crop,
                              ),
                        fnCount: fields.length,
                        areaHa: _areaFor(fields),
                        onTap: () => setState(
                          () => _selectedDate = normalizeDate(day),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayMetric(List<DetasselingPlanField> selectedFields) {
    return _DetailPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _DetailInlineStat(
              icon: Icons.calendar_month_rounded,
              value: _selectedDateLabel,
            ),
          ),
          _DetailDivider(height: 30),
          Expanded(
            child: _DetailInlineStat(
              icon: Icons.groups_2_rounded,
              value: '${selectedFields.length} FN',
            ),
          ),
          _DetailDivider(height: 30),
          Expanded(
            child: _DetailInlineStat(
              icon: Icons.eco_rounded,
              value: '${_formatHa(_areaFor(selectedFields))} Ha',
              valueColor: AdvantaColors.lightGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFnTable(List<DetasselingPlanField> selectedFields) {
    return _DetailPanel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FN List - $_selectedDateLabel',
            style: AdvantaText.heading3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (selectedFields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Tidak ada FN pada tanggal ini.',
                  style: AdvantaText.body2.copyWith(color: Colors.white70),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 560,
                  child: Column(
                    children: [
                      const _DetailFnHeader(),
                      for (final field in selectedFields)
                        _DetailFnRow(
                          field: field,
                          passLabel: _passLabelForDate(
                            widget.week.startDate,
                            field.plannedDate,
                            widget.group.crop,
                          ),
                          onTap: () => widget.onFieldTap(field),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return _DetailPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For FC, detasseling pass recommendation is staggered every +2 days (P1, P2, P3). For SC, it continues to P4 and P5 every +2 days.',
              style: AdvantaText.body2.copyWith(
                color: Colors.white.withAlpha(205),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(List<DetasselingPlanField> selectedFields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final halfWidth = (constraints.maxWidth - 8) / 2;
        final hasFields = selectedFields.isNotEmpty;
        final picture = SizedBox(
          width: compact ? halfWidth : (constraints.maxWidth - 16) * 0.34,
          child: _DetailActionButton(
            icon: Icons.image_outlined,
            title: 'Download Picture',
            subtitle: _selectedDate == null ? 'Export all date' : 'Export PNG',
            busy: _exportingPicture,
            onTap: widget.onDownloadPicture == null || !hasFields
                ? null
                : () => unawaited(_handlePictureExport()),
          ),
        );
        final pdf = SizedBox(
          width: compact ? halfWidth : (constraints.maxWidth - 16) * 0.32,
          child: _DetailActionButton(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Download PDF',
            subtitle: _selectedDate == null ? 'Export all date' : 'Export PDF',
            busy: _exportingPdf,
            onTap: widget.onDownloadPdf == null || !hasFields
                ? null
                : () => unawaited(_handlePdfExport()),
          ),
        );
        final inspection = SizedBox(
          width: compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 16) * 0.34,
          child: _DetailActionButton(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Mass Inspection',
            subtitle: '${selectedFields.length} FN',
            filled: true,
            onTap: hasFields
                ? () => widget.onOpenInspection(selectedFields)
                : null,
          ),
        );

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [picture, pdf, inspection],
        );
      },
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DetailPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF074129).withAlpha(215),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: child,
    );
  }
}

class _DetailSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool chip;

  const _DetailSummaryMetric({
    required this.label,
    required this.value,
    this.valueColor,
    this.chip = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      value.isEmpty ? '-' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AdvantaText.bodyBold.copyWith(
        color: valueColor ?? Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdvantaText.caption.copyWith(color: Colors.white60),
        ),
        const SizedBox(height: 4),
        if (chip)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AdvantaColors.lightGreen.withAlpha(70),
                borderRadius: BorderRadius.circular(999),
              ),
              child: valueWidget,
            ),
          )
        else
          valueWidget,
      ],
    );
  }
}

class _DetailDivider extends StatelessWidget {
  final double height;

  const _DetailDivider({this.height = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withAlpha(24),
    );
  }
}

class _DetailAllDayChip extends StatelessWidget {
  final bool selected;
  final int fnCount;
  final double areaHa;
  final VoidCallback onTap;

  const _DetailAllDayChip({
    required this.selected,
    required this.fnCount,
    required this.areaHa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AdvantaColors.deepForest : Colors.white;
    final muted = selected
        ? AdvantaColors.deepForest.withAlpha(170)
        : Colors.white.withAlpha(178);
    final badgeColor =
        selected ? AdvantaColors.primaryGreen : AdvantaColors.lightGreen;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color:
                selected ? const Color(0xFFEAF7F0) : Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AdvantaColors.lightGreen
                  : Colors.white.withAlpha(20),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ALL DATE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.caption.copyWith(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(selected ? 36 : 80),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'All',
                      style: AdvantaText.caption.copyWith(
                        color: selected ? badgeColor : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'All',
                textAlign: TextAlign.center,
                style: AdvantaText.heading2.copyWith(
                  color: fg,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Date',
                textAlign: TextAlign.center,
                style: AdvantaText.caption.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withAlpha(175)
                      : Colors.black.withAlpha(28),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_2_rounded, size: 12, color: muted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '$fnCount FN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdvantaText.caption.copyWith(
                              color: fg,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_formatHa(areaHa)} Ha',
                        maxLines: 1,
                        style: AdvantaText.caption.copyWith(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailDayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final String passLabel;
  final int fnCount;
  final double areaHa;
  final VoidCallback onTap;

  const _DetailDayChip({
    required this.date,
    required this.selected,
    required this.passLabel,
    required this.fnCount,
    required this.areaHa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPass = passLabel != '-';
    final fg = selected ? AdvantaColors.deepForest : Colors.white;
    final muted = selected
        ? AdvantaColors.deepForest.withAlpha(170)
        : Colors.white.withAlpha(178);
    final badgeColor =
        selected ? AdvantaColors.primaryGreen : AdvantaColors.lightGreen;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF7F0)
                : hasPass
                    ? Colors.white.withAlpha(13)
                    : Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AdvantaColors.lightGreen
                  : Colors.white.withAlpha(20),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEE', 'id_ID').format(date).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.caption.copyWith(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: hasPass
                          ? badgeColor.withAlpha(selected ? 36 : 80)
                          : Colors.white.withAlpha(selected ? 80 : 12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      passLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.caption.copyWith(
                        color: hasPass
                            ? (selected ? badgeColor : Colors.white)
                            : muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('d', 'id_ID').format(date),
                textAlign: TextAlign.center,
                style: AdvantaText.heading2.copyWith(
                  color: fg,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                DateFormat('MMM', 'id_ID').format(date),
                textAlign: TextAlign.center,
                style: AdvantaText.caption.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withAlpha(175)
                      : Colors.black.withAlpha(28),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.groups_2_rounded,
                          size: 12,
                          color: muted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '$fnCount FN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdvantaText.caption.copyWith(
                              color: fg,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_formatHa(areaHa)} Ha',
                        maxLines: 1,
                        style: AdvantaText.caption.copyWith(
                          color: hasPass ? badgeColor : muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailInlineStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? valueColor;

  const _DetailInlineStat({
    required this.icon,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withAlpha(198), size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.heading3.copyWith(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailFnHeader extends StatelessWidget {
  const _DetailFnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: const [
          _DetailFnCell('FN Code', width: 110, muted: true),
          _DetailFnCell('Farmer', width: 112, muted: true),
          _DetailFnCell('Area', width: 74, muted: true),
          _DetailFnCell('Est. Date', width: 84, muted: true),
          _DetailFnCell('Status', width: 92, muted: true),
          _DetailFnCell('Pass', width: 58, muted: true),
        ],
      ),
    );
  }
}

class _DetailFnRow extends StatelessWidget {
  final DetasselingPlanField field;
  final String passLabel;
  final VoidCallback onTap;

  const _DetailFnRow({
    required this.field,
    required this.passLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = field.isAssessmentDone;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withAlpha(16)),
            ),
          ),
          child: Row(
            children: [
              _DetailFnCell(field.fieldNumber.isEmpty ? '-' : field.fieldNumber,
                  width: 110),
              _DetailFnCell(field.farmerName.isEmpty ? '-' : field.farmerName,
                  width: 112),
              _DetailFnCell('${_formatHa(field.areaHa)} Ha',
                  width: 74, accent: true),
              _DetailFnCell(
                DateFormat('d MMM', 'id_ID').format(field.plannedDate),
                width: 84,
              ),
              SizedBox(
                width: 92,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _MiniBadge(
                    label: done ? 'Done' : 'Planned',
                    color: AdvantaColors.lightGreen,
                    dark: true,
                  ),
                ),
              ),
              SizedBox(
                width: 58,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _MiniBadge(
                    label: passLabel,
                    color: AdvantaColors.lightGreen,
                    dark: true,
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

class _DetailFnCell extends StatelessWidget {
  final String text;
  final double width;
  final bool muted;
  final bool accent;

  const _DetailFnCell(
    this.text, {
    required this.width,
    this.muted = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (muted ? AdvantaText.caption : AdvantaText.body2).copyWith(
          color: muted
              ? Colors.white70
              : accent
                  ? AdvantaColors.lightGreen
                  : Colors.white,
          fontWeight: muted || accent ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;

  const _DetailActionButton({
    required this.icon,
    required this.title,
    this.subtitle,
    this.filled = false,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final background = filled
        ? AdvantaColors.primaryGreen
        : Colors.white.withAlpha(enabled ? 10 : 6);
    final border = filled
        ? AdvantaColors.lightGreen.withAlpha(160)
        : Colors.white.withAlpha(enabled ? 28 : 14);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(80)),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.bodyBold.copyWith(
                        color: enabled ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdvantaText.caption.copyWith(
                          color: enabled ? Colors.white70 : Colors.white30,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodetMarker extends StatelessWidget {
  final DetasselingPlanGroup group;
  final bool isSelected;

  const _CodetMarker({required this.group, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = group.status == DetasselingGroupStatus.done
        ? AdvantaColors.primaryGreen
        : AdvantaColors.gold;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: 8,
          child: Container(
            width: isSelected ? 46 : 40,
            height: isSelected ? 46 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border:
                  Border.all(color: Colors.white, width: isSelected ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(120),
                  blurRadius: isSelected ? 20 : 12,
                  spreadRadius: isSelected ? 3 : 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                group.fieldCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          child: Container(
            width: 2,
            height: 12,
            color: Colors.white.withAlpha(230),
          ),
        ),
      ],
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  final int count;

  const _ClusterMarker({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AdvantaColors.deepForest.withAlpha(230),
        border: Border.all(color: AdvantaColors.goldLight, width: 2),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconPill({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(22)),
          ),
          child: Icon(icon, color: AdvantaColors.goldLight, size: 19),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: isActive
            ? AdvantaColors.primaryGreen.withAlpha(210)
            : Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AdvantaColors.lightGreen.withAlpha(140)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white70, size: 15),
        ],
      ),
    );
  }
}

class _PopupRow extends StatelessWidget {
  final String label;
  final bool selected;

  const _PopupRow({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AdvantaText.body2.copyWith(
              color: selected ? AdvantaColors.goldLight : Colors.white,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        if (selected)
          const Icon(Icons.check_circle_rounded,
              color: AdvantaColors.goldLight, size: 16),
      ],
    );
  }
}

class _ExportIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback onTap;

  const _ExportIconButton({
    required this.icon,
    required this.tooltip,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AdvantaColors.paleGreen,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdvantaColors.dividerGrey),
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(9),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: AdvantaColors.primaryGreen, size: 18),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dark;

  const _MiniBadge({
    required this.label,
    required this.color,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(dark ? 32 : 28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(dark ? 150 : 120)),
      ),
      child: Text(
        label,
        style: AdvantaText.caption.copyWith(
          color: dark ? Colors.white : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AdvantaColors.softGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AdvantaColors.mutedGrey),
          const SizedBox(width: 4),
          Text(
            label,
            style: AdvantaText.caption.copyWith(
              color: AdvantaColors.charcoal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _rawText(
  Map<String, dynamic>? raw,
  List<String> keys, {
  String fallback = '-',
}) {
  if (raw == null) return fallback;
  for (final key in keys) {
    final value = raw[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _detailStatusLabel(DetasselingGroupStatus status) {
  return status == DetasselingGroupStatus.done ? 'Done' : 'Planned';
}

String _passLabelForDate(
  DateTime weekStart,
  DateTime date,
  DetasselingCropFilter crop,
) {
  final offset =
      normalizeDate(date).difference(normalizeDate(weekStart)).inDays;
  final pass = (offset ~/ 2) + 1;
  final maxPass = crop == DetasselingCropFilter.sc ? 5 : 3;
  return 'P${pass.clamp(1, maxPass)}';
}

String _formatHa(double value) {
  return NumberFormat('#,##0.##', 'id_ID').format(value);
}
