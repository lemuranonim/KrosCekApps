import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/shorebird_update_service.dart';
import '../theme/app_theme.dart';

class ShorebirdUpdateCard extends StatefulWidget {
  const ShorebirdUpdateCard({
    super.key,
    this.service,
    this.autoCheck = true,
  });

  final ShorebirdUpdateService? service;
  final bool autoCheck;

  @override
  State<ShorebirdUpdateCard> createState() => _ShorebirdUpdateCardState();
}

class _ShorebirdUpdateCardState extends State<ShorebirdUpdateCard> {
  late final ShorebirdUpdateService _service;
  ShorebirdUpdateResult _result = const ShorebirdUpdateResult(
    state: ShorebirdUpdateState.checking,
    isAvailable: false,
  );
  String _appVersion = 'Memuat...';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ShorebirdUpdateService();
    _loadAppVersion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoCheck) {
        _checkForUpdate();
      } else {
        _loadInstalledPatch();
      }
    });
  }

  void _loadAppVersion() {
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _appVersion = 'Dev');
    });
  }

  Future<void> _loadInstalledPatch() async {
    final result = await _service.readInstalledPatch();
    if (!mounted) return;
    setState(() => _result = result);
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    setState(() {
      _result = _result.copyWith(
        state: ShorebirdUpdateState.checking,
        clearError: true,
      );
    });

    final result = await _service.checkForUpdate();
    if (!mounted) return;
    setState(() => _result = result);
  }

  Future<void> _downloadUpdate() async {
    if (!mounted) return;
    setState(() {
      _result = _result.copyWith(
        state: ShorebirdUpdateState.downloading,
        clearError: true,
      );
    });

    final result = await _service.downloadUpdate();
    if (!mounted) return;
    setState(() => _result = result);

    if (result.state == ShorebirdUpdateState.downloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Update berhasil diunduh. Tutup dan buka kembali aplikasi untuk menerapkan patch.',
          ),
          backgroundColor: AdvantaColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AdvantaRadius.cardRadius,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor(theme);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(20)
              : AdvantaColors.charcoal.withAlpha(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.system_update_alt_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Aplikasi',
                      style: AdvantaText.bodyBold.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _result.statusMessage,
                      style: AdvantaText.caption.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: _statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Versi aplikasi', value: 'v$_appVersion'),
          _InfoRow(label: 'Versi patch', value: _patchLabel),
          if (_result.nextPatchNumber != null)
            _InfoRow(
              label: 'Patch terunduh',
              value: '#${_result.nextPatchNumber}',
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _result.isBusy ? null : _checkForUpdate,
                icon: _result.state == ShorebirdUpdateState.checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Cek Update'),
              ),
              if (_result.hasUpdate)
                ElevatedButton.icon(
                  onPressed: _result.isBusy ? null : _downloadUpdate,
                  icon: _result.state == ShorebirdUpdateState.downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Download Update'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _patchLabel {
    final currentPatchNumber = _result.currentPatchNumber;
    if (currentPatchNumber == null) return 'Belum ada patch';
    return '#$currentPatchNumber';
  }

  String get _statusLabel {
    switch (_result.state) {
      case ShorebirdUpdateState.idle:
      case ShorebirdUpdateState.checking:
        return 'Cek';
      case ShorebirdUpdateState.unavailable:
        return 'Debug';
      case ShorebirdUpdateState.upToDate:
        return 'Terbaru';
      case ShorebirdUpdateState.updateAvailable:
        return 'Baru';
      case ShorebirdUpdateState.downloading:
        return 'Unduh';
      case ShorebirdUpdateState.downloaded:
        return 'Restart';
      case ShorebirdUpdateState.error:
        return 'Gagal';
    }
  }

  Color _statusColor(ThemeData theme) {
    switch (_result.state) {
      case ShorebirdUpdateState.idle:
      case ShorebirdUpdateState.checking:
        return theme.colorScheme.primary;
      case ShorebirdUpdateState.unavailable:
        return AdvantaColors.mutedGrey;
      case ShorebirdUpdateState.upToDate:
      case ShorebirdUpdateState.downloaded:
        return AdvantaColors.primaryGreen;
      case ShorebirdUpdateState.updateAvailable:
      case ShorebirdUpdateState.downloading:
        return AdvantaColors.gold;
      case ShorebirdUpdateState.error:
        return AdvantaColors.error;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AdvantaText.bodyBold.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(72)),
      ),
      child: Text(
        label,
        style: AdvantaText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
