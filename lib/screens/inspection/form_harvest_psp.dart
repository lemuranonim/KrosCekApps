import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../providers/attendance_provider.dart';
import '../../providers/audit_harvest_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart';
import 'psp_form_widgets.dart';

const _kPspHarvest = kPspHarvestColor;

class FormHarvestPSP extends ConsumerStatefulWidget {
  final String fieldNumber;

  const FormHarvestPSP({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormHarvestPSP> createState() => _FormHarvestPSPState();
}

class _FormHarvestPSPState extends ConsumerState<FormHarvestPSP> {
  final _formKey = GlobalKey<FormState>();
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  bool _isSaving = false;
  bool _dataLoaded = false;
  ActiveSession? _session;
  DateTime _auditDate = DateTime.now();
  DateTime? _downgradeFlagDate;
  String? _earCondition;
  String? _cropUniformity;
  String? _cropHealth;
  String? _statusDowngrade;
  String? _reasonDowngrade;
  String? _downgradeFlagging;
  String? _finalFlagging;
  bool _showDowngrade = false;

  bool get _isGuest => GuestGuard.isGuest(_session);

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
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic>? audit, Map<String, dynamic> fieldData) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text =
        audit?['qa_fi']?.toString() ?? fieldData['qa_fi']?.toString() ?? '';
    _qaSpvCtrl.text =
        audit?['qa_spv']?.toString() ?? fieldData['qa_spv']?.toString() ?? '';
    _remarksCtrl.text = audit?['remarks']?.toString() ?? '';

    if (audit?['date_of_audit'] != null) {
      try {
        _auditDate = DateTime.parse(audit!['date_of_audit'].toString());
      } catch (_) {}
    }

    setState(() {
      _earCondition = audit?['ear_condition_observation']?.toString();
      _cropUniformity = audit?['crop_uniformity']?.toString();
      _cropHealth = audit?['crop_health']?.toString();
      _statusDowngrade = audit?['status_downgrade']?.toString();
      _reasonDowngrade = audit?['reason_downgrade']?.toString();
      _downgradeFlagging = audit?['downgrade_flagging']?.toString();
      _finalFlagging = audit?['final_flagging']?.toString();
      if (audit?['downgrade_flag_date'] != null) {
        try {
          _downgradeFlagDate =
              DateTime.parse(audit!['downgrade_flag_date'].toString());
        } catch (_) {}
      }
      _showDowngrade = _statusDowngrade != null ||
          _reasonDowngrade != null ||
          _downgradeFlagging != null ||
          _downgradeFlagDate != null;
    });
  }

