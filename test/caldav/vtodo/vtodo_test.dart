import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/caldav/vtodo.dart';
import '../../../lib/data/todo_models.dart';

void main() {
  group('VTodo Parsing & Serialization Suite', () {
    final DateTime mockTime = DateTime.utc(2026, 2, 24, 15, 0, 0);

    test('Serializes ToDoItem to VTODO String', () {
      final item = ToDoItem(
        id: 'test-123',
        listId: 'list-1',
        title: 'Buy Groceries',
        description: 'Milk & Eggs',
        isDone: false,
        priority: Priority.high,
        tags: ['Shopping', 'Urgent'],
        createDateTime: mockTime,
        dueDateTime: mockTime.add(const Duration(days: 1)),
      );

      final vtodo = VTodo.fromToDoItem(item);
      final icsString = vtodo.toIcalendar();

      expect(icsString, contains('BEGIN:VTODO'));
      expect(icsString, contains('END:VTODO'));
      expect(icsString, contains('UID:test-123'));
      expect(icsString, contains('SUMMARY:Buy Groceries'));
      expect(icsString, contains('DESCRIPTION:Milk & Eggs'));
      expect(icsString, contains('STATUS:NEEDS-ACTION'));
      expect(icsString, contains('PRIORITY:1')); // High = 1
      expect(icsString, contains('CATEGORIES:Shopping,Urgent'));
      expect(icsString, contains('DTSTAMP:20260224T150000Z'));
      expect(icsString, contains('DUE;VALUE=DATE:20260225'));
    });

    test('Parses raw VTODO string to VTodo Object', () {
      const rawIcs = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTODO
UID:parsed-456
SUMMARY:Call Bob
STATUS:COMPLETED
PRIORITY:5
CATEGORIES:Work
DTSTAMP:20260224T150000Z
END:VTODO
END:VCALENDAR''';

      final vtodo = VTodo.fromIcalendar(
        rawIcs,
        href: Uri.parse('http://example.com/parsed-456.ics'),
      );

      expect(vtodo.uid, 'parsed-456');
      expect(vtodo.summary, 'Call Bob');
      expect(vtodo.status, 'COMPLETED');
      expect(vtodo.priority, 5); // Normal
      expect(vtodo.categories, ['Work']);
      expect(vtodo.href?.toString(), 'http://example.com/parsed-456.ics');
    });

    test('Converts VTodo object back to local ToDoItem', () {
      final vtodo = VTodo(
        uid: 'convert-789',
        summary: 'Send Invoice',
        status: 'NEEDS-ACTION',
        priority: 9, // Low
        categories: ['Finance'],
        dtstamp: mockTime,
        href: Uri.parse('http://example.com/convert-789.ics'),
        etag: '"123456789"',
      );

      // Converts back to a ToDoItem assigned to a specific listId
      final item = vtodo.toLocalItem(formatListId: 'parent-list');

      expect(item.id, 'convert-789');
      expect(item.listId, 'parent-list');
      expect(item.title, 'Send Invoice');
      expect(item.isDone, false);
      expect(item.priority, Priority.low); // 9 -> Priority.low
      expect(item.tags, ['Finance']);
    });

    test('Parses complex multi-line descriptions comprehensively', () {
      const rawIcs = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTODO
UID:multi-line-test
SUMMARY:Test description formatting
DESCRIPTION:Line 1\\nLine 2 (Escaped newline)
 And Line 3 (Folded line)
Line 4 (Unescaped non-standard literal newline)
STATUS:NEEDS-ACTION
END:VTODO
END:VCALENDAR''';

      final vtodo = VTodo.fromIcalendar(rawIcs);

      expect(vtodo.uid, 'multi-line-test');
      expect(
        vtodo.description,
        'Line 1\nLine 2 (Escaped newline)And Line 3 (Folded line)',
      );
    });
  });
}
