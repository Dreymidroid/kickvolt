import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/projects/projects.dart';

void main() {
  // Sunday 22 Nov 2026 15:00 local time.
  final now = DateTime(2026, 11, 22, 15, 0, 0);

  test('< 1 min returns Edited just now', () {
    expect(
      editedLabel(now.subtract(const Duration(seconds: 45)), now),
      'Edited just now',
    );
    expect(editedLabel(now, now), 'Edited just now');
  });

  test('< 60 min returns Edited N min ago', () {
    expect(
      editedLabel(now.subtract(const Duration(minutes: 1)), now),
      'Edited 1 min ago',
    );
    expect(
      editedLabel(now.subtract(const Duration(minutes: 5)), now),
      'Edited 5 min ago',
    );
    expect(
      editedLabel(now.subtract(const Duration(minutes: 59, seconds: 59)), now),
      'Edited 59 min ago',
    );
  });

  test('< 24 h returns Edited N h ago', () {
    expect(
      editedLabel(now.subtract(const Duration(hours: 1)), now),
      'Edited 1 h ago',
    );
    expect(
      editedLabel(now.subtract(const Duration(hours: 2)), now),
      'Edited 2 h ago',
    );
    expect(
      editedLabel(now.subtract(const Duration(hours: 23, minutes: 59)), now),
      'Edited 23 h ago',
    );
  });

  test('previous calendar day (>= 24 h) returns Edited yesterday', () {
    // Saturday 21 Nov 2026 10:00 (29 hours ago, previous calendar day).
    expect(
      editedLabel(DateTime(2026, 11, 21, 10, 0, 0), now),
      'Edited yesterday',
    );
  });

  test('within the last 7 days returns Edited <Weekday>', () {
    // Monday 16 Nov 2026 (6 days ago) -> Edited Mon.
    expect(editedLabel(DateTime(2026, 11, 16, 12, 0, 0), now), 'Edited Mon');
    // Thursday 19 Nov 2026 (3 days ago) -> Edited Thu.
    expect(editedLabel(DateTime(2026, 11, 19, 12, 0, 0), now), 'Edited Thu');
  });

  test('same year (>= 7 days) returns Edited D Mon', () {
    expect(editedLabel(DateTime(2026, 11, 12, 9, 0, 0), now), 'Edited 12 Nov');
    expect(editedLabel(DateTime(2026, 3, 5, 9, 0, 0), now), 'Edited 5 Mar');
  });

  test('previous year and year boundary return Edited D Mon YYYY', () {
    expect(
      editedLabel(DateTime(2025, 11, 12, 9, 0, 0), now),
      'Edited 12 Nov 2025',
    );

    // Year boundary check: now is 10 Jan 2026, updated is 31 Dec 2025 (10 days ago).
    final janNow = DateTime(2026, 1, 10, 12, 0, 0);
    expect(
      editedLabel(DateTime(2025, 12, 31, 12, 0, 0), janNow),
      'Edited 31 Dec 2025',
    );

    // Year boundary yesterday: now is 1 Jan 2026 18:00, updated is 31 Dec 2025 10:00 (32h ago).
    final newYearDay = DateTime(2026, 1, 1, 18, 0, 0);
    expect(
      editedLabel(DateTime(2025, 12, 31, 10, 0, 0), newYearDay),
      'Edited yesterday',
    );
  });
}
