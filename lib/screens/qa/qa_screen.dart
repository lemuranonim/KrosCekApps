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

import 'dart:async';
import 'dart:math' as math;

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
import '../../utils/qa_name_helper.dart';
import '../../widgets/audit_status_widgets.dart';
import '../../widgets/phase_asset_icon.dart';

// ─── Work mode enum ──────────────────────────────────────
enum _WorkMode { single, mass }

// ─── Audit Status filter enum ────────────────────────────
enum _AuditFilter {
  all, // Semua lahan
  sampun, // Sudah audit fase aktif
  partial, // Dereng Jangkep (generatif sebagian)
  dereng, // Belum audit sama sekali (Dereng Blas)
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
  final GlobalKey _mapViewKey = GlobalKey();
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

  // ── Polygon overlay ────────────────────────────────────
  static const double _polygonMinZoom = 14.0;
  static const double _polygonViewportPaddingFactor = 0.35;
  static const double _markerViewportPaddingFactor = 0.20;
  double _currentZoom = 8.0;
  bool _showPolygons = true; // toggle on/off oleh user
  final LayerHitNotifier<ParsedFieldData> _polygonHitNotifier =
      ValueNotifier<LayerHitResult<ParsedFieldData>?>(null);
  ParsedFieldData? _editingPolygonField;
  List<LatLng> _editingPolygonPoints = [];
  final List<List<LatLng>> _polygonEditUndoStack = [];
  int? _selectedPolygonVertexIndex;
  bool _isSavingPolygon = false;
  bool _isSavingCorrectionTagging = false;
  bool _isPolygonSheetOpen = false;

  // ── State Minggu Kerja ──────────────────────────────────
  late List<Map<String, dynamic>> _workWeeks; // UBAH JADI dynamic
  late Map<String, dynamic> _selectedWeek; // UBAH JADI dynamic

  // ── User GPS location ──────────────────────────────────
  LatLng? _userLocation;
  bool _isLocating = false;
  bool _gpsEnabled = false;
  StreamSubscription<Position>? _positionSub;

  // ── Loading / Refresh overlay ─────────────────────────
  bool _isRefreshing = false;
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;
  late AnimationController _refreshSpinCtrl;

  late AnimationController _speedDialCtrl;

  ActivePhaseView _activePhaseView = ActivePhaseView.auto;
  _AuditFilter _auditFilter = _AuditFilter.all;

  // ── Cache for filtered fields ──────────────────────────
  List<ParsedFieldData>? _cachedFilteredFields;
  Object? _lastFilterKey;

  // ── Cache for markers ──────────────────────────────────
  List<Marker>? _cachedMarkers;
  Object? _lastMarkerKey;

  void _clearMapCaches() {
    _cachedFilteredFields = null;
    _lastFilterKey = null;
    _cachedMarkers = null;
    _lastMarkerKey = null;
  }

  void _refreshMapProviders() {
    _clearMapCaches();
    ref.invalidate(masterFieldsProvider);
    ref.invalidate(parsedMapFieldsProvider);
  }

  void _handleInspectDone(Map<String, dynamic> fieldData) {
    unawaited(_refreshAndOpenFreshField(fieldData));
  }

  Future<void> _refreshAndOpenFreshField(Map<String, dynamic> fieldData) async {
    final fieldNumber = fieldData['field_number']?.toString();

    _refreshMapProviders();

    if (fieldNumber == null || fieldNumber.isEmpty) return;

    try {
      final parsedFields = await ref.read(parsedMapFieldsProvider.future);
      if (!mounted) return;

      Map<String, dynamic>? freshField;
      for (final f in parsedFields) {
        if (f.raw['field_number']?.toString() == fieldNumber) {
          freshField = f.raw;
          break;
        }
      }

      FieldDetailBottomSheet.show(
        context,
        freshField ?? fieldData,
        onInspectDone: _handleInspectDone,
      );
    } catch (_) {
      if (!mounted) return;
      FieldDetailBottomSheet.show(
        context,
        fieldData,
        onInspectDone: _handleInspectDone,
      );
    }
  }

  // FUNGSI BARU: Menghitung proyeksi DAP berdasarkan minggu yang dipilih
  int _getProjectedDap(int currentDap) {
    return currentDap + _getWeekProjectionDeltaDays();
  }

  int _getWeekProjectionDeltaDays() {
    if (_selectedWeek.isEmpty || _selectedWeek['startDate'] == null) {
      return 0; // Jika "Semua Minggu" dipilih, gunakan DAP asli
    }

    final weekStart = _selectedWeek['startDate'] as DateTime;
    final today = DateTime.now();

    // Normalisasi jam agar hitungan hari presisi
    final normalizedWeekStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final targetDate = normalizedWeekStart.add(
      Duration(days: today.weekday - normalizedWeekStart.weekday),
    );
    final normalizedTarget =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return normalizedTarget.difference(normalizedToday).inDays;
  }

  // FUNGSI BARU: Mengecek apakah lahan masuk jendela operasional pada minggu yang dipilih
  bool _isFieldActiveInSelectedWeek(ParsedFieldData f) {
    // Jika "Semua Minggu" dipilih, kembalikan true (biarkan filter fase normal yang bekerja)
    if (_selectedWeek.isEmpty ||
        _selectedWeek['startDate'] == null ||
        _selectedWeek['endDate'] == null) {
      return true;
    }

    final int currentDap = f.dap;
    final bool isSc = DapHelper.isSweetCorn(f.raw['hybrid']?.toString());

    final startDate = _selectedWeek['startDate'] as DateTime;
    final endDate = _selectedWeek['endDate'] as DateTime;
    final today = DateTime.now();

    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Hitung DAP di hari pertama dan hari terakhir pada minggu yang dipilih
    final dapAtStart =
        currentDap + normalizedStart.difference(normalizedToday).inDays;
    final dapAtEnd =
        currentDap + normalizedEnd.difference(normalizedToday).inDays;

    // Tentukan target range DAP berdasarkan fase inspeksi FC/SC,
    // termasuk window overdue yang masih dihitung sebagai fase tersebut.
    final targetRanges = DapHelper.getOperationalRanges(
      _activePhaseView,
      hybrid: isSc ? 'AX01' : null,
    );

    // Cek apakah range umur lahan [dapAtStart - dapAtEnd] bersinggungan dengan target fase
    for (final range in targetRanges) {
      final phaseStart = range[0];
      final phaseEnd = range[1];

      // Rumus Overlap: (Start A <= End B) dan (End A >= Start B)
      if (dapAtStart <= phaseEnd && dapAtEnd >= phaseStart) {
        return true; // Lahan aktif di fase ini pada minggu tersebut!
      }
    }

    return false; // Lahan berada di luar jendela operasional (misal: fase kosong / overdue)
  }

  List<Map<String, dynamic>> _generateDynamicWorkWeeks() {
    final now = DateTime.now();
    // UBAH: Dari 2 (Selasa) menjadi 1 (Senin)
    final int startDayOfWeek = 1;

    // Logika pencarian hari Senin terdekat
    int daysToSubtract = now.weekday - startDayOfWeek;
    if (daysToSubtract < 0) daysToSubtract += 7;

    final DateTime startOfThisWeek =
        now.subtract(Duration(days: daysToSubtract));

    List<Map<String, dynamic>> weeks = [];

    for (int i = -4; i <= 3; i++) {
      // Saya set -4 agar bisa mundur lebih jauh
      final start = DateTime(
              startOfThisWeek.year, startOfThisWeek.month, startOfThisWeek.day)
          .add(Duration(days: i * 7));
      final end = start.add(const Duration(days: 6)); // Senin + 6 hari = Minggu

      final startFormat = DateFormat('d MMM', 'id_ID').format(start);
      final endFormat = DateFormat('d MMM', 'id_ID').format(end);

      final String dateLabel = start.month == end.month
          ? '${start.day}–$endFormat'
          : '$startFormat–$endFormat';

      final int dayOfYear = int.parse(DateFormat("D").format(start));
      int weekNumber = ((dayOfYear - start.weekday + 10) / 7).floor();

      weeks.add({
        'label': 'W$weekNumber',
        'date': dateLabel,
        'startDate': start,
        'endDate': end,
      });
    }
    return weeks;
  }

  // FUNGSI BARU 1: Membuat daftar minggu yang panjang (misal -26 minggu ke belakang sampai +26 ke depan)
  List<Map<String, dynamic>> _generateExtendedWeeks() {
    final now = DateTime.now();
    final int startDayOfWeek = 1; // UBAH JADI 1 (Senin)

    int daysToSubtract = now.weekday - startDayOfWeek;
    if (daysToSubtract < 0) daysToSubtract += 7;

    final DateTime startOfThisWeek =
        now.subtract(Duration(days: daysToSubtract));

    List<Map<String, dynamic>> extendedWeeks = [];

    for (int i = -26; i <= 26; i++) {
      final start = DateTime(
              startOfThisWeek.year, startOfThisWeek.month, startOfThisWeek.day)
          .add(Duration(days: i * 7));
      final end = start.add(const Duration(days: 6));

      final startFormat = DateFormat('d MMM', 'id_ID').format(start);
      final endFormat = DateFormat('d MMM', 'id_ID').format(end);
      final String dateLabel = start.month == end.month
          ? '${start.day}–$endFormat'
          : '$startFormat–$endFormat';

      final int dayOfYear = int.parse(DateFormat("D").format(start));
      int weekNumber = ((dayOfYear - start.weekday + 10) / 7).floor();
      if (weekNumber < 1) weekNumber = 52;

      final yearLabel = start.year != now.year ? ' ${start.year}' : '';

      extendedWeeks.add({
        'label': 'W$weekNumber$yearLabel',
        'date': dateLabel,
        'startDate': start,
        'endDate': end,
      });
    }
    return extendedWeeks;
  }

