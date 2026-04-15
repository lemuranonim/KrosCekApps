// lib/screens/inspection/form_vegetative.dart
//
// FORM VEGETATIVE — Selaras penuh dengan generative_form_widgets.dart
// ─────────────────────────────────────────────────────────
// Semua widget lokal (section, field, option picker, save bar, app bar)
// diganti dengan widget dari generative_form_widgets.dart.
// Hanya widget khusus Vegetative yang tetap di sini:
//   • _buildCorrectionTaggingWidget (GPS/koordinat, unik untuk Veg)
//   • _buildSowingRatio             (F:M dual input, unik untuk Veg)
//   • _ReadOnlyCell                 (dibutuhkan di _buildFieldCard extended)
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../providers/audit_vegetative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import 'generative_form_widgets.dart';

// ─── Phase accent color ───────────────────────────────────
const _kPhaseVeg = Color(0xFF78909C); // Blue-Grey — Vegetative

// ─── Option lists ─────────────────────────────────────────
const _roguingOpts = [
  GenOpt('A', 'A – Not Yet'),
  GenOpt('B', 'B – On Going'),
  GenOpt('C', 'C – Done'),
];

const _lsvOpts = [
  GenOpt('A', 'A – None'),
  GenOpt('B', 'B – Low'),
  GenOpt('C', 'C – Moderate'),
  GenOpt('D', 'D – High'),
];

const _cropCondOpts = [
  GenOpt('1', '1 – Very Poor'),
  GenOpt('2', '2 – Poor'),
  GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'),
  GenOpt('5', '5 – Best'),
];

const _offtypeOpts = [
  GenOpt('A', 'A – 0'),
  GenOpt('B', 'B – >0'),
];

const _isolationOpts = [
  GenOpt('A', 'A – Yes'),
  GenOpt('B', 'B – No'),
];

const _finalDecisionOpts = [
  GenOpt('A', 'A – Pass'),
  GenOpt('B', 'B – Pass w/ Note'),
  GenOpt('C', 'C – Hold'),
  GenOpt('D', 'D – Discard'),
];

const _actionNeededOpts = [
  GenOpt('A', 'A – None'),
  GenOpt('B', 'B – Roguing'),
  GenOpt('C', 'C – Re-Detasseling'),
  GenOpt('D', 'D – Monitor'),
  GenOpt('E', 'E – Hold'),
  GenOpt('F', 'F – Discard Partial'),
  GenOpt('G', 'G – Discard Full'),
];

const _pldReasonOpts = [
  GenOpt('A', 'A – Poor Population'),
  GenOpt('B', 'B – Water Logging'),
  GenOpt('C', 'C – Pest/Disease Attack'),
  GenOpt('D', 'D – No Field'),
];

const _finalFlaggingOpts = [
  GenOpt('GF',  'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF',  'BF'),
  GenOpt('PLD', 'PLD'),
];

const _maleSplitOpts = [
  GenOpt('Y', 'Y – Yes'),
  GenOpt('N', 'N – No'),
];

const _yesNoOpts = [
  GenOpt('Y', 'Y – Yes'),
  GenOpt('N', 'N – No'),
];

const _splitFieldOpts = [
  GenOpt('A', 'A – Yes'),
  GenOpt('B', 'B – No'),
];

