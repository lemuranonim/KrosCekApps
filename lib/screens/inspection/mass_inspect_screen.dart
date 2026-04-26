// lib/screens/inspection/mass_inspect_screen.dart
//
// MASS INSPECTION SCREEN — Bulk Insert / Update untuk semua fase audit
// Field-per-fase IDENTIK dengan form individual masing-masing fase:
//   • vegetative       → form_vegetative.dart
//   • generative_1     → form_generative_1.dart
//   • generative_2     → form_generative_2.dart
//   • generative_3     → form_generative_3.dart
//   • pre_harvest      → form_pre_harvest.dart
//   • harvest          → form_harvest.dart
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../theme/app_theme.dart';
import 'generative_form_widgets.dart';

// ─── Phase accent colors ──────────────────────────────────
const _kVeg  = Color(0xFF78909C);
const _kGen1 = Color(0xFFFFCA28);
const _kGen2 = Color(0xFFFF7043);
const _kGen3 = Color(0xFFE53935);
const _kPreH = Color(0xFF26C6DA);
const _kHarv = Color(0xFFFF7043);

// ─────────────────────────────────────────────────────────
// OPTION LISTS — identik dengan masing-masing form individu
// ─────────────────────────────────────────────────────────

// — Vegetative —
const _vegRoguingOpts = [
  GenOpt('A', 'A – Not Yet'), GenOpt('B', 'B – On Going'), GenOpt('C', 'C – Done'),
];
const _vegLsvOpts = [
  GenOpt('A', 'A – None'), GenOpt('B', 'B – Low'),
  GenOpt('C', 'C – Moderate'), GenOpt('D', 'D – High'),
];
const _vegCropCondOpts = [
  GenOpt('1', '1 – Very Poor'), GenOpt('2', '2 – Poor'), GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'), GenOpt('5', '5 – Best'),
];
const _vegOfftypeOpts  = [GenOpt('A', 'A – 0'), GenOpt('B', 'B – >0')];
const _vegIsolationOpts = [GenOpt('A', 'A – Yes'), GenOpt('B', 'B – No')];
const _vegPreviousCropOpts = [
  GenOpt('CAC', 'Corn After Corn'), GenOpt('NC', 'Not Corn'),
];
const _vegFinalDecisionOpts = [
  GenOpt('A', 'A – Pass'), GenOpt('B', 'B – Pass w/ Note'),
  GenOpt('C', 'C – Hold'), GenOpt('D', 'D – Discard'),
];
const _vegActionNeededOpts = [
  GenOpt('A', 'A – None'), GenOpt('B', 'B – Roguing'),
  GenOpt('C', 'C – Re-Detasseling'), GenOpt('D', 'D – Monitor'),
  GenOpt('E', 'E – Hold'), GenOpt('F', 'F – Discard Partial'),
  GenOpt('G', 'G – Discard Full'),
];
const _vegPldReasonOpts = [
  GenOpt('A', 'A – Poor Population'), GenOpt('B', 'B – Water Logging'),
  GenOpt('C', 'C – Pest/Disease Attack'), GenOpt('D', 'D – No Field'),
];
const _vegFinalFlaggingOpts = [
  GenOpt('GF', 'GF'), GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'), GenOpt('BF', 'BF'), GenOpt('PLD', 'PLD'),
];
const _vegMaleSplitOpts   = [GenOpt('Y', 'Y – Yes'), GenOpt('N', 'N – No')];
const _vegSplitFieldOpts  = [GenOpt('A', 'A – Yes'), GenOpt('B', 'B – No')];
const _vegYesNoOpts       = [GenOpt('Y', 'Y – Yes'), GenOpt('N', 'N – No')];
const _vegPoiAccuracyOpts = [GenOpt('Valid', 'Valid'), GenOpt('Not Valid', 'Not Valid')];

// — Generative shared —
const _genReadinessOpts = [
  GenOpt('A', 'A – 100%'), GenOpt('B', 'B – 75%'),
  GenOpt('C', 'C – 50%'), GenOpt('D', 'D – <25%'),
];
const _genRoguingOpts = [
  GenOpt('A', 'A – Not Yet'), GenOpt('B', 'B – On Going'), GenOpt('C', 'C – Done'),
];
const _genLsvOpts = [
  GenOpt('A', 'A – None'), GenOpt('B', 'B – Low'),
  GenOpt('C', 'C – Moderate'), GenOpt('D', 'D – High'),
];
const _genCropCondOpts = [
  GenOpt('1', '1 – Very Poor'), GenOpt('2', '2 – Poor'), GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'), GenOpt('5', '5 – Best'),
];
const _genOfftypeOpts = [
  GenOpt('A', 'A – 0%–1%'), GenOpt('B', 'B – 1%–3%'),
  GenOpt('C', 'C – 3%–5%'), GenOpt('D', 'D – >5%'),
];
const _genFemaleShedOpts = [
  GenOpt('A', 'A – 0%–10%'), GenOpt('B', 'B – 10%–30%'),
  GenOpt('C', 'C – 30%–50%'), GenOpt('D', 'D – >50%'),
];
const _genActionNeededOpts = [
  GenOpt('A', 'A – None'), GenOpt('B', 'B – Roguing'),
  GenOpt('C', 'C – Re-Detasseling'), GenOpt('D', 'D – Monitor'),
  GenOpt('E', 'E – Hold'), GenOpt('F', 'F – Discard Partial'),
  GenOpt('G', 'G – Discard Full'),
];
const _genFinalDecisionOpts = [
  GenOpt('A', 'A – Pass'), GenOpt('B', 'B – Pass w/ Note'),
  GenOpt('C', 'C – Hold'), GenOpt('D', 'D – Discard'),
];
const _genDetasselingOpts = [
  GenOpt('A', 'A – 0%–5%'), GenOpt('B', 'B – 5%–10%'),
  GenOpt('C', 'C – 10%–15%'), GenOpt('D', 'D – >15%'),
];
const _genIsolationOpts  = [GenOpt('A', 'A – Good'), GenOpt('B', 'B – Risky')];
const _genAffectedOpts   = [GenOpt('Y', 'Y – Yes'), GenOpt('N', 'N – No')];
const _genFlaggingOpts   = [
  GenOpt('GF', 'GF'), GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'), GenOpt('BF', 'BF'), GenOpt('PLD', 'PLD'),
];

