import 'dart:async';

import 'package:flutter/material.dart';

import '../services/shorebird_update_service.dart';
import '../theme/app_theme.dart';

/// Shows a small badge once a downloaded patch is waiting for an app restart.
class ShorebirdSettingsIndicator extends StatefulWidget {
  const ShorebirdSettingsIndicator({
    super.key,
    required this.child,
    required this.onTap,
    this.service,
  });

  final Widget child;
  final Future<void> Function() onTap;
  final ShorebirdUpdateService? service;

  @override
  State<ShorebirdSettingsIndicator> createState() =>
      _ShorebirdSettingsIndicatorState();
}

class _ShorebirdSettingsIndicatorState extends State<ShorebirdSettingsIndicator>
    with WidgetsBindingObserver {
  late final ShorebirdUpdateService _service;
  Timer? _timer;
  bool _restartRequired = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ShorebirdUpdateService();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkPatch());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPatch());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPatch();
  }

  Future<void> _checkPatch() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      final result = await _service.readInstalledPatch();
      if (!mounted) return;
      final restartRequired = result.state == ShorebirdUpdateState.downloaded;
      if (_restartRequired != restartRequired) {
        setState(() => _restartRequired = restartRequired);
      }
    } catch (_) {
      // A status badge must never interrupt navigation when the updater fails.
    } finally {
      _checking = false;
    }
  }

  Future<void> _openSettings() async {
    await widget.onTap();
    await _checkPatch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _restartRequired
          ? 'Pengaturan, patch siap diterapkan setelah restart'
          : 'Pengaturan',
      child: GestureDetector(
        onTap: _openSettings,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_restartRequired)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AdvantaColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
