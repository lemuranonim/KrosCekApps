import 'dart:io' as io;
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

import '../utils/dap_helper.dart';

class DetasselingIsoFormData {
  final Map<String, dynamic> fieldData;
  final Map<String, dynamic> auditData;
  final int passNumber;
  final String cropLabel;

  const DetasselingIsoFormData({
    required this.fieldData,
    required this.auditData,
    required this.passNumber,
    required this.cropLabel,
  });
}

class DetasselingIsoExportService {
  static const _advantaLogoAsset = 'assets/advanta-logo.png';
  static const _green = Color(0xFF004822);
  static const _line = Color(0xFF8E9892);
  static const _ink = Color(0xFF101915);

  static Future<String> downloadPicture(DetasselingIsoFormData data) async {
    final bytes = await buildPng(data);
    return _saveBytes(
      bytes: bytes,
      fileName: _fileName(data, 'png'),
      mimeType: 'image/png',
    );
  }

  static Future<String> downloadPdf(DetasselingIsoFormData data) async {
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

  static Future<Uint8List> buildPng(DetasselingIsoFormData data) async {
    const width = 1800.0;
    const height = 1280.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), paint);

    _drawBorder(
        canvas, const Rect.fromLTWH(8, 8, width - 16, height - 16), _line, 1.2);

    final f = _FieldSnapshot.from(data);
    final passCount = f.isSweetCorn ? 5 : 3;
    final planDates = _planDates(
      f.plantingDate,
      passCount,
      f.detasselingStartDap,
    );
    final actualDates = _actualDates(data, passCount);
    final advantaLogo = await _loadUiImage(_advantaLogoAsset);

    _drawHeader(canvas, advantaLogo);
    _drawFieldInfo(canvas, f);
    _drawPlanSchedule(canvas, f, planDates, actualDates);
    _drawLaborBox(canvas, f);
    _drawFnSchedule(canvas, f, planDates, actualDates, data.passNumber);
    _drawInspectionSummary(canvas, f);
    _drawFlaggingLegend(canvas);
    _drawSignatures(canvas);
    _drawFooter(canvas, f, data.passNumber);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawHeader(Canvas canvas, ui.Image? advantaLogo) {
    if (advantaLogo != null) {
      _drawImageContain(
        canvas,
        advantaLogo,
        const Rect.fromLTWH(22, 24, 282, 58),
      );
    } else {
      _text(
        canvas,
        'KROSCEK',
        const Offset(78, 36),
        size: 31,
        weight: FontWeight.w800,
        color: _green,
      );
      _text(
        canvas,
        'TRUST - VERIFY - IMPROVE',
        const Offset(80, 77),
        size: 12,
        weight: FontWeight.w600,
        color: _green,
      );
      _drawLeafLogo(canvas, const Offset(34, 26));
    }
    _text(
      canvas,
      'QUALITY PROCESS: DETASSELLING (PLAN VS ACTUAL & INSPECTION OUTPUT)',
      const Offset(370, 30),
      size: 34,
      weight: FontWeight.w900,
      color: Colors.black,
    );
    _drawFilledRect(canvas, const Rect.fromLTWH(18, 96, 1764, 4), _green);
  }

  static void _drawFieldInfo(Canvas canvas, _FieldSnapshot f) {
    final rows = [
      ('Season', f.season),
      ('Week', f.week),
      ('Region', f.region),
      ('Codet', f.codet),
      ('Crop', f.crop),
      ('Village', f.village),
      ('Hybrid', f.hybrid),
      ('Farmer', f.farmer),
      ('FN', f.fieldNumber),
      ('Total Ha Detasselling', '${_formatHa(f.totalAreaHa)} Ha'),
      ('Ha Plant', '${_formatHa(f.areaHa)} Ha'),
      ('Planting Date', _formatDate(f.plantingDate)),
      ('Est DT', '${f.estimatedDap} HST'),
    ];

    var y = 125.0;
    for (final row in rows) {
      _text(canvas, row.$1, Offset(22, y), size: 18, weight: FontWeight.w600);
      _text(canvas, ':', Offset(230, y), size: 18, weight: FontWeight.w700);
      _text(canvas, row.$2, Offset(260, y), size: 18, weight: FontWeight.w700);
      y += row.$1 == 'FN' ? 37 : 25;
    }
  }

