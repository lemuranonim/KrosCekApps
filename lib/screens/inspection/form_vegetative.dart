// lib/screens/inspection/form_vegetative.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <── TAMBAHKAN INI
import '../../providers/audit_vegetative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';   // ← NEW
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart';           // ← NEW
import 'generative_form_widgets.dart';

const _kPhaseVeg = Color(0xFF78909C);

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

const _cropUniformityOpts = [
  GenOpt('1', '1 – Very Poor'),
  GenOpt('2', '2 – Poor'),
  GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'),
  GenOpt('5', '5 – Best'),
];

const _cropHealthOpts = [
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

const _previousCropOpts = [
  GenOpt('CAC', 'Corn After Corn'),
  GenOpt('NC',  'Not Corn'),
];

const _finalDecisionOpts = [
  GenOpt('A', 'A – Pass'),
  GenOpt('B', 'B – Pass with Note'),
  GenOpt('C', 'C – Hold'),
  GenOpt('D', 'D – Discard'),
];

const _actionNeededOpts = [
  GenOpt('A', 'A – None'),
  GenOpt('B', 'B – Roguing'),
  GenOpt('C', 'C – Re-Detasseling'),
  GenOpt('D', 'D – Hold'),
  GenOpt('E', 'E – Recom PLD Partial'),
  GenOpt('F', 'F – Recom PLD Full'),
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

const _poiAccuracyOpts = [
  GenOpt('Valid',     'Valid'),
  GenOpt('Not Valid', 'Not Valid'),
];

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

  // ── NEW: session untuk GuestGuard ────────────────────────
  ActiveSession? _session;
  bool get _isGuest => GuestGuard.isGuest(_session);

  final _qaFiCtrl          = TextEditingController();
  final _qaSpvCtrl         = TextEditingController();
  final _corrTaggingCtrl   = TextEditingController();
  final _coDetasselingCtrl = TextEditingController();
  final _fieldSizeCtrl     = TextEditingController();
  final _sowingRatioFCtrl  = TextEditingController();
  final _sowingRatioMCtrl  = TextEditingController();
  final _remarksCtrl       = TextEditingController();
  final _manualLatCtrl     = TextEditingController();
  final _manualLngCtrl     = TextEditingController();

  DateTime _auditDateUser = DateTime.now();
  DateTime? _revPlantingDate; // Untuk Rev Planting Date

  String? _cropUniformity;    // Pengganti _cropCondition
  String? _cropHealth;        // Variabel baru
  String? _previousCrop;
  String? _maleSplit;
  String? _splitField;
  String? _oneSeedPerHole;
  String? _isolationProblem;
  String? _roguingStatus;
  String? _lsvStatus;
  String? _offtypeM;
  String? _offtypeF;
  String? _poiAccuracy;
  String? _finalDecision;
  String? _actionNeeded;
  String? _pldReason;
  String? _finalFlagging;

  bool _isGeocodingExisting = false;
  bool _isCapturingGps      = false;
  Map<String, String>? _existingGeoResult;
  Map<String, String>? _newGeoResult;
  String? _existingCoordinate;
  String? _corrTaggingSource;

  @override
  void initState() {
    super.initState();
    SessionManager.instance.getActiveSession().then((s) {
      if (mounted) setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _corrTaggingCtrl.dispose();
    _coDetasselingCtrl.dispose();
    _fieldSizeCtrl.dispose();
    _sowingRatioFCtrl.dispose();
    _sowingRatioMCtrl.dispose();
    _remarksCtrl.dispose();
    _manualLatCtrl.dispose();
    _manualLngCtrl.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil saran nama QA dari Supabase (Tabel master_fields)
  Future<Iterable<String>> _fetchQA(String column, String query) async {
    if (query.isEmpty) return const Iterable<String>.empty();
    try {
      // Cari nama di tabel master_fields yang mengandung kata yang diketik
      final response = await Supabase.instance.client
          .from('master_fields')
          .select(column)
          .ilike(column, '%$query%')
          .limit(20); // Ambil agak banyak untuk disaring uniknya

      final List<dynamic> data = response;

      // Saring data agar tidak ada nama yang duplikat dan jadikan KAPITAL
      final Set<String> uniqueNames = data
          .map((e) => e[column]?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .map((s) => s.toUpperCase())
          .toSet();

      return uniqueNames.take(5); // Batasi 5 saran teratas agar rapi
    } catch (e) {
      debugPrint('Error fetching QA: $e');
      return const Iterable<String>.empty();
    }
  }

  // Komponen Autocomplete khusus untuk form QA
  Widget _buildQaAutocomplete({
    required String label,
    required String hint,
    required String column, // 'qa_fi' atau 'qa_spv'
    required TextEditingController controller,
    required IconData icon,
    required Color accentColor,
    required bool isRequired,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor = isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
    final borderColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: AdvantaText.body2.copyWith(color: subColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (TextEditingValue textEditingValue) async {
            return await _fetchQA(column, textEditingValue.text);
          },
          onSelected: (String selection) {
            controller.text = selection;
            FocusScope.of(context).unfocus();
          },
          fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
            // Sinkronisasi controller Autocomplete dengan controller form
            fieldController.addListener(() {
              if (controller.text != fieldController.text) {
                controller.text = fieldController.text;
              }
            });

            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters, // Otomatis Huruf Besar
              style: AdvantaText.body1.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: subColor.withAlpha(100), fontSize: 13),
                prefixIcon: Icon(icon, color: accentColor, size: 20),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdvantaColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdvantaColors.error, width: 1.5),
                ),
                suffixIcon: fieldController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: subColor,
                  onPressed: () {
                    fieldController.clear();
                    controller.clear();
                  },
                )
                    : null,
              ),
              validator: isRequired ? (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null : null,
              onFieldSubmitted: (v) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width - 64, // Sesuaikan lebar dalam kotak Section
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AdvantaColors.deepForest : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Text(
                            option,
                            style: AdvantaText.body2.copyWith(color: accentColor, fontWeight: FontWeight.w600),
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
      ],
    );
  }



  void _loadAudit(Map<String, dynamic> audit, Map<String, dynamic> fieldData) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text          = audit['qa_fi']  ?? '';
    _qaSpvCtrl.text         = audit['qa_spv'] ?? '';
    _corrTaggingCtrl.text   = audit['correction_tagging'] ?? '';
    _coDetasselingCtrl.text = audit['co_detasseling']     ?? '';
    _fieldSizeCtrl.text     = audit['field_size_by_audit_ha']?.toString() ?? '';
    _remarksCtrl.text       = audit['remarks']      ?? '';

    final ratio = audit['sowing_ratio_by_audit'] as String?;
    if (ratio != null && ratio.contains(':')) {
      final p = ratio.split(':');
      _sowingRatioFCtrl.text = p[0];
      _sowingRatioMCtrl.text = p.length > 1 ? p[1] : '';
    }

    if (audit['audit_date_user'] != null) {
      try { _auditDateUser = DateTime.parse(audit['audit_date_user']); } catch (_) {}
    }

    if (audit['rev_planting_date'] != null) {
      try { _revPlantingDate = DateTime.parse(audit['rev_planting_date']); } catch (_) {}
    } else {
      // Fallback to planting_date_pdn if audit has no rev_planting_date
      final pdn = fieldData['planting_date_pdn'];
      if (pdn != null) {
        try { _revPlantingDate = DateTime.parse(pdn.toString()); } catch (_) {}
      }
    }

    setState(() {
      _cropUniformity    = audit['crop_uniformity']; // Baca dari kolom baru hasil rename
      _cropHealth        = audit['crop_health'];
      _previousCrop     = audit['previous_crop_by_audit'];
      _maleSplit        = audit['male_split_by_audit'];
      _splitField       = audit['split_field_by_audit'];
      _oneSeedPerHole   = audit['one_seed_per_hole'];
      _isolationProblem = audit['isolation_problem_by_audit'];
      _roguingStatus    = audit['roguing_status'];
      _lsvStatus        = audit['lsv_status'];
      _offtypeM         = audit['offtype_in_male'];
      _offtypeF         = audit['offtype_in_female'];
      _poiAccuracy      = audit['poi_accuracy'];
      _finalDecision    = audit['final_decision'];
      _actionNeeded     = audit['action_needed'];
      _pldReason        = audit['pld_reason'];
      _finalFlagging    = audit['final_flagging'];
    });
  }

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
    if (GuestGuard.blockIfGuest(context, _session)) return;
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
    if (GuestGuard.blockIfGuest(context, _session)) return;
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

  Future<LatLng?> _geocodeWilayah(Map<String, dynamic> fieldData) async {
    final dusun     = fieldData['hamlet_dusun']?.toString().trim() ?? '';
    final desa      = fieldData['village_desa']?.toString().trim() ?? '';
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
    if (kabupaten.isNotEmpty) {
      queries.add('$kabupaten, Indonesia');
    }
    if (queries.isEmpty) return null;

    for (final q in queries) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
              '?format=json&q=${Uri.encodeComponent(q)}&limit=1&countrycodes=id',
        );
        final resp = await http.get(url, headers: {
          'User-Agent': 'AdvantaSeedsFieldAudit/1.0 (audit@advantaseeds.com)',
          'Accept'    : 'application/json',
        }).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final lat = double.tryParse(list[0]['lat']?.toString() ?? '');
            final lng = double.tryParse(list[0]['lon']?.toString() ?? '');
            if (lat != null && lng != null) {
              return LatLng(lat, lng);
            }
          }
        }
      } on TimeoutException {
        debugPrint('[GEO] Timeout geocode: $q');
      } catch (e) {
        debugPrint('[GEO] Error geocode: $e');
      }
    }
    return null;
  }

  Future<void> _importFromKml() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    try {
      final result = await FilePicker.pickFiles(
        type             : FileType.custom,
        allowedExtensions: ['kml', 'KML'],
        withData         : true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      final path  = result.files.first.path;
      String content;
      if (bytes != null) {
        content = utf8.decode(bytes);
      } else if (path != null) {
        content = await File(path).readAsString();
      } else {
        _snack('Tidak dapat membaca file KML', err: true);
        return;
      }

      final coordMatch = RegExp(
        r'<coordinates[^>]*>\s*([-\d.]+)\s*,\s*([-\d.]+)',
        caseSensitive: false,
      ).firstMatch(content);

      if (coordMatch == null) {
        _snack('Koordinat tidak ditemukan di file KML', err: true);
        return;
      }

      final kmlLng = double.tryParse(coordMatch.group(1)!);
      final kmlLat = double.tryParse(coordMatch.group(2)!);
      if (kmlLat == null || kmlLng == null) {
        _snack('Format koordinat KML tidak valid', err: true);
        return;
      }

      final coordStr  = '${kmlLat.toStringAsFixed(6)},${kmlLng.toStringAsFixed(6)}';
      final geoResult = await _reverseGeocode(kmlLat, kmlLng);
      if (mounted) {
        setState(() {
          _corrTaggingCtrl.text = coordStr;
          _newGeoResult         = geoResult;
          _corrTaggingSource    = 'kml';
        });
        _snack('Koordinat dari KML berhasil dimuat: $coordStr');
      }
    } catch (e) {
      if (mounted) _snack('Gagal import KML: $e', err: true);
    }
  }

  Future<void> _applyManualCoord() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    final lat = double.tryParse(_manualLatCtrl.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_manualLngCtrl.text.trim().replaceAll(',', '.'));
    if (lat == null || lng == null) {
      _snack('Latitude / Longitude tidak valid', err: true);
      return;
    }
    final coordStr  = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    final geoResult = await _reverseGeocode(lat, lng);
    if (mounted) {
      setState(() {
        _corrTaggingCtrl.text = coordStr;
        _newGeoResult         = geoResult;
        _corrTaggingSource    = 'manual';
      });
      _snack('Koordinat manual diterapkan: $coordStr');
    }
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
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Mencari koordinat wilayah...', style: TextStyle(fontSize: 13)),
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
    final coordStr  = '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}';
    final geoResult = await _reverseGeocode(result.latitude, result.longitude);
    if (mounted) {
      setState(() {
        _corrTaggingCtrl.text = coordStr;
        _newGeoResult         = geoResult;
        _corrTaggingSource    = 'map';
        _manualLatCtrl.text   = result.latitude.toStringAsFixed(6);
        _manualLngCtrl.text   = result.longitude.toStringAsFixed(6);
      });
      _snack('Koordinat dari peta diterapkan: $coordStr');
    }
  }

  Future<void> _pickAuditDate() async {
    if (_isGuest) { GuestGuard.blockIfGuest(context, _session); return; }
    final p = await showDatePicker(
      context: context,
      initialDate: _auditDateUser,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: genDatePickerTheme(ctx, _kPhaseVeg),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDateUser = p);
  }

  Future<void> _saveAudit() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;

    // ── TAMBAHAN VALIDASI WAJIB: CORRECTION TAGGING ──
    if (_corrTaggingCtrl.text.trim().isEmpty) {
      _snack('Correction Tagging wajib diisi atau dikonfirmasi!', err: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now  = DateTime.now();
      final data = {
        'field_number'              : widget.fieldNumber,
        'date_of_audit'             : DateFormat('yyyy-MM-dd').format(now),
        'audit_date_user'           : DateFormat('yyyy-MM-dd').format(_auditDateUser),
        'audit_week'                : calcAuditWeek(_auditDateUser),
        'qa_fi'                     : _qaFiCtrl.text.trim(),
        'qa_spv'                    : _qaSpvCtrl.text.trim(),
        'correction_tagging'        : _corrTaggingCtrl.text.trim(),
        'co_detasseling'            : _coDetasselingCtrl.text.trim(),
        'field_size_by_audit_ha'    : double.tryParse(_fieldSizeCtrl.text.replaceAll(',', '.')),
        'male_split_by_audit'       : _maleSplit,
        'sowing_ratio_by_audit'     : '${_sowingRatioFCtrl.text.trim()}:${_sowingRatioMCtrl.text.trim()}',
        'split_field_by_audit'      : _splitField,
        'previous_crop_by_audit'    : _previousCrop,
        'one_seed_per_hole'         : _oneSeedPerHole,
        'isolation_problem_by_audit': _isolationProblem,
        'rev_planting_date'         : _revPlantingDate != null ? DateFormat('yyyy-MM-dd').format(_revPlantingDate!) : null, // MENGGUNAKAN TANGGAL PILIHAN USER
        'crop_uniformity'           : _cropUniformity,
        'crop_health'               : _cropHealth,
        'roguing_status'            : _roguingStatus,
        'lsv_status'                : _lsvStatus,
        'offtype_in_male'           : _offtypeM,
        'offtype_in_female'         : _offtypeF,
        'poi_accuracy'              : _poiAccuracy,
        'final_decision'            : _finalDecision,
        'action_needed'             : _actionNeeded,
        'pld_reason'                : _finalDecision == 'D' ? _pldReason : null,
        'final_flagging'            : _finalFlagging,
        'remarks'                   : _remarksCtrl.text.trim(),
        'fase'                      : 'vegetative',
        'updated_at'                : now.toIso8601String(),
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
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg, style: AdvantaText.body2.copyWith(color: Colors.white)),
      backgroundColor: err ? theme.colorScheme.error : AdvantaColors.success,
      behavior       : SnackBarBehavior.floating,
      shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin         : const EdgeInsets.all(12),
    ));
  }

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
      appBar: GenAppBar(
        checkpointLabel: 'Vegetative Audit',
        fieldNumber    : widget.fieldNumber,
        isDiscard      : isDiscard,
        accentColor    : _kPhaseVeg,
        onBack         : () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPhaseVeg)),
        error  : (e, _) => Center(
          child: Text('Error: $e',
              style: AdvantaText.body2.copyWith(color: Theme.of(context).colorScheme.error)),
        ),
        data   : (audit) {
          if (audit != null) {
            _loadAudit(audit, fieldData);
          } else {
            // New audit logic for default value
            if (!_dataLoaded && fieldData.isNotEmpty) {
              _dataLoaded = true;
              final pdn = fieldData['planting_date_pdn'];
              if (pdn != null) {
                try {
                  _revPlantingDate = DateTime.parse(pdn.toString());
                } catch (_) {
                  _revPlantingDate = DateTime.now();
                }
              } else {
                _revPlantingDate = DateTime.now();
              }
            }
          }
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
                  _buildFieldCard(context, fieldData, corrTag),
                  const SizedBox(height: 14),

                  // ── NEW: Guest read-only banner ──────────────
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

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
                      GenDateTile(
                        label: 'Rev Planting Date',
                        date : _revPlantingDate ?? DateTime.now(), // <--- TAMBAHKAN INI
                        onTap: () async {
                          if (_isGuest) { GuestGuard.blockIfGuest(context, _session); return; }
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _revPlantingDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (ctx, child) => Theme(
                              data: genDatePickerTheme(ctx, _kPhaseVeg),
                              child: child!,
                            ),
                          );
                          if (p != null) setState(() => _revPlantingDate = p);
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── GANTI GENTEXTFIELD QA FI MENJADI INI ──
                      _buildQaAutocomplete(
                        label      : 'QA FI',
                        hint       : 'Ketik Nama QA Field Inspector...',
                        column     : 'qa_fi', // Referensi kolom di database
                        controller : _qaFiCtrl,
                        icon       : Icons.person_outline,
                        accentColor: _kPhaseVeg,
                        isRequired : !_isGuest,
                      ),
                      const SizedBox(height: 12),

                      // ── GANTI GENTEXTFIELD QA SPV MENJADI INI ──
                      _buildQaAutocomplete(
                        label      : 'QA SPV',
                        hint       : 'Ketik Nama QA Supervisor...',
                        column     : 'qa_spv', // Referensi kolom di database
                        controller : _qaSpvCtrl,
                        icon       : Icons.supervisor_account_outlined,
                        accentColor: _kPhaseVeg,
                        isRequired : !_isGuest,
                      ),
                      const SizedBox(height: 12),
                      _buildCorrectionTaggingWidget(context, fieldData),
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
                        required   : !isDiscard && !_isGuest,
                        options    : _maleSplitOpts,
                        value      : _maleSplit,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _maleSplit = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      _buildSowingRatio(context, isDiscard),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Split Field',
                        required   : !isDiscard && !_isGuest,
                        options    : _splitFieldOpts,
                        value      : _splitField,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _splitField = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Previous Crop',
                        required   : !isDiscard && !_isGuest,
                        options    : _previousCropOpts,
                        value      : _previousCrop,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _previousCrop = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFF26A69A),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'One Seed / Hole',
                        required   : !isDiscard && !_isGuest,
                        options    : _yesNoOpts,
                        value      : _oneSeedPerHole,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _oneSeedPerHole = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
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
                        label      : 'Crop Uniformity', // Ganti label
                        required   : !isDiscard && !_isGuest,
                        options    : _cropUniformityOpts,
                        value      : _cropUniformity,
                        onChanged  : (v) => setState(() => _cropUniformity = v),
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Crop Health', // Field baru
                        required   : !isDiscard && !_isGuest,
                        options    : _cropHealthOpts,
                        value      : _cropHealth,
                        onChanged  : (v) => setState(() => _cropHealth = v),
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Roguing Status',
                        required   : !isDiscard && !_isGuest,
                        options    : _roguingOpts,
                        value      : _roguingStatus,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _roguingStatus = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'LSV Status',
                        required   : !isDiscard && !_isGuest,
                        options    : _lsvOpts,
                        value      : _lsvStatus,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _lsvStatus = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Isolation Problem',
                        required   : !isDiscard && !_isGuest,
                        options    : _isolationOpts,
                        value      : _isolationProblem,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _isolationProblem = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFFFFCA28),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Offtype M',
                              required   : !isDiscard && !_isGuest,
                              options    : _offtypeOpts,
                              value      : _offtypeM,
                              onChanged  : (v) { if (!_isGuest) {
                                setState(() => _offtypeM = v);
                              } else {
                                GuestGuard.blockIfGuest(context, _session);
                              } },
                              accentColor: const Color(0xFFFFCA28),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Offtype F',
                              required   : !isDiscard && !_isGuest,
                              options    : _offtypeOpts,
                              value      : _offtypeF,
                              onChanged  : (v) { if (!_isGuest) {
                                setState(() => _offtypeF = v);
                              } else {
                                GuestGuard.blockIfGuest(context, _session);
                              } },
                              accentColor: const Color(0xFFFFCA28),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'POI Accuracy',
                        required   : !isDiscard && !_isGuest,
                        options    : _poiAccuracyOpts,
                        value      : _poiAccuracy,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _poiAccuracy = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFFFFCA28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section 4: Keputusan ──
                  GenSection(
                    title: 'Keputusan',
                    icon : Icons.gavel_outlined,
                    color: AdvantaColors.error,
                    children: [
                      GenOptionPicker(
                        label      : 'Final Decision',
                        required   : !_isGuest,
                        options    : _finalDecisionOpts,
                        value      : _finalDecision,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() {
                          _finalDecision = v;
                          if (v != 'D') _pldReason = null;
                        });
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: AdvantaColors.error,
                      ),
                      if (isDiscard) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message: 'Mode Discard aktif — pastikan PLD Reason terisi sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenOptionPicker(
                          label      : 'PLD Reason',
                          required   : !_isGuest,
                          options    : _pldReasonOpts,
                          value      : _pldReason,
                          onChanged  : (v) { if (!_isGuest) {
                            setState(() => _pldReason = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          } },
                          accentColor: AdvantaColors.error,
                        ),
                      ],
                      const SizedBox(height: 14),
                      GenOptionPickerLong(
                        label      : 'Action Needed',
                        options    : _actionNeededOpts,
                        value      : _actionNeeded,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _actionNeeded = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: AdvantaColors.error,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Final Flagging',
                        options    : _finalFlaggingOpts,
                        value      : _finalFlagging,
                        onChanged  : (v) { if (!_isGuest) {
                          setState(() => _finalFlagging = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: AdvantaColors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section 5: Catatan ──
                  GenSection(
                    title: 'Catatan',
                    icon : Icons.notes_outlined,
                    color: AdvantaColors.mutedGrey,
                    children: [
                      GenTextField(
                        controller : _remarksCtrl,
                        label      : 'Remarks',
                        hint       : 'Catatan tambahan di lapangan...',
                        maxLines   : 4,
                        icon       : Icons.edit_note_outlined,
                        accentColor: AdvantaColors.mutedGrey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          GenSaveBar(
            isSaving : _isSaving,
            isDiscard: isDiscard && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY — TIDAK DAPAT MENYIMPAN'
                : (isDiscard ? 'SIMPAN — DISCARD' : 'SIMPAN VEGETATIVE'),
            onSave   : _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _saveAudit,
          ),
        ],
      ),
    );
  }

  // ── Field Card ────────────────────────────────────────────
  Widget _buildFieldCard(BuildContext context, Map<String, dynamic> f, String? corrTag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor   = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final valueColor   = Theme.of(context).colorScheme.onSurface;

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
            Expanded(child: _VegCell('Petani',    f['farmer_name']?.toString(), labelColor: labelColor, valueColor: valueColor)),
            Expanded(child: _VegCell('Hybrid',    f['hybrid']?.toString(), labelColor: labelColor, valueColor: valueColor)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Grower',    f['grower']?.toString(), labelColor: labelColor, valueColor: valueColor)),
            Expanded(child: _VegCell('Luas Eff',  '${f['effective_area_ha'] ?? '-'} Ha', labelColor: labelColor, valueColor: valueColor)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Season',    f['season']?.toString(), labelColor: labelColor, valueColor: valueColor)),
            Expanded(child: _VegCell('Region',    f['region']?.toString(), labelColor: labelColor, valueColor: valueColor)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Dusun',     f['hamlet_dusun']?.toString(), labelColor: labelColor, valueColor: valueColor)),
            Expanded(child: _VegCell('Desa',      f['village_desa']?.toString(), labelColor: labelColor, valueColor: valueColor)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VegCell('Kecamatan', f['sub_district_kec']?.toString(), labelColor: labelColor, valueColor: valueColor)),
            Expanded(child: _VegCell('Kabupaten', f['district_kab']?.toString(), labelColor: labelColor, valueColor: valueColor)),
          ]),
        ],
      ),
    );
  }

  // ── Correction Tagging Widget ─────────────────────────────
  Widget _buildCorrectionTaggingWidget(BuildContext context, Map<String, dynamic> fieldData) {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final rawCoord       = fieldData['coordinate']?.toString() ?? '';
    final hasCoord       = rawCoord.isNotEmpty;
    final parsed         = _parseCoordinate(rawCoord);
    final isZeroCoord    = parsed != null && parsed.lat.abs() < 0.0001 && parsed.lng.abs() < 0.0001;

    // Theme-aware colors
    final kBlue          = isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0288D1);
    final kBlueMuted     = isDark ? const Color(0xFF80CBC4) : const Color(0xFF26A69A);
    final kDarkPanel     = isDark ? const Color(0xFF1A2E40) : const Color(0xFFF0F4F8);
    final kDarkBorder    = isDark ? const Color(0xFF2A4A60) : const Color(0xFFB0BEC5);
    final kManualColor   = const Color(0xFF4DB6AC);
    final kKmlColor      = const Color(0xFFFFB74D);
    final kMapColor      = const Color(0xFF9575CD);
    final subColor       = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor      = isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
    final borderColor    = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final textColor      = Theme.of(context).colorScheme.onSurface;

    IconData  sourceIcon  = Icons.check_circle_outline;
    Color     sourceColor = kBlue;
    String    sourceLabel = 'KOREKSI — KOORDINAT DIKONFIRMASI';
    switch (_corrTaggingSource) {
      case 'gps':
        sourceIcon  = Icons.gps_fixed;
        sourceColor = AdvantaColors.success;
        sourceLabel = 'KOREKSI — GPS BARU DIAMBIL';
        break;
      case 'kml':
        sourceIcon  = Icons.file_open_outlined;
        sourceColor = kKmlColor;
        sourceLabel = 'KOREKSI — DARI FILE KML';
        break;
      case 'map':
        sourceIcon  = Icons.pin_drop_outlined;
        sourceColor = kMapColor;
        sourceLabel = 'KOREKSI — GESER PIN PETA';
        break;
      case 'manual':
        sourceIcon  = Icons.edit_location_alt_outlined;
        sourceColor = kManualColor;
        sourceLabel = 'KOREKSI — INPUT MANUAL';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          !_isGuest ? 'Correction Tagging *' : 'Correction Tagging', // Beri bintang jika bukan guest
          style: AdvantaText.body2.copyWith(color: subColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // ── Master coordinate card ──────────────────────────────────────────
        if (hasCoord) ...[
          Container(
            padding   : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color       : isZeroCoord ? AdvantaColors.error.withValues(alpha: 0.08) : kDarkPanel,
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: isZeroCoord ? AdvantaColors.error.withValues(alpha: 0.40) : kDarkBorder),
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
                        color       : isZeroCoord ? AdvantaColors.error.withValues(alpha: 0.15) : kBlue.withValues(alpha: 0.12),
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
                    Row(children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: kBlue)),
                      const SizedBox(width: 8),
                      Text('Memuat detail lokasi…', style: TextStyle(color: kBlueMuted, fontSize: 11)),
                    ])
                  else if (_existingGeoResult != null) ...[
                    _geoRow(Icons.home_outlined,          'Desa',      _existingGeoResult!['desa'],      color: kBlueMuted),
                    const SizedBox(height: 4),
                    _geoRow(Icons.map_outlined,           'Kecamatan', _existingGeoResult!['kecamatan'], color: kBlueMuted),
                    const SizedBox(height: 4),
                    _geoRow(Icons.location_city_outlined, 'Kabupaten', _existingGeoResult!['kabupaten'], color: kBlueMuted),
                  ],
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'Koordinat mengarah ke titik 0,0 (tidak valid). Gunakan tombol koreksi di bawah.',
                    style: TextStyle(color: const Color(0xFFEF9A9A), fontSize: 10, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Row 1: Konfirmasi + GPS ─────────────────────────────────────────
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
                    foregroundColor: _corrTaggingSource == 'confirmed' ? AdvantaColors.success : kBlue,
                    side           : BorderSide(
                      color: _corrTaggingSource == 'confirmed'
                          ? AdvantaColors.success.withValues(alpha: 0.50)
                          : kDarkBorder,
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
                  foregroundColor: _corrTaggingSource == 'gps' ? AdvantaColors.success : _kPhaseVeg,
                  side           : BorderSide(
                    color: _corrTaggingSource == 'gps'
                        ? AdvantaColors.success.withValues(alpha: 0.60)
                        : _kPhaseVeg.withValues(alpha: 0.60),
                  ),
                  shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Row 2: Import KML + Geser Pin ──────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importFromKml,
                icon : const Icon(Icons.file_open_outlined, size: 15),
                label: const Text('Import KML', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corrTaggingSource == 'kml' ? kKmlColor : kKmlColor.withValues(alpha: 0.70),
                  side           : BorderSide(
                    color: _corrTaggingSource == 'kml'
                        ? kKmlColor.withValues(alpha: 0.70)
                        : kKmlColor.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                  shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openMapPinDialog(fieldData),
                icon : const Icon(Icons.pin_drop_outlined, size: 15),
                label: const Text('Geser Pin Peta', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corrTaggingSource == 'map' ? kMapColor : kMapColor.withValues(alpha: 0.70),
                  side           : BorderSide(
                    color: _corrTaggingSource == 'map'
                        ? kMapColor.withValues(alpha: 0.70)
                        : kMapColor.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                  shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Manual Lat/Lng input ────────────────────────────────────────────
        Container(
          padding   : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color       : kManualColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border      : Border.all(color: kManualColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.edit_location_alt_outlined, color: Color(0xFF4DB6AC), size: 13),
                const SizedBox(width: 6),
                const Text(
                  'INPUT MANUAL KOORDINAT',
                  style: TextStyle(color: Color(0xFF4DB6AC), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller  : _manualLatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style       : AdvantaText.body2.copyWith(color: textColor),
                    decoration  : _manualCoordDecor(context, 'Latitude', '-7.123456'),
                    onChanged   : (_) {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller  : _manualLngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style       : AdvantaText.body2.copyWith(color: textColor),
                    decoration  : _manualCoordDecor(context, 'Longitude', '110.123456'),
                    onChanged   : (_) {},
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _applyManualCoord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kManualColor.withValues(alpha: 0.20),
                      foregroundColor: kManualColor,
                      elevation      : 0,
                      side           : BorderSide(color: kManualColor.withValues(alpha: 0.50)),
                      shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding        : const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Terapkan', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Result card ─────────────────────────────────────────────────────
        if (_corrTaggingCtrl.text.isNotEmpty) ...[
          Container(
            padding   : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color       : sourceColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: sourceColor.withValues(alpha: 0.35)),
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
                          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _corrTaggingCtrl.clear();
                        _newGeoResult      = null;
                        _corrTaggingSource = null;
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
                    fontSize: 11, fontFamily: 'monospace',
                  ),
                ),
                if (_newGeoResult != null) ...[
                  const SizedBox(height: 8),
                  _geoRow(Icons.home_outlined,          'Desa',      _newGeoResult!['desa'],      color: sourceColor.withValues(alpha: 0.90)),
                  const SizedBox(height: 3),
                  _geoRow(Icons.map_outlined,           'Kecamatan', _newGeoResult!['kecamatan'], color: sourceColor.withValues(alpha: 0.90)),
                  const SizedBox(height: 3),
                  _geoRow(Icons.location_city_outlined, 'Kabupaten', _newGeoResult!['kabupaten'], color: sourceColor.withValues(alpha: 0.90)),
                ],
              ],
            ),
          ),
        ] else ...[
          Container(
            padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color       : fillColor,
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: subColor.withValues(alpha: 0.50), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pilih salah satu opsi di atas untuk mengisi koreksi koordinat.',
                    style: AdvantaText.caption.copyWith(color: subColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _manualCoordDecor(BuildContext context, String label, String hint) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final subColor    = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor   = isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
    final borderColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    return InputDecoration(
      labelText     : label,
      hintText      : hint,
      labelStyle    : TextStyle(color: subColor, fontSize: 11),
      hintStyle     : TextStyle(color: subColor.withValues(alpha: 0.40), fontSize: 11),
      filled        : true,
      fillColor     : fillColor,
      isDense       : true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder : OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide  : BorderSide(color: borderColor),
      ),
      focusedBorder : OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide  : const BorderSide(color: Color(0xFF4DB6AC), width: 1.5),
      ),
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

  Widget _buildSowingRatio(BuildContext context, bool isDiscard) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final subColor    = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final textColor   = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDiscard ? 'Sowing Ratio (F : M)' : 'Sowing Ratio (F : M) *',
          style: AdvantaText.body2.copyWith(color: subColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller   : _sowingRatioFCtrl,
                keyboardType : TextInputType.number,
                style        : AdvantaText.body1.copyWith(color: textColor),
                decoration   : _ratioDecor(context, 'Female'),
                validator    : !isDiscard ? (v) => (v == null || v.isEmpty) ? 'Wajib' : null : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child  : Text(':', style: TextStyle(color: subColor.withValues(alpha: 0.70), fontSize: 22, fontWeight: FontWeight.w300)),
            ),
            Expanded(
              child: TextFormField(
                controller   : _sowingRatioMCtrl,
                keyboardType : TextInputType.number,
                style        : AdvantaText.body1.copyWith(color: textColor),
                decoration   : _ratioDecor(context, 'Male'),
                validator    : !isDiscard ? (v) => (v == null || v.isEmpty) ? 'Wajib' : null : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _ratioDecor(BuildContext context, String label) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final subColor    = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor   = isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
    final borderColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    return InputDecoration(
      labelText    : label,
      labelStyle   : TextStyle(color: subColor, fontSize: 12),
      filled       : true,
      fillColor    : fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : const BorderSide(color: _kPhaseVeg, width: 1.5),
      ),
      errorBorder : OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : BorderSide(color: AdvantaColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : BorderSide(color: AdvantaColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Veg Cell Widget
// ─────────────────────────────────────────────────────────────────────────────
class _VegCell extends StatelessWidget {
  final String  label;
  final String? value;
  final Color   labelColor;
  final Color   valueColor;
  const _VegCell(this.label, this.value, {required this.labelColor, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child  : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w500)),
          Text(
            value?.isNotEmpty == true ? value! : '—',
            style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Pin Drag Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _MapPinDialog extends StatefulWidget {
  final LatLng initial;
  const _MapPinDialog({required this.initial});

  @override
  State<_MapPinDialog> createState() => _MapPinDialogState();
}

class _MapPinDialogState extends State<_MapPinDialog> {
  late LatLng _pinPosition;
  late final MapController _mapCtrl;

  @override
  void initState() {
    super.initState();
    _pinPosition = widget.initial;
    _mapCtrl     = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final textColor    = Theme.of(context).colorScheme.onSurface;
    final subColor     = isDark ? Colors.white60 : AdvantaColors.mutedGrey;

    return Dialog(
      backgroundColor: surfaceColor,
      shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding   : const EdgeInsets.all(16),
      child          : SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child : Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child  : Row(
                children: [
                  const Icon(Icons.pin_drop_outlined, color: Color(0xFF9575CD), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geser Pin ke Titik Koordinat',
                      style: AdvantaText.bodyBold.copyWith(color: textColor),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon     : Icon(Icons.close, color: subColor, size: 20),
                    padding  : EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child  : Container(
                padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color       : const Color(0xFF9575CD).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border      : Border.all(color: const Color(0xFF9575CD).withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, color: Color(0xFF9575CD), size: 13),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_pinPosition.latitude.toStringAsFixed(6)},  ${_pinPosition.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(color: Color(0xFFCE93D8), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Map ──
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child       : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapCtrl,
                      options      : MapOptions(
                        initialCenter: _pinPosition,
                        initialZoom  : 15,
                        onTap        : (tapPos, latLng) => setState(() => _pinPosition = latLng),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.advantaseeds.fieldaudit',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point : _pinPosition,
                              width : 40,
                              height: 50,
                              child : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children    : [
                                  Icon(Icons.location_pin, color: Color(0xFF9575CD), size: 38),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 12,
                      left  : 0,
                      right : 0,
                      child : Center(
                        child: Container(
                          padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color       : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Ketuk peta untuk memindahkan pin',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Confirm button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child  : SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _pinPosition),
                  icon     : const Icon(Icons.check_rounded, size: 18),
                  label    : const Text('Gunakan Koordinat Ini'),
                  style    : ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9575CD),
                    foregroundColor: Colors.white,
                    padding        : const EdgeInsets.symmetric(vertical: 12),
                    shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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