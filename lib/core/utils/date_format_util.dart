import 'package:intl/intl.dart';

class DateFormatUtil {
  DateFormatUtil._();

  static final DateFormat _dateDisplay = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeDisplay = DateFormat('dd MMM yyyy HH:mm');
  static final DateFormat _timeDisplay = DateFormat('HH:mm');

  static String formatDate(DateTime? dt) =>
      dt == null ? '—' : _dateDisplay.format(dt.toLocal());

  static String formatDateTime(DateTime? dt) =>
      dt == null ? '—' : _dateTimeDisplay.format(dt.toLocal());

  static String formatTime(DateTime? dt) =>
      dt == null ? '—' : _timeDisplay.format(dt.toLocal());

  /// Returns a human-readable countdown like "14m 30s" until [target].
  static String countdownTo(DateTime target) {
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative) return 'now';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}