  // FUNGSI BARU 2: Menampilkan Bottom Sheet untuk memilih minggu manual
  void _showExtendedWeekPicker() {
    final extendedWeeks = _generateExtendedWeeks();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
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
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Pilih Minggu Manual',
                    style: AdvantaText.heading3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withAlpha(20), height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: extendedWeeks.length,
                      itemBuilder: (context, index) {
                        final week = extendedWeeks[index];
                        final isSelected = _selectedWeek.isNotEmpty &&
                            _selectedWeek['label'] == week['label'];

                        return ListTile(
                          title: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  week['label'],
                                  style: AdvantaText.bodyBold
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                              Text(
                                week['date'],
                                style: AdvantaText.body2
                                    .copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: AdvantaColors.lightGreen)
                              : const Icon(Icons.chevron_right,
                                  color: Colors.white24),
                          onTap: () {
                            setState(() => _selectedWeek = week);
                            Navigator.pop(context); // Tutup bottom sheet
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // ── Generate Minggu Dinamis ──
    _workWeeks = _generateDynamicWorkWeeks();
    // Set default pilihan ke "Minggu Ini" (index 2 karena kita mulai dari -2)
    final now = DateTime.now();
    _selectedWeek = _workWeeks.firstWhere((week) {
      final start = week['startDate'] as DateTime;
      final end = week['endDate'] as DateTime;
      // Cek apakah hari ini berada di antara startDate dan endDate
      return now.isAfter(start.subtract(const Duration(days: 1))) &&
          now.isBefore(end.add(const Duration(days: 1)));
    }, orElse: () => _workWeeks[4]); // Fallback ke index 4 jika meleset

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
    _polygonHitNotifier.addListener(_handlePolygonHit);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _polygonHitNotifier.removeListener(_handlePolygonHit);
    _polygonHitNotifier.dispose();
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
    _startLocationStream();
  }

  Future<void> _fetchAndMoveToUser({bool centerMap = false}) async {
    if (_isLocating) return;
    if (mounted) setState(() => _isLocating = true);

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _gpsEnabled = true;
        _isLocating = false;
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

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _gpsEnabled = true;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _gpsEnabled = false);
    });
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
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Color helpers ───────────────────────────────────────
  // Warna fase DAP — tetap hardcoded karena merupakan data semantik,
  // bukan tema UI. Digunakan di map markers & legenda.
  static const _phaseColors = [
    Color(0xFF78909C), // Vegetative   0-49 DAP (36-49 overdue)
    Color(0xFFFFCA28), // Generative1  50-54
    Color(0xFFFF7043), // Generative2  55-59
    Color(0xFFE53935), // Generative3  60-70 (66-70 overdue)
    Color(0xFF795548), // Pre-Harvest  71-94 (91-94 overdue)
    Color(0xFF43A047), // Harvest      ≥95
  ];

  Color _markerColor(int dap, {String? hybrid}) {
    return DapHelper.getDapMarkerColor(dap, hybrid: hybrid);
  }

  // ─── Helpers ────────────────────────────────────────────
  List<ParsedFieldData> _getFilteredFields(List<ParsedFieldData> allParsed) {
    // Buat key unik berdasarkan semua parameter filter
    final filterKey = [
      identityHashCode(allParsed),
      allParsed.length,
      _selectedRegion,
      _selectedDistrict,
      _activeFilters.length,
      _activeFilters.map((f) => '${f.param.fieldKey}:${f.value}').join(','),
      _selectedWeek['label'],
      _activePhaseView,
      _auditFilter,
    ].join('|');

    if (_cachedFilteredFields != null && _lastFilterKey == filterKey) {
      return _cachedFilteredFields!;
    }

    _lastFilterKey = filterKey;
    _cachedFilteredFields = _filterFields(allParsed);
    return _cachedFilteredFields!;
  }

  List<ParsedFieldData> _filterFields(List<ParsedFieldData> allParsed) {
    final selRegion = _selectedRegion?.trim().toLowerCase();
    final selDistrict = _selectedDistrict?.trim().toLowerCase();

    return allParsed.where((f) {
      // ── Proyeksi DAP untuk Visual Marker ──
      final int projectedDap = _getProjectedDap(f.dap);
      final ActivePhaseView projectedPhase = _activePhaseView ==
              ActivePhaseView.auto
          ? _dapToPhaseView(projectedDap, hybrid: f.raw['hybrid']?.toString())
          : _activePhaseView;

      // ── Region, District, & Multi-param filters (TETAP SAMA) ──
      if (selRegion != null) {
        final dbRegion = f.raw['region']?.toString().trim().toLowerCase() ?? '';
        if (dbRegion != selRegion) return false;
      }
      if (selDistrict != null) {
        final dbDistrict =
            f.raw['district_kab']?.toString().trim().toLowerCase() ?? '';
        if (dbDistrict != selDistrict) return false;
      }
      for (final filter in _activeFilters) {
        if (filter.value.trim().isEmpty) continue;
        final q = filter.value.trim().toLowerCase();
        if (filter.param == SearchParam.qaFI) {
          if (!QaNameHelper.fieldMatchesFiSearch(f.raw, q)) return false;
        } else {
          final dbVal =
              f.raw[filter.param.fieldKey]?.toString().toLowerCase().trim() ??
                  '';
          if (!dbVal.contains(q)) return false;
        }
      }

      // ── LOGIKA BARU: FILTER FASE & MINGGU (SIMULASI DAP) ──
      if (_selectedWeek.isNotEmpty) {
        // Jika user memilih minggu spesifik, cek apakah lahan ini punya hari aktif
        // di fase tersebut pada rentang hari Senin-Minggu.
        if (!_isFieldActiveInSelectedWeek(f)) return false;
      }

      // ── Audit Status filter (TETAP SAMA) ──
      if (_auditFilter != _AuditFilter.all) {
        final auditStatus = AuditStatusHelper.fromRaw(f.raw);
        // Tetap gunakan projectedPhase agar status di map menyesuaikan kondisi minggu yang dicek
        final phaseToCheck = projectedPhase;

        switch (_auditFilter) {
          case _AuditFilter.sampun:
            // Gunakan isAuditDoneFor dengan projectedDap agar granularity generatif terjaga
            if (!auditStatus.isAuditDoneFor(phaseToCheck, projectedDap)) {
              return false;
            }
            break;
          case _AuditFilter.dereng:
            if (auditStatus.isAuditDoneFor(phaseToCheck, projectedDap)) {
              return false;
            }
            if (phaseToCheck == ActivePhaseView.generative &&
                auditStatus.generative == GenerativeAuditStatus.derengJangkep) {
              return false;
            }
            break;
          case _AuditFilter.partial:
            if (phaseToCheck != ActivePhaseView.generative) {
              return false;
            }
            if (auditStatus.generative != GenerativeAuditStatus.derengJangkep) {
              return false;
            }
            break;
          case _AuditFilter.all:
            break;
        }
      }

      return true;
    }).toList();
  }

  // Helper: resolve phase dari DAP (duplikat dari MarkerAuditDot, tapi perlu di state level)
  ActivePhaseView _dapToPhaseView(int dap, {String? hybrid}) {
    return DapHelper.getActivePhaseView(dap, hybrid: hybrid);
  }

  bool _isAuditDoneForPhaseKey(FieldAuditStatus status, String phaseKey) {
    switch (phaseKey) {
      case 'vegetative':
        return status.vegetative == SingleAuditStatus.sampun;
      case 'generative_1':
        return status.gen1Done;
      case 'generative_2':
        return status.gen2Done;
      case 'generative_3':
        return status.gen3Done;
      case 'generative_4':
        return status.gen4Done;
      case 'generative_5':
        return status.gen5Done;
      case 'pre_harvest':
        return status.preHarvest == SingleAuditStatus.sampun;
      case 'harvest':
        return status.harvest == SingleAuditStatus.sampun;
      default:
        return false;
    }
  }

  bool _hasOverdueInspection(
    FieldAuditStatus status,
    int dap, {
    String? hybrid,
  }) {
    return DapHelper.getPhaseRules(hybrid: hybrid).any((rule) {
      final isDone = _isAuditDoneForPhaseKey(status, rule.key);
      return DapHelper.getDapBadgeLabel(
            dap,
            rule.key,
            hybrid: hybrid,
            isDone: isDone,
          ) ==
          'Overdue';
    });
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
            onInspectDone: _handleInspectDone,
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
    final regions = ref.watch(uniqueRegionsProvider);
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

    // Semua user yang masuk ke /qa bisa akses Coverage Dashboard.
    // Filtering view di dalam dashboard sudah ditangani per role
    // (FI → operasional, SPV → tim, Manager/Dev → bird-eye).
    // Hanya 'guest' yang dikecualikan karena read-only.
    final bool canSeeCoverage =
        user != null && user.role.toLowerCase() != 'guest';
    final bool canUseMassInspect =
        user != null && user.role.toLowerCase() != 'guest';

    if (!canUseMassInspect && _workMode == _WorkMode.mass) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _workMode != _WorkMode.mass) return;
        setState(() {
          _workMode = _WorkMode.single;
          _selectedFieldNumbers.clear();
        });
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. MAP ─────────────────────────────────────────
          parsedMapAsync.when(
            data: (parsedFields) {
              final filtered = _getFilteredFields(parsedFields);
              return _buildMap(filtered, parsedFields); // Selalu tampilkan map
            },
            loading: () => const SizedBox.expand(),
            error: (e, _) => _buildError(e.toString()),
          ),

          // ── 1b. REFRESH OVERLAY ────────────────────────────
          if (_isRefreshing && masterAsync is! AsyncLoading)
            _buildRefreshOverlay(),

          // ── 2. NEW UNIFIED TOP OVERLAY (Minimalist) ────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              key: _topOverlayKey,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AdvantaColors.deepForest.withAlpha(240),
                    AdvantaColors.deepForest.withAlpha(150),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // BARIS 1: Unified Search & Action Bar
                    _buildUnifiedTopBar(attendance),

                    // BARIS 2: Gabungan Semua Filter (Region, District, QA, Status, Fase)
                    if (masterAsync is AsyncData)
                      _buildUnifiedFilters(
                        regions: regions,
                        districts: districts,
                        qaList: ref.watch(uniqueQAProvider(QAFilterParams(
                          region: _selectedRegion,
                          district: _selectedDistrict,
                        ))),
                        userRole: user?.role, // <── TAMBAHKAN BARIS INI
                      ),

                    // BARIS 3: Uncoord Banner (Dibuat lebih tipis/compact)
                    if (masterAsync is AsyncData)
                      parsedMapAsync.whenData((parsedFields) {
                            final uncoordFields = _filterFields(parsedFields)
                                .where((f) => f.isDefault)
                                .map((f) => f.raw)
                                .toList();
                            if (uncoordFields.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return _buildCompactUncoordBanner(uncoordFields);
                          }).value ??
                          const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. FLOATING WORK MODE TOGGLE ───────────────────
          // Dipindah ke bawah agar tidak menutupi map atas
          if (masterAsync is AsyncData && _editingPolygonField == null)
            Positioned(
              bottom: _workMode == _WorkMode.mass
                  ? 116
                  : 32, // Sesuaikan dengan Mass Bar
              left: 16, // Taruh di kiri bawah, berseberangan dengan Speed Dial
              child:
                  _buildFloatingModeToggle(canSeeCoverage, canUseMassInspect),
            ),

          // ── 5. RIGHT FABs ──────────────────────────────────
          if (masterAsync is AsyncData && _editingPolygonField == null)
            Positioned(
              right: 12,
              bottom: _workMode == _WorkMode.mass ? 116 : 32,
              child: _buildRightFabs(masterAsync),
            ),
          // ── 5b. DISMISS BARRIER UNTUK LEGENDA ──
          // Jika legenda muncul, buat lapisan transparan di seluruh layar untuk menangkap tap
          if (_isLegendVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isLegendVisible = false),
                child: Container(color: Colors.transparent),
              ),
            ),

          // ── 6. LEGEND ─────────────────────────────────────────────
          if (_isLegendVisible && masterAsync is AsyncData)
            Positioned(
              right: 62, // ← sebelumnya 68, sekarang sejajar tombol speed-dial
              bottom: _workMode == _WorkMode.mass ? 116 : 32,
              child: _buildLegend(),
            ),

          // ── 7. MASS INSPECT BAR ───────────────────────────
          if (_workMode == _WorkMode.mass &&
              masterAsync is AsyncData &&
              _editingPolygonField == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildMassBar(),
            ),

          if (_editingPolygonField != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildPolygonEditToolbar(),
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

  // ─── DESAIN BARU: COMPACT HEADER BUILDERS ─────────────────────────────────

  // 1. Unified Top Bar (Search + Attendance + Settings dalam 1 baris)
  Widget _buildUnifiedTopBar(AttendanceState att) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Dot Attendance Compact
          _CompactAttendanceDot(attendance: att),
          const SizedBox(width: 8),

          // Search Bar di Tengah
          Expanded(
              child:
                  _buildNewRow2Search()), // Gunakan fungsi search bar kamu yang sudah ada

          const SizedBox(width: 8),

          // Tombol Refresh Mini
          GestureDetector(
            onTap: () async {
              if (_isRefreshing) return;
              setState(() => _isRefreshing = true);
              _refreshSpinCtrl.repeat();
              await SupabaseAuthService().restoreSession();
              ref.invalidate(currentUserProvider);
              _refreshMapProviders();
            },
            child: AnimatedBuilder(
              animation: _refreshSpinCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _isRefreshing ? _refreshSpinCtrl.value * 6.28319 : 0,
                child: child,
              ),
              child: const _NewActionPill(icon: Icons.sync_rounded),
            ),
          ),

