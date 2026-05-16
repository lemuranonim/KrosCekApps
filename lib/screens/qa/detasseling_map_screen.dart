import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:android_path_provider/android_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../providers/detasseling_plan_provider.dart';
import '../../providers/filter_data_provider.dart';
import '../../theme/app_theme.dart';

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
    final groups = plan?.groups ?? const <DetasselingPlanGroup>[];
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
                plan: plan,
                exportingPicture: _isExportingPicture,
                exportingPdf: _isExportingPdf,
                onPicture: () => unawaited(_downloadPicture(plan)),
                onPdf: () => unawaited(_downloadPdf(plan)),
              ),
              _buildDailyStrip(plan),
              Divider(
                  height: 1, color: AdvantaColors.dividerGrey.withAlpha(180)),
              Expanded(child: _buildGroupList(plan)),
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
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        scrollDirection: Axis.horizontal,
        itemCount: plan.dailySummaries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = plan.dailySummaries[index];
          return _DayTile(summary: day);
        },
      ),
    );
  }

  Widget _buildGroupList(DetasselingPlanningData plan) {
    if (plan.groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            'Tidak ada Codet yang masuk planning DT untuk filter ini.',
            textAlign: TextAlign.center,
            style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      itemCount: plan.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = plan.groups[index];
        return _CodetSummaryRow(
          group: group,
          isSelected: group.key == _selectedGroupKey,
          onTap: () {
            setState(() => _selectedGroupKey = group.key);
            _fitGroup(group);
          },
          onDetail: () => _showGroupDetail(group),
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

  DetasselingPlanGroup? _selectedGroup(DetasselingPlanningData? plan) {
    if (plan == null || _selectedGroupKey == null) return null;
    for (final group in plan.groups) {
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
    if (value == null || value.groups.isEmpty) return;
    _fitPoints(value.groups.map((group) => group.center).toList());
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
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _planningCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Planning card belum siap untuk dicapture.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw Exception('Gagal membuat file gambar.');
      await _saveBytes(
        bytes: bytes,
        fileName: _exportFileName(plan, 'png'),
        mimeType: 'image/png',
      );
      _snack('Picture weekly planning berhasil diunduh.');
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
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Text(
              'Detasseling Weekly Planning',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('${plan.week.label} • ${plan.week.rangeLabel}'),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                _pdfMetric('Codet', plan.codetCount.toString()),
                _pdfMetric('FN', plan.plannedFieldCount.toString()),
                _pdfMetric('Total Ha', _formatHa(plan.totalAreaHa)),
                _pdfMetric('Pending', plan.pendingGroupCount.toString()),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.green800),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Codet',
                'Desa',
                'Hybrid',
                'Crop',
                'FN',
                'Total Ha',
                'Status',
              ],
              data: plan.groups.map((group) {
                return [
                  group.codet,
                  group.village,
                  group.hybrid,
                  group.cropLabel,
                  group.fieldCount.toString(),
                  _formatHa(group.totalAreaHa),
                  group.statusLabel,
                ];
              }).toList(),
            ),
          ],
        ),
      );
      await _saveBytes(
        bytes: await doc.save(),
        fileName: _exportFileName(plan, 'pdf'),
        mimeType: 'application/pdf',
      );
      _snack('PDF weekly planning berhasil diunduh.');
    } catch (e) {
      _snack('Gagal download PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = io.File(p.join(tempDir.path, fileName));
    await tempFile.writeAsBytes(bytes, flush: true);

    final downloadDir = await _downloadDirectory();
    if (io.Platform.isAndroid || io.Platform.isIOS) {
      final taskId = await FlutterDownloader.enqueue(
        url: tempFile.uri.toString(),
        savedDir: downloadDir.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: io.Platform.isAndroid,
      );
      if (taskId == null) {
        throw Exception('Gagal membuat task download $mimeType.');
      }
      return;
    }

    final outputFile = io.File(p.join(downloadDir.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    await OpenFile.open(outputFile.path);
  }

  Future<io.Directory> _downloadDirectory() async {
    if (io.Platform.isAndroid) {
      return io.Directory(await AndroidPathProvider.downloadsPath);
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  String _exportFileName(DetasselingPlanningData plan, String extension) {
    final stamp = DateFormat('yyyyMMdd').format(plan.week.startDate);
    return 'detasseling_${plan.week.label}_$stamp.$extension';
  }

  void _showGroupDetail(DetasselingPlanGroup group) {
    setState(() => _selectedGroupKey = group.key);
    _fitGroup(group);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CodetDetailSheet(group: group),
    );
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
  final bool exportingPicture;
  final bool exportingPdf;
  final VoidCallback onPicture;
  final VoidCallback onPdf;

  const _PlanningHeader({
    required this.plan,
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
            child: const Icon(Icons.content_cut_rounded,
                color: Colors.white, size: 19),
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
                  '${plan.codetCount} Codet • ${plan.plannedFieldCount} FN • ${_formatHa(plan.totalAreaHa)} Ha',
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.mutedGrey,
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

  const _DayTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    final hasPlan = summary.codetCount > 0;
    return Container(
      width: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasPlan ? AdvantaColors.paleGreen : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPlan
              ? AdvantaColors.primaryGreen.withAlpha(90)
              : AdvantaColors.dividerGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEE', 'id_ID').format(summary.date),
            style: AdvantaText.caption.copyWith(
              color: AdvantaColors.mutedGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            DateFormat('d MMM', 'id_ID').format(summary.date),
            style: AdvantaText.label.copyWith(
              color: AdvantaColors.deepForest,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '${summary.codetCount} Codet',
            style: AdvantaText.caption.copyWith(
              color: AdvantaColors.deepForest,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${_formatHa(summary.areaHa)} Ha',
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ],
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

class _CodetDetailSheet extends StatelessWidget {
  final DetasselingPlanGroup group;

  const _CodetDetailSheet({required this.group});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AdvantaColors.deepForest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.codet,
                            style: AdvantaText.heading2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${group.village} • ${group.hybrid} • ${_formatHa(group.totalAreaHa)} Ha',
                            style: AdvantaText.body2.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MiniBadge(
                      label: group.statusLabel,
                      color: group.status == DetasselingGroupStatus.done
                          ? AdvantaColors.lightGreen
                          : AdvantaColors.goldLight,
                      dark: true,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: group.fields.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final field = group.fields[index];
                    return _DetailFieldTile(field: field);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailFieldTile extends StatelessWidget {
  final DetasselingPlanField field;

  const _DetailFieldTile({required this.field});

  @override
  Widget build(BuildContext context) {
    final statusColor = field.isAssessmentDone
        ? AdvantaColors.lightGreen
        : AdvantaColors.goldLight;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  field.fieldNumber.isEmpty ? '-' : field.fieldNumber,
                  style: AdvantaText.bodyBold.copyWith(color: Colors.white),
                ),
              ),
              _MiniBadge(
                label: field.isAssessmentDone ? 'Done' : 'Pending',
                color: statusColor,
                dark: true,
              ),
            ],
          ),
          if (field.farmerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field.farmerName,
              style: AdvantaText.caption.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DarkInfoBadge(
                icon: Icons.calendar_today_rounded,
                label:
                    DateFormat('EEE, d MMM', 'id_ID').format(field.plannedDate),
              ),
              _DarkInfoBadge(
                icon: Icons.speed_rounded,
                label: 'DAP ${field.currentDap}->${field.plannedDap}',
              ),
              _DarkInfoBadge(
                icon: Icons.area_chart_rounded,
                label: '${_formatHa(field.areaHa)} Ha',
              ),
            ],
          ),
        ],
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

class _DarkInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DarkInfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            label,
            style: AdvantaText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatHa(double value) {
  return NumberFormat('#,##0.##', 'id_ID').format(value);
}
