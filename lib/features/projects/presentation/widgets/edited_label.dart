const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a human-readable relative edit timestamp in local time:
/// - `< 1 min` → `Edited just now`
/// - `< 60 min` → `Edited 5 min ago`
/// - `< 24 h` → `Edited 2 h ago`
/// - previous calendar day → `Edited yesterday`
/// - within the last 7 days → `Edited Mon`
/// - same year → `Edited 12 Nov`
/// - otherwise → `Edited 12 Nov 2025`
String editedLabel(DateTime updated, DateTime now) {
  final u = updated.toLocal();
  final n = now.toLocal();
  final diff = n.difference(u);

  if (diff < const Duration(minutes: 1)) {
    return 'Edited just now';
  }
  if (diff < const Duration(minutes: 60)) {
    return 'Edited ${diff.inMinutes} min ago';
  }
  if (diff < const Duration(hours: 24)) {
    return 'Edited ${diff.inHours} h ago';
  }

  final uDate = DateTime.utc(u.year, u.month, u.day);
  final nDate = DateTime.utc(n.year, n.month, n.day);
  final dayDiff = nDate.difference(uDate).inDays;

  if (dayDiff == 1) {
    return 'Edited yesterday';
  }
  if (dayDiff > 1 && dayDiff < 7) {
    return 'Edited ${_weekdays[u.weekday - 1]}';
  }
  final month = _months[u.month - 1];
  if (u.year == n.year) {
    return 'Edited ${u.day} $month';
  }
  return 'Edited ${u.day} $month ${u.year}';
}
