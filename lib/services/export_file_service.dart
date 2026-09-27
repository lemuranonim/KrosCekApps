import 'dart:io' as io;
import 'dart:typed_data';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredExportFile {
  final String displayPath;
  final String openPath;
  final String mimeType;

  const StoredExportFile({
    required this.displayPath,
    required this.openPath,
    required this.mimeType,
  });
}

class ExportOpenOutcome {
  final bool success;
  final String message;

  const ExportOpenOutcome._({required this.success, required this.message});

  const ExportOpenOutcome.success()
    : this._(success: true, message: 'File berhasil dibuka.');

  const ExportOpenOutcome.failure(String message)
    : this._(success: false, message: message);
}

/// Shared storage/opening flow for every generated ISO file.
///
/// Android receives two copies intentionally:
/// - a user-visible copy in Download/Kroscek through MediaStore;
/// - a durable app-private copy used by FileProvider when the user taps Open.
///
/// Opening the private copy avoids relying on a MediaStore URI/path that can
/// vary between Android vendors while the downloaded file remains accessible
/// from the user's Downloads app.
class ExportFileService {
  const ExportFileService._();

  static Future<StoredExportFile> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final stableFile = await _writeStableCopy(bytes, fileName);

    if (io.Platform.isAndroid) {
      try {
        MediaStore.appFolder = 'Kroscek';
        await MediaStore.ensureInitialized();
        final saved = await MediaStore().saveFile(
          tempFilePath: stableFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        if (saved == null) {
          throw const io.FileSystemException(
            'MediaStore tidak mengembalikan lokasi file.',
          );
        }
        return StoredExportFile(
          displayPath: 'Download/Kroscek/$fileName',
          openPath: stableFile.path,
          mimeType: mimeType,
        );
      } catch (_) {
        return StoredExportFile(
          displayPath: 'Penyimpanan aplikasi/Kroscek/$fileName',
          openPath: stableFile.path,
          mimeType: mimeType,
        );
      }
    }

    final outputDirectory = io.Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : (await getDownloadsDirectory()) ??
              await getApplicationDocumentsDirectory();
    final outputFile = io.File(p.join(outputDirectory.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    return StoredExportFile(
      displayPath: outputFile.path,
      openPath: outputFile.path,
      mimeType: mimeType,
    );
  }

  static Future<ExportOpenOutcome> open({
    required String path,
    required String mimeType,
  }) async {
    try {
      final file = io.File(path);
      if (!await file.exists()) {
        return const ExportOpenOutcome.failure(
          'File tidak ditemukan. Silakan download ulang.',
        );
      }

      final result = await OpenFile.open(path, type: mimeType);
      return switch (result.type) {
        ResultType.done => const ExportOpenOutcome.success(),
        ResultType.noAppToOpen => const ExportOpenOutcome.failure(
          'Tidak ada aplikasi yang dapat membuka format file ini.',
        ),
        ResultType.fileNotFound => const ExportOpenOutcome.failure(
          'File tidak ditemukan. Silakan download ulang.',
        ),
        ResultType.permissionDenied => const ExportOpenOutcome.failure(
          'Android menolak akses file. Coba buka dari folder Download/Kroscek.',
        ),
        ResultType.error => ExportOpenOutcome.failure(
          result.message.trim().isEmpty
              ? 'File belum dapat dibuka di perangkat ini.'
              : result.message,
        ),
      };
    } catch (_) {
      return const ExportOpenOutcome.failure(
        'File belum dapat dibuka. Coba buka dari folder Download/Kroscek.',
      );
    }
  }

  static Future<io.File> _writeStableCopy(
    Uint8List bytes,
    String fileName,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDirectory = io.Directory(p.join(directory.path, 'exports'));
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }
    final outputFile = io.File(p.join(outputDirectory.path, fileName));
    await outputFile.writeAsBytes(bytes, flush: true);
    await _prunePrivateCopies(outputDirectory, keepPath: outputFile.path);
    return outputFile;
  }

  static Future<void> _prunePrivateCopies(
    io.Directory directory, {
    required String keepPath,
  }) async {
    try {
      final files = await directory
          .list()
          .where((entity) => entity is io.File)
          .cast<io.File>()
          .toList();
      final dated = <({io.File file, DateTime modified})>[];
      for (final file in files) {
        dated.add((file: file, modified: await file.lastModified()));
      }
      dated.sort((a, b) => b.modified.compareTo(a.modified));
      for (final entry in dated.skip(20)) {
        if (entry.file.path != keepPath) await entry.file.delete();
      }
    } catch (_) {
      // Cleanup must never turn a successful download into an error.
    }
  }
}
