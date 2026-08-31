import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/weekly_audit.dart';

String auditHa(double value) =>
    '${NumberFormat('#,##0.##', 'id_ID').format(value)} ha';

String auditWorkload(double areaHa, int fn) =>
    '${areaHa.toStringAsFixed(1)} Ha | $fn FN';

class AuditWeekFilter extends StatelessWidget {
  final Set<DateTime> selectedWeeks;
  final bool allWeeks;
  final String allLabel;
  final String allDescription;
  final void Function(Set<DateTime> weeks, bool allWeeks) onChanged;

  const AuditWeekFilter({
    super.key,
    required this.selectedWeeks,
    required this.allWeeks,
    required this.onChanged,
    this.allLabel = 'All Coverage',
    this.allDescription = 'Seluruh coverage dalam scope user',
  });

  @override
  Widget build(BuildContext context) {
    final sorted = selectedWeeks.toList()..sort();
    final label = allWeeks
        ? allLabel
        : sorted.length == 1
            ? _weekLabel(sorted.single)
            : '${sorted.length} Weeks';
    return ActionChip(
      avatar: const Icon(Icons.date_range_rounded,
          size: 17, color: AdvantaColors.primaryGreen),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AdvantaColors.deepForest)),
      backgroundColor: Colors.white,
      side: BorderSide(color: AdvantaColors.deepForest.withValues(alpha: .16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () => _openPicker(context),
    );
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final range = start.month == end.month
        ? '${start.day}–${DateFormat('d MMM yyyy', 'id_ID').format(end)}'
        : '${DateFormat('d MMM', 'id_ID').format(start)} – ${DateFormat('d MMM yyyy', 'id_ID').format(end)}';
    return 'W${auditIsoWeekNumber(start)} · $range';
  }

  Future<void> _openPicker(BuildContext context) async {
    final anchor = selectedWeeks.isEmpty
        ? auditWeekStart(DateTime.now())
        : (selectedWeeks.toList()..sort()).last;
    final options = List.generate(
        13, (index) => anchor.add(Duration(days: (index - 6) * 7)));
    final draft = {...selectedWeeks};
    var draftAll = allWeeks;
    final result = await showDialog<(Set<DateTime>, bool)>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('Filter week'),
                  content: SizedBox(
                      width: 340,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        CheckboxListTile(
                            dense: true,
                            title: Text(allLabel),
                            subtitle: Text(allDescription),
                            value: draftAll,
                            onChanged: (checked) => update(() {
                                  draftAll = checked == true;
                                  if (draftAll) draft.clear();
                                })),
                        const Divider(),
                        ...options.map((week) {
                          final end = week.add(const Duration(days: 6));
                          return CheckboxListTile(
                              dense: true,
                              title: Text(
                                  '${DateFormat('d MMM', 'id_ID').format(week)} – ${DateFormat('d MMM yyyy', 'id_ID').format(end)}'),
                              value: !draftAll && draft.contains(week),
                              onChanged: (checked) => update(() {
                                    draftAll = false;
                                    checked == true
                                        ? draft.add(week)
                                        : draft.remove(week);
                                  }));
                        }),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal')),
                    FilledButton(
                        onPressed: draftAll || draft.isNotEmpty
                            ? () => Navigator.pop(context, (draft, draftAll))
                            : null,
                        child: const Text('Terapkan'))
                  ],
                )));
    if (result != null) onChanged(result.$1, result.$2);
  }
}

class AuditWeekSelector extends StatelessWidget {
  final DateTime weekStart;
  final ValueChanged<DateTime> onChanged;
  const AuditWeekSelector(
      {super.key, required this.weekStart, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdvantaColors.dividerGrey),
            boxShadow: AdvantaShadows.card(false)),
        child: Row(children: [
          _weekButton(
              tooltip: 'Minggu sebelumnya',
              icon: Icons.chevron_left_rounded,
              onPressed: () =>
                  onChanged(weekStart.subtract(const Duration(days: 7)))),
          Expanded(
              child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: weekStart,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (date != null) onChanged(auditWeekStart(date));
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: AdvantaColors.paleGreen,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.date_range_rounded,
                                    size: 17,
                                    color: AdvantaColors.primaryGreen)),
                            const SizedBox(width: 9),
                            Flexible(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('MINGGU AUDIT',
                                      style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: .7,
                                          fontWeight: FontWeight.w800,
                                          color: AdvantaColors.mutedGrey)),
                                  const SizedBox(height: 1),
                                  Text(
                                      'W${auditIsoWeekNumber(weekStart)} · ${DateFormat('d MMM', 'id_ID').format(weekStart)} – ${DateFormat('d MMM yyyy', 'id_ID').format(end)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AdvantaColors.deepForest))
                                ]))
                          ])))),
          _weekButton(
              tooltip: 'Minggu berikutnya',
              icon: Icons.chevron_right_rounded,
              onPressed: () =>
                  onChanged(weekStart.add(const Duration(days: 7)))),
        ]));
  }

  Widget _weekButton(
          {required String tooltip,
          required IconData icon,
          required VoidCallback onPressed}) =>
      IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
              backgroundColor: AdvantaColors.softGrey,
              foregroundColor: AdvantaColors.primaryGreen),
          icon: Icon(icon),
          onPressed: onPressed);
}