          const SizedBox(width: 6),

          // Tombol Settings Mini
          GestureDetector(
            onTap: () => context.push('/qa/settings'),
            child: const _NewActionPill(icon: Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  // 2. Filter Bar (Peringkas: 3 Baris Terpisah)
  Widget _buildUnifiedFilters({
    required List<String> regions,
    required List<String> districts,
    required List<String> qaList,
    String? userRole,
  }) {
    String getAuditLabel() {
      switch (_auditFilter) {
        case _AuditFilter.all:
          return 'Status';
        case _AuditFilter.sampun:
          return 'Sampun';
        case _AuditFilter.partial:
          return 'Jangkep';
        case _AuditFilter.dereng:
          return 'Belum';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── BARIS 1: WEEK PICKER (Memanjang Full Width) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity, // <── Membuatnya memanjang penuh
            child: _NewWeekPickerChip(
              selectedWeek: _selectedWeek,
              workWeeks: _workWeeks,
              onSelected: (val) {
                if (val.containsKey('action') && val['action'] == 'manual') {
                  _showExtendedWeekPicker();
                } else {
                  setState(() => _selectedWeek = val);
                }
              },
            ),
          ),
        ),

        // ── BARIS 2: LOKASI & STATUS (Dapat Digeser) ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _FilterPopupChip<String>(
                // Hilangkan kurung kurawal menjadi:
                key: ValueKey('reg_$_selectedRegion'),
                icon: Icons.map_outlined,
                // Pastikan label kembali ke "Semua Region" jika null
                label: _selectedRegion ?? 'Semua Region',
                currentValue: _selectedRegion,
                items: regions,
                itemLabel: (s) => s,
                isActive: _selectedRegion != null,
                onSelected: (val) {
                  setState(() {
                    _selectedRegion = val; // val akan null jika pilih "Semua"
                    _selectedDistrict = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              if (districts.isNotEmpty) ...[
                _FilterPopupChip<String>(
                  // Hilangkan kurung kurawal menjadi:
                  key: ValueKey('dist_$_selectedDistrict'),
                  icon: Icons.location_city_outlined,
                  label: _selectedDistrict ?? 'Semua Kabupaten',
                  currentValue: _selectedDistrict,
                  items: districts,
                  itemLabel: (s) => s,
                  enabled: true,
                  isActive: _selectedDistrict != null,
                  onSelected: (val) => setState(() => _selectedDistrict = val),
                ),
                const SizedBox(width: 8),
              ],
              _NewQuickFilterChip(
                icon: Icons.checklist_rtl_outlined,
                label: getAuditLabel(),
                hasDropdown: true,
                isActive: _auditFilter != _AuditFilter.all,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => _AuditStatusSheet(
                      currentFilter: _auditFilter,
                      activePhase: _activePhaseView,
                      onSelected: (selectedFilter) {
                        setState(() => _auditFilter = selectedFilter);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── BARIS 3: FASE (Ikon Ringkas) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildPhaseIconButton(ActivePhaseView.auto, Icons.auto_awesome),
              const SizedBox(width: 8),
              _buildPhaseIconButton(
                  ActivePhaseView.vegetative, Icons.eco_outlined),
              const SizedBox(width: 8),
              _buildPhaseIconButton(
                  ActivePhaseView.generative, Icons.grass_rounded),
              const SizedBox(width: 8),
              _buildPhaseIconButton(
                  ActivePhaseView.preHarvest, Icons.agriculture_outlined),
              const SizedBox(width: 8),
              _buildPhaseIconButton(
                  ActivePhaseView.harvest, Icons.grain_rounded),
            ],
          ),
        ),
      ],
    );
  }

  // Fungsi Helper baru untuk membuat Tombol Ikon Fase yang ringkas
  Widget _buildPhaseIconButton(ActivePhaseView phase, IconData icon) {
    final isActive = _activePhaseView == phase;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activePhaseView = phase;
          // Logika reset filter parsial jika pindah dari generatif
          if (phase != ActivePhaseView.generative &&
              phase != ActivePhaseView.auto &&
              _auditFilter == _AuditFilter.partial) {
            _auditFilter = _AuditFilter.all;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? AdvantaColors.primaryGreen.withAlpha(80)
              : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AdvantaColors.lightGreen
                : Colors.white.withAlpha(30),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: AdvantaColors.primaryGreen.withAlpha(60),
                      blurRadius: 8)
                ]
              : [],
        ),
        child: Icon(icon,
            color: isActive ? Colors.white : Colors.white60, size: 18),
      ),
    );
  }

  // 3. Uncoord Banner Compact
  Widget _buildCompactUncoordBanner(List<Map<String, dynamic>> uncoordFields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _showDefaultCoordSheet(uncoordFields),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdvantaColors.error.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdvantaColors.error),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(
                '${uncoordFields.length} Lahan Tanpa Koordinat',
                style: AdvantaText.caption
                    .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Floating Mode Toggle (Ditaruh di Kiri Bawah)
  Widget _buildFloatingModeToggle(bool canSeeCoverage, bool canUseMassInspect) {
    return Container(
      decoration: BoxDecoration(
        color: AdvantaColors.deepForest.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20)),
        boxShadow: AdvantaShadows.card(true),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactSegmentButton(
            icon: Icons.touch_app_outlined,
            isActive: _workMode == _WorkMode.single,
            onTap: () => setState(() {
              _workMode = _WorkMode.single;
              _selectedFieldNumbers.clear();
            }),
          ),
          if (canUseMassInspect)
            _CompactSegmentButton(
              icon: Icons.checklist_rtl_outlined,
              isActive: _workMode == _WorkMode.mass,
              onTap: () => setState(() => _workMode = _WorkMode.mass),
            ),
          if (canSeeCoverage)
            _CompactSegmentButton(
              icon: Icons.analytics_outlined,
              isActive: false,
              isWarning: true,
              onTap: () => context.push('/coverage'),
            ),
        ],
      ),
    );
  }

  Widget _buildPolygonEditToolbar() {
    final field = _editingPolygonField?.raw;
    final fieldNumber = field?['field_number']?.toString() ?? '-';
    final canDelete = _selectedPolygonVertexIndex != null &&
        _editingPolygonPoints.length > 3 &&
        !_isSavingPolygon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdvantaColors.deepForest.withAlpha(238),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdvantaColors.gold.withAlpha(120)),
        boxShadow: AdvantaShadows.card(true),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AdvantaColors.gold.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_location_alt_outlined,
                    color: AdvantaColors.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fieldNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.bodyBold.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${_editingPolygonPoints.length} titik polygon',
                      style:
                          AdvantaText.caption.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isSavingPolygon ? null : _savePolygonEdit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 42,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isSavingPolygon
                        ? AdvantaColors.primaryGreen.withAlpha(90)
                        : AdvantaColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isSavingPolygon
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PolygonToolButton(
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: 'Fit polygon',
                  onTap: _isSavingPolygon ? null : _fitEditingPolygon,
                ),
                _PolygonToolButton(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  onTap: _polygonEditUndoStack.isEmpty || _isSavingPolygon
                      ? null
                      : _undoPolygonEdit,
                ),
                _PolygonToolButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Hapus titik',
                  color: AdvantaColors.error,
                  onTap: canDelete ? _deleteSelectedPolygonVertex : null,
                ),
                _PolygonToolButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Reset',
                  onTap: _isSavingPolygon ? null : _resetPolygonEdit,
                ),
                _PolygonToolButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Batal',
                  onTap: _isSavingPolygon ? null : _cancelPolygonEdit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAP ─────────────────────────────────────────────────
  List<Marker> _getMarkers(
    List<ParsedFieldData> fieldsData, {
    required bool stackDefaultMarkers,
  }) {
    final dataToMark = stackDefaultMarkers
        ? fieldsData.where((f) => !f.isDefault).toList()
        : fieldsData;
    final selectedKey = _selectedFieldNumbers.toList()..sort();
    final markerCoordinateHash = Object.hashAll(dataToMark.map((f) {
      return Object.hash(
        f.raw['field_number']?.toString() ?? '',
        f.lat,
        f.lng,
        f.isDefault,
        f.isCorrected,
        f.isFromPolygon,
      );
    }));

    // Buat key untuk cache marker
    final markerKey = [
      fieldsData.length,
      dataToMark.length,
      markerCoordinateHash,
      selectedKey.join(','),
      _workMode,
      _activePhaseView,
      stackDefaultMarkers,
    ].join('|');

    if (_cachedMarkers != null && _lastMarkerKey == markerKey) {
      return _cachedMarkers!;
    }

    _lastMarkerKey = markerKey;
    _cachedMarkers = _buildMarkers(dataToMark);
    return _cachedMarkers!;
  }

  Widget _buildMap(
      List<ParsedFieldData> fieldsData, List<ParsedFieldData> allFields) {
    final uncoordRaw =
        fieldsData.where((f) => f.isDefault).map((f) => f.raw).toList();
    // final coordFields = fieldsData.where((f) => !f.isDefault).toList();

    final visibleMarkerFields = _getVisibleMarkerFields(fieldsData);
    final polygonFields = _getVisiblePolygonFields(fieldsData);

    return FlutterMap(
      key: _mapViewKey,
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(-7.5, 112.5),
        initialZoom: 8.0,
        maxZoom: 18.0,
        // ── Optimasi: Kurangi frekuensi rebuild saat zoom ──
        onMapEvent: (event) {
          final newZoom = _mapController.camera.zoom;
          final crossedPolygonZoom = (_currentZoom < _polygonMinZoom &&
                  newZoom >= _polygonMinZoom) ||
              (_currentZoom >= _polygonMinZoom && newZoom < _polygonMinZoom);
          final zoomChangedEnough = (newZoom - _currentZoom).abs() > 0.5;
          final viewportSettled = event is MapEventMoveEnd ||
              event is MapEventFlingAnimationEnd ||
              event is MapEventDoubleTapZoomEnd ||
              event is MapEventScrollWheelZoom;

          if (zoomChangedEnough || crossedPolygonZoom || viewportSettled) {
            setState(() => _currentZoom = newZoom);
          }
        },
        onTap: (_, __) {
          if (_isLegendVisible || _isSpeedDialOpen) {
            setState(() {
              _isLegendVisible = false;
              _isSpeedDialOpen = false;
              _speedDialCtrl.reverse();
            });
          }
        },
      ),
      children: [
        // ── 1. Tile Layer (basemap) ────────────────────────
        TileLayer(
          urlTemplate: _isSatellite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kroscek.app',
          maxNativeZoom: 18,
          // Optimasi: Gunakan cache untuk tile jika memungkinkan (bawaan flutter_map)
        ),

        // ── 2. Polygon Layer (tampil saat zoom >= 14) ──────
        // Render di bawah marker agar marker tetap terlihat di atas
        if (_editingPolygonField != null)
          _buildEditingPolygonLayer()
        else if (polygonFields.isNotEmpty)
          _buildPolygonLayer(polygonFields),

        // ── 3. User location marker ────────────────────────
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 52,
                height: 52,
                child: _UserLocationMarker(isLocating: _isLocating),
              ),
            ],
          ),

        // ── 4. Uncoord stack marker ────────────────────────
        if (uncoordRaw.length > 4)
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(-7.637017, 112.8272303),
                width: 72,
                height: 72,
                child: GestureDetector(
                  onTap: () => _showDefaultCoordSheet(uncoordRaw),
                  child: _UncoordMarker(count: uncoordRaw.length),
                ),
              ),
            ],
          ),

        // ── 5. Field markers (cluster) ────────────────────
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(46, 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            // Optimasi cluster: matikan animasi jika marker terlalu banyak
            animationsOptions: const AnimationsOptions(
              zoom: Duration.zero,
              fitBound: Duration.zero,
              centerMarker: Duration.zero,
              spiderfy: Duration.zero,
            ),
            markers: _getMarkers(
              visibleMarkerFields,
              stackDefaultMarkers: uncoordRaw.length > 4,
            ),
            builder: (ctx, markers) => _buildCluster(markers.length),
          ),
        ),

        if (_editingPolygonField != null) _buildPolygonEditHandleLayer(),
      ],
    );
  }

  List<Marker> _buildMarkers(List<ParsedFieldData> fieldsData) {
    final result = <Marker>[];

    for (final f in fieldsData) {
      final projectedDap = _getProjectedDap(f.dap);
      final hybrid = f.raw['hybrid']?.toString();
      final color = _markerColor(projectedDap,
          hybrid: hybrid); // Gunakan projectedDap & hybrid
      final fn = f.raw['field_number']?.toString() ?? '';
      final isSelected = _selectedFieldNumbers.contains(fn);
      final isCorrected = f.isCorrected;
      final bool isSc = DapHelper.isSweetCorn(hybrid);

      // Parse audit status
      final auditStatus = AuditStatusHelper.fromRaw(f.raw);
      final markerActivePhase = _activePhaseView == ActivePhaseView.auto
          ? _dapToPhaseView(projectedDap, hybrid: hybrid)
          : _activePhaseView;
      final isOverdue = _hasOverdueInspection(
        auditStatus,
        projectedDap,
        hybrid: hybrid,
      );

      result.add(Marker(
        point: LatLng(f.lat, f.lng),
        width: 56,
        height: 56,
        alignment: Alignment.topCenter,
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              if (_editingPolygonField != null) return;
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
                  onInspectDone: _handleInspectDone,
                );
              }
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ── 0. GOLDEN HALO (FOR SC ONLY) ───────────────────
                if (isSc && !isSelected)
                  Positioned(
                    bottom: 12,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AdvantaColors.gold.withAlpha(220),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: AdvantaColors.gold.withAlpha(150),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── 1. BENTUK MAP PIN (TEARDROP) ───────────────────
                Positioned(
                  bottom: 8,
                  child: Transform.rotate(
                    angle: 45 * (3.14159265359 / 180),
                    child: Container(
                      width: isCorrected ? 38 : 34,
                      height: isCorrected ? 38 : 34,
                      decoration: BoxDecoration(
                        color: isSelected ? AdvantaColors.primaryGreen : color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(3), // Ujung lancip
                        ),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : isCorrected
                                  ? AdvantaColors.gold
                                  : Colors.white,
                          width: isSelected ? 3.0 : 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(120),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── 2. ANGKA DAP ATAU ICON CENTANG ─────────────────
                Positioned(
                  bottom: 18,
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22)
                      : Text(
                          '$projectedDap',
                          style: AdvantaText.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.0,
                          ),
                        ),
                ),

                // ── 3. BADGE KOREKSI (C) ───────────────────────────
                if (isCorrected && !isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
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

                // ── 4. AUDIT STATUS DOT ────────────────────────────
                if (!isSelected)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: MarkerAuditDot(
                      auditStatus: auditStatus,
                      dap: projectedDap, // <--- Gunakan projectedDap
                      activePhase: markerActivePhase,
                      isCorrected: isCorrected,
                    ),
                  ),

                // ── 5. OVERDUE INDICATOR ────────────────────────
                if (!isSelected && isOverdue)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AdvantaColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: AdvantaColors.error.withAlpha(136),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
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

  bool get _isEditingPolygon => _editingPolygonField != null;

  bool get _canEditPolygon {
    final role = ref.read(currentUserProvider).value?.role.toLowerCase();
    return role != null && role != 'guest';
  }

  void _showPolygonActionSheet(ParsedFieldData field) {
    if (_isPolygonSheetOpen) return;
    _isPolygonSheetOpen = true;

    final raw = field.raw;
    final fieldNumber = raw['field_number']?.toString() ?? '-';
    final farmer = raw['farmer_name']?.toString() ?? '-';
    final region = raw['region']?.toString() ?? '-';
    final district = raw['district_kab']?.toString() ?? '-';
    final area = raw['effective_area_ha'] ?? raw['area_ha'] ?? raw['ha'];
    final points = field.polygonPoints ?? const <LatLng>[];
    final canEdit = _canEditPolygon;
    final centroid = _polygonCentroid(points);
    final centroidText =
        centroid == null ? '-' : _formatCorrectionCoordinate(centroid);
    final canCorrect =
        canEdit && centroid != null && !_isSavingCorrectionTagging;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdvantaColors.deepForest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdvantaColors.lightGreen.withAlpha(35)),
            boxShadow: AdvantaShadows.card(true),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AdvantaColors.primaryGreen.withAlpha(60),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pentagon_outlined,
                        color: AdvantaColors.lightGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fieldNumber,
                            style: AdvantaText.bodyBold
                                .copyWith(color: Colors.white)),
                        Text(farmer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdvantaText.caption
                                .copyWith(color: Colors.white60)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 20),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PolygonInfoChip(
                    icon: Icons.location_city_outlined,
                    label: district,
                  ),
                  _PolygonInfoChip(
                    icon: Icons.map_outlined,
                    label: region,
                  ),
                  _PolygonInfoChip(
                    icon: Icons.straighten_rounded,
                    label: area == null ? '-' : '$area ha',
                  ),
                  _PolygonInfoChip(
                    icon: Icons.adjust_rounded,
                    label: '${_openPolygonRing(points).length} titik',
                  ),
                  _PolygonInfoChip(
                    icon: Icons.control_camera_rounded,
                    label: centroidText,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        FieldDetailBottomSheet.show(
                          context,
                          raw,
                          onInspectDone: _handleInspectDone,
                        );
                      },
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text('Detail', style: AdvantaText.button),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withAlpha(45)),
                        shape: RoundedRectangleBorder(
                          borderRadius: AdvantaRadius.buttonRadius,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canCorrect
                          ? () {
                              Navigator.pop(sheetContext);
                              unawaited(_savePolygonCentroidCorrection(field));
                            }
                          : null,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text('Corr. Tag', style: AdvantaText.button),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: AdvantaColors.gold.withAlpha(120),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AdvantaRadius.buttonRadius,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canEdit
                      ? () {
                          Navigator.pop(sheetContext);
                          _startPolygonEdit(field);
                        }
                      : null,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: Text('Edit Polygon', style: AdvantaText.button),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdvantaColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AdvantaRadius.buttonRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _isPolygonSheetOpen = false);
  }

  void _startPolygonEdit(ParsedFieldData field) {
    if (!_canEditPolygon) {
      _showPolygonSnack('Akses edit polygon tidak tersedia.', isError: true);
      return;
    }

    final points = _openPolygonRing(field.polygonPoints ?? const <LatLng>[]);
    if (points.length < 3) {
      _showPolygonSnack('Polygon belum punya minimal 3 titik.');
      return;
    }

    setState(() {
      _editingPolygonField = field;
      _editingPolygonPoints = List<LatLng>.from(points);
      _polygonEditUndoStack.clear();
      _selectedPolygonVertexIndex = null;
      _workMode = _WorkMode.single;
      _selectedFieldNumbers.clear();
      _isLegendVisible = false;
      _isSpeedDialOpen = false;
      _showPolygons = true;
    });
    _speedDialCtrl.reverse();
    _fitPolygonPoints(points);
  }

  void _cancelPolygonEdit() {
    if (_isSavingPolygon) return;
    setState(() {
      _editingPolygonField = null;
      _editingPolygonPoints = [];
      _polygonEditUndoStack.clear();
      _selectedPolygonVertexIndex = null;
    });
  }

  void _pushPolygonUndo() {
    if (_editingPolygonPoints.isEmpty) return;
    _polygonEditUndoStack.add(List<LatLng>.from(_editingPolygonPoints));
    if (_polygonEditUndoStack.length > 25) {
      _polygonEditUndoStack.removeAt(0);
    }
  }

  void _undoPolygonEdit() {
    if (_polygonEditUndoStack.isEmpty || _isSavingPolygon) return;
    setState(() {
      _editingPolygonPoints = _polygonEditUndoStack.removeLast();
      _selectedPolygonVertexIndex = null;
    });
  }

  void _resetPolygonEdit() {
    final field = _editingPolygonField;
    if (field == null || _isSavingPolygon) return;
    final points = _openPolygonRing(field.polygonPoints ?? const <LatLng>[]);
    if (points.length < 3) return;
    _pushPolygonUndo();
    setState(() {
      _editingPolygonPoints = List<LatLng>.from(points);
      _selectedPolygonVertexIndex = null;
    });
    _fitPolygonPoints(points);
  }

  void _insertPolygonVertex(int insertIndex, LatLng point) {
    if (_isSavingPolygon) return;
    _pushPolygonUndo();
    setState(() {
      _editingPolygonPoints.insert(insertIndex, point);
      _selectedPolygonVertexIndex = insertIndex;
    });
  }

  void _deleteSelectedPolygonVertex() {
    final index = _selectedPolygonVertexIndex;
    if (index == null) return;
    _deletePolygonVertex(index);
  }

  void _deletePolygonVertex(int index) {
    if (_isSavingPolygon) return;
    if (_editingPolygonPoints.length <= 3) {
      _showPolygonSnack('Polygon minimal harus punya 3 titik.');
      return;
    }
    if (index < 0 || index >= _editingPolygonPoints.length) return;

    _pushPolygonUndo();
    setState(() {
      _editingPolygonPoints.removeAt(index);
      _selectedPolygonVertexIndex = null;
    });
  }

  void _movePolygonVertex(int index, Offset globalPosition) {
    final latLng = _globalPositionToLatLng(globalPosition);
    if (latLng == null || index < 0 || index >= _editingPolygonPoints.length) {
      return;
    }
    setState(() {
      _editingPolygonPoints[index] = latLng;
      _selectedPolygonVertexIndex = index;
    });
  }

  LatLng? _globalPositionToLatLng(Offset globalPosition) {
    final ctx = _mapViewKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final local = box.globalToLocal(globalPosition);
    return _mapController.camera.pointToLatLng(
      math.Point<double>(local.dx, local.dy),
    );
  }

  Future<void> _savePolygonEdit() async {
    final field = _editingPolygonField;
    if (field == null || _isSavingPolygon) return;
    if (!_canEditPolygon) {
      _showPolygonSnack('Akses edit polygon tidak tersedia.', isError: true);
      return;
    }

    final fieldNumber = field.raw['field_number']?.toString();
    if (fieldNumber == null || fieldNumber.isEmpty) {
      _showPolygonSnack('No. lahan tidak ditemukan.');
      return;
    }
    if (_editingPolygonPoints.length < 3) {
      _showPolygonSnack('Polygon minimal harus punya 3 titik.');
      return;
    }

    setState(() => _isSavingPolygon = true);

    try {
      final geometryWkt = _latLngListToPolygonWkt(_editingPolygonPoints);
      await ref.read(supabaseServiceProvider).updateFieldGeometryWkt(
            fieldNumber: fieldNumber,
            geometryWkt: geometryWkt,
          );

      if (!mounted) return;
      setState(() {
        _editingPolygonField = null;
        _editingPolygonPoints = [];
        _polygonEditUndoStack.clear();
        _selectedPolygonVertexIndex = null;
        _isSavingPolygon = false;
      });
      _refreshMapProviders();
      _showPolygonSnack('Polygon berhasil disimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPolygon = false);
      _showPolygonSnack('Gagal menyimpan polygon: $e', isError: true);
    }
  }

  Future<void> _savePolygonCentroidCorrection(ParsedFieldData field) async {
    if (_isSavingCorrectionTagging) return;
    if (!_canEditPolygon) {
      _showPolygonSnack('Akses correction tagging tidak tersedia.',
          isError: true);
      return;
    }

    final fieldNumber = field.raw['field_number']?.toString();
    if (fieldNumber == null || fieldNumber.isEmpty) {
      _showPolygonSnack('No. lahan tidak ditemukan.');
      return;
    }

    final centroid = _polygonCentroid(field.polygonPoints ?? const <LatLng>[]);
    if (centroid == null) {
      _showPolygonSnack('Centroid polygon belum bisa dihitung.', isError: true);
      return;
    }

    final correctionTagging = _formatCorrectionCoordinate(centroid);
    setState(() => _isSavingCorrectionTagging = true);

    try {
      await ref.read(supabaseServiceProvider).updateFieldCorrectionTagging(
            fieldNumber: fieldNumber,
            correctionTagging: correctionTagging,
          );

      if (!mounted) return;
      setState(() => _isSavingCorrectionTagging = false);
      _refreshMapProviders();
      _showPolygonSnack('Correction tagging disimpan ke centroid polygon.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingCorrectionTagging = false);
      _showPolygonSnack('Gagal menyimpan correction tagging: $e',
          isError: true);
    }
  }

  void _fitEditingPolygon() {
    if (_editingPolygonPoints.length < 3) return;
    _fitPolygonPoints(_editingPolygonPoints);
  }

  void _fitPolygonPoints(List<LatLng> points) {
    if (points.length < 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(86),
          maxZoom: 18.0,
        ),
      );
    });
  }

  List<LatLng> _openPolygonRing(List<LatLng> points) {
    if (points.length < 2) return List<LatLng>.from(points);
    final result = List<LatLng>.from(points);
    if (_sameLatLng(result.first, result.last)) {
      result.removeLast();
    }
    return result;
  }

  List<LatLng> _closedPolygonRing(List<LatLng> points) {
    final result = _openPolygonRing(points);
    if (result.isNotEmpty) result.add(result.first);
    return result;
  }

  bool _sameLatLng(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0000001 &&
        (a.longitude - b.longitude).abs() < 0.0000001;
  }

  String _latLngListToPolygonWkt(List<LatLng> points) {
    final closed = _closedPolygonRing(points);
    final pairs = closed.map((p) {
      final lng = p.longitude.toStringAsFixed(7);
      final lat = p.latitude.toStringAsFixed(7);
      return '$lng $lat';
    }).join(', ');
    return 'POLYGON(($pairs))';
  }

  LatLng? _polygonCentroid(List<LatLng> points) {
    final ring = _openPolygonRing(points);
    if (ring.length < 3) return null;

    double signedArea = 0;
    double centroidLng = 0;
    double centroidLat = 0;

    for (var i = 0; i < ring.length; i++) {
      final current = ring[i];
      final next = ring[(i + 1) % ring.length];
      final cross =
          current.longitude * next.latitude - next.longitude * current.latitude;
      signedArea += cross;
      centroidLng += (current.longitude + next.longitude) * cross;
      centroidLat += (current.latitude + next.latitude) * cross;
    }

    if (signedArea.abs() < 0.000000000001) {
      double sumLng = 0;
      double sumLat = 0;
      for (final p in ring) {
        sumLng += p.longitude;
        sumLat += p.latitude;
      }
      return LatLng(sumLat / ring.length, sumLng / ring.length);
    }

    signedArea *= 0.5;
    return LatLng(
      centroidLat / (6 * signedArea),
      centroidLng / (6 * signedArea),
    );
  }

  String _formatCorrectionCoordinate(LatLng point) {
    return '${point.latitude.toStringAsFixed(7)},${point.longitude.toStringAsFixed(7)}';
  }

  LatLng _midpoint(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  void _showPolygonSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdvantaColors.error : AdvantaColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<ParsedFieldData> _getVisibleMarkerFields(
      List<ParsedFieldData> fieldsData) {
    final visibleBounds = _getExpandedVisibleBounds(
      paddingFactor: _markerViewportPaddingFactor,
    );
    if (visibleBounds == null) return fieldsData;

    return fieldsData.where((f) {
      return _boundsContainsLatLng(visibleBounds, f.lat, f.lng);
    }).toList(growable: false);
  }

  List<ParsedFieldData> _getVisiblePolygonFields(
      List<ParsedFieldData> fieldsData) {
    if (!_showPolygons || _currentZoom < _polygonMinZoom) {
      return const [];
    }

    final visibleBounds = _getExpandedVisibleBounds();
    if (visibleBounds == null) return const [];

    return fieldsData.where((f) {
      final points = f.polygonPoints;
      if (points == null || points.length < 3) return false;
      final bounds = f.polygonBounds ?? LatLngBounds.fromPoints(points);
      return bounds.isOverlapping(visibleBounds);
    }).toList();
  }

  LatLngBounds? _getExpandedVisibleBounds({
    double paddingFactor = _polygonViewportPaddingFactor,
  }) {
    try {
      final bounds = _mapController.camera.visibleBounds;
      final latSpan = (bounds.north - bounds.south).abs();
      final lngSpan = (bounds.east - bounds.west).abs();
      if (latSpan == 0 || lngSpan == 0) return null;

      final latPadding = latSpan * paddingFactor;
      final lngPadding = lngSpan * paddingFactor;

      return LatLngBounds.unsafe(
        north: (bounds.north + latPadding).clamp(
          LatLngBounds.minLatitude,
          LatLngBounds.maxLatitude,
        ),
        south: (bounds.south - latPadding).clamp(
          LatLngBounds.minLatitude,
          LatLngBounds.maxLatitude,
        ),
        east: (bounds.east + lngPadding).clamp(
          LatLngBounds.minLongitude,
          LatLngBounds.maxLongitude,
        ),
        west: (bounds.west - lngPadding).clamp(
          LatLngBounds.minLongitude,
          LatLngBounds.maxLongitude,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  bool _boundsContainsLatLng(LatLngBounds bounds, double lat, double lng) {
    final south = math.min(bounds.south, bounds.north);
    final north = math.max(bounds.south, bounds.north);
    if (lat < south || lat > north) return false;

    final west = bounds.west;
    final east = bounds.east;
    if (west <= east) {
      return lng >= west && lng <= east;
    }
    return lng >= west || lng <= east;
  }

  void _handlePolygonHit() {
    final hit = _polygonHitNotifier.value;
    if (!mounted || _isEditingPolygon || hit == null || hit.hitValues.isEmpty) {
      return;
    }

    final field = hit.hitValues.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isEditingPolygon) return;
      if (identical(_polygonHitNotifier.value, hit)) {
        _polygonHitNotifier.value = null;
      }

      final fieldNumber = field.raw['field_number']?.toString() ?? '';

      if (_workMode == _WorkMode.mass && fieldNumber.isNotEmpty) {
        setState(() {
          if (_selectedFieldNumbers.contains(fieldNumber)) {
            _selectedFieldNumbers.remove(fieldNumber);
          } else {
            _selectedFieldNumbers.add(fieldNumber);
          }
        });
        return;
      }

      if (_isLegendVisible || _isSpeedDialOpen) {
        setState(() {
          _isLegendVisible = false;
          _isSpeedDialOpen = false;
          _speedDialCtrl.reverse();
        });
      }

      _showPolygonActionSheet(field);
    });
  }

  PolygonLayer<ParsedFieldData> _buildEditingPolygonLayer() {
    final field = _editingPolygonField;
    final points = _editingPolygonPoints;
    if (field == null || points.length < 3) {
      return const PolygonLayer<ParsedFieldData>(polygons: []);
    }

    return PolygonLayer<ParsedFieldData>(
      polygons: [
        Polygon<ParsedFieldData>(
          points: points,
          color: AdvantaColors.gold.withAlpha(45),
          borderColor: AdvantaColors.gold,
          borderStrokeWidth: 2.4,
          hitValue: field,
        ),
      ],
    );
  }

  MarkerLayer _buildPolygonEditHandleLayer() {
    final points = _editingPolygonPoints;
    final markers = <Marker>[];
    if (points.length < 3) return const MarkerLayer(markers: []);

    for (var i = 0; i < points.length; i++) {
      final nextIndex = (i + 1) % points.length;
      final midpoint = _midpoint(points[i], points[nextIndex]);
      markers.add(
        Marker(
          point: midpoint,
          width: 28,
          height: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _insertPolygonVertex(i + 1, midpoint),
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AdvantaColors.deepForest.withAlpha(230),
                  shape: BoxShape.circle,
                  border: Border.all(color: AdvantaColors.gold, width: 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: AdvantaColors.gold, size: 14),
              ),
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < points.length; i++) {
      final isSelected = _selectedPolygonVertexIndex == i;
      markers.add(
        Marker(
          point: points[i],
          width: 42,
          height: 42,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedPolygonVertexIndex = i),
            onLongPress: () => _deletePolygonVertex(i),
            onPanStart: (_) {
              _pushPolygonUndo();
              setState(() => _selectedPolygonVertexIndex = i);
            },
            onPanUpdate: (details) =>
                _movePolygonVertex(i, details.globalPosition),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: isSelected ? 30 : 26,
                height: isSelected ? 30 : 26,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AdvantaColors.gold
                      : AdvantaColors.deepForest,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: isSelected ? AdvantaColors.charcoal : Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  /// Build PolygonLayer dari semua field yang punya polygonPoints.
  /// Hanya ditampilkan saat zoom >= 14 agar tidak berantakan di zoom jauh.
  PolygonLayer<ParsedFieldData> _buildPolygonLayer(
      List<ParsedFieldData> fieldsData) {
    final polygons = <Polygon<ParsedFieldData>>[];

    for (final f in fieldsData) {
      if (f.polygonPoints == null) continue;

      final points = f.polygonPoints!;
      if (points.length < 3) continue;

      // Warna polygon berdasarkan sumber koordinat
      final Color borderColor;
      final Color fillColor;

      if (f.isCorrected) {
        // Koreksi manual QA → gold/kuning
        borderColor = AdvantaColors.gold;
        fillColor = AdvantaColors.gold.withAlpha(40);
      } else {
        // Dari polygon WKT / koordinat biasa → hijau
        borderColor = AdvantaColors.lightGreen;
        fillColor = AdvantaColors.primaryGreen.withAlpha(35);
      }

      polygons.add(Polygon<ParsedFieldData>(
        points: points,
        color: fillColor,
        borderColor: borderColor,
        borderStrokeWidth: 1.5,
        hitValue: f,
      ));
    }

    return PolygonLayer<ParsedFieldData>(
      polygons: polygons,
      hitNotifier: _polygonHitNotifier,
    );
  }

  Widget _buildInitialLoadingScreen() =>
      _MapLoadingScreen(shimmerAnim: _shimmerAnim);

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AdvantaColors.deepForest,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                            color: AdvantaColors.primaryGreen.withAlpha(100)),
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
                onPressed: _refreshMapProviders,
                icon: const Icon(Icons.refresh),
                label: Text('Coba Lagi', style: AdvantaText.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdvantaColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AdvantaRadius.buttonRadius),
                ),
              ),
            ],
          ),
        ),
      );

  // ─── DESAIN BARU: HEADER BUILDERS ─────────────────────────────────
  Widget _buildNewRow2Search() {
    return GestureDetector(
      onTap: () {
        // Ambil semua data lahan saat ini untuk fitur Autocomplete (Saran Teks)
        final allFields = ref.read(parsedMapFieldsProvider).value ?? [];

        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'SearchSheet',
          barrierColor: Colors.black.withAlpha(150), // Latar belakang redup
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim1, anim2) {
            return Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(
                    // Memastikan letaknya persis di bawah SafeArea (poni HP)
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AdvantaColors.deepForest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AdvantaColors.lightGreen.withAlpha(30)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 20,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(50),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Panggil _SmartSearchBar dan kirim data allFields
                            _SmartSearchBar(
                              filters: _activeFilters,
                              allFields: allFields, // <--- Data List
                              onFiltersChanged: () => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (ctx, anim1, anim2, child) {
            // Animasi Slide dari Atas ke Bawah
            return SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: anim1, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: anim1, child: child),
            );
          },
        );
      },
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _activeFilters.isNotEmpty
                    ? '${_activeFilters.length} parameter pencarian'
                    : 'Cari lahan / petani...',
                style: AdvantaText.body2.copyWith(
                    color: _activeFilters.isNotEmpty
                        ? Colors.white
                        : Colors.white54),
              ),
            ),
            if (_activeFilters.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AdvantaColors.primaryGreen),
                child: Text('${_activeFilters.length}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              )
            else
              const Icon(Icons.tune_rounded, color: Colors.white54, size: 18),
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
        final items = <({
          IconData icon,
          String label,
          Color color,
          bool active,
          VoidCallback onTap
        })>[
          (
            icon: Icons.format_list_bulleted_rounded,
            label: 'List View',
            color: AdvantaColors.primaryGreen,
            active: false,
            onTap: () {
              // Tutup speed dial
              setState(() => _isSpeedDialOpen = false);
              _speedDialCtrl.reverse();

              // Hitung deltaDays untuk Time Traveller
              final deltaDays = _getWeekProjectionDeltaDays();

              // Ambil data lahan dan tampilkan Bottom Sheet
              ref.read(parsedMapFieldsProvider).whenData((allFields) {
                final filtered = _filterFields(allFields);
                FieldListView.showSheet(
                  context,
                  fieldsData: filtered,
                  userLocation: _userLocation,
                  getMarkerColor: _markerColor,
                  onUncoordBannerTap: (uncoordFields) =>
                      _showDefaultCoordSheet(uncoordFields),
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
                        onInspectDone: _handleInspectDone,
                      );
                    }
                  },
                  activePhase: _activePhaseView,
                  onPhaseChanged: (phase) {
                    setState(() => _activePhaseView = phase);
                  },
                  deltaDays: deltaDays, // <── TERUSKAN DELTA DAYS
                );
              });
            },
          ),
          (
            icon: Icons.fit_screen_outlined,
            label: 'Fit on Map',
            color: AdvantaColors.midGreen,
            active: false,
            onTap: () {
              ref.read(parsedMapFieldsProvider).whenData(
                    (all) => _fitBounds(_filterFields(all)),
                  );
              setState(() => _isSpeedDialOpen = false);
              _speedDialCtrl.reverse();
            },
          ),
          (
            icon: _isLegendVisible ? Icons.layers : Icons.layers_outlined,
            label: 'Legends',
            color: AdvantaColors.midGreen,
            active: _isLegendVisible,
            onTap: () => setState(() {
                  _isLegendVisible = !_isLegendVisible;
                }),
          ),
          (
            icon: _showPolygons
                ? Icons.pentagon_rounded
                : Icons.pentagon_outlined,
            label: _currentZoom < _polygonMinZoom && _showPolygons
                ? 'Polygon (zoom in)'
                : 'Polygon',
            color: AdvantaColors.primaryGreen,
            active: _showPolygons,
            onTap: () => setState(() => _showPolygons = !_showPolygons),
          ),
          (
            icon: _isSatellite
                ? Icons.map_outlined
                : Icons.satellite_alt_outlined,
            label: _isSatellite ? 'StreetView' : 'Satelit',
            color: AdvantaColors.goldLight,
            active: _isSatellite,
            onTap: () => setState(() => _isSatellite = !_isSatellite),
          ),
          (
            icon: _isLocating
                ? Icons.location_searching_rounded
                : (_gpsEnabled
                    ? Icons.my_location_rounded
                    : Icons.location_off_rounded),
            label: 'Get User GPS',
            color: _gpsEnabled ? AdvantaColors.lightGreen : AdvantaColors.error,
            active: _gpsEnabled,
            onTap: _goToUserLocation,
          ),
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Item-item yang muncul saat open ──────────────────
            ...items.asMap().entries.map((e) {
              final idx = e.key;
              final item = e.value;
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AdvantaColors.deepForest.withAlpha(210),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.white.withAlpha(25)),
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
                            child:
                                item.icon == Icons.location_searching_rounded &&
                                        _isLocating
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(item.icon,
                                        size: 16,
                                        color: item.active
                                            ? Colors.white
                                            : Colors.white70),
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
                willOpen ? _speedDialCtrl.forward() : _speedDialCtrl.reverse();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: _isSpeedDialOpen
                      ? const LinearGradient(
                          colors: [
                            AdvantaColors.primaryGreen,
                            AdvantaColors.midGreen
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _isSpeedDialOpen
                      ? null
                      : AdvantaColors.deepForest.withAlpha(220),
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
      (_phaseColors, 0, '7–35 DAP · OD 36–49', 'Vegetative'),
      (_phaseColors, 1, '50–54 DAP', 'Generative 1'),
      (_phaseColors, 2, '55–59 DAP', 'Generative 2'),
      (_phaseColors, 3, '60–65 DAP · OD 66–70', 'Generative 3'),
      (_phaseColors, 4, '71–90 DAP · OD 91–94', 'Pre-Harvest'),
      (_phaseColors, 5, '95–105 DAP', 'Harvest'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      width: 220, // Beri lebar pasti agar rapi
      decoration: BoxDecoration(
        color: AdvantaColors.deepForest.withAlpha(240),
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.goldLight.withAlpha(30)),
        boxShadow: AdvantaShadows.card(true),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HEADER DENGAN TOMBOL CLOSE ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LEGENDA DAP',
                style: AdvantaText.caption.copyWith(
                  color: AdvantaColors.goldLight.withAlpha(153),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isLegendVisible = false),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white38, size: 16),
              ),
            ],
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
          // Sweet Corn Halo Legend
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AdvantaColors.gold.withAlpha(220),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sweet Corn (SC)',
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Marker bercahaya emas',
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
                  child: Icon(Icons.location_off_rounded,
                      color: Colors.white, size: 7),
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
                          colors: [
                            AdvantaColors.primaryGreen,
                            AdvantaColors.midGreen
                          ],
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
                          style: AdvantaText.heading2
                              .copyWith(color: Colors.white),
                        )
                      : const Icon(Icons.touch_app_rounded,
                          color: Colors.white38, size: 20),
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
                            style: AdvantaText.bodyBold
                                .copyWith(color: Colors.white),
                          ),
                          Text(
                            'Tap marker di peta untuk memilih lahan',
                            style: AdvantaText.caption
                                .copyWith(color: Colors.white38),
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
                            style: AdvantaText.caption
                                .copyWith(color: Colors.white38),
                          ),
                        ],
                      ),
              ),

              // Actions
              if (count > 0) ...[
                GestureDetector(
                  onTap: _showSelectedFieldsSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(22)),
                    ),
                    child: Text(
                      'Daftar',
                      style: AdvantaText.label
                          .copyWith(color: AdvantaColors.goldLight),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _selectedFieldNumbers.clear()),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AdvantaColors.primaryGreen,
                          AdvantaColors.midGreen
                        ],
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
  bool _selectedFieldsAreSweetCornOnly() {
    final parsedFields = ref.read(parsedMapFieldsProvider).value;
    if (parsedFields == null) return false;

    final selectedFields = parsedFields
        .where((f) =>
            _selectedFieldNumbers.contains(f.raw['field_number']?.toString()))
        .toList();

    return selectedFields.isNotEmpty &&
        selectedFields.every(
          (f) => DapHelper.isSweetCorn(f.raw['hybrid']?.toString()),
        );
  }

  bool _selectedFieldsArePspOnly() {
    final parsedFields = ref.read(parsedMapFieldsProvider).value;
    if (parsedFields == null) return false;

    final selectedFields = parsedFields
        .where((f) =>
            _selectedFieldNumbers.contains(f.raw['field_number']?.toString()))
        .toList();

    return selectedFields.isNotEmpty &&
        selectedFields.every((f) {
          final hybrid = f.raw['hybrid']?.toString().toUpperCase().trim() ?? '';
          return hybrid.startsWith('ASF');
        });
  }

  void _showPhaseSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PhaseSheet(
        selectionCount: _selectedFieldNumbers.length,
        includeSweetCornPhases: _selectedFieldsAreSweetCornOnly(),
        includePspPhases: _selectedFieldsArePspOnly(),
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
        .where((f) =>
            _selectedFieldNumbers.contains(f.raw['field_number']?.toString()))
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

class _CompactAttendanceDot extends StatelessWidget {
  final AttendanceState attendance;
  const _CompactAttendanceDot({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final isNotCheckedIn = !attendance.isCheckedIn;
    final isCheckedOut = attendance.isCheckedOut;
    final isActive = attendance.isCheckedIn && !attendance.isCheckedOut;

    Color color;
    if (isNotCheckedIn) {
      color = AdvantaColors.error;
    } else if (isCheckedOut) {
      color = AdvantaColors.gold;
    } else {
      color = AdvantaColors.primaryGreen;
    }

    return GestureDetector(
      onTap: () {
        if (isNotCheckedIn) {
          context.push('/checkin');
        } else if (isActive) {
          context.push('/checkout');
        }
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(40),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Icon(
              isNotCheckedIn
                  ? Icons.warning_amber_rounded
                  : isCheckedOut
                      ? Icons.task_alt_rounded
                      : Icons.person,
              color: color,
              size: 18),
        ),
      ),
    );
  }
}

class _CompactSegmentButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isWarning;
  final VoidCallback onTap;

  const _CompactSegmentButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Colors.white
        : (isWarning ? AdvantaColors.goldLight : Colors.white54);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? AdvantaColors.primaryGreen : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _NewWeekPickerChip extends StatelessWidget {
  final Map<String, dynamic> selectedWeek;
  final List<Map<String, dynamic>> workWeeks;
  final Function(Map<String, dynamic>) onSelected;

  const _NewWeekPickerChip({
    required this.selectedWeek,
    required this.workWeeks,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Format tanggal hari ini seperti di gambar: "Rab, 22 Apr"
    final todayStr = DateFormat('E, d MMM', 'id_ID').format(DateTime.now());

    // Teks yang tampil di Chip
    final displayText = selectedWeek.isNotEmpty && selectedWeek['label'] != null
        ? '$todayStr • ${selectedWeek['label']}'
        : 'Semua Minggu';

    return PopupMenuButton<Map<String, dynamic>>(
      color: const Color(0xFF132A1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withAlpha(20)),
      ),
      offset: const Offset(0, 45),
      elevation: 12,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return [
          // 1. HEADER DROPDOWN
          PopupMenuItem<Map<String, dynamic>>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Minggu',
                  style: AdvantaText.bodyBold.copyWith(color: Colors.white),
                ),
                Text(
                  'Berdasarkan minggu kerja / tanggal',
                  style: AdvantaText.caption
                      .copyWith(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.white.withAlpha(20), height: 1),
              ],
            ),
          ),

          // 2. OPSI "SEMUA MINGGU" (TOMBOL RESET)
          PopupMenuItem<Map<String, dynamic>>(
            value: const {}, // Kirim Map kosong sebagai penanda "Semua"
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selectedWeek.isEmpty
                    ? AdvantaColors.primaryGreen.withAlpha(40)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedWeek.isEmpty
                      ? AdvantaColors.lightGreen.withAlpha(100)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Icon(Icons.all_inclusive_rounded,
                        color: selectedWeek.isEmpty
                            ? AdvantaColors.lightGreen
                            : Colors.white,
                        size: 20),
                  ),
                  Expanded(
                    child: Text(
                      'Semua Minggu',
                      style: AdvantaText.bodyBold.copyWith(
                        color: selectedWeek.isEmpty
                            ? AdvantaColors.lightGreen
                            : Colors.white70,
                      ),
                    ),
                  ),
                  if (selectedWeek.isEmpty)
                    const Icon(Icons.check_circle_rounded,
                        color: AdvantaColors.lightGreen, size: 18),
                ],
              ),
            ),
          ),

          // Garis pemisah tipis antara "Semua" dan List Minggu Kalender
          const PopupMenuItem<Map<String, dynamic>>(
            enabled: false,
            height: 10,
            child: Divider(color: Colors.white12, height: 1),
          ),

          // TOMBOL MANUAL
          PopupMenuItem<Map<String, dynamic>>(
            value: const {
              'action': 'manual'
            }, // Map penanda untuk memicu bottom sheet
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Pilih Minggu Lainnya...',
                    style: AdvantaText.body2.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // 3. LIST MINGGU KALENDER (W15, W16, W17, dst)
          ...workWeeks.map((week) {
            final isSelected = selectedWeek.isNotEmpty &&
                selectedWeek['label'] == week['label'];
            return PopupMenuItem<Map<String, dynamic>>(
              value: week,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AdvantaColors.primaryGreen.withAlpha(40)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AdvantaColors.lightGreen.withAlpha(100)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        week['label'],
                        style: AdvantaText.bodyBold.copyWith(
                          color: isSelected
                              ? AdvantaColors.lightGreen
                              : Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        week['date'],
                        style: AdvantaText.body2.copyWith(
                          color: isSelected
                              ? AdvantaColors.lightGreen
                              : Colors.white70,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AdvantaColors.lightGreen, size: 18),
                  ],
                ),
              ),
            );
          }),
        ];
      },
      // Desain Chip Utama yang bisa diklik
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: AdvantaText.label.copyWith(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _NewActionPill extends StatelessWidget {
  final IconData icon;
  const _NewActionPill({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Icon(icon, color: AdvantaColors.goldLight, size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AUDIT STATUS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────
class _AuditStatusSheet extends StatelessWidget {
  final _AuditFilter currentFilter;
  final ActivePhaseView activePhase; // TAMBAHAN: Menerima info fase aktif
  final Function(_AuditFilter) onSelected;

  const _AuditStatusSheet({
    required this.currentFilter,
    required this.activePhase,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Data opsi filter dinamis
    final items = [
      (
        filter: _AuditFilter.all,
        label: 'Semua Status',
        icon: Icons.apps_rounded,
        color: Colors.white70
      ),
      (
        filter: _AuditFilter.sampun,
        label: 'Sampun (Sudah Audit)',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF43A047)
      ),
      // MUNCUL HANYA JIKA FASE = GENERATIF atau AUTO
      if (activePhase == ActivePhaseView.generative ||
          activePhase == ActivePhaseView.auto)
        (
          filter: _AuditFilter.partial,
          label: 'Jangkep (Generatif Sebagian)',
          icon: Icons.timelapse_rounded,
          color: const Color(0xFFFFA726)
        ),
      (
        filter: _AuditFilter.dereng,
        label: 'Dereng (Belum Audit)',
        icon: Icons.radio_button_unchecked_rounded,
        color: const Color(0xFFEF5350)
      ),
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        color: AdvantaColors.deepForest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Pilih Status Audit',
            style: AdvantaText.heading3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withAlpha(20), height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withAlpha(10), height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item.filter == currentFilter;

                return ListTile(
                  leading: Icon(item.icon, color: item.color),
                  title: Text(item.label,
                      style: AdvantaText.body1.copyWith(color: Colors.white)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: AdvantaColors.lightGreen)
                      : null,
                  onTap: () {
                    onSelected(item.filter);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewQuickFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasDropdown;
  final bool isActive;
  final VoidCallback? onTap;

  const _NewQuickFilterChip({
    required this.icon,
    required this.label,
    this.hasDropdown = false,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Jika aktif, warnanya jadi hijau. Jika tidak, transparan.
          color: isActive
              ? AdvantaColors.primaryGreen.withAlpha(50)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AdvantaColors.primaryGreen
                : Colors.white.withAlpha(25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? AdvantaColors.lightGreen : Colors.white70,
                size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: AdvantaText.caption.copyWith(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: isActive ? Colors.white : Colors.white70, size: 14),
            ]
          ],
        ),
      ),
    );
  }
}

class _PolygonInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PolygonInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdvantaText.caption.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolygonToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const _PolygonToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withAlpha(14)
                : Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? Colors.white.withAlpha(24)
                  : Colors.white.withAlpha(8),
            ),
          ),
          child: Icon(
            icon,
            color: enabled ? color.withAlpha(220) : Colors.white24,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _AllFilterPopupValue {
  const _AllFilterPopupValue();
}

const _allFilterPopupValue = _AllFilterPopupValue();

class _FilterPopupChip<T extends Object> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T? currentValue;
  final List<T> items;
  final String Function(T) itemLabel;
  final Function(T?) onSelected;
  final bool isActive;
  final bool enabled;

  const _FilterPopupChip({
    super.key, // <── TAMBAHKAN BARIS INI
    required this.icon,
    required this.label,
    required this.currentValue,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    this.isActive = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      enabled: enabled,
      color: const Color(0xFF132A1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withAlpha(20)),
      ),
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == _allFilterPopupValue) {
          onSelected(null);
          return;
        }
        onSelected(value as T);
      },
      initialValue: currentValue ?? _allFilterPopupValue,
      itemBuilder: (context) => [
        // ── Perbaikan Opsi "Semua" (Ditambah Checkmark) ──
        PopupMenuItem<Object>(
          value: _allFilterPopupValue,
          child: Row(
            children: [
              Expanded(
                child: Text('Semua',
                    style: AdvantaText.body2.copyWith(
                      color: currentValue == null
                          ? AdvantaColors.lightGreen
                          : Colors.white70,
                      fontWeight: currentValue == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    )),
              ),
              if (currentValue == null)
                const Icon(Icons.check_circle_rounded,
                    color: AdvantaColors.lightGreen, size: 16),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...items.map((item) {
          final isSelected = item == currentValue;
          return PopupMenuItem<Object>(
            value: item,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    itemLabel(item),
                    style: AdvantaText.body2.copyWith(
                      color:
                          isSelected ? AdvantaColors.lightGreen : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AdvantaColors.lightGreen, size: 16),
              ],
            ),
          );
        }),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AdvantaColors.primaryGreen.withAlpha(50)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AdvantaColors.primaryGreen
                : Colors.white.withAlpha(25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? AdvantaColors.lightGreen : Colors.white70,
                size: 14),
            const SizedBox(width: 6),
            Text(
              label, // Label ini dikirim dari parent
              style: AdvantaText.caption.copyWith(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: isActive ? Colors.white : Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMART SEARCH — Supabase-style multi-parameter filter
// ─────────────────────────────────────────────────────────────

/// Defines a searchable parameter
enum SearchParam {
  fieldNumber('No. Lahan', 'field_number', Icons.tag_rounded),
  farmerName('Nama Petani', 'farmer_name', Icons.person_rounded),
  grower('Grower', 'grower', Icons.store_rounded),
  season('Season', 'season', Icons.calendar_today_rounded),
  hybrid('Hybrid', 'hybrid', Icons.grass_rounded),
  village('Desa', 'village_desa', Icons.location_city_rounded), // ← fix
  district('Kecamatan', 'sub_district_kec', Icons.map_rounded), // ← fix
  fa('Nama FA', 'fa', Icons.badge_rounded), // ← fix
  qaFI('Nama FI', 'qa_fi', Icons.badge_outlined), // ← fix
  qaSPV('Nama SPV', 'qa_spv', Icons.supervisor_account_rounded); // ← fix

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
  final List<ParsedFieldData> allFields; // Menerima data
  final VoidCallback onFiltersChanged;

  const _SmartSearchBar({
    required this.filters,
    required this.allFields,
    required this.onFiltersChanged,
  });

  @override
  State<_SmartSearchBar> createState() => _SmartSearchBarState();
}

class _SmartSearchBarState extends State<_SmartSearchBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addFilter() {
    final usedParams = widget.filters.map((f) => f.param).toSet();
    final available =
        SearchParam.values.where((p) => !usedParams.contains(p)).toList();
    if (available.isEmpty) return;

    setState(() {
      widget.filters.add(SearchFilter(param: available.first));
    });
    widget.onFiltersChanged();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _removeFilter(int index) {
    setState(() {
      widget.filters.removeAt(index);
    });
    widget.onFiltersChanged();
  }

  void _clearAll() {
    setState(() {
      widget.filters.clear();
    });
    widget.onFiltersChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.manage_search_rounded,
                color: AdvantaColors.lightGreen, size: 24),
            const SizedBox(width: 8),
            Text(
              'Pencarian Spesifik',
              style: AdvantaText.heading3.copyWith(color: Colors.white),
            ),
            const Spacer(),
            if (widget.filters.isNotEmpty)
              TextButton(
                onPressed: _clearAll,
                child: Text('Reset',
                    style:
                        AdvantaText.label.copyWith(color: AdvantaColors.error)),
              )
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tambahkan parameter untuk mencari berdasarkan teks (Sistem akan memberi saran otomatis saat Anda mengetik).',
          style: AdvantaText.caption.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.filters.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada parameter pencarian.',
                      style: AdvantaText.body2.copyWith(color: Colors.white30),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.filters.length,
                  itemBuilder: (_, i) => _FilterRow(
                    key: ValueKey(i),
                    filter: widget.filters[i],
                    index: i,
                    usedParams: widget.filters.map((f) => f.param).toSet(),
                    allFields: widget.allFields, // Teruskan ke baris filter
                    onRemove: () => _removeFilter(i),
                    onChanged: widget.onFiltersChanged,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: GestureDetector(
                  onTap: widget.filters.length < SearchParam.values.length
                      ? _addFilter
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.filters.length < SearchParam.values.length
                          ? AdvantaColors.primaryGreen.withAlpha(30)
                          : Colors.white.withAlpha(5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.filters.length < SearchParam.values.length
                            ? AdvantaColors.lightGreen.withAlpha(60)
                            : Colors.white.withAlpha(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color:
                              widget.filters.length < SearchParam.values.length
                                  ? AdvantaColors.lightGreen
                                  : Colors.white24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.filters.length < SearchParam.values.length
                              ? 'Tambah Parameter'
                              : 'Semua parameter digunakan',
                          style: AdvantaText.bodyBold.copyWith(
                            color: widget.filters.length <
                                    SearchParam.values.length
                                ? AdvantaColors.lightGreen
                                : Colors.white24,
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
      ],
    );
  }
}

/// A single filter row inside the panel
class _FilterRow extends StatefulWidget {
  final SearchFilter filter;
  final int index;
  final Set<SearchParam> usedParams;
  final List<ParsedFieldData> allFields; // Menerima data
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _FilterRow({
    super.key,
    required this.filter,
    required this.index,
    required this.usedParams,
    required this.allFields,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  // Tidak perlu lagi TextEditingController manual karena Autocomplete yang mengurusnya!

  void _showParamPicker() {
    final available = SearchParam.values
        .where(
            (p) => p == widget.filter.param || !widget.usedParams.contains(p))
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
          widget.filter.value = ''; // Reset nilai ketika parameter berubah
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
          // ── Tombol Pilih Parameter ──
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
                  Icon(widget.filter.param.icon,
                      size: 13, color: AdvantaColors.lightGreen),
                  const SizedBox(width: 6),
                  Text(
                    widget.filter.param.label,
                    style: AdvantaText.caption.copyWith(
                      color: AdvantaColors.lightGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more_rounded,
                      size: 12, color: AdvantaColors.lightGreen.withAlpha(150)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),
          Text('≈',
              style: AdvantaText.body2
                  .copyWith(color: Colors.white30, fontSize: 16)),
          const SizedBox(width: 8),

          // ── Kotak Teks dengan Autocomplete (Pencarian Cerdas) ──
          Expanded(
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.filter.value),
              optionsBuilder: (TextEditingValue textEditingValue) {
                // Logika pencarian list saran (suggestions)
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                final query = textEditingValue.text.toLowerCase();
                final key = widget.filter.param.fieldKey;

                // Memfilter data unik yang cocok dengan ketikan user
                final suggestions = widget.allFields
                    .map((f) => f.raw[key]?.toString() ?? '')
                    .where((val) =>
                        val.trim().isNotEmpty &&
                        val.toLowerCase().contains(query))
                    .toSet()
                    .toList();

                return suggestions.take(5); // Batasi maksimal 5 saran agar rapi
              },
              onSelected: (String selection) {
                widget.filter.value = selection;
                widget.onChanged();
                FocusScope.of(context).unfocus(); // Tutup keyboard
              },
              // UI dari kotak input (TextField)
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AdvantaText.body2
                      .copyWith(color: Colors.white, fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  cursorColor: AdvantaColors.lightGreen,
                  decoration: InputDecoration(
                    hintText: 'Cari...',
                    hintStyle:
                        AdvantaText.caption.copyWith(color: Colors.white54),
                    filled: true,
                    fillColor: AdvantaColors.midGreen.withAlpha(160),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AdvantaColors.lightGreen.withAlpha(60)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AdvantaColors.lightGreen.withAlpha(180)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    suffixIcon: controller.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              controller.clear();
                              widget.filter.value = '';
                              widget.onChanged();
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white54),
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    widget.filter.value = v;
                    widget.onChanged();
                  },
                  onSubmitted: (v) => onFieldSubmitted(),
                );
              },
              // UI dari List Dropdown Saran Pencarian
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width -
                          160, // Sesuaikan sisa lebar layar
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF132A1C), // Deep Forest
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(30)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(150),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: Colors.white.withAlpha(10)),
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Text(
                                option,
                                style: AdvantaText.body2.copyWith(
                                    color: AdvantaColors.lightGreen,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 6),

          // ── Tombol Hapus ──
          GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: 36,
              height: 40,
              decoration: BoxDecoration(
                color: AdvantaColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AdvantaColors.error.withAlpha(50), width: 1),
              ),
              child: const Icon(Icons.remove_rounded,
                  size: 15, color: AdvantaColors.error),
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
                Icon(Icons.tune_rounded,
                    size: 16, color: AdvantaColors.lightGreen),
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          color: isSelected
                              ? AdvantaColors.lightGreen
                              : Colors.white54,
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
                                color:
                                    isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: AdvantaColors.lightGreen),
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

// ─────────────────────────────────────────────────────────────
// PHASE SELECTION BOTTOM SHEET
// Dark-themed menggunakan AdvantaColors palette
// ─────────────────────────────────────────────────────────────

class _PhaseSheet extends StatelessWidget {
  final int selectionCount;
  final bool includeSweetCornPhases;
  final bool includePspPhases;
  final void Function(String) onSelected;

  const _PhaseSheet({
    required this.selectionCount,
    required this.includeSweetCornPhases,
    required this.includePspPhases,
    required this.onSelected,
  });

  static const _phases = [
    (
      Icons.eco_outlined,
      'Vegetative',
      'vegetative',
      Color(0xFF78909C),
      '100% target – semua field aktif',
      false
    ),
    (
      Icons.grass_outlined,
      'Generative 1',
      'generative_1',
      Color(0xFFFFCA28),
      'Checkpoint pertama – readiness & roguing',
      false
    ),
    (
      Icons.grass,
      'Generative 2',
      'generative_2',
      Color(0xFFFF7043),
      'Checkpoint kedua – female shedding',
      false
    ),
    (
      Icons.grass,
      'Generative 3 (Final)',
      'generative_3',
      Color(0xFFE53935),
      'Checkpoint final – flagging & detasseling',
      false
    ),
    (
      Icons.grass,
      'Generative 4 (SC)',
      'generative_4',
      Color(0xFF8E24AA),
      'Sweet Corn – checkpoint keempat',
      true
    ),
    (
      Icons.grass,
      'Generative 5 (SC)',
      'generative_5',
      Color(0xFFD81B60),
      'Sweet Corn – checkpoint kelima',
      true
    ),
    (
      Icons.agriculture_outlined,
      'Pre-Harvest',
      'pre_harvest',
      Color(0xFF795548),
      'Target 50% – sampling eligible',
      false
    ),
    (
      Icons.grain,
      'Harvest',
      'harvest',
      Color(0xFF43A047),
      'Target 50% + field flagged',
      false
    ),
  ];

  List<(IconData, String, String, Color, String, bool)> get _visiblePhases {
    if (includePspPhases) {
      return const [
        (
          Icons.eco_outlined,
          'Vegetative (PSP)',
          'vegetative',
          Color(0xFF78909C),
          'Roguing 1-4',
          false
        ),
        (
          Icons.grass,
          'Generative (PSP)',
          'generative_5',
          Color(0xFFE53935),
          'Roguing 5-6',
          false
        ),
        (
          Icons.grain,
          'Harvest (PSP)',
          'harvest',
          Color(0xFF43A047),
          'Ear condition & crop health',
          false
        ),
      ];
    }
    if (includeSweetCornPhases) return _phases;
    return _phases.where((phase) => !phase.$6).toList(growable: false);
  }

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
                  child: Icon(Icons.checklist_rtl,
                      color: AdvantaColors.lightGreen, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Fase – Mass Inspect',
                        style:
                            AdvantaText.heading3.copyWith(color: Colors.white),
                      ),
                      Text(
                        '$selectionCount lahan akan diinspeksi bersamaan',
                        style:
                            AdvantaText.caption.copyWith(color: Colors.white54),
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
            itemCount: _visiblePhases.length,
            itemBuilder: (ctx, i) {
              final (icon, label, key, color, desc, _) = _visiblePhases[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PhaseAssetIcon(
                      phaseKey: key,
                      fallbackIcon: icon,
                      fallbackColor: color,
                      size: 32,
                    ),
                  ),
                ),
                title: Text(
                  label,
                  style: AdvantaText.body1.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  desc,
                  style: AdvantaText.caption.copyWith(color: Colors.white38),
                ),
                trailing:
                    Icon(Icons.chevron_right, color: Colors.white30, size: 18),
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
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
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
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2196F3)
                    .withAlpha((_opacity.value * 255).round()),
              ),
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Color(0x662196F3), blurRadius: 8, spreadRadius: 2),
            ],
          ),
        ),
        Container(
          width: 13,
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
    _scale = Tween<double>(begin: 1.0, end: 2.2)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.5, end: 0.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
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
                color: AdvantaColors.error
                    .withAlpha((_opacity.value * 255).round()),
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
              const Icon(Icons.location_off_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(height: 1),
              Text(
                '${widget.count}',
                style: AdvantaText.heading3
                    .copyWith(color: Colors.white, height: 1.0),
              ),
              Text(
                'lahan',
                style: AdvantaText.caption
                    .copyWith(color: Colors.white70, height: 1.1),
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
      final fn = f['field_number']?.toString().toLowerCase() ?? '';
      final farmer = f['farmer_name']?.toString().toLowerCase() ?? '';
      final fa = f['fa']?.toString().toLowerCase() ?? '';
      return fn.contains(q) || farmer.contains(q) || fa.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Sheet ini selalu dark-themed (ditampilkan di atas peta)
    const kBg = AdvantaColors.deepForest;
    const kRed = AdvantaColors.error;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
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
                      child: const Icon(Icons.location_off_rounded,
                          color: kRed, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lahan Tanpa Koordinat',
                            style: AdvantaText.heading3
                                .copyWith(color: Colors.white),
                          ),
                          Text(
                            '${widget.fields.length} lahan — koordinat belum diisi / masih 0',
                            style: AdvantaText.caption
                                .copyWith(color: Colors.white54),
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
                        child: const Icon(Icons.close,
                            color: Colors.white54, size: 16),
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
                    border:
                        Border.all(color: AdvantaColors.success.withAlpha(128)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AdvantaColors.lightGreen, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap baris lahan → buka detail → Correction Tagging untuk mengisi koordinat yang benar.',
                          style: AdvantaText.caption
                              .copyWith(color: AdvantaColors.lightGreen),
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
                child: TextField(
                  controller: _searchCtrl,
                  style: AdvantaText.body2
                      .copyWith(color: Colors.white, fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  cursorColor: AdvantaColors.lightGreen,
                  decoration: InputDecoration(
                    hintText: 'Cari No. Lahan, Petani, FA…',
                    hintStyle: AdvantaText.body2
                        .copyWith(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white54, size: 18),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: const Icon(Icons.clear,
                                color: Colors.white54, size: 16),
                          )
                        : null,
                    filled: true,
                    fillColor: AdvantaColors.midGreen.withAlpha(200),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AdvantaColors.goldLight.withAlpha(30)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AdvantaColors.goldLight.withAlpha(30)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AdvantaColors.lightGreen.withAlpha(180)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _query = v),
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
                            const Icon(Icons.search_off,
                                color: Colors.white24, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              'Tidak ada hasil',
                              style: AdvantaText.body2
                                  .copyWith(color: Colors.white38),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: kRed.withAlpha(31),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.location_off_rounded,
                                        color: kRed,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fn,
                                                style: AdvantaText.bodyBold
                                                    .copyWith(
                                                        color: Colors.white),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.white.withAlpha(15),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                ha,
                                                style: AdvantaText.caption
                                                    .copyWith(
                                                        color: Colors.white54),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          farmer,
                                          style: AdvantaText.body2
                                              .copyWith(color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (village.isNotEmpty ||
                                                district.isNotEmpty)
                                              Expanded(
                                                child: Text(
                                                  [village, district]
                                                      .where(
                                                          (s) => s.isNotEmpty)
                                                      .join(', '),
                                                  style: AdvantaText.caption
                                                      .copyWith(
                                                    color:
                                                        AdvantaColors.mutedGrey,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            if (fa.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                margin: const EdgeInsets.only(
                                                    left: 6),
                                                decoration: BoxDecoration(
                                                  color: AdvantaColors
                                                      .primaryGreen
                                                      .withAlpha(51),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  fa,
                                                  style: AdvantaText.caption
                                                      .copyWith(
                                                    color: AdvantaColors
                                                        .lightGreen,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.white24, size: 18),
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
                  width: 96,
                  height: 96,
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
                    padding: const EdgeInsets.all(18),
                    child: SvgPicture.asset(
                      'assets/logo_kc.svg',
                      placeholderBuilder: (_) => const Icon(
                          Icons.agriculture_rounded,
                          color: Colors.white,
                          size: 48),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

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
                  'Kroscek · Field Support',
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
                      child: const Icon(Icons.checklist_rtl,
                          color: AdvantaColors.lightGreen, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Lahan Dipilih',
                            style: AdvantaText.heading3
                                .copyWith(color: Colors.white),
                          ),
                          Text(
                            '${fields.length} lahan siap diinspeksi',
                            style: AdvantaText.caption
                                .copyWith(color: Colors.white54),
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
                        child: const Icon(Icons.close,
                            color: Colors.white54, size: 16),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
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
                                      style: AdvantaText.caption
                                          .copyWith(color: Colors.white54),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  farmer,
                                  style: AdvantaText.bodyBold
                                      .copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hybrid: $hybrid',
                                  style: AdvantaText.caption
                                      .copyWith(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => onRemove(fn),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AdvantaColors.error),
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
