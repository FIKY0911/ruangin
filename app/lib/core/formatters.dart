import 'package:intl/intl.dart';

/// Indonesian-style time, e.g. "10.00".
String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

String formatTimeRange(DateTime start, DateTime end) =>
    '${formatTime(start)}–${formatTime(end)}';

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String formatDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String formatDateTime(DateTime d) => '${formatShortDate(d)} · ${formatTime(d)}';

/// Stable key for persistence, e.g. "2026-11-22".
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
