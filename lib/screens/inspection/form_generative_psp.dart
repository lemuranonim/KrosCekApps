import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../providers/audit_generative_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart';
import 'psp_form_widgets.dart';

const _kPspGen = kPspGenerativeColor;

class FormGenerativePSP extends ConsumerStatefulWidget {
  final String fieldNumber;

  const FormGenerativePSP({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerativePSP> createState() => _FormGenerativePSPState();
}

class _FormGenerativePSPState extends ConsumerState<FormGenerativePSP> {
  final _formKey = GlobalKey<FormState>();
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  final _pldAreaCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  late final List<_PspGenRoguingDraft> _roguings;

  bool _isSaving = false;
  bool _dataLoaded = false;
  ActiveSession? _session;
  String? _recommendation;

  bool get _isGuest => GuestGuard.isGuest(_session);
  bool get _isPld => pspIsDiscardDecision(_recommendation);

  @override
  void initState() {
    super.initState();
    _roguings = [_PspGenRoguingDraft(5), _PspGenRoguingDraft(6)];
    SessionManager.instance.getActiveSession().then((s) {
      if (mounted) setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _pldAreaCtrl.dispose();
    _remarksCtrl.dispose();
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

  String? _formatDate(DateTime? date) =>
      date == null ? null : DateFormat('yyyy-MM-dd').format(date);

  double? _parseDouble(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _loadAudit(Map<String, dynamic>? audit, Map<String, dynamic> fieldData) {
    if (_dataLoaded) return;
    _dataLoaded = true;

    _qaFiCtrl.text = audit?['qa_fi_5']?.toString() ??
        audit?['qa_fi']?.toString() ??
        fieldData['qa_fi']?.toString() ??
        '';
    _qaSpvCtrl.text =
        audit?['qa_spv']?.toString() ?? fieldData['qa_spv']?.toString() ?? '';
    _pldAreaCtrl.text = audit?['pld_area_ha_5']?.toString() ?? '';
    _remarksCtrl.text = audit?['remarks_5']?.toString() ?? '';

    setState(() {
      _recommendation = audit?['final_decision_5']?.toString();
      for (final roguing in _roguings) {
        roguing.load(audit, parseDate: _parseDate);
      }
      _roguings[1].lsv ??= audit?['lsv_status_5']?.toString();
      _roguings[1].cropHealth ??= audit?['crop_health_5']?.toString();
      _roguings[1].cropUniformity ??= audit?['crop_uniformity_5']?.toString();
      _roguings[1].flagging ??= audit?['final_flagging_5']?.toString();
    });
  }

  Future<void> _pickDate(_PspGenRoguingDraft roguing) async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: roguing.date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: pspDatePickerTheme(ctx, _kPspGen),
        child: child!,
      ),
    );
    if (picked != null) setState(() => roguing.date = picked);
  }

  bool _validateDates() {
    final missing = _roguings
        .where((roguing) => roguing.date == null)
        .map((roguing) => roguing.number)
        .toList();
    if (missing.isNotEmpty) {
      _snack('Tanggal Roguing ${missing.join(', ')} wajib diisi', err: true);
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (!_validateDates()) return;
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final r6 = _roguings[1];
      final data = <String, dynamic>{
        'field_number': widget.fieldNumber,
        'date_of_audit_5': _formatDate(r6.date),
        'week_of_audit_5': calcAuditWeek(r6.date!),
        'qa_fi_5': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'lsv_status_5': r6.lsv,
        'crop_health_5': r6.cropHealth,
        'crop_uniformity_5': r6.cropUniformity,
        'final_flagging_5': r6.flagging,
        'final_decision_5': _recommendation,
        'pld_area_ha_5': _isPld ? _parseDouble(_pldAreaCtrl) : null,
        'pld_reason_5': _isPld ? 'PSP Recommendation Discard' : null,
        'remarks_5': _remarksCtrl.text.trim(),
        'submitted_at_5': now.toIso8601String(),
        'fase': 'generative_5',
      };
      for (final roguing in _roguings) {
        data.addAll(roguing.toPayload());
      }

      final service = ref.read(supabaseServiceProvider);
      await service.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint: 5,
        data: data,
      );

      double lat = 0, lng = 0;
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
          phase: 'generative_5',
          actionType: 'single_submit_psp',
          lat: lat,
          lng: lng,
        );
      }

      if (!mounted) return;
      ref.invalidate(masterFieldsProvider);
      ref.invalidate(generativeAuditProvider(widget.fieldNumber));
      _snack('Generative PSP audit berhasil disimpan');
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
    final auditAsync = ref.watch(generativeAuditProvider(widget.fieldNumber));
    final fields = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData = fields.firstWhere(
      (f) => f['field_number'] == widget.fieldNumber,
      orElse: () => {},
    );

    return Scaffold(
      appBar: PspAppBar(
        checkpointLabel: 'Generative PSP/PS',
        fieldNumber: widget.fieldNumber,
        isDiscard: _isPld,
        accentColor: _kPspGen,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPspGen)),
        error: (e, _) => Center(child: Text('Error: $e')),
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
                  PspFieldCard(fieldData: fieldData, accentColor: _kPspGen),
                  const SizedBox(height: 14),
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],
                  _buildAuditInfo(),
                  const SizedBox(height: 12),
                  _buildRoguingSection(_roguings[0], isFinal: false),
                  const SizedBox(height: 12),
                  _buildRoguingSection(_roguings[1], isFinal: true),
                ],
              ),
            ),
          ),
          PspSaveBar(
            isSaving: _isSaving,
            isDiscard: _isPld && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY - TIDAK DAPAT MENYIMPAN'
                : (_isPld
                    ? 'SIMPAN GENERATIVE PSP - PLD'
                    : 'SIMPAN GENERATIVE PSP'),
            onSave: _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _save,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditInfo() {
    return PspSection(
      title: 'Informasi Audit',
      icon: Icons.assignment_outlined,
      color: _kPspGen,
      children: [
        PspQaAutocomplete(
          controller: _qaFiCtrl,
          label: 'QA FI',
          hint: 'Nama QA Field Inspector',
          column: 'qa_fi',
          required: !_isGuest,
          icon: Icons.person_outline,
          accentColor: _kPspGen,
        ),
        const SizedBox(height: 12),
        PspQaAutocomplete(
          controller: _qaSpvCtrl,
          label: 'QA SPV',
          hint: 'Nama QA Supervisor',
          column: 'qa_spv',
          required: !_isGuest,
          icon: Icons.supervisor_account_outlined,
          accentColor: _kPspGen,
        ),
      ],
    );
  }

  Widget _buildRoguingSection(_PspGenRoguingDraft roguing,
      {required bool isFinal}) {
    final color = isFinal ? AdvantaColors.error : const Color(0xFFFFCA28);
    return PspSection(
      title: 'Roguing ${roguing.number}${isFinal ? ' Final' : ''}',
      icon: isFinal ? Icons.gavel_outlined : Icons.fact_check_outlined,
      color: color,
      children: [
        PspDateTileNullable(
          label: 'Date Of Inspeksi Roguing ${roguing.number}',
          date: roguing.date,
          onTap: () => _pickDate(roguing),
          onClear: _isGuest ? null : () => setState(() => roguing.date = null),
        ),
        const SizedBox(height: 14),
        _coreFields(roguing, color),
        const SizedBox(height: 14),
        _isolationFields(roguing, color),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Nicking Observation',
          required: !_isGuest,
          options: pspNoYesOpts,
          value: roguing.nickingObservation,
          onChanged: (v) => _setValue(() => roguing.nickingObservation = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Flagging',
          required: !_isGuest,
          options: pspRoguingFlaggingOpts,
          value: roguing.flagging,
          onChanged: (v) => _setValue(() => roguing.flagging = v),
          accentColor: color,
        ),
        if (isFinal) ...[
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
            controller: _pldAreaCtrl,
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
            maxLines: 4,
            icon: Icons.edit_note_outlined,
            accentColor: color,
          ),
        ],
      ],
    );
  }

  Widget _coreFields(_PspGenRoguingDraft roguing, Color color) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PspOptionPicker(
                label: 'Standing crop Offtype',
                required: !_isGuest,
                options: pspBinaryFindingOpts,
                value: roguing.standingCropOfftype,
                onChanged: (v) =>
                    _setValue(() => roguing.standingCropOfftype = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PspOptionPicker(
                label: 'Standing crop Volunteer',
                required: !_isGuest,
                options: pspBinaryFindingOpts,
                value: roguing.standingCropVolunteer,
                onChanged: (v) =>
                    _setValue(() => roguing.standingCropVolunteer = v),
                accentColor: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PspOptionPicker(
                label: 'Offtype Shed',
                required: !_isGuest,
                options: pspBinaryFindingOpts,
                value: roguing.offtypeShed,
                onChanged: (v) => _setValue(() => roguing.offtypeShed = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PspOptionPicker(
                label: 'Volunteer Shed',
                required: !_isGuest,
                options: pspBinaryFindingOpts,
                value: roguing.volunteerShed,
                onChanged: (v) => _setValue(() => roguing.volunteerShed = v),
                accentColor: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PspOptionPicker(
          label: 'Audit LSV',
          required: !_isGuest,
          options: pspNoYesOpts,
          value: roguing.lsv,
          onChanged: (v) => _setValue(() => roguing.lsv = v),
          accentColor: color,
        ),
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

  Widget _isolationFields(_PspGenRoguingDraft roguing, Color color) {
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

class _PspGenRoguingDraft {
  final int number;

  DateTime? date;
  String? standingCropOfftype;
  String? standingCropVolunteer;
  String? offtypeShed;
  String? volunteerShed;
  String? lsv;
  String? cropHealth;
  String? cropUniformity;
  String? isolationAudit;
  String? isolationType;
  String? isolationDistance;
  String? nickingObservation;
  String? flagging;

  _PspGenRoguingDraft(this.number);

  void dispose() {}

  void load(
    Map<String, dynamic>? audit, {
    required DateTime? Function(dynamic raw) parseDate,
  }) {
    date = parseDate(audit?['date_of_inspeksi_roguing_$number']);
    standingCropOfftype =
        audit?['standing_crop_offtype_roguing_$number']?.toString();
    standingCropVolunteer =
        audit?['standing_crop_volunteer_roguing_$number']?.toString();
    offtypeShed = audit?['offtype_shed_roguing_$number']?.toString();
    volunteerShed = audit?['volunteer_shed_roguing_$number']?.toString();
    lsv = audit?['audit_lsv_roguing_$number']?.toString();
    cropHealth = audit?['crop_health_roguing_$number']?.toString();
    cropUniformity = audit?['crop_uniformity_roguing_$number']?.toString();
    isolationAudit = audit?['isolation_audit_roguing_$number']?.toString();
    isolationType = audit?['isolation_type_roguing_$number']?.toString();
    isolationDistance =
        audit?['isolation_distance_roguing_$number']?.toString();
    nickingObservation =
        audit?['nicking_observation_roguing_$number']?.toString();
    flagging = audit?['flagging_roguing_$number']?.toString();
  }

  Map<String, dynamic> toPayload() {
    return {
      'date_of_inspeksi_roguing_$number':
          date == null ? null : DateFormat('yyyy-MM-dd').format(date!),
      'standing_crop_offtype_roguing_$number': standingCropOfftype,
      'standing_crop_volunteer_roguing_$number': standingCropVolunteer,
      'offtype_shed_roguing_$number': offtypeShed,
      'volunteer_shed_roguing_$number': volunteerShed,
      'audit_lsv_roguing_$number': lsv,
      'crop_health_roguing_$number': cropHealth,
      'crop_uniformity_roguing_$number': cropUniformity,
      'isolation_audit_roguing_$number': isolationAudit,
      'isolation_type_roguing_$number': isolationType,
      'isolation_distance_roguing_$number': isolationDistance,
      'nicking_observation_roguing_$number': nickingObservation,
      'flagging_roguing_$number': flagging,
    };
  }
}
