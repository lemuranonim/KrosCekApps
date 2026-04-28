// lib/screens/inspection/form_generative_5_sc.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_generative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart';
import 'generative_form_widgets.dart';

const Color kGen5Color = Color(0xFFE53935); // Merah karena ini Final Audit

class FormGenerative5SC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative5SC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative5SC> createState() => _FormGenerative5SCState();
}

class _FormGenerative5SCState extends ConsumerState<FormGenerative5SC> {
  final _formKey           = GlobalKey<FormState>();
  bool _isSaving           = false;
  bool _dataLoaded         = false;
  ActiveSession? _session;

  final _qaFiCtrl          = TextEditingController();
  final _qaSpvCtrl         = TextEditingController();
  final _discardAreaCtrl   = TextEditingController();
  final _discardReasonCtrl = TextEditingController();

  DateTime _auditDate = DateTime.now();
  DateTime? _closedOutDate;

  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _detasseling;
  String? _isolationProblem;
  String? _affectedOther;
  String? _finalFlagging;
  String? _finalDecision;

  bool get _isGuest => GuestGuard.isGuest(_session);
  bool get _isDiscard => _finalDecision == 'D';

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
    _discardAreaCtrl.dispose();
    _discardReasonCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text           = audit['qa_fi_5'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text          = audit['qa_spv']  ?? '';
    _discardAreaCtrl.text    = audit['pld_area_ha_5']?.toString() ?? '';
    _discardReasonCtrl.text  = audit['pld_reason_5'] ?? '';

    if (audit['date_of_audit_5'] != null) {
      try { _auditDate = DateTime.parse(audit['date_of_audit_5']); } catch (_) {}
    }
    if (audit['closed_out_date_5'] != null) {
      try { _closedOutDate = DateTime.parse(audit['closed_out_date_5']); } catch (_) {}
    }

    setState(() {
      _femaleShed      = audit['female_shedding_5'];
      _offtypeM        = audit['offtype_m_5'];
      _offtypeF        = audit['offtype_f_5'];
      _lsv             = audit['lsv_status_5'];
      _cropUniformity  = audit['crop_uniformity_5'];
      _cropHealth      = audit['crop_health_5'];
      _detasseling     = audit['detasseling_assesment_5'];
      _isolationProblem= audit['isolation_problem_5'];
      _affectedOther   = audit['affected_other_field_5'];
      _finalFlagging   = audit['final_flagging_5'];
      _finalDecision   = audit['final_decision_5'];
    });
  }

  Future<void> _pickAuditDate() async {
    if (_isGuest) return;
    final p = await showDatePicker(
      context: context, initialDate: _auditDate,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _save() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final now  = DateTime.now();
      final data = {
        'field_number'            : widget.fieldNumber,
        'date_of_audit_5'         : DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_5'         : calcAuditWeek(_auditDate),
        'female_shedding_5'       : _femaleShed,
        'offtype_m_5'             : _offtypeM,
        'offtype_f_5'             : _offtypeF,
        'lsv_status_5'            : _lsv,
        'crop_uniformity_5'       : _cropUniformity,
        'crop_health_5'           : _cropHealth,
        'detasseling_assesment_5' : _detasseling,
        'isolation_problem_5'     : _isolationProblem,
        'affected_other_field_5'  : _affectedOther,
        'closed_out_date_5'       : _closedOutDate != null ? DateFormat('yyyy-MM-dd').format(_closedOutDate!) : null,
        'final_flagging_5'        : _finalFlagging,
        'final_decision_5'        : _finalDecision,
        'pld_area_ha_5'           : _isDiscard ? double.tryParse(_discardAreaCtrl.text.replaceAll(',', '.')) : null,
        'pld_reason_5'            : _isDiscard ? _discardReasonCtrl.text.trim() : null,
        'qa_fi_5'                 : _qaFiCtrl.text.trim(),
        'qa_spv'                  : _qaSpvCtrl.text.trim(),
        'submitted_at_5'          : now.toIso8601String(),
        'fase'                    : 'generative_5',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(fieldNumber: widget.fieldNumber, checkpoint: 5, data: data);

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        Navigator.pop(context);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(generativeAuditProvider(widget.fieldNumber));
    final fields     = ref.watch(masterFieldsProvider).value ?? [];
    final fd         = fields.firstWhere((f) => f['field_number'] == widget.fieldNumber, orElse: () => {});

    return Scaffold(
      appBar: GenAppBar(
        checkpointLabel: 'Audit 5 (SC) – Final Audit',
        fieldNumber: widget.fieldNumber, isDiscard: _isDiscard, accentColor: kGen5Color,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fd);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> fd) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GenFieldCard(fieldData: fd, accentColor: kGen5Color),
                  const SizedBox(height: 12),

                  // Gunakan UI yang persis sama dengan form_generative_3.dart lama,
                  // hanya saja pastikan mapping database JSON-nya menembak ke `_5` (seperti logika `_save()` di atas).
                  // ... (Isi UI Dropdown Final Decision, PLD Area, dll)

                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving: _isSaving, isDiscard: _isDiscard && !_isGuest,
            saveLabel: _isGuest ? 'READ-ONLY' : (_isDiscard ? 'SIMPAN — DISCARD' : 'SIMPAN GEN-5 (FINAL)'),
            onSave: _isGuest ? () => GuestGuard.blockIfGuest(context, _session) : _save,
          ),
        ],
      ),
    );
  }
}