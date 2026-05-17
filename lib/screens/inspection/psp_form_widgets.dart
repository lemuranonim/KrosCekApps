// lib/screens/inspection/psp_form_widgets.dart
//
// Shared design tokens & widgets for PSP/PS inspection forms.
// Kept separate from FC/SC widgets so PSP-specific labels, validation,
// and visual treatment can evolve without touching the other crop flows.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// PSP/PS ACCENT COLORS (fixed — not theme-dependent)
// ─────────────────────────────────────────────────────────
const kPspVegetativeColor = Color(0xFF78909C);
const kPspGenerativeColor = Color(0xFFE53935);
const kPspHarvestColor = Color(0xFF43A047);

// ─────────────────────────────────────────────────────────
// INTERNAL THEME HELPERS
// ─────────────────────────────────────────────────────────
extension _PspTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get pspSurface => isDark ? AdvantaColors.primaryGreen : Colors.white;
  Color get pspBorder =>
      isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
  Color get pspSub => isDark ? Colors.white60 : AdvantaColors.mutedGrey;
  Color get pspText => Theme.of(this).colorScheme.onSurface;
  Color get pspFill =>
      isDark ? AdvantaColors.deepForest.withAlpha(200) : AdvantaColors.softGrey;
}

// ─────────────────────────────────────────────────────────
// OPTION MODEL
// ─────────────────────────────────────────────────────────
class PspOpt {
  // `value` is kept as the legacy code so older rows still render selected;
  // new submissions persist `persistedValue`.
  final String value;
  final String label;
  const PspOpt(this.value, this.label);

  String get persistedValue => pspPersistedOptionValue(label);
}

String pspPersistedOptionValue(String label) {
  final trimmed = label.trim();
  final match = RegExp(r'^[A-Z0-9]{1,4}\s+[–-]\s+(.+)$').firstMatch(trimmed);
  return match?.group(1)?.trim() ?? trimmed;
}

String pspLegacyOptionValue(String label) {
  final trimmed = label.trim();
  final match = RegExp(r'^([A-Z0-9]{1,4})\s+[–-]\s+.+$').firstMatch(trimmed);
  if (match != null) return match.group(1)?.trim() ?? '';
  const aliases = {
    'Corn After Corn': 'CAC',
    'Not Corn': 'NC',
    'Stage 2': '2',
    'Stage 3': '3',
    'Stage 4': '4',
    'Found': 'Y',
    'Not Found': 'N',
  };
  return aliases[trimmed] ?? '';
}

bool pspOptionMatches(String? value, PspOpt option) {
  if (value == null) return false;
  final trimmed = value.trim();
  final legacyValue = pspLegacyOptionValue(option.label);
  return trimmed == option.value ||
      trimmed == option.label ||
      trimmed == option.persistedValue ||
      (legacyValue.isNotEmpty && trimmed == legacyValue);
}

String? pspResolveOptionValue(String? value, List<PspOpt> options) {
  if (value == null || value.trim().isEmpty) return value;
  for (final option in options) {
    if (pspOptionMatches(value, option)) return option.persistedValue;
  }
  return value;
}

bool pspValueIn(String? value, Iterable<String> accepted) {
  if (value == null) return false;
  final normalized = value.trim().toLowerCase();
  return accepted.any((item) => normalized == item.trim().toLowerCase());
}

bool pspIsDiscardFull(String? value) =>
    pspValueIn(value, const ['G', 'Discard Full']);

bool pspIsDiscardDecision(String? value) =>
    pspValueIn(value, const ['D', 'Discard', 'PLD']);

// ─────────────────────────────────────────────────────────
// PSP/PS COMMON OPTION LISTS
// ─────────────────────────────────────────────────────────
const pspBinaryFindingOpts = [
  PspOpt('0', 'A - 0'),
  PspOpt('>0', 'B - >0'),
];

const pspNoYesOpts = [
  PspOpt('NO', 'A - NO'),
  PspOpt('YES', 'B - YES'),
];

