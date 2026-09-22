import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/shorebird_update_service.dart';
import 'package:kroscek/widgets/shorebird_settings_indicator.dart';
import 'package:kroscek/widgets/shorebird_update_card.dart';

class _PendingPatchService extends ShorebirdUpdateService {
  static const result = ShorebirdUpdateResult(
    state: ShorebirdUpdateState.downloaded,
    isAvailable: true,
    currentPatchNumber: 2,
    nextPatchNumber: 3,
  );

  @override
  Future<ShorebirdUpdateResult> readInstalledPatch() async => result;

  @override
  Future<ShorebirdUpdateResult> checkForUpdate() async => result;
}

void main() {
  testWidgets('pending patch is visible on Settings and its entry button',
      (tester) async {
    final service = _PendingPatchService();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ShorebirdSettingsIndicator(
              service: service,
              onTap: () async {},
              child: const Icon(Icons.settings_outlined),
            ),
            ShorebirdUpdateCard(service: service),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tutup aplikasi sepenuhnya'), findsOneWidget);
    expect(find.text('Patch terunduh:'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.label ==
              'Pengaturan, patch siap diterapkan setelah restart'),
      findsOneWidget,
    );
  });
}
