import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

const _gotFetNavy = Color(0xFF061A44);
const _gotFetGreen = Color(0xFF009B54);
const _gotFetSurface = Color(0xFFF6F8FB);

class GotFetSettingsScreen extends StatefulWidget {
  const GotFetSettingsScreen({super.key});

  @override
  State<GotFetSettingsScreen> createState() => _GotFetSettingsScreenState();
}

class _GotFetSettingsScreenState extends State<GotFetSettingsScreen> {
  ActiveSession? _session;
  bool _isLoading = true;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadSession();
    _fetchVersion();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.getActiveSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  Future<void> _fetchVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = packageInfo.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = 'Dev');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
          title: Text(
            'Keluar dari GOT & FET?',
            style: AdvantaText.heading2
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            'Sesi pengguna di perangkat ini akan dihapus. Setelah login ulang, user akan memilih modul lagi.',
            style: AdvantaText.body1
                .copyWith(color: theme.colorScheme.onSurface.withAlpha(180)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: AdvantaText.bodyBold
                    .copyWith(color: AdvantaColors.mutedGrey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdvantaColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('KELUAR'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await SessionManager.instance
        .clearSessionOnLogout(userId: _session?.userId);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;
    final mutedColor = isDark
        ? AdvantaColors.goldLight.withAlpha(165)
        : AdvantaColors.mutedGrey;

    return Scaffold(
      backgroundColor: isDark ? AdvantaColors.deepForest : _gotFetSurface,
      appBar: AppBar(
        backgroundColor: _gotFetNavy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('GOT & FET Settings'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: _gotFetGreen.withAlpha(
                                isDark ? 45 : 24,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.science_rounded,
                              color: _gotFetGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _session?.name.trim().isNotEmpty == true
                                      ? _session!.name
                                      : 'GOT & FET User',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AdvantaText.heading2
                                      .copyWith(color: textColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _session?.email ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AdvantaText.body2
                                      .copyWith(color: mutedColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Role',
                    value: _session?.role ?? '-',
                  ),
                  _SettingsTile(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Action',
                    value: _session?.action ?? '-',
                  ),
                  _SettingsTile(
                    icon: Icons.science_rounded,
                    title: 'Modul Aktif',
                    value: 'GOT & FET',
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Versi Aplikasi',
                    value: _version,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdvantaColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('KELUAR'),
                      onPressed: _logout,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen,
        ),
        title: Text(
          title,
          style: AdvantaText.bodyBold.copyWith(
            color: isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
          ),
        ),
        subtitle: Text(
          value,
          style: AdvantaText.body2.copyWith(
            color: isDark
                ? AdvantaColors.goldLight.withAlpha(155)
                : AdvantaColors.mutedGrey,
          ),
        ),
      ),
    );
  }
}
