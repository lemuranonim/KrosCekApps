import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/audit_vegetative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/coord_helper.dart';
import '../../utils/guest_guard.dart';
import 'psp_form_widgets.dart';

const _kPspVeg = kPspVegetativeColor;

class FormVegetativePSP extends ConsumerStatefulWidget {
  final String fieldNumber;

  const FormVegetativePSP({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormVegetativePSP> createState() => _FormVegetativePSPState();
}

class _FormVegetativePSPState extends ConsumerState<FormVegetativePSP> {
  final _formKey = GlobalKey<FormState>();
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  final _corrTaggingCtrl = TextEditingController();
  final _coRoguingCtrl = TextEditingController();
  final _fieldSizeCtrl = TextEditingController();
  final _recommendationPldCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _manualLatCtrl = TextEditingController();
  final _manualLngCtrl = TextEditingController();
  late final List<_PspRoguingDraft> _roguings;

  bool _isSaving = false;
  bool _isCapturingGps = false;
  bool _isGeocodingExisting = false;
  bool _dataLoaded = false;
  ActiveSession? _session;

  String? _existingCoordinate;
  String? _existingCoordinateSource;
  Map<String, String>? _existingGeoResult;
  Map<String, String>? _newGeoResult;
  String? _pendingGeometryWkt;
  DateTime? _revTglTanam;
  String? _previousCrop;
  String? _recommendation;
  String? _flagging;
  String? _typeSeed;
  String? _corrTaggingSource;

  bool get _isGuest => GuestGuard.isGuest(_session);
  bool get _isPld => pspIsDiscardDecision(_recommendation);

  @override
  void initState() {
    super.initState();
    _roguings = List.generate(4, (i) => _PspRoguingDraft(i + 1));
    SessionManager.instance.getActiveSession().then((s) {
      if (mounted) setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _corrTaggingCtrl.dispose();
    _coRoguingCtrl.dispose();
    _fieldSizeCtrl.dispose();
    _recommendationPldCtrl.dispose();
    _remarksCtrl.dispose();
    _manualLatCtrl.dispose();
    _manualLngCtrl.dispose();
    for (final roguing in _roguings) {
      roguing.dispose();
    }
    super.dispose();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('yyyy-MM-dd').format(date);
  }

  double? _parseDouble(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  ({double lat, double lng})? _parseCoordinate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim().replaceAll(',', '.'));
    final lng = double.tryParse(parts[1].trim().replaceAll(',', '.'));
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  String _formatCoordinate(double lat, double lng) {
    return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  }

  String? _readVegetativeCorrection(Map<String, dynamic> fieldData) {
    final vegRow = fieldData['audit_vegetative'];
    Object? value;
    if (vegRow is List && vegRow.isNotEmpty) {
      value = vegRow[0]['correction_tagging'];
    } else if (vegRow is Map) {
      value = vegRow['correction_tagging'];
    }

    final auditCorrection = value?.toString().trim();
    if (auditCorrection != null && auditCorrection.isNotEmpty) {
      return auditCorrection;
    }

    final fieldCorrection = fieldData['correction_tagging']?.toString().trim();
    if (fieldCorrection != null && fieldCorrection.isNotEmpty) {
      return fieldCorrection;
    }

    return null;
  }

  ({String coordinate, double lat, double lng, String source})?
      _resolveFieldCoordinate(Map<String, dynamic> fieldData) {
    final centroid =
        CoordHelper.wktCentroid(fieldData['geometry_wkt']?.toString());
    if (centroid != null) {
      final lat = centroid['lat']!;
      final lng = centroid['lng']!;
      if (CoordHelper.isValidIndonesia(lat, lng)) {
        return (
          coordinate: _formatCoordinate(lat, lng),
          lat: lat,
          lng: lng,
          source: 'polygon'
        );
      }
    }

    final correction = _parseCoordinate(_readVegetativeCorrection(fieldData));
    if (correction != null &&
        CoordHelper.isValidIndonesia(correction.lat, correction.lng)) {
      return (
        coordinate: _formatCoordinate(correction.lat, correction.lng),
        lat: correction.lat,
        lng: correction.lng,
        source: 'correction'
      );
    }

    final coordinate = _parseCoordinate(fieldData['coordinate']?.toString());
    if (coordinate != null &&
        CoordHelper.isValidIndonesia(coordinate.lat, coordinate.lng)) {
      return (
        coordinate: _formatCoordinate(coordinate.lat, coordinate.lng),
        lat: coordinate.lat,
        lng: coordinate.lng,
        source: 'coordinate'
      );
    }

    return null;
  }

  String _coordinateSourceLabel(String? source) {
    switch (source) {
      case 'polygon':
        return 'Centroid WKT';
      case 'correction':
        return 'Correction Tagging';
      case 'coordinate':
        return 'Kolom Coordinate';
      default:
        return 'Koordinat Lahan';
    }
  }

  void _loadAudit(Map<String, dynamic>? audit, Map<String, dynamic> fieldData) {
    if (_dataLoaded) return;
    _dataLoaded = true;

    _qaFiCtrl.text =
        audit?['qa_fi']?.toString() ?? fieldData['qa_fi']?.toString() ?? '';
    _qaSpvCtrl.text =
        audit?['qa_spv']?.toString() ?? fieldData['qa_spv']?.toString() ?? '';
    _corrTaggingCtrl.text = audit?['correction_tagging']?.toString() ??
        fieldData['correction_tagging']?.toString() ??
        '';
    _coRoguingCtrl.text = audit?['co_detasseling']?.toString() ?? '';
    _fieldSizeCtrl.text = audit?['field_size_by_audit_ha']?.toString() ?? '';
    _recommendationPldCtrl.text =
        audit?['recommendation_pld_ha']?.toString() ?? '';
    _remarksCtrl.text = audit?['remarks']?.toString() ?? '';

    _revTglTanam = _parseDate(
        audit?['rev_planting_date'] ?? fieldData['planting_date_pdn']);

    setState(() {
      _previousCrop = audit?['previous_crop_by_audit']?.toString();
      _recommendation = audit?['decision']?.toString();
      _flagging = audit?['flagging']?.toString();
      _typeSeed = audit?['type_seed']?.toString();
      for (final roguing in _roguings) {
        roguing.load(audit);
      }
    });
  }

  Future<void> _pickDate({
    required DateTime? initialDate,
    required void Function(DateTime date) onPicked,
  }) async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: pspDatePickerTheme(ctx, _kPspVeg),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _captureUserGps() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    setState(() => _isCapturingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Izin lokasi ditolak', err: true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final coordStr = _formatCoordinate(pos.latitude, pos.longitude);
      final geoResult = await _reverseGeocode(pos.latitude, pos.longitude);
      setState(() {
        _corrTaggingCtrl.text = coordStr;
        _newGeoResult = geoResult;
        _corrTaggingSource = 'gps';
        _pendingGeometryWkt = null;
      });
      _snack('GPS berhasil diambil: $coordStr');
    } catch (e) {
      _snack('Gagal ambil GPS: $e', err: true);
    } finally {
      if (mounted) setState(() => _isCapturingGps = false);
    }
  }

  Future<Map<String, String>> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=14&addressdetails=1',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'AdvantaSeedsFieldAudit/1.0 (audit@advantaseeds.com)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final jsonData = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = jsonData['address'] as Map<String, dynamic>? ?? {};
        return {
          'desa': (addr['village'] ??
                  addr['hamlet'] ??
                  addr['suburb'] ??
                  addr['neighbourhood'] ??
                  '-')
              .toString(),
          'kecamatan': (addr['subdistrict'] ??
                  addr['city_district'] ??
                  addr['district'] ??
                  addr['county'] ??
                  '-')
              .toString(),
          'kabupaten': (addr['regency'] ??
                  addr['city'] ??
                  addr['state_district'] ??
                  addr['county'] ??
                  addr['state'] ??
                  '-')
              .toString(),
        };
      }
    } on TimeoutException {
      debugPrint('[GEO][PSP] Timeout ($lat, $lng)');
    } catch (e) {
      debugPrint('[GEO][PSP] Exception: $e');
    }
    return {'desa': 'Gagal memuat', 'kecamatan': '-', 'kabupaten': '-'};
  }