const pspScoreOpts = [
  PspOpt('Very Poor', '1 - Very Poor'),
  PspOpt('Poor', '2 - Poor'),
  PspOpt('Fair', '3 - Fair'),
  PspOpt('Good', '4 - Good'),
  PspOpt('Best', '5 - Best'),
];

const pspPreviousCropActualOpts = [
  PspOpt('Not Corn', 'A - Not Corn'),
  PspOpt('Corn after corn with different trait',
      'B - Corn after corn with different trait'),
  PspOpt('Corn after Corn same trait', 'C - Corn after Corn same trait'),
];

const pspIsolationTypeOpts = [
  PspOpt('Other Seed Production', 'A - Other Seed Production'),
  PspOpt('Commercial', 'B - Commercial'),
];

const pspIsolationDistanceOpts = [
  PspOpt('>400', 'A - >400'),
  PspOpt('<400', 'B - <400'),
];

const pspRecommendationOpts = [
  PspOpt('Continue', 'Continue'),
  PspOpt('Discard', 'Discard'),
];

const pspRoguingFlaggingOpts = [
  PspOpt('GF', 'GF'),
  PspOpt('OF', 'OF'),
  PspOpt('RF', 'RF'),
];

const pspTypeSeedOpts = [
  PspOpt('Pre Basic', 'Pre Basic'),
  PspOpt('Basic', 'Basic'),
];

const pspHarvestEarConditionOpts = [
  PspOpt('Stage 2', 'Stage 2'),
  PspOpt('Stage 3', 'Stage 3'),
  PspOpt('Stage 4', 'Stage 4'),
];

const pspHarvestReasonDowngradeOpts = [
  PspOpt('Suspect Mix Material', 'A - Suspect Mix Material'),
  PspOpt('Not Accessible during Detasseling',
      'B - Not Accessible during Detasseling'),
  PspOpt('Not Sure during Harvest', 'C - Not Sure during Harvest'),
];

const pspHarvestStatusDowngradeOpts = [
  PspOpt('Yes', 'A - Yes'),
  PspOpt('No', 'B - No'),
];

const pspHarvestDowngradeFlaggingOpts = [
  PspOpt('RFI', 'RFI'),
  PspOpt('RFD', 'RFD'),
];

const pspHarvestFinalFlaggingOpts = [
  PspOpt('GF', 'GF'),
  PspOpt('RFI', 'RFI'),
  PspOpt('RFD', 'RFD'),
  PspOpt('BF', 'BF'),
  PspOpt('PLD', 'PLD'),
];

// ─────────────────────────────────────────────────────────
// WEEK HELPER
// ─────────────────────────────────────────────────────────
String calcAuditWeek(DateTime date) {
  final start = DateTime(date.year, 1, 1);
  final week = (date.difference(start).inDays / 7).ceil();
  return 'W${week.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────
// DATE PICKER THEME HELPER
// ─────────────────────────────────────────────────────────
ThemeData pspDatePickerTheme(BuildContext context, Color accentColor) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: accentColor,
            surface: AdvantaColors.primaryGreen,
          ),
        )
      : ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: accentColor,
            surface: Colors.white,
            onSurface: AdvantaColors.deepForest,
          ),
        );
}

