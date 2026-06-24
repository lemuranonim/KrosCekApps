import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum PhaseIsoType { vegetative, preHarvest, harvest }

class PhaseIsoExportData {
  final Map<String, dynamic> fieldData;
  final PhaseIsoType phase;

  const PhaseIsoExportData({
    required this.fieldData,
    required this.phase,
  });
}

class PhaseIsoExportService {
  static const _advantaLogoAsset = 'assets/advanta-logo.png';
  static const _green = Color(0xFF004822);
  static const _line = Color(0xFF8E9892);
  static const _ink = Color(0xFF101915);
  static const _risk = Color(0xFFE53935);
  static const _warn = Color(0xFFF6C400);
  static const _ok = Color(0xFF0B6D25);
  static const _okFill = Color(0xFFE2F2DF);
  static const _riskFill = Color(0xFFFFE9D4);
  static const _warnFill = Color(0xFFFFF1C2);

  static bool hasAuditData(Map<String, dynamic> fieldData, PhaseIsoType phase) {
    final audit = _auditFor(fieldData, phase);
    if (audit == null || audit.isEmpty) return false;
    final date = switch (phase) {
      PhaseIsoType.vegetative =>
        audit['audit_date_user'] ?? audit['date_of_audit'],
      PhaseIsoType.preHarvest => audit['audit_date'],
      PhaseIsoType.harvest => audit['date_of_audit'],
    };
    return _readText(date, fallback: '').isNotEmpty;
  }

  static String phaseLabel(PhaseIsoType phase) {
    return switch (phase) {
      PhaseIsoType.vegetative => 'Vegetative',
      PhaseIsoType.preHarvest => 'Pre-Harvest',
      PhaseIsoType.harvest => 'Harvest',
    };
  }

  static Future<String> downloadPicture(PhaseIsoExportData data) async {
    final bytes = await buildPng(data);
    return _saveBytes(
      bytes: bytes,
      fileName: _fileName(data, 'png'),
      mimeType: 'image/png',
    );
  }

  static Future<String> downloadPdf(PhaseIsoExportData data) async {
    final png = await buildPng(data);
    final doc = pw.Document();
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );

