import 'package:flutter/services.dart';

/// Status unduhan APK penuh yang dilaporkan oleh Android DownloadManager.
enum FullUpdateDownloadStatus {
  pending,
  running,
  paused,
  successful,
  failed,
  missing,
}

class FullUpdateDownloadSnapshot {
  const FullUpdateDownloadSnapshot({
    required this.status,
    required this.reason,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  factory FullUpdateDownloadSnapshot.fromMap(Map<Object?, Object?> map) {
    final rawStatus = map['status'] as String? ?? 'missing';
    return FullUpdateDownloadSnapshot(
      status: FullUpdateDownloadStatus.values.firstWhere(
        (status) => status.name == rawStatus,
        orElse: () => FullUpdateDownloadStatus.missing,
      ),
      reason: (map['reason'] as num?)?.toInt() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? -1,
    );
  }

  final FullUpdateDownloadStatus status;
  final int reason;
  final int downloadedBytes;
  final int totalBytes;

  double? get progress {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0).toDouble();
  }
}

/// Jembatan ke Android DownloadManager untuk update APK penuh.
///
/// DownloadManager dipakai agar unduhan tetap dimiliki sistem ketika aplikasi
/// masuk background, proses aplikasi dihentikan, atau jaringan berganti.
class FullUpdateService {
  const FullUpdateService();

  static const MethodChannel _channel = MethodChannel(
    'com.example.kroscek/full_update',
  );

  Future<int> enqueue({
    required String url,
    required String fileName,
    required String version,
  }) async {
    final id = await _channel.invokeMethod<num>('enqueue', <String, Object>{
      'url': url,
      'fileName': fileName,
      'version': version,
    });
    if (id == null) {
      throw PlatformException(
        code: 'ENQUEUE_FAILED',
        message: 'Android tidak mengembalikan ID unduhan.',
      );
    }
    return id.toInt();
  }

  Future<FullUpdateDownloadSnapshot> query(int downloadId) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'query',
      <String, Object>{'downloadId': downloadId},
    );
    return FullUpdateDownloadSnapshot.fromMap(
      result ?? const <Object?, Object?>{'status': 'missing'},
    );
  }

  Future<void> remove(int downloadId) async {
    await _channel.invokeMethod<void>('remove', <String, Object>{
      'downloadId': downloadId,
    });
  }

  Future<void> openInstaller(String fileName) async {
    await _channel.invokeMethod<void>('openInstaller', <String, Object>{
      'fileName': fileName,
    });
  }
}