  static void _drawPlanSchedule(
    Canvas canvas,
    _FieldSnapshot f,
    List<DateTime> planDates,
    Map<int, DateTime> actualDates,
  ) {
    const left = 405.0;
    const top = 122.0;
    const width = 1090.0;
    const height = 372.0;
    _drawBorder(
        canvas, const Rect.fromLTWH(left, top, width, height), _line, 1);
    _drawSectionTitle(
      canvas,
      const Rect.fromLTWH(left, top, width, 38),
      'PLAN VS ACTUAL DETASSELLING SCHEDULE (${f.crop})',
    );

    final dates = _dateWindow(planDates, actualDates.values.toList());
    const labelW = 104.0;
    final colW = (width - labelW) / dates.length;
    final rowTop = top + 38;
    const dowH = 28.0;
    const dateH = 54.0;
    const scheduleRowH = 37.0;
    const scheduleRowCount = 6;
    const gridH = dowH + dateH + scheduleRowH * scheduleRowCount;
    final passTkdPerHa =
        f.isSweetCorn ? const [4, 4, 4, 4, 4] : const [5, 5, 5];
    final plannedTkdByPass = _allocateTkdByPass(f.totalAreaHa, passTkdPerHa);

    _drawGridLine(canvas, Offset(left + labelW, rowTop),
        Offset(left + labelW, rowTop + gridH));
    var x = left + labelW;
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      final colRect = Rect.fromLTWH(x, rowTop, colW, dowH + dateH);
      if (_isSameDay(date, f.auditDate)) {
        _drawFilledRect(canvas, colRect, const Color(0xFFEAF7EF));
      }
      _drawGridLine(canvas, Offset(x, rowTop), Offset(x, rowTop + gridH));
      _textCentered(
        canvas,
        DateFormat('E', 'id_ID').format(date).substring(0, 1).toUpperCase(),
        Rect.fromLTWH(x, rowTop + 5, colW, 18),
        size: 14,
        weight: FontWeight.w800,
      );
      _textCentered(
        canvas,
        '${date.day}\n${DateFormat('MMM', 'id_ID').format(date)}',
        Rect.fromLTWH(x, rowTop + dowH + 6, colW, 42),
        size: 14,
        weight: FontWeight.w700,
      );

      final planned = _passForDate(planDates, date);
      final actual = _actualPassForDate(actualDates, date);
      final values = [
        planned == null ? '-' : '${plannedTkdByPass[planned - 1]}',
        actual == null ? '-' : _actualTkdLabel(f.actualTkdByPass[actual]),
        planned == null ? '-' : 'P$planned',
        actual == null ? '-' : '✓',
        actual == null ? '-' : _personCode(f.auditFiByPass[actual] ?? f.qaFi),
        actual == null ? '-' : _personCode(f.auditHelperByPass[actual] ?? ''),
      ];
      for (var row = 0; row < values.length; row++) {
        _textCentered(
          canvas,
          values[row],
          Rect.fromLTWH(
            x + 2,
            rowTop + dowH + dateH + scheduleRowH * row + 7,
            colW - 4,
            22,
          ),
          size: row == 3 && values[row] == '✓' ? 20 : 13.5,
          weight: FontWeight.w900,
          color:
              row == 3 && values[row] == '✓' ? const Color(0xFF1B6E1F) : _ink,
        );
      }
      x += colW;
    }

    _drawGridLine(canvas, Offset(left, rowTop + dowH),
        Offset(left + width, rowTop + dowH));
    _drawGridLine(canvas, Offset(left, rowTop + dowH + dateH),
        Offset(left + width, rowTop + dowH + dateH));
    for (var row = 1; row <= scheduleRowCount; row++) {
      final y = rowTop + dowH + dateH + scheduleRowH * row;
      _drawGridLine(canvas, Offset(left, y), Offset(left + width, y));
    }

    final rowLabels = [
      'PLANNING\nTKD',
      'AKTUAL\nTKD',
      'PLAN\n(Pass)',
      'AKTUAL\nDT',
      'AUDIT\nFI',
      'AUDIT\nHELPER',
    ];
    for (var row = 0; row < rowLabels.length; row++) {
      _textCentered(
        canvas,
        rowLabels[row],
        Rect.fromLTWH(
          left + 4,
          rowTop + dowH + dateH + scheduleRowH * row + 5,
          labelW - 8,
          scheduleRowH - 10,
        ),
        size: 12.5,
        weight: FontWeight.w800,
      );
    }