class AuditFlagFilter extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const AuditFlagFilter(
      {super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => ActionChip(
        backgroundColor: Colors.white,
        side:
            BorderSide(color: AdvantaColors.deepForest.withValues(alpha: .16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        avatar: Icon(
            selected.contains('PLD')
                ? Icons.flag_outlined
                : Icons.visibility_off_outlined,
            color: AdvantaColors.primaryGreen,
            size: 17),
        label: Text(
            'Flagging ${selected.length}/${auditFlagLabels.length}${selected.contains('PLD') ? '' : ' · PLD hide'}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdvantaColors.deepForest)),
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
                                      child:
                                          const Text('Reset semua kategori')),
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
                        : flag == auditNotYetFlagging
                            ? AdvantaColors.mutedGrey
                            : AdvantaColors.error,
                () => _open('Flagging · $flag', (f) => f.flag == flag))),
          ]),
          Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdvantaColors.dividerGrey)),
              child: ExpansionTile(
                  title: const Text('Detail analytics',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AdvantaColors.deepForest)),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    _card('Crop monitoring', Icons.eco_outlined, [
                      _metric(
                          'CU oke · Fair / Good / Best',
                          cu,
                          AdvantaColors.midGreen,
                          () => _open(
                              'CU oke',
                              (f) => _cropOk(
                                  f.latest((o) => o.cu)?.toLowerCase() ?? ''))),
                      _metric(
                          'CH oke · Fair / Good / Best',
                          ch,
                          AdvantaColors.midGreen,
                          () => _open(
                              'CH oke',
                              (f) => _cropOk(
                                  f.latest((o) => o.ch)?.toLowerCase() ?? ''))),
                    ]),
                    _card('Male chopping', Icons.content_cut_rounded, [
                      _metric(
                          'Done / Complete',
                          chopping,
                          AdvantaColors.midGreen,
                          () => _open(
                              'Male chopping · Done',
                              (f) => _choppingDone(f
                                      .latest((o) => o.maleChopping)
                                      ?.toLowerCase() ??
                                  ''))),
                    ]),
                    _card('Stage', Icons.timeline_rounded, [
                      ...auditStageLabels.entries.map((stage) => _metric(
                          stage.value,
                          stages[stage.key] ??
                              AuditAreaMetric(
                                  0, summary.targetHa, summary.targetHa),
                          AdvantaColors.midGreen,
                          () => _open('Stage · ${stage.value}',
                              (f) => f.stage == stage.key))),
                    ]),
                  ])),
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

  Widget _metric(String label, AuditAreaMetric metric, Color color,
          VoidCallback onTap) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final value =
                          Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            '${metric.percent.toStringAsFixed(2)}% · ${auditHa(metric.areaHa)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: color)),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: color),
                      ]);
                      final title = Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600));
                      if (constraints.maxWidth < 280) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              const SizedBox(height: 2),
                              FittedBox(
                                  alignment: Alignment.centerRight,
                                  fit: BoxFit.scaleDown,
                                  child: value),
                            ]);
                      }
                      return Row(children: [
                        Expanded(child: title),
                        const SizedBox(width: 10),
                        value,
                      ]);
                    }),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                        value: (metric.percent / 100).clamp(0.0, 1.0),
                        color: color,
                        backgroundColor: color.withValues(alpha: .12),
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(8)),
                  ])));

  Widget _note(String text) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(text,
          style:
              const TextStyle(fontSize: 11, color: AdvantaColors.mutedGrey)));
}
