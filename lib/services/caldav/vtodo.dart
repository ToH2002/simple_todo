import 'package:uuid/uuid.dart';
import '../../data/todo_models.dart';

/// Represents a CalDAV To-Do event (VTODO)
/// Designed specifically as a translation layer extending the `caldav` package utilities.
class VTodo {
  final String uid;
  final String summary;
  final String? description;
  final String? status; // NEEDS-ACTION, COMPLETED, IN-PROCESS, CANCELLED
  final int? percentComplete; // 0=none, 100=done
  final int? priority; // 0=none, 1=high, 5=normal, 9=low
  final List<String> categories;

  final DateTime? dtstart;
  final DateTime? due;
  final DateTime? completed;
  final DateTime dtstamp;
  final DateTime? lastModified;

  final String? rrule;

  // Connection mapping state
  final Uri? href;
  final String? etag;

  VTodo({
    required this.uid,
    required this.summary,
    this.description,
    this.status = 'NEEDS-ACTION',
    this.percentComplete,
    this.priority = 0,
    this.categories = const [],
    this.dtstart,
    this.due,
    this.completed,
    required this.dtstamp,
    this.lastModified,
    this.rrule,
    this.href,
    this.etag,
  });

  /// Translates our internal App model into a standardized VTodo representation
  factory VTodo.fromToDoItem(ToDoItem item) {
    int vPriority = 0;
    switch (item.priority) {
      case Priority.high:
        vPriority = 1;
        break;
      case Priority.normal:
        vPriority = 5;
        break;
      case Priority.low:
        vPriority = 9;
        break;
      case Priority.none:
        vPriority = 0;
        break;
    }

    return VTodo(
      uid: item.id,
      summary: item.title,
      description: item.description.isNotEmpty ? item.description : null,
      status: item.isDone ? 'COMPLETED' : 'NEEDS-ACTION',
      priority: vPriority,
      categories: item.tags,
      dtstart: item.startDateTime,
      due: item.dueDateTime,
      dtstamp: item.createDateTime, // Standard requires a dtstamp
      lastModified: item.lastModified,
      rrule: item.recurringRule,
    );
  }

  /// Deserializes a raw .ics String received from a CalDAV server into a VTodo object
  factory VTodo.fromIcalendar(String icsData, {Uri? href, String? etag}) {
    // Incredibly lightweight manual parser for VTODO structures.
    // In production with complex line folds, a dedicated iCal parsing library is better,
    // but CalDAV payload responses for single resources are relatively flat.

    String uid = const Uuid().v4();
    String summary = 'Untitled VTODO';
    String? description;
    String? status;
    int? priority;
    List<String> categories = [];
    DateTime? dtstart;
    DateTime? due;
    DateTime dtstamp = DateTime.now().toUtc();
    DateTime? lastModified;
    String? rrule;
    int? percentComplete;

    final lines = icsData.split(RegExp(r'\r?\n'));

    // Advanced line unwrapping & handling of non-standard line breaks
    final unwrappedLines = <String>[];
    for (var line in lines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        // RFC 5545 proper line fold
        if (unwrappedLines.isNotEmpty) {
          unwrappedLines.last += line.substring(1);
        }
      } else {
        if (line.isEmpty) continue;

        // // Does this look like a new known property?
        // final isKnownProperty =
        //     line.startsWith('UID:') ||
        //     line.startsWith('SUMMARY:') ||
        //     line.startsWith('DESCRIPTION:') ||
        //     line.startsWith('STATUS:') ||
        //     line.startsWith('PRIORITY:') ||
        //     line.startsWith('CATEGORIES:') ||
        //     line.startsWith('DTSTAMP:') ||
        //     line.startsWith('LAST-MODIFIED:') ||
        //     line.startsWith('DTSTART') ||
        //     line.startsWith('DUE') ||
        //     line.startsWith('RRULE:') ||
        //     line.startsWith('BEGIN:') ||
        //     line.startsWith('END:') ||
        //     line.startsWith('VERSION:') ||
        //     line.startsWith('SEQUENCE:') ||
        //     line.startsWith('COMPLETED:') ||
        //     line.startsWith('PERCENT-COMPLETE:') ||
        //     line.startsWith('PRODID:');

        // if (isKnownProperty || unwrappedLines.isEmpty) {
        //   unwrappedLines.add(line);
        // } else {
        //   // This is a non-standard literal line break in the middle of a property (likely DESCRIPTION)
        //   // We encode it as \\n so the property unescaper handles it uniformly below.
        //   unwrappedLines.last += '\\n$line';
        // }

        // alternative: always treat like well-formed VTODO
        unwrappedLines.add(line);
      }
    }

