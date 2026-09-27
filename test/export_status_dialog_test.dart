import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/export_file_service.dart';
import 'package:kroscek/widgets/export_status_dialog.dart';

void main() {
  testWidgets(
    'export completion stays visible above a modal sheet and reports open errors',
    (tester) async {
      var openCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => Center(
                      child: FilledButton(
                        onPressed: () => showExportCompletedDialog(
                          sheetContext,
                          title: 'ISO Form berhasil didownload',
                          displayPath: 'Download/Kroscek/iso_test.pdf',
                          onOpen: () async {
                            openCalls++;
                            return const ExportOpenOutcome.failure(
                              'Tidak ada aplikasi yang dapat membuka format file ini.',
                            );
                          },
                        ),
                        child: const Text('Selesaikan download'),
                      ),
                    ),
                  ),
                  child: const Text('Buka detail'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selesaikan download'));
      await tester.pumpAndSettle();

      expect(find.text('ISO Form berhasil didownload'), findsOneWidget);
      expect(find.text('Download/Kroscek/iso_test.pdf'), findsOneWidget);
      expect(find.text('Buka sekarang'), findsOneWidget);

      await tester.tap(find.text('Buka sekarang'));
      await tester.pumpAndSettle();

      expect(openCalls, 1);
      expect(
        find.text('Tidak ada aplikasi yang dapat membuka format file ini.'),
        findsOneWidget,
      );
      expect(find.text('Tutup'), findsOneWidget);
    },
  );
}
