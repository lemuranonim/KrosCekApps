import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/weekly_audit.dart';

String auditHa(double value) =>
    '${NumberFormat('#,##0.##', 'id_ID').format(value)} ha';

class AuditWeekSelector extends StatelessWidget {
  final DateTime weekStart;
  final ValueChanged<DateTime> onChanged;
  const AuditWeekSelector(
      {super.key, required this.weekStart, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      IconButton(
          tooltip: 'Minggu sebelumnya',
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              onChanged(weekStart.subtract(const Duration(days: 7)))),
      TextButton.icon(
          icon: const Icon(Icons.date_range_rounded, size: 18),
          label: Text(
              '${DateFormat('d MMM', 'id_ID').format(weekStart)} – ${DateFormat('d MMM yyyy', 'id_ID').format(end)}'),
          onPressed: () async {
            final date = await showDatePicker(
                context: context,
                initialDate: weekStart,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100));
            if (date != null) onChanged(auditWeekStart(date));
          }),
      IconButton(
          tooltip: 'Minggu berikutnya',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(weekStart.add(const Duration(days: 7)))),
    ]);
  }
}

class AuditFlagFilter extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const AuditFlagFilter(
      {super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(
            selected.contains('PLD')
                ? Icons.flag_outlined
                : Icons.visibility_off_outlined,
            size: 16),
        label: Text(
            'Flagging ${selected.length}/${auditFlagLabels.length}${selected.contains('PLD') ? '' : ' · PLD hide'}'),
        onPressed: () async {
          final draft = {...selected};
          final result = await showDialog<Set<String>>(
              context: context,
              builder: (context) => StatefulBuilder(
                  builder: (context, update) => AlertDialog(
                        title: const Text('Filter flagging'),
                        content: SizedBox(
                            width: 320,
                            child: SingleChildScrollView(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Text(
                                      'Hanya kategori terpilih yang masuk hitungan ha dan persentase.'),
                                  ...auditFlagLabels
                                      .map((flag) => CheckboxListTile(
                                          dense: true,
                                          title: Text(flag),
                                          value: draft.contains(flag),
                                          onChanged: (checked) => update(() {
                                                if (checked == true) {
                                                  draft.add(flag);
                                                } else {
                                                  draft.remove(flag);
                                                }
                                              }))),
                                  TextButton(
                                      onPressed: () => update(() {
                                            draft.clear();
                                            draft.addAll(defaultAuditFlags);
                                          }),
                                      child: const Text(
                                          'Reset · PLD disembunyikan')),
                                ]))),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, draft),
                              child: const Text('Terapkan'))
                        ],
                      )));
          if (result != null) onChanged(result);
        },
      );
}

