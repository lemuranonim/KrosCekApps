import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class GotFetService {
  GotFetService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const evidenceBucket = 'got_fet_evidence';

  Future<void> submitGotObservation({
    required String lotId,
    required String sampleId,
    required String hybrid,
    required String plotId,
    required String stage,
    required int totalObserved,
    required int offTypeCount,
    required int selfingCount,
    required int maleCount,
    required int suspiciousCount,
    required int trueTypeCount,
    required double purityPercent,
    required String submittedBy,
    required List<File> evidencePhotos,
    String? remarks,
  }) async {
    final submittedAt = DateTime.now().toUtc().toIso8601String();
    final photoUrls = await uploadEvidencePhotos(
      files: evidencePhotos,
      lotId: lotId,
      module: 'got',
    );

    await _supabase.from('got_fet_got_observation').insert({
      'lot_id': lotId,
      'sample_id': sampleId,
      'hybrid': hybrid,
      'plot_id': plotId,
      'observation_stage': stage,
      'total_observed': totalObserved,
      'off_type_count': offTypeCount,
      'selfing_count': selfingCount,
      'male_count': maleCount,
      'suspicious_count': suspiciousCount,
      'true_type_count': trueTypeCount,
      'purity_percent': purityPercent,
      'remarks': remarks,
      'submitted_by': submittedBy,
      'submitted_datetime': submittedAt,
      'review_status': 'Submitted',
      'created_by_user_id': _supabase.auth.currentUser?.id,
    });

    await _insertPhotoEvidence(
      lotId: lotId,
      sampleId: sampleId,
      testType: 'GOT',
      module: 'got',
      plotId: plotId,
      uploadedBy: submittedBy,
      uploadedAt: submittedAt,
      photoUrls: photoUrls,
    );

    await appendTrackingEvent(
      lotId: lotId,
      status: 'Submitted',
      actor: submittedBy,
      remarks: 'GOT observation submitted',
      eventAt: submittedAt,
    );
  }

  Future<void> submitFetObservation({
    required String lotId,
    required String sampleId,
    required String hybrid,
    required String plotId,
    required int replication,
    required int dap,
    required int totalPoints,
    required int grownCount,
    required int notGrownCount,
    required int reviewCount,
    required int notReadableCount,
    required double emergencePercent,
    required List<String> pointStatuses,
    required String submittedBy,
    File? plotPhoto,
    String? remarks,
  }) async {
    final submittedAt = DateTime.now().toUtc().toIso8601String();
    final photoUrls = plotPhoto == null
        ? <String>[]
        : await uploadEvidencePhotos(
            files: [plotPhoto],
            lotId: lotId,
            module: 'fet',
            replication: 'u$replication',
          );

    await _supabase.from('got_fet_fet_observation').insert({
      'lot_id': lotId,
      'sample_id': sampleId,
      'hybrid': hybrid,
      'plot_id': plotId,
      'replication': replication,
      'dap': dap,
      'total_points': totalPoints,
      'grown_count': grownCount,
      'not_grown_count': notGrownCount,
      'review_count': reviewCount,
      'not_readable_count': notReadableCount,
      'emergence_percent': emergencePercent,
      'point_statuses': [
        for (var i = 0; i < pointStatuses.length; i++)
          {'point_no': i + 1, 'status': pointStatuses[i]},
      ],
      'plot_photo_url': photoUrls.isEmpty ? null : photoUrls.first,
      'remarks': remarks,
      'submitted_by': submittedBy,
      'submitted_datetime': submittedAt,
      'review_status': 'Submitted',
      'created_by_user_id': _supabase.auth.currentUser?.id,
    });

    await _insertPhotoEvidence(
      lotId: lotId,
      sampleId: sampleId,
      testType: 'FET',
      module: 'fet',
      plotId: plotId,
      replication: replication.toString(),
      uploadedBy: submittedBy,
      uploadedAt: submittedAt,
      photoUrls: photoUrls,
    );

    await appendTrackingEvent(
      lotId: lotId,
      status: 'Submitted',
      actor: submittedBy,
      remarks: 'FET replication $replication submitted',
      eventAt: submittedAt,
    );
  }

  Future<void> submitReviewDecision({
    required String lotId,
    required String sampleId,
    required String module,
    required String previousStatus,
    required String newStatus,
    required String reviewer,
    String? remarks,
  }) async {
    final reviewedAt = DateTime.now().toUtc().toIso8601String();

    await _supabase.from('got_fet_review_history').insert({
      'lot_id': lotId,
      'sample_id': sampleId,
      'module': module,
      'previous_status': previousStatus,
      'new_status': newStatus,
      'review_action': newStatus,
      'reviewer': reviewer,
      'review_datetime': reviewedAt,
      'remarks': remarks,
      'created_by_user_id': _supabase.auth.currentUser?.id,
    });

    if (newStatus == 'Approved' || newStatus == 'Rejected') {
      await _supabase.from('got_fet_final_decision').insert({
        'lot_id': lotId,
        'sample_id': sampleId,
        'module': module,
        'decision': newStatus,
        'decided_by': reviewer,
        'decision_datetime': reviewedAt,
        'remarks': remarks,
        'created_by_user_id': _supabase.auth.currentUser?.id,
      });
    }

    await appendTrackingEvent(
      lotId: lotId,
      status: newStatus,
      actor: reviewer,
      remarks: remarks,
      eventAt: reviewedAt,
    );
  }

  Future<List<String>> uploadEvidencePhotos({
    required Iterable<File> files,
    required String lotId,
    required String module,
    String? replication,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final uploadedPath = await _uploadEvidencePhoto(
        file: file,
        lotId: lotId,
        module: module,
        replication: replication,
      );
      urls.add(
          _supabase.storage.from(evidenceBucket).getPublicUrl(uploadedPath));
    }
    return urls;
  }

  Future<void> appendTrackingEvent({
    required String lotId,
    required String status,
    required String actor,
    String? remarks,
    String? eventAt,
  }) async {
    await _supabase.from('got_fet_sample_tracking').insert({
      'lot_id': lotId,
      'status': status,
      'actor': actor,
      'event_datetime': eventAt ?? DateTime.now().toUtc().toIso8601String(),
      'remarks': remarks,
      'created_by_user_id': _supabase.auth.currentUser?.id,
    });
  }

  Future<String> _uploadEvidencePhoto({
    required File file,
    required String lotId,
    required String module,
    String? replication,
  }) async {
    final safeLotId = _safeSegment(lotId);
    final safeModule = _safeSegment(module);
    final safeReplication = _safeSegment(replication ?? 'main');
    final extension = _fileExtension(file.path);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final objectPath = '$safeLotId/$safeModule/$safeReplication/$fileName';

    await _supabase.storage.from(evidenceBucket).upload(
          objectPath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return objectPath;
  }

  Future<void> _insertPhotoEvidence({
    required String lotId,
    required String sampleId,
    required String testType,
    required String module,
    required String plotId,
    required String uploadedBy,
    required String uploadedAt,
    required List<String> photoUrls,
    String? replication,
  }) async {
    if (photoUrls.isEmpty) return;

    await _supabase.from('got_fet_photo_evidence').insert([
      for (final url in photoUrls)
        {
          'lot_id': lotId,
          'sample_id': sampleId,
          'test_type': testType,
          'module': module,
          'plot_id': plotId,
          'replication': replication,
          'photo_url': url,
          'uploaded_by': uploadedBy,
          'uploaded_datetime': uploadedAt,
          'review_status': 'Submitted',
          'created_by_user_id': _supabase.auth.currentUser?.id,
        },
    ]);
  }

  String _safeSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  }

  String _fileExtension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return 'jpg';
    return name.substring(dotIndex + 1).toLowerCase();
  }
}
