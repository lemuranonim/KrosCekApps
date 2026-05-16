// lib/screens/inspection/mass_inspect_screen.dart
//
// MASS INSPECTION SCREEN — Bulk Insert / Update untuk semua fase audit
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../theme/app_theme.dart';
import 'fc_form_widgets.dart';

// ─── Phase accent colors ──────────────────────────────────
const _kVeg = Color(0xFF78909C);
const _kGen1 = Color(0xFFFFCA28);
const _kGen2 = Color(0xFFFF7043);
const _kGen3 = Color(0xFFE53935);
const _kPreH = Color(0xFF26C6DA);
const _kHarv = Color(0xFFFF7043);

// ─────────────────────────────────────────────────────────
// OPTION LISTS
// ─────────────────────────────────────────────────────────

// — Vegetative —
const _vegRoguingOpts = [
  GenOpt('Not Yet', 'A – Not Yet'),
  GenOpt('On Going', 'B – On Going'),
  GenOpt('Done', 'C – Done'),
];
const _vegLsvOpts = [
  GenOpt('None', 'A – None'),
  GenOpt('Low', 'B – Low'),
  GenOpt('Moderate', 'C – Moderate'),
  GenOpt('High', 'D – High'),
];
const _vegCropUniformityOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
const _vegCropHealthOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
const _vegOfftypeOpts = [GenOpt('0', 'A – 0'), GenOpt('>0', 'B – >0')];
const _vegIsolationOpts = [GenOpt('Yes', 'A – Yes'), GenOpt('No', 'B – No')];
const _pspYesNoOpts = [GenOpt('NO', 'A – NO'), GenOpt('YES', 'B – YES')];
const _pspLsvOpts = [GenOpt('NO', 'A – NO'), GenOpt('YES', 'B – YES')];
const _pspIsolationTypeOpts = [
  GenOpt('Other Seed Production', 'A – Other Seed Production'),
  GenOpt('Commercial', 'B – Commercial'),
];
const _pspIsolationDistanceOpts = [
  GenOpt('>400', 'A – >400'),
  GenOpt('<400', 'B – <400'),
];
const _vegPreviousCropOpts = [
  GenOpt('Corn After Corn', 'Corn After Corn'),
  GenOpt('Not Corn', 'Not Corn'),
];
const _pspPreviousCropOpts = [
  GenOpt('Not Corn', 'A – Not Corn'),
  GenOpt('Corn after corn with different trait',
      'B – Corn after corn with different trait'),
  GenOpt('Corn after Corn same trait', 'C – Corn after Corn same trait'),
];
const _vegFinalDecisionOpts = [
  GenOpt('Pass', 'A – Pass'),
  GenOpt('Pass w/ Note', 'B – Pass w/ Note'),
  GenOpt('Hold', 'C – Hold'),
  GenOpt('Discard', 'D – Discard'),
];
const _pspRecommendationOpts = [
  GenOpt('Continue', 'Continue'),
  GenOpt('Discard', 'Discard'),
];
const _vegActionNeededOpts = [
  GenOpt('None', 'A – None'),
  GenOpt('Roguing', 'B – Roguing'),
  GenOpt('Re-Detasseling', 'C – Re-Detasseling'),
  GenOpt('Monitor', 'D – Monitor'),
  GenOpt('Hold', 'E – Hold'),
  GenOpt('Discard Partial', 'F – Discard Partial'),
  GenOpt('Discard Full', 'G – Discard Full'),
];
const _vegPldReasonOpts = [
  GenOpt('Poor Population', 'A – Poor Population'),
  GenOpt('Water Logging', 'B – Water Logging'),
  GenOpt('Pest/Disease Attack', 'C – Pest/Disease Attack'),
  GenOpt('No Field', 'D – No Field'),
];
const _vegFinalFlaggingOpts = [
  GenOpt('GF', 'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF', 'BF'),
  GenOpt('PLD', 'PLD'),
];
const _pspFlaggingOpts = [
  GenOpt('GF', 'GF'),
  GenOpt('OF', 'OF'),
  GenOpt('RF', 'RF'),
];
const _pspTypeSeedOpts = [
  GenOpt('Pre Basic', 'Pre Basic'),
  GenOpt('Basic', 'Basic')
];
const _vegMaleSplitOpts = [GenOpt('Yes', 'Y – Yes'), GenOpt('No', 'N – No')];
const _vegSplitFieldOpts = [GenOpt('Yes', 'A – Yes'), GenOpt('No', 'B – No')];
const _vegYesNoOpts = [GenOpt('Yes', 'Y – Yes'), GenOpt('No', 'N – No')];
const _vegPoiAccuracyOpts = [
  GenOpt('Valid', 'Valid'),
  GenOpt('Not Valid', 'Not Valid')
];

// — Generative shared —
const _genReadinessOpts = [
  GenOpt('100%', 'A – 100%'),
  GenOpt('75%', 'B – 75%'),
  GenOpt('50%', 'C – 50%'),
  GenOpt('<25%', 'D – <25%'),
];
const _genRoguingOpts = [
  GenOpt('Not Yet', 'A – Not Yet'),
  GenOpt('On Going', 'B – On Going'),
  GenOpt('Done', 'C – Done'),
];
const _genLsvOpts = [
  GenOpt('None', 'A – None'),
  GenOpt('Low', 'B – Low'),
  GenOpt('Moderate', 'C – Moderate'),
  GenOpt('High', 'D – High'),
];
// Crop Uniformity — sama untuk FC dan SC
const _genCropUniformityOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
// Crop Health FC — Very Poor s/d Best
const _genCropHealthFCOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
// Crop Health SC — persentase 0%–5%
const _genCropHealthSCOpts = [
  GenOpt('0% serangan', '0 – 0% serangan'),
  GenOpt('1%', '1 – 1%'),
  GenOpt('2%', '2 – 2%'),
  GenOpt('3%', '3 – 3%'),
  GenOpt('4%', '4 – 4%'),
  GenOpt('5%', '5 – 5%'),
];

const _genOfftypeOpts = [
  GenOpt('0%–1%', 'A – 0%–1%'),
  GenOpt('1%–3%', 'B – 1%–3%'),
  GenOpt('3%–5%', 'C – 3%–5%'),
  GenOpt('>5%', 'D – >5%'),
];
const _genFemaleShedOpts = [
  GenOpt('0%–10%', 'A – 0%–10%'),
  GenOpt('10%–30%', 'B – 10%–30%'),
  GenOpt('30%–50%', 'C – 30%–50%'),
  GenOpt('>50%', 'D – >50%'),
];
const _genActionNeededOpts = [
  GenOpt('None', 'A – None'),
  GenOpt('Roguing', 'B – Roguing'),
  GenOpt('Re-Detasseling', 'C – Re-Detasseling'),
  GenOpt('Monitor', 'D – Monitor'),
  GenOpt('Hold', 'E – Hold'),
  GenOpt('Discard Partial', 'F – Discard Partial'),
  GenOpt('Discard Full', 'G – Discard Full'),
];
const _genFinalDecisionOpts = [
  GenOpt('Pass', 'A – Pass'),
  GenOpt('Pass w/ Note', 'B – Pass w/ Note'),
  GenOpt('Hold', 'C – Hold'),
  GenOpt('Discard', 'D – Discard'),
];
const _genDetasselingOpts = [
  GenOpt('0%–5%', 'A – 0%–5%'),
  GenOpt('5%–10%', 'B – 5%–10%'),
  GenOpt('10%–15%', 'C – 10%–15%'),
  GenOpt('>15%', 'D – >15%'),
];
const _genIsolationOpts = [
  GenOpt('Good', 'A – Good'),
  GenOpt('Risky', 'B – Risky')
];
const _genAffectedOpts = [GenOpt('Yes', 'Y – Yes'), GenOpt('No', 'N – No')];
const _genFlaggingOpts = [
  GenOpt('GF', 'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF', 'BF'),
  GenOpt('PLD', 'PLD'),
];

// — Pre-Harvest —
const _preHMaleChoppingOpts = [
  GenOpt('Complete', 'A – Complete'),
  GenOpt('Not Complete', 'B – Not Complete'),
];
const _preHCropUniformityOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
const _preHCropHealthOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
const _preHFinalFlaggingOpts = [
  GenOpt('GF', 'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF', 'BF'),
  GenOpt('PLD', 'PLD'),
];
const _preHFinalDecisionOpts = [
  GenOpt('Pass', 'A – Pass'),
  GenOpt('Pass w/ Note', 'B – Pass w/ Note'),
  GenOpt('Hold', 'C – Hold'),
  GenOpt('Discard', 'D – Discard'),
];

