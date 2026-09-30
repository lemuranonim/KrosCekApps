import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/shorebird_update_service.dart';
import 'package:kroscek/widgets/mandatory_patch_update_gate.dart';

class _FakePatchService extends ShorebirdUpdateService {
  _FakePatchService({
    required this.checkResult,
    this.downloadResult = const ShorebirdUpdateResult(
      state: ShorebirdUpdateState.downloaded,
      isAvailable: true,
      currentPatchNumber: 4,
      nextPatchNumber: 5,
    ),
  });

  ShorebirdUpdateResult checkResult;
  ShorebirdUpdateResult downloadResult;
  int downloadCalls = 0;

  @override
  Future<ShorebirdUpdateResult> checkForUpdate() async => checkResult;

  @override
  Future<ShorebirdUpdateResult> downloadUpdate() async {
    downloadCalls++;
    return downloadResult;
  }
}

Widget _app({
  required ShorebirdUpdateService service,
  Future<void> Function()? restart,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: MandatoryPatchUpdateGate(
      service: service,
      restartApplication: restart,
      child: const Scaffold(body: Text('Konten utama')),
    ),
  );
}

void main() {
  testWidgets('does not block the app when no patch is available', (
    tester,
  ) async {
    final service = _FakePatchService(
      checkResult: const ShorebirdUpdateResult(
        state: ShorebirdUpdateState.upToDate,
        isAvailable: true,
        currentPatchNumber: 5,
      ),
    );

    await tester.pumpWidget(_app(service: service));
    await tester.pumpAndSettle();

    expect(find.text('Konten utama'), findsOneWidget);
    expect(find.text('UPDATE WAJIB'), findsNothing);
  });

  testWidgets('forces download and restart before app use', (tester) async {
    var restartCalls = 0;
    final service = _FakePatchService(
      checkResult: const ShorebirdUpdateResult(
        state: ShorebirdUpdateState.updateAvailable,
        isAvailable: true,
        currentPatchNumber: 4,
        nextPatchNumber: 5,
      ),
    );

    await tester.pumpWidget(
      _app(
        service: service,
        restart: () async {
          restartCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UPDATE WAJIB'), findsOneWidget);
    expect(find.text('Pembaruan KC tersedia'), findsOneWidget);
    expect(find.text('Perbarui sekarang'), findsOneWidget);

    await tester.tap(find.text('Perbarui sekarang'));
    await tester.pumpAndSettle();

    expect(service.downloadCalls, 1);
    expect(find.text('Pembaruan siap dipakai'), findsOneWidget);
    expect(find.text('Restart sekarang'), findsOneWidget);

    await tester.tap(find.text('Restart sekarang'));
    await tester.pump();
    expect(restartCalls, 1);
  });

  testWidgets('download failure stays blocking and offers retry', (
    tester,
  ) async {
    final service = _FakePatchService(
      checkResult: const ShorebirdUpdateResult(
        state: ShorebirdUpdateState.updateAvailable,
        isAvailable: true,
        currentPatchNumber: 4,
      ),
      downloadResult: const ShorebirdUpdateResult(
        state: ShorebirdUpdateState.error,
        isAvailable: true,
        currentPatchNumber: 4,
        errorMessage: 'Koneksi internet terputus',
      ),
    );

    await tester.pumpWidget(_app(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perbarui sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Pembaruan belum selesai'), findsOneWidget);
    expect(find.text('Koneksi internet terputus'), findsOneWidget);
    expect(find.text('Coba unduh lagi'), findsOneWidget);
    expect(find.text('UPDATE WAJIB'), findsOneWidget);
  });
}
