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
import 'fc_form_widgets.dart';

const _kPspHarvest = Color(0xFF43A047);

const _earConditionOpts = [
  GenOpt('Stage 2', 'Stage 2'),
  GenOpt('Stage 3', 'Stage 3'),
  GenOpt('Stage 4', 'Stage 4'),
];

const _cropHealthOpts = [
  GenOpt('Very Poor', '1 - Very Poor'),
  GenOpt('Poor', '2 - Poor'),
  GenOpt('Fair', '3 - Fair'),
  GenOpt('Good', '4 - Good'),
  GenOpt('Best', '5 - Best'),
];

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
  String? _earCondition;
  String? _cropHealth;

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
      _cropHealth = audit?['crop_health']?.toString();
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
        data: genDatePickerTheme(ctx, _kPspHarvest),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _auditDate = picked);
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
        'crop_health': _cropHealth,
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
    final auditAsync = ref.watch(harvestAuditProvider(widget.fieldNumber));
    final fields = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData = fields.firstWhere(
      (f) => f['field_number'] == widget.fieldNumber,
      orElse: () => {},
    );

    return Scaffold(
      appBar: GenAppBar(
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
                  GenFieldCard(fieldData: fieldData, accentColor: _kPspHarvest),
                  const SizedBox(height: 14),
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: _kPspHarvest,
                    children: [
                      GenDateTile(
                        label: 'Date of Inspeksi Harvest',
                        date: _auditDate,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _qaFiCtrl,
                        label: 'QA FI',
                        required: !_isGuest,
                        icon: Icons.person_outline,
                        accentColor: _kPspHarvest,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: _kPspHarvest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GenSection(
                    title: 'Penilaian Harvest',
                    icon: Icons.agriculture_outlined,
                    color: _kPspHarvest,
                    children: [
                      GenOptionPicker(
                        label: 'Ear Condition',
                        required: !_isGuest,
                        options: _earConditionOpts,
                        value: _earCondition,
                        onChanged: (v) => _setValue(() => _earCondition = v),
                        accentColor: _kPspHarvest,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Crop Health',
                        required: !_isGuest,
                        options: _cropHealthOpts,
                        value: _cropHealth,
                        onChanged: (v) => _setValue(() => _cropHealth = v),
                        accentColor: _kPspHarvest,
                      ),
                      const SizedBox(height: 14),
                      GenTextField(
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
          GenSaveBar(
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
}