// — Harvest —
const _harvEarCondOpts = [
  GenOpt('Stage 2', 'Stage 2'),
  GenOpt('Stage 3', 'Stage 3'),
  GenOpt('Stage 4', 'Stage 4'),
];
const _harvCropUniformityOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
const _harvCropHealthOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];
const _harvReasonDowngradeOpts = [
  GenOpt('Suspect Mix Material', 'A – Suspect Mix Material'),
  GenOpt('Not Accessible during Detasseling',
      'B – Not Accessible during Detasseling'),
  GenOpt('Not Sure during Harvest', 'C – Not Sure during Harvest'),
];
const _harvStatusDowngradeOpts = [
  GenOpt('Yes', 'A – Yes'),
  GenOpt('No', 'B – No')
];
const _harvDowngradeFlaggingOpts = [GenOpt('RFI', 'RFI'), GenOpt('RFD', 'RFD')];
const _harvFinalFlaggingOpts = [
  GenOpt('GF', 'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF', 'BF'),
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
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  DateTime _auditDate = DateTime.now();

  // ── Common ────────────────────────────────────────────────
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();

  // ── Vegetative ────────────────────────────────────────────
  final _vegSowingRatioFCtrl = TextEditingController();
  final _vegSowingRatioMCtrl = TextEditingController();
  final _vegCoDetasselingCtrl = TextEditingController();
  final _vegRemarksCtrl = TextEditingController();
  final _pspRecommendationPldCtrl = TextEditingController();
  final List<_MassPspRoguingDraft> _pspRoguings =
      List.generate(4, (i) => _MassPspRoguingDraft(i + 1));
  String? _pspTypeSeed;
  final _pspGenPldAreaCtrl = TextEditingController();
  final _pspGenRemarksCtrl = TextEditingController();
  final List<_MassPspGenRoguingDraft> _pspGenRoguings = [
    _MassPspGenRoguingDraft(5),
    _MassPspGenRoguingDraft(6)
  ];
  String? _pspGenRecommendation;
  String? _vegPreviousCrop, _vegMaleSplit, _vegSplitField, _vegOneSeedPerHole;
  DateTime? _vegRevPlantingDate;
  String? _vegIsolationProblem,
      _vegCropUniformity,
      _vegCropHealth,
      _vegRoguingStatus,
      _vegLsvStatus;
  String? _vegOfftypeM, _vegOfftypeF, _vegPoiAccuracy;
  String? _vegFinalDecision, _vegActionNeeded, _vegPldReason, _vegFinalFlagging;

  // ── Generative 1 ──────────────────────────────────────────
  String? _gen1Readiness,
      _gen1Roguing,
      _gen1Lsv,
      _gen1CropUniformity,
      _gen1CropHealth,
      _gen1ActionNeeded;

  // ── Generative 2 ──────────────────────────────────────────
  String? _gen2FemaleShed, _gen2OfftypeM, _gen2OfftypeF;
  String? _gen2Lsv, _gen2CropUniformity, _gen2CropHealth, _gen2ActionNeeded;

  // ── Generative 3 ──────────────────────────────────────────
  final _gen3DiscardAreaCtrl = TextEditingController();
  final _gen3DiscardReasonCtrl = TextEditingController();
  DateTime? _gen3ClosedOutDate;
  String? _gen3FemaleShed, _gen3OfftypeM, _gen3OfftypeF;
  String? _gen3Lsv, _gen3CropUniformity, _gen3CropHealth, _gen3Detasseling;
  String? _gen3IsolationStatus,
      _gen3AffectedOther,
      _gen3Flagging,
      _gen3FinalDecision;

  // ── Generative 4 (SC Only) ────────────────────────────────
  String? _gen4FemaleShed, _gen4OfftypeM, _gen4OfftypeF;
  String? _gen4Lsv, _gen4CropUniformity, _gen4CropHealth, _gen4ActionNeeded;

  // ── Generative 5 (SC Only) ────────────────────────────────
  String? _gen5FemaleShed, _gen5OfftypeM, _gen5OfftypeF;
  String? _gen5Lsv, _gen5CropUniformity, _gen5CropHealth, _gen5ActionNeeded;

  // ── Pre-Harvest ───────────────────────────────────────────
  final _preHDiscardAreaCtrl = TextEditingController();
  final _preHDiscardReasonCtrl = TextEditingController();
  String? _preHMaleChopping,
      _preHCropUniformity,
      _preHCropHealth,
      _preHFinalFlagging,
      _preHFinalDecision;

  // ── Harvest ───────────────────────────────────────────────
  DateTime? _harvDowngradeFlagDate;
  bool _harvShowDowngrade = false;
  final _harvRemarksCtrl = TextEditingController();
  String? _harvEarCondition, _harvCropUniformity, _harvCropHealth;
  String? _harvStatusDowngrade,
      _harvReasonDowngrade,
      _harvDowngradeFlagging,
      _harvFinalFlagging;

  // ── Helpers ───────────────────────────────────────────────
  Color get _phaseColor {
    switch (widget.targetPhase) {
      case 'vegetative':
        return _kVeg;
      case 'generative_1':
        return _kGen1;
      case 'generative_2':
        return _kGen2;
      case 'generative_3':
        return _kGen3;
      case 'generative_4':
        return Colors.purple;
      case 'generative_5':
        return Colors.pink;
      case 'pre_harvest':
        return _kPreH;
      case 'harvest':
        return _kHarv;
      default:
        return AdvantaColors.mutedGrey;
    }
  }

  String get _phaseLabel {
    switch (widget.targetPhase) {
      case 'vegetative':
        return 'Vegetative Audit';
      case 'generative_1':
        return 'Generative Audit 1 – Readiness';
      case 'generative_2':
        return 'Generative Audit 2 – Process';
      case 'generative_3':
        return 'Generative Audit 3 – Final';
      case 'generative_4':
        return 'Generative Audit 4 – Process (SC)';
      case 'generative_5':
        return 'Generative Audit 5 – Process (SC)';
      case 'pre_harvest':
        return 'Pre-Harvest Audit';
      case 'harvest':
        return 'Harvest Audit';
      default:
        return widget.targetPhase.replaceAll('_', ' ').toUpperCase();
    }
  }

  bool _isSweetCornSelection(List<Map<String, dynamic>> selectedFields) {
    if (selectedFields.isEmpty) return false;
    return selectedFields.every((field) {
      final hybrid = field['hybrid']?.toString().toUpperCase().trim() ?? '';
      return ['AX01', 'AX02', 'AX03', 'AX04'].contains(hybrid);
    });
  }

  bool _isPspSelection(List<Map<String, dynamic>> selectedFields) {
    if (selectedFields.isEmpty) return false;
    return selectedFields.every((field) {
      final hybrid = field['hybrid']?.toString().toUpperCase().trim() ?? '';
      return hybrid.startsWith('ASF');
    });
  }

  bool _hasMixedPspSelection(List<Map<String, dynamic>> selectedFields) {
    if (selectedFields.isEmpty) return false;
    final hasPsp = selectedFields.any((field) {
      final hybrid = field['hybrid']?.toString().toUpperCase().trim() ?? '';
      return hybrid.startsWith('ASF');
    });
    final hasNonPsp = selectedFields.any((field) {
      final hybrid = field['hybrid']?.toString().toUpperCase().trim() ?? '';
      return !hybrid.startsWith('ASF');
    });
    return hasPsp && hasNonPsp;
  }

  bool get _isDiscard {
    switch (widget.targetPhase) {
      case 'vegetative':
        return genIsDiscardDecision(_vegFinalDecision);
      case 'generative_1':
        return genIsDiscardFull(_gen1ActionNeeded);
      case 'generative_2':
        return genIsDiscardFull(_gen2ActionNeeded);
      case 'generative_3':
        return genIsDiscardDecision(_gen3FinalDecision);
      case 'generative_4':
        return genIsDiscardFull(_gen4ActionNeeded);
      case 'generative_5':
        return genIsDiscardFull(_gen5ActionNeeded) ||
            genIsDiscardDecision(_pspGenRecommendation);
      case 'pre_harvest':
        return genIsDiscardDecision(_preHFinalDecision);
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _vegSowingRatioFCtrl.dispose();
    _vegSowingRatioMCtrl.dispose();
    _vegCoDetasselingCtrl.dispose();
    _vegRemarksCtrl.dispose();
    _pspRecommendationPldCtrl.dispose();
    for (final roguing in _pspRoguings) {
      roguing.dispose();
    }
    _pspGenPldAreaCtrl.dispose();
    _pspGenRemarksCtrl.dispose();
    for (final roguing in _pspGenRoguings) {
      roguing.dispose();
    }
    _gen3DiscardAreaCtrl.dispose();
    _gen3DiscardReasonCtrl.dispose();
    _preHDiscardAreaCtrl.dispose();
    _preHDiscardReasonCtrl.dispose();
    _harvRemarksCtrl.dispose();
    super.dispose();
  }

  // ─── Date pickers ─────────────────────────────────────────
  Future<void> _pickAuditDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _phaseColor), child: child!),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _pickVegRevPlantingDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _vegRevPlantingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kVeg), child: child!),
    );
    if (p != null) setState(() => _vegRevPlantingDate = p);
  }

  Future<void> _pickPspRoguingDate(int index) async {
    final roguing = _pspRoguings[index];
    final p = await showDatePicker(
      context: context,
      initialDate: roguing.date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kVeg), child: child!),
    );
    if (p != null) setState(() => roguing.date = p);
  }

  Future<void> _pickPspGenRoguingDate(int index) async {
    final roguing = _pspGenRoguings[index];
    final p = await showDatePicker(
      context: context,
      initialDate: roguing.date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kGen3), child: child!),
    );
    if (p != null) setState(() => roguing.date = p);
  }

  Future<void> _pickGen3ClosedDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _gen3ClosedOutDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kGen3), child: child!),
    );
    if (p != null) setState(() => _gen3ClosedOutDate = p);
  }

  Future<void> _pickHarvDowngradeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _harvDowngradeFlagDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) =>
          Theme(data: genDatePickerTheme(ctx, _kHarv), child: child!),
    );
    if (p != null) setState(() => _harvDowngradeFlagDate = p);
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: AdvantaText.body2.copyWith(color: Colors.white)),
      backgroundColor: err ? AdvantaColors.error : AdvantaColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  bool _validatePspMassDates() {
    final missing = _pspRoguings
        .where((roguing) => roguing.date == null)
        .map((roguing) => roguing.number)
        .toList();
    if (missing.isNotEmpty) {
      _snack('Tanggal Roguing ${missing.join(', ')} PSP wajib diisi',
          err: true);
      return false;
    }
    return true;
  }

  bool _validatePspGenMassDates() {
    final missing = _pspGenRoguings
        .where((roguing) => roguing.date == null)
        .map((roguing) => roguing.number)
        .toList();
    if (missing.isNotEmpty) {
      _snack('Tanggal Roguing ${missing.join(', ')} PSP wajib diisi',
          err: true);
      return false;
    }
    return true;
  }

  // ─── SUBMIT ──────────────────────────────────────────────
  Future<void> _submitBulk(List<Map<String, dynamic>> selectedFields) async {
    final isPspSelection = _isPspSelection(selectedFields);
    if (_hasMixedPspSelection(selectedFields)) {
      _snack('Mass inspect PSP tidak boleh dicampur dengan FC/SC', err: true);
      return;
    }
    if (isPspSelection &&
        widget.targetPhase == 'vegetative' &&
        !_validatePspMassDates()) {
      return;
    }
    if (isPspSelection &&
        widget.targetPhase == 'generative_5' &&
        !_validatePspGenMassDates()) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_auditDate);
      final week = calcAuditWeek(_auditDate);
      final nowStr = DateTime.now().toIso8601String();
      final records = <Map<String, dynamic>>[];

      for (final field in selectedFields) {
        final fn = field['field_number'] as String;
        final Map<String, dynamic> rec = {
          'field_number': fn,
          'is_mass_submit': true,
        };

        switch (widget.targetPhase) {
          case 'vegetative':
            final rawArea = field['effective_area_ha'];
            final effectiveArea = rawArea is num
                ? rawArea.toDouble()
                : double.tryParse(rawArea?.toString() ?? '');

            if (isPspSelection) {
              final completionDate = _pspRoguings[3].date;
              final latestDate = _pspRoguings
                  .map((roguing) => roguing.date)
                  .whereType<DateTime>()
                  .fold<DateTime?>(null, (latest, date) {
                if (latest == null || date.isAfter(latest)) return date;
                return latest;
              });
              final summaryDate = completionDate ?? latestDate ?? _auditDate;
              final r1 = _pspRoguings[0];
              final r4 = _pspRoguings[3];
              final filledCount =
                  _pspRoguings.where((roguing) => roguing.date != null).length;
              final inferredRoguingStatus =
                  completionDate != null ? 'C' : (filledCount > 0 ? 'B' : 'A');

              rec.addAll({
                'audit_date_user': DateFormat('yyyy-MM-dd').format(summaryDate),
                'date_of_audit': completionDate == null
                    ? null
                    : DateFormat('yyyy-MM-dd').format(completionDate),
                'audit_week': calcAuditWeek(summaryDate),
                'qa_fi': _qaFiCtrl.text.trim(),
                'qa_spv': _qaSpvCtrl.text.trim(),
                'co_detasseling': _vegCoDetasselingCtrl.text.trim(),
                'field_size_by_audit_ha': effectiveArea,
                'previous_crop_by_audit': _vegPreviousCrop,
                'type_seed': _pspTypeSeed,
                'isolation_problem_by_audit':
                    r4.isolationAudit ?? r1.isolationAudit,
                'rev_planting_date': _vegRevPlantingDate != null
                    ? DateFormat('yyyy-MM-dd').format(_vegRevPlantingDate!)
                    : null,
                'crop_uniformity': r4.cropUniformity ?? r1.cropUniformity,
                'crop_health': r4.cropHealth ?? r1.cropHealth,
                'roguing_status': inferredRoguingStatus,
                'lsv_status': r4.lsv,
                'offtype_in_male': r4.offtype ?? r1.offtype,
                'offtype_in_female': r4.offtype ?? r1.offtype,
                'decision': _vegFinalDecision,
                'pld_reason': genIsDiscardDecision(_vegFinalDecision)
                    ? 'PSP Recommendation Discard'
                    : null,
                'flagging': _vegFinalFlagging,
                'remarks': _vegRemarksCtrl.text.trim(),
                'fase': 'vegetative',
                'updated_at': nowStr,
                'recommendation_pld_ha': double.tryParse(
                    _pspRecommendationPldCtrl.text.replaceAll(',', '.')),
              });
              for (final roguing in _pspRoguings) {
                rec.addAll(roguing.toPayload());
              }
              break;
            }

            rec.addAll({
              'audit_date_user': dateStr,
              'date_of_audit': dateStr,
              'audit_week': week,
              'qa_fi': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'co_detasseling': _vegCoDetasselingCtrl.text.trim(),
              'field_size_by_audit_ha': effectiveArea,
              'male_split_by_audit': _vegMaleSplit,
              'sowing_ratio_by_audit':
                  '${_vegSowingRatioFCtrl.text.trim()}:${_vegSowingRatioMCtrl.text.trim()}',
              'split_field_by_audit': _vegSplitField,
              'previous_crop_by_audit': _vegPreviousCrop,
              'one_seed_per_hole': _vegOneSeedPerHole,
              'isolation_problem_by_audit': _vegIsolationProblem,
              'rev_planting_date': _vegRevPlantingDate != null
                  ? DateFormat('yyyy-MM-dd').format(_vegRevPlantingDate!)
                  : null,
              'crop_uniformity': _vegCropUniformity,
              'crop_health': _vegCropHealth,
              'roguing_status': _vegRoguingStatus,
              'lsv_status': _vegLsvStatus,
              'offtype_in_male': _vegOfftypeM,
              'offtype_in_female': _vegOfftypeF,
              'poi_accuracy': _vegPoiAccuracy,
              'decision': _vegFinalDecision,
              'action_needed': _vegActionNeeded,
              'pld_reason': genIsDiscardDecision(_vegFinalDecision)
                  ? _vegPldReason
                  : null,
              'flagging': _vegFinalFlagging,
              'remarks': _vegRemarksCtrl.text.trim(),
              'fase': 'vegetative',
              'updated_at': nowStr,
            });

          case 'generative_1':
            rec.addAll({
              'date_of_audit_1': dateStr,
              'week_of_audit_1': week,
              'qa_fi_1': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'readiness_status_1': _gen1Readiness,
              'roguing_status_1': _gen1Roguing,
              'lsv_status_1': _gen1Lsv,
              'crop_uniformity_1': _gen1CropUniformity,
              'crop_health_1': _gen1CropHealth,
              'action_needed_1': _gen1ActionNeeded,
              'submitted_at_1': nowStr,
              'fase': 'generative_1',
              'is_mass_submit_1': true,
            });

          case 'generative_2':
            rec.addAll({
              'date_of_audit_2': dateStr,
              'week_of_audit_2': week,
              'qa_fi_2': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'female_shedding_2': _gen2FemaleShed,
              'offtype_m_2': _gen2OfftypeM,
              'offtype_f_2': _gen2OfftypeF,
              'lsv_status_2': _gen2Lsv,
              'crop_uniformity_2': _gen2CropUniformity,
              'crop_health_2': _gen2CropHealth,
              'action_needed_2': _gen2ActionNeeded,
              'submitted_at_2': nowStr,
              'fase': 'generative_2',
              'is_mass_submit_2': true,
            });

          case 'generative_3':
            final isD3 = genIsDiscardDecision(_gen3FinalDecision);
            rec.addAll({
              'date_of_audit_3': dateStr,
              'week_of_audit_3': week,
              'qa_fi_3': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'female_shedding_3': _gen3FemaleShed,
              'offtype_m_3': _gen3OfftypeM,
              'offtype_f_3': _gen3OfftypeF,
              'lsv_status_3': _gen3Lsv,
              'crop_uniformity_3': _gen3CropUniformity,
              'crop_health_3': _gen3CropHealth,
              'detasseling_assesment_3': _gen3Detasseling,
              'isolation_status_3': _gen3IsolationStatus,
              'affected_other_field_3': _gen3AffectedOther,
              'closed_out_date': _gen3ClosedOutDate != null
                  ? DateFormat('yyyy-MM-dd').format(_gen3ClosedOutDate!)
                  : null,
              'flagging': _gen3Flagging,
              'final_decision_3': _gen3FinalDecision,
              'action_needed_3': isD3 ? 'Discard Full' : 'None',
              'discard_area_ha_3': isD3
                  ? double.tryParse(
                      _gen3DiscardAreaCtrl.text.replaceAll(',', '.'))
                  : null,
              'discard_reason_3':
                  isD3 ? _gen3DiscardReasonCtrl.text.trim() : null,
              'submitted_at_3': nowStr,
              'fase': 'generative_3',
              'is_mass_submit_3': true,
            });

          case 'generative_4':
            rec.addAll({
              'date_of_audit_4': dateStr,
              'week_of_audit_4': week,
              'qa_fi_4': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'female_shedding_4': _gen4FemaleShed,
              'offtype_m_4': _gen4OfftypeM,
              'offtype_f_4': _gen4OfftypeF,
              'lsv_status_4': _gen4Lsv,
              'crop_uniformity_4': _gen4CropUniformity,
              'crop_health_4': _gen4CropHealth,
              'action_needed_4': _gen4ActionNeeded,
              'submitted_at_4': nowStr,
              'fase': 'generative_4',
              'is_mass_submit_4': true,
            });

          case 'generative_5':
            if (isPspSelection) {
              final r6 = _pspGenRoguings[1];
              rec.addAll({
                'date_of_audit_5': DateFormat('yyyy-MM-dd').format(r6.date!),
                'week_of_audit_5': calcAuditWeek(r6.date!),
                'qa_fi_5': _qaFiCtrl.text.trim(),
                'qa_spv': _qaSpvCtrl.text.trim(),
                'lsv_status_5': r6.lsv,
                'crop_uniformity_5': r6.cropUniformity,
                'crop_health_5': r6.cropHealth,
                'final_flagging_5': r6.flagging,
                'final_decision_5': _pspGenRecommendation,
                'pld_area_ha_5': genIsDiscardDecision(_pspGenRecommendation)
                    ? double.tryParse(
                        _pspGenPldAreaCtrl.text.replaceAll(',', '.'))
                    : null,
                'pld_reason_5': genIsDiscardDecision(_pspGenRecommendation)
                    ? 'PSP Recommendation Discard'
                    : null,
                'remarks_5': _pspGenRemarksCtrl.text.trim(),
                'submitted_at_5': nowStr,
                'fase': 'generative_5',
                'is_mass_submit_5': true,
              });
              for (final roguing in _pspGenRoguings) {
                rec.addAll(roguing.toPayload());
              }
              break;
            }

            rec.addAll({
              'date_of_audit_5': dateStr,
              'week_of_audit_5': week,
              'qa_fi_5': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'female_shedding_5': _gen5FemaleShed,
              'offtype_m_5': _gen5OfftypeM,
              'offtype_f_5': _gen5OfftypeF,
              'lsv_status_5': _gen5Lsv,
              'crop_uniformity_5': _gen5CropUniformity,
              'crop_health_5': _gen5CropHealth,
              'action_needed_5': _gen5ActionNeeded,
              'submitted_at_5': nowStr,
              'fase': 'generative_5',
              'is_mass_submit_5': true,
            });

          case 'pre_harvest':
            final isDPH = genIsDiscardDecision(_preHFinalDecision);
            rec.addAll({
              'audit_date': dateStr,
              'audit_week': week,
              'qa_fi': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'male_chopping_rows': _preHMaleChopping,
              'crop_uniformity': _preHCropUniformity,
              'crop_health': _preHCropHealth,
              'final_flagging': _preHFinalFlagging,
              'final_decision': _preHFinalDecision,
              'discard_area_ha': isDPH
                  ? double.tryParse(
                      _preHDiscardAreaCtrl.text.replaceAll(',', '.'))
                  : null,
              'discard_reason':
                  isDPH ? _preHDiscardReasonCtrl.text.trim() : null,
              'fase': 'Pre-Harvest',
              'updated_at': nowStr,
            });

          case 'harvest':
            if (isPspSelection) {
              rec.addAll({
                'date_of_audit': dateStr,
                'audit_week': week,
                'qa_fi': _qaFiCtrl.text.trim(),
                'qa_spv': _qaSpvCtrl.text.trim(),
                'ear_condition_observation': _harvEarCondition,
                'crop_health': _harvCropHealth,
                'remarks': _harvRemarksCtrl.text.trim(),
                'fase': 'Harvest',
                'updated_at': nowStr,
              });
              break;
            }

            rec.addAll({
              'date_of_audit': dateStr,
              'audit_week': week,
              'qa_fi': _qaFiCtrl.text.trim(),
              'qa_spv': _qaSpvCtrl.text.trim(),
              'ear_condition_observation': _harvEarCondition,
              'crop_uniformity': _harvCropUniformity,
              'crop_health': _harvCropHealth,
              'status_downgrade':
                  _harvShowDowngrade ? _harvStatusDowngrade : null,
              'reason_downgrade':
                  _harvShowDowngrade ? _harvReasonDowngrade : null,
              'downgrade_flagging':
                  _harvShowDowngrade ? _harvDowngradeFlagging : null,
              'date_of_downgrade_flagging':
                  _harvShowDowngrade && _harvDowngradeFlagDate != null
                      ? DateFormat('yyyy-MM-dd').format(_harvDowngradeFlagDate!)
                      : null,
              'final_flagging': _harvFinalFlagging,
              'remarks': _harvRemarksCtrl.text.trim(),
              'fase': 'Harvest',
              'updated_at': nowStr,
            });
        }
        records.add(rec);
      }

      final service = ref.read(supabaseServiceProvider);
      await service.bulkUpsertInspection(
          phase: widget.targetPhase, records: records);

      final att = ref.read(attendanceProvider);
      if (att.isCheckedIn && att.attendanceId != null) {
        double lat = 0, lng = 0;
        try {
          final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high));
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {}
        for (final field in selectedFields) {
          await service.logActivity(
            attendanceId: att.attendanceId!,
            userId: _qaFiCtrl.text.trim().isNotEmpty
                ? _qaFiCtrl.text.trim()
                : 'unknown',
            fieldNumber: field['field_number'],
            phase: widget.targetPhase,
            actionType: 'mass_submit',
            lat: lat,
            lng: lng,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final masterAsync = ref.watch(masterFieldsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AdvantaColors.deepForest : AdvantaColors.softGrey,
      appBar: _buildAppBar(context),
      body: masterAsync.when(
        data: (allFields) {
          final selected = allFields
              .where((f) => widget.fieldNumbers.contains(f['field_number']))
              .toList();
          return _buildForm(context, selected);
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: _phaseColor)),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: AdvantaText.body2
                  .copyWith(color: Theme.of(context).colorScheme.error)),
        ),
      ),
    );
  }

  // ─── APP BAR ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = _isDiscard
        ? const Color(0xFF7B1821)
        : (isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen);
    final iconColor = isDark ? AdvantaColors.goldLight : Colors.white;
    final divColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);

    return AppBar(
      backgroundColor: appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon:
            Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mass Inspection',
              style: AdvantaText.caption.copyWith(
                color: _isDiscard ? const Color(0xFFFF8A80) : _phaseColor,
                fontWeight: FontWeight.w500,
              )),
          Text(_phaseLabel,
              style: AdvantaText.heading2.copyWith(color: iconColor)),
        ],
      ),
      actions: [
        if (_isDiscard)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdvantaColors.error.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdvantaColors.error.withAlpha(128)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF8A80), size: 14),
              SizedBox(width: 4),
              Text('DISCARD',
                  style: TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
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
  Widget _buildForm(
      BuildContext context, List<Map<String, dynamic>> selectedFields) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final isPspSelection = _isPspSelection(selectedFields);
    final hasMixedPspSelection = _hasMixedPspSelection(selectedFields);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _phaseColor.withAlpha(26),
            child: Row(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Common: Informasi Audit ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: _phaseColor,
                    children: [
                      if (!(isPspSelection &&
                          widget.targetPhase == 'generative_5')) ...[
                        GenDateTile(
                            label: widget.targetPhase == 'harvest' &&
                                    isPspSelection
                                ? 'Date of Inspeksi Harvest'
                                : 'Tanggal Audit',
                            date: _auditDate,
                            onTap: _pickAuditDate),
                        const SizedBox(height: 12),
                      ],
                      GenTextField(
                        controller: _qaFiCtrl,
                        label: 'QA FI',
                        hint: 'Nama QA Field Inspector',
                        required: true,
                        icon: Icons.person_outline,
                        accentColor: _phaseColor,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        required: true,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: _phaseColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ..._buildPhaseFields(
                    context,
                    isSweetCorn: _isSweetCornSelection(selectedFields),
                    isPsp: isPspSelection,
                  ),

                  const SizedBox(height: 12),

                  if (hasMixedPspSelection) ...[
                    const GenDiscardBanner(
                      message:
                          'Field PSP/ASF tidak boleh dicampur dengan FC/SC dalam satu mass inspect.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Field Terpilih ──
                  GenSection(
                    title: 'Field Terpilih (${selectedFields.length})',
                    icon: Icons.crop_square_rounded,
                    color: AdvantaColors.mutedGrey,
                    children: selectedFields.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Tidak ada field terpilih.',
                                  style: AdvantaText.body2.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(128))),
                            ),
                          ]
                        : selectedFields
                            .map((f) => _FieldChip(
                                  fieldData: f,
                                  accentColor: _phaseColor,
                                  onRemove: () => setState(() => widget
                                      .fieldNumbers
                                      .remove(f['field_number'])),
                                ))
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
          _buildSaveBar(
            context,
            selectedFields,
            disabled: hasMixedPspSelection,
          ),
        ],
      ),
    );
  }

  // ─── PHASE FIELD ROUTER ───────────────────────────────────
  List<Widget> _buildPhaseFields(
    BuildContext context, {
    required bool isSweetCorn,
    required bool isPsp,
  }) {
    switch (widget.targetPhase) {
      case 'vegetative':
        return isPsp
            ? _buildVegetativePspFields(context)
            : _buildVegetativeFields(context, isSweetCorn: isSweetCorn);
      case 'generative_1':
        return _buildGen1Fields(isSweetCorn: isSweetCorn);
      case 'generative_2':
        return _buildGen2Fields(isSweetCorn: isSweetCorn);
      case 'generative_3':
        return _buildGen3Fields(context, isSweetCorn: isSweetCorn);
      case 'generative_4':
        return _buildGen4Fields();
      case 'generative_5':
        return isPsp ? _buildGenerativePspFields() : _buildGen5Fields();
      case 'pre_harvest':
        return _buildPreHarvestFields(isSweetCorn: isSweetCorn);
      case 'harvest':
        return isPsp
            ? _buildHarvestPspFields()
            : _buildHarvestFields(context, isSweetCorn: isSweetCorn);
      default:
        return [];
    }
  }

  // ── VEGETATIVE ────────────────────────────────────────────
  List<Widget> _buildVegetativeFields(
    BuildContext context, {
    required bool isSweetCorn,
  }) {
    final isD = genIsDiscardDecision(_vegFinalDecision);
    return [
      GenSection(
        title: 'Kondisi Lahan',
        icon: Icons.landscape_outlined,
        color: const Color(0xFF26A69A),
        children: [
          GenDateTileNullable(
            label: 'Rev Planting Date',
            date: _vegRevPlantingDate,
            onTap: _pickVegRevPlantingDate,
            onClear: () => setState(() => _vegRevPlantingDate = null),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Male Split',
            required: !isD,
            options: _vegMaleSplitOpts,
            value: _vegMaleSplit,
            onChanged: (v) => setState(() => _vegMaleSplit = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          _buildSowingRatio(context, isD),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Split Field',
            required: !isD,
            options: _vegSplitFieldOpts,
            value: _vegSplitField,
            onChanged: (v) => setState(() => _vegSplitField = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Previous Crop',
            required: !isD,
            options: _vegPreviousCropOpts,
            value: _vegPreviousCrop,
            onChanged: (v) => setState(() => _vegPreviousCrop = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'One Seed / Hole',
            required: !isD,
            options: _vegYesNoOpts,
            value: _vegOneSeedPerHole,
            onChanged: (v) => setState(() => _vegOneSeedPerHole = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenTextField(
            controller: _vegCoDetasselingCtrl,
            label: 'Co Detasseling',
            hint: 'Nama Co Detasseling',
            required: true,
            icon: Icons.group_outlined,
            accentColor: const Color(0xFF26A69A),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Penilaian Audit',
        icon: Icons.assessment_outlined,
        color: const Color(0xFFFFCA28),
        children: [
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _vegCropUniformityOpts,
            value: _vegCropUniformity,
            onChanged: (v) => setState(() => _vegCropUniformity = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: isSweetCorn
                ? 'Crop Health (Bulai, Hawar) % dari Populasi'
                : 'Crop Health',
            required: !isD,
            options: isSweetCorn ? _genCropHealthSCOpts : _vegCropHealthOpts,
            value: _vegCropHealth,
            onChanged: (v) => setState(() => _vegCropHealth = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Roguing Status',
            required: !isD,
            options: _vegRoguingOpts,
            value: _vegRoguingStatus,
            onChanged: (v) => setState(() => _vegRoguingStatus = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status',
            required: !isD,
            options: _vegLsvOpts,
            value: _vegLsvStatus,
            onChanged: (v) => setState(() => _vegLsvStatus = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Isolation Problem',
            required: !isD,
            options: _vegIsolationOpts,
            value: _vegIsolationProblem,
            onChanged: (v) => setState(() => _vegIsolationProblem = v),
            accentColor: const Color(0xFFFFCA28),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M',
                  required: !isD,
                  options: _vegOfftypeOpts,
                  value: _vegOfftypeM,
                  onChanged: (v) => setState(() => _vegOfftypeM = v),
                  accentColor: const Color(0xFFFFCA28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F',
                  required: !isD,
                  options: _vegOfftypeOpts,
                  value: _vegOfftypeF,
                  onChanged: (v) => setState(() => _vegOfftypeF = v),
                  accentColor: const Color(0xFFFFCA28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'POI Accuracy',
            required: !isD,
            options: _vegPoiAccuracyOpts,
            value: _vegPoiAccuracy,
            onChanged: (v) => setState(() => _vegPoiAccuracy = v),
            accentColor: const Color(0xFFFFCA28),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Keputusan',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPicker(
            label: 'Final Decision',
            required: true,
            options: _vegFinalDecisionOpts,
            value: _vegFinalDecision,
            onChanged: (v) => setState(() {
              _vegFinalDecision = v;
              if (!genIsDiscardDecision(v)) _vegPldReason = null;
            }),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message:
                  'Mode Discard aktif — pastikan PLD Reason terisi sebelum menyimpan.',
            ),
            const SizedBox(height: 14),
            GenOptionPicker(
              label: 'PLD Reason',
              required: true,
              options: _vegPldReasonOpts,
              value: _vegPldReason,
              onChanged: (v) => setState(() => _vegPldReason = v),
              accentColor: AdvantaColors.error,
            ),
          ],
          const SizedBox(height: 14),
          GenOptionPickerLong(
            label: 'Action Needed',
            required: true,
            options: _vegActionNeededOpts,
            value: _vegActionNeeded,
            onChanged: (v) => setState(() => _vegActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Final Flagging',
            required: true,
            options: _vegFinalFlaggingOpts,
            value: _vegFinalFlagging,
            onChanged: (v) => setState(() => _vegFinalFlagging = v),
            accentColor: AdvantaColors.error,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Catatan',
        icon: Icons.notes_outlined,
        color: AdvantaColors.mutedGrey,
        children: [
          GenTextField(
            controller: _vegRemarksCtrl,
            label: 'Remarks',
            hint: 'Catatan tambahan di lapangan...',
            maxLines: 4,
            icon: Icons.edit_note_outlined,
            accentColor: AdvantaColors.mutedGrey,
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildVegetativePspFields(BuildContext context) {
    final isD = genIsDiscardDecision(_vegFinalDecision);
    return [
      GenSection(
        title: 'Roguing 1',
        icon: Icons.eco_outlined,
        color: const Color(0xFF26A69A),
        children: [
          _buildPspDateTile(0),
          const SizedBox(height: 12),
          GenTextField(
            controller: _vegCoDetasselingCtrl,
            label: 'Co-Roguing',
            hint: 'Nama PIC co-roguing',
            icon: Icons.group_outlined,
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 12),
          GenDateTileNullable(
            label: 'Rev Tgl Tanam',
            date: _vegRevPlantingDate,
            onTap: _pickVegRevPlantingDate,
            onClear: () => setState(() => _vegRevPlantingDate = null),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Previous Crop Actual',
            required: !isD,
            options: _pspPreviousCropOpts,
            value: _vegPreviousCrop,
            onChanged: (v) => setState(() => _vegPreviousCrop = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Type Seed',
            required: true,
            options: _pspTypeSeedOpts,
            value: _pspTypeSeed,
            onChanged: (v) => setState(() => _pspTypeSeed = v),
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(height: 14),
          _buildPspIsolationFields(_pspRoguings[0], const Color(0xFF26A69A)),
          const SizedBox(height: 14),
          _buildPspCoreFields(_pspRoguings[0], const Color(0xFF26A69A),
              includeLsv: false),
        ],
      ),
      const SizedBox(height: 12),
      _buildPspRoguingSection(_pspRoguings[1]),
      const SizedBox(height: 12),
      _buildPspRoguingSection(_pspRoguings[2]),
      const SizedBox(height: 12),
      GenSection(
        title: 'Roguing 4 Final',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          _buildPspDateTile(3),
          const SizedBox(height: 14),
          _buildPspCoreFields(_pspRoguings[3], AdvantaColors.error,
              includeLsv: true),
          const SizedBox(height: 14),
          _buildPspIsolationFields(_pspRoguings[3], AdvantaColors.error),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Flagging',
            options: _pspFlaggingOpts,
            value: _vegFinalFlagging,
            onChanged: (v) => setState(() => _vegFinalFlagging = v),
            accentColor: AdvantaColors.error,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Recommendation',
            required: true,
            options: _pspRecommendationOpts,
            value: _vegFinalDecision,
            onChanged: (v) => setState(() => _vegFinalDecision = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message: 'Recommendation Discard aktif - isi luas PLD bila ada.',
            ),
          ],
          const SizedBox(height: 14),
          GenTextField(
            controller: _pspRecommendationPldCtrl,
            label: 'Recommendation PLD (Ha)',
            keyboardType: TextInputType.number,
            icon: Icons.square_foot_outlined,
            required: isD,
            accentColor: AdvantaColors.error,
          ),
          const SizedBox(height: 14),
          GenTextField(
            controller: _vegRemarksCtrl,
            label: 'Remarks',
            hint: 'Catatan tambahan PSP/PS...',
            maxLines: 4,
            icon: Icons.edit_note_outlined,
            accentColor: AdvantaColors.error,
          ),
        ],
      ),
    ];
  }

  Widget _buildPspRoguingSection(_MassPspRoguingDraft roguing) {
    const color = Color(0xFFFFCA28);
    return GenSection(
      title: 'Roguing ${roguing.number}',
      icon: Icons.fact_check_outlined,
      color: color,
      children: [
        _buildPspDateTile(roguing.number - 1),
        const SizedBox(height: 14),
        _buildPspCoreFields(roguing, color, includeLsv: true),
      ],
    );
  }

  Widget _buildPspDateTile(int index) {
    final roguing = _pspRoguings[index];
    return GenDateTileNullable(
      label: 'Date Of Inspeksi Roguing ${roguing.number}',
      date: roguing.date,
      onTap: () => _pickPspRoguingDate(index),
      onClear: () => setState(() => roguing.date = null),
    );
  }

  Widget _buildPspCoreFields(
    _MassPspRoguingDraft roguing,
    Color color, {
    required bool includeLsv,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GenOptionPicker(
                label: 'Audit Offtype',
                required: true,
                options: _vegOfftypeOpts,
                value: roguing.offtype,
                onChanged: (v) => setState(() => roguing.offtype = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GenOptionPicker(
                label: 'Audit Volunteer',
                required: true,
                options: _vegOfftypeOpts,
                value: roguing.volunteer,
                onChanged: (v) => setState(() => roguing.volunteer = v),
                accentColor: color,
              ),
            ),
          ],
        ),
        if (includeLsv) ...[
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Audit LSV',
            required: true,
            options: _pspLsvOpts,
            value: roguing.lsv,
            onChanged: (v) => setState(() => roguing.lsv = v),
            accentColor: color,
          ),
        ],
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Crop Health',
          required: true,
          options: _vegCropHealthOpts,
          value: roguing.cropHealth,
          onChanged: (v) => setState(() => roguing.cropHealth = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Crop Uniformity',
          required: true,
          options: _vegCropUniformityOpts,
          value: roguing.cropUniformity,
          onChanged: (v) => setState(() => roguing.cropUniformity = v),
          accentColor: color,
        ),
      ],
    );
  }

  Widget _buildPspIsolationFields(_MassPspRoguingDraft roguing, Color color) {
    return Column(
      children: [
        GenOptionPicker(
          label: 'Isolation Audit',
          required: true,
          options: _pspYesNoOpts,
          value: roguing.isolationAudit,
          onChanged: (v) => setState(() => roguing.isolationAudit = v),
          accentColor: color,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GenOptionPicker(
                label: 'Isolation Type',
                options: _pspIsolationTypeOpts,
                value: roguing.isolationType,
                onChanged: (v) => setState(() => roguing.isolationType = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GenOptionPicker(
                label: 'Isolation Distance',
                options: _pspIsolationDistanceOpts,
                value: roguing.isolationDistance,
                onChanged: (v) => setState(() => roguing.isolationDistance = v),
                accentColor: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildGenerativePspFields() {
    return [
      _buildPspGenRoguingSection(_pspGenRoguings[0], isFinal: false),
      const SizedBox(height: 12),
      _buildPspGenRoguingSection(_pspGenRoguings[1], isFinal: true),
    ];
  }

  Widget _buildPspGenRoguingSection(
    _MassPspGenRoguingDraft roguing, {
    required bool isFinal,
  }) {
    final color = isFinal ? AdvantaColors.error : _kGen1;
    final isPld = genIsDiscardDecision(_pspGenRecommendation);
    return GenSection(
      title: 'Roguing ${roguing.number}${isFinal ? ' Final' : ''}',
      icon: isFinal ? Icons.gavel_outlined : Icons.fact_check_outlined,
      color: color,
      children: [
        GenDateTileNullable(
          label: 'Date Of Inspeksi Roguing ${roguing.number}',
          date: roguing.date,
          onTap: () => _pickPspGenRoguingDate(roguing.number - 5),
          onClear: () => setState(() => roguing.date = null),
        ),
        const SizedBox(height: 14),
        _buildPspGenCoreFields(roguing, color),
        const SizedBox(height: 14),
        _buildPspGenIsolationFields(roguing, color),
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Nicking Observation',
          required: true,
          options: _pspYesNoOpts,
          value: roguing.nickingObservation,
          onChanged: (v) => setState(() => roguing.nickingObservation = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Flagging',
          required: true,
          options: _pspFlaggingOpts,
          value: roguing.flagging,
          onChanged: (v) => setState(() => roguing.flagging = v),
          accentColor: color,
        ),
        if (isFinal) ...[
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Recommendation',
            required: true,
            options: _pspRecommendationOpts,
            value: _pspGenRecommendation,
            onChanged: (v) => setState(() => _pspGenRecommendation = v),
            accentColor: color,
          ),
          if (isPld) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message: 'Recommendation Discard aktif - isi luas PLD bila ada.',
            ),
          ],
          const SizedBox(height: 14),
          GenTextField(
            controller: _pspGenPldAreaCtrl,
            label: 'Recommendation PLD (Ha)',
            keyboardType: TextInputType.number,
            icon: Icons.square_foot_outlined,
            required: isPld,
            accentColor: color,
          ),
          const SizedBox(height: 14),
          GenTextField(
            controller: _pspGenRemarksCtrl,
            label: 'Remarks',
            maxLines: 4,
            icon: Icons.edit_note_outlined,
            accentColor: color,
          ),
        ],
      ],
    );
  }

  Widget _buildPspGenCoreFields(_MassPspGenRoguingDraft roguing, Color color) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GenOptionPicker(
                label: 'Standing crop Offtype',
                required: true,
                options: _vegOfftypeOpts,
                value: roguing.standingCropOfftype,
                onChanged: (v) =>
                    setState(() => roguing.standingCropOfftype = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GenOptionPicker(
                label: 'Standing crop Volunteer',
                required: true,
                options: _vegOfftypeOpts,
                value: roguing.standingCropVolunteer,
                onChanged: (v) =>
                    setState(() => roguing.standingCropVolunteer = v),
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
              child: GenOptionPicker(
                label: 'Offtype Shed',
                required: true,
                options: _vegOfftypeOpts,
                value: roguing.offtypeShed,
                onChanged: (v) => setState(() => roguing.offtypeShed = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GenOptionPicker(
                label: 'Volunteer Shed',
                required: true,
                options: _vegOfftypeOpts,
                value: roguing.volunteerShed,
                onChanged: (v) => setState(() => roguing.volunteerShed = v),
                accentColor: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Audit LSV',
          required: true,
          options: _pspLsvOpts,
          value: roguing.lsv,
          onChanged: (v) => setState(() => roguing.lsv = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Crop Health',
          required: true,
          options: _vegCropHealthOpts,
          value: roguing.cropHealth,
          onChanged: (v) => setState(() => roguing.cropHealth = v),
          accentColor: color,
        ),
        const SizedBox(height: 14),
        GenOptionPicker(
          label: 'Crop Uniformity',
          required: true,
          options: _vegCropUniformityOpts,
          value: roguing.cropUniformity,
          onChanged: (v) => setState(() => roguing.cropUniformity = v),
          accentColor: color,
        ),
      ],
    );
  }

  Widget _buildPspGenIsolationFields(
      _MassPspGenRoguingDraft roguing, Color color) {
    return Column(
      children: [
        GenOptionPicker(
          label: 'Isolation Audit',
          required: true,
          options: _pspYesNoOpts,
          value: roguing.isolationAudit,
          onChanged: (v) => setState(() => roguing.isolationAudit = v),
          accentColor: color,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GenOptionPicker(
                label: 'Isolation Type',
                options: _pspIsolationTypeOpts,
                value: roguing.isolationType,
                onChanged: (v) => setState(() => roguing.isolationType = v),
                accentColor: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GenOptionPicker(
                label: 'Isolation Distance',
                options: _pspIsolationDistanceOpts,
                value: roguing.isolationDistance,
                onChanged: (v) => setState(() => roguing.isolationDistance = v),
                accentColor: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildHarvestPspFields() {
    return [
      GenSection(
        title: 'Penilaian Harvest',
        icon: Icons.agriculture_outlined,
        color: _kHarv,
        children: [
          GenOptionPicker(
            label: 'Ear Condition',
            required: true,
            options: _harvEarCondOpts,
            value: _harvEarCondition,
            onChanged: (v) => setState(() => _harvEarCondition = v),
            accentColor: _kHarv,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Health',
            required: true,
            options: _harvCropHealthOpts,
            value: _harvCropHealth,
            onChanged: (v) => setState(() => _harvCropHealth = v),
            accentColor: _kHarv,
          ),
          const SizedBox(height: 14),
          GenTextField(
            controller: _harvRemarksCtrl,
            label: 'Remarks',
            maxLines: 4,
            icon: Icons.edit_note_outlined,
            accentColor: _kHarv,
          ),
        ],
      ),
    ];
  }

  Widget _buildSowingRatio(BuildContext context, bool isDiscard) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor = isDark
        ? AdvantaColors.deepForest.withAlpha(200)
        : AdvantaColors.softGrey;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);

    InputDecoration decor(String lbl) => InputDecoration(
          labelText: lbl,
          labelStyle: TextStyle(color: subColor, fontSize: 12),
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF26A69A), width: 1.5)),
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
                validator: isDiscard
                    ? null
                    : (v) => (v == null || v.trim().isEmpty) ? 'Wajib' : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(':',
                  style: AdvantaText.heading2.copyWith(color: subColor)),
            ),
            Expanded(
              child: TextFormField(
                controller: _vegSowingRatioMCtrl,
                keyboardType: TextInputType.number,
                decoration: decor('Male'),
                validator: isDiscard
                    ? null
                    : (v) => (v == null || v.trim().isEmpty) ? 'Wajib' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── GENERATIVE 1 (FC score, SC disease percentage) ────────
  List<Widget> _buildGen1Fields({required bool isSweetCorn}) {
    final isD = genIsDiscardFull(_gen1ActionNeeded);
    return [
      GenSection(
        title: 'Penilaian Readiness',
        icon: Icons.checklist_outlined,
        color: _kGen1,
        children: [
          GenOptionPicker(
            label: 'Readiness Status',
            required: !isD,
            options: _genReadinessOpts,
            value: _gen1Readiness,
            onChanged: (v) => setState(() => _gen1Readiness = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Roguing Status',
            required: !isD,
            options: _genRoguingOpts,
            value: _gen1Roguing,
            onChanged: (v) => setState(() => _gen1Roguing = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status',
            required: !isD,
            options: _genLsvOpts,
            value: _gen1Lsv,
            onChanged: (v) => setState(() => _gen1Lsv = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _genCropUniformityOpts,
            value: _gen1CropUniformity,
            onChanged: (v) => setState(() => _gen1CropUniformity = v),
            accentColor: _kGen1,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: isSweetCorn
                ? 'Crop Health (Bulai, Hawar) % dari Populasi'
                : 'Crop Health',
            required: !isD,
            options: isSweetCorn ? _genCropHealthSCOpts : _genCropHealthFCOpts,
            value: _gen1CropHealth,
            onChanged: (v) => setState(() => _gen1CropHealth = v),
            accentColor: _kGen1,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Action Needed',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPickerLong(
            label: 'Action Needed',
            required: true,
            options: _genActionNeededOpts,
            value: _gen1ActionNeeded,
            onChanged: (v) => setState(() => _gen1ActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message:
                  'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
            ),
          ],
        ],
      ),
    ];
  }

  // ── GENERATIVE 2 (FC score, SC disease percentage) ────────
  List<Widget> _buildGen2Fields({required bool isSweetCorn}) {
    final isD = genIsDiscardFull(_gen2ActionNeeded);
    return [
      GenSection(
        title: 'Penilaian Process',
        icon: Icons.grass_outlined,
        color: _kGen2,
        children: [
          GenOptionPicker(
            label: 'Female Shedding',
            required: !isD,
            options: _genFemaleShedOpts,
            value: _gen2FemaleShed,
            onChanged: (v) => setState(() => _gen2FemaleShed = v),
            accentColor: _kGen2,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen2OfftypeM,
                  onChanged: (v) => setState(() => _gen2OfftypeM = v),
                  accentColor: _kGen2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen2OfftypeF,
                  onChanged: (v) => setState(() => _gen2OfftypeF = v),
                  accentColor: _kGen2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status',
            required: !isD,
            options: _genLsvOpts,
            value: _gen2Lsv,
            onChanged: (v) => setState(() => _gen2Lsv = v),
            accentColor: _kGen2,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _genCropUniformityOpts,
            value: _gen2CropUniformity,
            onChanged: (v) => setState(() => _gen2CropUniformity = v),
            accentColor: _kGen2,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: isSweetCorn
                ? 'Crop Health (Bulai, Hawar) % dari Populasi'
                : 'Crop Health',
            required: !isD,
            options: isSweetCorn ? _genCropHealthSCOpts : _genCropHealthFCOpts,
            value: _gen2CropHealth,
            onChanged: (v) => setState(() => _gen2CropHealth = v),
            accentColor: _kGen2,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Action Needed',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPickerLong(
            label: 'Action Needed',
            required: true,
            options: _genActionNeededOpts,
            value: _gen2ActionNeeded,
            onChanged: (v) => setState(() => _gen2ActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message:
                  'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
            ),
          ],
        ],
      ),
    ];
  }

  // ── GENERATIVE 3 (FC score, SC disease percentage) ────────
  List<Widget> _buildGen3Fields(
    BuildContext context, {
    required bool isSweetCorn,
  }) {
    final isD = genIsDiscardDecision(_gen3FinalDecision);
    return [
      GenSection(
        title: 'Penilaian Final',
        icon: Icons.grass_outlined,
        color: _kGen3,
        children: [
          GenOptionPicker(
            label: 'Female Shedding',
            required: !isD,
            options: _genFemaleShedOpts,
            value: _gen3FemaleShed,
            onChanged: (v) => setState(() => _gen3FemaleShed = v),
            accentColor: _kGen3,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen3OfftypeM,
                  onChanged: (v) => setState(() => _gen3OfftypeM = v),
                  accentColor: _kGen3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen3OfftypeF,
                  onChanged: (v) => setState(() => _gen3OfftypeF = v),
                  accentColor: _kGen3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status',
            required: !isD,
            options: _genLsvOpts,
            value: _gen3Lsv,
            onChanged: (v) => setState(() => _gen3Lsv = v),
            accentColor: _kGen3,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _genCropUniformityOpts,
            value: _gen3CropUniformity,
            onChanged: (v) => setState(() => _gen3CropUniformity = v),
            accentColor: _kGen3,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: isSweetCorn
                ? 'Crop Health (Bulai, Hawar) % dari Populasi'
                : 'Crop Health',
            required: !isD,
            options: isSweetCorn ? _genCropHealthSCOpts : _genCropHealthFCOpts,
            value: _gen3CropHealth,
            onChanged: (v) => setState(() => _gen3CropHealth = v),
            accentColor: _kGen3,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Detasseling & Isolasi',
        icon: Icons.agriculture_outlined,
        color: const Color(0xFFAB47BC),
        children: [
          GenOptionPicker(
            label: 'Detasseling Assessment',
            required: !isD,
            options: _genDetasselingOpts,
            value: _gen3Detasseling,
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
                  options: _genIsolationOpts,
                  value: _gen3IsolationStatus,
                  onChanged: (v) => setState(() => _gen3IsolationStatus = v),
                  accentColor: const Color(0xFFAB47BC),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Affected Other Field',
                  options: _genAffectedOpts,
                  value: _gen3AffectedOther,
                  onChanged: (v) => setState(() => _gen3AffectedOther = v),
                  accentColor: const Color(0xFFAB47BC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenDateTileNullable(
            label: 'Closed Out Date (Opsional)',
            date: _gen3ClosedOutDate,
            onTap: _pickGen3ClosedDate,
            onClear: () => setState(() => _gen3ClosedOutDate = null),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Flagging',
        icon: Icons.flag_outlined,
        color: const Color(0xFF42A5F5),
        children: [
          GenOptionPicker(
            label: 'Flagging',
            required: true,
            options: _genFlaggingOpts,
            value: _gen3Flagging,
            onChanged: (v) => setState(() => _gen3Flagging = v),
            accentColor: const Color(0xFF42A5F5),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Keputusan Final',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPicker(
            label: 'Final Decision',
            required: true,
            options: _genFinalDecisionOpts,
            value: _gen3FinalDecision,
            onChanged: (v) => setState(() {
              _gen3FinalDecision = v;
              if (!genIsDiscardDecision(v)) {
                _gen3DiscardAreaCtrl.clear();
                _gen3DiscardReasonCtrl.clear();
              }
            }),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 14),
            const GenDiscardBanner(
              message:
                  'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
            ),
            const SizedBox(height: 14),
            GenTextField(
              controller: _gen3DiscardAreaCtrl,
              label: 'Discard Area (Ha)',
              hint: 'Luas area discard',
              required: true,
              keyboardType: TextInputType.number,
              icon: Icons.crop_landscape_outlined,
              accentColor: AdvantaColors.error,
            ),
            const SizedBox(height: 12),
            GenTextField(
              controller: _gen3DiscardReasonCtrl,
              label: 'Discard Reason',
              hint: 'Alasan discard...',
              required: true,
              maxLines: 3,
              icon: Icons.notes_outlined,
              accentColor: AdvantaColors.error,
            ),
          ],
        ],
      ),
    ];
  }

  // ── GENERATIVE 4 (SC Only — Crop Health: 0%–5%) ───────────
  List<Widget> _buildGen4Fields() {
    final color = Colors.purple;
    final isD = genIsDiscardFull(_gen4ActionNeeded);
    return [
      GenSection(
        title: 'Penilaian Audit (SC CP4)',
        icon: Icons.spa_outlined,
        color: color,
        children: [
          GenOptionPicker(
            label: 'Female Shedding',
            required: !isD,
            options: _genFemaleShedOpts,
            value: _gen4FemaleShed,
            onChanged: (v) => setState(() => _gen4FemaleShed = v),
            accentColor: color,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen4OfftypeM,
                  onChanged: (v) => setState(() => _gen4OfftypeM = v),
                  accentColor: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen4OfftypeF,
                  onChanged: (v) => setState(() => _gen4OfftypeF = v),
                  accentColor: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status',
            required: !isD,
            options: _genLsvOpts,
            value: _gen4Lsv,
            onChanged: (v) => setState(() => _gen4Lsv = v),
            accentColor: color,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _genCropUniformityOpts,
            value: _gen4CropUniformity,
            onChanged: (v) => setState(() => _gen4CropUniformity = v),
            accentColor: color,
          ),
          const SizedBox(height: 14),
          // SC: Crop Health = 0%–5%
          GenOptionPicker(
            label: 'Crop Health (SC)',
            required: !isD,
            options: _genCropHealthSCOpts,
            value: _gen4CropHealth,
            onChanged: (v) => setState(() => _gen4CropHealth = v),
            accentColor: color,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Action Needed',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPickerLong(
            label: 'Action Needed',
            required: true,
            options: _genActionNeededOpts,
            value: _gen4ActionNeeded,
            onChanged: (v) => setState(() => _gen4ActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message:
                  'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
            ),
          ],
        ],
      ),
    ];
  }

  // ── GENERATIVE 5 (SC Only — Crop Health: 0%–5%) ───────────
  List<Widget> _buildGen5Fields() {
    final color = Colors.pink;
    final isD = genIsDiscardFull(_gen5ActionNeeded);
    return [
      GenSection(
        title: 'Penilaian Audit (SC CP5)',
        icon: Icons.spa_outlined,
        color: color,
        children: [
          GenOptionPicker(
            label: 'Female Shedding',
            required: !isD,
            options: _genFemaleShedOpts,
            value: _gen5FemaleShed,
            onChanged: (v) => setState(() => _gen5FemaleShed = v),
            accentColor: color,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype M',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen5OfftypeM,
                  onChanged: (v) => setState(() => _gen5OfftypeM = v),
                  accentColor: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GenOptionPicker(
                  label: 'Offtype F',
                  required: !isD,
                  options: _genOfftypeOpts,
                  value: _gen5OfftypeF,
                  onChanged: (v) => setState(() => _gen5OfftypeF = v),
                  accentColor: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'LSV Status',
            required: !isD,
            options: _genLsvOpts,
            value: _gen5Lsv,
            onChanged: (v) => setState(() => _gen5Lsv = v),
            accentColor: color,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _genCropUniformityOpts,
            value: _gen5CropUniformity,
            onChanged: (v) => setState(() => _gen5CropUniformity = v),
            accentColor: color,
          ),
          const SizedBox(height: 14),
          // SC: Crop Health = 0%–5%
          GenOptionPicker(
            label: 'Crop Health (SC)',
            required: !isD,
            options: _genCropHealthSCOpts,
            value: _gen5CropHealth,
            onChanged: (v) => setState(() => _gen5CropHealth = v),
            accentColor: color,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Action Needed',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPickerLong(
            label: 'Action Needed',
            required: true,
            options: _genActionNeededOpts,
            value: _gen5ActionNeeded,
            onChanged: (v) => setState(() => _gen5ActionNeeded = v),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message:
                  'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
            ),
          ],
        ],
      ),
    ];
  }

  // ── PRE-HARVEST ───────────────────────────────────────────
  List<Widget> _buildPreHarvestFields({required bool isSweetCorn}) {
    final isD = genIsDiscardDecision(_preHFinalDecision);
    return [
      GenSection(
        title: 'Penilaian Pre-Harvest',
        icon: Icons.checklist_outlined,
        color: _kPreH,
        children: [
          GenOptionPicker(
            label: 'Male Chopping (Rows)',
            required: !isD,
            options: _preHMaleChoppingOpts,
            value: _preHMaleChopping,
            onChanged: (v) => setState(() => _preHMaleChopping = v),
            accentColor: _kPreH,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: !isD,
            options: _preHCropUniformityOpts,
            value: _preHCropUniformity,
            onChanged: (v) => setState(() => _preHCropUniformity = v),
            accentColor: _kPreH,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: isSweetCorn
                ? 'Crop Health (Bulai, Hawar) % dari Populasi'
                : 'Crop Health',
            required: !isD,
            options: isSweetCorn ? _genCropHealthSCOpts : _preHCropHealthOpts,
            value: _preHCropHealth,
            onChanged: (v) => setState(() => _preHCropHealth = v),
            accentColor: _kPreH,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Flagging',
        icon: Icons.flag_outlined,
        color: const Color(0xFF42A5F5),
        children: [
          GenOptionPicker(
            label: 'Final Flagging',
            required: true,
            options: _preHFinalFlaggingOpts,
            value: _preHFinalFlagging,
            onChanged: (v) => setState(() => _preHFinalFlagging = v),
            accentColor: const Color(0xFF42A5F5),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GenSection(
        title: 'Keputusan Final',
        icon: Icons.gavel_outlined,
        color: AdvantaColors.error,
        children: [
          GenOptionPicker(
            label: 'Final Decision',
            required: true,
            options: _preHFinalDecisionOpts,
            value: _preHFinalDecision,
            onChanged: (v) => setState(() {
              _preHFinalDecision = v;
              if (!genIsDiscardDecision(v)) {
                _preHDiscardAreaCtrl.clear();
                _preHDiscardReasonCtrl.clear();
              }
            }),
            accentColor: AdvantaColors.error,
          ),
          if (isD) ...[
            const SizedBox(height: 12),
            const GenDiscardBanner(
              message:
                  'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
            ),
            const SizedBox(height: 14),
            GenTextField(
              controller: _preHDiscardAreaCtrl,
              label: 'Discard Area (Ha)',
              hint: 'Luas area discard',
              required: true,
              keyboardType: TextInputType.number,
              icon: Icons.crop_landscape_outlined,
              accentColor: AdvantaColors.error,
            ),
            const SizedBox(height: 12),
            GenTextField(
              controller: _preHDiscardReasonCtrl,
              label: 'Discard Reason',
              hint: 'Alasan discard...',
              required: true,
              maxLines: 3,
              icon: Icons.notes_outlined,
              accentColor: AdvantaColors.error,
            ),
          ],
        ],
      ),
    ];
  }

  // ── HARVEST ───────────────────────────────────────────────
  List<Widget> _buildHarvestFields(
    BuildContext context, {
    required bool isSweetCorn,
  }) {
    return [
      GenSection(
        title: 'Penilaian Harvest',
        icon: Icons.agriculture_outlined,
        color: _kHarv,
        children: [
          GenOptionPicker(
            label: 'Ear Condition (Maturity)',
            required: true,
            options: _harvEarCondOpts,
            value: _harvEarCondition,
            onChanged: (v) => setState(() => _harvEarCondition = v),
            accentColor: _kHarv,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: 'Crop Uniformity',
            required: true,
            options: _harvCropUniformityOpts,
            value: _harvCropUniformity,
            onChanged: (v) => setState(() => _harvCropUniformity = v),
            accentColor: _kHarv,
          ),
          const SizedBox(height: 14),
          GenOptionPicker(
            label: isSweetCorn
                ? 'Crop Health (Bulai, Hawar) % dari Populasi'
                : 'Crop Health',
            required: true,
            options: isSweetCorn ? _genCropHealthSCOpts : _harvCropHealthOpts,
            value: _harvCropHealth,
            onChanged: (v) => setState(() => _harvCropHealth = v),
            accentColor: _kHarv,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildHarvDowngradeSection(context),
      const SizedBox(height: 12),
      GenSection(
        title: 'Final Flagging',
        icon: Icons.flag_outlined,
        color: const Color(0xFF42A5F5),
        children: [
          GenOptionPicker(
            label: 'Final Flagging',
            required: true,
            options: _harvFinalFlaggingOpts,
            value: _harvFinalFlagging,
            onChanged: (v) => setState(() => _harvFinalFlagging = v),
            accentColor: const Color(0xFF42A5F5),
          ),
        ],
      ),
    ];
  }

  Widget _buildHarvDowngradeSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor = isDark
        ? AdvantaColors.deepForest.withAlpha(200)
        : AdvantaColors.softGrey;
    const accentColor = Color(0xFFAB47BC);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _harvShowDowngrade
              ? accentColor.withValues(alpha: 0.60)
              : borderColor,
        ),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () =>
                setState(() => _harvShowDowngrade = !_harvShowDowngrade),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.swap_vert_outlined,
                      color: _harvShowDowngrade
                          ? const Color(0xFFCE93D8)
                          : subColor,
                      size: 14),
                  const SizedBox(width: 8),
                  Text('DOWNGRADE FLAGGING',
                      style: AdvantaText.caption.copyWith(
                        color: _harvShowDowngrade
                            ? const Color(0xFFCE93D8)
                            : subColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      )),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _harvShowDowngrade
                          ? accentColor.withValues(alpha: 0.15)
                          : fillColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _harvShowDowngrade
                            ? accentColor.withValues(alpha: 0.50)
                            : borderColor,
                      ),
                    ),
                    child: Text('Opsional',
                        style: AdvantaText.caption.copyWith(
                          color: _harvShowDowngrade
                              ? const Color(0xFFCE93D8)
                              : subColor,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _harvShowDowngrade
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: subColor,
                    size: 18,
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
                    label: 'Tanggal Downgrade Flagging',
                    date: _harvDowngradeFlagDate,
                    onTap: _pickHarvDowngradeDate,
                    onClear: () =>
                        setState(() => _harvDowngradeFlagDate = null),
                  ),
                  const SizedBox(height: 14),
                  GenOptionPicker(
                    label: 'Status Downgrade',
                    options: _harvStatusDowngradeOpts,
                    value: _harvStatusDowngrade,
                    onChanged: (v) => setState(() => _harvStatusDowngrade = v),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 14),
                  GenOptionPickerLong(
                    label: 'Reason Downgrade',
                    options: _harvReasonDowngradeOpts,
                    value: _harvReasonDowngrade,
                    onChanged: (v) => setState(() => _harvReasonDowngrade = v),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 14),
                  GenOptionPicker(
                    label: 'Downgrade Flagging',
                    required: true,
                    options: _harvDowngradeFlaggingOpts,
                    value: _harvDowngradeFlagging,
                    onChanged: (v) =>
                        setState(() => _harvDowngradeFlagging = v),
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
  Widget _buildSaveBar(
    BuildContext context,
    List<Map<String, dynamic>> selectedFields, {
    bool disabled = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? AdvantaColors.primaryGreen : Colors.white;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final progColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.mutedGrey;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: surfaceBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isSaving
            ? Center(
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
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
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: selectedFields.isNotEmpty && !disabled
                      ? () => _submitBulk(selectedFields)
                      : null,
                  icon: Icon(
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
                    backgroundColor: _isDiscard
                        ? AdvantaColors.error
                        : AdvantaColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AdvantaColors.mutedGrey.withAlpha(51),
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AdvantaRadius.buttonRadius),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MassPspRoguingDraft {
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

  _MassPspRoguingDraft(this.number);

  void dispose() {}

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'date_of_inspeksi_roguing_$number':
          date == null ? null : DateFormat('yyyy-MM-dd').format(date!),
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
}

class _MassPspGenRoguingDraft {
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

  _MassPspGenRoguingDraft(this.number);

  void dispose() {}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AdvantaColors.deepForest : AdvantaColors.softGrey;
    final borderColor =
        isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 34,
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AdvantaColors.error.withAlpha(31),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AdvantaColors.error.withAlpha(77)),
              ),
              child:
                  const Icon(Icons.close, color: Color(0xFFEF9A9A), size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
