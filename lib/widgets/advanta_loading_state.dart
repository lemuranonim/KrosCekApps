import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdvantaLoadingState extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color? accentColor;
  final IconData icon;
  final bool compact;
  final bool showSignals;
  final EdgeInsetsGeometry padding;

  const AdvantaLoadingState({
    super.key,
    this.title = 'Memuat data',
    this.subtitle = 'Menyiapkan informasi terbaru',
    this.accentColor,
    this.icon = Icons.radar_rounded,
    this.compact = false,
    this.showSignals = true,
    this.padding = const EdgeInsets.all(24),
  });

  const AdvantaLoadingState.compact({
    super.key,
    this.title = 'Memuat data',
    this.subtitle = 'Sinkronisasi berjalan',
    this.accentColor,
    this.icon = Icons.sync_rounded,
    this.compact = true,
    this.showSignals = false,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  State<AdvantaLoadingState> createState() => _AdvantaLoadingStateState();
}

class _AdvantaLoadingStateState extends State<AdvantaLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? theme.colorScheme.primary;
    final textColor = isDark ? Colors.white : AdvantaColors.deepForest;
    final subtitleColor = isDark
        ? Colors.white.withAlpha(150)
        : AdvantaColors.midGreen.withAlpha(190);
    final surfaceColor = isDark
        ? Colors.white.withAlpha(18)
        : Colors.white.withAlpha(210);
    final borderColor = isDark
        ? accent.withAlpha(72)
        : accent.withAlpha(44);
    final panelWidth = widget.compact ? 260.0 : 340.0;

    return Center(
      child: Padding(
        padding: widget.padding,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = Curves.easeInOut.transform(
              math.sin(_controller.value * math.pi).abs(),
            );

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: panelWidth,
                minWidth: widget.compact ? 220 : 248,
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  widget.compact ? 14 : 16,
                  widget.compact ? 12 : 14,
                  widget.compact ? 14 : 16,
                  widget.compact ? 12 : 13,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: AdvantaColors.deepForest.withAlpha(isDark ? 70 : 18),
                      blurRadius: widget.compact ? 16 : 24,
                      offset: Offset(0, widget.compact ? 8 : 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: widget.compact ? 30 : 34,
                          height: widget.compact ? 30 : 34,
                          decoration: BoxDecoration(
                            color: accent.withAlpha(isDark ? 36 : 24),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent.withAlpha(70)),
                          ),
                          child: Icon(
                            widget.icon,
                            color: accent,
                            size: widget.compact ? 16 : 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: widget.compact ? 12 : 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: widget.compact ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 0.88 + (pulse * 0.12),
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withAlpha(120),
                                  blurRadius: 12 + (pulse * 8),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.compact ? 10 : 14),
                    SizedBox(
                      height: widget.compact ? 28 : 42,
                      child: CustomPaint(
                        painter: _AdvantaLoadingRailPainter(
                          progress: _controller.value,
                          pulse: pulse,
                          accentColor: accent,
                          isDark: isDark,
                          compact: widget.compact,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    if (widget.showSignals) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _SignalPill(label: 'Data', accentColor: accent, textColor: textColor, isDark: isDark, progress: _controller.value, index: 0)),
                          const SizedBox(width: 8),
                          Expanded(child: _SignalPill(label: 'Map', accentColor: accent, textColor: textColor, isDark: isDark, progress: _controller.value, index: 1)),
                          const SizedBox(width: 8),
                          Expanded(child: _SignalPill(label: 'Audit', accentColor: accent, textColor: textColor, isDark: isDark, progress: _controller.value, index: 2)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  final String label;
  final Color accentColor;
  final Color textColor;
  final bool isDark;
  final double progress;
  final int index;

  const _SignalPill({
    required this.label,
    required this.accentColor,
    required this.textColor,
    required this.isDark,
    required this.progress,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final wave = (progress + (index * 0.22)) % 1.0;
    final glow = Curves.easeInOut.transform(wave < 0.5 ? wave * 2 : (1 - wave) * 2);

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : AdvantaColors.primaryGreen.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withAlpha(24 + (glow * 42).round())),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(120 + (glow * 120).round()),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withAlpha(isDark ? 180 : 170),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvantaLoadingRailPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final Color accentColor;
  final bool isDark;
  final bool compact;

  const _AdvantaLoadingRailPainter({
    required this.progress,
    required this.pulse,
    required this.accentColor,
    required this.isDark,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final railTop = size.height * (compact ? 0.50 : 0.54);
    final railHeight = compact ? 6.0 : 8.0;
    final railRect = Rect.fromLTWH(0, railTop, size.width, railHeight);
    final railRadius = Radius.circular(railHeight);
    final railRRect = RRect.fromRectAndRadius(railRect, railRadius);

    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(18) : AdvantaColors.deepForest.withAlpha(18);
    canvas.drawRRect(railRRect, trackPaint);

    if (!compact) {
      final fieldPath = Path();
      for (double x = 0; x <= size.width; x += 4) {
        final wave = math.sin((x / size.width * math.pi * 2) + progress * math.pi * 2);
        final y = 11 + wave * 3;
        if (x == 0) {
          fieldPath.moveTo(x, y);
        } else {
          fieldPath.lineTo(x, y);
        }
      }

      final fieldPaint = Paint()
        ..color = accentColor.withAlpha(isDark ? 68 : 48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(fieldPath, fieldPaint);
    }

    final tickPaint = Paint()
      ..color = accentColor.withAlpha(isDark ? 48 : 36)
      ..strokeWidth = 1;
    for (int i = 0; i <= 12; i++) {
      final x = size.width * (i / 12);
      final tickHeight = i % 3 == 0 ? (compact ? 8.0 : 14.0) : (compact ? 5.0 : 9.0);
      canvas.drawLine(Offset(x, railTop - tickHeight), Offset(x, railTop - 3), tickPaint);
    }

    final segmentWidth = size.width * 0.34;
    final leading = (size.width + segmentWidth) * progress - segmentWidth;
    final movingRect = Rect.fromLTWH(leading, railTop, segmentWidth, railHeight).intersect(railRect);

    if (!movingRect.isEmpty) {
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            accentColor.withAlpha(0),
            accentColor.withAlpha(isDark ? 155 : 130),
            AdvantaColors.goldLight.withAlpha(isDark ? 230 : 190),
            accentColor.withAlpha(0),
          ],
        ).createShader(movingRect.inflate(12));
      canvas.drawRRect(RRect.fromRectAndRadius(movingRect, railRadius), activePaint);
    }

    final headX = leading + segmentWidth * 0.66;
    if (headX >= 0 && headX <= size.width) {
      final glowPaint = Paint()
        ..color = AdvantaColors.goldLight.withAlpha((70 + pulse * 70).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, compact ? 6 : 8);
      canvas.drawCircle(Offset(headX, railTop + railHeight / 2), (compact ? 6 : 8) + pulse * 3, glowPaint);

      final headPaint = Paint()..color = AdvantaColors.goldLight;
      canvas.drawCircle(Offset(headX, railTop + railHeight / 2), compact ? 2.6 : 3.2, headPaint);
    }

    final baselinePaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(38) : Colors.white.withAlpha(130)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, railTop + railHeight + (compact ? 5 : 7)),
      Offset(size.width, railTop + railHeight + (compact ? 5 : 7)),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AdvantaLoadingRailPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}
