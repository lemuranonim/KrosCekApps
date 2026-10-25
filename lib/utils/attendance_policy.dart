/// Attendance follows the operational timezone (WIB / UTC+7), independently
/// of the device timezone. The database enforces the same checkout boundary.
class AttendancePolicy {
  AttendancePolicy._();

  static DateTime workTime(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 7));

  static String dateKey(DateTime instant) =>
      workTime(instant).toIso8601String().split('T').first;

  static DateTime day(DateTime instant) {
    final local = workTime(instant);
    return DateTime(local.year, local.month, local.day);
  }

  static bool remindCheckout({
    required bool checkedIn,
    required bool checkedOut,
    required DateTime now,
  }) => checkedIn && !checkedOut && workTime(now).hour >= 12;

  static bool canCheckOut({
    required bool checkedIn,
    required bool checkedOut,
    required DateTime now,
  }) => checkedIn && !checkedOut && workTime(now).hour >= 15;

  static void validateCoordinates(double lat, double lng) {
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      throw ArgumentError('Koordinat GPS tidak valid. Muat ulang lokasi.');
    }
  }
}
