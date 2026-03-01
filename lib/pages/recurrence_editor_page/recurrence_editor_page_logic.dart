import 'package:flutter/material.dart';
import 'package:rrule/rrule.dart';
import 'package:intl/intl.dart';

enum RecurrenceFrequency { none, daily, weekly, monthly, yearly }

enum MonthlyType { dayOfMonth, nthWeekday, lastWeekday }

enum EndType { never, untilDate, count }

class RecurrenceEditorPageManager extends ChangeNotifier {
  late DateTime dueDate;
  RecurrenceFrequency frequency = RecurrenceFrequency.none;
  int interval = 1;

  // Weekly
  Set<int> weeklyDays = {}; // 1-7, 1=Monday

  // Monthly
  MonthlyType monthlyType = MonthlyType.dayOfMonth;

  // End
  EndType endType = EndType.never;
  DateTime? untilDate;
  int repetitionCount = 7;

  // Next Repeat From
  bool repeatFromDoneDate = false;

  RecurrenceEditorPageManager({
    String? initialRule,
    required DateTime dueDate,
  }) {
    this.dueDate = dueDate;
    if (initialRule != null && initialRule.isNotEmpty) {
      try {
        if (initialRule.startsWith('X-FROM-DONE-DATE=TRUE;')) {
          repeatFromDoneDate = true;
        }
        final actualRuleStr = initialRule
            .replaceAll('X-FROM-DONE-DATE=TRUE;', '')
            .replaceAll('RRULE:', '');

        final safeStr = 'RRULE:$actualRuleStr';
        final parsed = RecurrenceRule.fromString(safeStr);
        _applyParsedRule(parsed);
      } catch (e) {
        print('Error parsing initial rule: $e');
        frequency = RecurrenceFrequency.none;
      }
    } else {
      weeklyDays.add(dueDate.weekday);
    }
  }

  void _applyParsedRule(RecurrenceRule rule) {
    if (rule.frequency == Frequency.daily) {
      frequency = RecurrenceFrequency.daily;
    } else if (rule.frequency == Frequency.weekly) {
      frequency = RecurrenceFrequency.weekly;
      weeklyDays.clear();
      if (rule.byWeekDays.isNotEmpty) {
        for (var d in rule.byWeekDays) {
          weeklyDays.add(d.day);
        }
      } else {
        weeklyDays.add(dueDate.weekday);
      }
    } else if (rule.frequency == Frequency.monthly) {
      frequency = RecurrenceFrequency.monthly;
      if (rule.byWeekDays.isNotEmpty) {
        final entry = rule.byWeekDays.first;
        if (entry.occurrence == -1) {
          monthlyType = MonthlyType.lastWeekday;
        } else {
          monthlyType = MonthlyType.nthWeekday;
        }
      } else {
        monthlyType = MonthlyType.dayOfMonth;
      }
    } else if (rule.frequency == Frequency.yearly) {
      frequency = RecurrenceFrequency.yearly;
    }

    interval = rule.interval ?? 1;

    if (rule.until != null) {
      endType = EndType.untilDate;
      untilDate = rule.until;
    } else if (rule.count != null) {
      endType = EndType.count;
      repetitionCount = rule.count!;
    } else {
      endType = EndType.never;
    }
  }

  void setDueDate(DateTime date) {
    dueDate = date;
    notifyListeners();
  }

  void setFrequency(RecurrenceFrequency freq) {
    frequency = freq;
    notifyListeners();
  }

  void setInterval(int inter) {
    interval = inter;
    notifyListeners();
  }

  void toggleWeeklyDay(int dayNum) {
    if (weeklyDays.contains(dayNum)) {
      if (weeklyDays.length > 1) {
        weeklyDays.remove(dayNum);
      }
    } else {
      weeklyDays.add(dayNum);
    }
    notifyListeners();
  }

  void setMonthlyType(MonthlyType type) {
    monthlyType = type;
    notifyListeners();
  }

  void setRepeatFromDoneDate(bool val) {
    repeatFromDoneDate = val;
    notifyListeners();
  }

  void setEndType(EndType type) {
    endType = type;
    notifyListeners();
  }

  void setUntilDate(DateTime date) {
    untilDate = date;
    notifyListeners();
  }

  void setRepetitionCount(int count) {
    repetitionCount = count;
    notifyListeners();
  }

  String _numSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String getWeekdayString() {
    return DateFormat('EEEE').format(dueDate);
  }

  String getNthWeekdayString() {
    final dayNum = dueDate.day;
    final nth = ((dayNum - 1) / 7).floor() + 1;
    return '${nth}${_numSuffix(nth)} ${getWeekdayString()}';
  }

  bool isLastWeekOfMonth() {
    final daysInMonth = DateTime(dueDate.year, dueDate.month + 1, 0).day;
    return (daysInMonth - dueDate.day) < 7;
  }

  String? compileRule() {
    if (frequency == RecurrenceFrequency.none) return null;

    Frequency freq;
    switch (frequency) {
      case RecurrenceFrequency.daily:
        freq = Frequency.daily;
        break;
      case RecurrenceFrequency.weekly:
        freq = Frequency.weekly;
        break;
      case RecurrenceFrequency.monthly:
        freq = Frequency.monthly;
        break;
      case RecurrenceFrequency.yearly:
        freq = Frequency.yearly;
        break;
      default:
        return null;
    }

    DateTime? until;
    int? count;
    if (endType == EndType.untilDate && untilDate != null) {
      until = DateTime.utc(
        untilDate!.year,
        untilDate!.month,
        untilDate!.day,
        23,
        59,
        59,
      );
    } else if (endType == EndType.count) {
      count = repetitionCount;
    }

    List<ByWeekDayEntry>? byDays;
    List<int>? byMonthDays;

    if (frequency == RecurrenceFrequency.weekly && weeklyDays.isNotEmpty) {
      byDays = weeklyDays.map((d) => ByWeekDayEntry(d)).toList();
    } else if (frequency == RecurrenceFrequency.monthly) {
      if (monthlyType == MonthlyType.nthWeekday) {
        final nth = ((dueDate.day - 1) / 7).floor() + 1;
        byDays = [ByWeekDayEntry(dueDate.weekday, nth)];
      } else if (monthlyType == MonthlyType.lastWeekday) {
        byDays = [ByWeekDayEntry(dueDate.weekday, -1)];
      } else {
        byMonthDays = [dueDate.day];
      }
    }

    final rule = RecurrenceRule(
      frequency: freq,
      interval: interval > 1 ? interval : null,
      until: until,
      count: count,
      byWeekDays: byDays ?? const [],
      byMonthDays: byMonthDays ?? const [],
    );

    // Prefix with custom flag if Done Date is requested.
    // X-FROM-DONE-DATE=TRUE;
    final rruleStr = rule.toString().replaceAll('RRULE:', '');
    if (repeatFromDoneDate) {
      return 'X-FROM-DONE-DATE=TRUE;$rruleStr';
    }
    return rruleStr;
  }
}