    _text(
      canvas,
      'P = waktu/pass detasselling dimulai. TKD aktual dan helper mengikuti tanggal audit tiap pass.',
      const Offset(left + 16, top + height - 23),
      size: 13.5,
      weight: FontWeight.w500,
    );
  }

  static void _drawLaborBox(Canvas canvas, _FieldSnapshot f) {
    const rect = Rect.fromLTWH(1514, 122, 268, 372);
    final passCount = f.isSweetCorn ? 5 : 3;
    final passTkdPerHa =
        f.isSweetCorn ? const [4, 4, 4, 4, 4] : const [5, 5, 5];
    final ruleLabel =
        f.isSweetCorn ? 'SC 20 TKD/Ha: 4-4-4-4-4' : 'FC 15 TKD/Ha: 5-5-5';
    _drawBorder(canvas, rect, _line, 1);
    _textCentered(
      canvas,
      'Perkiraan mulai detasseling:',
      const Rect.fromLTWH(1525, 146, 246, 24),
      size: 15,
      weight: FontWeight.w700,
    );
    _textCentered(
      canvas,
      '${f.detasselingStartDap} HST',
      const Rect.fromLTWH(1525, 177, 246, 34),
      size: 27,
      weight: FontWeight.w900,
      color: _green,
    );
    _drawGridLine(canvas, const Offset(1514, 230), const Offset(1782, 230));
    _textCentered(
      canvas,
      'Akumulasi jumlah TKD\nper petak-hari',
      const Rect.fromLTWH(1530, 249, 236, 46),
      size: 16,
      weight: FontWeight.w800,
    );
    _textCentered(
      canvas,
      ruleLabel,
      const Rect.fromLTWH(1530, 294, 236, 18),
      size: 12.5,
      weight: FontWeight.w800,
      color: _green,
    );

    final allocatedTkd = _allocateTkdByPass(f.totalAreaHa, passTkdPerHa);
    final values = List<String>.generate(5, (index) {
      if (index >= passCount) return '-';
      return '${allocatedTkd[index]} TKD';
    });
    var y = 326.0;
    for (var i = 0; i < 5; i++) {
      _text(canvas, 'Pass ${i + 1}', Offset(1536, y),
          size: 16.5, weight: FontWeight.w600);
      _text(canvas, ':', Offset(1666, y), size: 16.5, weight: FontWeight.w700);
      _text(canvas, values[i], Offset(1704, y),
          size: 16.5, weight: FontWeight.w900);
      y += 34;
    }
  }

  static void _drawFnSchedule(
    Canvas canvas,
    _FieldSnapshot f,
    List<DateTime> planDates,
    Map<int, DateTime> actualDates,
    int currentPass,
  ) {
    const left = 18.0;
    const top = 510.0;
    const width = 1764.0;
    const height = 196.0;
    _drawBorder(
        canvas, const Rect.fromLTWH(left, top, width, height), _line, 1);
    _drawSectionTitle(
      canvas,
      const Rect.fromLTWH(left, top, width, 34),
      'FN SCHEDULE DETAIL (PLAN VS ACTUAL)',
    );

    final passCount = f.isSweetCorn ? 5 : 3;
    const headTop = top + 34;
    const bodyTop = top + 124;
    final cols = [
      155.0,
      160.0,
      150.0,
      128.0,
      132.0,
      116.0,
      104.0,
      116.0,
      116.0,
      116.0,
      116.0,
      if (passCount == 5) 116.0,
      if (passCount == 5) 116.0,
    ];
    final used = cols.fold<double>(0, (a, b) => a + b);
    final remarkW = width - used;
    final allCols = [...cols, remarkW];
    final labels = [
      'FN',
      'Farmer',
      'Village',
      'Ha Plant\n(Ha)',
      'Planting\nDate',
      'Hybrid',
      'Est DT\n(HST)',
      'TKD / FN\n(by Ha)',
      'P1\n(${_dayMonth(planDates[0])})',
      'P2\n(${_dayMonth(planDates[1])})',
      'P3\n(${_dayMonth(planDates[2])})',
      if (passCount == 5) 'P4\n(${_dayMonth(planDates[3])})',
      if (passCount == 5) 'P5\n(${_dayMonth(planDates[4])})',
      'Action / Remarks',
    ];

    var x = left;
    for (var i = 0; i < allCols.length; i++) {
      _drawGridLine(canvas, Offset(x, headTop), Offset(x, top + height));
      _textCentered(
        canvas,
        labels[i],
        Rect.fromLTWH(x + 4, headTop + 18, allCols[i] - 8, 54),
        size: 15,
        weight: FontWeight.w800,
      );
      x += allCols[i];
    }
    _drawGridLine(canvas, Offset(left + width, headTop),
        Offset(left + width, top + height));
    _drawGridLine(canvas, const Offset(left, bodyTop),
        const Offset(left + width, bodyTop));

    final values = [
      f.fieldNumber,
      f.farmer,
      f.village,
      '${_formatHa(f.areaHa)} Ha',
      _formatDate(f.plantingDate),
      f.hybrid,
      '${f.estimatedDap}',
      '${f.recommendedTkdForPass(currentPass)} TKD',
    ];

    x = left;
    for (var i = 0; i < values.length; i++) {
      _textCentered(
        canvas,
        values[i],
        Rect.fromLTWH(x + 6, bodyTop + 34, allCols[i] - 12, 32),
        size: 17,
        weight: FontWeight.w800,
      );
      x += allCols[i];
    }

    for (var pass = 1; pass <= passCount; pass++) {
      final actual = actualDates[pass];
      final mark = actual == null ? '-' : '✓\n${_dayMonth(actual)}';
      _textCentered(
        canvas,
        mark,
        Rect.fromLTWH(x + 6, bodyTop + 20, allCols[7 + pass] - 12, 56),
        size: actual == null ? 17 : 23,
        weight: FontWeight.w900,
        color: actual == null ? _ink : const Color(0xFF1B6E1F),
      );
      x += allCols[7 + pass];
    }

    final action = f.actionRemarks.isEmpty ? '-' : f.actionRemarks;
    _text(
      canvas,
      action,
      Offset(x + 14, bodyTop + 28),
      size: 15,
      weight: FontWeight.w700,
      maxWidth: remarkW - 24,
      maxLines: 3,
    );
  }

  static void _drawInspectionSummary(Canvas canvas, _FieldSnapshot f) {
    const left = 18.0;
    const top = 722.0;
    const width = 1764.0;
    const height = 252.0;
    _drawBorder(
        canvas, const Rect.fromLTWH(left, top, width, height), _line, 1);
    _drawSectionTitle(
      canvas,
      const Rect.fromLTWH(left, top, width, 34),
      'INSPECTION RESULTS SUMMARY',
    );

    final meta = [
      ('Audit Date:', _longDate(f.auditDate)),
      ('Week:', f.week),
      ('Auditor (QA FI):', f.qaFi),
      ('QA SPV:', f.qaSpv),
      ('Audit Helper:', f.auditHelper),
    ];
    final metaW = width / 5;
    for (var i = 0; i < meta.length; i++) {
      final rect =
          Rect.fromLTWH(left + 18 + (metaW - 9) * i, top + 48, metaW - 28, 50);
      _drawBorder(canvas, rect, _line, 1);
      _text(canvas, meta[i].$1, Offset(rect.left + 16, rect.top + 14),
          size: 13, weight: FontWeight.w800);
      _textCentered(
        canvas,
        meta[i].$2,
        Rect.fromLTWH(rect.left + 154, rect.top + 12, rect.width - 166, 24),
        size: 15,
        weight: FontWeight.w800,
      );
    }

    final firstRow = [
      ('Female Shedding', _femaleShedding(f.femaleShedding)),
      ('Offtype M', _offtype(f.offtypeM)),
      ('Offtype F', _offtype(f.offtypeF)),
      ('LSV Status', _lsv(f.lsvStatus)),
      ('Crop Uniformity', _score(f.cropUniformity)),
      ('Crop Health', _score(f.cropHealth)),
    ];
    final secondRow = [
      ('Detasseling Assessment', _detasseling(f.detasselingAssessment)),
      ('Isolation Status', _yesNo(f.isolationStatus)),
      ('Affected Other Field', _yesNo(f.affectedOtherField)),
      ('Action Needed', _action(f.actionNeeded)),
      ('Flagging', _dash(f.flagging)),
    ];

    _drawSummaryRow(canvas, firstRow, top + 116, 6);
    _drawSummaryRow(canvas, secondRow, top + 184, 5);
  }

  static void _drawSummaryRow(
    Canvas canvas,
    List<(String, String)> items,
    double top,
    int count,
  ) {
    const left = 40.0;
    const totalW = 1720.0;
    final cellW = totalW / count;
    for (var i = 0; i < items.length; i++) {
      final rect = Rect.fromLTWH(left + cellW * i, top, cellW, 56);
      final isFlagging = items[i].$1 == 'Flagging';
      if (isFlagging) {
        final flagColor = _flaggingColor(items[i].$2);
        _drawFilledRect(canvas, rect, flagColor.withAlpha(24));
        _drawBorder(canvas, rect, flagColor, 2);
        _textCentered(
          canvas,
          items[i].$1.toUpperCase(),
          Rect.fromLTWH(rect.left + 6, rect.top + 7, rect.width - 12, 15),
          size: 12,
          weight: FontWeight.w900,
          color: flagColor,
        );
        _drawFlagIcon(canvas, Offset(rect.left + 72, rect.top + 23), flagColor);
        final badge = Rect.fromLTWH(rect.left + 118, rect.top + 22, 108, 28);
        _drawRoundedFill(canvas, badge, flagColor, 6);
        _textCentered(
          canvas,
          items[i].$2,
          badge.deflate(4),
          size: 19,
          weight: FontWeight.w900,
          color: _flaggingTextColor(items[i].$2),
        );
        continue;
      }

      _drawBorder(canvas, rect, _line, 1);
      _textCentered(
        canvas,
        items[i].$1,
        Rect.fromLTWH(rect.left + 6, rect.top + 8, rect.width - 12, 17),
        size: 12.5,
        weight: FontWeight.w800,
      );
      _textCentered(
        canvas,
        items[i].$2,
        Rect.fromLTWH(rect.left + 6, rect.top + 30, rect.width - 12, 18),
        size: 15.5,
        weight: FontWeight.w900,
        color: _green,
      );
    }
  }

  static void _drawFlaggingLegend(Canvas canvas) {
    _textCentered(
      canvas,
      'FLAGGING LEGEND',
      const Rect.fromLTWH(40, 984, 1720, 18),
      size: 13.5,
      weight: FontWeight.w900,
    );

    const rect = Rect.fromLTWH(40, 1008, 1720, 44);
    _drawBorder(canvas, rect, _line, 1);
    final items = [
      ('GF', 'Green Flag', const Color(0xFF2E7D32)),
      ('RFI', 'Red Flag Isolation', const Color(0xFFE53935)),
      ('RFD', 'Red Flag Detasseling', const Color(0xFFE53935)),
      ('BF', 'Black Flag', Colors.black),
      ('PLD', 'Discard area', const Color(0xFFF5C400)),
    ];
    var x = 58.0;
    for (final item in items) {
      _drawFlagIcon(canvas, Offset(x, 1016), item.$3);
      _drawFilledRect(
        canvas,
        Rect.fromLTWH(x + 44, 1016, 50, 28),
        item.$3 == const Color(0xFFF5C400) ? const Color(0xFFFFEB3B) : item.$3,
      );
      _textCentered(
        canvas,
        item.$1,
        Rect.fromLTWH(x + 44, 1021, 50, 15),
        size: 13,
        weight: FontWeight.w900,
        color: item.$1 == 'PLD' ? Colors.black : Colors.white,
      );
      _text(canvas, '= ${item.$2}', Offset(x + 110, 1022),
          size: 15, weight: FontWeight.w600);
      x += 340;
      if (item != items.last) {
        _drawGridLine(canvas, Offset(x - 24, 1014), Offset(x - 24, 1047));
      }
    }
  }

  static void _drawSignatures(Canvas canvas) {
    const top = 1068.0;
    const h = 138.0;
    const gap = 18.0;
    final w = (1764 - gap) / 2;
    _signatureBox(canvas, Rect.fromLTWH(18, top, w, h), 'FA');
    _signatureBox(canvas, Rect.fromLTWH(18 + w + gap, top, w, h), 'FI');
  }

  static void _signatureBox(Canvas canvas, Rect rect, String title) {
    _drawBorder(canvas, rect, _line, 1);
    _drawSectionTitle(
        canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, 28), title);
    final rows = ['Signature', 'Nama', 'Tanggal'];
    var y = rect.top + 50;
    for (final row in rows) {
      _text(canvas, row, Offset(rect.left + 28, y),
          size: 14, weight: FontWeight.w700);
      _text(canvas, ':', Offset(rect.left + 188, y),
          size: 14, weight: FontWeight.w700);
      _drawGridLine(
        canvas,
        Offset(rect.left + 230, y + 15),
        Offset(rect.right - 80, y + 15),
      );
      y += 30;
    }
  }

  static void _drawFooter(Canvas canvas, _FieldSnapshot f, int passNumber) {
    const rect = Rect.fromLTWH(18, 1214, 1764, 42);
    _drawBorder(canvas, rect, _line, 1);
    final widths = [240.0, 500.0, 250.0, 150.0, 340.0, 120.0, 164.0];
    final labels = [
      'Generated by KROSCEK',
      'Field Inspection Output Form - Detasselling & Isolation Audit',
      'Form ID   ${f.fieldNumber}',
      'Pass   P$passNumber',
      'Doc Code   KC-QA-FRM-DET-01',
      'Rev.   00',
      'Page  1 of 1',
    ];
    var x = rect.left;
    for (var i = 0; i < widths.length; i++) {
      if (i > 0) {
        _drawGridLine(canvas, Offset(x, rect.top), Offset(x, rect.bottom));
      }
      _textCentered(
        canvas,
        labels[i],
        Rect.fromLTWH(x + 8, rect.top + 12, widths[i] - 16, 16),
        size: 13.5,
        weight: i == 0 || i == 2 || i == 3 ? FontWeight.w900 : FontWeight.w700,
        color: i == 0 || i == 2 || i == 3 ? _green : _ink,
      );
      x += widths[i];
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

  static Future<io.File> _saveToAppDocuments(
      Uint8List bytes, String fileName) async {
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
    if (io.Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
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

  static String _fileName(DetasselingIsoFormData data, String extension) {
    final f = _FieldSnapshot.from(data);
    final pass = 'P${data.passNumber}';
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fn = _safePart(f.fieldNumber);
    return 'iso_detasselling_${fn}_${pass}_$stamp.$extension';
  }

  static List<DateTime> _planDates(
    DateTime plantingDate,
    int passCount,
    int startDap,
  ) {
    final p1 = DateTime(plantingDate.year, plantingDate.month, plantingDate.day)
        .add(Duration(days: startDap - 1));
    return List.generate(passCount, (i) => p1.add(Duration(days: i * 2)));
  }

  static Map<int, DateTime> _actualDates(
    DetasselingIsoFormData data,
    int passCount,
  ) {
    final result = <int, DateTime>{};
    for (var pass = 1; pass <= passCount; pass++) {
      final parsed = _parseDate(data.auditData['date_of_audit_$pass']);
      if (parsed != null) result[pass] = parsed;
    }
    return result;
  }

  static List<DateTime> _dateWindow(
    List<DateTime> planDates,
    List<DateTime> actualDates,
  ) {
    final all = [...planDates, ...actualDates];
    all.sort();
    final first = all.isEmpty ? DateTime.now() : all.first;
    final last = all.isEmpty ? DateTime.now() : all.last;
    var start = DateTime(first.year, first.month, first.day)
        .subtract(const Duration(days: 8));
    var days = last.difference(start).inDays + 3;
    if (days < 17) days = 17;
    if (days > 19) {
      start = DateTime(first.year, first.month, first.day)
          .subtract(const Duration(days: 6));
      days = 19;
    }
    return List.generate(days, (i) => start.add(Duration(days: i)));
  }

  static int? _passForDate(List<DateTime> planDates, DateTime date) {
    for (var i = 0; i < planDates.length; i++) {
      if (_isSameDay(planDates[i], date)) return i + 1;
    }
    return null;
  }

  static int? _actualPassForDate(
      Map<int, DateTime> actualDates, DateTime date) {
    for (final entry in actualDates.entries) {
      if (_isSameDay(entry.value, date)) return entry.key;
    }
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static void _drawLeafLogo(Canvas canvas, Offset origin) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _green;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE9F6EC);
    final path = Path()
      ..moveTo(origin.dx + 18, origin.dy + 44)
      ..quadraticBezierTo(
          origin.dx + 10, origin.dy + 10, origin.dx + 44, origin.dy + 0)
      ..quadraticBezierTo(
          origin.dx + 60, origin.dy + 30, origin.dx + 18, origin.dy + 44);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.drawLine(Offset(origin.dx + 25, origin.dy + 40),
        Offset(origin.dx + 42, origin.dy + 8), stroke);
  }

  static void _drawImageContain(Canvas canvas, ui.Image image, Rect rect) {
    final imageRatio = image.width / image.height;
    final rectRatio = rect.width / rect.height;
    late final Rect dst;
    if (imageRatio > rectRatio) {
      final height = rect.width / imageRatio;
      dst = Rect.fromLTWH(
        rect.left,
        rect.top + (rect.height - height) / 2,
        rect.width,
        height,
      );
    } else {
      final width = rect.height * imageRatio;
      dst = Rect.fromLTWH(
        rect.left + (rect.width - width) / 2,
        rect.top,
        width,
        rect.height,
      );
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  static void _drawFlagIcon(Canvas canvas, Offset origin, Color color) {
    final pole = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..color = Colors.black.withAlpha(190);
    canvas.drawLine(origin, Offset(origin.dx, origin.dy + 28), pole);

    final flag = Path()
      ..moveTo(origin.dx + 1, origin.dy + 1)
      ..lineTo(origin.dx + 28, origin.dy + 5)
      ..lineTo(origin.dx + 28, origin.dy + 19)
      ..lineTo(origin.dx + 1, origin.dy + 15)
      ..close();
    canvas.drawPath(
      flag,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  static void _drawSectionTitle(Canvas canvas, Rect rect, String text) {
    _drawFilledRect(canvas, rect, _green);
    _textCentered(
      canvas,
      text,
      Rect.fromLTWH(rect.left, rect.top + 8, rect.width, rect.height - 12),
      size: 18,
      weight: FontWeight.w900,
      color: Colors.white,
    );
  }

  static void _drawFilledRect(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(rect, paint);
  }

  static void _drawRoundedFill(
      Canvas canvas, Rect rect, Color color, double radius) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  static void _drawBorder(Canvas canvas, Rect rect, Color color, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    canvas.drawRect(rect, paint);
  }

  static void _drawGridLine(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = _line;
    canvas.drawLine(start, end, paint);
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
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd-MM-yyyy', 'id_ID').format(date);
  }

  static String _longDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  static String _dayMonth(DateTime date) {
    return DateFormat('d MMM', 'id_ID').format(date);
  }

  static String _formatHa(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  static List<int> _allocateTkdByPass(double areaHa, List<int> passTkdPerHa) {
    if (areaHa <= 0) return List.filled(passTkdPerHa.length, 0);

    final exact = passTkdPerHa.map((value) => areaHa * value).toList();
    final floors = exact.map((value) => value.floor()).toList();
    final targetTotal =
        exact.fold<double>(0, (total, value) => total + value).round();
    var remainder = targetTotal - floors.fold<int>(0, (a, b) => a + b);
    if (remainder <= 0) return floors;

    final order = List<int>.generate(exact.length, (index) => index);
    order.sort((a, b) {
      final aFraction = exact[a] - floors[a];
      final bFraction = exact[b] - floors[b];
      final byFraction = bFraction.compareTo(aFraction);
      if (byFraction != 0) return byFraction;
      return a.compareTo(b);
    });

    var cursor = 0;
    while (remainder > 0 && order.isNotEmpty) {
      floors[order[cursor % order.length]] += 1;
      cursor++;
      remainder--;
    }
    return floors;
  }

  static Color _flaggingColor(String value) {
    switch (value.trim().toUpperCase()) {
      case 'GF':
        return const Color(0xFF2E7D32);
      case 'RFI':
      case 'RFD':
        return const Color(0xFFE53935);
      case 'BF':
        return Colors.black;
      case 'PLD':
        return const Color(0xFFF5C400);
      default:
        return _green;
    }
  }

  static Color _flaggingTextColor(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized == 'PLD' ? Colors.black : Colors.white;
  }

  static String _weekLabel(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    final week = (date.difference(start).inDays / 7).ceil();
    return 'W${week.toString().padLeft(2, '0')}';
  }

  static String _femaleShedding(String value) {
    final v = _norm(value);
    if (v == '0' || v == 'a') return 'A (0)';
    if (v.contains('>0') && v.contains('<2') || v == 'b') return 'B (>0 <2)';
    if (v.contains('2') && v.contains('5') || v == 'c') return 'C (2-5)';
    if (v.contains('>=5') || v.contains('≥5') || v == 'd') return 'D (>=5)';
    return _dash(value);
  }

  static String _offtype(String value) {
    final v = _norm(value);
    if (v == '0' || v == 'a') return 'A';
    if (v.contains('>0') || v == 'b') return 'B';
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

  static String _score(String value) {
    final v = _norm(value);
    const map = {
      'very poor': '1 (Very Poor)',
      'poor': '2 (Poor)',
      'fair': '3 (Fair)',
      'good': '4 (Good)',
      'best': '5 (Best)',
      '1': '1 (Very Poor)',
      '2': '2 (Poor)',
      '3': '3 (Fair)',
      '4': '4 (Good)',
      '5': '5 (Best)',
    };
    return map[v] ?? _dash(value);
  }

  static String _detasseling(String value) {
    final v = _norm(value);
    const map = {
      'best': 'A (Best)',
      'good': 'B (Good)',
      'fair': 'C (Fair)',
      'poor': 'D (Poor)',
      'very poor': 'E (Very Poor)',
      'a': 'A (Best)',
      'b': 'B (Good)',
      'c': 'C (Fair)',
      'd': 'D (Poor)',
      'e': 'E (Very Poor)',
    };
    return map[v] ?? _dash(value);
  }

  static String _yesNo(String value) {
    final v = _norm(value);
    if (v == 'yes' || v == 'found' || v == 'a') return 'A (Yes)';
    if (v == 'no' || v == 'not found' || v == 'b') return 'B (No)';
    return _dash(value);
  }

  static String _action(String value) {
    final v = _norm(value);
    const map = {
      'none': 'A (None)',
      'roguing': 'B (Roguing)',
      're-detasseling': 'C (Re-Detasseling)',
      'monitor': 'D (Monitor)',
      'hold': 'E (Hold)',
      'discard partial': 'F (Discard Partial)',
      'discard full': 'G (Discard Full)',
      'a': 'A (None)',
      'b': 'B (Roguing)',
      'c': 'C (Re-Detasseling)',
      'd': 'D (Monitor)',
      'e': 'E (Hold)',
      'f': 'F (Discard Partial)',
      'g': 'G (Discard Full)',
    };
    return map[v] ?? _dash(value);
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
        .replaceAll(RegExp(r'^[a-z0-9]{1,4}\s*-\s*'), '');
  }

  static String _readText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static String _actualTkdLabel(int? value) {
    return value == null ? '-' : value.toString();
  }

  static String _personCode(String value) {
    final text = value.trim();
    if (text.isEmpty) return '-';
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return '-';
    if (words.length == 1) {
      final word = words.first;
      return word.length <= 4 ? word.toUpperCase() : word.substring(0, 4);
    }
    return words
        .take(2)
        .map((word) => word.substring(0, 1).toUpperCase())
        .join();
  }

  static double _readArea(Map<String, dynamic> raw) {
    for (final value in [
      raw['effective_area_ha'],
      raw['effective_area'],
      raw['area_ha'],
      raw['ha'],
    ]) {
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static Map<String, dynamic>? _firstRow(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    try {
      final parsed = DateTime.tryParse(text);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
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
      return null;
    } catch (_) {
      return null;
    }
  }

  static int _dapOnDate(DateTime plantingDate, DateTime targetDate) {
    final planting =
        DateTime(plantingDate.year, plantingDate.month, plantingDate.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(planting).inDays + 1;
  }

  static String _safePart(String value) {
    final safe = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'fn' : safe;
  }
}

class _FieldSnapshot {
  final String fieldNumber;
  final String farmer;
  final String codet;
  final String village;
  final String hybrid;
  final String season;
  final String region;
  final String crop;
  final String week;
  final DateTime auditDate;
  final DateTime plantingDate;
  final double areaHa;
  final double totalAreaHa;
  final int estimatedDap;
  final int detasselingStartDap;
  final String qaFi;
  final String qaSpv;
  final String auditHelper;
  final Map<int, int> actualTkdByPass;
  final Map<int, String> auditFiByPass;
  final Map<int, String> auditHelperByPass;
  final String femaleShedding;
  final String offtypeM;
  final String offtypeF;
  final String lsvStatus;
  final String cropUniformity;
  final String cropHealth;
  final String detasselingAssessment;
  final String isolationStatus;
  final String affectedOtherField;
  final String actionNeeded;
  final String remarks;
  final String flagging;

  const _FieldSnapshot({
    required this.fieldNumber,
    required this.farmer,
    required this.codet,
    required this.village,
    required this.hybrid,
    required this.season,
    required this.region,
    required this.crop,
    required this.week,
    required this.auditDate,
    required this.plantingDate,
    required this.areaHa,
    required this.totalAreaHa,
    required this.estimatedDap,
    required this.detasselingStartDap,
    required this.qaFi,
    required this.qaSpv,
    required this.auditHelper,
    required this.actualTkdByPass,
    required this.auditFiByPass,
    required this.auditHelperByPass,
    required this.femaleShedding,
    required this.offtypeM,
    required this.offtypeF,
    required this.lsvStatus,
    required this.cropUniformity,
    required this.cropHealth,
    required this.detasselingAssessment,
    required this.isolationStatus,
    required this.affectedOtherField,
    required this.actionNeeded,
    required this.remarks,
    required this.flagging,
  });

  bool get isSweetCorn => crop.toUpperCase() == 'SC';

  int recommendedTkdForPass(int pass) {
    final passTkdPerHa = isSweetCorn ? const [4, 4, 4, 4, 4] : const [5, 5, 5];
    if (pass < 1 || pass > passTkdPerHa.length) return 0;
    return DetasselingIsoExportService._allocateTkdByPass(
      totalAreaHa,
      passTkdPerHa,
    )[pass - 1];
  }

  String get actionRemarks {
    final action = DetasselingIsoExportService._action(actionNeeded);
    final note = remarks.trim();
    if (action == '-' && note.isEmpty) return '';
    if (action == '-') return note;
    if (note.isEmpty) return action;
    return '$action | $note';
  }

  factory _FieldSnapshot.from(DetasselingIsoFormData data) {
    final raw = data.fieldData;
    final audit = data.auditData;
    final veg = DetasselingIsoExportService._firstRow(raw['audit_vegetative']);
    final plantingDate =
        DetasselingIsoExportService._parseDate(veg?['rev_planting_date']) ??
            DetasselingIsoExportService._parseDate(raw['planting_date_pdn']) ??
            DateTime.now();
    final auditDate = DetasselingIsoExportService._parseDate(
            audit['date_of_audit_${data.passNumber}']) ??
        DateTime.now();
    final cropLabel = data.cropLabel.trim().toUpperCase().isEmpty
        ? 'FC'
        : data.cropLabel.trim().toUpperCase();
    final rawHybrid = raw['hybrid']?.toString();
    final helperHybrid = cropLabel == 'SC' && !DapHelper.isSweetCorn(rawHybrid)
        ? 'AX01'
        : rawHybrid;
    final detasselingStartDap = DapHelper.detasselingStartDapForValues(
      hybrid: helperHybrid,
      district: raw['district_kab']?.toString(),
      region: raw['region']?.toString(),
      subDistrict: raw['sub_district_kec']?.toString(),
    );
    final passOne =
        DateTime(plantingDate.year, plantingDate.month, plantingDate.day)
            .add(Duration(days: detasselingStartDap - 1));

    final actualTkdByPass = <int, int>{};
    final auditFiByPass = <int, String>{};
    final auditHelperByPass = <int, String>{};
    for (var pass = 1; pass <= 5; pass++) {
      final actualTkd =
          DetasselingIsoExportService._readInt(audit['actual_tkd_$pass']);
      if (actualTkd != null) actualTkdByPass[pass] = actualTkd;

      final auditFi = DetasselingIsoExportService._readText(
        audit['qa_fi_$pass'] ?? audit['qa_fi'],
        fallback: '',
      );
      if (auditFi.isNotEmpty) auditFiByPass[pass] = auditFi;

      final auditHelper = DetasselingIsoExportService._readText(
        audit['audit_helper_$pass'],
        fallback: '',
      );
      if (auditHelper.isNotEmpty) auditHelperByPass[pass] = auditHelper;
    }

    return _FieldSnapshot(
      fieldNumber: DetasselingIsoExportService._readText(raw['field_number']),
      farmer: DetasselingIsoExportService._readText(raw['farmer_name']),
      codet: DetasselingIsoExportService._readText(
        veg?['co_detasseling'],
        fallback: 'Belum ada Codet',
      ),
      village: DetasselingIsoExportService._readText(raw['village_desa']),
      hybrid: DetasselingIsoExportService._readText(raw['hybrid']),
      season: DetasselingIsoExportService._readText(raw['season']),
      region: DetasselingIsoExportService._readText(raw['region']),
      crop: cropLabel,
      week: DetasselingIsoExportService._weekLabel(auditDate),
      auditDate: auditDate,
      plantingDate: plantingDate,
      areaHa: DetasselingIsoExportService._readArea(raw),
      totalAreaHa: DetasselingIsoExportService._readArea(raw),
      estimatedDap:
          DetasselingIsoExportService._dapOnDate(plantingDate, passOne),
      detasselingStartDap: detasselingStartDap,
      qaFi: DetasselingIsoExportService._readText(
        audit['qa_fi_${data.passNumber}'] ?? audit['qa_fi'],
      ),
      qaSpv: DetasselingIsoExportService._readText(audit['qa_spv']),
      auditHelper: DetasselingIsoExportService._readText(
        audit['audit_helper_${data.passNumber}'],
      ),
      actualTkdByPass: actualTkdByPass,
      auditFiByPass: auditFiByPass,
      auditHelperByPass: auditHelperByPass,
      femaleShedding: DetasselingIsoExportService._readText(
        audit['female_shedding_${data.passNumber}'],
        fallback: '',
      ),
      offtypeM: DetasselingIsoExportService._readText(
        audit['offtype_m_${data.passNumber}'],
        fallback: '',
      ),
      offtypeF: DetasselingIsoExportService._readText(
        audit['offtype_f_${data.passNumber}'],
        fallback: '',
      ),
      lsvStatus: DetasselingIsoExportService._readText(
        audit['lsv_status_${data.passNumber}'],
        fallback: '',
      ),
      cropUniformity: DetasselingIsoExportService._readText(
        audit['crop_uniformity_${data.passNumber}'],
        fallback: '',
      ),
      cropHealth: DetasselingIsoExportService._readText(
        audit['crop_health_${data.passNumber}'],
        fallback: '',
      ),
      detasselingAssessment: DetasselingIsoExportService._readText(
        audit['detasseling_assesment_${data.passNumber}'],
        fallback: '',
      ),
      isolationStatus: DetasselingIsoExportService._readText(
        audit['isolation_status_${data.passNumber}'] ??
            audit['isolation_problem_${data.passNumber}'],
        fallback: '',
      ),
      affectedOtherField: DetasselingIsoExportService._readText(
        audit['affected_other_field_${data.passNumber}'],
        fallback: '',
      ),
      actionNeeded: DetasselingIsoExportService._readText(
        audit['action_needed_${data.passNumber}'] ??
            audit['final_decision_${data.passNumber}'],
        fallback: '',
      ),
      remarks: DetasselingIsoExportService._readText(
        audit['remarks_${data.passNumber}'],
        fallback: '',
      ),
      flagging: DetasselingIsoExportService._readText(
        audit['flagging'] ?? audit['final_flagging_${data.passNumber}'],
        fallback: '',
      ),
    );
  }
}