// — Pre-Harvest —
const _preHMaleChoppingOpts = [
  GenOpt('A', 'A – Complete'), GenOpt('B', 'B – Not Complete'),
];
const _preHCropCondOpts = [
  GenOpt('1', '1 – Very Poor'), GenOpt('2', '2 – Poor'), GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'), GenOpt('5', '5 – Best'),
];
const _preHFinalFlaggingOpts = [
  GenOpt('GF', 'GF'), GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'), GenOpt('BF', 'BF'), GenOpt('PLD', 'PLD'),
];
const _preHFinalDecisionOpts = [
  GenOpt('A', 'A – Pass'), GenOpt('B', 'B – Pass w/ Note'),
  GenOpt('C', 'C – Hold'), GenOpt('D', 'D – Discard'),
];

// — Harvest —
const _harvEarCondOpts = [
  GenOpt('2', 'Stage 2'), GenOpt('3', 'Stage 3'), GenOpt('4', 'Stage 4'),
];
const _harvCropCondOpts = [
  GenOpt('1', '1 – Very Poor'), GenOpt('2', '2 – Poor'), GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'), GenOpt('5', '5 – Best'),
];
const _harvReasonDowngradeOpts = [
  GenOpt('A', 'A – Suspect Mix Material'),
  GenOpt('B', 'B – Not Accessible during Detasseling'),
  GenOpt('C', 'C – Not Sure during Harvest'),
];
const _harvStatusDowngradeOpts   = [GenOpt('A', 'A – Yes'), GenOpt('B', 'B – No')];
const _harvDowngradeFlaggingOpts = [GenOpt('RFI', 'RFI'), GenOpt('RFD', 'RFD')];
const _harvFinalFlaggingOpts     = [
  GenOpt('GF', 'GF'), GenOpt('RFI', 'RFI'), GenOpt('RFD', 'RFD'), GenOpt('BF', 'BF'),
];

// ─────────────────────────────────────────────────────────
class MassInspectScreen extends ConsumerStatefulWidget {
  final List<String> fieldNumbers;
  final String targetPhase;
  const MassInspectScreen({
    super.key,
    required this.fieldNumbers,
    required this.targetPhase,
  });

  @override
  ConsumerState<MassInspectScreen> createState() => _MassInspectScreenState();
}

class _MassInspectScreenState extends ConsumerState<MassInspectScreen> {
  final _formKey  = GlobalKey<FormState>();
  bool  _isSaving = false;
  DateTime _auditDate = DateTime.now();

  // ── Common ────────────────────────────────────────────────
  final _qaFiCtrl  = TextEditingController();
  final _qaSpvCtrl = TextEditingController();

  // ── Vegetative ────────────────────────────────────────────
  final _vegSowingRatioFCtrl  = TextEditingController();
  final _vegSowingRatioMCtrl  = TextEditingController();
  final _vegCoDetasselingCtrl = TextEditingController();
  final _vegRemarksCtrl       = TextEditingController();
  String? _vegPreviousCrop, _vegMaleSplit, _vegSplitField, _vegOneSeedPerHole;
  String? _vegIsolationProblem, _vegCropCondition, _vegRoguingStatus, _vegLsvStatus;
  String? _vegOfftypeM, _vegOfftypeF, _vegPoiAccuracy;
  String? _vegFinalDecision, _vegActionNeeded, _vegPldReason, _vegFinalFlagging;

  // ── Generative 1 ──────────────────────────────────────────
  String? _gen1Readiness, _gen1Roguing, _gen1Lsv, _gen1CropCond, _gen1ActionNeeded;

  // ── Generative 2 ──────────────────────────────────────────
  String? _gen2FemaleShed, _gen2OfftypeM, _gen2OfftypeF;
  String? _gen2Lsv, _gen2CropCond, _gen2ActionNeeded;

  // ── Generative 3 ──────────────────────────────────────────
  final _gen3DiscardAreaCtrl   = TextEditingController();
  final _gen3DiscardReasonCtrl = TextEditingController();
  DateTime? _gen3ClosedOutDate;
  String? _gen3FemaleShed, _gen3OfftypeM, _gen3OfftypeF;
  String? _gen3Lsv, _gen3CropCond, _gen3Detasseling;
  String? _gen3IsolationStatus, _gen3AffectedOther, _gen3Flagging, _gen3FinalDecision;

  // ── Pre-Harvest ───────────────────────────────────────────
  final _preHDiscardAreaCtrl   = TextEditingController();
  final _preHDiscardReasonCtrl = TextEditingController();
  String? _preHMaleChopping, _preHCropCondition, _preHFinalFlagging, _preHFinalDecision;

  // ── Harvest ───────────────────────────────────────────────
  DateTime? _harvDowngradeFlagDate;
  bool      _harvShowDowngrade = false;
  String? _harvEarCondition, _harvCropCondition;
  String? _harvStatusDowngrade, _harvReasonDowngrade, _harvDowngradeFlagging, _harvFinalFlagging;

  // ── Helpers ───────────────────────────────────────────────
  Color get _phaseColor {
    switch (widget.targetPhase) {
      case 'vegetative'  : return _kVeg;
      case 'generative_1': return _kGen1;
      case 'generative_2': return _kGen2;
      case 'generative_3': return _kGen3;
      case 'pre_harvest' : return _kPreH;
      case 'harvest'     : return _kHarv;
      default            : return AdvantaColors.mutedGrey;
    }
  }