class WeeklyAuditCards extends StatelessWidget {
  final WeeklyAuditSummary summary;
  final void Function(String title, List<WeeklyAuditField> fields) onDetail;
  const WeeklyAuditCards(
      {super.key, required this.summary, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final flags = summary.composition((f) => f.flag);
    final stages = summary.composition((f) => f.stage);
    final cu = summary.metric((f) => f.latest((o) => o.cu), _cropOk);
    final ch = summary.metric((f) => f.latest((o) => o.ch), _cropOk);
    final chopping =
        summary.metric((f) => f.latest((o) => o.maleChopping), _choppingDone);
    final roguing = summary.metric((f) => f.latest((o) => o.roguing),
        (v) => const {'not yet', 'on going', 'a', 'b'}.contains(v));
    final lsv = summary.metric(
        (f) => f.latest((o) => o.lsv),
        (v) =>
            const {'low', 'moderate', 'high', '>0', 'b', 'c', 'd'}.contains(v));
    final isolation = summary.metric((f) => f.latest((o) => o.isolation),
        (v) => const {'yes', 'a'}.contains(v));
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(children: [
          _card('NC primer negatif', Icons.warning_amber_rounded, [
            _metric('Roguing belum Done', roguing, AdvantaColors.error,
                () => _open('NC · Roguing', (f) => f.roguingNegative)),
            _metric('LSV Low / Moderate / High', lsv, AdvantaColors.error,
                () => _open('NC · LSV', (f) => f.lsvNegative)),
            _metric('Isolasi bermasalah', isolation, AdvantaColors.error,
                () => _open('NC · Isolasi', (f) => f.isolationNegative)),
            _note(
                'Setiap indikator dihitung sendiri; satu lahan dapat memiliki beberapa NC.'),
          ]),
          _card('Komposisi flagging', Icons.flag_rounded, [
            if (flags.isEmpty)
              _note('Tidak ada target audit untuk filter ini.'),
            ...auditFlagLabels.where(flags.containsKey).map((flag) => _metric(
                flag,
                flags[flag]!,
                flag == 'GF'
                    ? AdvantaColors.midGreen
                    : flag == 'RFI'
                        ? AdvantaColors.gold
                        : flag == 'Belum ada'
                            ? AdvantaColors.mutedGrey
                            : AdvantaColors.error,
                () => _open('Flagging · $flag', (f) => f.flag == flag),
                assessed: false)),
            _note(
                'Persentase dihitung ulang dari luas kategori yang dipilih. Belum ada flagging tetap ditampilkan terpisah.'),
          ]),
          _card('Crop monitoring', Icons.eco_outlined, [
            _metric(
                'CU oke · Fair / Good / Best',
                cu,
                AdvantaColors.midGreen,
                () => _open(
                    'CU oke',
                    (f) =>
                        _cropOk(f.latest((o) => o.cu)?.toLowerCase() ?? ''))),
            _metric(
                'CH oke · Fair / Good / Best',
                ch,
                AdvantaColors.midGreen,
                () => _open(
                    'CH oke',
                    (f) =>
                        _cropOk(f.latest((o) => o.ch)?.toLowerCase() ?? ''))),
          ]),
          _card('Male chopping', Icons.content_cut_rounded, [
            _metric(
                'Done / Complete',
                chopping,
                AdvantaColors.midGreen,
                () => _open(
                    'Male chopping · Done',
                    (f) => _choppingDone(
                        f.latest((o) => o.maleChopping)?.toLowerCase() ?? ''))),
          ]),
          _card('Stage', Icons.timeline_rounded, [
            ...auditStageLabels.entries.map((stage) => _metric(
                stage.value,
                stages[stage.key] ??
                    AuditAreaMetric(0, summary.targetHa, summary.targetHa),
                AdvantaColors.midGreen,
                () => _open(
                    'Stage · ${stage.value}', (f) => f.stage == stage.key),
                assessed: false)),
            _note(
                'Fase berdasarkan DAP akhir minggu terpilih; setiap lahan dihitung satu kali.'),
          ]),
          _note(
              'Basis: ${auditHa(summary.targetHa)} target minggu terpilih. Kondisi memakai hasil audit terakhir sampai akhir minggu (maksimal hari ini). Data kosong tidak dianggap oke.'),
        ]));
  }

  static bool _cropOk(String value) =>
      const {'fair', 'good', 'best', '3', '4', '5'}.contains(value);
  static bool _choppingDone(String value) =>
      const {'done', 'complete', 'a'}.contains(value);
  void _open(String title, bool Function(WeeklyAuditField) predicate) =>
      onDetail(title, summary.fields.where(predicate).toList());

  Widget _card(String title, IconData icon, List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdvantaColors.dividerGrey)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: AdvantaColors.deepForest),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AdvantaColors.deepForest)))
        ]),
        const SizedBox(height: 12),
        ...children,
      ]));

  Widget _metric(
          String label, AuditAreaMetric metric, Color color, VoidCallback onTap,
          {bool assessed = true}) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                              '${metric.percent.toStringAsFixed(2)}% · ${auditHa(metric.areaHa)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                        ]),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                        value: (metric.percent / 100).clamp(0.0, 1.0),
                        color: color,
                        backgroundColor: color.withValues(alpha: .12),
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(8)),
                    if (assessed)
                      _note(
                          'Ada data ${auditHa(metric.assessedHa)} / ${auditHa(metric.baseHa)} target'),
                  ])));

  Widget _note(String text) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(text,
          style:
              const TextStyle(fontSize: 11, color: AdvantaColors.mutedGrey)));
}