  Future<void> _loadExistingGeocode(String coordinate) async {
    final parsed = _parseCoordinate(coordinate);
    if (parsed == null) return;
    setState(() => _isGeocodingExisting = true);
    final result = await _reverseGeocode(parsed.lat, parsed.lng);
    if (mounted && _existingCoordinate == coordinate) {
      setState(() {
        _existingGeoResult = result;
        _isGeocodingExisting = false;
      });
    }
  }

  void _useExistingCoordinate() {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (_existingCoordinate == null || _existingCoordinate!.trim().isEmpty) {
      _snack('Koordinat lahan belum tersedia', err: true);
      return;
    }
    setState(() {
      _corrTaggingCtrl.text = _existingCoordinate!.trim();
      _newGeoResult = _existingGeoResult;
      _corrTaggingSource = 'confirmed';
      _pendingGeometryWkt = null;
    });
    _snack(
        '${_coordinateSourceLabel(_existingCoordinateSource)} dikonfirmasi sebagai koreksi');
  }

  Future<LatLng?> _geocodeWilayah(Map<String, dynamic> fieldData) async {
    final dusun = fieldData['hamlet_dusun']?.toString().trim() ?? '';
    final desa = fieldData['village_desa']?.toString().trim() ?? '';
    final kecamatan = fieldData['sub_district_kec']?.toString().trim() ?? '';
    final kabupaten = fieldData['district_kab']?.toString().trim() ?? '';

    final queries = <String>[];
    if (dusun.isNotEmpty && desa.isNotEmpty && kabupaten.isNotEmpty) {
      queries.add('$dusun, $desa, $kecamatan, $kabupaten, Indonesia');
    }
    if (desa.isNotEmpty && kabupaten.isNotEmpty) {
      queries.add('$desa, $kecamatan, $kabupaten, Indonesia');
    }
    if (kecamatan.isNotEmpty && kabupaten.isNotEmpty) {
      queries.add('$kecamatan, $kabupaten, Indonesia');
    }
    if (kabupaten.isNotEmpty) queries.add('$kabupaten, Indonesia');
    if (queries.isEmpty) return null;

    for (final q in queries) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?format=json&q=${Uri.encodeComponent(q)}&limit=1&countrycodes=id',
        );
        final resp = await http.get(url, headers: {
          'User-Agent': 'AdvantaSeedsFieldAudit/1.0 (audit@advantaseeds.com)',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final lat = double.tryParse(list[0]['lat']?.toString() ?? '');
            final lng = double.tryParse(list[0]['lon']?.toString() ?? '');
            if (lat != null && lng != null) return LatLng(lat, lng);
          }
        }
      } on TimeoutException {
        debugPrint('[GEO][PSP] Timeout geocode: $q');
      } catch (e) {
        debugPrint('[GEO][PSP] Error geocode: $e');
      }
    }
    return null;
  }

  Future<void> _importFromKml() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml', 'KML'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      final path = result.files.first.path;
      String content;
      if (bytes != null) {
        content = utf8.decode(bytes);
      } else if (path != null) {
        content = await File(path).readAsString();
      } else {
        _snack('Tidak dapat membaca file KML', err: true);
        return;
      }

      final polygon = CoordHelper.kmlPolygonToWkt(content);
      final coordinate = polygon == null
          ? CoordHelper.firstKmlCoordinate(content)
          : (lat: polygon.lat, lng: polygon.lng);
      if (coordinate == null) {
        _snack('Koordinat tidak ditemukan di file KML', err: true);
        return;
      }

      final coordStr = _formatCoordinate(coordinate.lat, coordinate.lng);
      final geoResult = await _reverseGeocode(coordinate.lat, coordinate.lng);
      if (mounted) {
        setState(() {
          _corrTaggingCtrl.text = coordStr;
          _newGeoResult = geoResult;
          _corrTaggingSource = 'kml';
          _pendingGeometryWkt = polygon?.wkt;
        });
        final polygonInfo =
            polygon == null ? '' : ' + polygon ${polygon.pointCount} titik';
        _snack('KML berhasil dimuat$polygonInfo: $coordStr');
      }
    } catch (e) {
      if (mounted) _snack('Gagal import KML: $e', err: true);
    }
  }

  Future<void> _applyManualCoord() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    final lat =
        double.tryParse(_manualLatCtrl.text.trim().replaceAll(',', '.'));
    final lng =
        double.tryParse(_manualLngCtrl.text.trim().replaceAll(',', '.'));
    if (lat == null || lng == null || !CoordHelper.isValidIndonesia(lat, lng)) {
      _snack('Latitude / Longitude tidak valid', err: true);
      return;
    }
    final coordStr = _formatCoordinate(lat, lng);
    final geoResult = await _reverseGeocode(lat, lng);
    setState(() {
      _corrTaggingCtrl.text = coordStr;
      _newGeoResult = geoResult;
      _corrTaggingSource = 'manual';
      _pendingGeometryWkt = null;
    });
    _snack('Koordinat manual diterapkan: $coordStr');
  }

  Future<void> _openMapPinDialog(Map<String, dynamic> fieldData) async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    LatLng initial = const LatLng(-7.5, 110.0);
    final existing = _parseCoordinate(_corrTaggingCtrl.text);
    if (existing != null) {
      initial = LatLng(existing.lat, existing.lng);
    } else {
      final field = _parseCoordinate(_existingCoordinate);
      if (field != null) {
        initial = LatLng(field.lat, field.lng);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Mencari koordinat wilayah...',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Color(0xFF9575CD),
            ),
          );
        }
        final geo = await _geocodeWilayah(fieldData);
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (geo != null) initial = geo;
      }
    }

    if (!mounted) return;
    final result = await showDialog<LatLng>(
      context: context,
      builder: (_) => _MapPinDialog(initial: initial),
    );

    if (result == null || !mounted) return;
    final coordStr = _formatCoordinate(result.latitude, result.longitude);
    final geoResult = await _reverseGeocode(result.latitude, result.longitude);
    if (mounted) {
      setState(() {
        _corrTaggingCtrl.text = coordStr;
        _newGeoResult = geoResult;
        _corrTaggingSource = 'map';
        _pendingGeometryWkt = null;
        _manualLatCtrl.text = result.latitude.toStringAsFixed(6);
        _manualLngCtrl.text = result.longitude.toStringAsFixed(6);
      });
      _snack('Koordinat dari peta diterapkan: $coordStr');
    }
  }

  bool _validateDates() {
    if (_roguings.every((roguing) => roguing.date == null)) {
      _snack('Minimal satu tanggal inspeksi roguing harus diisi', err: true);
      return false;
    }
    if (_roguings[3].date != null) return true;

    final hasLaterIncomplete = _recommendation != null ||
        _flagging != null ||
        _recommendationPldCtrl.text.trim().isNotEmpty;
    if (hasLaterIncomplete) {
      _snack('Isi tanggal Roguing 4 untuk recommendation/flagging final',
          err: true);
      return false;
    }
    return true;
  }

  Future<void> _saveAudit() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (_corrTaggingCtrl.text.trim().isEmpty) {
      _snack('Correction Tagging wajib diisi atau dikonfirmasi', err: true);
      return;
    }
    if (!_validateDates()) return;
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final completionDate = _roguings[3].date;
      final latestDate = _roguings
          .map((roguing) => roguing.date)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, date) {
        if (latest == null || date.isAfter(latest)) return date;
        return latest;
      });
      final summaryDate = completionDate ?? latestDate ?? now;
      final r1 = _roguings[0];
      final r4 = _roguings[3];
      final roguingFilledCount =
          _roguings.where((roguing) => roguing.date != null).length;
      final inferredRoguingStatus =
          completionDate != null ? 'C' : (roguingFilledCount > 0 ? 'B' : 'A');

      final data = <String, dynamic>{
        'field_number': widget.fieldNumber,
        'date_of_audit': _formatDate(completionDate),
        'audit_date_user': _formatDate(summaryDate),
        'audit_week': calcAuditWeek(summaryDate),
        'qa_fi': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'correction_tagging': _corrTaggingCtrl.text.trim(),
        'co_detasseling': _coRoguingCtrl.text.trim(),
        'field_size_by_audit_ha': _parseDouble(_fieldSizeCtrl),
        'previous_crop_by_audit': _previousCrop,
        'type_seed': _typeSeed,
        'isolation_problem_by_audit': r4.isolationAudit ?? r1.isolationAudit,
        'crop_health': r4.cropHealth ?? r1.cropHealth,
        'crop_uniformity': r4.cropUniformity ?? r1.cropUniformity,
        'roguing_status': inferredRoguingStatus,
        'offtype_in_male': r4.offtype ?? r1.offtype,
        'offtype_in_female': r4.offtype ?? r1.offtype,
        'lsv_status': r4.lsv,
        'decision': _recommendation,
        'pld_reason': _isPld ? 'PSP Recommendation Discard' : null,
        'flagging': _flagging,
        'remarks': _remarksCtrl.text.trim(),
        'fase': 'vegetative',
        'updated_at': now.toIso8601String(),
        'recommendation_pld_ha': _parseDouble(_recommendationPldCtrl),
      };

      for (final roguing in _roguings) {
        data.addAll(roguing.toPayload());
      }

      final service = ref.read(supabaseServiceProvider);
      await service.upsertVegetativeAudit(data);
      if (_pendingGeometryWkt != null &&
          _pendingGeometryWkt!.trim().isNotEmpty) {
        await service.updateFieldGeometryWkt(
          fieldNumber: widget.fieldNumber,
          geometryWkt: _pendingGeometryWkt!.trim(),
        );
      }

      double lat = 0.0, lng = 0.0;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final attendance = ref.read(attendanceProvider);
      if (attendance.isCheckedIn && attendance.attendanceId != null) {
        await service.logActivity(
          attendanceId: attendance.attendanceId!,
          userId: _qaFiCtrl.text.trim(),
          fieldNumber: widget.fieldNumber,
          phase: 'vegetative',
          actionType: 'single_submit_psp',
          lat: lat,
          lng: lng,
        );
      }

      if (!mounted) return;
      ref.invalidate(masterFieldsProvider);
      ref.invalidate(parsedMapFieldsProvider);
      ref.invalidate(vegetativeAuditProvider(widget.fieldNumber));
      _snack('Vegetative PSP audit berhasil disimpan');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool err = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: AdvantaText.body2.copyWith(color: Colors.white)),
        backgroundColor: err ? theme.colorScheme.error : AdvantaColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(vegetativeAuditProvider(widget.fieldNumber));
    final fields = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData = fields.firstWhere(
      (f) => f['field_number'] == widget.fieldNumber,
      orElse: () => {},
    );

    final resolvedCoord = _resolveFieldCoordinate(fieldData);
    if (resolvedCoord != null) {
      if (resolvedCoord.coordinate != _existingCoordinate ||
          resolvedCoord.source != _existingCoordinateSource) {
        _existingCoordinate = resolvedCoord.coordinate;
        _existingCoordinateSource = resolvedCoord.source;
        _existingGeoResult = null;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadExistingGeocode(resolvedCoord.coordinate),
        );
      }
    } else if (_existingCoordinate != null) {
      _existingCoordinate = null;
      _existingCoordinateSource = null;
      _existingGeoResult = null;
    }

    return Scaffold(
      appBar: PspAppBar(
        checkpointLabel: 'Vegetative PSP/PS',
        fieldNumber: widget.fieldNumber,
        isDiscard: _isPld,
        accentColor: _kPspVeg,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPspVeg)),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: AdvantaText.body2
                .copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (audit) {
          _loadAudit(audit, fieldData);
          return _buildBody(fieldData);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> fieldData) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PspFieldCard(fieldData: fieldData, accentColor: _kPspVeg),
                  const SizedBox(height: 14),
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],
                  _buildHeaderSection(),
                  const SizedBox(height: 12),
                  _buildRoguing1Section(fieldData),
                  const SizedBox(height: 12),
                  _buildRoguingSection(_roguings[1]),
                  const SizedBox(height: 12),
                  _buildRoguingSection(_roguings[2]),
                  const SizedBox(height: 12),
                  _buildRoguing4Section(),
                ],
              ),
            ),
          ),
          PspSaveBar(
            isSaving: _isSaving,
            isDiscard: _isPld && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY - TIDAK DAPAT MENYIMPAN'
                : (_isPld ? 'SIMPAN PSP - PLD' : 'SIMPAN PSP VEGETATIVE'),
            onSave: _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _saveAudit,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return PspSection(
      title: 'Informasi Audit',
      icon: Icons.assignment_outlined,
      color: _kPspVeg,
      children: [
        PspQaAutocomplete(
          controller: _qaFiCtrl,
          label: 'QA FI',
          hint: 'Nama QA Field Inspector',
          column: 'qa_fi',
          icon: Icons.person_outline,
          required: !_isGuest,
          accentColor: _kPspVeg,
        ),
        const SizedBox(height: 12),
        PspQaAutocomplete(
          controller: _qaSpvCtrl,
          label: 'QA SPV',
          hint: 'Nama QA Supervisor',
          column: 'qa_spv',
          icon: Icons.supervisor_account_outlined,
          required: !_isGuest,
          accentColor: _kPspVeg,
        ),
      ],
    );
  }

  Widget _buildRoguing1Section(Map<String, dynamic> fieldData) {
    final roguing = _roguings[0];
    const color = Color(0xFF26A69A);
    return PspSection(
      title: 'Roguing 1',
      icon: Icons.eco_outlined,
      color: color,
      children: [
        _dateTile('Date Of Inspeksi Roguing 1', roguing),
        const SizedBox(height: 12),
        _buildCorrectionTaggingWidget(fieldData, color),
        const SizedBox(height: 12),
        PspTextField(
          controller: _coRoguingCtrl,
          label: 'Co-Roguing',
          hint: 'Nama PIC co-roguing',
          icon: Icons.group_outlined,
          accentColor: color,
        ),
        const SizedBox(height: 12),
        PspDateTileNullable(
          label: 'Rev Tgl Tanam',
          date: _revTglTanam,
          onTap: () => _pickDate(
            initialDate: _revTglTanam,
            onPicked: (date) => setState(() => _revTglTanam = date),
          ),
          onClear: _isGuest ? null : () => setState(() => _revTglTanam = null),
        ),
        const SizedBox(height: 12),
        PspTextField(
          controller: _fieldSizeCtrl,
          label: 'Field Size by Audit (Ha)',
          keyboardType: TextInputType.number,
          icon: Icons.crop_landscape_outlined,
          required: !_isGuest,
          accentColor: color,
        ),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Previous Crop Actual',
          options: pspPreviousCropActualOpts,
          value: _previousCrop,
          required: !_isGuest,
          onChanged: (v) => _setValue(() => _previousCrop = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Type Seed',
          options: pspTypeSeedOpts,
          value: _typeSeed,
          required: !_isGuest,
          onChanged: (v) => _setValue(() => _typeSeed = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        _isolationFields(roguing, color),
        const SizedBox(height: 14),
        _coreRoguingFields(roguing, color, includeLsv: false),
      ],
    );
  }

  Widget _buildRoguingSection(_PspRoguingDraft roguing) {
    const color = Color(0xFFFFCA28);
    return PspSection(
      title: 'Roguing ${roguing.number}',
      icon: Icons.fact_check_outlined,
      color: color,
      children: [
        _dateTile('Date Of Inspeksi Roguing ${roguing.number}', roguing),
        const SizedBox(height: 14),
        _coreRoguingFields(roguing, color, includeLsv: true),
      ],
    );
  }

  Widget _buildRoguing4Section() {
    final roguing = _roguings[3];
    const color = AdvantaColors.error;
    return PspSection(
      title: 'Roguing 4 Final',
      icon: Icons.gavel_outlined,
      color: color,
      children: [
        _dateTile('Date Of Inspeksi Roguing 4', roguing),
        const SizedBox(height: 14),
        _coreRoguingFields(roguing, color, includeLsv: true),
        const SizedBox(height: 14),
        _isolationFields(roguing, color),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Flagging',
          options: pspRoguingFlaggingOpts,
          value: _flagging,
          onChanged: (v) => _setValue(() => _flagging = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Recommendation',
          required: !_isGuest,
          options: pspRecommendationOpts,
          value: _recommendation,
          onChanged: (v) => _setValue(() => _recommendation = v),
          accentColor: color,
        ),
        if (_isPld) ...[
          const SizedBox(height: 12),
          const PspDiscardBanner(
            message: 'Recommendation Discard aktif - isi luas PLD bila ada.',
          ),
        ],
        const SizedBox(height: 14),
        PspTextField(
          controller: _recommendationPldCtrl,
          label: 'Recommendation PLD (Ha)',
          keyboardType: TextInputType.number,
          icon: Icons.square_foot_outlined,
          required: _isPld && !_isGuest,
          accentColor: color,
        ),
        const SizedBox(height: 14),
        PspTextField(
          controller: _remarksCtrl,
          label: 'Remarks',
          hint: 'Catatan tambahan PSP/PS...',
          maxLines: 4,
          icon: Icons.edit_note_outlined,
          accentColor: color,
        ),
      ],
    );
  }

  Widget _buildCorrectionTaggingWidget(
      Map<String, dynamic> fieldData, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayCoord = _existingCoordinate ?? '';
    final coordSourceLabel = _coordinateSourceLabel(_existingCoordinateSource);
    final parsed = _parseCoordinate(displayCoord);
    final hasCoord = displayCoord.isNotEmpty;
    final isZeroCoord = parsed != null &&
        parsed.lat.abs() < 0.0001 &&
        parsed.lng.abs() < 0.0001;

    final kBlue = isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0288D1);
    final kBlueMuted =
        isDark ? const Color(0xFF80CBC4) : const Color(0xFF26A69A);
    final kDarkPanel =
        isDark ? const Color(0xFF1A2E40) : const Color(0xFFF0F4F8);
    final kDarkBorder =
        isDark ? const Color(0xFF2A4A60) : const Color(0xFFB0BEC5);
    const kManualColor = Color(0xFF4DB6AC);
    const kKmlColor = Color(0xFFFFB74D);
    const kMapColor = Color(0xFF9575CD);
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final fillColor = isDark
        ? AdvantaColors.deepForest.withAlpha(200)
        : AdvantaColors.softGrey;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);

    IconData sourceIcon = Icons.check_circle_outline;
    Color sourceColor = color;
    String sourceLabel = 'KOREKSI - KOORDINAT DIKONFIRMASI';
    switch (_corrTaggingSource) {
      case 'gps':
        sourceIcon = Icons.gps_fixed;
        sourceColor = AdvantaColors.success;
        sourceLabel = 'KOREKSI - GPS BARU DIAMBIL';
        break;
      case 'kml':
        sourceIcon = Icons.file_open_outlined;
        sourceColor = kKmlColor;
        sourceLabel = 'KOREKSI - DARI FILE KML';
        break;
      case 'map':
        sourceIcon = Icons.pin_drop_outlined;
        sourceColor = kMapColor;
        sourceLabel = 'KOREKSI - GESER PIN PETA';
        break;
      case 'manual':
        sourceIcon = Icons.edit_location_alt_outlined;
        sourceColor = kManualColor;
        sourceLabel = 'KOREKSI - INPUT MANUAL';
        break;
      case 'confirmed':
        sourceColor = kBlue;
        break;
    }
    final hasCorrection = _corrTaggingCtrl.text.trim().isNotEmpty;
    final panelAccent = hasCorrection ? sourceColor : color;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelAccent.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: panelAccent.withValues(alpha: hasCorrection ? 0.45 : 0.24),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: panelAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit_location_alt_rounded,
                    color: panelAccent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_isGuest ? 'Correction Tagging *' : 'Correction Tagging',
                      style: AdvantaText.bodyBold.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Koreksi titik koordinat lahan sebelum submit audit.',
                      style: AdvantaText.caption
                          .copyWith(color: subColor, height: 1.25),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: panelAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: panelAccent.withValues(alpha: 0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasCorrection
                          ? sourceIcon
                          : Icons.radio_button_unchecked_rounded,
                      size: 12,
                      color: panelAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasCorrection
                          ? sourceLabel.replaceFirst('KOREKSI - ', '')
                          : 'BELUM DIISI',
                      style: TextStyle(
                        color: panelAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasCoord) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isZeroCoord
                    ? AdvantaColors.error.withValues(alpha: 0.08)
                    : kDarkPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isZeroCoord
                      ? AdvantaColors.error.withValues(alpha: 0.40)
                      : kDarkBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isZeroCoord
                            ? Icons.wrong_location_outlined
                            : Icons.location_on_outlined,
                        color: isZeroCoord ? const Color(0xFFEF9A9A) : kBlue,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'KOORDINAT LAHAN (MASTER)',
                        style: TextStyle(
                          color: isZeroCoord ? const Color(0xFFEF9A9A) : kBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isZeroCoord
                              ? AdvantaColors.error.withValues(alpha: 0.15)
                              : kBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isZeroCoord ? 'Koordinat Nol' : coordSourceLabel,
                          style: TextStyle(
                            color:
                                isZeroCoord ? const Color(0xFFEF9A9A) : kBlue,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayCoord,
                    style: TextStyle(
                      color: isZeroCoord
                          ? const Color(0xFFEF9A9A).withValues(alpha: 0.70)
                          : kBlueMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (!isZeroCoord) ...[
                    const SizedBox(height: 8),
                    if (_isGeocodingExisting)
                      Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: kBlue),
                          ),
                          const SizedBox(width: 8),
                          Text('Memuat detail lokasi...',
                              style:
                                  TextStyle(color: kBlueMuted, fontSize: 11)),
                        ],
                      )
                    else if (_existingGeoResult != null) ...[
                      _geoRow(Icons.home_outlined, 'Desa',
                          _existingGeoResult!['desa'],
                          color: kBlueMuted),
                      const SizedBox(height: 4),
                      _geoRow(Icons.map_outlined, 'Kecamatan',
                          _existingGeoResult!['kecamatan'],
                          color: kBlueMuted),
                      const SizedBox(height: 4),
                      _geoRow(Icons.location_city_outlined, 'Kabupaten',
                          _existingGeoResult!['kabupaten'],
                          color: kBlueMuted),
                    ],
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      'Koordinat mengarah ke titik 0,0. Gunakan tombol koreksi di bawah.',
                      style: TextStyle(
                          color: const Color(0xFFEF9A9A),
                          fontSize: 10,
                          height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (hasCoord && parsed != null && !isZeroCoord) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _corrTaggingSource == 'confirmed' || _isGuest
                        ? null
                        : _useExistingCoordinate,
                    icon: Icon(
                      _corrTaggingSource == 'confirmed'
                          ? Icons.check_circle_rounded
                          : Icons.done_all_rounded,
                      size: 15,
                    ),
                    label: Text(
                      _corrTaggingSource == 'confirmed'
                          ? 'Sudah Dikonfirmasi'
                          : 'Koordinat Sudah Benar',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _corrTaggingSource == 'confirmed'
                          ? AdvantaColors.success
                          : kBlue,
                      side: BorderSide(
                        color: _corrTaggingSource == 'confirmed'
                            ? AdvantaColors.success.withValues(alpha: 0.50)
                            : kDarkBorder,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _isCapturingGps
                    ? Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: color.withValues(alpha: 0.40)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: color),
                            ),
                            const SizedBox(width: 8),
                            Text('Mengambil GPS...',
                                style: TextStyle(color: color, fontSize: 12)),
                          ],
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _isGuest || _isCapturingGps
                            ? null
                            : _captureUserGps,
                        icon: const Icon(Icons.my_location_rounded, size: 15),
                        label: const Text('Ambil GPS Saya',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _corrTaggingSource == 'gps'
                              ? AdvantaColors.success
                              : color,
                          side: BorderSide(
                            color: _corrTaggingSource == 'gps'
                                ? AdvantaColors.success.withValues(alpha: 0.60)
                                : color.withValues(alpha: 0.60),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGuest ? null : _importFromKml,
                  icon: const Icon(Icons.file_open_outlined, size: 15),
                  label:
                      const Text('Import KML', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _corrTaggingSource == 'kml'
                        ? kKmlColor
                        : kKmlColor.withValues(alpha: 0.70),
                    side: BorderSide(
                      color: _corrTaggingSource == 'kml'
                          ? kKmlColor.withValues(alpha: 0.70)
                          : kKmlColor.withValues(alpha: 0.30),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isGuest ? null : () => _openMapPinDialog(fieldData),
                  icon: const Icon(Icons.pin_drop_outlined, size: 15),
                  label: const Text('Geser Pin Peta',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _corrTaggingSource == 'map'
                        ? kMapColor
                        : kMapColor.withValues(alpha: 0.70),
                    side: BorderSide(
                      color: _corrTaggingSource == 'map'
                          ? kMapColor.withValues(alpha: 0.70)
                          : kMapColor.withValues(alpha: 0.30),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kManualColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kManualColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_location_alt_outlined,
                        color: kManualColor, size: 13),
                    SizedBox(width: 6),
                    Text(
                      'INPUT MANUAL KOORDINAT',
                      style: TextStyle(
                          color: kManualColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualLatCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: AdvantaText.body2.copyWith(color: textColor),
                        decoration:
                            _manualCoordDecor(context, 'Latitude', '-7.123456'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _manualLngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: AdvantaText.body2.copyWith(color: textColor),
                        decoration: _manualCoordDecor(
                            context, 'Longitude', '110.123456'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _isGuest ? null : _applyManualCoord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kManualColor.withValues(alpha: 0.20),
                          foregroundColor: kManualColor,
                          elevation: 0,
                          side: BorderSide(
                              color: kManualColor.withValues(alpha: 0.50)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Terapkan',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (hasCorrection) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sourceColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sourceColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(sourceIcon, color: sourceColor, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sourceLabel,
                          style: TextStyle(
                            color: sourceColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (!_isGuest)
                        GestureDetector(
                          onTap: () => setState(() {
                            _corrTaggingCtrl.clear();
                            _newGeoResult = null;
                            _corrTaggingSource = null;
                            _pendingGeometryWkt = null;
                          }),
                          child: Icon(Icons.close, color: subColor, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _corrTaggingCtrl.text,
                    style: TextStyle(
                      color: sourceColor.withValues(alpha: 0.80),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (_newGeoResult != null) ...[
                    const SizedBox(height: 8),
                    _geoRow(Icons.home_outlined, 'Desa', _newGeoResult!['desa'],
                        color: sourceColor.withValues(alpha: 0.90)),
                    const SizedBox(height: 3),
                    _geoRow(Icons.map_outlined, 'Kecamatan',
                        _newGeoResult!['kecamatan'],
                        color: sourceColor.withValues(alpha: 0.90)),
                    const SizedBox(height: 3),
                    _geoRow(Icons.location_city_outlined, 'Kabupaten',
                        _newGeoResult!['kabupaten'],
                        color: sourceColor.withValues(alpha: 0.90)),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: subColor.withValues(alpha: 0.50), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pilih salah satu opsi di atas untuk mengisi koreksi koordinat.',
                      style: AdvantaText.caption
                          .copyWith(color: subColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _manualCoordDecor(
      BuildContext context, String label, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor = isDark
        ? AdvantaColors.deepForest.withAlpha(200)
        : AdvantaColors.softGrey;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: subColor, fontSize: 11),
      hintStyle:
          TextStyle(color: subColor.withValues(alpha: 0.40), fontSize: 11),
      filled: true,
      fillColor: fillColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4DB6AC), width: 1.5),
      ),
    );
  }

  Widget _geoRow(IconData icon, String label, String? value,
      {Color color = const Color(0xFF80CBC4)}) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color.withValues(alpha: 0.70)),
        const SizedBox(width: 5),
        Text('$label: ',
            style:
                TextStyle(color: color.withValues(alpha: 0.70), fontSize: 11)),
        Expanded(
          child: Text(
            value?.isNotEmpty == true ? value! : '-',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _dateTile(String label, _PspRoguingDraft roguing) {
    return PspDateTileNullable(
      label: label,
      date: roguing.date,
      onTap: () => _pickDate(
        initialDate: roguing.date,
        onPicked: (date) => setState(() => roguing.date = date),
      ),
      onClear: _isGuest ? null : () => setState(() => roguing.date = null),
    );
  }

  Widget _coreRoguingFields(
    _PspRoguingDraft roguing,
    Color color, {
    required bool includeLsv,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PspOptionPicker(
                label: 'Audit Offtype',
                required: !_isGuest,
                options: pspBinaryFindingOpts,
                value: roguing.offtype,
                onChanged: (v) => _setValue(() => roguing.offtype = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PspOptionPicker(
                label: 'Audit Volunteer',
                required: !_isGuest,
                options: pspBinaryFindingOpts,
                value: roguing.volunteer,
                onChanged: (v) => _setValue(() => roguing.volunteer = v),
                accentColor: color,
              ),
            ),
          ],
        ),
        if (includeLsv) ...[
          const SizedBox(height: 14),
          PspOptionPicker(
            label: 'Audit LSV',
            required: !_isGuest,
            options: pspNoYesOpts,
            value: roguing.lsv,
            onChanged: (v) => _setValue(() => roguing.lsv = v),
            accentColor: color,
          ),
        ],
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Crop Health',
          required: !_isGuest,
          options: pspScoreOpts,
          value: roguing.cropHealth,
          onChanged: (v) => _setValue(() => roguing.cropHealth = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Crop Uniformity',
          required: !_isGuest,
          options: pspScoreOpts,
          value: roguing.cropUniformity,
          onChanged: (v) => _setValue(() => roguing.cropUniformity = v),
          accentColor: color,
        ),
      ],
    );
  }

  Widget _isolationFields(_PspRoguingDraft roguing, Color color) {
    return Column(
      children: [
        PspOptionPicker(
          label: 'Isolation Audit',
          required: !_isGuest,
          options: pspNoYesOpts,
          value: roguing.isolationAudit,
          onChanged: (v) => _setValue(() => roguing.isolationAudit = v),
          accentColor: color,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PspOptionPicker(
                label: 'Isolation Type',
                options: pspIsolationTypeOpts,
                value: roguing.isolationType,
                onChanged: (v) => _setValue(() => roguing.isolationType = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PspOptionPicker(
                label: 'Isolation Distance',
                options: pspIsolationDistanceOpts,
                value: roguing.isolationDistance,
                onChanged: (v) =>
                    _setValue(() => roguing.isolationDistance = v),
                accentColor: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _setValue(VoidCallback update) {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    setState(update);
  }
}

class _MapPinDialog extends StatefulWidget {
  final LatLng initial;

  const _MapPinDialog({required this.initial});

  @override
  State<_MapPinDialog> createState() => _MapPinDialogState();
}

class _MapPinDialogState extends State<_MapPinDialog> {
  late LatLng _pinPosition;
  late final MapController _mapCtrl;
  bool _isSatellite = true;

  String get _tileUrl => _isSatellite
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _pinPosition = widget.initial;
    _mapCtrl = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_outlined,
                      color: Color(0xFF9575CD), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geser Pin ke Titik Koordinat',
                      style: AdvantaText.bodyBold.copyWith(color: textColor),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: subColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9575CD).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF9575CD).withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined,
                        color: Color(0xFF9575CD), size: 13),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_pinPosition.latitude.toStringAsFixed(6)},  ${_pinPosition.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                            color: Color(0xFFCE93D8),
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: _pinPosition,
                        initialZoom: 15,
                        onTap: (tapPos, latLng) =>
                            setState(() => _pinPosition = latLng),
                      ),
                      children: [
                        TileLayer(
                          key: ValueKey(_isSatellite),
                          urlTemplate: _tileUrl,
                          userAgentPackageName: 'com.advantaseeds.fieldaudit',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pinPosition,
                              width: 40,
                              height: 50,
                              child: const Icon(Icons.location_pin,
                                  color: Color(0xFF9575CD), size: 38),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MapLayerButton(
                              selected: !_isSatellite,
                              icon: Icons.map_rounded,
                              label: 'Map',
                              onTap: () => setState(() => _isSatellite = false),
                            ),
                            _MapLayerButton(
                              selected: _isSatellite,
                              icon: Icons.satellite_alt_rounded,
                              label: 'Satellite',
                              onTap: () => setState(() => _isSatellite = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isSatellite)
                      Positioned(
                        left: 12,
                        bottom: 52,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Esri World Imagery',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 9),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Ketuk peta untuk memindahkan pin',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _pinPosition),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Gunakan Koordinat Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9575CD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLayerButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapLayerButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9575CD).withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected
                    ? const Color(0xFF7E57C2)
                    : AdvantaColors.mutedGrey,
                size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF7E57C2)
                    : AdvantaColors.mutedGrey,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PspRoguingDraft {
  final int number;

  DateTime? date;
  String? offtype;
  String? volunteer;
  String? lsv;
  String? cropHealth;
  String? cropUniformity;
  String? isolationAudit;
  String? isolationType;
  String? isolationDistance;

  _PspRoguingDraft(this.number);

  void dispose() {}

  void load(Map<String, dynamic>? audit) {
    date = _parse(audit?['date_of_inspeksi_roguing_$number']);
    offtype = audit?['audit_offtype_roguing_$number']?.toString();
    volunteer = audit?['audit_volunteer_roguing_$number']?.toString();
    lsv = audit?['audit_lsv_roguing_$number']?.toString();
    cropHealth = audit?['crop_health_roguing_$number']?.toString();
    cropUniformity = audit?['crop_uniformity_roguing_$number']?.toString();
    isolationAudit = audit?['isolation_audit_roguing_$number']?.toString();
    isolationType = audit?['isolation_type_roguing_$number']?.toString();
    isolationDistance =
        audit?['isolation_distance_roguing_$number']?.toString();
  }

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'date_of_inspeksi_roguing_$number': _format(date),
      'audit_offtype_roguing_$number': offtype,
      'audit_volunteer_roguing_$number': volunteer,
      'crop_health_roguing_$number': cropHealth,
      'crop_uniformity_roguing_$number': cropUniformity,
    };
    if (number != 1) {
      payload['audit_lsv_roguing_$number'] = lsv;
    }
    if (number == 1 || number == 4) {
      payload.addAll({
        'isolation_audit_roguing_$number': isolationAudit,
        'isolation_type_roguing_$number': isolationType,
        'isolation_distance_roguing_$number': isolationDistance,
      });
    }
    return payload;
  }

  static DateTime? _parse(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  static String? _format(DateTime? date) {
    if (date == null) return null;
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
