import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/session_manager.dart';
import '../theme/app_theme.dart';

class ModuleSelectScreen extends StatefulWidget {
  const ModuleSelectScreen({super.key});

  @override
  State<ModuleSelectScreen> createState() => _ModuleSelectScreenState();
}

class _ModuleSelectScreenState extends State<ModuleSelectScreen> {
  ActiveSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.getActiveSession();
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _openModule(String route) async {
    await SessionManager.instance.saveSelectedModuleRoute(route);
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;
    final muted = isDark
        ? AdvantaColors.goldLight.withAlpha(170)
        : AdvantaColors.mutedGrey;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AdvantaColors.midGreen
                          : AdvantaColors.paleGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.apps_rounded,
                      color: isDark
                          ? AdvantaColors.goldLight
                          : AdvantaColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KROSCEK',
                          style: AdvantaText.brandTitle
                              .copyWith(color: foreground),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _session?.name.trim().isNotEmpty == true
                              ? _session!.name
                              : 'Pilih modul kerja',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdvantaText.body2.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Pilih Modul',
                style: AdvantaText.display.copyWith(
                  color: foreground,
                  fontSize: 30,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'QA Inspection tetap untuk mapping audit. GOT & FET memakai workflow seed quality yang terpisah.',
                style: AdvantaText.body1.copyWith(color: muted),
              ),
              const SizedBox(height: 24),
              _ModuleCard(
                icon: Icons.map_rounded,
                title: 'QA Inspection',
                subtitle: 'Mapping audit lahan dan inspeksi fase',
                accentColor: AdvantaColors.primaryGreen,
                chips: const ['Map', 'Audit', 'Coverage'],
                onTap: () => _openModule('/qa'),
              ),
              const SizedBox(height: 14),
              _ModuleCard(
                icon: Icons.science_rounded,
                title: 'GOT & FET',
                subtitle: 'Sample tracking, purity, emergence, dan approval',
                accentColor: AdvantaColors.gold,
                chips: const ['GOT', 'FET', 'Review'],
                onTap: () => _openModule('/got-fet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<String> chips;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;
    final muted = isDark
        ? AdvantaColors.goldLight.withAlpha(160)
        : AdvantaColors.mutedGrey;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 45 : 28),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accentColor, size: 26),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accentColor),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: AdvantaText.heading1.copyWith(color: foreground),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AdvantaText.body2.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in chips)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(isDark ? 36 : 20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chip,
                        style: AdvantaText.caption.copyWith(
                          color: isDark
                              ? AdvantaColors.goldLight
                              : AdvantaColors.deepForest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