  String get _phaseLabel {
    switch (widget.targetPhase) {
      case 'vegetative'  : return 'Vegetative Audit';
      case 'generative_1': return 'Generative Audit 1 – Readiness';
      case 'generative_2': return 'Generative Audit 2 – Process';
      case 'generative_3': return 'Generative Audit 3 – Final';
      case 'pre_harvest' : return 'Pre-Harvest Audit';
      case 'harvest'     : return 'Harvest Audit';
      default            : return widget.targetPhase.replaceAll('_', ' ').toUpperCase();
    }
  }

  bool get _isDiscard {
    switch (widget.targetPhase) {
      case 'vegetative'  : return _vegFinalDecision == 'D';
      case 'generative_1': return _gen1ActionNeeded == 'G';
      case 'generative_2': return _gen2ActionNeeded == 'G';
      case 'generative_3': return _gen3FinalDecision == 'D';
      case 'pre_harvest' : return _preHFinalDecision == 'D';
      default            : return false;
    }
  }

  @override
  void dispose() {
    _qaFiCtrl.dispose(); _qaSpvCtrl.dispose();
    _vegSowingRatioFCtrl.dispose();
    _vegSowingRatioMCtrl.dispose(); _vegCoDetasselingCtrl.dispose();
    _vegRemarksCtrl.dispose();
    _gen3DiscardAreaCtrl.dispose(); _gen3DiscardReasonCtrl.dispose();
    _preHDiscardAreaCtrl.dispose(); _preHDiscardReasonCtrl.dispose();
    super.dispose();
  }

