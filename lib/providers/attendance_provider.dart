// lib/providers/attendance_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'master_fields_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceState {
  final String? attendanceId;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final String? checkInPhotoUrl;
  final String? notes;
  final String status; // 'open' | 'closed'
  final int totalActivities;
  final List<AttendanceActivity> activities;
  final bool isLoading;
  final String? errorMessage;

  const AttendanceState({
    this.attendanceId,
    this.isCheckedIn = false,
    this.isCheckedOut = false,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.checkInPhotoUrl,
    this.notes,
    this.status = 'open',
    this.totalActivities = 0,
    this.activities = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Durasi kerja aktif dalam menit
  int? get workDurationMinutes {
    if (checkInTime == null) return null;
    final end = checkOutTime ?? DateTime.now();
    return end.difference(checkInTime!).inMinutes;
  }

  /// Format durasi sebagai string "Xj Ym"
  String get workDurationFormatted {
    final minutes = workDurationMinutes;
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}j ${m}m';
  }

  AttendanceState copyWith({
    String? attendanceId,
    bool? isCheckedIn,
    bool? isCheckedOut,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? checkInLat,
    double? checkInLng,
    double? checkOutLat,
    double? checkOutLng,
    String? checkInPhotoUrl,
    String? notes,
    String? status,
    int? totalActivities,
    List<AttendanceActivity>? activities,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AttendanceState(
      attendanceId: attendanceId ?? this.attendanceId,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      isCheckedOut: isCheckedOut ?? this.isCheckedOut,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLat: checkInLat ?? this.checkInLat,
      checkInLng: checkInLng ?? this.checkInLng,
      checkOutLat: checkOutLat ?? this.checkOutLat,
      checkOutLng: checkOutLng ?? this.checkOutLng,
      checkInPhotoUrl: checkInPhotoUrl ?? this.checkInPhotoUrl,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      totalActivities: totalActivities ?? this.totalActivities,
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceActivity {
  final String activityId;
  final String? fieldNumber;
  final String? phase;
  final String? actionType;
  final DateTime actionTime;
  final double? lat;
  final double? lng;

  const AttendanceActivity({
    required this.activityId,
    this.fieldNumber,
    this.phase,
    this.actionType,
    required this.actionTime,
    this.lat,
    this.lng,
  });

  factory AttendanceActivity.fromMap(Map<String, dynamic> map) {
    return AttendanceActivity(
      activityId: map['activity_id'] as String,
      fieldNumber: map['field_number'] as String?,
      phase: map['phase'] as String?,
      actionType: map['action_type'] as String?,
      actionTime: DateTime.parse(map['action_time'] as String),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() => const AttendanceState();

  /// Load semua data attendance hari ini termasuk activities
  Future<void> loadTodayAttendance(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final service = ref.read(supabaseServiceProvider);

      // Load header
      final header = await service.getTodayAttendance(userId);
      if (header == null) {
        state = const AttendanceState();
        return;
      }

      final attendanceId = header['attendance_id'] as String?;
      final isClosed = header['status'] == 'closed';

      // Load activities jika sudah check-in
      List<AttendanceActivity> activities = [];
      if (attendanceId != null) {
        final activityData = await service.getTodayActivities(attendanceId);
        activities = activityData
            .map((e) => AttendanceActivity.fromMap(e))
            .toList();
      }

      state = AttendanceState(
        attendanceId: attendanceId,
        isCheckedIn: header['check_in_time'] != null,
        isCheckedOut: isClosed,
        checkInTime: header['check_in_time'] != null
            ? DateTime.parse(header['check_in_time'] as String)
            : null,
        checkOutTime: header['check_out_time'] != null
            ? DateTime.parse(header['check_out_time'] as String)
            : null,
        checkInLat: (header['check_in_lat'] as num?)?.toDouble(),
        checkInLng: (header['check_in_lng'] as num?)?.toDouble(),
        checkOutLat: (header['check_out_lat'] as num?)?.toDouble(),
        checkOutLng: (header['check_out_lng'] as num?)?.toDouble(),
        checkInPhotoUrl: header['check_in_photo'] as String?,
        notes: header['notes'] as String?,
        status: header['status'] as String? ?? 'open',
        totalActivities: activities.length,
        activities: activities,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat data absensi: $e',
      );
    }
  }

  /// Check-in dengan foto opsional
  Future<void> performCheckIn({
    required String userId,
    required double lat,
    required double lng,
    String? photoUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final service = ref.read(supabaseServiceProvider);
      final id = await service.checkIn(
        userId: userId,
        lat: lat,
        lng: lng,
        photoUrl: photoUrl,
      );
      state = state.copyWith(
        attendanceId: id,
        isCheckedIn: true,
        checkInTime: DateTime.now(),
        checkInLat: lat,
        checkInLng: lng,
        checkInPhotoUrl: photoUrl,
        status: 'open',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '$e');
      rethrow;
    }
  }

  /// Check-out dengan catatan dan lokasi
  Future<void> performCheckOut({
    required String userId,
    required double lat,
    required double lng,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.checkOut(
        userId: userId,
        lat: lat,
        lng: lng,
        notes: notes,
      );
      state = state.copyWith(
        isCheckedOut: true,
        checkOutTime: DateTime.now(),
        checkOutLat: lat,
        checkOutLng: lng,
        notes: notes,
        status: 'closed',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '$e');
      rethrow;
    }
  }

  /// Log aktivitas lapangan ke attendance_activity
  Future<void> logFieldActivity({
    required String userId,
    required String fieldNumber,
    required String phase,
    required String actionType,
    required double lat,
    required double lng,
    String? referenceInspectionId,
  }) async {
    if (state.attendanceId == null) return;
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.logActivity(
        attendanceId: state.attendanceId!,
        userId: userId,
        fieldNumber: fieldNumber,
        phase: phase,
        actionType: actionType,
        lat: lat,
        lng: lng,
        referenceInspectionId: referenceInspectionId,
      );
      // Refresh activity count
      state = state.copyWith(
        totalActivities: state.totalActivities + 1,
      );
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  /// Refresh hanya activity list (tanpa reload full)
  Future<void> refreshActivities() async {
    if (state.attendanceId == null) return;
    try {
      final service = ref.read(supabaseServiceProvider);
      final activityData = await service.getTodayActivities(state.attendanceId!);
      final activities = activityData
          .map((e) => AttendanceActivity.fromMap(e))
          .toList();
      state = state.copyWith(
        activities: activities,
        totalActivities: activities.length,
      );
    } catch (e) {
      debugPrint('Error refreshing activities: $e');
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final attendanceProvider =
NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);

/// Provider untuk computed work duration (real-time)
final workDurationProvider = Provider<String>((ref) {
  final attendance = ref.watch(attendanceProvider);
  return attendance.workDurationFormatted;
});