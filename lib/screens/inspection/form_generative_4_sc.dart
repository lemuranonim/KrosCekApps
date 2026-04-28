// lib/screens/inspection/form_generative_4_sc.dart
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

// Gunakan warna ungu atau warna lain untuk CP4
const Color kGen4Color = Color(0xFF8E24AA);

class FormGenerative4SC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative4SC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative4SC> createState() => _FormGenerative4SCState();
}

class _FormGenerative4SCState extends ConsumerState<FormGenerative4SC> {
  final _formKey   = GlobalKey<FormState>();
  bool _isSaving   = false;
  bool _dataLoaded = false;
  ActiveSession? _session;

  final _qaFiCtrl  = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  DateTime _auditDate = DateTime.now();

  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _roguing;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _actionNeeded;

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
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text  = audit['qa_fi_4'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv']  ?? '';
    if (audit['date_of_audit_4'] != null) {
      try { _auditDate = DateTime.parse(audit['date_of_audit_4']); } catch (_) {}
    }
    setState(() {
      _femaleShed     = audit['female_shedding_4'];
      _offtypeM       = audit['offtype_m_4'];
      _offtypeF       = audit['offtype_f_4'];
      _roguing        = audit['roguing_status_4'];
      _lsv            = audit['lsv_status_4'];
      _cropUniformity = audit['crop_uniformity_4'];
      _cropHealth     = audit['crop_health_4'];
      _actionNeeded   = audit['action_needed_4'];
    });
  }

  Future<void> _pickDate() async {
    if (_isGuest) { GuestGuard.blockIfGuest(context, _session); return; }
    final p = await showDatePicker(
      context: context, initialDate: _auditDate,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: genDatePickerTheme(ctx, kGen4Color), child: child!),
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
        'field_number'      : widget.fieldNumber,
        'date_of_audit_4'   : DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_4'   : calcAuditWeek(_auditDate),
        'female_shedding_4' : _femaleShed,
        'offtype_m_4'       : _offtypeM,
        'offtype_f_4'       : _offtypeF,
        'roguing_status_4'  : _roguing,
        'lsv_status_4'      : _lsv,
        'crop_uniformity_4' : _cropUniformity,
        'crop_health_4'     : _cropHealth,
        'action_needed_4'   : _actionNeeded,
        'qa_fi_4'           : _qaFiCtrl.text.trim(),
        'qa_spv'            : _qaSpvCtrl.text.trim(),
        'submitted_at_4'    : now.toIso8601String(),
        'fase'              : 'generative_4',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(fieldNumber: widget.fieldNumber, checkpoint: 4, data: data);

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
        checkpointLabel: 'Audit 4 (SC) – Process Check',
        fieldNumber: widget.fieldNumber, isDiscard: false, accentColor: kGen4Color,
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
                  GenFieldCard(fieldData: fd, accentColor: kGen4Color),
                  const SizedBox(height: 12),
                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon:  Icons.assignment_outlined,
                    color: kGen2Color,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date:  _auditDate,
                          onTap: _pickDate),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller:  _qaFiCtrl,
                        label:       'QA FI',
                        hint:        'Nama QA Field Inspector',
                        required:    !_isGuest,
                        icon:        Icons.person_outline,
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller:  _qaSpvCtrl,
                        label:       'QA SPV',
                        hint:        'Nama QA Supervisor',
                        required:    !_isGuest,
                        icon:        Icons.supervisor_account_outlined,
                        accentColor: kGen2Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ... (Tambahkan widget dropdown untuk Female Shed, Offtype, LSV, dsb seperti di CP2)
                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving: _isSaving, isDiscard: false,
            saveLabel: _isGuest ? 'READ-ONLY' : 'SIMPAN GEN-4 (SC)',
            onSave: _isGuest ? () => GuestGuard.blockIfGuest(context, _session) : _save,
          ),
        ],
      ),
    );
  }
}