    return _saveBytes(
      bytes: await doc.save(),
      fileName: _fileName(data, 'pdf'),
      mimeType: 'application/pdf',
    );
  }

  static Future<Uint8List> buildPng(PhaseIsoExportData data) async {
    const width = 1800.0;
    const height = 1280.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );
    _drawBorder(
      canvas,
      const Rect.fromLTWH(8, 8, width - 16, height - 16),
      _line,
      1.2,
    );

    final snapshot = _PhaseIsoSnapshot.from(data);
    final logo = await _loadUiImage(_advantaLogoAsset);

    _drawHeader(canvas, snapshot, logo);
    _drawIdentity(canvas, snapshot);
    _drawAuditProfile(canvas, snapshot);
    _drawResultPanel(canvas, snapshot);
    _drawFnDetail(canvas, snapshot);
    _drawSummary(canvas, snapshot);
    _drawLegend(canvas, snapshot);
    _drawSignatures(canvas);
    _drawFooter(canvas, snapshot);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawHeader(
    Canvas canvas,
    _PhaseIsoSnapshot s,
    ui.Image? logo,
  ) {
    if (logo != null) {
      _drawImageContain(
        canvas,
        logo,
        const Rect.fromLTWH(32, 22, 182, 70),
      );
    } else {
      _text(
        canvas,
        'ADVANTA',
        const Offset(36, 42),
        size: 30,
        weight: FontWeight.w900,
        color: _green,
      );
    }
    _textCentered(
      canvas,
      s.title,
      const Rect.fromLTWH(260, 26, 1280, 42),
      size: 33,
      weight: FontWeight.w900,
      color: Colors.black,
    );
    _drawFilledRect(canvas, const Rect.fromLTWH(18, 96, 1764, 5), _green);
  }

  static void _drawIdentity(Canvas canvas, _PhaseIsoSnapshot s) {
    final rect = s.phase == PhaseIsoType.vegetative
        ? const Rect.fromLTWH(20, 118, 370, 385)
        : const Rect.fromLTWH(20, 118, 500, 405);

    if (s.phase != PhaseIsoType.vegetative) {
      _sectionLabel(
        canvas,
        Rect.fromLTWH(rect.left, rect.top, rect.width, 44),
        'FIELD IDENTITY',
      );
    }

    final yStart = s.phase == PhaseIsoType.vegetative ? rect.top + 6 : rect.top + 58;
    final rows = <(String, String)>[
      ('Season', s.season),
      ('Week', s.week),
      ('Region', s.region),
      if (s.phase == PhaseIsoType.vegetative) ('Codet', s.codet),
      ('Crop', s.crop),
      if (s.phase == PhaseIsoType.vegetative) ('Village', s.village),
      ('Grower', s.grower),
      ('Farmer', s.farmer),
      ('Hybrid', s.hybrid),
      ('Field Number', s.fieldNumber),
      ('Effective Area Ha', '${_formatHa(s.effectiveAreaHa)} Ha'),
      if (s.phase == PhaseIsoType.vegetative)
        ('Ha Plant', '${_formatHa(s.totalAreaHa)} Ha'),
      ('Planting Date', _formatDate(s.plantingDate)),
      (s.phase == PhaseIsoType.vegetative ? 'DAP' : 'DAP / HST', '${s.dap} HST'),
      if (s.phase == PhaseIsoType.vegetative) ('Target Audit', s.targetAudit),
      if (s.phase == PhaseIsoType.vegetative) ('Field Stage', s.fieldStage),
    ];

    _drawTextRows(
      canvas,
      rows,
      x: rect.left + 2,
      y: yStart,
      labelW: s.phase == PhaseIsoType.vegetative ? 170 : 205,
      valueW: rect.width - (s.phase == PhaseIsoType.vegetative ? 210 : 250),
      rowH: s.phase == PhaseIsoType.vegetative ? 24 : 27,
      size: s.phase == PhaseIsoType.vegetative ? 16.5 : 17,
    );
    _drawBorder(canvas, rect, _line, 1.1);
  }

  static void _drawAuditProfile(Canvas canvas, _PhaseIsoSnapshot s) {
    final rect = s.phase == PhaseIsoType.vegetative
        ? const Rect.fromLTWH(420, 118, 710, 385)
        : const Rect.fromLTWH(540, 118, 800, 405);
    _drawBorder(canvas, rect, _green, 1.4);
    _sectionLabel(
      canvas,
      Rect.fromLTWH(rect.left, rect.top, rect.width, 48),
      'FIELD & AUDIT PROFILE',
    );

    final rowTop = rect.top + 48;
    final rowH = (rect.height - 48) / 5;
    final iconW = 78.0;
    final halfW = (rect.width - iconW) / 2;
    final icons = [
      Icons.calendar_today_rounded,
      Icons.person_rounded,
      s.phase == PhaseIsoType.vegetative
          ? Icons.person_add_alt_1_rounded
          : Icons.assignment_turned_in_rounded,
      Icons.warning_amber_rounded,
      Icons.settings_rounded,
    ];
    final rows = [
      (s.phase == PhaseIsoType.vegetative ? 'Audit Date' : 'Audit Date', s.auditDateLabel,
          'Week', s.week),
      ('Auditor (QA FI)', s.qaFi, 'QA SPV', s.qaSpv),
      (
        s.phase == PhaseIsoType.vegetative ? 'Actual DAP' : 'Audit Status',
        s.phase == PhaseIsoType.vegetative ? '${s.dap} DAP' : s.auditStatus,
        s.phase == PhaseIsoType.vegetative ? 'Target Audit' : '',
        s.phase == PhaseIsoType.vegetative ? s.targetAudit : ''
      ),
      ('Main Issue', s.mainIssue, '', ''),
      ('Action Needed', s.actionNeeded, '', ''),
    ];

    for (var i = 0; i < rows.length; i++) {
      final y = rowTop + i * rowH;
      if (i > 0) {
        _drawGridLine(canvas, Offset(rect.left, y), Offset(rect.right, y));
      }
      _drawGridLine(canvas, Offset(rect.left + iconW, y), Offset(rect.left + iconW, y + rowH));
      if (i < 3) {
        _drawGridLine(
          canvas,
          Offset(rect.left + iconW + halfW, y),
          Offset(rect.left + iconW + halfW, y + rowH),
        );
      }
      _drawMaterialIcon(
        canvas,
        icons[i],
        Rect.fromLTWH(rect.left + 24, y + 16, 30, 30),
        color: _green,
      );

      final row = rows[i];
      _profileCell(
        canvas,
        Rect.fromLTWH(rect.left + iconW, y, halfW, rowH),
        row.$1,
        row.$2,
        valueColor: (i >= 3 && s.statusLevel != _IsoStatus.pass) ? _risk : _ink,
      );
      if (i < 3) {
        _profileCell(
          canvas,
          Rect.fromLTWH(rect.left + iconW + halfW, y, halfW, rowH),
          row.$3,
          row.$4,
        );
      }
    }
  }

  static void _drawResultPanel(Canvas canvas, _PhaseIsoSnapshot s) {
    final rect = s.phase == PhaseIsoType.vegetative
        ? const Rect.fromLTWH(1155, 118, 625, 385)
        : const Rect.fromLTWH(1360, 118, 420, 405);

    if (s.phase == PhaseIsoType.vegetative) {
      final pld = Rect.fromLTWH(rect.left, rect.top, rect.width, 168);
      final accuracy = Rect.fromLTWH(rect.left, rect.top + 185, rect.width, 200);
      _drawBorder(canvas, pld, _green, 1.2);
      _sectionLabel(canvas, Rect.fromLTWH(pld.left, pld.top, pld.width, 44), 'PLD RECOMMENDATION');
      _drawLeafBadge(canvas, Offset(pld.left + 42, pld.top + 72), 64);
      _drawTextRows(
        canvas,
        [
          ('Recommended PLD', s.recommendedPldHa),
          ('PLD Status', s.pldStatus),
        ],
        x: pld.left + 165,
        y: pld.top + 78,
        labelW: 175,
        valueW: 230,
        rowH: 47,
        size: 17,
      );

      _drawBorder(canvas, accuracy, _green, 1.2);
      _sectionLabel(
        canvas,
        Rect.fromLTWH(accuracy.left, accuracy.top, accuracy.width, 44),
        'DATA ACCURACY SUMMARY',
      );
      _drawTextRows(
        canvas,
        [
          ('Tagging', s.taggingAccuracy),
          ('Koreksi Tanggal Tanam', s.plantingCorrection),
          ('Field Size', s.fieldSizeAccuracy),
        ],
        x: accuracy.left + 26,
        y: accuracy.top + 62,
        labelW: 265,
        valueW: 255,
        rowH: 45,
        size: 16.5,
      );
      return;
    }

    _drawBorder(canvas, rect, _green, 1.2);
    _textCentered(
      canvas,
      s.resultPanelTitle,
      Rect.fromLTWH(rect.left + 10, rect.top + 22, rect.width - 20, 30),
      size: 19,
      weight: FontWeight.w900,
      color: _green,
    );
    _drawClipboardBadge(canvas, Offset(rect.right - 84, rect.top + 34), 56);

    _textCentered(
      canvas,
      'Final Flagging',
      Rect.fromLTWH(rect.left + 20, rect.top + 88, rect.width - 40, 22),
      size: 17,
      weight: FontWeight.w600,
    );
    _textCentered(
      canvas,
      s.finalFlagging,
      Rect.fromLTWH(rect.left + 20, rect.top + 123, rect.width - 40, 42),
      size: 35,
      weight: FontWeight.w900,
      color: _statusColor(s.statusLevel),
    );
    _drawDottedLine(canvas, Offset(rect.left + 26, rect.top + 176), Offset(rect.right - 26, rect.top + 176));
    _textCentered(
      canvas,
      s.phase == PhaseIsoType.harvest ? 'Harvest Result' : 'Final Decision',
      Rect.fromLTWH(rect.left + 20, rect.top + 196, rect.width - 40, 24),
      size: 17,
      weight: FontWeight.w600,
    );
    _textCentered(
      canvas,
      s.resultDecision,
      Rect.fromLTWH(rect.left + 20, rect.top + 232, rect.width - 40, 42),
      size: 28,
      weight: FontWeight.w900,
      color: _statusColor(s.statusLevel),
    );
    _drawDottedLine(canvas, Offset(rect.left + 26, rect.top + 292), Offset(rect.right - 26, rect.top + 292));
    _textCentered(
      canvas,
      'Status',
      Rect.fromLTWH(rect.left + 20, rect.top + 312, rect.width - 40, 23),
      size: 16,
      weight: FontWeight.w700,
    );
    final statusRect = Rect.fromLTWH(rect.left + 70, rect.top + 352, rect.width - 140, 46);
    _drawRoundedFill(canvas, statusRect, _statusFill(s.statusLevel), 8);
    _textCentered(
      canvas,
      s.statusText,
      statusRect,
      size: 25,
      weight: FontWeight.w900,
      color: _statusColor(s.statusLevel),
    );
  }

  static void _drawFnDetail(Canvas canvas, _PhaseIsoSnapshot s) {
    final rect = const Rect.fromLTWH(20, 540, 1760, 150);
    _drawBorder(canvas, rect, _green, 1.2);
    _sectionLabel(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, 38), 'FN OBSERVATION DETAIL');

    final isVeg = s.phase == PhaseIsoType.vegetative;
    final labels = isVeg
        ? ['FN', 'Farmer', 'Village', 'Ha Plant (Ha)', 'Planting Date', 'DAP', 'Hybrid', 'Field Stage', 'Audit Result', 'Action / Remarks']
        : ['FN', 'Farmer', 'Grower', 'Effective Area', 'Planting Date', 'HST', 'Hybrid', 'Audit Result', 'Action / Remarks'];
    final widths = isVeg
        ? [145.0, 170.0, 150.0, 160.0, 170.0, 125.0, 145.0, 155.0, 170.0, 370.0]
        : [170.0, 210.0, 245.0, 180.0, 205.0, 125.0, 150.0, 150.0, 325.0];
    final values = isVeg
        ? [
            s.fieldNumber,
            s.farmer,
            s.village,
            '${_formatHa(s.totalAreaHa)} Ha',
            _formatDate(s.plantingDate),
            s.dap.toString(),
            s.hybrid,
            s.fieldStage,
            s.statusText.titleCase,
            s.remarks,
          ]
        : [
            s.fieldNumber,
            s.farmer,
            s.grower,
            '${_formatHa(s.effectiveAreaHa)} Ha',
            _formatDate(s.plantingDate),
            s.dap.toString(),
            s.hybrid,
            s.statusText.titleCase,
            s.remarks,
          ];

    _drawTableHeader(canvas, rect.left, rect.top + 38, widths, labels);
    _drawTableRow(canvas, rect.left, rect.top + 78, widths, 72, values, ratingIndex: labels.indexOf('Audit Result'), status: s.statusLevel);
  }

  static void _drawSummary(Canvas canvas, _PhaseIsoSnapshot s) {
    final left = const Rect.fromLTWH(20, 710, 1285, 335);
    final right = const Rect.fromLTWH(1328, 710, 452, 335);

    _drawBorder(canvas, left, _green, 1.2);
    _sectionLabel(canvas, Rect.fromLTWH(left.left, left.top, left.width, 38), 'INSPECTION RESULTS SUMMARY');

    if (s.phase == PhaseIsoType.vegetative) {
      _drawVegetativeSummary(canvas, s, left);
    } else {
      _drawSingleSummary(canvas, s, left);
    }

    _drawFinalStatus(canvas, s, right);
  }

  static void _drawVegetativeSummary(Canvas canvas, _PhaseIsoSnapshot s, Rect rect) {
    final metaTop = rect.top + 46;
    final meta = [
      ('Audit Date', s.auditDateLabel),
      ('Week', s.week),
      ('Auditor (QA FI)', s.qaFi),
      ('QA SPV', s.qaSpv),
    ];
    var x = rect.left + 10;
    final widths = [255.0, 200.0, 340.0, 470.0];
    for (var i = 0; i < meta.length; i++) {
      final r = Rect.fromLTWH(x, metaTop, widths[i] - 8, 34);
      _drawRoundedPanel(canvas, r, const Color(0xFFF8FAF8), _line, 4);
      _text(canvas, '${meta[i].$1}:', Offset(r.left + 12, r.top + 10), size: 13, weight: FontWeight.w800);
      _text(canvas, meta[i].$2, Offset(r.left + 105, r.top + 10), size: 13, weight: FontWeight.w700, maxWidth: r.width - 115, maxLines: 1);
      x += widths[i];
    }

    final tableTop = rect.top + 94;
    final leftTable = Rect.fromLTWH(rect.left + 10, tableTop, 705, 230);
    final rightTable = Rect.fromLTWH(rect.left + 730, tableTop, 545, 230);

    _drawSubTitle(canvas, Rect.fromLTWH(leftTable.left, leftTable.top, leftTable.width, 30), 'A. LEADING INDICATOR RESULTS');
    _drawAssessmentTable(
      canvas,
      Rect.fromLTWH(leftTable.left, leftTable.top + 30, leftTable.width, leftTable.height - 30),
      ['No.', 'Indicator / Item', 'Result / Status', 'Rating'],
      [55, 280, 210, 160],
      s.vegetativeRows,
    );

    _drawSubTitle(canvas, Rect.fromLTWH(rightTable.left, rightTable.top, rightTable.width, 30), 'B. DATA ACCURACY / CORRECTION RESULTS');
    _drawAssessmentTable(
      canvas,
      Rect.fromLTWH(rightTable.left, rightTable.top + 30, rightTable.width, rightTable.height - 30),
      ['No.', 'Correction Item', 'Result / Status', 'Rating'],
      [55, 215, 220, 155],
      s.accuracyRows,
    );
  }

  static void _drawSingleSummary(Canvas canvas, _PhaseIsoSnapshot s, Rect rect) {
    _drawSubTitle(
      canvas,
      Rect.fromLTWH(rect.left, rect.top + 38, rect.width, 34),
      s.phase == PhaseIsoType.harvest
          ? 'A. HARVEST ASSESSMENT RESULT'
          : 'A. PRE-HARVEST ASSESSMENT RESULT',
    );
    _drawAssessmentTable(
      canvas,
      Rect.fromLTWH(rect.left, rect.top + 72, rect.width, 185),
      ['No.', 'Assessment Item', 'Result / Status', 'Rating'],
      [105, 520, 330, 330],
      s.assessmentRows,
    );

    final remarksRect = Rect.fromLTWH(rect.left, rect.top + 267, rect.width, 68);
    _sectionLabel(canvas, Rect.fromLTWH(remarksRect.left, remarksRect.top, remarksRect.width, 30), 'REMARKS');
    _textInRect(
      canvas,
      s.remarks,
      Rect.fromLTWH(remarksRect.left + 40, remarksRect.top + 36, remarksRect.width - 80, 28),
      size: 14,
      weight: FontWeight.w600,
      textAlign: TextAlign.center,
      maxLines: 2,
    );
  }

  static void _drawFinalStatus(Canvas canvas, _PhaseIsoSnapshot s, Rect rect) {
    _drawBorder(canvas, rect, _green, 1.2);
    _sectionLabel(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, 38), 'FINAL STATUS');
    final box = Rect.fromLTWH(rect.left + 28, rect.top + 66, rect.width - 56, 88);
    _drawRoundedPanel(canvas, box, Colors.white, _green, 8);
    _textCentered(
      canvas,
      s.statusText,
      box,
      size: s.statusText.length > 7 ? 48 : 62,
      weight: FontWeight.w900,
      color: _statusColor(s.statusLevel),
    );
    _textCentered(
      canvas,
      'Action Needed:',
      Rect.fromLTWH(rect.left + 30, rect.top + 178, rect.width - 60, 28),
      size: 20,
      weight: FontWeight.w900,
    );
    _textInRect(
      canvas,
      s.actionNeeded,
      Rect.fromLTWH(rect.left + 42, rect.top + 217, rect.width - 84, 72),
      size: 18,
      weight: FontWeight.w600,
      textAlign: TextAlign.center,
      maxLines: 3,
    );
  }

  static void _drawLegend(Canvas canvas, _PhaseIsoSnapshot s) {
    final rect = const Rect.fromLTWH(20, 1060, 1760, 58);
    _drawBorder(canvas, rect, _line, 1);
    final items = [
      (_IsoStatus.pass, 'CONFORMANCE', '= Requirement met'),
      (_IsoStatus.atRisk, 'AT RISK', '= Attention / Improvement needed'),
      (_IsoStatus.nc, 'NC', '= Non Conformance'),
      if (s.phase == PhaseIsoType.vegetative)
        (_IsoStatus.pld, 'PLD RECOMMENDATION', '= Planned / discard recommendation review'),
    ];
    final w = rect.width / items.length;
    for (var i = 0; i < items.length; i++) {
      final x = rect.left + i * w;
      if (i > 0) {
        _drawGridLine(canvas, Offset(x, rect.top + 8), Offset(x, rect.bottom - 8));
      }
      final item = items[i];
      _drawLegendIcon(canvas, Offset(x + 55, rect.top + 15), item.$1);
      _text(canvas, item.$2, Offset(x + 105, rect.top + 13), size: 13.5, weight: FontWeight.w900);
      _text(canvas, item.$3, Offset(x + 105, rect.top + 33), size: 12.2, weight: FontWeight.w700);
    }
  }

  static void _drawSignatures(Canvas canvas) {
    final left = const Rect.fromLTWH(20, 1132, 860, 92);
    final right = const Rect.fromLTWH(900, 1132, 880, 92);
    _signatureBox(canvas, left, 'FA');
    _signatureBox(canvas, right, 'FI');
  }

  static void _drawFooter(Canvas canvas, _PhaseIsoSnapshot s) {
    final rect = const Rect.fromLTWH(20, 1238, 1760, 46);
    _drawBorder(canvas, rect, _line, 1);
    final widths = s.phase == PhaseIsoType.harvest
        ? [310.0, 250.0, 240.0, 360.0, 190.0, 410.0]
        : [280.0, 455.0, 270.0, 390.0, 195.0, 170.0];
    final texts = s.phase == PhaseIsoType.harvest
        ? [
            'Generated by KROSCEK',
            'Form ID',
            s.fieldNumber,
            'Doc Code    ${s.docCode}',
            'Rev.    00',
            'Page 1 of 1',
          ]
        : [
            'Generated by KROSCEK',
            'Field Inspection Output Form - ${s.phaseLabel} Audit',
            'Form ID    ${s.fieldNumber}',
            'Doc Code    ${s.docCode}',
            'Rev.    00',
            'Page 1 of 1',
          ];
    var x = rect.left;
    for (var i = 0; i < widths.length; i++) {
      if (i > 0) {
        _drawGridLine(canvas, Offset(x, rect.top), Offset(x, rect.bottom));
      }
      _textCentered(
        canvas,
        texts[i],
        Rect.fromLTWH(x + 8, rect.top + 5, widths[i] - 16, rect.height - 10),
        size: 15,
        weight: i == 0 || texts[i].contains(s.fieldNumber) ? FontWeight.w900 : FontWeight.w700,
        color: i == 0 || texts[i].contains(s.fieldNumber) ? _green : _ink,
      );
      x += widths[i];
    }
  }

  static void _profileCell(
    Canvas canvas,
    Rect rect,
    String label,
    String value, {
    Color valueColor = _ink,
  }) {
    if (label.isEmpty && value.isEmpty) return;
    _text(canvas, label, Offset(rect.left + 22, rect.top + rect.height / 2 - 10), size: 16, weight: FontWeight.w700);
    _text(canvas, ':', Offset(rect.left + 185, rect.top + rect.height / 2 - 10), size: 16, weight: FontWeight.w800);
    _text(
      canvas,
      value,
      Offset(rect.left + 215, rect.top + rect.height / 2 - 10),
      size: 16,
      weight: FontWeight.w800,
      color: valueColor,
      maxWidth: rect.width - 230,
      maxLines: 2,
    );
  }

  static void _drawAssessmentTable(
    Canvas canvas,
    Rect rect,
    List<String> headers,
    List<num> widths,
    List<_AssessmentRow> rows,
  ) {
    _drawBorder(canvas, rect, _line, 1);
    _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, 30), _green);
    var x = rect.left;
    for (var i = 0; i < headers.length; i++) {
      if (i > 0) _drawGridLine(canvas, Offset(x, rect.top), Offset(x, rect.bottom));
      _textCentered(
        canvas,
        headers[i],
        Rect.fromLTWH(x + 4, rect.top + 4, widths[i].toDouble() - 8, 22),
        size: 13.5,
        weight: FontWeight.w800,
        color: Colors.white,
      );
      x += widths[i].toDouble();
    }

    final rowH = (rect.height - 30) / rows.length;
    for (var r = 0; r < rows.length; r++) {
      final y = rect.top + 30 + r * rowH;
      _drawGridLine(canvas, Offset(rect.left, y), Offset(rect.right, y));
      final row = rows[r];
      final cells = [
        '${r + 1}',
        row.item,
        row.result,
        row.ratingLabel,
      ];
      x = rect.left;
      for (var c = 0; c < cells.length; c++) {
        final cell = Rect.fromLTWH(x, y, widths[c].toDouble(), rowH);
        if (c == cells.length - 1) {
          _drawFilledRect(canvas, cell.deflate(0.6), _ratingFill(row.rating));
        }
        _textInRect(
          canvas,
          cells[c],
          cell.deflate(5),
          size: 13.5,
          weight: c == 0 || c == 3 ? FontWeight.w900 : FontWeight.w600,
          color: c == 3 ? _ratingText(row.rating) : _ink,
          textAlign: c == 1 ? TextAlign.left : TextAlign.center,
          maxLines: 2,
        );
        x += widths[c].toDouble();
      }
    }
  }

  static void _drawTableHeader(
    Canvas canvas,
    double left,
    double top,
    List<double> widths,
    List<String> labels,
  ) {
    _drawFilledRect(canvas, Rect.fromLTWH(left, top, widths.fold(0, (a, b) => a + b), 40), _green);
    var x = left;
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) _drawGridLine(canvas, Offset(x, top), Offset(x, top + 112));
      _textCentered(canvas, labels[i], Rect.fromLTWH(x + 4, top + 8, widths[i] - 8, 22), size: 14.5, weight: FontWeight.w800, color: Colors.white);
      x += widths[i];
    }
    _drawGridLine(canvas, Offset(left, top + 40), Offset(left + widths.fold(0, (a, b) => a + b), top + 40));
  }

  static void _drawTableRow(
    Canvas canvas,
    double left,
    double top,
    List<double> widths,
    double height,
    List<String> values, {
    required int ratingIndex,
    required _IsoStatus status,
  }) {
    var x = left;
    for (var i = 0; i < values.length; i++) {
      final rect = Rect.fromLTWH(x, top, widths[i], height);
      _textInRect(
        canvas,
        values[i],
        rect.deflate(7),
        size: 15.5,
        weight: i == 0 || i == ratingIndex ? FontWeight.w900 : FontWeight.w600,
        color: i == ratingIndex ? _statusColor(status) : _ink,
        textAlign: TextAlign.center,
        maxLines: i == values.length - 1 ? 3 : 2,
      );
      x += widths[i];
    }
  }

  static void _signatureBox(Canvas canvas, Rect rect, String title) {
    _drawBorder(canvas, rect, _green, 1);
    _sectionLabel(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, 24), title, size: 13);
    var y = rect.top + 39;
    for (final label in ['Signature', 'Nama', 'Tanggal']) {
      _text(canvas, label, Offset(rect.left + 25, y), size: 12.5, weight: FontWeight.w700);
      _text(canvas, ':', Offset(rect.left + 150, y), size: 12.5, weight: FontWeight.w700);
      _drawGridLine(canvas, Offset(rect.left + 195, y + 11), Offset(rect.right - 140, y + 11));
      y += 24;
    }
  }

  static void _sectionLabel(Canvas canvas, Rect rect, String label, {double size = 18}) {
    _drawFilledRect(canvas, rect, _green);
    _textCentered(canvas, label, rect.deflate(4), size: size, weight: FontWeight.w900, color: Colors.white);
  }

  static void _drawSubTitle(Canvas canvas, Rect rect, String label) {
    _drawFilledRect(canvas, rect, const Color(0xFFE9F7EA));
    _drawBorder(canvas, rect, _green, 1);
    _textCentered(canvas, label, rect.deflate(4), size: 17, weight: FontWeight.w900, color: _green);
  }

  static void _drawTextRows(
    Canvas canvas,
    List<(String, String)> rows, {
    required double x,
    required double y,
    required double labelW,
    required double valueW,
    required double rowH,
    required double size,
  }) {
    for (var i = 0; i < rows.length; i++) {
      final dy = y + i * rowH;
      _text(canvas, rows[i].$1, Offset(x, dy), size: size, weight: FontWeight.w700, maxWidth: labelW, maxLines: 1);
      _text(canvas, ':', Offset(x + labelW, dy), size: size, weight: FontWeight.w900);
      _text(canvas, rows[i].$2, Offset(x + labelW + 30, dy), size: size, weight: FontWeight.w800, maxWidth: valueW, maxLines: 2);
    }
  }

  static void _drawLeafBadge(Canvas canvas, Offset origin, double size) {
    final rect = Rect.fromLTWH(origin.dx, origin.dy, size, size);
    canvas.drawOval(rect, Paint()..color = const Color(0xFFE9F6EC));
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _green,
    );
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = _green;
    canvas.drawLine(Offset(origin.dx + size * .5, origin.dy + size * .72), Offset(origin.dx + size * .5, origin.dy + size * .27), stem);
    final leaf = Path()
      ..moveTo(origin.dx + size * .5, origin.dy + size * .42)
      ..quadraticBezierTo(origin.dx + size * .15, origin.dy + size * .23, origin.dx + size * .22, origin.dy + size * .62)
      ..quadraticBezierTo(origin.dx + size * .42, origin.dy + size * .67, origin.dx + size * .5, origin.dy + size * .42);
    canvas.drawPath(leaf, Paint()..color = _green);
    final leaf2 = Path()
      ..moveTo(origin.dx + size * .51, origin.dy + size * .46)
      ..quadraticBezierTo(origin.dx + size * .82, origin.dy + size * .22, origin.dx + size * .78, origin.dy + size * .62)
      ..quadraticBezierTo(origin.dx + size * .58, origin.dy + size * .68, origin.dx + size * .51, origin.dy + size * .46);
    canvas.drawPath(leaf2, Paint()..color = _green);
  }

  static void _drawClipboardBadge(Canvas canvas, Offset origin, double size) {
    final rect = Rect.fromLTWH(origin.dx, origin.dy, size, size);
    canvas.drawOval(rect, Paint()..color = _green);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final board = RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx + size * .28, origin.dy + size * .22, size * .44, size * .56),
      const Radius.circular(5),
    );
    canvas.drawRRect(board, paint);
    canvas.drawLine(Offset(origin.dx + size * .39, origin.dy + size * .36), Offset(origin.dx + size * .61, origin.dy + size * .36), paint);
    canvas.drawLine(Offset(origin.dx + size * .39, origin.dy + size * .50), Offset(origin.dx + size * .61, origin.dy + size * .50), paint);
    canvas.drawLine(Offset(origin.dx + size * .39, origin.dy + size * .64), Offset(origin.dx + size * .54, origin.dy + size * .64), paint);
  }

  static void _drawMaterialIcon(
    Canvas canvas,
    IconData icon,
    Rect rect, {
    Color color = _green,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: color,
          fontSize: rect.height,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout(maxWidth: rect.width);
    painter.paint(canvas, Offset(rect.left, rect.top));
  }

  static void _drawLegendIcon(Canvas canvas, Offset origin, _IsoStatus status) {
    switch (status) {
      case _IsoStatus.pass:
        canvas.drawCircle(origin + const Offset(18, 18), 18, Paint()..color = _ok);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white;
        canvas.drawLine(origin + const Offset(9, 18), origin + const Offset(16, 26), p);
        canvas.drawLine(origin + const Offset(16, 26), origin + const Offset(28, 10), p);
        break;
      case _IsoStatus.atRisk:
        final path = Path()
          ..moveTo(origin.dx + 18, origin.dy)
          ..lineTo(origin.dx + 36, origin.dy + 34)
          ..lineTo(origin.dx, origin.dy + 34)
          ..close();
        canvas.drawPath(path, Paint()..color = _warn);
        _textCentered(canvas, '!', Rect.fromLTWH(origin.dx, origin.dy + 9, 36, 25), size: 23, weight: FontWeight.w900);
        break;
      case _IsoStatus.nc:
        canvas.drawCircle(origin + const Offset(18, 18), 18, Paint()..color = Colors.red);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white;
        canvas.drawLine(origin + const Offset(10, 10), origin + const Offset(26, 26), p);
        canvas.drawLine(origin + const Offset(26, 10), origin + const Offset(10, 26), p);
        break;
      case _IsoStatus.pld:
        _drawClipboardBadge(canvas, origin, 38);
        break;
    }
  }

  static void _drawFilledRect(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  static void _drawRoundedFill(Canvas canvas, Rect rect, Color color, double radius) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  static void _drawRoundedPanel(Canvas canvas, Rect rect, Color fill, Color border, double radius) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = border,
    );
  }

  static void _drawBorder(Canvas canvas, Rect rect, Color color, double width) {
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  static void _drawGridLine(Canvas canvas, Offset start, Offset end) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = 1
        ..color = _line,
    );
  }

  static void _drawDottedLine(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..strokeWidth = 1.3
      ..color = Colors.black.withAlpha(170);
    const dash = 4.0;
    const gap = 5.0;
    var x = start.dx;
    while (x < end.dx) {
      final next = (x + dash).clamp(start.dx, end.dx);
      canvas.drawLine(Offset(x, start.dy), Offset(next, end.dy), paint);
      x += dash + gap;
    }
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = _ink,
    double? maxWidth,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          height: 1.15,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    );
    painter.layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  static void _textCentered(
    Canvas canvas,
    String text,
    Rect rect, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = _ink,
  }) {
    _textInRect(
      canvas,
      text,
      rect,
      size: size,
      weight: weight,
      color: color,
      textAlign: TextAlign.center,
      maxLines: 2,
    );
  }

  static void _textInRect(
    Canvas canvas,
    String text,
    Rect rect, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = _ink,
    TextAlign textAlign = TextAlign.left,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          height: 1.12,
        ),
      ),
      textAlign: textAlign,
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    );
    painter.layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.left,
        rect.top + (rect.height - painter.height).clamp(0.0, rect.height) / 2,
      ),
    );
  }

  static void _drawImageContain(Canvas canvas, ui.Image image, Rect rect) {
    final imageRatio = image.width / image.height;
    final rectRatio = rect.width / rect.height;
    late final Rect dst;
    if (imageRatio > rectRatio) {
      final height = rect.width / imageRatio;
      dst = Rect.fromLTWH(rect.left, rect.top + (rect.height - height) / 2, rect.width, height);
    } else {
      final width = rect.height * imageRatio;
      dst = Rect.fromLTWH(rect.left + (rect.width - width) / 2, rect.top, width, rect.height);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  static Future<ui.Image?> _loadUiImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = io.File(p.join(tempDir.path, fileName));
    await tempFile.writeAsBytes(bytes, flush: true);

    if (io.Platform.isAndroid) {
      try {
        MediaStore.appFolder = 'Kroscek';
        await MediaStore.ensureInitialized();
        final saved = await MediaStore().saveFile(
          tempFilePath: tempFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        if (saved == null) {
          throw Exception('MediaStore tidak mengembalikan lokasi file.');
        }
        return 'Download/Kroscek/$fileName';
      } catch (_) {
        final fallback = await _saveToAppDocuments(bytes, fileName);
        await OpenFile.open(fallback.path);
        return 'Documents/${fallback.uri.pathSegments.last} ($mimeType)';
      }
    }

    final downloadDir = await _downloadDirectory();
    final outputFile = io.File(p.join(downloadDir.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    await OpenFile.open(outputFile.path);
    return outputFile.path;
  }

  static Future<io.File> _saveToAppDocuments(Uint8List bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDir = io.Directory(p.join(directory.path, 'exports'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    final outputFile = io.File(p.join(outputDir.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  static Future<io.Directory> _downloadDirectory() async {
    if (io.Platform.isIOS) return getApplicationDocumentsDirectory();
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  static String _fileName(PhaseIsoExportData data, String extension) {
    final snapshot = _PhaseIsoSnapshot.from(data);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'iso_${snapshot.filePhase}_${_safePart(snapshot.fieldNumber)}_$stamp.$extension';
  }

  static Map<String, dynamic>? _auditFor(Map<String, dynamic> field, PhaseIsoType phase) {
    return switch (phase) {
      PhaseIsoType.vegetative => _firstRow(field['audit_vegetative']),
      PhaseIsoType.preHarvest => _firstRow(field['audit_pre_harvest']),
      PhaseIsoType.harvest => _firstRow(field['audit_harvest']),
    };
  }

  static Map<String, dynamic>? _firstRow(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd-MM-yyyy', 'id_ID').format(date);
  }

  static String _longDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  static String _formatHa(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  static String _weekLabel(DateTime? date) {
    if (date == null) return '-';
    final start = DateTime(date.year, 1, 1);
    final week = (date.difference(start).inDays / 7).ceil();
    return 'W${week.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    try {
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
      if (text.contains('/')) {
        final parts = text.split('/');
        if (parts.length != 3) return null;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        var year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
      if (text.contains('-')) {
        final parts = text.split('-');
        if (parts.length != 3 || parts.first.length > 2) return null;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        var year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static int _dapOnDate(DateTime? plantingDate, DateTime? auditDate) {
    if (plantingDate == null || auditDate == null) return 0;
    final planting = DateTime(plantingDate.year, plantingDate.month, plantingDate.day);
    final audit = DateTime(auditDate.year, auditDate.month, auditDate.day);
    return audit.difference(planting).inDays + 1;
  }

  static double _readArea(Map<String, dynamic> raw) {
    for (final value in [
      raw['effective_area_ha'],
      raw['effective_area'],
      raw['area_ha'],
      raw['ha'],
      raw['total_area_planted_ha'],
    ]) {
      final parsed = _readDouble(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.').trim());
  }

  static String _readText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _score(String value) {
    final v = _norm(value);
    const map = {
      'very poor': '1 - Very Poor',
      'poor': '2 - Poor',
      'fair': '3 - Fair',
      'good': '4 - Good',
      'best': '5 - Best',
      '1': '1 - Very Poor',
      '2': '2 - Poor',
      '3': '3 - Fair',
      '4': '4 - Good',
      '5': '5 - Best',
    };
    return map[v] ?? _dash(value);
  }

  static _IsoStatus _scoreStatus(String value) {
    final v = _norm(value);
    if (const {'best', 'good', '4', '5'}.contains(v)) return _IsoStatus.pass;
    if (const {'fair', '3'}.contains(v)) return _IsoStatus.atRisk;
    if (const {'poor', 'very poor', '1', '2'}.contains(v)) return _IsoStatus.nc;
    return _IsoStatus.atRisk;
  }

  static String _yesNo(String value) {
    final v = _norm(value);
    if (v == 'yes' || v == 'found' || v == 'a' || v == 'y') return 'A (Yes)';
    if (v == 'no' || v == 'not found' || v == 'b' || v == 'n') return 'B (No)';
    return _dash(value);
  }

  static String _lsv(String value) {
    final v = _norm(value);
    if (v == 'none' || v == 'a') return 'A (None)';
    if (v == 'low' || v == 'b') return 'B (Low)';
    if (v == 'moderate' || v == 'c') return 'C (Moderate)';
    if (v == 'high' || v == 'd') return 'D (High)';
    return _dash(value);
  }

  static String _decision(String value) {
    final v = _norm(value);
    const map = {
      'pass': 'A - Pass',
      'pass with note': 'B - Pass w/ Note',
      'pass w/ note': 'B - Pass w/ Note',
      'hold': 'C - Hold',
      'discard': 'D - Discard',
      'pld': 'D - PLD',
      'a': 'A - Pass',
      'b': 'B - Pass w/ Note',
      'c': 'C - Hold',
      'd': 'D - Discard',
    };
    return map[v] ?? _dash(value);
  }

  static _IsoStatus _decisionStatus(String value) {
    final v = _norm(value);
    if (v == 'pass' || v == 'a') return _IsoStatus.pass;
    if (v == 'pass with note' || v == 'pass w/ note' || v == 'b' || v == 'hold' || v == 'c') {
      return _IsoStatus.atRisk;
    }
    if (v.contains('discard') || v == 'pld' || v == 'd') return _IsoStatus.nc;
    return _IsoStatus.atRisk;
  }

  static String _roguing(String value) {
    final v = _norm(value);
    if (v == 'not yet' || v == 'a') return 'A (Not Yet)';
    if (v == 'on going' || v == 'ongoing' || v == 'b') return 'B (On Going)';
    if (v == 'done' || v == 'c') return 'C (Done)';
    return _dash(value);
  }

  static String _action(String value) {
    final v = _norm(value);
    const map = {
      'none': 'A (None)',
      'roguing': 'B (Roguing)',
      're-detasseling': 'C (Re-Detasseling)',
      'hold': 'D (Hold)',
      'recom pld partial': 'E (Recom PLD Partial)',
      'recom pld full': 'F (Recom PLD Full)',
      'a': 'A (None)',
      'b': 'B (Roguing)',
      'c': 'C (Re-Detasseling)',
      'd': 'D (Hold)',
      'e': 'E (Recom PLD Partial)',
      'f': 'F (Recom PLD Full)',
    };
    return map[v] ?? _dash(value);
  }

  static bool _isNeutralAction(String value) {
    final v = _norm(value);
    return v.isEmpty || const {'none', 'a', '-'}.contains(v);
  }

  static String _dash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  static String _norm(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('–', '-')
        .replaceAll(RegExp(r'^[a-z0-9]{1,4}\s*-\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _safePart(String value) {
    final safe = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'fn' : safe;
  }

  static Color _statusColor(_IsoStatus status) {
    return switch (status) {
      _IsoStatus.pass => _ok,
      _IsoStatus.atRisk => _risk,
      _IsoStatus.nc => Colors.red,
      _IsoStatus.pld => const Color(0xFF183A9E),
    };
  }

  static Color _statusFill(_IsoStatus status) {
    return switch (status) {
      _IsoStatus.pass => _okFill,
      _IsoStatus.atRisk => _riskFill,
      _IsoStatus.nc => const Color(0xFFFFE0E0),
      _IsoStatus.pld => const Color(0xFFE2E7FF),
    };
  }

  static Color _ratingFill(_IsoStatus status) {
    return switch (status) {
      _IsoStatus.pass => const Color(0xFFD9F0DA),
      _IsoStatus.atRisk => _warn,
      _IsoStatus.nc => const Color(0xFFFFCDD2),
      _IsoStatus.pld => const Color(0xFFE2E7FF),
    };
  }

  static Color _ratingText(_IsoStatus status) {
    return switch (status) {
      _IsoStatus.pass => _ok,
      _IsoStatus.atRisk => Colors.black,
      _IsoStatus.nc => _risk,
      _IsoStatus.pld => const Color(0xFF183A9E),
    };
  }
}

enum _IsoStatus { pass, atRisk, nc, pld }

extension on String {
  String get titleCase {
    if (isEmpty) return this;
    return split(RegExp(r'\s+'))
        .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}

class _AssessmentRow {
  final String item;
  final String result;
  final _IsoStatus rating;

  const _AssessmentRow(this.item, this.result, this.rating);

  String get ratingLabel {
    return switch (rating) {
      _IsoStatus.pass => 'CONFORM',
      _IsoStatus.atRisk => 'AT RISK',
      _IsoStatus.nc => 'NC',
      _IsoStatus.pld => 'PLD',
    };
  }
}

class _PhaseIsoSnapshot {
  final PhaseIsoType phase;
  final Map<String, dynamic> field;
  final Map<String, dynamic> audit;
  final String fieldNumber;
  final String farmer;
  final String grower;
  final String codet;
  final String village;
  final String hybrid;
  final String season;
  final String region;
  final String crop;
  final DateTime? auditDate;
  final DateTime? plantingDate;
  final double effectiveAreaHa;
  final double totalAreaHa;
  final int dap;
  final String week;
  final String qaFi;
  final String qaSpv;
  final String remarks;

  const _PhaseIsoSnapshot({
    required this.phase,
    required this.field,
    required this.audit,
    required this.fieldNumber,
    required this.farmer,
    required this.grower,
    required this.codet,
    required this.village,
    required this.hybrid,
    required this.season,
    required this.region,
    required this.crop,
    required this.auditDate,
    required this.plantingDate,
    required this.effectiveAreaHa,
    required this.totalAreaHa,
    required this.dap,
    required this.week,
    required this.qaFi,
    required this.qaSpv,
    required this.remarks,
  });

  factory _PhaseIsoSnapshot.from(PhaseIsoExportData data) {
    final field = data.fieldData;
    final audit = PhaseIsoExportService._auditFor(field, data.phase) ?? const <String, dynamic>{};
    final auditDate = switch (data.phase) {
      PhaseIsoType.vegetative => PhaseIsoExportService._parseDate(audit['audit_date_user']) ??
          PhaseIsoExportService._parseDate(audit['date_of_audit']),
      PhaseIsoType.preHarvest => PhaseIsoExportService._parseDate(audit['audit_date']),
      PhaseIsoType.harvest => PhaseIsoExportService._parseDate(audit['date_of_audit']),
    };
    final plantingDate = data.phase == PhaseIsoType.vegetative
        ? PhaseIsoExportService._parseDate(audit['rev_planting_date']) ??
            PhaseIsoExportService._parseDate(field['planting_date_pdn'])
        : PhaseIsoExportService._parseDate(field['planting_date_pdn']);
    final effectiveArea = PhaseIsoExportService._readArea(field);
    final totalArea = PhaseIsoExportService._readDouble(field['total_area_planted_ha']) ?? effectiveArea;
    final qaFi = PhaseIsoExportService._readText(audit['qa_fi'], fallback: PhaseIsoExportService._readText(field['qa_fi']));
    final qaSpv = PhaseIsoExportService._readText(audit['qa_spv'], fallback: PhaseIsoExportService._readText(field['qa_spv']));
    final week = PhaseIsoExportService._readText(
      audit['audit_week'],
      fallback: PhaseIsoExportService._weekLabel(auditDate),
    );

    return _PhaseIsoSnapshot(
      phase: data.phase,
      field: field,
      audit: audit,
      fieldNumber: PhaseIsoExportService._readText(field['field_number']),
      farmer: PhaseIsoExportService._readText(field['farmer_name']),
      grower: PhaseIsoExportService._readText(field['grower']),
      codet: PhaseIsoExportService._readText(field['codet'], fallback: PhaseIsoExportService._readText(field['fa'])),
      village: PhaseIsoExportService._readText(field['village_desa']),
      hybrid: PhaseIsoExportService._readText(field['hybrid']),
      season: PhaseIsoExportService._readText(field['season']),
      region: PhaseIsoExportService._readText(field['region']),
      crop: PhaseIsoExportService._readText(field['type'], fallback: 'FC'),
      auditDate: auditDate,
      plantingDate: plantingDate,
      effectiveAreaHa: effectiveArea,
      totalAreaHa: totalArea,
      dap: PhaseIsoExportService._dapOnDate(plantingDate, auditDate),
      week: week,
      qaFi: qaFi,
      qaSpv: qaSpv,
      remarks: PhaseIsoExportService._readText(audit['remarks'], fallback: '-'),
    );
  }

  String get title {
    return switch (phase) {
      PhaseIsoType.vegetative => 'QUALITY PROCESS: VEGETATIVE AUDIT & FIELD CONDITION RECORD',
      PhaseIsoType.preHarvest => 'QUALITY PROCESS: PRE-HARVEST READINESS AUDIT RECORD',
      PhaseIsoType.harvest => 'QUALITY PROCESS: HARVEST AUDIT RECORD',
    };
  }

  String get phaseLabel {
    return switch (phase) {
      PhaseIsoType.vegetative => 'Vegetative',
      PhaseIsoType.preHarvest => 'Pre-Harvest',
      PhaseIsoType.harvest => 'Harvest',
    };
  }

  String get filePhase {
    return switch (phase) {
      PhaseIsoType.vegetative => 'vegetative',
      PhaseIsoType.preHarvest => 'pre_harvest',
      PhaseIsoType.harvest => 'harvest',
    };
  }

  String get docCode {
    return switch (phase) {
      PhaseIsoType.vegetative => 'KC-QA-FRM-VEG-01',
      PhaseIsoType.preHarvest => 'KC-QA-FRM-PHV-01',
      PhaseIsoType.harvest => 'KC-QA-FRM-HRV-01',
    };
  }

  String get auditDateLabel => PhaseIsoExportService._longDate(auditDate);

  String get targetAudit => '25-30 DAP';

  String get fieldStage {
    if (phase != PhaseIsoType.vegetative) return '-';
    if (dap <= 0) return '-';
    if (dap < 10) return 'V2';
    if (dap < 15) return 'V3';
    if (dap < 20) return 'V4';
    if (dap < 25) return 'V5';
    if (dap < 31) return 'V8';
    return 'V10';
  }

  String get resultPanelTitle {
    return switch (phase) {
      PhaseIsoType.vegetative => 'VEGETATIVE RESULT',
      PhaseIsoType.preHarvest => 'PRE-HARVEST RESULT',
      PhaseIsoType.harvest => 'HARVEST RESULT',
    };
  }

  String get finalFlagging {
    return switch (phase) {
      PhaseIsoType.vegetative => PhaseIsoExportService._readText(audit['flagging']),
      PhaseIsoType.preHarvest => PhaseIsoExportService._readText(audit['final_flagging']),
      PhaseIsoType.harvest => PhaseIsoExportService._readText(audit['final_flagging']),
    };
  }

  String get resultDecision {
    if (phase == PhaseIsoType.harvest) {
      return harvestResult;
    }
    if (phase == PhaseIsoType.vegetative) {
      return PhaseIsoExportService._decision(
        PhaseIsoExportService._readText(audit['decision'], fallback: ''),
      );
    }
    return PhaseIsoExportService._decision(
      PhaseIsoExportService._readText(audit['final_decision'], fallback: ''),
    );
  }

  String get harvestResult {
    final downgrade = PhaseIsoExportService._norm(
      PhaseIsoExportService._readText(audit['status_downgrade'], fallback: ''),
    );
    final finalFlag = finalFlagging.toUpperCase();
    if (finalFlag == 'GF' && (downgrade.isEmpty || downgrade == 'no' || downgrade == 'b')) {
      return 'A - Pass';
    }
    if (finalFlag == 'BF') return 'C - Hold';
    return 'B - Pass w/ Note';
  }

  String get statusText {
    return switch (statusLevel) {
      _IsoStatus.pass => phase == PhaseIsoType.vegetative ? 'CONFORM' : 'PASS',
      _IsoStatus.atRisk => 'AT RISK',
      _IsoStatus.nc => 'NC',
      _IsoStatus.pld => 'PLD',
    };
  }

  _IsoStatus get statusLevel {
    final ratings = <_IsoStatus>[
      ...assessmentRows.map((row) => row.rating),
      if (phase == PhaseIsoType.vegetative) ...accuracyRows.map((row) => row.rating),
    ];
    if (phase == PhaseIsoType.vegetative) {
      final action = PhaseIsoExportService._readText(audit['action_needed'], fallback: '');
      if (PhaseIsoExportService._norm(action).contains('pld')) return _IsoStatus.pld;
    }
    if (ratings.any((rating) => rating == _IsoStatus.nc)) return _IsoStatus.nc;
    if (ratings.any((rating) => rating == _IsoStatus.atRisk || rating == _IsoStatus.pld)) {
      return _IsoStatus.atRisk;
    }
    return _IsoStatus.pass;
  }

  String get auditStatus {
    if (dap <= 0) return '-';
    if (phase == PhaseIsoType.vegetative) return dap >= 25 && dap <= 30 ? 'On Time' : 'Out of Window';
    if (phase == PhaseIsoType.preHarvest) return dap >= 80 && dap <= 95 ? 'On Time' : 'Review Window';
    return dap >= 90 ? 'On Time' : 'Review Window';
  }

  String get mainIssue {
    if (remarks != '-' && remarks.length < 90) return remarks;
    if (phase == PhaseIsoType.vegetative) {
      final roguing = PhaseIsoExportService._readText(audit['roguing_status'], fallback: '');
      if (!PhaseIsoExportService._norm(roguing).contains('done')) return 'Roguing ${PhaseIsoExportService._dash(roguing)}';
      return 'Vegetative audit finding review';
    }
    if (phase == PhaseIsoType.preHarvest) {
      return statusLevel == _IsoStatus.pass ? 'Ready for harvest monitoring' : 'Monitoring until harvest';
    }
    return statusLevel == _IsoStatus.pass ? 'Ear maturity ready for harvest' : 'Harvest finding needs follow up';
  }

  String get actionNeeded {
    final direct = PhaseIsoExportService._readText(audit['action_needed'], fallback: '');
    if (direct.isNotEmpty) {
      return PhaseIsoExportService._action(direct);
    }
    if (phase == PhaseIsoType.vegetative) {
      return statusLevel == _IsoStatus.pass ? 'No corrective action required.' : 'Complete corrective action before next stage.';
    }
    if (phase == PhaseIsoType.preHarvest) {
      if (statusLevel == _IsoStatus.pass) return 'Proceed to harvest monitoring.';
      return 'Continue observation until harvest date.';
    }
    if (statusLevel == _IsoStatus.pass) return 'Proceed with harvest as scheduled.';
    return 'Review harvest finding and follow up downgrade flagging.';
  }

  String get recommendedPldHa {
    final area = PhaseIsoExportService._readDouble(audit['recommendation_pld_ha']) ??
        PhaseIsoExportService._readDouble(audit['pld_area_ha']);
    if (area == null) return '0.00 Ha';
    return '${area.toStringAsFixed(2)} Ha';
  }

  String get pldStatus {
    final action = PhaseIsoExportService._norm(PhaseIsoExportService._readText(audit['action_needed'], fallback: ''));
    final decision = PhaseIsoExportService._norm(PhaseIsoExportService._readText(audit['decision'], fallback: ''));
    if (action.contains('pld') || decision.contains('pld')) return 'Recommendation Review';
    return 'No Recommendation Yet';
  }

  String get taggingAccuracy {
    final poi = PhaseIsoExportService._norm(PhaseIsoExportService._readText(audit['poi_accuracy'], fallback: ''));
    if (poi == 'valid') return 'A (Match)';
    if (poi == 'not valid') return 'B (Check)';
    final tagging = PhaseIsoExportService._readText(audit['correction_tagging'] ?? field['correction_tagging'], fallback: '');
    return tagging.isEmpty ? '-' : 'A (Match)';
  }

  String get plantingCorrection {
    final rev = PhaseIsoExportService._parseDate(audit['rev_planting_date']);
    if (rev == null) return 'No';
    return 'Yes';
  }

  String get fieldSizeAccuracy {
    final audited = PhaseIsoExportService._readDouble(audit['field_size_by_audit_ha']);
    if (audited == null) return '-';
    final diff = (audited - effectiveAreaHa).abs();
    final pct = effectiveAreaHa <= 0 ? 0 : diff / effectiveAreaHa * 100;
    return '${_PhaseIsoExportServiceBridge.formatHa(diff)} Ha (${pct < 5 ? 'Less than 5%' : 'More than 5%'})';
  }

  List<_AssessmentRow> get vegetativeRows {
    final cropUniformity = PhaseIsoExportService._readText(audit['crop_uniformity'], fallback: '');
    final lsv = PhaseIsoExportService._readText(audit['lsv_status'], fallback: '');
    final maleSplit = PhaseIsoExportService._readText(audit['male_split_by_audit'], fallback: '');
    final oneSeed = PhaseIsoExportService._readText(audit['one_seed_per_hole'], fallback: '');
    final roguing = PhaseIsoExportService._readText(audit['roguing_status'], fallback: '');
    final isolation = PhaseIsoExportService._readText(audit['isolation_problem_by_audit'], fallback: '');
    final ratio = PhaseIsoExportService._readText(audit['sowing_ratio_by_audit'], fallback: '-');

    return [
      _AssessmentRow('Crop Uniformity', PhaseIsoExportService._score(cropUniformity), PhaseIsoExportService._scoreStatus(cropUniformity)),
      _AssessmentRow('LSV Status', PhaseIsoExportService._lsv(lsv), _lsvStatus(lsv)),
      _AssessmentRow('Male Split', PhaseIsoExportService._yesNo(maleSplit), _yesNoStatus(maleSplit, yesIsPass: true)),
      _AssessmentRow('Male 2 Rows', ratio, ratio == '-' ? _IsoStatus.atRisk : _IsoStatus.pass),
      _AssessmentRow('One Seed per Hole', PhaseIsoExportService._yesNo(oneSeed), _yesNoStatus(oneSeed, yesIsPass: true)),
      _AssessmentRow('Roguing Status', PhaseIsoExportService._roguing(roguing), _roguingStatus(roguing)),
      _AssessmentRow('Isolation Problem', PhaseIsoExportService._yesNo(isolation), _yesNoStatus(isolation, yesIsPass: false)),
    ];
  }

  List<_AssessmentRow> get accuracyRows {
    final taggingRating = taggingAccuracy.startsWith('A') ? _IsoStatus.pass : _IsoStatus.atRisk;
    final plantingRating = plantingCorrection == 'Yes' ? _IsoStatus.pass : _IsoStatus.atRisk;
    final audited = PhaseIsoExportService._readDouble(audit['field_size_by_audit_ha']);
    final fieldRating = audited == null
        ? _IsoStatus.atRisk
        : ((effectiveAreaHa <= 0 || ((audited - effectiveAreaHa).abs() / effectiveAreaHa * 100) <= 5)
            ? _IsoStatus.pass
            : _IsoStatus.atRisk);
    return [
      _AssessmentRow('Tagging', taggingAccuracy, taggingRating),
      _AssessmentRow('Koreksi Tanggal Tanam', PhaseIsoExportService._formatDate(PhaseIsoExportService._parseDate(audit['rev_planting_date'])), plantingRating),
      _AssessmentRow('Field Size', fieldSizeAccuracy, fieldRating),
    ];
  }

  List<_AssessmentRow> get assessmentRows {
    if (phase == PhaseIsoType.vegetative) return vegetativeRows;
    if (phase == PhaseIsoType.preHarvest) {
      final male = PhaseIsoExportService._readText(audit['male_chopping_rows'], fallback: '');
      final uniformity = PhaseIsoExportService._readText(audit['crop_uniformity'], fallback: '');
      final health = PhaseIsoExportService._readText(audit['crop_health'], fallback: '');
      final flagging = PhaseIsoExportService._readText(audit['final_flagging'], fallback: '');
      final decision = PhaseIsoExportService._readText(audit['final_decision'], fallback: '');
      return [
        _AssessmentRow('Male Chopping (Rows)', _maleChoppingLabel(male), PhaseIsoExportService._norm(male) == 'complete' || PhaseIsoExportService._norm(male) == 'a' ? _IsoStatus.pass : _IsoStatus.atRisk),
        _AssessmentRow('Crop Uniformity', PhaseIsoExportService._score(uniformity), PhaseIsoExportService._scoreStatus(uniformity)),
        _AssessmentRow('Crop Health', PhaseIsoExportService._score(health), PhaseIsoExportService._scoreStatus(health)),
        _AssessmentRow('Final Flagging', PhaseIsoExportService._dash(flagging), flagging.toUpperCase() == 'GF' ? _IsoStatus.pass : _IsoStatus.atRisk),
        _AssessmentRow('Final Decision', PhaseIsoExportService._decision(decision), PhaseIsoExportService._decisionStatus(decision)),
      ];
    }

    final ear = PhaseIsoExportService._readText(audit['ear_condition_observation'], fallback: '');
    final uniformity = PhaseIsoExportService._readText(audit['crop_uniformity'], fallback: '');
    final health = PhaseIsoExportService._readText(audit['crop_health'], fallback: '');
    final downgrade = PhaseIsoExportService._readText(audit['downgrade_flagging'], fallback: '');
    final flagging = PhaseIsoExportService._readText(audit['final_flagging'], fallback: '');
    return [
      _AssessmentRow('Ear Condition (Maturity)', PhaseIsoExportService._dash(ear), _earStatus(ear)),
      _AssessmentRow('Crop Uniformity', PhaseIsoExportService._score(uniformity), PhaseIsoExportService._scoreStatus(uniformity)),
      _AssessmentRow('Crop Health', PhaseIsoExportService._score(health), PhaseIsoExportService._scoreStatus(health)),
      _AssessmentRow('Downgrade Flagging', PhaseIsoExportService._dash(downgrade.isEmpty ? 'None' : downgrade), downgrade.isEmpty || downgrade == '-' ? _IsoStatus.pass : _IsoStatus.atRisk),
      _AssessmentRow('Final Flagging', PhaseIsoExportService._dash(flagging), flagging.toUpperCase() == 'GF' ? _IsoStatus.pass : _IsoStatus.atRisk),
      _AssessmentRow('Harvest Result', harvestResult, harvestResult.startsWith('A') ? _IsoStatus.pass : _IsoStatus.atRisk),
    ];
  }

  static _IsoStatus _lsvStatus(String value) {
    final v = PhaseIsoExportService._norm(value);
    if (v == 'none' || v == 'a') return _IsoStatus.pass;
    if (v == 'high' || v == 'd') return _IsoStatus.nc;
    return _IsoStatus.atRisk;
  }

  static _IsoStatus _yesNoStatus(String value, {required bool yesIsPass}) {
    final v = PhaseIsoExportService._norm(value);
    final yes = v == 'yes' || v == 'a' || v == 'y';
    final no = v == 'no' || v == 'b' || v == 'n';
    if (yes) return yesIsPass ? _IsoStatus.pass : _IsoStatus.atRisk;
    if (no) return yesIsPass ? _IsoStatus.atRisk : _IsoStatus.pass;
    return _IsoStatus.atRisk;
  }

  static _IsoStatus _roguingStatus(String value) {
    final v = PhaseIsoExportService._norm(value);
    if (v == 'done' || v == 'c') return _IsoStatus.pass;
    return _IsoStatus.atRisk;
  }

  static _IsoStatus _earStatus(String value) {
    final v = PhaseIsoExportService._norm(value);
    if (v == 'stage 3' || v == 'stage 4' || v == '3' || v == '4') return _IsoStatus.pass;
    return _IsoStatus.atRisk;
  }

  static String _maleChoppingLabel(String value) {
    final v = PhaseIsoExportService._norm(value);
    if (v == 'complete' || v == 'a') return 'A - Complete';
    if (v == 'not complete' || v == 'b') return 'B - Not Complete';
    return PhaseIsoExportService._dash(value);
  }
}

class _PhaseIsoExportServiceBridge {
  static String formatHa(double value) => PhaseIsoExportService._formatHa(value);
}
