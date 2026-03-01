import 'package:flutter_test/flutter_test.dart';
import 'package:rrule/rrule.dart';

void main() {
  group('Recurrence Rollover Logic Tests', () {
    test('Calculates next Daily occurrence correctly', () {
      final ruleString = 'RRULE:FREQ=DAILY;INTERVAL=1';
      final rrule = RecurrenceRule.fromString(ruleString);
      final baseDate = DateTime(2026, 1, 1, 10, 0); // Jan 1st

      final instances = rrule.getInstances(
        start: baseDate.copyWith(microsecond: 0).toUtc(),
        after: baseDate.copyWith(microsecond: 0).toUtc(),
        includeAfter: false,
      );

      final nextDate = instances.first.toLocal();
      expect(nextDate.year, 2026);
      expect(nextDate.month, 1);
      expect(nextDate.day, 2);
    });

    test('Calculates next Weekly (Mon/Wed) occurrence correctly', () {
      final ruleString = 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE';
      final rrule = RecurrenceRule.fromString(ruleString);

      // Jan 5th 2026 is Monday
      final baseDate = DateTime(2026, 1, 5, 10, 0);

      final instances = rrule.getInstances(
        start: baseDate.copyWith(microsecond: 0).toUtc(),
        after: baseDate.copyWith(microsecond: 0).toUtc(),
        includeAfter: false,
      );

      final nextDate = instances.first.toLocal();
      // Next day should be Wednesday (Jan 7th)
      expect(nextDate.year, 2026);
      expect(nextDate.month, 1);
      expect(nextDate.day, 7);
    });

    test('Calculates Monthly Last Weekday occurrence correctly', () {
      final ruleString = 'RRULE:FREQ=MONTHLY;BYDAY=-1WE';
      final rrule = RecurrenceRule.fromString(ruleString);

      // Jan 28th 2026 is the last wednesday of Jan
      final baseDate = DateTime(2026, 1, 28, 10, 0);

      final instances = rrule.getInstances(
        start: baseDate.copyWith(microsecond: 0).toUtc(),
        after: baseDate.copyWith(microsecond: 0).toUtc(),
        includeAfter: false,
      );

      final nextDate = instances.first.toLocal();
      // Next last wednesday is Feb 25, 2026
      expect(nextDate.year, 2026);
      expect(nextDate.month, 2);
      expect(nextDate.day, 25);
    });

    test('Decrements recurrence count correctly', () {
      final ruleString = 'RRULE:FREQ=DAILY;COUNT=5';
      final rrule = RecurrenceRule.fromString(ruleString);

      int newCount = rrule.count! - 1;
      final updatedRule = rrule.copyWith(count: newCount);

      // Library serializes rules predictably
      expect(updatedRule.toString(), 'RRULE:FREQ=DAILY;COUNT=4');
    });
  });
}
