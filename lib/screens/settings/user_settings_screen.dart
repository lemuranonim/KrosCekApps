// lib/screens/settings/user_settings_screen.dart
//
// PERUBAHAN untuk role Guest:
//   • Semua aksi tulis (Rename, Force Sync, Mapping) diblokir via GuestGuard
//   • _RoleBadge diberi warna khusus Guest (ungu/abu)
//   • Subtitle "Role & Akses" mengenali Guest sebagai "Read-Only"
//   • Tampil GuestGuard.banner() di atas list jika Guest
// ─────────────────────────────────────────────────────────

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kroscek/widgets/advanta_loading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../providers/profile_rename_provider.dart';
import '../../providers/qa_mapping_provider.dart';
import '../../utils/guest_guard.dart'; // ← NEW
import '../../widgets/shorebird_update_card.dart';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  ActiveSession? _session;
  bool _isLoading = true;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadSession();
    _fetchVersion();
  }

  Future<void> _fetchVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = packageInfo.version);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _version = 'Dev');
      }
    }
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.getActiveSession();
    if (mounted) {
      setState(() {
        _session = session;
        _isLoading = false;
      });
    }
  }

  bool get _isGuest => GuestGuard.isGuest(_session);

  Future<void> _logout() async {
    final confirmed = await _showConfirmDialog(
      title: 'Keluar dari Akun?',
      message:
          'Semua data sesi akan dihapus dari perangkat ini. Anda perlu login ulang.',
      confirmLabel: 'KELUAR',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    _invalidateAllProviders();
    await SessionManager.instance
        .clearSessionOnLogout(userId: _session?.userId);
    if (mounted) context.go('/login');
  }

  void _invalidateAllProviders() {
    ref.invalidate(currentSessionProvider);
    ref.invalidate(qaMappingProvider);
    ref.invalidate(profileRenameProvider);
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
        title: Text(title,
            style: AdvantaText.heading2
                .copyWith(color: theme.colorScheme.onSurface)),
        content: Text(message,
            style: AdvantaText.body1
                .copyWith(color: theme.colorScheme.onSurface.withAlpha(180))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: AdvantaText.bodyBold
                    .copyWith(color: AdvantaColors.mutedGrey)),
          ),
          ElevatedButton(
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: AdvantaColors.error,
                    foregroundColor: Colors.white)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Role & Akses subtitle ─────────────────────────────────
  String _roleSubtitle() {
    final role = _session?.role.toLowerCase() ?? '';
    if (role == 'guest') return 'Read-Only (View Only)';
    if (role == 'admin' || role == 'qa') return 'Akses Penuh';
    return 'Akses Audit Only';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const AdvantaLoadingState(
              title: 'Memuat pengaturan',
              subtitle: 'Mengambil sesi dan preferensi',
              icon: Icons.manage_accounts_rounded,
            )
          : ListView(
              children: [
                // ── Guest banner ──────────────────────────────
                if (_isGuest) ...[
                  const SizedBox(height: 8),
                  GuestGuard.banner(),
                ],

                _ProfileCard(session: _session, isDark: isDark, theme: theme),
                const SizedBox(height: 8),

                _SectionHeader(label: 'Akun'),
                _SettingsTile(
                  icon: Icons.person_outline,
                  label: 'Informasi Profil',
                  subtitle: _session?.email ?? '-',
                  // Guest: buka sheet tapi tombol rename diblokir di dalam sheet
                  onTap: () => _showProfileSheet(),
                ),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  label: 'Role & Akses',
                  subtitle: _roleSubtitle(),
                  onTap: null,
                  trailing: _RoleBadge(role: _session?.role ?? ''),
                ),

                const SizedBox(height: 8),

                _SectionHeader(label: 'Master Data'),
                _SettingsTile(
                  icon: Icons.map_outlined,
                  label: 'Pengaturan Wilayah',
                  subtitle: 'Kelola pemetaan kabupaten, kecamatan, desa & FA',
                  // Guest: blokir navigasi ke mapping (write screen)
                  onTap: _isGuest
                      ? () => GuestGuard.blockIfGuest(context, _session)
                      : () => context.push('/qa/settings/mapping'),
                ),
                _SettingsTile(
                  icon: Icons.grass_outlined,
                  label: 'Data Lahan',
                  subtitle: 'Lihat dan filter master field data',
                  onTap: () => _showFeatureUnderDevelopment('Data Lahan'),
                ),
                _SettingsTile(
                  icon: Icons.people_outline,
                  label: 'Data Petani & FA',
                  subtitle: 'Kelola daftar petani dan field assistant',
                  onTap: () => _showFeatureUnderDevelopment('Data Petani & FA'),
                ),
                _SettingsTile(
                  icon: Icons.science_outlined,
                  label: 'Hybrid & Varietas',
                  subtitle: 'Master data varietas tanaman',
                  onTap: () =>
                      _showFeatureUnderDevelopment('Hybrid & Varietas'),
                ),

                const SizedBox(height: 8),

                _SectionHeader(label: 'Sinkronisasi'),
                _SettingsTile(
                  icon: Icons.sync_outlined,
                  label: 'Paksa Sinkronisasi Ulang',
                  subtitle:
                      'Hapus cache lokal dan ambil data terbaru dari server',
                  // Guest: hanya baca, tidak perlu sync write
                  onTap: _isGuest
                      ? () => GuestGuard.blockIfGuest(context, _session)
                      : () => _forceSyncAll(),
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  label: 'Status Cache',
                  subtitle: 'Lihat info data tersimpan di perangkat',
                  onTap: () => _showCacheInfo(), // read-only, boleh untuk Guest
                ),

                const SizedBox(height: 8),

                _SectionHeader(label: 'Aplikasi'),
                const ShorebirdUpdateCard(),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang Kroscek',
                  subtitle: 'Versi, lisensi, dan informasi aplikasi',
                  onTap: () => _showAboutDialog(),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded,
                        color: AdvantaColors.error),
                    label: const Text('Keluar dari Akun',
                        style: TextStyle(color: AdvantaColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AdvantaColors.error, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _logout,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Future<void> _forceSyncAll() async {
    final confirmed = await _showConfirmDialog(
      title: 'Paksa Sinkronisasi?',
      message:
          'Semua cache lokal akan dihapus dan data akan diambil ulang dari server. Pastikan koneksi internet aktif.',
      confirmLabel: 'SINKRONISASI',
    );
    if (!confirmed || !mounted) return;

    _invalidateAllProviders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sinkronisasi dimulai. Data sedang diperbarui.'),
          backgroundColor: AdvantaColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showFeatureUnderDevelopment(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.construction_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fitur $featureName sedang dalam pengembangan (Coming Soon).',
                style: AdvantaText.body2.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AdvantaColors.mutedGrey,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showCacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _session?.userId ?? '';
    final userKeys =
        prefs.getKeys().where((k) => k.startsWith('u_${uid}_')).toList();
    final totalKeys = prefs.getKeys().length;

    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? AdvantaColors.goldLight.withAlpha(50)
                      : AdvantaColors.mutedGrey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Status Cache',
                style: AdvantaText.heading2
                    .copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            _CacheInfoRow(
                label: 'User aktif',
                value: uid.isEmpty ? 'Tidak ada' : '${uid.substring(0, 8)}...'),
            _CacheInfoRow(
                label: 'Key milik user ini', value: '${userKeys.length} item'),
            _CacheInfoRow(
                label: 'Total key di perangkat', value: '$totalKeys item'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('TUTUP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => _ProfileSheetContent(
        session: _session,
        isGuest: _isGuest, // ← NEW: kirim flag Guest ke sheet
        onRenameSuccess: () async {
          final newSession = await SessionManager.instance.getActiveSession();
          if (mounted) setState(() => _session = newSession);
          ref.invalidate(currentSessionProvider);
          ref.invalidate(qaMappingProvider);
          ref.invalidate(profileRenameProvider);
        },
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Kroscek',
      applicationVersion: 'v$_version',
      applicationLegalese:
          '© 2024-${DateTime.now().year} Advanta Seeds Indonesia. All rights reserved.',
    );
  }
}

// ── _ProfileSheetContent ──────────────────────────────────
class _ProfileSheetContent extends ConsumerStatefulWidget {
  final ActiveSession? session;
  final bool isGuest; // ← NEW
  final VoidCallback onRenameSuccess;

  const _ProfileSheetContent({
    required this.session,
    required this.isGuest,
    required this.onRenameSuccess,
  });

  @override
  ConsumerState<_ProfileSheetContent> createState() =>
      _ProfileSheetContentState();
}

class _ProfileSheetContentState extends ConsumerState<_ProfileSheetContent> {
  bool _showRenameForm = false;
  final _newNameCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final renameAsync = ref.watch(profileRenameProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? AdvantaColors.goldLight.withAlpha(50)
                    : AdvantaColors.mutedGrey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Informasi Profil',
            style: AdvantaText.heading2
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 16),

          _CacheInfoRow(label: 'Nama', value: widget.session?.name ?? '-'),
          _CacheInfoRow(label: 'Email', value: widget.session?.email ?? '-'),
          _CacheInfoRow(
              label: 'Role',
              value: (widget.session?.role ?? '-').toUpperCase()),
          _CacheInfoRow(
            label: 'Akses',
            value: widget.isGuest
                ? 'Read-Only (View Only)'
                : (widget.session?.role.toLowerCase() == 'admin' ||
                        widget.session?.role.toLowerCase() == 'qa')
                    ? 'Penuh (All)'
                    : 'Terbatas (Audit Only)',
          ),
          _CacheInfoRow(
            label: 'ID',
            value: (widget.session?.userId ?? '-').length > 8
                ? '${widget.session!.userId.substring(0, 8)}...'
                : (widget.session?.userId ?? '-'),
          ),

          const SizedBox(height: 20),

          // Guest: sembunyikan seluruh section rename
          if (!widget.isGuest)
            renameAsync.when(
              loading: () => const AdvantaLoadingState.compact(
                title: 'Memuat profil',
                subtitle: 'Mengecek data nama',
                icon: Icons.person_search_rounded,
              ),
              error: (e, _) => _InfoBanner(
                icon: Icons.error_outline,
                color: AdvantaColors.error,
                message: 'Gagal memuat info nama: $e',
              ),
              data: (renameState) => _buildRenameSection(
                context,
                theme,
                isDark,
                renameState,
              ),
            )
          else
            _InfoBanner(
              icon: Icons.lock_outline_rounded,
              color: AdvantaColors.error,
              message: 'Akun Guest tidak dapat mengubah nama profil.',
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRenameSection(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    ProfileRenameState renameState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!renameState.isSynced) ...[
          _InfoBanner(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            message:
                'Nama profil "${renameState.profileName}" tidak cocok dengan nama di pemetaan wilayah '
                '"${renameState.mappingName}". Silakan lakukan rename agar data wilayah dapat tampil dengan benar.',
          ),
          const SizedBox(height: 12),
        ],
        Divider(color: isDark ? Colors.white12 : Colors.black12),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.drive_file_rename_outline,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Ganti Nama Profil',
              style: AdvantaText.bodyBold
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!renameState.canRename) ...[
          _InfoBanner(
            icon: Icons.lock_clock_outlined,
            color: AdvantaColors.mutedGrey,
            message:
                'Nama sudah pernah diganti. Bisa ganti lagi dalam ${renameState.cooldownDaysLeft} hari.',
          ),
        ] else if (renameState.lastRenameAt != null) ...[
          Text(
            'Terakhir diubah: ${_formatDate(renameState.lastRenameAt!)}',
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
          const SizedBox(height: 8),
        ],
        if (renameState.canRename) ...[
          if (!_showRenameForm)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ubah Nama'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() {
                  _showRenameForm = true;
                  _newNameCtrl.text = renameState.profileName;
                }),
              ),
            )
          else
            _buildRenameForm(context, theme, isDark, renameState),
        ],
      ],
    );
  }

  Widget _buildRenameForm(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    ProfileRenameState renameState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AdvantaColors.goldLight.withAlpha(15)
                : AdvantaColors.mutedGrey.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: AdvantaColors.mutedGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nama saat ini: ${renameState.profileName}',
                  style: AdvantaText.caption
                      .copyWith(color: AdvantaColors.mutedGrey),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newNameCtrl,
          autofocus: true,
          style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
          decoration: const InputDecoration(
            labelText: 'Nama Baru',
            hintText: 'Masukkan nama baru...',
          ),
        ),
        const SizedBox(height: 8),
        _InfoBanner(
          icon: Icons.info_outline,
          color: theme.colorScheme.primary,
          message:
              'Perubahan ini akan memperbarui nama di profil dan semua data pemetaan wilayah. '
              'Rename hanya bisa dilakukan 1x per 14 hari.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _showRenameForm = false),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _doRename(),
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('SIMPAN'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _doRename() async {
    final newName = _newNameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tidak boleh kosong.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
        title: const Text('Konfirmasi Ganti Nama'),
        content: const Text(
          'Nama akan diubah dan tidak bisa diganti lagi selama 14 hari ke depan.\n\n'
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YA, GANTI'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileRenameProvider.notifier).renameTo(newName);
      if (mounted) {
        setState(() {
          _showRenameForm = false;
          _isSaving = false;
        });
        widget.onRenameSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Nama berhasil diubah dan data wilayah telah diperbarui.'),
            backgroundColor: AdvantaColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah nama: $e'),
            backgroundColor: AdvantaColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

// ── Sub-widgets (unchanged) ───────────────────────────────

class _ProfileCard extends StatelessWidget {
  final ActiveSession? session;
  final bool isDark;
  final ThemeData theme;

  const _ProfileCard(
      {required this.session, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(session?.name ?? session?.email ?? '?');
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AdvantaColors.deepForest, const Color(0xFF112E20)]
              : [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withAlpha(30),
            child: Text(
              initials,
              style: AdvantaText.heading2
                  .copyWith(color: Colors.white, fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session?.name ?? 'Pengguna',
                  style: AdvantaText.heading3.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  session?.email ?? '-',
                  style: AdvantaText.caption
                      .copyWith(color: Colors.white.withAlpha(180)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _RoleBadge(role: session?.role ?? '', onDark: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: AdvantaText.caption.copyWith(
          color: AdvantaColors.mutedGrey,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(20)
              : AdvantaColors.charcoal.withAlpha(10),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(label,
            style: AdvantaText.bodyBold
                .copyWith(color: theme.colorScheme.onSurface)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: AdvantaText.caption
                    .copyWith(color: AdvantaColors.mutedGrey))
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right,
                    color: AdvantaColors.mutedGrey.withAlpha(150))
                : null),
        onTap: onTap,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final bool onDark;
  const _RoleBadge({required this.role, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'DEV':
        bg = AdvantaColors.gold.withAlpha(onDark ? 60 : 30);
        fg = onDark ? AdvantaColors.goldLight : AdvantaColors.gold;
        break;
      case 'MANAGER':
      case 'SPV':
        bg = AdvantaColors.primaryGreen.withAlpha(onDark ? 60 : 30);
        fg = onDark ? AdvantaColors.lightGreen : AdvantaColors.primaryGreen;
        break;
      case 'FI':
        bg = Colors.blue.withAlpha(onDark ? 60 : 30);
        fg = onDark ? Colors.lightBlue : Colors.blue.shade700;
        break;
      // ── NEW: Guest badge ─────────────────────────────────
      case 'GUEST':
        bg = Colors.purple.withAlpha(onDark ? 60 : 30);
        fg = onDark ? Colors.purpleAccent : Colors.purple.shade600;
        break;
      default:
        bg = AdvantaColors.mutedGrey.withAlpha(40);
        fg = AdvantaColors.mutedGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        role.toUpperCase().isEmpty ? 'USER' : role.toUpperCase(),
        style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1),
      ),
    );
  }
}

class _CacheInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _CacheInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label:',
              style:
                  AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AdvantaText.bodyBold
                  .copyWith(color: theme.colorScheme.onSurface),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AdvantaText.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
