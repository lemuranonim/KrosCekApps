import 'package:flutter/material.dart';

import '../services/export_file_service.dart';
import '../theme/app_theme.dart';

Future<void> showExportCompletedDialog(
  BuildContext context, {
  required String title,
  required String displayPath,
  required Future<ExportOpenOutcome> Function() onOpen,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => _ExportCompletedDialog(
      title: title,
      displayPath: displayPath,
      onOpen: onOpen,
    ),
  );
}

Future<void> showExportMessageDialog(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
        color: isError ? AdvantaColors.error : AdvantaColors.deepForest,
        size: 34,
      ),
      title: Text(isError ? 'Download belum berhasil' : 'Informasi'),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

class _ExportCompletedDialog extends StatefulWidget {
  final String title;
  final String displayPath;
  final Future<ExportOpenOutcome> Function() onOpen;

  const _ExportCompletedDialog({
    required this.title,
    required this.displayPath,
    required this.onOpen,
  });

  @override
  State<_ExportCompletedDialog> createState() => _ExportCompletedDialogState();
}

class _ExportCompletedDialogState extends State<_ExportCompletedDialog> {
  bool _opening = false;
  String? _error;

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    final outcome = await widget.onOpen();
    if (!mounted) return;
    setState(() {
      _opening = false;
      _error = outcome.success ? null : outcome.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AdvantaColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: AdvantaColors.success,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AdvantaText.heading2.copyWith(
                color: AdvantaColors.deepForest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'File sudah tersimpan dan siap dibuka.',
              textAlign: TextAlign.center,
              style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdvantaColors.softGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 20,
                    color: AdvantaColors.deepForest,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.displayPath,
                      style: AdvantaText.caption.copyWith(
                        color: AdvantaColors.deepForest,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdvantaColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AdvantaColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AdvantaText.caption.copyWith(
                          color: AdvantaColors.error,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      actions: [
        TextButton(
          onPressed: _opening ? null : () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: _opening ? null : _open,
          icon: _opening
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(_opening ? 'Membuka...' : 'Buka sekarang'),
        ),
      ],
    );
  }
}
