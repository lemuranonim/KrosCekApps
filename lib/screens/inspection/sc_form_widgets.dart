// lib/screens/inspection/generative_form_widgets.dart
//
// Shared design tokens & widgets for Form Generative 1 / 2 / 3.
// Fully aligned with AdvantaTheme — supports light & dark mode.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// PHASE ACCENT COLORS (fixed — not theme-dependent)
// ─────────────────────────────────────────────────────────
const kGen1Color = Color(0xFFFFCA28); // Generative CP1 — amber
const kGen2Color = Color(0xFFFF7043); // Generative CP2 — deep orange
const kGen3Color = Color(0xFFE53935); // Generative CP3 (Final) — red

// ─────────────────────────────────────────────────────────
// INTERNAL THEME HELPERS
// ─────────────────────────────────────────────────────────
extension _GenTheme on BuildContext {
  bool  get isDark      => Theme.of(this).brightness == Brightness.dark;
  Color get genSurface  => isDark ? AdvantaColors.primaryGreen : Colors.white;
  Color get genBorder   => isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(20);
  Color get genSub      => isDark ? Colors.white60 : AdvantaColors.mutedGrey;
  Color get genText     => Theme.of(this).colorScheme.onSurface;
  Color get genFill     => isDark
      ? AdvantaColors.deepForest.withAlpha(200)
      : AdvantaColors.softGrey;
}

// ─────────────────────────────────────────────────────────
// OPTION MODEL
// ─────────────────────────────────────────────────────────
class GenOpt {
  final String value;
  final String label;
  const GenOpt(this.value, this.label);
}

// ─────────────────────────────────────────────────────────
// SHARED OPTION LISTS
// ─────────────────────────────────────────────────────────
const genReadinessOpts = [
  GenOpt('A', 'A – 100%'),
  GenOpt('B', 'B – 75%'),
  GenOpt('C', 'C – 50%'),
  GenOpt('D', 'D – <25%'),
];

const genRoguingOpts = [
  GenOpt('A', 'A – Not Yet'),
  GenOpt('B', 'B – On Going'),
  GenOpt('C', 'C – Done'),
];

const genRoguingStatusOpts = [
  GenOpt('A', 'Not Yet'),
  GenOpt('B', 'On Going'),
  GenOpt('C', 'Done'),
];

const genLsvOpts = [
  GenOpt('A', 'A – None'),
  GenOpt('B', 'B – Low'),
  GenOpt('C', 'C – Moderate'),
  GenOpt('D', 'D – High'),
];

const genCropUniformityOpts = [
  GenOpt('1', '1 – Very Poor'),
  GenOpt('2', '2 – Poor'),
  GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'),
  GenOpt('5', '5 – Best'),
];

const genCropHealthOpts = [
  GenOpt('0', '0 – 0% serangan'),
  GenOpt('1', '1 – 1%'),
  GenOpt('2', '2 – 2%'),
  GenOpt('3', '3 – 3%'),
  GenOpt('4', '4 – 4%'),
  GenOpt('5', '5 – 5%'),
];

const genFemaleShedOpts = [
  GenOpt('A', 'A – 0'),
  GenOpt('B', 'B – >0 <2'),
  GenOpt('C', 'C – ≥2 <5'),
  GenOpt('D', 'D – ≥5'),
];

const genNSTOpts = [
  GenOpt('Y', 'Found'),
  GenOpt('N', 'Not Found'),
];

const genOfftypeOpts = [
  GenOpt('A', 'A – 0'),
  GenOpt('B', 'B – >0'),
];

const genDetasselingOpts = [
  GenOpt('A', 'A – Best'),
  GenOpt('B', 'B – Good'),
  GenOpt('C', 'C – Fair'),
  GenOpt('D', 'D – Poor'),
  GenOpt('E', 'E – Very Poor'),
];

const genIsolationOpts = [
  GenOpt('A', 'A – Yes'),
  GenOpt('B', 'B – No'),
];

const genAffectedOpts = [
  GenOpt('A', 'A – Yes'),
  GenOpt('B', 'B – No'),
];

const genActionNeededOpts = [
  GenOpt('A', 'A – None'),
  GenOpt('B', 'B – Roguing'),
  GenOpt('C', 'C – Re-Detasseling'),
  GenOpt('D', 'D – Monitor'),
  GenOpt('E', 'E – Hold'),
  GenOpt('F', 'F – Discard Partial'),
  GenOpt('G', 'G – Discard Full'),
];

const genFinalDecisionOpts = [
  GenOpt('A', 'A – Pass'),
  GenOpt('B', 'B – Pass w/ Note'),
  GenOpt('C', 'C – Hold'),
  GenOpt('D', 'D – Discard'),
];

