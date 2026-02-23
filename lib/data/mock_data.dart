import 'todo_models.dart';

class MockData {
  static final ToDoList personalList = ToDoList(
    id: 'list_1',
    name: 'Personal',
    tags: ['Errands', 'Health', 'Finance', 'Home', 'Fun', 'Travel', 'Hobby'],
  );

  static final List<ToDoItem> items = [
    ToDoItem(
      id: '1',
      listId: 'default',
      title: 'Buy groceries',
      description: 'Milk, bread, eggs, cheese',
      isDone: false,
      priority: Priority.normal,
      tags: ['Errands'],
      createDateTime: DateTime.now().subtract(const Duration(days: 2)),
      dueDateTime: DateTime.now().subtract(const Duration(days: 1)), // Overdue
    ),
    ToDoItem(
      id: '2',
      listId: 'default',
      title: 'Schedule dentist appointment',
      isDone: false,
      priority: Priority.high,
      tags: ['Health'],
      createDateTime: DateTime.now().subtract(const Duration(days: 5)),
      dueDateTime: DateTime.now(), // Due today
    ),
    ToDoItem(
      id: '3',
      listId: 'default',
      title: 'Pay council tax',
      isDone: true,
      priority: Priority.high,
      tags: ['Finance', 'Home'],
      createDateTime: DateTime.now().subtract(const Duration(days: 10)),
      dueDateTime: DateTime.now().subtract(
        const Duration(days: 2),
      ), // Done, previously overdue
    ),
    ToDoItem(
      id: '4',
      listId: 'default',
      title: 'Plan weekend trip',
      isDone: false,
      priority: Priority.low,
      tags: ['Fun', 'Travel'],
      createDateTime: DateTime.now().subtract(const Duration(days: 1)),
      dueDateTime: DateTime.now().add(const Duration(days: 4)), // Future
    ),
    ToDoItem(
      id: '5',
      listId: 'default',
      title: 'Read new Sci-Fi book',
      description: 'The one by Andy Weir',
      isDone: false,
      priority: Priority.none,
      tags: ['Hobby'],
      createDateTime: DateTime.now(),
      // No due date
    ),
  ];
}
