import 'package:shorebird_code_push/shorebird_code_push.dart';

enum ShorebirdUpdateState {
  idle,
  unavailable,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  downloaded,
  error,
}

class ShorebirdUpdateResult {
  const ShorebirdUpdateResult({
    required this.state,
    required this.isAvailable,
    this.currentPatchNumber,
    this.nextPatchNumber,
    this.errorMessage,
  });

  factory ShorebirdUpdateResult.idle({
    required bool isAvailable,
    int? currentPatchNumber,
  }) {
    return ShorebirdUpdateResult(
      state: isAvailable
          ? ShorebirdUpdateState.idle
          : ShorebirdUpdateState.unavailable,
      isAvailable: isAvailable,
      currentPatchNumber: currentPatchNumber,
    );
  }

  factory ShorebirdUpdateResult.unavailable({int? currentPatchNumber}) {
    return ShorebirdUpdateResult(
      state: ShorebirdUpdateState.unavailable,
      isAvailable: false,
      currentPatchNumber: currentPatchNumber,
    );
  }

  final ShorebirdUpdateState state;
  final bool isAvailable;
  final int? currentPatchNumber;
  final int? nextPatchNumber;
  final String? errorMessage;

  bool get hasUpdate => state == ShorebirdUpdateState.updateAvailable;

  bool get isBusy =>
      state == ShorebirdUpdateState.checking ||
      state == ShorebirdUpdateState.downloading;

  String get statusMessage {
    switch (state) {
      case ShorebirdUpdateState.idle:
        return 'Aplikasi siap dicek';
      case ShorebirdUpdateState.unavailable:
        return 'Update tidak tersedia di mode debug';
      case ShorebirdUpdateState.checking:
        return 'Mengecek update...';
      case ShorebirdUpdateState.upToDate:
        return 'Aplikasi sudah terbaru';
      case ShorebirdUpdateState.updateAvailable:
        return 'Patch baru tersedia';
      case ShorebirdUpdateState.downloading:
        return 'Update sedang diunduh...';
      case ShorebirdUpdateState.downloaded:
        return 'Update berhasil diunduh, restart aplikasi untuk menerapkan';
      case ShorebirdUpdateState.error:
        return errorMessage ?? 'Gagal mengecek update';
    }
  }

  ShorebirdUpdateResult copyWith({
    ShorebirdUpdateState? state,
    bool? isAvailable,
    int? currentPatchNumber,
    int? nextPatchNumber,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShorebirdUpdateResult(
      state: state ?? this.state,
      isAvailable: isAvailable ?? this.isAvailable,
      currentPatchNumber: currentPatchNumber ?? this.currentPatchNumber,
      nextPatchNumber: nextPatchNumber ?? this.nextPatchNumber,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ShorebirdUpdateService {
  ShorebirdUpdateService({ShorebirdUpdater? updater})
      : _updater = updater ?? ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  bool get isShorebirdAvailable {
    try {
      return _updater.isAvailable;
    } catch (_) {
      return false;
    }
  }

  Future<ShorebirdUpdateResult> readInstalledPatch() async {
    if (!isShorebirdAvailable) {
      return ShorebirdUpdateResult.unavailable();
    }

    final patchNumber = await currentPatchNumber();
    return ShorebirdUpdateResult.idle(
      isAvailable: true,
      currentPatchNumber: patchNumber,
    );
  }

  Future<int?> currentPatchNumber() async {
    if (!isShorebirdAvailable) return null;

    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  Future<int?> nextPatchNumber() async {
    if (!isShorebirdAvailable) return null;

    try {
      final patch = await _updater.readNextPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  Future<ShorebirdUpdateResult> checkForUpdate() async {
    if (!isShorebirdAvailable) {
      return ShorebirdUpdateResult.unavailable();
    }

    final patchNumber = await currentPatchNumber();

    try {
      final updateStatus = await _updater.checkForUpdate();
      return _resultFromUpdateStatus(
        updateStatus,
        currentPatchNumber: patchNumber,
      );
    } catch (_) {
      return ShorebirdUpdateResult(
        state: ShorebirdUpdateState.error,
        isAvailable: true,
        currentPatchNumber: patchNumber,
        errorMessage: 'Gagal mengecek update',
      );
    }
  }

  Future<ShorebirdUpdateResult> downloadUpdate() async {
    if (!isShorebirdAvailable) {
      return ShorebirdUpdateResult.unavailable();
    }

    final patchNumber = await currentPatchNumber();

    try {
      await _updater.update();
      final downloadedPatchNumber = await nextPatchNumber();

      return ShorebirdUpdateResult(
        state: ShorebirdUpdateState.downloaded,
        isAvailable: true,
        currentPatchNumber: patchNumber,
        nextPatchNumber: downloadedPatchNumber,
      );
    } catch (_) {
      return ShorebirdUpdateResult(
        state: ShorebirdUpdateState.error,
        isAvailable: true,
        currentPatchNumber: patchNumber,
        errorMessage: 'Gagal mengunduh update',
      );
    }
  }

  ShorebirdUpdateResult _resultFromUpdateStatus(
    UpdateStatus status, {
    int? currentPatchNumber,
  }) {
    switch (status) {
      case UpdateStatus.upToDate:
        return ShorebirdUpdateResult(
          state: ShorebirdUpdateState.upToDate,
          isAvailable: true,
          currentPatchNumber: currentPatchNumber,
        );
      case UpdateStatus.outdated:
        return ShorebirdUpdateResult(
          state: ShorebirdUpdateState.updateAvailable,
          isAvailable: true,
          currentPatchNumber: currentPatchNumber,
        );
      case UpdateStatus.restartRequired:
        return ShorebirdUpdateResult(
          state: ShorebirdUpdateState.downloaded,
          isAvailable: true,
          currentPatchNumber: currentPatchNumber,
        );
      case UpdateStatus.unavailable:
        return ShorebirdUpdateResult.unavailable(
          currentPatchNumber: currentPatchNumber,
        );
    }
  }
}