const genFlaggingOpts = [
  GenOpt('GF',  'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF',  'BF'),
  GenOpt('PLD', 'PLD'),
];

// ─────────────────────────────────────────────────────────
// WEEK HELPER
// ─────────────────────────────────────────────────────────
String calcAuditWeek(DateTime date) {
  final start = DateTime(date.year, 1, 1);
  final week  = (date.difference(start).inDays / 7).ceil();
  return 'W${week.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────
// DATE PICKER THEME HELPER
// ─────────────────────────────────────────────────────────
ThemeData genDatePickerTheme(BuildContext context, Color accentColor) {
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
      primary:   accentColor,
      surface:   Colors.white,
      onSurface: AdvantaColors.deepForest,
    ),
  );
}

// ─────────────────────────────────────────────────────────
// APP BAR  (replaces buildGenAppBar function — now context-aware)
// ─────────────────────────────────────────────────────────
class GenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String checkpointLabel;
  final String fieldNumber;
  final bool isDiscard;
  final Color accentColor;
  final VoidCallback onBack;

  const GenAppBar({
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
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final discardBg   = isDark ? const Color(0xFF7B1821) : AdvantaColors.error;
    final normalBg    = isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen;
    final bgColor     = isDiscard ? discardBg : normalBg;
    final fgColor     = isDark && !isDiscard ? AdvantaColors.goldLight : Colors.white;
    final labelColor  = isDiscard
        ? const Color(0xFFFF8A80)
        : (isDark ? AdvantaColors.goldLight.withAlpha(200) : Colors.white.withAlpha(210));
    final borderColor = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(25);

    return AppBar(
      backgroundColor:  bgColor,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      leading: IconButton(
        icon:    Icon(Icons.arrow_back_ios_new_rounded, color: fgColor, size: 18),
        onPressed: onBack,
        tooltip: 'Kembali ke Field Detail',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            checkpointLabel,
            style: AdvantaText.caption.copyWith(
              color:       labelColor,
              fontWeight:  FontWeight.w600,
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
            margin:  const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        AdvantaColors.error.withAlpha(isDark ? 60 : 30),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(
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
                    color:       Color(0xFFFF8A80),
                    fontSize:    10,
                    fontWeight:  FontWeight.bold,
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
class GenFieldCard extends StatelessWidget {
  final Map<String, dynamic> fieldData;
  final Color accentColor;

  const GenFieldCard({
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
        color:        accentColor.withAlpha(isDark ? 25 : 15),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: accentColor.withAlpha(isDark ? 80 : 55)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.grass_outlined, color: accentColor, size: 13),
              const SizedBox(width: 7),
              Text(
                'DATA LAHAN (READ ONLY)',
                style: AdvantaText.caption.copyWith(
                  color:       accentColor,
                  fontWeight:  FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Cell('Petani',  _f(fieldData['farmer_name']))),
            Expanded(child: _Cell('Hybrid',  _f(fieldData['hybrid']))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _Cell('Grower',  _f(fieldData['grower']))),
            Expanded(child: _Cell('Efektif', '${_f(fieldData['effective_area_ha'])} Ha')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _Cell('Season',  _f(fieldData['season']))),
            Expanded(child: _Cell('Region',  _f(fieldData['region']))),
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
                  color: context.genSub, fontWeight: FontWeight.w500)),
          Text(value,
              style: AdvantaText.body2.copyWith(
                  color: context.genText, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────
class GenSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const GenSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final surface     = context.genSurface;
    final borderColor = context.genBorder;
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:        surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: borderColor),
        boxShadow:    AdvantaShadows.card(isDark),
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
                    color:       color,
                    fontWeight:  FontWeight.w700,
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

// ─────────────────────────────────────────────────────────
// DATE PICKER TILE — required date
// ─────────────────────────────────────────────────────────
class GenDateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool required;
  final bool allowFuture;
  final VoidCallback onTap;

  const GenDateTile({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.required    = true,
    this.allowFuture = false,
  });

  @override
  Widget build(BuildContext context) {
    final weekLabel   = calcAuditWeek(date);
    final bgColor     = context.genFill;
    final borderColor = context.genBorder;
    final subColor    = context.genSub;
    final textColor   = context.genText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: borderColor),
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
                style: AdvantaText.caption.copyWith(
                    color: subColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Icon(Icons.edit_calendar_outlined, color: subColor, size: 15),
          ],
        ),
      ),
    );
  }
}

// DATE PICKER TILE — optional / nullable
class GenDateTileNullable extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const GenDateTileNullable({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor     = context.genFill;
    final borderColor = context.genBorder;
    final subColor    = context.genSub;
    final textColor   = context.genText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: borderColor),
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
                      color:      date != null ? textColor : subColor,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
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
class GenTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final IconData? icon;
  final Color? accentColor;

  const GenTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.required     = false,
    this.maxLines     = 1,
    this.keyboardType,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent      = accentColor ?? Theme.of(context).colorScheme.primary;
    final bgColor     = context.genFill;
    final borderColor = context.genBorder;
    final subColor    = context.genSub;
    final textColor   = context.genText;

    return TextFormField(
      controller:   controller,
      maxLines:     maxLines,
      keyboardType: keyboardType,
      style:        AdvantaText.body1.copyWith(color: textColor),
      decoration: InputDecoration(
        labelText:  required ? '$label *' : label,
        labelStyle: AdvantaText.caption.copyWith(color: subColor),
        hintText:   hint,
        hintStyle:  AdvantaText.caption.copyWith(
            color: subColor.withAlpha(120)),
        prefixIcon: icon != null
            ? Icon(icon, color: subColor, size: 16)
            : null,
        filled:         true,
        fillColor:      bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: AdvantaColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: AdvantaColors.error, width: 1.5),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────
// OPTION PICKER — chip row (2–5 options)
// ─────────────────────────────────────────────────────────
class GenOptionPicker extends StatelessWidget {
  final String label;
  final bool required;
  final List<GenOpt> options;
  final String? value;
  final void Function(String?) onChanged;
  final Color? accentColor;

  const GenOptionPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required    = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent      = accentColor ?? Theme.of(context).colorScheme.primary;
    final bgColor     = context.genFill;
    final borderColor = context.genBorder;
    final subColor    = context.genSub;
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return FormField<String>(
      initialValue: value,
      validator:    required
          ? (v) => (v == null || v.isEmpty) ? 'Wajib dipilih' : null
          : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '$label *' : label,
              style: AdvantaText.caption.copyWith(
                  color: subColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing:    8,
              runSpacing: 8,
              children:   options.map((opt) {
                final isSel = value == opt.value;
                return GestureDetector(
                  onTap: () {
                    final next = isSel ? null : opt.value;
                    onChanged(next);
                    state.didChange(next);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? accent.withAlpha(isDark ? 55 : 28)
                          : bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? accent : borderColor,
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      opt.label,
                      style: AdvantaText.caption.copyWith(
                        color:      isSel ? accent : subColor,
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
                  style: AdvantaText.caption.copyWith(
                      color: AdvantaColors.error)),
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
class GenOptionPickerLong extends StatelessWidget {
  final String label;
  final bool required;
  final List<GenOpt> options;
  final String? value;
  final void Function(String?) onChanged;
  final Color? accentColor;

  const GenOptionPickerLong({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required    = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent      = accentColor ?? Theme.of(context).colorScheme.primary;
    final bgColor     = context.genFill;
    final borderColor = context.genBorder;
    final subColor    = context.genSub;
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return FormField<String>(
      initialValue: value,
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Wajib dipilih' : null
          : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '$label *' : label,
              style: AdvantaText.caption.copyWith(
                  color: subColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...options.map((opt) {
              final isSel = value == opt.value;
              return GestureDetector(
                onTap: () {
                  final next = isSel ? null : opt.value;
                  onChanged(next);
                  state.didChange(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel
                        ? accent.withAlpha(isDark ? 55 : 25)
                        : bgColor,
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
                            ? const Icon(Icons.check, color: Colors.white, size: 11)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        opt.label,
                        style: AdvantaText.body2.copyWith(
                          color: isSel ? accent : subColor,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
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
class GenDiscardBanner extends StatelessWidget {
  final String message;
  const GenDiscardBanner({
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
        color:        AdvantaColors.error.withAlpha(isDark ? 40 : 18),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(
            color: AdvantaColors.error.withAlpha(isDark ? 100 : 60)),
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
                color:  isDark ? const Color(0xFFFF8A80) : AdvantaColors.error,
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
class GenSaveBar extends StatelessWidget {
  final bool isSaving;
  final bool isDiscard;
  final String saveLabel;
  final VoidCallback onSave;

  const GenSaveBar({
    super.key,
    required this.isSaving,
    required this.isDiscard,
    required this.saveLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final surface     = context.genSurface;
    final borderColor = context.genBorder;
    final subColor    = context.genSub;
    final btnColor    = isDiscard ? AdvantaColors.error : AdvantaColors.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color:  surface,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset:     const Offset(0, -4),
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
                  width:  20,
                  height: 20,
                  child:  CircularProgressIndicator(
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
          width:  double.infinity,
          height: 50,
          child:  ElevatedButton.icon(
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
              elevation:       0,
              textStyle:       AdvantaText.button,
              shape: const RoundedRectangleBorder(
                  borderRadius: AdvantaRadius.buttonRadius),
            ),
          ),
        ),
      ),
    );
  }
}