// ─────────────────────────────────────────────────────────
class FormVegetative extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormVegetative({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormVegetative> createState() => _FormVegetativeState();
}

class _FormVegetativeState extends ConsumerState<FormVegetative> {
  final _formKey   = GlobalKey<FormState>();
  bool _isSaving   = false;
  bool _dataLoaded = false;

  // ─── Controllers ────────────────────────────────────────
  final _qaFiCtrl          = TextEditingController();
  final _qaSpvCtrl         = TextEditingController();
  final _corrTaggingCtrl   = TextEditingController();
  final _coDetasselingCtrl = TextEditingController();
  final _fieldSizeCtrl     = TextEditingController();
  final _sowingRatioFCtrl  = TextEditingController();
  final _sowingRatioMCtrl  = TextEditingController();
  final _poiAccuracyCtrl   = TextEditingController();
  final _remarksCtrl       = TextEditingController();
  final _previousCropCtrl  = TextEditingController();

  // ─── Date ────────────────────────────────────────────────
  DateTime _auditDateUser = DateTime.now();

  // ─── Dropdown state ─────────────────────────────────────
  String? _maleSplit;
  String? _splitField;
  String? _oneSeedPerHole;
  String? _isolationProblem;
  String? _cropCondition;
  String? _roguingStatus;
  String? _lsvStatus;
  String? _offtypeM;
  String? _offtypeF;
  String? _finalDecision;
  String? _actionNeeded;
  String? _pldReason;
  String? _finalFlagging;

  // ─── Correction Tagging GPS state ───────────────────────
  bool _isGeocodingExisting = false;
  bool _isCapturingGps      = false;
  Map<String, String>? _existingGeoResult;
  Map<String, String>? _newGeoResult;
  String? _existingCoordinate;
  String? _corrTaggingSource; // 'confirmed' | 'gps' | null

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _corrTaggingCtrl.dispose();
    _coDetasselingCtrl.dispose();
    _fieldSizeCtrl.dispose();
    _sowingRatioFCtrl.dispose();
    _sowingRatioMCtrl.dispose();
    _poiAccuracyCtrl.dispose();
    _remarksCtrl.dispose();
    _previousCropCtrl.dispose();
    super.dispose();
  }

  // ─── Load existing audit ─────────────────────────────────
  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text          = audit['qa_fi']  ?? '';
    _qaSpvCtrl.text         = audit['qa_spv'] ?? '';
    _corrTaggingCtrl.text   = audit['correction_tagging'] ?? '';
    _coDetasselingCtrl.text = audit['co_detasseling']     ?? '';
    _fieldSizeCtrl.text     = audit['field_size_by_audit_ha']?.toString() ?? '';
    _poiAccuracyCtrl.text   = audit['poi_accuracy'] ?? '';
    _remarksCtrl.text       = audit['remarks']      ?? '';
    _previousCropCtrl.text  = audit['previous_crop_by_audit'] ?? '';

    final ratio = audit['sowing_ratio_by_audit'] as String?;
    if (ratio != null && ratio.contains(':')) {
      final p = ratio.split(':');
      _sowingRatioFCtrl.text = p[0];
      _sowingRatioMCtrl.text = p.length > 1 ? p[1] : '';
    }

    if (audit['audit_date_user'] != null) {
      try { _auditDateUser = DateTime.parse(audit['audit_date_user']); } catch (_) {}
    }
    setState(() {
      _maleSplit        = audit['male_split_by_audit'];
      _splitField       = audit['split_field_by_audit'];
      _oneSeedPerHole   = audit['one_seed_per_hole'];
      _isolationProblem = audit['isolation_problem_by_audit'];
      _cropCondition    = audit['crop_condition'];
      _roguingStatus    = audit['roguing_status'];
      _lsvStatus        = audit['lsv_status'];
      _offtypeM         = audit['offtype_in_male'];
      _offtypeF         = audit['offtype_in_female'];
      _finalDecision    = audit['final_decision'];
      _actionNeeded     = audit['action_needed'];
      _pldReason        = audit['pld_reason'];
      _finalFlagging    = audit['final_flagging'];
    });
  }

  // ─── Coordinate helpers ──────────────────────────────────
  ({double lat, double lng})? _parseCoordinate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
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
        final addr    = jsonData['address'] as Map<String, dynamic>? ?? {};
        return {
          'desa'      : (addr['village'] ?? addr['hamlet'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? '-').toString(),
          'kecamatan' : (addr['subdistrict'] ?? addr['city_district'] ?? addr['district'] ?? addr['county'] ?? '-').toString(),
          'kabupaten' : (addr['regency'] ?? addr['city'] ?? addr['state_district'] ?? addr['county'] ?? addr['state'] ?? '-').toString(),
        };
      }
    } on TimeoutException {
      debugPrint('[GEO] Timeout ($lat, $lng)');
    } catch (e) {
      debugPrint('[GEO] Exception: $e');
    }
    return {'desa': 'Gagal memuat', 'kecamatan': '-', 'kabupaten': '-'};
  }

  Future<void> _loadExistingGeocode(String coordinate) async {
    final parsed = _parseCoordinate(coordinate);
    if (parsed == null) return;
    setState(() => _isGeocodingExisting = true);
    final result = await _reverseGeocode(parsed.lat, parsed.lng);
    if (mounted) setState(() { _existingGeoResult = result; _isGeocodingExisting = false; });
  }

  Future<void> _captureUserGps() async {
    setState(() => _isCapturingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) { _snack('Izin lokasi ditolak', err: true); setState(() => _isCapturingGps = false); }
        return;
      }
      final pos       = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      final coordStr  = '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
      final geoResult = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _corrTaggingCtrl.text = coordStr;
          _newGeoResult         = geoResult;
          _corrTaggingSource    = 'gps';
          _isCapturingGps       = false;
        });
        _snack('GPS berhasil diambil: $coordStr');
      }
    } catch (e) {
      if (mounted) { _snack('Gagal ambil GPS: $e', err: true); setState(() => _isCapturingGps = false); }
    }
  }

  void _useExistingCoordinate() {
    if (_existingCoordinate == null || _existingCoordinate!.trim().isEmpty) {
      _snack('Koordinat lahan tidak tersedia', err: true);
      return;
    }
    setState(() {
      _corrTaggingCtrl.text = _existingCoordinate!.trim();
      _newGeoResult         = _existingGeoResult;
      _corrTaggingSource    = 'confirmed';
    });
    _snack('Koordinat lama dikonfirmasi sebagai koreksi ✓');
  }

  // ─── Date picker ────────────────────────────────────────
  Future<void> _pickAuditDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _auditDateUser,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _kPhaseVeg, surface: kGenSurface),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDateUser = p);
  }

  // ─── Save ────────────────────────────────────────────────
  Future<void> _saveAudit() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now  = DateTime.now();
      final data = {
        'field_number'            : widget.fieldNumber,
        'date_of_audit'           : DateFormat('yyyy-MM-dd').format(now),
        'audit_date_user'         : DateFormat('yyyy-MM-dd').format(_auditDateUser),
        'audit_week'              : calcAuditWeek(_auditDateUser),
        'qa_fi'                   : _qaFiCtrl.text.trim(),
        'qa_spv'                  : _qaSpvCtrl.text.trim(),
        'correction_tagging'      : _corrTaggingCtrl.text.trim(),
        'co_detasseling'          : _coDetasselingCtrl.text.trim(),
        'field_size_by_audit_ha'  : double.tryParse(_fieldSizeCtrl.text.replaceAll(',', '.')),
        'male_split_by_audit'     : _maleSplit,
        'sowing_ratio_by_audit'   : '${_sowingRatioFCtrl.text.trim()}:${_sowingRatioMCtrl.text.trim()}',
        'split_field_by_audit'    : _splitField,
        'previous_crop_by_audit'  : _previousCropCtrl.text.trim(),
        'one_seed_per_hole'       : _oneSeedPerHole,
        'isolation_problem_by_audit': _isolationProblem,
        'crop_condition'          : _cropCondition,
        'roguing_status'          : _roguingStatus,
        'lsv_status'              : _lsvStatus,
        'offtype_in_male'         : _offtypeM,
        'offtype_in_female'       : _offtypeF,
        'poi_accuracy'            : _poiAccuracyCtrl.text.trim(),
        'final_decision'          : _finalDecision,
        'action_needed'           : _actionNeeded,
        'pld_reason'              : _finalDecision == 'D' ? _pldReason : null,
        'final_flagging'          : _finalFlagging,
        'remarks'                 : _remarksCtrl.text.trim(),
        'fase'                    : 'vegetative',
        'updated_at'              : now.toIso8601String(),
      };

      final service = ref.read(supabaseServiceProvider);
      await service.upsertVegetativeAudit(data);

      double lat = 0.0, lng = 0.0;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
        );
        lat = pos.latitude; lng = pos.longitude;
      } catch (_) {}

      final attendance = ref.read(attendanceProvider);
      if (attendance.isCheckedIn && attendance.attendanceId != null) {
        await service.logActivity(
          attendanceId: attendance.attendanceId!,
          userId      : _qaFiCtrl.text.trim(),
          fieldNumber : widget.fieldNumber,
          phase       : 'vegetative',
          actionType  : 'single_submit',
          lat: lat, lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(vegetativeAuditProvider(widget.fieldNumber));
        _snack('Vegetative audit berhasil disimpan ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: err ? kGenRed : kGenGreen,
      behavior       : SnackBarBehavior.floating,
      shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(vegetativeAuditProvider(widget.fieldNumber));
    final fields     = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData  = fields.firstWhere(
          (f) => f['field_number'] == widget.fieldNumber,
      orElse: () => {},
    );

    final rawCoord = fieldData['coordinate']?.toString();
    if (rawCoord != null &&
        rawCoord.isNotEmpty &&
        rawCoord != _existingCoordinate &&
        !_isGeocodingExisting) {
      _existingCoordinate = rawCoord;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingGeocode(rawCoord));
    }

    final isDiscard = _finalDecision == 'D';

    return Scaffold(
      backgroundColor: kGenBg,
      appBar: buildGenAppBar(
        checkpointLabel: 'Vegetative Audit',
        fieldNumber    : widget.fieldNumber,
        isDiscard      : isDiscard,
        accentColor    : _kPhaseVeg,
        onBack         : () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPhaseVeg)),
        error  : (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: kGenSub))),
        data   : (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fieldData, isDiscard);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> fieldData, bool isDiscard) {
    final corrTag = fieldData['correction_tagging']?.toString();
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
                  // ── Field Info Card ──
                  _buildFieldCard(fieldData, corrTag),
                  const SizedBox(height: 14),

                  // ── Section 1: Informasi Audit ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon : Icons.assignment_outlined,
                    color: _kPhaseVeg,
                    children: [
                      GenDateTile(
                        label: 'Tanggal Audit',
                        date : _auditDateUser,
                        onTap: _pickAuditDate,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller : _qaFiCtrl,
                        label      : 'QA FI',
                        hint       : 'Nama QA Field Inspector',
                        required   : true,
                        icon       : Icons.person_outline,
                        accentColor: _kPhaseVeg,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller : _qaSpvCtrl,
                        label      : 'QA SPV',
                        hint       : 'Nama QA Supervisor',
                        required   : true,
                        icon       : Icons.supervisor_account_outlined,
                        accentColor: _kPhaseVeg,
                      ),
                      const SizedBox(height: 12),
                      _buildCorrectionTaggingWidget(fieldData),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller : _coDetasselingCtrl,
                        label      : 'Co Detasseling',
                        hint       : 'Nama Co Detasseling',
                        icon       : Icons.group_outlined,
                        accentColor: _kPhaseVeg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section 2: Kondisi Lahan ──
                  GenSection(
                    title: 'Kondisi Lahan',
                    icon : Icons.landscape_outlined,
                    color: const Color(0xFF26A69A),
                    children: [
                      GenTextField(
                        controller  : _fieldSizeCtrl,
                        label       : 'Field Size (Ha)',
                        hint        : 'Luas lahan audit',
                        keyboardType: TextInputType.number,
                        icon        : Icons.crop_landscape_outlined,
                        required    : !isDiscard,
                        accentColor : const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Male Split',
                        required   : !isDiscard,
                        options    : _maleSplitOpts,
                        value      : _maleSplit,
                        onChanged  : (v) => setState(() => _maleSplit = v),
                        accentColor: const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      _buildSowingRatio(isDiscard),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Split Field',
                        required   : !isDiscard,
                        options    : _splitFieldOpts,
                        value      : _splitField,
                        onChanged  : (v) => setState(() => _splitField = v),
                        accentColor: const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      GenTextField(
                        controller : _previousCropCtrl,
                        label      : 'Previous Crop',
                        hint       : 'Tanaman sebelumnya',
                        icon       : Icons.history_outlined,
                        accentColor: const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'One Seed / Hole',
                        required   : !isDiscard,
                        options    : _yesNoOpts,
                        value      : _oneSeedPerHole,
                        onChanged  : (v) => setState(() => _oneSeedPerHole = v),
                        accentColor: const Color(0xFF26A69A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section 3: Penilaian Audit ──
                  GenSection(
                    title: 'Penilaian Audit',
                    icon : Icons.assessment_outlined,
                    color: const Color(0xFFFFCA28),
                    children: [
                      GenOptionPicker(
                        label      : 'Crop Condition',
                        required   : !isDiscard,
                        options    : _cropCondOpts,
                        value      : _cropCondition,
                        onChanged  : (v) => setState(() => _cropCondition = v),
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Roguing Status',
                        required   : !isDiscard,
                        options    : _roguingOpts,
                        value      : _roguingStatus,
                        onChanged  : (v) => setState(() => _roguingStatus = v),
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'LSV Status',
                        required   : !isDiscard,
                        options    : _lsvOpts,
                        value      : _lsvStatus,
                        onChanged  : (v) => setState(() => _lsvStatus = v),
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Isolation Problem',
                        required   : !isDiscard,
                        options    : _isolationOpts,
                        value      : _isolationProblem,
                        onChanged  : (v) => setState(() => _isolationProblem = v),
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Offtype M',
                              required   : !isDiscard,
                              options    : _offtypeOpts,
                              value      : _offtypeM,
                              onChanged  : (v) => setState(() => _offtypeM = v),
                              accentColor: const Color(0xFFFFCA28),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Offtype F',
                              required   : !isDiscard,
                              options    : _offtypeOpts,
                              value      : _offtypeF,
                              onChanged  : (v) => setState(() => _offtypeF = v),
                              accentColor: const Color(0xFFFFCA28),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GenTextField(
                        controller : _poiAccuracyCtrl,
                        label      : 'POI Accuracy',
                        hint       : 'Tingkat akurasi POI',
                        icon       : Icons.gps_fixed_outlined,
                        accentColor: const Color(0xFFFFCA28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section 4: Keputusan ──
                  GenSection(
                    title: 'Keputusan',
                    icon : Icons.gavel_outlined,
                    color: kGenRed,
                    children: [
                      GenOptionPicker(
                        label      : 'Final Decision',
                        required   : true,
                        options    : _finalDecisionOpts,
                        value      : _finalDecision,
                        onChanged  : (v) => setState(() {
                          _finalDecision = v;
                          if (v != 'D') _pldReason = null;
                        }),
                        accentColor: kGenRed,
                      ),
                      if (isDiscard) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message: 'Mode Discard aktif — pastikan PLD Reason terisi sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenOptionPicker(
                          label      : 'PLD Reason',
                          required   : true,
                          options    : _pldReasonOpts,
                          value      : _pldReason,
                          onChanged  : (v) => setState(() => _pldReason = v),
                          accentColor: kGenRed,
                        ),
                      ],
                      const SizedBox(height: 14),
                      GenOptionPickerLong(
                        label      : 'Action Needed',
                        options    : _actionNeededOpts,
                        value      : _actionNeeded,
                        onChanged  : (v) => setState(() => _actionNeeded = v),
                        accentColor: kGenRed,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Final Flagging',
                        options    : _finalFlaggingOpts,
                        value      : _finalFlagging,
                        onChanged  : (v) => setState(() => _finalFlagging = v),
                        accentColor: kGenRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section 5: Catatan ──
                  GenSection(
                    title: 'Catatan',
                    icon : Icons.notes_outlined,
                    color: kGenSub,
                    children: [
                      GenTextField(
                        controller : _remarksCtrl,
                        label      : 'Remarks',
                        hint       : 'Catatan tambahan di lapangan...',
                        maxLines   : 4,
                        icon       : Icons.edit_note_outlined,
                        accentColor: kGenSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky Save Bar (dari shared widgets) ──
          GenSaveBar(
            isSaving : _isSaving,
            isDiscard: isDiscard,
            saveLabel: isDiscard ? 'SIMPAN — DISCARD' : 'SIMPAN VEGETATIVE',
            onSave   : _saveAudit,
          ),
        ],
      ),
    );
  }

  // ─── FIELD INFO CARD (Extended: ada Dusun/Desa/Kec/Kab) ─
  Widget _buildFieldCard(Map<String, dynamic> f, String? corrTag) {
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : _kPhaseVeg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border      : Border.all(color: _kPhaseVeg.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: _kPhaseVeg, size: 14),
              const SizedBox(width: 8),
              const Text(
                'DATA LAHAN (READ ONLY)',
                style: TextStyle(color: _kPhaseVeg, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              const Spacer(),
              if (corrTag != null && corrTag.isNotEmpty)
                Container(
                  padding   : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color        : const Color(0xFFFF7043).withValues(alpha: 0.15),
                    borderRadius : BorderRadius.circular(8),
                    border       : Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Corr: $corrTag',
                    style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VegCell('Petani',    f['farmer_name']?.toString())),
            Expanded(child: _VegCell('Hybrid',    f['hybrid']?.toString())),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Grower',    f['grower']?.toString())),
            Expanded(child: _VegCell('Luas Eff',  '${f['effective_area_ha'] ?? '-'} Ha')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Season',    f['season']?.toString())),
            Expanded(child: _VegCell('Region',    f['region']?.toString())),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Dusun',     f['hamlet_dusun']?.toString())),
            Expanded(child: _VegCell('Desa',      f['village_desa']?.toString())),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Kecamatan', f['sub_district_kec']?.toString())),
            Expanded(child: _VegCell('Kabupaten', f['district_kab']?.toString())),
          ]),
        ],
      ),
    );
  }

  // ─── CORRECTION TAGGING WIDGET ───────────────────────────
  Widget _buildCorrectionTaggingWidget(Map<String, dynamic> fieldData) {
    final rawCoord       = fieldData['coordinate']?.toString() ?? '';
    final hasCoord       = rawCoord.isNotEmpty;
    final parsed         = _parseCoordinate(rawCoord);
    final isZeroCoord    = parsed != null && parsed.lat.abs() < 0.0001 && parsed.lng.abs() < 0.0001;
    const kBlue          = Color(0xFF4FC3F7);
    const kBlueMuted     = Color(0xFF80CBC4);
    const kDarkPanel     = Color(0xFF1A2E40);
    const kDarkBorder    = Color(0xFF2A4A60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Correction Tagging',
          style: TextStyle(color: kGenSub, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // ── Koordinat Master Panel ──
        if (hasCoord) ...[
          Container(
            padding   : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color       : isZeroCoord ? kGenRed.withValues(alpha: 0.08) : kDarkPanel,
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: isZeroCoord ? kGenRed.withValues(alpha: 0.40) : kDarkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isZeroCoord ? Icons.wrong_location_outlined : Icons.location_on_outlined,
                      color: isZeroCoord ? const Color(0xFFEF9A9A) : kBlue,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'KOORDINAT LAHAN (MASTER)',
                      style: TextStyle(
                        color: isZeroCoord ? const Color(0xFFEF9A9A) : kBlue,
                        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding   : const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color       : isZeroCoord ? kGenRed.withValues(alpha: 0.15) : kBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isZeroCoord ? '⚠ Koordinat Nol' : '● Tersedia',
                        style: TextStyle(
                          color: isZeroCoord ? const Color(0xFFEF9A9A) : kBlue,
                          fontSize: 9, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  rawCoord,
                  style: TextStyle(
                    color: isZeroCoord ? const Color(0xFFEF9A9A).withValues(alpha: 0.70) : kBlueMuted,
                    fontSize: 10, fontFamily: 'monospace',
                  ),
                ),
                if (!isZeroCoord) ...[
                  const SizedBox(height: 8),
                  if (_isGeocodingExisting)
                    const Row(children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: kBlue)),
                      SizedBox(width: 8),
                      Text('Memuat detail lokasi…', style: TextStyle(color: kBlueMuted, fontSize: 11)),
                    ])
                  else if (_existingGeoResult != null) ...[
                    _geoRow(Icons.home_outlined,          'Desa',      _existingGeoResult!['desa']),
                    const SizedBox(height: 4),
                    _geoRow(Icons.map_outlined,           'Kecamatan', _existingGeoResult!['kecamatan']),
                    const SizedBox(height: 4),
                    _geoRow(Icons.location_city_outlined, 'Kabupaten', _existingGeoResult!['kabupaten']),
                  ],
                ] else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Koordinat mengarah ke titik 0,0 (tidak valid). Gunakan tombol "Ambil GPS Saya".',
                    style: TextStyle(color: Color(0xFFEF9A9A), fontSize: 10, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Tombol Aksi ──
        Row(
          children: [
            if (hasCoord && parsed != null && !isZeroCoord) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _corrTaggingSource == 'confirmed' ? null : _useExistingCoordinate,
                  icon : Icon(
                    _corrTaggingSource == 'confirmed' ? Icons.check_circle_rounded : Icons.done_all_rounded,
                    size: 15,
                  ),
                  label: Text(
                    _corrTaggingSource == 'confirmed' ? 'Sudah Dikonfirmasi' : 'Koordinat Sudah Benar',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _corrTaggingSource == 'confirmed' ? kGenGreen : kBlue,
                    side           : BorderSide(
                      color: _corrTaggingSource == 'confirmed' ? kGenGreen.withValues(alpha: 0.50) : kDarkBorder,
                      width: 1.2,
                    ),
                    shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _isCapturingGps
                  ? Container(
                height    : 42,
                decoration: BoxDecoration(
                  color       : _kPhaseVeg.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border      : Border.all(color: _kPhaseVeg.withValues(alpha: 0.40)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kPhaseVeg)),
                    SizedBox(width: 8),
                    Text('Mengambil GPS…', style: TextStyle(color: _kPhaseVeg, fontSize: 12)),
                  ],
                ),
              )
                  : OutlinedButton.icon(
                onPressed: _captureUserGps,
                icon : const Icon(Icons.my_location_rounded, size: 15),
                label: const Text('Ambil GPS Saya', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corrTaggingSource == 'gps' ? kGenGreen : _kPhaseVeg,
                  side           : BorderSide(
                    color: _corrTaggingSource == 'gps'
                        ? kGenGreen.withValues(alpha: 0.60)
                        : _kPhaseVeg.withValues(alpha: 0.60),
                  ),
                  shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Hasil Koordinat Koreksi ──
        if (_corrTaggingCtrl.text.isNotEmpty) ...[
          Container(
            padding   : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color       : _corrTaggingSource == 'confirmed'
                  ? kBlue.withValues(alpha: 0.07) : kGenGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(
                color: _corrTaggingSource == 'confirmed'
                    ? kBlue.withValues(alpha: 0.35) : kGenGreen.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _corrTaggingSource == 'confirmed' ? Icons.check_circle_outline : Icons.gps_fixed,
                      color: _corrTaggingSource == 'confirmed' ? kBlue : kGenGreen,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _corrTaggingSource == 'confirmed'
                          ? 'KOREKSI — KOORDINAT DIKONFIRMASI'
                          : 'KOREKSI — GPS BARU DIAMBIL',
                      style: TextStyle(
                        color: _corrTaggingSource == 'confirmed' ? kBlue : const Color(0xFF81C784),
                        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _corrTaggingCtrl.clear();
                        _newGeoResult      = null;
                        _corrTaggingSource = null;
                      }),
                      child: const Icon(Icons.close, color: kGenSub, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _corrTaggingCtrl.text,
                  style: TextStyle(
                    color: _corrTaggingSource == 'confirmed' ? kBlueMuted : const Color(0xFF81C784),
                    fontSize: 11, fontFamily: 'monospace',
                  ),
                ),
                if (_newGeoResult != null) ...[
                  const SizedBox(height: 8),
                  _geoRow(Icons.home_outlined,          'Desa',      _newGeoResult!['desa'],
                      color: _corrTaggingSource == 'confirmed' ? kBlueMuted : const Color(0xFF81C784)),
                  const SizedBox(height: 3),
                  _geoRow(Icons.map_outlined,           'Kecamatan', _newGeoResult!['kecamatan'],
                      color: _corrTaggingSource == 'confirmed' ? kBlueMuted : const Color(0xFF81C784)),
                  const SizedBox(height: 3),
                  _geoRow(Icons.location_city_outlined, 'Kabupaten', _newGeoResult!['kabupaten'],
                      color: _corrTaggingSource == 'confirmed' ? kBlueMuted : const Color(0xFF81C784)),
                ],
              ],
            ),
          ),
        ] else ...[
          Container(
            padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color       : kGenBg,
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: kGenBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: kGenSub.withValues(alpha: 0.50), size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pilih salah satu tombol di atas untuk mengisi koreksi koordinat.',
                    style: TextStyle(color: Color(0xFF546E7A), fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _geoRow(IconData icon, String label, String? value,
      {Color color = const Color(0xFF80CBC4)}) {
    return Row(children: [
      Icon(icon, size: 11, color: color.withValues(alpha: 0.70)),
      const SizedBox(width: 5),
      Text('$label: ', style: TextStyle(color: color.withValues(alpha: 0.70), fontSize: 11)),
      Expanded(
        child: Text(
          value?.isNotEmpty == true ? value! : '-',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }

  // ─── SOWING RATIO F:M ────────────────────────────────────
  Widget _buildSowingRatio(bool isDiscard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDiscard ? 'Sowing Ratio (F : M)' : 'Sowing Ratio (F : M) *',
          style: const TextStyle(color: kGenSub, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller   : _sowingRatioFCtrl,
                keyboardType : TextInputType.number,
                style        : const TextStyle(color: kGenWhite, fontSize: 14),
                decoration   : _ratioDecor('Female'),
                validator    : !isDiscard ? (v) => (v == null || v.isEmpty) ? 'Wajib' : null : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child  : Text(':', style: TextStyle(color: kGenSub.withValues(alpha: 0.70), fontSize: 22, fontWeight: FontWeight.w300)),
            ),
            Expanded(
              child: TextFormField(
                controller   : _sowingRatioMCtrl,
                keyboardType : TextInputType.number,
                style        : const TextStyle(color: kGenWhite, fontSize: 14),
                decoration   : _ratioDecor('Male'),
                validator    : !isDiscard ? (v) => (v == null || v.isEmpty) ? 'Wajib' : null : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _ratioDecor(String label) => InputDecoration(
    labelText    : label,
    labelStyle   : const TextStyle(color: kGenSub, fontSize: 12),
    filled       : true,
    fillColor    : kGenBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide  : const BorderSide(color: kGenBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide  : const BorderSide(color: _kPhaseVeg, width: 1.5),
    ),
    errorBorder : OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide  : const BorderSide(color: kGenRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide  : const BorderSide(color: kGenRed, width: 1.5),
    ),
  );
}

// ─── VEGETATIVE READ-ONLY CELL (extended: handles null safely) ──
class _VegCell extends StatelessWidget {
  final String  label;
  final String? value;
  const _VegCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child  : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF546E7A), fontSize: 10, fontWeight: FontWeight.w500)),
          Text(
            value?.isNotEmpty == true ? value! : '—',
            style: const TextStyle(color: kGenWhite, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}