  Future<void> _pickDate() async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: pspDatePickerTheme(ctx, _kPspHarvest),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _auditDate = picked);
  }

  Future<void> _pickDowngradeDate() async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _downgradeFlagDate ?? _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: pspDatePickerTheme(ctx, _kPspHarvest),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _downgradeFlagDate = picked);
  }

  Future<void> _save() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final data = {
        'field_number': widget.fieldNumber,
        'date_of_audit': DateFormat('yyyy-MM-dd').format(_auditDate),
        'audit_week': calcAuditWeek(_auditDate),
        'ear_condition_observation': _earCondition,
        'crop_uniformity': _cropUniformity,
        'crop_health': _cropHealth,
        'status_downgrade': _showDowngrade ? _statusDowngrade : null,
        'reason_downgrade': _showDowngrade ? _reasonDowngrade : null,
        'downgrade_flagging': _showDowngrade ? _downgradeFlagging : null,
        'downgrade_flag_date': _showDowngrade && _downgradeFlagDate != null
            ? DateFormat('yyyy-MM-dd').format(_downgradeFlagDate!)
            : null,
        'final_flagging': _finalFlagging,
        'remarks': _remarksCtrl.text.trim(),
        'qa_fi': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'fase': 'Harvest',
        'updated_at': now.toIso8601String(),
      };

      final service = ref.read(supabaseServiceProvider);
      await service.upsertHarvestAudit(data);

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
          phase: 'harvest',
          actionType: 'single_submit_psp',
          lat: lat,
          lng: lng,
        );
      }

      if (!mounted) return;
      ref.invalidate(masterFieldsProvider);
      ref.invalidate(harvestAuditProvider(widget.fieldNumber));
      _snack('Harvest PSP audit berhasil disimpan');
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
    final auditAsync = ref.watch(harvestAuditProvider(widget.fieldNumber));
    final fields = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData = fields.firstWhere(
      (f) => f['field_number'] == widget.fieldNumber,
      orElse: () => {},
    );

    return Scaffold(
      appBar: PspAppBar(
        checkpointLabel: 'Harvest PSP/PS',
        fieldNumber: widget.fieldNumber,
        isDiscard: false,
        accentColor: _kPspHarvest,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPspHarvest)),
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
                  PspFieldCard(fieldData: fieldData, accentColor: _kPspHarvest),
                  const SizedBox(height: 14),
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],
                  PspSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: _kPspHarvest,
                    children: [
                      PspDateTile(
                        label: 'Date of Inspeksi Harvest',
                        date: _auditDate,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      PspQaAutocomplete(
                        controller: _qaFiCtrl,
                        label: 'QA FI',
                        hint: 'Nama QA Field Inspector',
                        column: 'qa_fi',
                        required: !_isGuest,
                        icon: Icons.person_outline,
                        accentColor: _kPspHarvest,
                      ),
                      const SizedBox(height: 12),
                      PspQaAutocomplete(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        column: 'qa_spv',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: _kPspHarvest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PspSection(
                    title: 'Penilaian Harvest',
                    icon: Icons.agriculture_outlined,
                    color: _kPspHarvest,
                    children: [
                      PspOptionPicker(
                        label: 'Ear Condition',
                        required: !_isGuest,
                        options: pspHarvestEarConditionOpts,
                        value: _earCondition,
                        onChanged: (v) => _setValue(() => _earCondition = v),
                        accentColor: _kPspHarvest,
                      ),
                      const SizedBox(height: 14),
                      PspOptionPicker(
                        label: 'Crop Uniformity',
                        required: !_isGuest,
                        options: pspScoreOpts,
                        value: _cropUniformity,
                        onChanged: (v) => _setValue(() => _cropUniformity = v),
                        accentColor: _kPspHarvest,
                      ),
                      const SizedBox(height: 14),
                      PspOptionPicker(
                        label: 'Crop Health',
                        required: !_isGuest,
                        options: pspScoreOpts,
                        value: _cropHealth,
                        onChanged: (v) => _setValue(() => _cropHealth = v),
                        accentColor: _kPspHarvest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDowngradeSection(),
                  const SizedBox(height: 12),
                  PspSection(
                    title: 'Final Flagging',
                    icon: Icons.flag_outlined,
                    color: const Color(0xFF42A5F5),
                    children: [
                      PspOptionPicker(
                        label: 'Final Flagging',
                        required: !_isGuest,
                        options: pspHarvestFinalFlaggingOpts,
                        value: _finalFlagging,
                        onChanged: (v) => _setValue(() => _finalFlagging = v),
                        accentColor: const Color(0xFF42A5F5),
                      ),
                      const SizedBox(height: 14),
                      PspTextField(
                        controller: _remarksCtrl,
                        label: 'Remarks',
                        maxLines: 4,
                        icon: Icons.edit_note_outlined,
                        accentColor: _kPspHarvest,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PspSaveBar(
            isSaving: _isSaving,
            isDiscard: false,
            saveLabel: _isGuest
                ? 'READ-ONLY - TIDAK DAPAT MENYIMPAN'
                : 'SIMPAN HARVEST PSP',
            onSave: _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _save,
          ),
        ],
      ),
    );
  }

  void _setValue(VoidCallback update) {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    setState(update);
  }

  Widget _buildDowngradeSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    const accent = Color(0xFFAB47BC);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _showDowngrade ? accent.withAlpha(150) : borderColor,
        ),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () {
              if (_isGuest) {
                GuestGuard.blockIfGuest(context, _session);
                return;
              }
              setState(() => _showDowngrade = !_showDowngrade);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.trending_down_outlined,
                      color: _showDowngrade ? accent : subColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DOWNGRADE FLAGGING',
                      style: AdvantaText.caption.copyWith(
                        color: _showDowngrade ? accent : subColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _showDowngrade,
                    activeThumbColor: accent,
                    onChanged: _isGuest
                        ? null
                        : (v) => setState(() => _showDowngrade = v),
                  ),
                ],
              ),
            ),
          ),
          if (_showDowngrade) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  PspDateTileNullable(
                    label: 'Tanggal Downgrade Flagging',
                    date: _downgradeFlagDate,
                    onTap: _pickDowngradeDate,
                    onClear: _isGuest
                        ? null
                        : () => setState(() => _downgradeFlagDate = null),
                  ),
                  const SizedBox(height: 14),
                  PspOptionPicker(
                    label: 'Downgrade Flagging',
                    required: !_isGuest,
                    options: pspHarvestStatusDowngradeOpts,
                    value: _statusDowngrade,
                    onChanged: (v) => _setValue(() => _statusDowngrade = v),
                    accentColor: accent,
                  ),
                  const SizedBox(height: 14),
                  PspOptionPickerLong(
                    label: 'Reason Downgrade',
                    required: !_isGuest,
                    options: pspHarvestReasonDowngradeOpts,
                    value: _reasonDowngrade,
                    onChanged: (v) => _setValue(() => _reasonDowngrade = v),
                    accentColor: accent,
                  ),
                  const SizedBox(height: 14),
                  PspOptionPicker(
                    label: 'Flagging Downgrade',
                    required: !_isGuest,
                    options: pspHarvestDowngradeFlaggingOpts,
                    value: _downgradeFlagging,
                    onChanged: (v) => _setValue(() => _downgradeFlagging = v),
                    accentColor: accent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
