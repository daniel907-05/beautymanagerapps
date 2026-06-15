class DateHelper {
  static DateTime startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime endOfToday() {
    return startOfToday().add(const Duration(days: 1));
  }

  static String todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .split('T')
        .first;
  }

  static DateTime startOfWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static DateTime endOfWeek() {
    return startOfWeek().add(const Duration(days: 7));
  }

  static DateTime startOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static DateTime endOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  static String localIsoNow() {
    return DateTime.now().toIso8601String();
  }
}
