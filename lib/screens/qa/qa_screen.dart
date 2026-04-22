// lib/screens/qa/qa_screen.dart
//
// HOME MAP SCREEN — Disesuaikan ke AdvantaTheme (centralized theme)
// ─────────────────────────────────────────────────────────
// Perubahan utama dari versi sebelumnya:
//   • Semua warna hardcoded → AdvantaColors.*
//   • Semua TextStyle hardcoded → AdvantaText.*
//   • Border, shape, shadow → AdvantaRadius.* & AdvantaShadows.*
//   • Warna dinamis light/dark dibaca dari Theme.of(context)
//   • Komponen bottom sheet (dark-themed) tetap menggunakan
//     AdvantaColors.deepForest / midGreen sesuai dark palette
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
// url_launcher
import 'package:url_launcher/url_launcher.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/filter_data_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/field_detail_bottom_sheet.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../services/session_manager.dart';
import '../../widgets/field_list_view.dart'; // Sesuaikan path ini
import '../../utils/audit_status_helper.dart';
import '../../utils/active_phase_filter.dart';
import '../../utils/dap_helper.dart';
import '../../widgets/audit_status_widgets.dart';

// ─── Work mode enum ──────────────────────────────────────
enum _WorkMode { single, mass }

// ─── Audit Status filter enum ────────────────────────────
enum _AuditFilter {
  all,     // Semua lahan
  sampun,  // Sudah audit fase aktif
  partial, // Dereng Jangkep (generatif sebagian)
  dereng,  // Belum audit sama sekali (Dereng Blas)
}

// ─── Screen ──────────────────────────────────────────────
class QAScreen extends ConsumerStatefulWidget {
  const QAScreen({super.key});

  @override
  ConsumerState<QAScreen> createState() => _QAScreenState();
}

