import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/full_update_service.dart';

void main() {
  group('FullUpdateDownloadSnapshot', () {
    test('memetakan status dan progress dari Android DownloadManager', () {
      final snapshot = FullUpdateDownloadSnapshot.fromMap(
        const <Object?, Object?>{
          'status': 'running',
          'reason': 0,
          'downloadedBytes': 25,
          'totalBytes': 100,
        },
      );

      expect(snapshot.status, FullUpdateDownloadStatus.running);
      expect(snapshot.progress, 0.25);
    });

    test('progress tidak ditentukan saat ukuran total belum tersedia', () {
      final snapshot = FullUpdateDownloadSnapshot.fromMap(
        const <Object?, Object?>{
          'status': 'pending',
          'downloadedBytes': 0,
          'totalBytes': -1,
        },
      );

      expect(snapshot.status, FullUpdateDownloadStatus.pending);
      expect(snapshot.progress, isNull);
    });

    test('status asing diperlakukan sebagai task yang hilang', () {
      final snapshot = FullUpdateDownloadSnapshot.fromMap(
        const <Object?, Object?>{'status': 'unexpected'},
      );

      expect(snapshot.status, FullUpdateDownloadStatus.missing);
    });

    test('progress dibatasi pada rentang nol sampai satu', () {
      final snapshot = FullUpdateDownloadSnapshot.fromMap(
        const <Object?, Object?>{
          'status': 'running',
          'downloadedBytes': 150,
          'totalBytes': 100,
        },
      );

      expect(snapshot.progress, 1);
    });
  });
}