  // ─── Date pickers ─────────────────────────────────────────
  Future<void> _pickAuditDate() async {
    final p = await showDatePicker(
      context: context, initialDate: _auditDate,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _phaseColor), child: child!),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _pickGen3ClosedDate() async {
    final p = await showDatePicker(
      context: context, initialDate: _gen3ClosedOutDate ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kGen3), child: child!),
    );
    if (p != null) setState(() => _gen3ClosedOutDate = p);
  }

  Future<void> _pickHarvDowngradeDate() async {
    final p = await showDatePicker(
      context: context, initialDate: _harvDowngradeFlagDate ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kHarv), child: child!),
    );
    if (p != null) setState(() => _harvDowngradeFlagDate = p);
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg, style: AdvantaText.body2.copyWith(color: Colors.white)),
      backgroundColor: err ? AdvantaColors.error : AdvantaColors.success,
      behavior       : SnackBarBehavior.floating,
      shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin         : const EdgeInsets.all(12),
    ));
  }

  // ─── SUBMIT ──────────────────────────────────────────────
  Future<void> _submitBulk(List<Map<String, dynamic>> selectedFields) async {
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_auditDate);
      final week    = calcAuditWeek(_auditDate);
      final nowStr  = DateTime.now().toIso8601String();
      final records = <Map<String, dynamic>>[];

      for (final field in selectedFields) {
        final fn = field['field_number'] as String;
        final Map<String, dynamic> rec = {
          'field_number'  : fn,
          'is_mass_submit': true,
        };

        switch (widget.targetPhase) {
          case 'vegetative':
          // Ambil effective_area_ha dari data lahan saat ini
            final rawArea = field['effective_area_ha'];
            final effectiveArea = rawArea is num
                ? rawArea.toDouble()
                : double.tryParse(rawArea?.toString() ?? '');

            rec.addAll({
              'audit_date_user'           : dateStr,
              'date_of_audit'             : dateStr,
              'audit_week'                : week,
              'qa_fi'                     : _qaFiCtrl.text.trim(),
              'qa_spv'                    : _qaSpvCtrl.text.trim(),
              'co_detasseling'            : _vegCoDetasselingCtrl.text.trim(),

              // UBAH: Gunakan effectiveArea dari database
              'field_size_by_audit_ha'    : effectiveArea,

              'male_split_by_audit'       : _vegMaleSplit,
              'sowing_ratio_by_audit'     :
              '${_vegSowingRatioFCtrl.text.trim()}:${_vegSowingRatioMCtrl.text.trim()}',
              'split_field_by_audit'      : _vegSplitField,
              'previous_crop_by_audit'    : _vegPreviousCrop,
              'one_seed_per_hole'         : _vegOneSeedPerHole,
              'isolation_problem_by_audit': _vegIsolationProblem,
              'crop_condition'            : _vegCropCondition,
              'roguing_status'            : _vegRoguingStatus,
              'lsv_status'                : _vegLsvStatus,
              'offtype_in_male'           : _vegOfftypeM,
              'offtype_in_female'         : _vegOfftypeF,
              'poi_accuracy'              : _vegPoiAccuracy,
              'final_decision'            : _vegFinalDecision,
              'action_needed'             : _vegActionNeeded,
              'pld_reason'                : _vegFinalDecision == 'D' ? _vegPldReason : null,
              'final_flagging'            : _vegFinalFlagging,
              'remarks'                   : _vegRemarksCtrl.text.trim(),
              'fase'                      : 'vegetative',
              'updated_at'                : nowStr,
            });

          case 'generative_1':
            rec.addAll({
              'date_of_audit_1'   : dateStr,
              'week_of_audit_1'   : week,
              'qa_fi_1'           : _qaFiCtrl.text.trim(),
              'qa_spv'            : _qaSpvCtrl.text.trim(),
              'readiness_status_1': _gen1Readiness,
              'roguing_status_1'  : _gen1Roguing,
              'lsv_status_1'      : _gen1Lsv,
              'crop_condition_1'  : _gen1CropCond,
              'action_needed_1'   : _gen1ActionNeeded,
              'submitted_at_1'    : nowStr,
              'fase'              : 'generative_1',
              'is_mass_submit_1'  : true,
            });

          case 'generative_2':
            rec.addAll({
              'date_of_audit_2'  : dateStr,
              'week_of_audit_2'  : week,
              'qa_fi_2'          : _qaFiCtrl.text.trim(),
              'qa_spv'           : _qaSpvCtrl.text.trim(),
              'female_shedding_2': _gen2FemaleShed,
              'offtype_m_2'      : _gen2OfftypeM,
              'offtype_f_2'      : _gen2OfftypeF,
              'lsv_status_2'     : _gen2Lsv,
              'crop_condition_2' : _gen2CropCond,
              'action_needed_2'  : _gen2ActionNeeded,
              'submitted_at_2'   : nowStr,
              'fase'             : 'generative_2',
              'is_mass_submit_2' : true,
            });

          case 'generative_3':
            final isD3 = _gen3FinalDecision == 'D';
            rec.addAll({
              'date_of_audit_3'        : dateStr,
              'week_of_audit_3'        : week,
              'qa_fi_3'                : _qaFiCtrl.text.trim(),
              'qa_spv'                 : _qaSpvCtrl.text.trim(),
              'female_shedding_3'      : _gen3FemaleShed,
              'offtype_m_3'            : _gen3OfftypeM,
              'offtype_f_3'            : _gen3OfftypeF,
              'lsv_status_3'           : _gen3Lsv,
              'crop_condition_3'       : _gen3CropCond,
              'detasseling_assesment_3': _gen3Detasseling,
              'isolation_status_3'     : _gen3IsolationStatus,
              'affected_other_field_3' : _gen3AffectedOther,
              'closed_out_date'        : _gen3ClosedOutDate != null
                  ? DateFormat('yyyy-MM-dd').format(_gen3ClosedOutDate!) : null,
              'flagging'               : _gen3Flagging,
              'final_decision_3'       : _gen3FinalDecision,
              'action_needed_3'        : isD3 ? 'G' : 'A',
              'discard_area_ha_3'      : isD3
                  ? double.tryParse(_gen3DiscardAreaCtrl.text.replaceAll(',', '.')) : null,
              'discard_reason_3'       : isD3 ? _gen3DiscardReasonCtrl.text.trim() : null,
              'submitted_at_3'         : nowStr,
              'fase'                   : 'generative_3',
              'is_mass_submit_3'       : true,
            });

          case 'pre_harvest':
            final isDPH = _preHFinalDecision == 'D';
            rec.addAll({
              'audit_date'      : dateStr,
              'audit_week'      : week,
              'qa_fi'           : _qaFiCtrl.text.trim(),
              'qa_spv'          : _qaSpvCtrl.text.trim(),
              'male_chopping_rows': _preHMaleChopping,
              'crop_condition'  : _preHCropCondition,
              'final_flagging'  : _preHFinalFlagging,
              'final_decision'  : _preHFinalDecision,
              'discard_area_ha' : isDPH
                  ? double.tryParse(_preHDiscardAreaCtrl.text.replaceAll(',', '.')) : null,
              'discard_reason'  : isDPH ? _preHDiscardReasonCtrl.text.trim() : null,
              'fase'            : 'Pre-Harvest',
              'updated_at'      : nowStr,
            });

          case 'harvest':
            rec.addAll({
              'date_of_audit'              : dateStr,
              'audit_week'                 : week,
              'qa_fi'                      : _qaFiCtrl.text.trim(),
              'qa_spv'                     : _qaSpvCtrl.text.trim(),
              'ear_condition_observation'  : _harvEarCondition,
              'crop_condition'             : _harvCropCondition,
              'status_downgrade'           : _harvShowDowngrade ? _harvStatusDowngrade : null,
              'reason_downgrade'           : _harvShowDowngrade ? _harvReasonDowngrade : null,
              'downgrade_flagging'         : _harvShowDowngrade ? _harvDowngradeFlagging : null,
              'date_of_downgrade_flagging' : _harvShowDowngrade && _harvDowngradeFlagDate != null
                  ? DateFormat('yyyy-MM-dd').format(_harvDowngradeFlagDate!) : null,
              'final_flagging'             : _harvFinalFlagging,
              'fase'                       : 'Harvest',
              'updated_at'                 : nowStr,
            });
        }
        records.add(rec);
      }

      final service = ref.read(supabaseServiceProvider);
      await service.bulkUpsertInspection(phase: widget.targetPhase, records: records);

      final att = ref.read(attendanceProvider);
      if (att.isCheckedIn && att.attendanceId != null) {
        double lat = 0, lng = 0;
        try {
          final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
          lat = pos.latitude; lng = pos.longitude;
        } catch (_) {}
        for (final field in selectedFields) {
          await service.logActivity(
            attendanceId: att.attendanceId!,
            userId      : _qaFiCtrl.text.trim().isNotEmpty
                ? _qaFiCtrl.text.trim() : 'unknown',
            fieldNumber : field['field_number'],
            phase       : widget.targetPhase,
            actionType  : 'mass_submit',
            lat: lat, lng: lng,
          );
        }
      }

      if (mounted) {
        _snack('Bulk Submit ${records.length} field berhasil ✓');
        ref.invalidate(masterFieldsProvider);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Gagal bulk submit: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final masterAsync = ref.watch(masterFieldsProvider);

    return Scaffold(
      backgroundColor: isDark ? AdvantaColors.deepForest : AdvantaColors.softGrey,
      appBar          : _buildAppBar(context),
      body            : masterAsync.when(
        data   : (allFields) {
          final selected = allFields
              .where((f) => widget.fieldNumbers.contains(f['field_number']))
              .toList();
          return _buildForm(context, selected);
        },
        loading: () => Center(child: CircularProgressIndicator(color: _phaseColor)),
        error  : (e, _) => Center(
          child: Text('Error: $e',
              style: AdvantaText.body2.copyWith(
                  color: Theme.of(context).colorScheme.error)),
        ),
      ),
    );
  }

  // ─── APP BAR ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final appBarBg  = _isDiscard
        ? const Color(0xFF7B1821)
        : (isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen);
    final iconColor = isDark ? AdvantaColors.goldLight : Colors.white;
    final divColor  = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);

    return AppBar(
      backgroundColor  : appBarBg,
      surfaceTintColor : Colors.transparent,
      elevation        : 0,
      leading          : IconButton(
        icon     : Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mass Inspection',
              style: AdvantaText.caption.copyWith(
                color     : _isDiscard ? const Color(0xFFFF8A80) : _phaseColor,
                fontWeight: FontWeight.w500,
              )),
          Text(_phaseLabel,
              style: AdvantaText.heading2.copyWith(color: iconColor)),
        ],
      ),
      actions: [
        if (_isDiscard)
          Container(
            margin    : const EdgeInsets.only(right: 16),
            padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color       : AdvantaColors.error.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
              border      : Border.all(color: AdvantaColors.error.withAlpha(128)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8A80), size: 14),
              SizedBox(width: 4),
              Text('DISCARD', style: TextStyle(
                  color: Color(0xFFFF8A80), fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ]),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: divColor),
      ),
    );
  }

  // ─── FORM BODY ───────────────────────────────────────────
  Widget _buildForm(BuildContext context, List<Map<String, dynamic>> selectedFields) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final divColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);

    return Form(
      key : _formKey,
      child: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color  : _phaseColor.withAlpha(26),
            child  : Row(
              children: [
                Icon(Icons.info_outline, color: _phaseColor, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mengisi data sekaligus untuk ${selectedFields.length} field terpilih.',
                    style: AdvantaText.body2.copyWith(
                        color: _phaseColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: divColor),

          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Common: Informasi Audit ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon : Icons.assignment_outlined,
                    color: _phaseColor,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit', date: _auditDate, onTap: _pickAuditDate),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _qaFiCtrl, label: 'QA FI',
                        hint: 'Nama QA Field Inspector', required: true,
                        icon: Icons.person_outline, accentColor: _phaseColor,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _qaSpvCtrl, label: 'QA SPV',
                        hint: 'Nama QA Supervisor', required: true,
                        icon: Icons.supervisor_account_outlined, accentColor: _phaseColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Phase-specific ──
                  ..._buildPhaseFields(context),

                  const SizedBox(height: 12),

                  // ── Field Terpilih ──
                  GenSection(
                    title: 'Field Terpilih (${selectedFields.length})',
                    icon : Icons.crop_square_rounded,
                    color: AdvantaColors.mutedGrey,
                    children: selectedFields.isEmpty
                        ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Tidak ada field terpilih.',
                            style: AdvantaText.body2.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha(128))),
                      ),
                    ]
                        : selectedFields.map((f) => _FieldChip(
                      fieldData  : f,
                      accentColor: _phaseColor,
                      onRemove   : () => setState(
                              () => widget.fieldNumbers.remove(f['field_number'])),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

          _buildSaveBar(context, selectedFields),
        ],
      ),
    );
  }

  // ─── PHASE FIELD ROUTER ───────────────────────────────────
  List<Widget> _buildPhaseFields(BuildContext context) {
    switch (widget.targetPhase) {
      case 'vegetative'  : return _buildVegetativeFields(context);
      case 'generative_1': return _buildGen1Fields();
      case 'generative_2': return _buildGen2Fields();
      case 'generative_3': return _buildGen3Fields(context);
      case 'pre_harvest' : return _buildPreHarvestFields();
      case 'harvest'     : return _buildHarvestFields(context);
      default            : return [];
    }
  }

  // ── VEGETATIVE ────────────────────────────────────────────
  List<Widget> _buildVegetativeFields(BuildContext context) {
    final isD = _vegFinalDecision == 'D';
    return [
      GenSection(
        title: 'Kondisi Lahan',
        icon : Icons.landscape_outlined,
        color: const Color(0xFF26A69A),
        children: [
          GenOptionPicker(
            label: 'Male Split', required: !isD,
            options: _vegMaleSplitOpts, value: _vegMaleSplit,
            onChanged: (v) => setState(() => _vegMaleSplit = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          _buildSowingRatio(context, isD),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Split Field', required: !isD,
            options: _vegSplitFieldOpts, value: _vegSplitField,
            onChanged: (v) => setState(() => _vegSplitField = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Previous Crop', required: !isD,
            options: _vegPreviousCropOpts, value: _vegPreviousCrop,
            onChanged: (v) => setState(() => _vegPreviousCrop = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'One Seed / Hole', required: !isD,
            options: _vegYesNoOpts, value: _vegOneSeedPerHole,
            onChanged: (v) => setState(() => _vegOneSeedPerHole = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenTextField(
            controller: _vegCoDetasselingCtrl, label: 'Co Detasseling',
            hint: 'Nama Co Detasseling',
            icon: Icons.group_outlined, accentColor: const Color(0xFF26A69A),
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Penilaian Audit',
        icon : Icons.assessment_outlined,
        color: const Color(0xFFFFCA28),
        children: [
          GenOptionPicker(
            label: 'Crop Condition', required: !isD,
            options: _vegCropCondOpts, value: _vegCropCondition,
            onChanged: (v) => setState(() => _vegCropCondition = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Roguing Status', required: !isD,
            options: _vegRoguingOpts, value: _vegRoguingStatus,
            onChanged: (v) => setState(() => _vegRoguingStatus = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status', required: !isD,
            options: _vegLsvOpts, value: _vegLsvStatus,
            onChanged: (v) => setState(() => _vegLsvStatus = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Isolation Problem', required: !isD,
            options: _vegIsolationOpts, value: _vegIsolationProblem,
            onChanged: (v) => setState(() => _vegIsolationProblem = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M', required: !isD,
                  options: _vegOfftypeOpts, value: _vegOfftypeM,
                  onChanged: (v) => setState(() => _vegOfftypeM = v),
                  accentColor: const Color(0xFFFFCA28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F', required: !isD,
                  options: _vegOfftypeOpts, value: _vegOfftypeF,
                  onChanged: (v) => setState(() => _vegOfftypeF = v),
                  accentColor: const Color(0xFFFFCA28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'POI Accuracy', required: !isD,
            options: _vegPoiAccuracyOpts, value: _vegPoiAccuracy,
            onChanged: (v) => setState(() => _vegPoiAccuracy = v),
            accentColor: const Color(0xFFFFCA28),
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Keputusan',
        icon : Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPicker(
            label: 'Final Decision', required: true,
            options: _vegFinalDecisionOpts, value: _vegFinalDecision,
            onChanged: (v) => setState(() {
              _vegFinalDecision = v;
              if (v != 'D') _vegPldReason = null;
            }),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message: 'Mode Discard aktif — pastikan PLD Reason terisi sebelum menyimpan.',
            ),
            const SizedBox(height: 14),
            GenOptionPicker(
              label: 'PLD Reason', required: true,
              options: _vegPldReasonOpts, value: _vegPldReason,
              onChanged: (v) => setState(() => _vegPldReason = v),
              accentColor: AdvantaColors.error,
            ),
          ],
          const SizedBox(height: 14),
          GenOptionPickerLong(
            label: 'Action Needed',
            options: _vegActionNeededOpts, value: _vegActionNeeded,
            onChanged: (v) => setState(() => _vegActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Final Flagging',
            options: _vegFinalFlaggingOpts, value: _vegFinalFlagging,
            onChanged: (v) => setState(() => _vegFinalFlagging = v),
            accentColor: AdvantaColors.error,
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Catatan',
        icon : Icons.notes_outlined,
        color: AdvantaColors.mutedGrey,
        children: [
          GenTextField(
            controller: _vegRemarksCtrl, label: 'Remarks',
            hint: 'Catatan tambahan di lapangan...',
            maxLines: 4, icon: Icons.edit_note_outlined,
            accentColor: AdvantaColors.mutedGrey,
          ),
        ],
      ),
    ];
  }

  Widget _buildSowingRatio(BuildContext context, bool isDiscard) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final subColor    = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor   = isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
    final borderColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);

    InputDecoration decor(String lbl) => InputDecoration(
      labelText: lbl, labelStyle: TextStyle(color: subColor, fontSize: 12),
      filled: true, fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF26A69A), width: 1.5)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sowing Ratio (F:M)',
            style: AdvantaText.label.copyWith(color: subColor)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _vegSowingRatioFCtrl,
                keyboardType: TextInputType.number,
                decoration: decor('Female'),
                validator: isDiscard ? null :
                    (v) => (v == null || v.trim().isEmpty) ? 'Wajib' : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(':', style: AdvantaText.heading2.copyWith(color: subColor)),
            ),
            Expanded(
              child: TextFormField(
                controller: _vegSowingRatioMCtrl,
                keyboardType: TextInputType.number,
                decoration: decor('Male'),
                validator: isDiscard ? null :
                    (v) => (v == null || v.trim().isEmpty) ? 'Wajib' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── GENERATIVE 1 ──────────────────────────────────────────
  List<Widget> _buildGen1Fields() {
    final isD = _gen1ActionNeeded == 'G';
    return [
      GenSection(
        title: 'Penilaian Readiness',
        icon : Icons.checklist_outlined,
        color: _kGen1,
        children: [
          GenOptionPicker(
            label: 'Readiness Status', required: !isD,
            options: _genReadinessOpts, value: _gen1Readiness,
            onChanged: (v) => setState(() => _gen1Readiness = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Roguing Status', required: !isD,
            options: _genRoguingOpts, value: _gen1Roguing,
            onChanged: (v) => setState(() => _gen1Roguing = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status', required: !isD,
            options: _genLsvOpts, value: _gen1Lsv,
            onChanged: (v) => setState(() => _gen1Lsv = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Condition', required: !isD,
            options: _genCropCondOpts, value: _gen1CropCond,
            onChanged: (v) => setState(() => _gen1CropCond = v),
            accentColor: _kGen1,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Action Needed',
        icon : Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPickerLong(
            label: 'Action Needed', required: true,
            options: _genActionNeededOpts, value: _gen1ActionNeeded,
            onChanged: (v) => setState(() => _gen1ActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message: 'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
            ),
          ],
        ],
      ),
    ];
  }

  // ── GENERATIVE 2 ──────────────────────────────────────────
  List<Widget> _buildGen2Fields() {
    final isD = _gen2ActionNeeded == 'G';
    return [
      GenSection(
        title: 'Penilaian Process',
        icon : Icons.grass_outlined,
        color: _kGen2,
        children: [
          GenOptionPicker(
            label: 'Female Shedding', required: !isD,
            options: _genFemaleShedOpts, value: _gen2FemaleShed,
            onChanged: (v) => setState(() => _gen2FemaleShed = v),
            accentColor: _kGen2,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M', required: !isD,
                  options: _genOfftypeOpts, value: _gen2OfftypeM,
                  onChanged: (v) => setState(() => _gen2OfftypeM = v),
                  accentColor: _kGen2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F', required: !isD,
                  options: _genOfftypeOpts, value: _gen2OfftypeF,
                  onChanged: (v) => setState(() => _gen2OfftypeF = v),
                  accentColor: _kGen2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status', required: !isD,
            options: _genLsvOpts, value: _gen2Lsv,
            onChanged: (v) => setState(() => _gen2Lsv = v),
            accentColor: _kGen2,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Condition', required: !isD,
            options: _genCropCondOpts, value: _gen2CropCond,
            onChanged: (v) => setState(() => _gen2CropCond = v),
            accentColor: _kGen2,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Action Needed',
        icon : Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPickerLong(
            label: 'Action Needed', required: true,
            options: _genActionNeededOpts, value: _gen2ActionNeeded,
            onChanged: (v) => setState(() => _gen2ActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message: 'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
            ),
          ],
        ],
      ),
    ];
  }

  // ── GENERATIVE 3 ──────────────────────────────────────────
  List<Widget> _buildGen3Fields(BuildContext context) {
    final isD = _gen3FinalDecision == 'D';
    return [
      GenSection(
        title: 'Penilaian Final',
        icon : Icons.grass_outlined,
        color: _kGen3,
        children: [
          GenOptionPicker(
            label: 'Female Shedding', required: !isD,
            options: _genFemaleShedOpts, value: _gen3FemaleShed,
            onChanged: (v) => setState(() => _gen3FemaleShed = v),
            accentColor: _kGen3,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M', required: !isD,
                  options: _genOfftypeOpts, value: _gen3OfftypeM,
                  onChanged: (v) => setState(() => _gen3OfftypeM = v),
                  accentColor: _kGen3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F', required: !isD,
                  options: _genOfftypeOpts, value: _gen3OfftypeF,
                  onChanged: (v) => setState(() => _gen3OfftypeF = v),
                  accentColor: _kGen3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status', required: !isD,
            options: _genLsvOpts, value: _gen3Lsv,
            onChanged: (v) => setState(() => _gen3Lsv = v),
            accentColor: _kGen3,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Condition', required: !isD,
            options: _genCropCondOpts, value: _gen3CropCond,
            onChanged: (v) => setState(() => _gen3CropCond = v),
            accentColor: _kGen3,
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Detasseling & Isolasi',
        icon : Icons.agriculture_outlined,
        color: const Color(0xFFAB47BC),
        children: [
          GenOptionPicker(
            label: 'Detasseling Assessment', required: !isD,
            options: _genDetasselingOpts, value: _gen3Detasseling,
            onChanged: (v) => setState(() => _gen3Detasseling = v),
            accentColor: const Color(0xFFAB47BC),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Isolation Status',
                  options: _genIsolationOpts, value: _gen3IsolationStatus,
                  onChanged: (v) => setState(() => _gen3IsolationStatus = v),
                  accentColor: const Color(0xFFAB47BC),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Affected Other Field',
                  options: _genAffectedOpts, value: _gen3AffectedOther,
                  onChanged: (v) => setState(() => _gen3AffectedOther = v),
                  accentColor: const Color(0xFFAB47BC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenDateTileNullable(
            label  : 'Closed Out Date (Opsional)',
            date   : _gen3ClosedOutDate,
            onTap  : _pickGen3ClosedDate,
            onClear: () => setState(() => _gen3ClosedOutDate = null),
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Flagging',
        icon : Icons.flag_outlined,
        color: const Color(0xFF42A5F5),
        children: [
          GenOptionPicker(
            label: 'Flagging',
            options: _genFlaggingOpts, value: _gen3Flagging,
            onChanged: (v) => setState(() => _gen3Flagging = v),
            accentColor: const Color(0xFF42A5F5),
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Keputusan Final',
        icon : Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPicker(
            label: 'Final Decision', required: true,
            options: _genFinalDecisionOpts, value: _gen3FinalDecision,
            onChanged: (v) => setState(() {
              _gen3FinalDecision = v;
              if (v != 'D') {
                _gen3DiscardAreaCtrl.clear();
                _gen3DiscardReasonCtrl.clear();
              }
            }),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 14),
            const GenDiscardBanner(
              message: 'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
            ),
            const SizedBox(height: 14),
            GenTextField(
              controller: _gen3DiscardAreaCtrl, label: 'Discard Area (Ha)',
              hint: 'Luas area discard', required: true,
              keyboardType: TextInputType.number,
              icon: Icons.crop_landscape_outlined, accentColor: AdvantaColors.error,
            ),
            const SizedBox(height: 12),
            GenTextField(
              controller: _gen3DiscardReasonCtrl, label: 'Discard Reason',
              hint: 'Alasan discard...', required: true,
              maxLines: 3, icon: Icons.notes_outlined, accentColor: AdvantaColors.error,
            ),
          ],
        ],
      ),
    ];
  }

  // ── PRE-HARVEST ───────────────────────────────────────────
  List<Widget> _buildPreHarvestFields() {
    final isD = _preHFinalDecision == 'D';
    return [
      GenSection(
        title: 'Penilaian Pre-Harvest',
        icon : Icons.checklist_outlined,
        color: _kPreH,
        children: [
          GenOptionPicker(
            label: 'Male Chopping (Rows)', required: !isD,
            options: _preHMaleChoppingOpts, value: _preHMaleChopping,
            onChanged: (v) => setState(() => _preHMaleChopping = v),
            accentColor: _kPreH,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Condition', required: !isD,
            options: _preHCropCondOpts, value: _preHCropCondition,
            onChanged: (v) => setState(() => _preHCropCondition = v),
            accentColor: _kPreH,
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Flagging',
        icon : Icons.flag_outlined,
        color: const Color(0xFF42A5F5),
        children: [
          GenOptionPicker(
            label: 'Final Flagging',
            options: _preHFinalFlaggingOpts, value: _preHFinalFlagging,
            onChanged: (v) => setState(() => _preHFinalFlagging = v),
            accentColor: const Color(0xFF42A5F5),
          ),
        ],
      ),
      const SizedBox(height: 12),

      GenSection(
        title: 'Keputusan Final',
        icon : Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPicker(
            label: 'Final Decision', required: true,
            options: _preHFinalDecisionOpts, value: _preHFinalDecision,
            onChanged: (v) => setState(() {
              _preHFinalDecision = v;
              if (v != 'D') {
                _preHDiscardAreaCtrl.clear();
                _preHDiscardReasonCtrl.clear();
              }
            }),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message: 'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
            ),
            const SizedBox(height: 14),
            GenTextField(
              controller: _preHDiscardAreaCtrl, label: 'Discard Area (Ha)',
              hint: 'Luas area discard', required: true,
              keyboardType: TextInputType.number,
              icon: Icons.crop_landscape_outlined, accentColor: AdvantaColors.error,
            ),
            const SizedBox(height: 12),
            GenTextField(
              controller: _preHDiscardReasonCtrl, label: 'Discard Reason',
              hint: 'Alasan discard...', required: true,
              maxLines: 3, icon: Icons.notes_outlined, accentColor: AdvantaColors.error,
            ),
          ],
        ],
      ),
    ];
  }

  // ── HARVEST ───────────────────────────────────────────────
  List<Widget> _buildHarvestFields(BuildContext context) {
    return [
      GenSection(
        title: 'Penilaian Harvest',
        icon : Icons.agriculture_outlined,
        color: _kHarv,
        children: [
          GenOptionPicker(
            label: 'Ear Condition (Maturity)', required: true,
            options: _harvEarCondOpts, value: _harvEarCondition,
            onChanged: (v) => setState(() => _harvEarCondition = v),
            accentColor: _kHarv,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Condition', required: true,
            options: _harvCropCondOpts, value: _harvCropCondition,
            onChanged: (v) => setState(() => _harvCropCondition = v),
            accentColor: _kHarv,
          ),
        ],
      ),
      const SizedBox(height: 12),

      _buildHarvDowngradeSection(context),
      const SizedBox(height: 12),

      GenSection(
        title: 'Final Flagging',
        icon : Icons.flag_outlined,
        color: const Color(0xFF42A5F5),
        children: [
          GenOptionPicker(
            label: 'Final Flagging', required: true,
            options: _harvFinalFlaggingOpts, value: _harvFinalFlagging,
            onChanged: (v) => setState(() => _harvFinalFlagging = v),
            accentColor: const Color(0xFF42A5F5),
          ),
        ],
      ),
    ];
  }

  Widget _buildHarvDowngradeSection(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final borderColor  = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final subColor     = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor    = isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
    const accentColor  = Color(0xFFAB47BC);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _harvShowDowngrade
              ? accentColor.withValues(alpha: 0.60) : borderColor,
        ),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _harvShowDowngrade = !_harvShowDowngrade),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.swap_vert_outlined,
                      color: _harvShowDowngrade ? const Color(0xFFCE93D8) : subColor,
                      size: 14),
                  const SizedBox(width: 8),
                  Text('DOWNGRADE FLAGGING',
                      style: AdvantaText.caption.copyWith(
                        color: _harvShowDowngrade ? const Color(0xFFCE93D8) : subColor,
                        fontWeight: FontWeight.w700, letterSpacing: 0.8,
                      )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _harvShowDowngrade
                          ? accentColor.withValues(alpha: 0.15) : fillColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _harvShowDowngrade
                            ? accentColor.withValues(alpha: 0.50) : borderColor,
                      ),
                    ),
                    child: Text('Opsional',
                        style: AdvantaText.caption.copyWith(
                          color: _harvShowDowngrade ? const Color(0xFFCE93D8) : subColor,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _harvShowDowngrade
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: subColor, size: 18,
                  ),
                ],
              ),
            ),
          ),

          if (_harvShowDowngrade) ...[
            Divider(height: 1, thickness: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GenDateTileNullable(
                    label  : 'Tanggal Downgrade Flagging',
                    date   : _harvDowngradeFlagDate,
                    onTap  : _pickHarvDowngradeDate,
                    onClear: () => setState(() => _harvDowngradeFlagDate = null),
                  ),
                  const SizedBox(height: 14),
                  GenOptionPicker(
                    label: 'Status Downgrade',
                    options: _harvStatusDowngradeOpts, value: _harvStatusDowngrade,
                    onChanged: (v) => setState(() => _harvStatusDowngrade = v),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 14),
                  GenOptionPickerLong(
                    label: 'Reason Downgrade',
                    options: _harvReasonDowngradeOpts, value: _harvReasonDowngrade,
                    onChanged: (v) => setState(() => _harvReasonDowngrade = v),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 14),
                  GenOptionPicker(
                    label: 'Downgrade Flagging',
                    options: _harvDowngradeFlaggingOpts, value: _harvDowngradeFlagging,
                    onChanged: (v) => setState(() => _harvDowngradeFlagging = v),
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── SAVE BAR ────────────────────────────────────────────
  Widget _buildSaveBar(BuildContext context, List<Map<String, dynamic>> selectedFields) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg   = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final borderColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final progColor   = isDark ? AdvantaColors.goldLight : AdvantaColors.mutedGrey;

    return Container(
      padding   : const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color : surfaceBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top : false,
        child: _isSaving
            ? Center(
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: progColor),
                ),
                const SizedBox(width: 12),
                Text('Menyimpan…',
                    style: AdvantaText.body2.copyWith(color: progColor)),
              ],
            ),
          ),
        )
            : SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: selectedFields.isNotEmpty
                ? () => _submitBulk(selectedFields) : null,
            icon : Icon(
              _isDiscard
                  ? Icons.do_not_disturb_on_outlined
                  : Icons.check_circle_outline,
              size: 18,
            ),
            label: Text(
              _isDiscard
                  ? 'SUBMIT ${widget.fieldNumbers.length} FIELDS — DISCARD'
                  : 'SUBMIT ${widget.fieldNumbers.length} FIELDS',
              style: AdvantaText.button,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor        : _isDiscard ? AdvantaColors.error : AdvantaColors.success,
              foregroundColor        : Colors.white,
              disabledBackgroundColor: AdvantaColors.mutedGrey.withAlpha(51),
              elevation              : 0,
              shape: const RoundedRectangleBorder(
                  borderRadius: AdvantaRadius.buttonRadius),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── FIELD CHIP ───────────────────────────────────────────
class _FieldChip extends StatelessWidget {
  final Map<String, dynamic> fieldData;
  final Color accentColor;
  final VoidCallback onRemove;

  const _FieldChip({
    required this.fieldData,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final cardBg      = isDark ? AdvantaColors.deepForest : AdvantaColors.softGrey;
    final borderColor = isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final textColor   = Theme.of(context).colorScheme.onSurface;
    final subColor    = isDark ? Colors.white60 : AdvantaColors.mutedGrey;

    return Container(
      margin    : const EdgeInsets.only(bottom: 8),
      padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 34,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(179),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Field #${fieldData['field_number']}',
                    style: AdvantaText.bodyBold.copyWith(color: textColor)),
                const SizedBox(height: 2),
                Text(
                  '${fieldData['farmer_name'] ?? '-'}  ·  ${fieldData['hybrid'] ?? '-'}',
                  style: AdvantaText.caption.copyWith(color: subColor),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding   : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color       : AdvantaColors.error.withAlpha(31),
                borderRadius: BorderRadius.circular(6),
                border      : Border.all(color: AdvantaColors.error.withAlpha(77)),
              ),
              child: const Icon(Icons.close, color: Color(0xFFEF9A9A), size: 14),
            ),
          ),
        ],
      ),
    );
  }
}