class _QAScreenState extends ConsumerState<QAScreen>
    with TickerProviderStateMixin {
  // Tinggi overlay atas (header + chips) — diukur setelah build
  final GlobalKey _topOverlayKey = GlobalKey();
  double _topOverlayHeight = 168.0; // fallback default

  // Map
  final MapController _mapController = MapController();
  bool _isSatellite = true;

  // Search & filter — Multi-param (Supabase-style)
  final List<SearchFilter> _activeFilters = [];

  // Region / District quick-filter (tetap dipertahankan)
  String? _selectedRegion;
  String? _selectedDistrict;

  // Modes
  _WorkMode _workMode = _WorkMode.single;
  final Set<String> _selectedFieldNumbers = {};

  // UI states
  bool _isLegendVisible = false;
  bool _isSpeedDialOpen = false;

  // ── User GPS location ──────────────────────────────────
  LatLng? _userLocation;
  bool _isLocating = false;
  bool _gpsEnabled = false;

  // ── Loading / Refresh overlay ─────────────────────────
  bool _isRefreshing = false;
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;
  late AnimationController _refreshSpinCtrl;

  late AnimationController _speedDialCtrl;

  ActivePhaseView _activePhaseView = ActivePhaseView.auto;
  _AuditFilter _auditFilter = _AuditFilter.all;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    _refreshSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadUser();
    _initUserLocation();
    _speedDialCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _refreshSpinCtrl.dispose();
    _speedDialCtrl.dispose();
    super.dispose();
  }

  void _measureTopOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _topOverlayKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if (h > 0 && h != _topOverlayHeight) {
        setState(() => _topOverlayHeight = h);
      }
    });
  }

  Future<void> _loadUser() async {
    final session = await SessionManager.instance.getActiveSession();
    final uid = session?.userId ?? '';
    if (uid.isEmpty || !mounted) return;
    ref.read(attendanceProvider.notifier).loadTodayAttendance(uid);
  }

  Future<void> _initUserLocation() async {
    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    await _fetchAndMoveToUser(centerMap: true);
  }

  Future<void> _fetchAndMoveToUser({bool centerMap = false}) async {
    if (_isLocating) return;
    if (!mounted) setState(() => _isLocating = true);

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy  : LocationAccuracy.high,
          timeLimit : Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _gpsEnabled   = true;
        _isLocating   = false;
      });
      if (centerMap) {
        _mapController.move(_userLocation!, 12.0);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsEnabled = false;
        _isLocating = false;
      });
    }
  }

  Future<void> _goToUserLocation() async {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
      return;
    }
    await _fetchAndMoveToUser(centerMap: true);
    if (!_gpsEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mendapatkan lokasi GPS. Pastikan izin lokasi aktif.',
            style: AdvantaText.body2.copyWith(color: Colors.white),
          ),
          backgroundColor: AdvantaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.cardRadius),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // Fungsi untuk membuka Google Maps
  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Color helpers ───────────────────────────────────────
  // Warna fase DAP — tetap hardcoded karena merupakan data semantik,
  // bukan tema UI. Digunakan di map markers & legenda.
  static const _phaseColors = [
    Color(0xFF78909C), // Vegetative   ≤45 DAP
    Color(0xFFFFCA28), // Generative1  46-54
    Color(0xFFFF7043), // Generative2  55-59
    Color(0xFFE53935), // Generative3  60-75
    Color(0xFF795548), // Pre-Harvest  76-100
    Color(0xFF43A047), // Harvest      >100
  ];

  Color _markerColor(int dap) {
    return DapHelper.getDapMarkerColor(dap);
  }

  // ─── Helpers ────────────────────────────────────────────
  List<ParsedFieldData> _filterFields(List<ParsedFieldData> allParsed) {
    final selRegion   = _selectedRegion?.trim().toLowerCase();
    final selDistrict = _selectedDistrict?.trim().toLowerCase();

    return allParsed.where((f) {
      // ── Region & District fixed filters ──
      if (selRegion != null) {
        final dbRegion = f.raw['region']?.toString().trim().toLowerCase() ?? '';
        if (dbRegion != selRegion) return false;
      }
      if (selDistrict != null) {
        final dbDistrict = f.raw['district_kab']?.toString().trim().toLowerCase() ?? '';
        if (dbDistrict != selDistrict) return false;
      }

      // ── Dynamic multi-param filters ──
      for (final filter in _activeFilters) {
        if (filter.value.trim().isEmpty) continue;
        final q      = filter.value.trim().toLowerCase();
        final dbVal  = f.raw[filter.param.fieldKey]?.toString().toLowerCase().trim() ?? '';
        if (!dbVal.contains(q)) return false;
      }

      // ── Audit Status filter ──
      if (_auditFilter != _AuditFilter.all) {
        final auditStatus = AuditStatusHelper.fromRaw(f.raw);
        final phase = _activePhaseView == ActivePhaseView.auto
            ? _dapToPhaseView(f.dap)
            : _activePhaseView;

        switch (_auditFilter) {
          case _AuditFilter.sampun:
            if (!_isAuditSampun(auditStatus, phase)) return false;
            break;
          case _AuditFilter.dereng:
          // Dereng Blas — belum sama sekali di fase aktif
            if (_isAuditSampun(auditStatus, phase)) return false;
            if (phase == ActivePhaseView.generative &&
                auditStatus.generative == GenerativeAuditStatus.derengJangkep) {
              return false; // Jangkep bukan Blas
            }
            break;
          case _AuditFilter.partial:
          // Dereng Jangkep — hanya berlaku untuk generatif
            if (phase != ActivePhaseView.generative) return false;
            if (auditStatus.generative != GenerativeAuditStatus.derengJangkep) return false;
            break;
          case _AuditFilter.all:
            break;
        }
      }

      return true;
    }).toList();
  }

  // Helper: resolve phase dari DAP (duplikat dari MarkerAuditDot, tapi perlu di state level)
  ActivePhaseView _dapToPhaseView(int dap) {
    if (dap <= 35)  return ActivePhaseView.vegetative;
    if (dap <= 65)  return ActivePhaseView.generative;
    if (dap <= 90) return ActivePhaseView.preHarvest;
    return ActivePhaseView.harvest;
  }

  bool _isAuditSampun(FieldAuditStatus s, ActivePhaseView phase) {
    switch (phase) {
      case ActivePhaseView.vegetative:  return s.vegetative == SingleAuditStatus.sampun;
      case ActivePhaseView.generative:  return s.generative == GenerativeAuditStatus.sampun;
      case ActivePhaseView.preHarvest:  return s.preHarvest == SingleAuditStatus.sampun;
      case ActivePhaseView.harvest:     return s.harvest == SingleAuditStatus.sampun;
      case ActivePhaseView.auto:        return false;
    }
  }

  void _fitBounds(List<ParsedFieldData> fields) {
    if (fields.isEmpty) return;
    // Menggunakan f.lat dan f.lng dari Provider
    final points = fields.map((f) => LatLng(f.lat, f.lng)).toList();
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _showDefaultCoordSheet(List<Map<String, dynamic>> uncoordFields) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UncoordFieldsSheet(
        fields: uncoordFields,
        onOpenField: (f) {
          Navigator.pop(context);
          FieldDetailBottomSheet.show(
            context,
            f,
            onInspectDone: (fieldData) {
              FieldDetailBottomSheet.show(context, fieldData);
            },
          );
        },
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _measureTopOverlay();
    final masterAsync = ref.watch(masterFieldsProvider);
    // 1. TAMBAHKAN BARIS INI: Mengambil data yang sudah di-parse oleh Isolate
    final parsedMapAsync = ref.watch(parsedMapFieldsProvider);

    final attendance = ref.watch(attendanceProvider);
    final regions   = ref.watch(uniqueRegionsProvider);
    final districts = ref.watch(uniqueDistrictsProvider(_selectedRegion));
    final user = ref.watch(currentUserProvider).value;

    // Matikan overlay refresh saat data baru sudah masuk
    if (_isRefreshing && masterAsync is AsyncData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isRefreshing) {
          setState(() => _isRefreshing = false);
          _refreshSpinCtrl.stop();
          _refreshSpinCtrl.reset();
        }
      });
    }

    bool canSeeCoverage = false;
    if (user != null) {
      final role = user.role.toUpperCase();
      final action = user.action.toLowerCase();
      canSeeCoverage = (action == 'all') &&
          ['SPV', 'MANAGER', 'DEV', 'ADMIN'].contains(role);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. MAP ─────────────────────────────────────────
          parsedMapAsync.when(
            data: (parsedFields) {
              final filtered = _filterFields(parsedFields);
              return _buildMap(filtered); // Selalu tampilkan map
            },
            loading: () => const SizedBox.expand(),
            error: (e, _) => _buildError(e.toString()),
          ),

          // ── 1b. REFRESH OVERLAY ────────────────────────────
          if (_isRefreshing && masterAsync is! AsyncLoading)
            _buildRefreshOverlay(),

          // ── 2. UNIFIED TOP OVERLAY ──────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Column(
              key: _topOverlayKey,   // ← TAMBAH INI
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(attendance, regions, districts),
                if (masterAsync is AsyncData)
                  _buildModeChips(canSeeCoverage),
                //   // ── BARU: Audit Phase Filter di map ──
                if (masterAsync is AsyncData)
                  parsedMapAsync.whenData((parsedFields) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AuditPhaseFilterBar(
                        activePhase: _activePhaseView,
                        onChanged: (phase) => setState(() {
                          _activePhaseView = phase;
                          // Reset filter 'Jangkep' jika phase bukan generatif
                          if (_auditFilter == _AuditFilter.partial &&
                              phase != ActivePhaseView.generative &&
                              phase != ActivePhaseView.auto) {
                            _auditFilter = _AuditFilter.all;
                          }
                        }),
                        compact: true,   // icon only di map agar tidak terlalu lebar
                      ),
                    );
                  }).value ?? const SizedBox.shrink(),

                // Uncoord banner — selalu di bawah mode chips
                if (masterAsync is AsyncData)
                  parsedMapAsync.whenData((parsedFields) {
                    final uncoordFields = _filterFields(parsedFields)
                        .where((f) => f.isDefault)
                        .map((f) => f.raw)
                        .toList();
                    if (uncoordFields.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: GestureDetector(
                        onTap: () => _showDefaultCoordSheet(uncoordFields),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AdvantaColors.error.withAlpha(220),
                                const Color(0xFFB71C1C).withAlpha(200),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withAlpha(30)),
                            boxShadow: [
                              BoxShadow(
                                color: AdvantaColors.error.withAlpha(90),
                                blurRadius: 16,
                                spreadRadius: -2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.location_off_rounded, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${uncoordFields.length} Lahan Tanpa Koordinat',
                                      style: AdvantaText.label.copyWith(
                                        color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.2,
                                      ),
                                    ),
                                    Text(
                                      'Tap untuk lihat daftar & koreksi',
                                      style: AdvantaText.caption.copyWith(color: Colors.white.withAlpha(180)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).value ?? const SizedBox.shrink(),
              ],
            ),
          ),

          // ── 5. RIGHT FABs ──────────────────────────────────
          if (masterAsync is AsyncData)
            Positioned(
              right: 12,
              bottom: _workMode == _WorkMode.mass ? 116 : 32,
              child: _buildRightFabs(masterAsync),
            ),

          // ── 6. LEGEND ─────────────────────────────────────────────
          if (_isLegendVisible && masterAsync is AsyncData)
            Positioned(
              right: 62,  // ← sebelumnya 68, sekarang sejajar tombol speed-dial
              bottom: _workMode == _WorkMode.mass ? 116 : 32,
              child: _buildLegend(),
            ),

          // ── 7. MASS INSPECT BAR ───────────────────────────
          if (_workMode == _WorkMode.mass && masterAsync is AsyncData)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildMassBar(),
            ),

          // ── 8. INITIAL LOADING — on top of everything ──────
          if (parsedMapAsync is AsyncLoading)
            Positioned.fill(
              child: _buildInitialLoadingScreen(),
            ),
        ],
      ),
    );
  }

  // ─── MAP ─────────────────────────────────────────────────
  Widget _buildMap(List<ParsedFieldData> fieldsData) {
    final uncoordRaw = fieldsData.where((f) => f.isDefault).map((f) => f.raw).toList();
    final coordFields = fieldsData.where((f) => !f.isDefault).toList();

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(-7.5, 112.5),
        initialZoom  : 8.0,
        maxZoom      : 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: _isSatellite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kroscek.app',
          maxNativeZoom: 18,
        ),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point : _userLocation!,
                width : 52,
                height: 52,
                child : _UserLocationMarker(isLocating: _isLocating),
              ),
            ],
          ),
        if (uncoordRaw.length > 4)
          MarkerLayer(
            markers: [
              Marker(
                point : const LatLng(-7.637017, 112.8272303),
                width : 72,
                height: 72,
                child : GestureDetector(
                  onTap: () => _showDefaultCoordSheet(uncoordRaw),
                  child: _UncoordMarker(count: uncoordRaw.length),
                ),
              ),
            ],
          ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size            : const Size(46, 46),
            alignment       : Alignment.center,
            padding         : const EdgeInsets.all(50),
            markers         : _buildMarkers(
              uncoordRaw.length > 4 ? coordFields : fieldsData,
            ),
            builder         : (ctx, markers) => _buildCluster(markers.length),
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers(List<ParsedFieldData> fieldsData) {
    final result = <Marker>[];

    for (final f in fieldsData) {
      final color = _markerColor(f.dap);
      final fn = f.raw['field_number']?.toString() ?? '';
      final isSelected = _selectedFieldNumbers.contains(fn);
      final isCorrected = f.isCorrected;

      // ── BARU: parse audit status ──
      final auditStatus = AuditStatusHelper.fromRaw(f.raw);

      result.add(Marker(
        point: LatLng(f.lat, f.lng),
        width: isCorrected ? 52 : 46,
        height: isCorrected ? 52 : 46,
        child: GestureDetector(
          onTap: () {
            if (_workMode == _WorkMode.mass) {
              setState(() {
                if (isSelected) {
                  _selectedFieldNumbers.remove(fn);
                } else {
                  _selectedFieldNumbers.add(fn);
                }
              });
            } else {
              FieldDetailBottomSheet.show(
                context,
                f.raw,
                onInspectDone: (fieldData) {
                  FieldDetailBottomSheet.show(context, fieldData);
                },
              );
            }
          },
          child: Stack(
            children: [
              Container(
                width: isCorrected ? 52 : 46,
                height: isCorrected ? 52 : 46,
                decoration: BoxDecoration(
                  color: isSelected ? AdvantaColors.primaryGreen : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : isCorrected
                        ? AdvantaColors.gold
                        : Colors.white70,
                    width: isSelected ? 3.0 : isCorrected ? 2.5 : 1.8,
                  ),
                  boxShadow: (isSelected || isCorrected)
                      ? [
                    BoxShadow(
                      color: (isSelected
                          ? AdvantaColors.primaryGreen
                          : AdvantaColors.gold)
                          .withAlpha(140),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                      : null,
                ),
                child: Center(
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18)
                      : Text(
                    '${f.dap}',
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),

              // Badge koreksi (existing — tidak berubah)
              if (isCorrected && !isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: AdvantaColors.gold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AdvantaColors.gold.withAlpha(136),
                            blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'C',
                        style: AdvantaText.caption.copyWith(
                          color: AdvantaColors.charcoal,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── BARU: Audit status dot di pojok KIRI ATAS ──
              // Hanya tampil jika belum audit (Dereng/Dereng Jangkep)
              // sehingga marker tetap bersih untuk yang sudah Sampun
              if (!isSelected)
                Positioned(
                  top: 0,
                  left: 0,
                  child: MarkerAuditDot(
                    auditStatus: auditStatus,
                    dap: f.dap,
                    activePhase: _activePhaseView,
                  ),
                ),
            ],
          ),
        ),
      ));
    }
    return result;
  }

  Widget _buildCluster(int count) => Container(
    decoration: BoxDecoration(
      color: AdvantaColors.primaryGreen,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.0),
      boxShadow: [
        BoxShadow(
          color: AdvantaColors.primaryGreen.withAlpha(128),
          blurRadius: 10,
        ),
      ],
    ),
    child: Center(
      child: Text(
        '$count',
        style: AdvantaText.bodyBold.copyWith(color: Colors.white),
      ),
    ),
  );

  Widget _buildInitialLoadingScreen() => _MapLoadingScreen(shimmerAnim: _shimmerAnim);

  Widget _buildRefreshOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            // Blur/dim layer
            Container(color: Colors.black.withAlpha(90)),

            // Floating pill di bawah header
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _refreshSpinCtrl,
                  builder: (_, __) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AdvantaColors.deepForest,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: AdvantaColors.primaryGreen.withAlpha(100)),
                        boxShadow: [
                          BoxShadow(
                            color: AdvantaColors.primaryGreen.withAlpha(60),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdvantaColors.lightGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Memperbarui data lahan…',
                            style: AdvantaText.body2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) => Container(
    color: AdvantaColors.deepForest,
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: AdvantaColors.error, size: 52),
          const SizedBox(height: 12),
          Text(
            'Gagal memuat peta',
            style: AdvantaText.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: AdvantaText.body2.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(masterFieldsProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Coba Lagi', style: AdvantaText.button),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.buttonRadius),
            ),
          ),
        ],
      ),
    ),
  );

  // ─── HEADER ──────────────────────────────────────────────
  Widget _buildHeader(AttendanceState att, List<String> regions, List<String> districts) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AdvantaColors.deepForest.withAlpha(240),
            AdvantaColors.deepForest.withAlpha(220),
            AdvantaColors.deepForest.withAlpha(180),
          ],
          stops: const [0.0, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Attendance + Date + Actions ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Row(
                children: [
                  _AttendanceChip(attendance: att),
                  const Spacer(),
                  _DateBadge(),
                  const SizedBox(width: 6),
                  // Divider tipis pemisah
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withAlpha(25),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  // ── Refresh button ──
                  GestureDetector(
                    onTap: () async {
                      if (_isRefreshing) return;
                      setState(() => _isRefreshing = true);
                      _refreshSpinCtrl.repeat();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Menyinkronkan data & profil terbaru...',
                            style: AdvantaText.body2.copyWith(color: Colors.white),
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AdvantaColors.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.cardRadius),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      await SupabaseAuthService().restoreSession();
                      ref.invalidate(currentUserProvider);
                      ref.invalidate(masterFieldsProvider);
                    },
                    child: AnimatedBuilder(
                      animation: _refreshSpinCtrl,
                      builder: (_, child) => Transform.rotate(
                        angle: _isRefreshing ? _refreshSpinCtrl.value * 6.28319 : 0,
                        child: child,
                      ),
                      child: _IconActionButton(
                        icon: Icons.sync_rounded,
                        color: _isRefreshing ? AdvantaColors.lightGreen : AdvantaColors.goldLight,
                        active: _isRefreshing,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── Settings button ──
                  GestureDetector(
                    onTap: () => context.push('/qa/settings'),
                    child: const _IconActionButton(
                      icon: Icons.settings_outlined,
                      color: AdvantaColors.goldLight,
                      active: false,
                    ),
                  ),
                ],
              ),
            ),

            // ── Row 2: Smart Search Bar ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _SmartSearchBar(
                      filters: _activeFilters,
                      onFiltersChanged: () => setState(() {}),
                      regions: regions,
                      districts: districts,
                      selectedRegion: _selectedRegion,
                      selectedDistrict: _selectedDistrict,
                      onRegionChanged: (v) => setState(() {
                        _selectedRegion = v;
                        _selectedDistrict = null;
                      }),
                      onDistrictChanged: (v) => setState(() => _selectedDistrict = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  } // end _buildHeader

  // ─── MODE CHIPS ────────────────────────────────────────────
  Widget _buildModeChips(bool canSeeCoverage) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Row(
          children: [
            // ── Mode chips (existing) ──
            _ModeChip(
              icon: Icons.touch_app_outlined,
              label: 'Single Inspect',
              active: _workMode == _WorkMode.single,
              activeColor: AdvantaColors.primaryGreen,
              onTap: () => setState(() {
                _workMode = _WorkMode.single;
                _selectedFieldNumbers.clear();
              }),
            ),
            const SizedBox(width: 8),
            _ModeChip(
              icon: Icons.checklist_rtl_outlined,
              label: 'Mass Inspect',
              active: _workMode == _WorkMode.mass,
              activeColor: AdvantaColors.midGreen,
              badge: _workMode == _WorkMode.mass && _selectedFieldNumbers.isNotEmpty
                  ? '${_selectedFieldNumbers.length}'
                  : null,
              onTap: () => setState(() {
                _workMode = _WorkMode.mass;
              }),
            ),
            if (canSeeCoverage) ...[
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.analytics_outlined,
                label: 'Coverage',
                color: AdvantaColors.gold,
                onTap: () => context.push('/coverage'),
              ),
            ],

            // ── Separator ──
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.white.withAlpha(40),
            ),

            // ── Audit Status filter chips ──
            _AuditFilterChip(
              filter: _AuditFilter.all,
              activeFilter: _auditFilter,
              onTap: () => setState(() => _auditFilter = _AuditFilter.all),
            ),
            const SizedBox(width: 6),
            _AuditFilterChip(
              filter: _AuditFilter.sampun,
              activeFilter: _auditFilter,
              onTap: () => setState(() => _auditFilter = _AuditFilter.sampun),
            ),
            const SizedBox(width: 6),
            // Dereng Jangkep hanya relevan jika phase generatif
            if (_activePhaseView == ActivePhaseView.generative ||
                _activePhaseView == ActivePhaseView.auto) ...[
              _AuditFilterChip(
                filter: _AuditFilter.partial,
                activeFilter: _auditFilter,
                onTap: () => setState(() => _auditFilter = _AuditFilter.partial),
              ),
              const SizedBox(width: 6),
            ],
            _AuditFilterChip(
              filter: _AuditFilter.dereng,
              activeFilter: _auditFilter,
              onTap: () => setState(() => _auditFilter = _AuditFilter.dereng),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SPEED-DIAL FAB ──────────────────────────────────────────
  Widget _buildRightFabs(AsyncValue<List<Map<String, dynamic>>> masterAsync) {
    return AnimatedBuilder(
      animation: _speedDialCtrl,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _speedDialCtrl,
          curve: Curves.easeOutCubic,
        ).value;

        // Item definitions: icon, label, activeColor, isActive, onTap
        final items = <({IconData icon, String label, Color color, bool active, VoidCallback onTap})>[
          (
          icon  : Icons.format_list_bulleted_rounded,
          label : 'List View',
          color : AdvantaColors.primaryGreen,
          active: false,
          onTap : () {
            // Tutup speed dial
            setState(() => _isSpeedDialOpen = false);
            _speedDialCtrl.reverse();

            // Ambil data lahan dan tampilkan Bottom Sheet
            ref.read(parsedMapFieldsProvider).whenData((allFields) {
              final filtered = _filterFields(allFields);
              FieldListView.showSheet(
                context,
                fieldsData: filtered,
                userLocation: _userLocation,
                getMarkerColor: _markerColor,
                onUncoordBannerTap: (uncoordFields) => _showDefaultCoordSheet(uncoordFields),
                onNavigateTap: (lat, lng) => _openInGoogleMaps(lat, lng),
                isMassMode: _workMode == _WorkMode.mass,
                selectedFieldNumbers: _selectedFieldNumbers,
                onFieldTap: (f) {
                  final fn = f.raw['field_number']?.toString() ?? '';
                  if (_workMode == _WorkMode.mass) {
                    // Jika mode massal, ubah status centang lahan
                    setState(() {
                      if (_selectedFieldNumbers.contains(fn)) {
                        _selectedFieldNumbers.remove(fn);
                      } else {
                        _selectedFieldNumbers.add(fn);
                      }
                    });
                  } else {
                    // Jika mode single, TUTUP list view dulu, baru buka detailnya
                    Navigator.pop(context);

                    FieldDetailBottomSheet.show(
                      context,
                      f.raw,
                      onInspectDone: (fieldData) {
                        FieldDetailBottomSheet.show(context, fieldData);
                      },
                    );
                  }
                },
                activePhase: _activePhaseView,          // ← TAMBAH
                onPhaseChanged: (phase) {               // ← TAMBAH
                  setState(() => _activePhaseView = phase);
                },
              );
            });
          },
          ),
          (
          icon  : Icons.fit_screen_outlined,
          label : 'Fit on Map',
          color : AdvantaColors.midGreen,
          active: false,
          onTap : () {
            ref.read(parsedMapFieldsProvider).whenData(
                  (all) => _fitBounds(_filterFields(all)),
            );
            setState(() => _isSpeedDialOpen = false);
            _speedDialCtrl.reverse();
          },
          ),
          (
          icon  : _isLegendVisible ? Icons.layers : Icons.layers_outlined,
          label : 'Legends',
          color : AdvantaColors.midGreen,
          active: _isLegendVisible,
          onTap : () => setState(() {
            _isLegendVisible = !_isLegendVisible;
          }),
          ),
          (
          icon  : _isSatellite ? Icons.map_outlined : Icons.satellite_alt_outlined,
          label : _isSatellite ? 'StreetView' : 'Satelit',
          color : AdvantaColors.goldLight,
          active: _isSatellite,
          onTap : () => setState(() => _isSatellite = !_isSatellite),
          ),
          (
          icon  : _isLocating
              ? Icons.location_searching_rounded
              : (_gpsEnabled ? Icons.my_location_rounded : Icons.location_off_rounded),
          label : 'Get User GPS',
          color : _gpsEnabled ? AdvantaColors.lightGreen : AdvantaColors.error,
          active: _gpsEnabled,
          onTap : _goToUserLocation,
          ),
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Item-item yang muncul saat open ──────────────────
            ...items.asMap().entries.map((e) {
              final idx   = e.key;
              final item  = e.value;
              final delay = (items.length - 1 - idx) * 0.07;
              final tItem = ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);

              return Opacity(
                opacity: tItem,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1.0 - tItem)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label pill
                        if (tItem > 0.3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AdvantaColors.deepForest.withAlpha(210),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withAlpha(25)),
                            ),
                            child: Text(
                              item.label,
                              style: AdvantaText.caption.copyWith(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        // FAB button
                        GestureDetector(
                          onTap: item.onTap,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.active
                                  ? item.color.withAlpha(220)
                                  : AdvantaColors.deepForest.withAlpha(210),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: item.active
                                    ? item.color.withAlpha(255)
                                    : Colors.white.withAlpha(28),
                                width: 1,
                              ),
                            ),
                            child: item.icon == Icons.location_searching_rounded && _isLocating
                                ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Icon(item.icon, size: 16,
                                color: item.active ? Colors.white : Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // ── Divider tipis sebelum tombol utama ───────────────
            if (_isSpeedDialOpen)
              Container(
                width: 36,
                height: 1,
                margin: const EdgeInsets.only(bottom: 6),
                color: Colors.white.withAlpha(30),
              ),

            // ── Tombol utama (toggle) ─────────────────────────────
            GestureDetector(
              onTap: () {
                final willOpen = !_isSpeedDialOpen;
                setState(() => _isSpeedDialOpen = willOpen);
                willOpen
                    ? _speedDialCtrl.forward()
                    : _speedDialCtrl.reverse();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: _isSpeedDialOpen
                      ? const LinearGradient(
                    colors: [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: _isSpeedDialOpen ? null : AdvantaColors.deepForest.withAlpha(220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isSpeedDialOpen
                        ? AdvantaColors.lightGreen.withAlpha(180)
                        : Colors.white.withAlpha(35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isSpeedDialOpen
                          ? AdvantaColors.primaryGreen.withAlpha(100)
                          : Colors.black.withAlpha(80),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedRotation(
                  turns: _isSpeedDialOpen ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    _isSpeedDialOpen ? Icons.close_rounded : Icons.tune_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── LEGEND ─────────────────────────────────────────────────
  Widget _buildLegend() {
    const items = [
      (_phaseColors, 0, '7–35 DAP', 'Vegetative'),
      (_phaseColors, 1, '50–54 DAP', 'Generative 1'),
      (_phaseColors, 2, '55–59 DAP', 'Generative 2'),
      (_phaseColors, 3, '60–65 DAP', 'Generative 3'),
      (_phaseColors, 4, '71–90 DAP', 'Pre-Harvest'),
      (_phaseColors, 5, '95–105 DAP', 'Harvest'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AdvantaColors.deepForest.withAlpha(224),
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.goldLight.withAlpha(30)),
        boxShadow: AdvantaShadows.card(true),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEGENDA DAP',
            style: AdvantaText.caption.copyWith(
              color: AdvantaColors.goldLight.withAlpha(153),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((it) {
            final color = it.$1[it.$2];
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withAlpha(153), blurRadius: 5),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.$4,
                        style: AdvantaText.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        it.$3,
                        style: AdvantaText.caption.copyWith(
                          color: Colors.white38,
                          fontSize: 9,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          Divider(color: AdvantaColors.goldLight.withAlpha(25), height: 14),
          // Corrected marker
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: AdvantaColors.gold, width: 1.5),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -5,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AdvantaColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'C',
                          style: AdvantaText.caption.copyWith(
                            color: AdvantaColors.charcoal,
                            fontSize: 5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Corrected',
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Koordinat sudah direvisi FI',
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white38,
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: AdvantaColors.goldLight.withAlpha(25), height: 14),
          // Uncoord marker
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  color: AdvantaColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.location_off_rounded, color: Colors.white, size: 7),
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum Terkoordinat',
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Tap marker merah → lihat daftar',
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white38,
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── MASS INSPECT BAR ────────────────────────────────────────
  Widget _buildMassBar() {
    final count = _selectedFieldNumbers.length;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdvantaColors.deepForest, Color(0xFF0F2318)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: count > 0
                ? AdvantaColors.primaryGreen.withAlpha(80)
                : Colors.white.withAlpha(18),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Count badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: count > 0
                      ? const LinearGradient(
                    colors: [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: count > 0 ? null : Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: count > 0
                        ? AdvantaColors.lightGreen.withAlpha(120)
                        : Colors.white.withAlpha(20),
                    width: 1,
                  ),
                  boxShadow: count > 0
                      ? [
                    BoxShadow(
                      color: AdvantaColors.primaryGreen.withAlpha(80),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ]
                      : [],
                ),
                child: Center(
                  child: count > 0
                      ? Text(
                    '$count',
                    style: AdvantaText.heading2.copyWith(color: Colors.white),
                  )
                      : const Icon(Icons.touch_app_rounded, color: Colors.white38, size: 20),
                ),
              ),
              const SizedBox(width: 12),

              // Description
              Expanded(
                child: count == 0
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mass Inspect Aktif',
                      style: AdvantaText.bodyBold.copyWith(color: Colors.white),
                    ),
                    Text(
                      'Tap marker di peta untuk memilih lahan',
                      style: AdvantaText.caption.copyWith(color: Colors.white38),
                    ),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count lahan dipilih',
                      style: AdvantaText.bodyBold.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Pilih fase untuk mulai inspeksi massal',
                      style: AdvantaText.caption.copyWith(color: Colors.white38),
                    ),
                  ],
                ),
              ),

              // Actions
              if (count > 0) ...[
                GestureDetector(
                  onTap: _showSelectedFieldsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(22)),
                    ),
                    child: Text(
                      'Daftar',
                      style: AdvantaText.label.copyWith(color: AdvantaColors.goldLight),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _selectedFieldNumbers.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: Text(
                      'Batal',
                      style: AdvantaText.label.copyWith(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showPhaseSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AdvantaColors.lightGreen.withAlpha(100),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AdvantaColors.primaryGreen.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'Lanjut →',
                      style: AdvantaText.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── PHASE SELECTION SHEET (mass only) ──────────────────────
  void _showPhaseSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PhaseSheet(
        selectionCount: _selectedFieldNumbers.length,
        onSelected: (phase) {
          Navigator.pop(context);
          context.push('/inspect/mass', extra: {
            'fieldNumbers': _selectedFieldNumbers.toList(),
            'phase': phase,
          });
        },
      ),
    );
  }

  void _showSelectedFieldsSheet() {
    // 1. Ambil data yang sudah di-parse (dimana DAP sudah dihitung)
    final parsedAsync = ref.read(parsedMapFieldsProvider);
    if (parsedAsync.value == null) return;

    // 2. Filter data berdasarkan field number yang dipilih
    final selectedParsedFields = parsedAsync.value!
        .where((f) => _selectedFieldNumbers.contains(f.raw['field_number']?.toString()))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectedFieldsSheet(
        fields: selectedParsedFields, // 3. Kirim data yang sudah di-parse
        onRemove: (fieldNumber) {
          setState(() {
            _selectedFieldNumbers.remove(fieldNumber);
          });
          if (_selectedFieldNumbers.isEmpty) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────

/// Icon-only action button untuk header (refresh, settings)
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool active;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active ? color.withAlpha(40) : Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color.withAlpha(120) : Colors.white.withAlpha(22),
          width: 1,
        ),
        boxShadow: active
            ? [
          BoxShadow(
            color: color.withAlpha(50),
            blurRadius: 10,
          ),
        ]
            : [],
      ),
      child: Icon(icon, color: color, size: 15),
    );
  }
}


class _AttendanceChip extends StatelessWidget {
  final AttendanceState attendance;
  const _AttendanceChip({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;
    final Color bgColor;

    if (attendance.isCheckedOut) {
      color = AdvantaColors.gold;
      bgColor = AdvantaColors.gold;
      icon = Icons.exit_to_app_rounded;
      label = 'Check-out';
    } else if (attendance.isCheckedIn) {
      color = AdvantaColors.lightGreen;
      bgColor = AdvantaColors.primaryGreen;
      icon = Icons.check_circle_rounded;
      label = attendance.checkInTime != null
          ? 'Masuk ${DateFormat('HH:mm').format(attendance.checkInTime!)}'
          : 'Check-in ✓';
    } else {
      color = AdvantaColors.error;
      bgColor = AdvantaColors.error;
      icon = Icons.warning_amber_rounded;
      label = 'Belum Check-in';
    }

    return GestureDetector(
      onTap: () {
        if (!attendance.isCheckedIn) {
          context.push('/checkin');
        } else if (!attendance.isCheckedOut) {
          context.push('/checkout');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              bgColor.withAlpha(55),
              bgColor.withAlpha(35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withAlpha(100), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: AdvantaText.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live dot
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AdvantaColors.lightGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('EEE, d MMM', 'id_ID').format(DateTime.now()),
            style: AdvantaText.label.copyWith(
              color: Colors.white.withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMART SEARCH — Supabase-style multi-parameter filter
// ─────────────────────────────────────────────────────────────

/// Defines a searchable parameter
enum SearchParam {
  fieldNumber('No. Lahan',   'field_number',      Icons.tag_rounded),
  farmerName ('Nama Petani', 'farmer_name',       Icons.person_rounded),
  grower     ('Grower',      'grower',            Icons.store_rounded),
  season     ('Season',      'season',            Icons.calendar_today_rounded),
  hybrid     ('Hybrid',      'hybrid',            Icons.grass_rounded),
  village    ('Desa',        'village_desa',      Icons.location_city_rounded),  // ← fix
  district   ('Kecamatan',   'sub_district_kec',  Icons.map_rounded),            // ← fix
  fa         ('Nama FA',     'fa',                Icons.badge_rounded),           // ← fix
  qaFI       ('Nama FI',     'qa_fi',             Icons.badge_outlined),          // ← fix
  qaSPV      ('Nama SPV',    'qa_spv',            Icons.supervisor_account_rounded); // ← fix

  const SearchParam(this.label, this.fieldKey, this.icon);
  final String label;
  final String fieldKey;
  final IconData icon;
}

/// A single active filter row
class SearchFilter {
  SearchParam param;
  String value;
  SearchFilter({required this.param, this.value = ''});
}

/// Modern Supabase-style multi-param search bar
class _SmartSearchBar extends StatefulWidget {
  final List<SearchFilter> filters;
  // HAPUS: final bool isExpanded;
  // HAPUS: final VoidCallback onToggleExpand;
  final VoidCallback onFiltersChanged;

  final List<String> regions;
  final List<String> districts;
  final String? selectedRegion;
  final String? selectedDistrict;
  final void Function(String?) onRegionChanged;
  final void Function(String?) onDistrictChanged;

  const _SmartSearchBar({
    required this.filters,
    required this.onFiltersChanged,
    required this.regions,
    required this.districts,
    required this.selectedRegion,
    required this.selectedDistrict,
    required this.onRegionChanged,
    required this.onDistrictChanged,
  });

  @override
  State<_SmartSearchBar> createState() => _SmartSearchBarState();
}

class _SmartSearchBarState extends State<_SmartSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  // TAMBAHKAN STATE LOKAL INI:
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 0.0, // Mulai dari posisi tertutup
    );
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
  }

  // HAPUS fungsi didUpdateWidget sepenuhnya karena kita tidak lagi menerima isExpanded dari luar

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  // TAMBAHKAN FUNGSI INI:
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    });
  }

  void _addFilter() {
    // Find a param not yet used
    final usedParams = widget.filters.map((f) => f.param).toSet();
    final available = SearchParam.values.where((p) => !usedParams.contains(p)).toList();
    if (available.isEmpty) return;
    widget.filters.add(SearchFilter(param: available.first));
    widget.onFiltersChanged();
  }

  void _removeFilter(int index) {
    widget.filters.removeAt(index);
    widget.onFiltersChanged();
  }

  void _clearAll() {
    widget.filters.clear();
    widget.onRegionChanged(null);
    widget.onDistrictChanged(null);
    widget.onFiltersChanged();
  }

  @override
  Widget build(BuildContext context) {
    final hasRegion   = widget.selectedRegion != null;
    final hasDistrict = widget.selectedDistrict != null;
    final hasFilters  = widget.filters.isNotEmpty || hasRegion || hasDistrict;
    final activeCount = widget.filters.where((f) => f.value.trim().isNotEmpty).length
        + (hasRegion ? 1 : 0)
        + (hasDistrict ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main bar (always visible) ──────────────────────────
        GestureDetector(
          onTap: _toggleExpand,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44,
            decoration: BoxDecoration(
              color: hasFilters
                  ? AdvantaColors.primaryGreen.withAlpha(30)
                  : Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFilters
                    ? AdvantaColors.lightGreen.withAlpha(120)
                    : Colors.white.withAlpha(28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasFilters
                      ? AdvantaColors.primaryGreen.withAlpha(40)
                      : Colors.black.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: hasFilters ? AdvantaColors.lightGreen : Colors.white38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasFilters
                      ? _buildFilterSummaryChips()
                      : Text(
                    'Filter lahan…',
                    style: AdvantaText.body2.copyWith(color: Colors.white38),
                  ),
                ),
                if (hasFilters) ...[
                  // Active count badge
                  if (activeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdvantaColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount aktif',
                        style: AdvantaText.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  // Clear all
                  GestureDetector(
                    onTap: _clearAll,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Icon(Icons.close_rounded, size: 15, color: Colors.white54),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Expandable filter panel ────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2410).withAlpha(230),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AdvantaColors.lightGreen.withAlpha(35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AdvantaColors.primaryGreen.withAlpha(50),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            Icons.filter_list_rounded,
                            size: 14,
                            color: AdvantaColors.lightGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filter Pencarian',
                          style: AdvantaText.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.filters.length} / ${SearchParam.values.length}',
                          style: AdvantaText.caption.copyWith(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Section: Lokasi (Region & Kabupaten) ──────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      children: [
                        Icon(Icons.place_rounded, size: 12, color: AdvantaColors.goldLight.withAlpha(180)),
                        const SizedBox(width: 6),
                        Text(
                          'LOKASI',
                          style: AdvantaText.caption.copyWith(
                            color: AdvantaColors.goldLight.withAlpha(180),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Row(
                      children: [
                        // Region picker
                        Expanded(
                          child: _LocationDropdown(
                            hint: 'Semua Region',
                            value: widget.selectedRegion,
                            items: widget.regions,
                            icon: Icons.map_outlined,
                            onChanged: widget.onRegionChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // District picker
                        Expanded(
                          child: _LocationDropdown(
                            hint: 'Semua Kabupaten',
                            value: widget.selectedDistrict,
                            items: widget.districts,
                            icon: Icons.location_city_outlined,
                            onChanged: widget.onDistrictChanged,
                            enabled: widget.selectedRegion != null || widget.districts.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Thin divider before dynamic filters
                  Container(
                    height: 1,
                    color: Colors.white.withAlpha(12),
                    margin: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                  ),

                  // ── Section: Filter Lainnya ───────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 12, color: AdvantaColors.lightGreen.withAlpha(180)),
                        const SizedBox(width: 6),
                        Text(
                          'FILTER LAINNYA',
                          style: AdvantaText.caption.copyWith(
                            color: AdvantaColors.lightGreen.withAlpha(180),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.filters.length} / ${SearchParam.values.length}',
                          style: AdvantaText.caption.copyWith(color: Colors.white30, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  // Filter rows
                  if (widget.filters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 13, color: Colors.white24),
                          const SizedBox(width: 8),
                          Text(
                            'Tambah filter untuk mencari lahan',
                            style: AdvantaText.caption.copyWith(color: Colors.white30),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                      itemCount: widget.filters.length,
                      itemBuilder: (_, i) => _FilterRow(
                        key: ValueKey(i),
                        filter: widget.filters[i],
                        index: i,
                        usedParams: widget.filters.map((f) => f.param).toSet(),
                        onRemove: () => _removeFilter(i),
                        onChanged: widget.onFiltersChanged,
                      ),
                    ),

                  // Add filter button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child: GestureDetector(
                      onTap: widget.filters.length < SearchParam.values.length
                          ? _addFilter
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.filters.length < SearchParam.values.length
                              ? AdvantaColors.primaryGreen.withAlpha(25)
                              : Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.filters.length < SearchParam.values.length
                                ? AdvantaColors.lightGreen.withAlpha(60)
                                : Colors.white.withAlpha(12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: widget.filters.length < SearchParam.values.length
                                  ? AdvantaColors.lightGreen
                                  : Colors.white24,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.filters.length < SearchParam.values.length
                                  ? 'Tambah Filter'
                                  : 'Semua filter digunakan',
                              style: AdvantaText.caption.copyWith(
                                color: widget.filters.length < SearchParam.values.length
                                    ? AdvantaColors.lightGreen
                                    : Colors.white24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSummaryChips() {
    final activeFilters = widget.filters.where((f) => f.value.trim().isNotEmpty).toList();
    final hasRegion   = widget.selectedRegion != null;
    final hasDistrict = widget.selectedDistrict != null;

    // Build all active chip data: (icon, label, color)
    final chips = <({IconData icon, String label, Color color})>[];

    if (hasRegion) {
      chips.add((icon: Icons.map_outlined, label: widget.selectedRegion!, color: AdvantaColors.gold));
    }
    if (hasDistrict) {
      chips.add((icon: Icons.location_city_outlined, label: widget.selectedDistrict!, color: AdvantaColors.gold));
    }
    for (final f in activeFilters) {
      chips.add((icon: f.param.icon, label: '${f.param.label}: ${f.value}', color: AdvantaColors.primaryGreen));
    }

    if (chips.isEmpty) {
      final total = (hasRegion ? 1 : 0) + (hasDistrict ? 1 : 0) + widget.filters.length;
      return Text(
        '$total filter dipilih',
        style: AdvantaText.body2.copyWith(color: Colors.white54),
        overflow: TextOverflow.ellipsis,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) => Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.color.withAlpha(55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.color.withAlpha(120)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, size: 10, color: c.color),
              const SizedBox(width: 4),
              Text(
                c.label,
                style: AdvantaText.caption.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

/// Compact dropdown untuk Region / Kabupaten di dalam panel filter
class _LocationDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final IconData icon;
  final void Function(String?) onChanged;
  final bool enabled;

  const _LocationDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: hasValue
            ? AdvantaColors.gold.withAlpha(28)
            : enabled
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasValue
              ? AdvantaColors.gold.withAlpha(120)
              : Colors.white.withAlpha(18),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Row(
            children: [
              Icon(icon, size: 12, color: enabled ? Colors.white30 : Colors.white.withAlpha(38)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  hint,
                  style: AdvantaText.caption.copyWith(
                    color: enabled ? Colors.white38 : Colors.white.withAlpha(38),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          value: value,
          dropdownColor: const Color(0xFF0D2410),
          style: AdvantaText.caption.copyWith(color: Colors.white, fontSize: 12),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: hasValue ? AdvantaColors.gold : Colors.white30,
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Semua', style: AdvantaText.caption.copyWith(color: Colors.white54, fontSize: 12)),
            ),
            ...items.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, overflow: TextOverflow.ellipsis,
                  style: AdvantaText.caption.copyWith(color: Colors.white, fontSize: 12)),
            )),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

/// A single filter row inside the panel
class _FilterRow extends StatefulWidget {
  final SearchFilter filter;
  final int index;
  final Set<SearchParam> usedParams;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _FilterRow({
    super.key,
    required this.filter,
    required this.index,
    required this.usedParams,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.filter.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showParamPicker() {
    final available = SearchParam.values
        .where((p) => p == widget.filter.param || !widget.usedParams.contains(p))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ParamPickerSheet(
        currentParam: widget.filter.param,
        availableParams: available,
        onSelected: (p) {
          setState(() => widget.filter.param = p);
          widget.onChanged();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // ── Param selector button ──────────────────────────
          GestureDetector(
            onTap: _showParamPicker,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AdvantaColors.primaryGreen.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AdvantaColors.lightGreen.withAlpha(80),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.filter.param.icon, size: 13, color: AdvantaColors.lightGreen),
                  const SizedBox(width: 6),
                  Text(
                    widget.filter.param.label,
                    style: AdvantaText.caption.copyWith(
                      color: AdvantaColors.lightGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more_rounded, size: 12, color: AdvantaColors.lightGreen.withAlpha(150)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── "contains" label ──────────────────────────────
          Text(
            '≈',
            style: AdvantaText.body2.copyWith(color: Colors.white30, fontSize: 16),
          ),

          const SizedBox(width: 8),

          // ── Value input ───────────────────────────────────
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(22), width: 1),
              ),
              child: TextField(
                controller: _ctrl,
                style: AdvantaText.body2.copyWith(color: Colors.white, fontSize: 13),

                // 1. TAMBAHKAN DUA BARIS INI:
                textAlignVertical: TextAlignVertical.center,
                cursorColor: AdvantaColors.lightGreen,

                decoration: InputDecoration(
                  hintText: 'nilai…',
                  hintStyle: AdvantaText.caption.copyWith(color: Colors.white30),
                  border: InputBorder.none,

                  // 2. TAMBAHKAN BARIS INI:
                  isDense: true,

                  // 3. SESUAIKAN PADDINGNYA:
                  contentPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 2),

                  suffixIcon: _ctrl.text.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      widget.filter.value = '';
                      widget.onChanged();
                      setState(() {});
                    },
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white30),
                  )
                      : null,
                ),
                onChanged: (v) {
                  widget.filter.value = v;
                  widget.onChanged();
                  setState(() {});
                },
              ),
            ),
          ),

          const SizedBox(width: 6),

          // ── Remove button ─────────────────────────────────
          GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: 36,
              height: 40,
              decoration: BoxDecoration(
                color: AdvantaColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdvantaColors.error.withAlpha(50), width: 1),
              ),
              child: Icon(Icons.remove_rounded, size: 15, color: AdvantaColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to pick a search parameter
class _ParamPickerSheet extends StatelessWidget {
  final SearchParam currentParam;
  final List<SearchParam> availableParams;
  final void Function(SearchParam) onSelected;

  const _ParamPickerSheet({
    required this.currentParam,
    required this.availableParams,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1F0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: AdvantaColors.lightGreen),
                const SizedBox(width: 10),
                Text(
                  'Pilih Parameter Filter',
                  style: AdvantaText.heading3.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withAlpha(12)),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: availableParams.length,
            itemBuilder: (_, i) {
              final p = availableParams[i];
              final isSelected = p == currentParam;
              return GestureDetector(
                onTap: () => onSelected(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AdvantaColors.primaryGreen.withAlpha(50)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AdvantaColors.lightGreen.withAlpha(100)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AdvantaColors.primaryGreen.withAlpha(80)
                              : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          p.icon,
                          size: 17,
                          color: isSelected ? AdvantaColors.lightGreen : Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.label,
                              style: AdvantaText.bodyBold.copyWith(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            Text(
                              p.fieldKey,
                              style: AdvantaText.caption.copyWith(
                                color: Colors.white30,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, size: 18, color: AdvantaColors.lightGreen),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final String? badge;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
            colors: [
              activeColor,
              activeColor.withAlpha(200),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: active ? null : Colors.white.withAlpha(16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? activeColor : Colors.white.withAlpha(30),
            width: 1,
          ),
          boxShadow: active
              ? [
            BoxShadow(
              color: activeColor.withAlpha(100),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 7),
            Text(
              label,
              style: AdvantaText.label.copyWith(
                color: Colors.white,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: AdvantaText.caption.copyWith(
                    color: activeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withAlpha(130), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(40),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 7),
            Text(
              label,
              style: AdvantaText.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withAlpha(180), size: 9),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AUDIT STATUS FILTER CHIP
// Chip kecil untuk filter Sampun / Jangkep / Dereng di mode chips row
// ─────────────────────────────────────────────────────────────
class _AuditFilterChip extends StatelessWidget {
  final _AuditFilter filter;
  final _AuditFilter activeFilter;
  final VoidCallback onTap;

  const _AuditFilterChip({
    required this.filter,
    required this.activeFilter,
    required this.onTap,
  });

  _AuditFilterStyle get _style {
    switch (filter) {
      case _AuditFilter.all:
        return _AuditFilterStyle(
          icon: Icons.apps_rounded,
          label: 'Semua',
          color: Colors.white70,
        );
      case _AuditFilter.sampun:
        return _AuditFilterStyle(
          icon: Icons.check_circle_rounded,
          label: 'Sampun',
          color: const Color(0xFF43A047),
        );
      case _AuditFilter.partial:
        return _AuditFilterStyle(
          icon: Icons.timelapse_rounded,
          label: 'Jangkep',
          color: const Color(0xFFFFA726),
        );
      case _AuditFilter.dereng:
        return _AuditFilterStyle(
          icon: Icons.radio_button_unchecked_rounded,
          label: 'Dereng',
          color: const Color(0xFFEF5350),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = filter == activeFilter;
    final s = _style;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? s.color.withAlpha(50) : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive ? s.color : Colors.white.withAlpha(28),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: s.color.withAlpha(80), blurRadius: 10, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 13, color: isActive ? s.color : Colors.white54),
            const SizedBox(width: 5),
            Text(
              s.label,
              style: AdvantaText.label.copyWith(
                color: isActive ? s.color : Colors.white54,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditFilterStyle {
  final IconData icon;
  final String label;
  final Color color;
  const _AuditFilterStyle({required this.icon, required this.label, required this.color});
}

// ─────────────────────────────────────────────────────────────
// PHASE SELECTION BOTTOM SHEET
// Dark-themed menggunakan AdvantaColors palette
// ─────────────────────────────────────────────────────────────

class _PhaseSheet extends StatelessWidget {
  final int selectionCount;
  final void Function(String) onSelected;

  const _PhaseSheet({
    required this.selectionCount,
    required this.onSelected,
  });

  static const _phases = [
    (Icons.eco_outlined, 'Vegetative', 'vegetative',
    Color(0xFF78909C), '100% target – semua field aktif'),
    (Icons.grass_outlined, 'Generative 1', 'generative_1',
    Color(0xFFFFCA28), 'Checkpoint pertama – readiness & roguing'),
    (Icons.grass, 'Generative 2', 'generative_2',
    Color(0xFFFF7043), 'Checkpoint kedua – female shedding'),
    (Icons.grass, 'Generative 3 (Final)', 'generative_3',
    Color(0xFFE53935), 'Checkpoint final – flagging & detasseling'),
    (Icons.agriculture_outlined, 'Pre-Harvest', 'pre_harvest',
    Color(0xFF795548), 'Target 50% – sampling eligible'),
    (Icons.grain, 'Harvest', 'harvest',
    Color(0xFF43A047), 'Target 50% + field flagged'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdvantaColors.deepForest,
        borderRadius: AdvantaRadius.sheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AdvantaColors.goldLight.withAlpha(46),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdvantaColors.primaryGreen.withAlpha(51),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.checklist_rtl, color: AdvantaColors.lightGreen, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Fase – Mass Inspect',
                        style: AdvantaText.heading3.copyWith(color: Colors.white),
                      ),
                      Text(
                        '$selectionCount lahan akan diinspeksi bersamaan',
                        style: AdvantaText.caption.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: AdvantaColors.goldLight.withAlpha(25), height: 20),

          // Phase list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _phases.length,
            itemBuilder: (ctx, i) {
              final (icon, label, key, color, desc) = _phases[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  label,
                  style: AdvantaText.body1.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  desc,
                  style: AdvantaText.caption.copyWith(color: Colors.white38),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.white30, size: 18),
                onTap: () => onSelected(key),
              );
            },
          ),

          SafeArea(top: false, child: const SizedBox(height: 8)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// USER LOCATION MARKER
// ─────────────────────────────────────────────────────────────
class _UserLocationMarker extends StatefulWidget {
  final bool isLocating;
  const _UserLocationMarker({required this.isLocating});

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _scale;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: false);

    _scale = Tween<double>(begin: 1.0, end: 2.4).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Warna biru GPS tetap dipertahankan — ini adalah konvensi UX universal
    // (mirip Google Maps / Apple Maps) bukan warna branding.
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width : 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2196F3).withAlpha((_opacity.value * 255).round()),
              ),
            ),
          ),
        ),
        Container(
          width : 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Color(0x662196F3), blurRadius: 8, spreadRadius: 2),
            ],
          ),
        ),
        Container(
          width : 13,
          height: 13,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2196F3),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UNCOORD MARKER
// ─────────────────────────────────────────────────────────────
class _UncoordMarker extends StatefulWidget {
  final int count;
  const _UncoordMarker({required this.count});

  @override
  State<_UncoordMarker> createState() => _UncoordMarkerState();
}

class _UncoordMarkerState extends State<_UncoordMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: false);
    _scale   = Tween<double>(begin: 1.0, end: 2.2).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing ring merah (error color)
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdvantaColors.error.withAlpha((_opacity.value * 255).round()),
              ),
            ),
          ),
        ),
        // Marker body
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AdvantaColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AdvantaColors.error.withAlpha(153),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.white, size: 18),
              const SizedBox(height: 1),
              Text(
                '${widget.count}',
                style: AdvantaText.heading3.copyWith(color: Colors.white, height: 1.0),
              ),
              Text(
                'lahan',
                style: AdvantaText.caption.copyWith(color: Colors.white70, height: 1.1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UNCOORD FIELDS SHEET
// ─────────────────────────────────────────────────────────────
class _UncoordFieldsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final void Function(Map<String, dynamic> field) onOpenField;

  const _UncoordFieldsSheet({
    required this.fields,
    required this.onOpenField,
  });

  @override
  State<_UncoordFieldsSheet> createState() => _UncoordFieldsSheetState();
}

class _UncoordFieldsSheetState extends State<_UncoordFieldsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.fields;
    final q = _query.toLowerCase();
    return widget.fields.where((f) {
      final fn     = f['field_number']?.toString().toLowerCase() ?? '';
      final farmer = f['farmer_name']?.toString().toLowerCase() ?? '';
      final fa     = f['fa']?.toString().toLowerCase() ?? '';
      return fn.contains(q) || farmer.contains(q) || fa.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Sheet ini selalu dark-themed (ditampilkan di atas peta)
    const kBg      = AdvantaColors.deepForest;
    const kSurface = AdvantaColors.midGreen;
    const kRed     = AdvantaColors.error;

    return DraggableScrollableSheet(
      initialChildSize : 0.72,
      minChildSize     : 0.45,
      maxChildSize     : 0.92,
      expand           : false,
      builder: (ctx, scrollCtrl) {
        final filtered = _filtered;

        return Container(
          decoration: const BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdvantaColors.goldLight.withAlpha(46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kRed.withAlpha(38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kRed.withAlpha(102)),
                      ),
                      child: const Icon(Icons.location_off_rounded, color: kRed, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lahan Tanpa Koordinat',
                            style: AdvantaText.heading3.copyWith(color: Colors.white),
                          ),
                          Text(
                            '${widget.fields.length} lahan — koordinat belum diisi / masih 0',
                            style: AdvantaText.caption.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.white54, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Info bar ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdvantaColors.successLight.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdvantaColors.success.withAlpha(128)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AdvantaColors.lightGreen, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap baris lahan → buka detail → Correction Tagging untuk mengisi koordinat yang benar.',
                          style: AdvantaText.caption.copyWith(color: AdvantaColors.lightGreen),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Search ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: kSurface.withAlpha(200),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdvantaColors.goldLight.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search, color: Colors.white38, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: AdvantaText.body2.copyWith(color: Colors.white, fontSize: 13),

                          // 1. Tambahkan perataan vertikal ke tengah
                          textAlignVertical: TextAlignVertical.center,
                          cursorColor: AdvantaColors.lightGreen,

                          decoration: InputDecoration(
                            hintText: 'Cari No. Lahan, Petani, FA…',
                            hintStyle: AdvantaText.body2.copyWith(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,

                            // 2. Pastikan isDense aktif
                            isDense: true,

                            // 3. Atur padding agar teks tidak terpotong
                            contentPadding: const EdgeInsets.only(left: 0, right: 10, bottom: 12),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.clear, color: Colors.white38, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: AdvantaColors.goldLight.withAlpha(20), height: 1),

              // ── List ──────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, color: Colors.white24, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada hasil',
                        style: AdvantaText.body2.copyWith(color: Colors.white38),
                      ),
                    ],
                  ),
                )
                    : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    color: AdvantaColors.goldLight.withAlpha(15),
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    final fn = f['field_number'] ?? '—';
                    final farmer = f['farmer_name'] ?? '—';
                    final fa = f['fa'] ?? '—';
                    final district = f['district_kab'] ?? '';
                    final village = f['village_desa'] ?? '';
                    final haRaw = f['effective_area_ha'];
                    final ha = haRaw != null
                        ? '${haRaw.toStringAsFixed(2)} ha'
                        : '—';

                    return InkWell(
                      onTap: () => widget.onOpenField(f),
                      splashColor: AdvantaColors.midGreen.withAlpha(51),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: kRed.withAlpha(31),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_off_rounded, color: kRed, size: 18),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fn,
                                          style: AdvantaText.bodyBold.copyWith(color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(15),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          ha,
                                          style: AdvantaText.caption.copyWith(color: Colors.white54),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    farmer,
                                    style: AdvantaText.body2.copyWith(color: Colors.white70),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (village.isNotEmpty || district.isNotEmpty)
                                        Expanded(
                                          child: Text(
                                            [village, district]
                                                .where((s) => s.isNotEmpty)
                                                .join(', '),
                                            style: AdvantaText.caption.copyWith(
                                              color: AdvantaColors.mutedGrey,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      if (fa.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: BoxDecoration(
                                            color: AdvantaColors.primaryGreen.withAlpha(51),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            fa,
                                            style: AdvantaText.caption.copyWith(
                                              color: AdvantaColors.lightGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                          ],
                        ),
                      ),
                    );
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

// ─────────────────────────────────────────────────────────────
// INITIAL MAP LOADING SCREEN — animated step-by-step
// ─────────────────────────────────────────────────────────────
class _MapLoadingScreen extends StatefulWidget {
  final Animation<double> shimmerAnim;
  const _MapLoadingScreen({required this.shimmerAnim});

  @override
  State<_MapLoadingScreen> createState() => _MapLoadingScreenState();
}

class _MapLoadingScreenState extends State<_MapLoadingScreen>
    with SingleTickerProviderStateMixin {

  // Step label & ikon
  static const _steps = [
    (Icons.wifi_rounded, 'Menghubungkan ke server…'),
    (Icons.verified_user_outlined, 'Memverifikasi sesi pengguna…'),
    (Icons.cloud_download_outlined, 'Mengambil data lahan…'),
    (Icons.place_outlined, 'Menyiapkan marker peta…'),
    (Icons.map_outlined, 'Merender peta…'),
  ];

  int _stepIndex = 0;
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut),
    );
    _tickStep();
  }

  void _tickStep() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _stepIndex = (_stepIndex + 1) % _steps.length;
      });
      _tickStep();
    });
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AdvantaColors.deepForest,
      child: Stack(
        children: [
          // ── Shimmer scan line efek di background ──────────
          AnimatedBuilder(
            animation: widget.shimmerAnim,
            builder: (_, __) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  painter: _ShimmerScanPainter(
                    progress: widget.shimmerAnim.value,
                  ),
                ),
              );
            },
          ),

          // ── Fake map tiles shimmer (bawah) ────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: AnimatedBuilder(
              animation: widget.shimmerAnim,
              builder: (_, __) {
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1,
                  ),
                  itemCount: 20,
                  itemBuilder: (_, i) {
                    final shimmerX = widget.shimmerAnim.value;
                    final t = ((shimmerX + i * 0.15) % 1.0).clamp(0.0, 1.0);
                    final alpha = (50 + (t * 35)).round();
                    return Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: AdvantaColors.midGreen.withAlpha(alpha),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Gradient overlay gelap dari atas ─────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AdvantaColors.deepForest,
                  Color(0xE0162920),
                  Color(0xA0162920),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Konten tengah ─────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / ikon utama
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AdvantaColors.primaryGreen.withAlpha(40),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AdvantaColors.lightGreen.withAlpha(80),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AdvantaColors.primaryGreen.withAlpha(60),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: SvgPicture.asset(
                      'assets/logo_kc.svg',
                      placeholderBuilder: (_) => const Icon(Icons.agriculture_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Judul
                Text(
                  'QA Field Map',
                  style: AdvantaText.heading2.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kroscek · Field Intelligence',
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.goldLight.withAlpha(153),
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 40),

                // Step-step animasi
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _StepPill(
                    key: ValueKey(_stepIndex),
                    icon: _steps[_stepIndex].$1,
                    label: _steps[_stepIndex].$2,
                  ),
                ),

                const SizedBox(height: 32),

                // Progress dots
                AnimatedBuilder(
                  animation: _dotAnim,
                  builder: (_, __) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final delay = i * 0.33;
                        final raw = (_dotCtrl.value - delay).abs();
                        final opacity = (1.0 - raw).clamp(0.2, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AdvantaColors.lightGreen.withAlpha(
                              (opacity * 220).round(),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Step counter
                Text(
                  'Langkah ${_stepIndex + 1} dari ${_steps.length}',
                  style: AdvantaText.caption.copyWith(color: Colors.white24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill kecil yang menampilkan step aktif
class _StepPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StepPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AdvantaColors.midGreen.withAlpha(180),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AdvantaColors.lightGreen.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: AdvantaColors.lightGreen,
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: AdvantaColors.goldLight, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: AdvantaText.body2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter untuk scan-line shimmer di background
class _ShimmerScanPainter extends CustomPainter {
  final double progress;
  _ShimmerScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * ((progress + 1.5) / 4.0).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AdvantaColors.lightGreen.withAlpha(18),
          AdvantaColors.lightGreen.withAlpha(30),
          AdvantaColors.lightGreen.withAlpha(18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 60), paint);
  }

  @override
  bool shouldRepaint(_ShimmerScanPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// SELECTED FIELDS SHEET (Mass Inspect List View)
// ─────────────────────────────────────────────────────────────
class _SelectedFieldsSheet extends StatelessWidget {
  // UBAH: Tipe data menjadi ParsedFieldData
  final List<ParsedFieldData> fields;
  final void Function(String fieldNumber) onRemove;

  const _SelectedFieldsSheet({
    required this.fields,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AdvantaColors.deepForest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdvantaColors.goldLight.withAlpha(46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AdvantaColors.primaryGreen.withAlpha(51),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.checklist_rtl, color: AdvantaColors.lightGreen, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Lahan Dipilih',
                            style: AdvantaText.heading3.copyWith(color: Colors.white),
                          ),
                          Text(
                            '${fields.length} lahan siap diinspeksi',
                            style: AdvantaText.caption.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.white54, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: AdvantaColors.goldLight.withAlpha(20), height: 1),

              // Daftar Lahan
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: fields.length,
                  separatorBuilder: (_, __) => Divider(
                    color: AdvantaColors.goldLight.withAlpha(15),
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (_, i) {
                    final f = fields[i];
                    // UBAH: Akses nilai dari objek ParsedFieldData
                    final fn = f.raw['field_number']?.toString() ?? '—';
                    final farmer = f.raw['farmer_name']?.toString() ?? '—';
                    final hybrid = f.raw['hybrid']?.toString() ?? '—';
                    final dap = f.dap.toString(); // Ambil langsung dari f.dap

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AdvantaColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        fn,
                                        style: AdvantaText.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'DAP $dap',
                                      style: AdvantaText.caption.copyWith(color: Colors.white54),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  farmer,
                                  style: AdvantaText.bodyBold.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hybrid: $hybrid',
                                  style: AdvantaText.caption.copyWith(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => onRemove(fn),
                            icon: const Icon(Icons.remove_circle_outline, color: AdvantaColors.error),
                            tooltip: 'Hapus dari daftar',
                          ),
                        ],
                      ),
                    );
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