// ─────────────────────────────────────────────────────────
// APP BAR  (replaces buildPspAppBar function — now context-aware)
// ─────────────────────────────────────────────────────────
class PspAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String checkpointLabel;
  final String fieldNumber;
  final bool isDiscard;
  final Color accentColor;
  final VoidCallback onBack;

  const PspAppBar({
    super.key,
    required this.checkpointLabel,
    required this.fieldNumber,
    required this.isDiscard,
    required this.accentColor,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discardBg = isDark ? const Color(0xFF7B1821) : AdvantaColors.error;
    final normalBg =
        isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen;
    final bgColor = isDiscard ? discardBg : normalBg;
    final fgColor =
        isDark && !isDiscard ? AdvantaColors.goldLight : Colors.white;
    final labelColor = isDiscard
        ? const Color(0xFFFF8A80)
        : (isDark
            ? AdvantaColors.goldLight.withAlpha(200)
            : Colors.white.withAlpha(210));
    final borderColor =
        isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(25);

    return AppBar(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: fgColor, size: 18),
        onPressed: onBack,
        tooltip: 'Kembali ke Field Detail',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            checkpointLabel,
            style: AdvantaText.caption.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            'Field #$fieldNumber',
            style: AdvantaText.heading3.copyWith(color: fgColor),
          ),
        ],
      ),
      actions: [
        if (isDiscard)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdvantaColors.error.withAlpha(isDark ? 60 : 30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AdvantaColors.error.withAlpha(isDark ? 120 : 80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFF8A80), size: 14),
                SizedBox(width: 4),
                Text(
                  'DISCARD',
                  style: TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: borderColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// FIELD INFO CARD (read-only summary)
// ─────────────────────────────────────────────────────────
class PspFieldCard extends StatelessWidget {
  final Map<String, dynamic> fieldData;
  final Color accentColor;

  const PspFieldCard({
    super.key,
    required this.fieldData,
    required this.accentColor,
  });

  String _f(dynamic v) =>
      (v == null || v.toString().trim().isEmpty) ? '—' : v.toString();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(isDark ? 25 : 15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withAlpha(isDark ? 80 : 55)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, color: accentColor, size: 13),
              const SizedBox(width: 7),
              Text(
                'DATA LAHAN PSP/PS (READ ONLY)',
                style: AdvantaText.caption.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Cell('Petani', _f(fieldData['farmer_name']))),
            Expanded(child: _Cell('Hybrid', _f(fieldData['hybrid']))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _Cell('Grower', _f(fieldData['grower']))),
            Expanded(
                child: _Cell(
                    'Efektif', '${_f(fieldData['effective_area_ha'])} Ha')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _Cell('Season', _f(fieldData['season']))),
            Expanded(child: _Cell('Region', _f(fieldData['region']))),
          ]),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  const _Cell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AdvantaText.caption.copyWith(
                  color: context.pspSub, fontWeight: FontWeight.w500)),
          Text(value,
              style: AdvantaText.body2.copyWith(
                  color: context.pspText, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────
class PspSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const PspSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.pspSurface;
    final borderColor = context.pspBorder;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: AdvantaText.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class PspRoguingAuditItem {
  final String label;
  final DateTime? date;
  final Color color;
  final IconData icon;

  const PspRoguingAuditItem({
    required this.label,
    required this.date,
    required this.color,
    required this.icon,
  });
}

class PspRoguingAuditSelector extends StatelessWidget {
  final List<PspRoguingAuditItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PspRoguingAuditSelector({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.pspSurface;
    final fill = context.pspFill;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final textColor = context.pspText;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == selectedIndex;
          final dateText = item.date == null
              ? 'Belum'
              : DateFormat('dd MMM').format(item.date!);
          final statusColor = item.date == null ? subColor : item.color;
          return Padding(
            padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 10),
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 124,
                height: 62,
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? item.color.withAlpha(isDark ? 48 : 24)
                      : surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? item.color : borderColor,
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? item.color.withAlpha(isDark ? 70 : 38)
                            : fill,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        item.icon,
                        color: selected ? item.color : subColor,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdvantaText.caption.copyWith(
                              color: selected ? item.color : textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdvantaText.caption.copyWith(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: item.date == null
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// DATE PICKER TILE — required date
// ─────────────────────────────────────────────────────────
class PspDateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool required;
  final bool allowFuture;
  final VoidCallback onTap;

  const PspDateTile({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.required = true,
    this.allowFuture = false,
  });

  @override
  Widget build(BuildContext context) {
    final weekLabel = calcAuditWeek(date);
    final bgColor = context.pspFill;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final textColor = context.pspText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: subColor, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(required ? '$label *' : label,
                      style: AdvantaText.caption.copyWith(
                          color: subColor, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(date),
                    style: AdvantaText.body1.copyWith(
                        color: textColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text(weekLabel,
                style: AdvantaText.caption
                    .copyWith(color: subColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Icon(Icons.edit_calendar_outlined, color: subColor, size: 15),
          ],
        ),
      ),
    );
  }
}

// DATE PICKER TILE — optional / nullable
class PspDateTileNullable extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const PspDateTileNullable({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = context.pspFill;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final textColor = context.pspText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: subColor, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AdvantaText.caption.copyWith(
                          color: subColor, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? DateFormat('dd MMMM yyyy', 'id_ID').format(date!)
                        : 'Pilih tanggal (opsional)',
                    style: AdvantaText.body1.copyWith(
                      color: date != null ? textColor : subColor,
                      fontWeight:
                          date != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, color: subColor, size: 16),
              )
            else
              Icon(Icons.edit_calendar_outlined, color: subColor, size: 15),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TEXT FIELD
// ─────────────────────────────────────────────────────────
class PspTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final IconData? icon;
  final Color? accentColor;

  const PspTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final bgColor = context.pspFill;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final textColor = context.pspText;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: AdvantaText.body1.copyWith(color: textColor),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: AdvantaText.caption.copyWith(color: subColor),
        hintText: hint,
        hintStyle: AdvantaText.caption.copyWith(color: subColor.withAlpha(120)),
        prefixIcon: icon != null ? Icon(icon, color: subColor, size: 16) : null,
        filled: true,
        fillColor: bgColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdvantaColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdvantaColors.error, width: 1.5),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
          : null,
    );
  }
}

class PspQaAutocomplete extends StatefulWidget {
  final String label;
  final String hint;
  final String column;
  final TextEditingController controller;
  final IconData icon;
  final Color accentColor;
  final bool required;

  const PspQaAutocomplete({
    super.key,
    required this.label,
    required this.hint,
    required this.column,
    required this.controller,
    required this.icon,
    required this.accentColor,
    this.required = false,
  });

  @override
  State<PspQaAutocomplete> createState() => _PspQaAutocompleteState();
}

class _PspQaAutocompleteState extends State<PspQaAutocomplete> {
  Future<Iterable<String>> _fetchQA(String query) async {
    if (query.trim().isEmpty) return const Iterable<String>.empty();
    try {
      final response = await Supabase.instance.client
          .from('master_fields')
          .select(widget.column)
          .ilike(widget.column, '%${query.trim()}%')
          .limit(20);

      final data = List<dynamic>.from(response);
      final uniqueNames = data
          .map((e) => e[widget.column]?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .map((s) => s.toUpperCase())
          .toSet();

      return uniqueNames.take(5);
    } catch (e) {
      debugPrint('Error fetching QA autocomplete: $e');
      return const Iterable<String>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;
    final fillColor = context.pspFill;
    final borderColor = context.pspBorder;
    final textColor = context.pspText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.required ? '${widget.label} *' : widget.label,
          style: AdvantaText.body2
              .copyWith(color: subColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: widget.controller.text),
          optionsBuilder: (value) => _fetchQA(value.text),
          onSelected: (selection) {
            widget.controller.text = selection;
            FocusScope.of(context).unfocus();
          },
          fieldViewBuilder:
              (context, fieldController, focusNode, onFieldSubmitted) {
            if (fieldController.text != widget.controller.text) {
              fieldController.text = widget.controller.text;
              fieldController.selection =
                  TextSelection.collapsed(offset: fieldController.text.length);
            }

            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters,
              style: AdvantaText.body1.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AdvantaText.caption
                    .copyWith(color: subColor.withAlpha(120)),
                prefixIcon:
                    Icon(widget.icon, color: widget.accentColor, size: 20),
                suffixIcon: fieldController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: subColor,
                        onPressed: () {
                          fieldController.clear();
                          widget.controller.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: fillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: widget.accentColor, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdvantaColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AdvantaColors.error, width: 1.5),
                ),
              ),
              validator: widget.required
                  ? (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
                  : null,
              onChanged: (value) => widget.controller.text = value,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width - 64,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AdvantaColors.deepForest : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Text(
                            option,
                            style: AdvantaText.body2.copyWith(
                              color: widget.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// OPTION PICKER — chip row (2–5 options)
// ─────────────────────────────────────────────────────────
class PspOptionPicker extends StatelessWidget {
  final String label;
  final bool required;
  final List<PspOpt> options;
  final String? value;
  final void Function(String?) onChanged;
  final Color? accentColor;

  const PspOptionPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final bgColor = context.pspFill;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FormField<String>(
      initialValue: value,
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Wajib dipilih' : null
          : null,
      builder: (state) {
        final resolvedValue = pspResolveOptionValue(value, options);
        if (resolvedValue != null && resolvedValue != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(resolvedValue);
            state.didChange(resolvedValue);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '$label *' : label,
              style: AdvantaText.caption
                  .copyWith(color: subColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) {
                final isSel = pspOptionMatches(value, opt);
                return GestureDetector(
                  onTap: () {
                    final next = isSel ? null : opt.persistedValue;
                    onChanged(next);
                    state.didChange(next);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isSel ? accent.withAlpha(isDark ? 55 : 28) : bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? accent : borderColor,
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      opt.label,
                      style: AdvantaText.caption.copyWith(
                        color: isSel ? accent : subColor,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 4),
              Text(state.errorText!,
                  style:
                      AdvantaText.caption.copyWith(color: AdvantaColors.error)),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// OPTION PICKER LONG — vertical radio list (6–7 options)
// ─────────────────────────────────────────────────────────
class PspOptionPickerLong extends StatelessWidget {
  final String label;
  final bool required;
  final List<PspOpt> options;
  final String? value;
  final void Function(String?) onChanged;
  final Color? accentColor;

  const PspOptionPickerLong({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final bgColor = context.pspFill;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FormField<String>(
      initialValue: value,
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Wajib dipilih' : null
          : null,
      builder: (state) {
        final resolvedValue = pspResolveOptionValue(value, options);
        if (resolvedValue != null && resolvedValue != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(resolvedValue);
            state.didChange(resolvedValue);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '$label *' : label,
              style: AdvantaText.caption
                  .copyWith(color: subColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...options.map((opt) {
              final isSel = pspOptionMatches(value, opt);
              return GestureDetector(
                onTap: () {
                  final next = isSel ? null : opt.persistedValue;
                  onChanged(next);
                  state.didChange(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? accent.withAlpha(isDark ? 55 : 25) : bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? accent : borderColor,
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isSel ? accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? accent : borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: isSel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 11)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        opt.label,
                        style: AdvantaText.body2.copyWith(
                          color: isSel ? accent : subColor,
                          fontWeight:
                              isSel ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (state.hasError) ...[
              const SizedBox(height: 4),
              Text(
                state.errorText!,
                style: AdvantaText.caption.copyWith(color: AdvantaColors.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// DISCARD BANNER
// ─────────────────────────────────────────────────────────
class PspDiscardBanner extends StatelessWidget {
  final String message;
  const PspDiscardBanner({
    super.key,
    this.message =
        'Mode Discard aktif — pastikan semua field wajib telah terisi.',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdvantaColors.error.withAlpha(isDark ? 40 : 18),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AdvantaColors.error.withAlpha(isDark ? 100 : 60)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AdvantaColors.error.withAlpha(isDark ? 220 : 200),
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AdvantaText.caption.copyWith(
                color: isDark ? const Color(0xFFFF8A80) : AdvantaColors.error,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SAVE BAR
// ─────────────────────────────────────────────────────────
class PspSaveBar extends StatelessWidget {
  final bool isSaving;
  final bool isDiscard;
  final String saveLabel;
  final VoidCallback onSave;

  const PspSaveBar({
    super.key,
    required this.isSaving,
    required this.isDiscard,
    required this.saveLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = context.pspSurface;
    final borderColor = context.pspBorder;
    final subColor = context.pspSub;
    final btnColor = isDiscard ? AdvantaColors.error : AdvantaColors.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: isSaving
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
                            strokeWidth: 2.5, color: subColor),
                      ),
                      const SizedBox(width: 12),
                      Text('Menyimpan…',
                          style: AdvantaText.body2.copyWith(color: subColor)),
                    ],
                  ),
                ),
              )
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: Icon(
                    isDiscard
                        ? Icons.do_not_disturb_on_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(saveLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: AdvantaText.button,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AdvantaRadius.buttonRadius),
                  ),
                ),
              ),
      ),
    );
  }
}
