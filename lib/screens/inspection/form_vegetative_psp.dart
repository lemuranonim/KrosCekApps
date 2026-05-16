import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

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
  bool _dataLoaded = false;
  ActiveSession? _session;

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

  ({String coordinate, String source})? _resolveFieldCoordinate(
      Map<String, dynamic> fieldData) {
    final centroid =
        CoordHelper.wktCentroid(fieldData['geometry_wkt']?.toString());
    if (centroid != null) {
      final lat = centroid['lat']!;
      final lng = centroid['lng']!;
      if (CoordHelper.isValidIndonesia(lat, lng)) {
        return (coordinate: _formatCoordinate(lat, lng), source: 'Polygon');
      }
    }

    final correction =
        _parseCoordinate(fieldData['correction_tagging']?.toString());
    if (correction != null &&
        CoordHelper.isValidIndonesia(correction.lat, correction.lng)) {
      return (
        coordinate: _formatCoordinate(correction.lat, correction.lng),
        source: 'Correction Tagging'
      );
    }

    final coordinate = _parseCoordinate(fieldData['coordinate']?.toString());
    if (coordinate != null &&
        CoordHelper.isValidIndonesia(coordinate.lat, coordinate.lng)) {
      return (
        coordinate: _formatCoordinate(coordinate.lat, coordinate.lng),
        source: 'Coordinate'
      );
    }

    return null;
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
      setState(() {
        _corrTaggingCtrl.text = _formatCoordinate(pos.latitude, pos.longitude);
        _corrTaggingSource = 'GPS';
      });
      _snack('GPS berhasil dipakai untuk correction tagging');
    } catch (e) {
      _snack('Gagal ambil GPS: $e', err: true);
    } finally {
      if (mounted) setState(() => _isCapturingGps = false);
    }
  }

  void _useExistingCoordinate(Map<String, dynamic> fieldData) {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    final resolved = _resolveFieldCoordinate(fieldData);
    if (resolved == null) {
      _snack('Koordinat lahan belum tersedia', err: true);
      return;
    }
    setState(() {
      _corrTaggingCtrl.text = resolved.coordinate;
      _corrTaggingSource = resolved.source;
    });
    _snack('${resolved.source} dipakai untuk correction tagging');
  }

  void _applyManualCoord() {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    final lat =
        double.tryParse(_manualLatCtrl.text.trim().replaceAll(',', '.'));
    final lng =
        double.tryParse(_manualLngCtrl.text.trim().replaceAll(',', '.'));
    if (lat == null || lng == null || !CoordHelper.isValidIndonesia(lat, lng)) {
      _snack('Latitude / Longitude tidak valid', err: true);
      return;
    }
    setState(() {
      _corrTaggingCtrl.text = _formatCoordinate(lat, lng);
      _corrTaggingSource = 'Manual';
    });
    _snack('Koordinat manual diterapkan');
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
      if (mounted) Navigator.pop(context);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final textColor = theme.colorScheme.onSurface;
    final fillColor = isDark
        ? AdvantaColors.deepForest.withAlpha(200)
        : AdvantaColors.softGrey;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final resolved = _resolveFieldCoordinate(fieldData);
    final hasCorrection = _corrTaggingCtrl.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 26 : 14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(isDark ? 90 : 55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !_isGuest ? 'Correction Tagging *' : 'Correction Tagging',
                  style: AdvantaText.bodyBold.copyWith(color: textColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (hasCorrection ? AdvantaColors.success : color)
                      .withAlpha(isDark ? 45 : 24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasCorrection
                      ? (_corrTaggingSource ?? 'TERISI').toUpperCase()
                      : 'BELUM DIISI',
                  style: AdvantaText.caption.copyWith(
                    color: hasCorrection ? AdvantaColors.success : color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (resolved != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: subColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resolved.source,
                            style: AdvantaText.caption.copyWith(
                                color: subColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(resolved.coordinate,
                            style: AdvantaText.body2.copyWith(
                                color: textColor, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isGuest
                        ? null
                        : () => _useExistingCoordinate(fieldData),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Pakai'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextFormField(
            controller: _corrTaggingCtrl,
            readOnly: _isGuest,
            style: AdvantaText.body1.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: '-7.123456,112.123456',
              hintStyle:
                  AdvantaText.caption.copyWith(color: subColor.withAlpha(120)),
              prefixIcon:
                  Icon(Icons.location_on_outlined, color: subColor, size: 18),
              suffixIcon: hasCorrection && !_isGuest
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() {
                        _corrTaggingCtrl.clear();
                        _corrTaggingSource = null;
                      }),
                    )
                  : null,
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() => _corrTaggingSource = 'Manual'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isGuest || _isCapturingGps ? null : _captureUserGps,
                icon: _isCapturingGps
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed, size: 16),
                label: Text(_isCapturingGps ? 'Mengambil GPS' : 'Ambil GPS'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _isGuest ? null : () => _useExistingCoordinate(fieldData),
                icon: const Icon(Icons.my_location_outlined, size: 16),
                label: const Text('Gunakan Koordinat Lahan'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PspTextField(
                  controller: _manualLatCtrl,
                  label: 'Latitude',
                  keyboardType: TextInputType.number,
                  accentColor: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PspTextField(
                  controller: _manualLngCtrl,
                  label: 'Longitude',
                  keyboardType: TextInputType.number,
                  accentColor: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isGuest ? null : _applyManualCoord,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
              label: const Text('Terapkan Manual'),
            ),
          ),
        ],
      ),
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
