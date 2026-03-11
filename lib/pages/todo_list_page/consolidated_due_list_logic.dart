import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../data/data_manager.dart';
import '../../data/todo_models.dart';

class ConsolidatedDueListLogic extends ChangeNotifier {
  final DataManager _dataManager = getIt<DataManager>();

  // The virtual "merged" list we present to the UI
  ToDoList? virtualList;

  // Map to help the UI look up the original list's color and name
  final Map<String, ToDoList> sourceLists = {};

  ConsolidatedDueListLogic() {
    loadConsolidatedList();
  }

  Future<void> loadConsolidatedList() async {
    final allLists = await _dataManager.getLists();

    final List<ToDoItem> consolidatedItems = [];
    sourceLists.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final list in allLists) {
      sourceLists[list.id] = list;

      for (final item in list.items) {
        if (!item.isDone && item.dueDateTime != null) {
          final due = DateTime(
            item.dueDateTime!.year,
            item.dueDateTime!.month,
            item.dueDateTime!.day,
          );
          // If it's due today or overdue
          if (due.isBefore(today) || due.isAtSameMomentAs(today)) {
            consolidatedItems.add(item);
          }
        }
      }
    }

    // Sorting: By priority first, then by Due Date (for overdue items)
    consolidatedItems.sort((a, b) {
      final pA = a.priority.index;
      final pB = b.priority.index;
      if (pA != pB) {
        return pA.compareTo(pB);
      }

      // Secondary: Due Date
      if (a.dueDateTime != null && b.dueDateTime != null) {
        return a.dueDateTime!.compareTo(b.dueDateTime!);
      }
      return 0; // Fallback
    });

    virtualList = ToDoList(
      id: 'consolidated_due_list',
      name: 'Due Tasks',
      items: consolidatedItems,
      color: Colors.grey.shade400,
    );

    notifyListeners();
  }
}