    for (var line in unwrappedLines) {
      if (line.startsWith('UID:')) {
        uid = line.substring(4);
      } else if (line.startsWith('SUMMARY:')) {
        summary = line.substring(8);
      } else if (line.startsWith('DESCRIPTION:')) {
        description = line.substring(12);
      } else if (line.startsWith('STATUS:')) {
        status = line.substring(7);
      } else if (line.startsWith('PRIORITY:')) {
        priority = int.tryParse(line.substring(9));
      } else if (line.startsWith('CATEGORIES:')) {
        categories = line
            .substring(11)
            .split(',')
            .map((c) => c.trim())
            .toList();
      } else if (line.startsWith('DTSTAMP:')) {
        dtstamp =
            _parseIcsDateTime(line.substring(8)) ?? DateTime.now().toUtc();
      } else if (line.startsWith('LAST-MODIFIED:')) {
        lastModified = _parseIcsDateTime(line.substring(14));
      } else if (line.startsWith('DTSTART;VALUE=DATE:') ||
          line.startsWith('DTSTART:')) {
        dtstart = _parseIcsDateTime(line.split(':').last);
      } else if (line.startsWith('DUE;VALUE=DATE:') ||
          line.startsWith('DUE:')) {
        due = _parseIcsDateTime(line.split(':').last);
      } else if (line.startsWith('RRULE:')) {
        rrule = line.substring(6);
      } else if (line.startsWith('PERCENT-COMPLETE:')) {
        percentComplete = int.tryParse(line.substring(17));
      }
    }

    return VTodo(
      uid: uid,
      summary: summary.replaceAll('\\n', '\n').replaceAll('\\,', ','),
      description: description?.replaceAll('\\n', '\n').replaceAll('\\,', ','),
      status: status,
      percentComplete: percentComplete,
      priority: priority,
      categories: categories,
      dtstart: dtstart,
      due: due,
      dtstamp: dtstamp,
      lastModified: lastModified,
      rrule: rrule,
      href: href,
      etag: etag,
    );
  }

  /// Converts this standards-compliant VTodo back into our UI's `ToDoItem`
  ToDoItem toLocalItem({required String formatListId}) {
    Priority p = Priority.none;
    if (priority != null && priority! > 0) {
      if (priority! < 5)
        p = Priority.high;
      else if (priority! == 5)
        p = Priority.normal;
      else if (priority! > 5)
        p = Priority.low;
    }

    return ToDoItem(
      id: uid,
      listId: formatListId,
      title: summary,
      description: description ?? '',
      isDone: status == 'COMPLETED' || percentComplete == 100,
      priority: p,
      tags: categories,
      createDateTime: dtstamp,
      lastModified: lastModified,
      startDateTime: dtstart,
      dueDateTime: due,
      recurringRule: rrule,
    );
  }

  /// Serializes into a standard VTODO `.ics` formatted string for PUT requests
  String toIcalendar() {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//cornerapps//SimpleToDo//EN');

    buffer.writeln('BEGIN:VTODO');
    buffer.writeln('UID:$uid');
    buffer.writeln('DTSTAMP:${_formatIcsDateTime(dtstamp)}');
    if (lastModified != null) {
      buffer.writeln('LAST-MODIFIED:${_formatIcsDateTime(lastModified!)}');
    }

    buffer.writeln('SUMMARY:${_escapeText(summary)}');
    if (description != null)
      buffer.writeln('DESCRIPTION:${_escapeText(description!)}');

    if (status != null) {
      buffer.writeln('STATUS:$status');
      if (status == 'COMPLETED') {
        buffer.writeln('PERCENT-COMPLETE:100');
      } else {
        buffer.writeln('PERCENT-COMPLETE:0');
      }
    }
    if (priority != null && priority! > 0) buffer.writeln('PRIORITY:$priority');
    if (categories.isNotEmpty)
      buffer.writeln('CATEGORIES:${categories.join(',')}');

    if (dtstart != null) {
      buffer.writeln('DTSTART;VALUE=DATE:${_formatIcsDateOnly(dtstart!)}');
    }
    if (due != null) {
      buffer.writeln('DUE;VALUE=DATE:${_formatIcsDateOnly(due!)}');
    }
    if (rrule != null) buffer.writeln('RRULE:$rrule');

    buffer.writeln('END:VTODO');
    buffer.writeln('END:VCALENDAR');

    return buffer.toString();
  }

  static DateTime? _parseIcsDateTime(String value) {
    if (value.isEmpty) return null;

    // Try native parse for basic formats, or strip the Z and T for basic ISO
    try {
      if (value.length == 8) {
        // YYYYMMDD - Floating Date (Local Time Semantics)
        return DateTime(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(4, 6)),
          int.parse(value.substring(6, 8)),
        );
      }

      // Expected YYYYMMDDTHHMMSSZ - Absolute Time (Convert back to Local Time)
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _formatIcsDateOnly(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatIcsDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}Z';
  }

  static String _escapeText(String text) {
    return text.replaceAll('\n', '\\n').replaceAll(',', '\\,');
  }
}
