import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../data/data_manager.dart';
import '../../data/todo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoListPageManager extends ChangeNotifier {
  final DataManager _dataManager = getIt<DataManager>();

  List<ToDoList> allLists = [];
  ToDoList? currentList;
  List<ToDoItem> allItems = [];
  String currentFilter = 'all';
  String currentTagFilter = 'All'; // 'All' means no tag filter applied
  bool showCompletedItems = true;

  TodoListPageManager() {
    loadLists();
  }

  Future<void> loadLists() async {
    allLists = await _dataManager.getLists();
    final prefs = await SharedPreferences.getInstance();

    if (currentList != null) {
      // Check if current list still exists or was updated
      final updatedList = await _dataManager.getList(currentList!.id);
      if (updatedList != null) {
        currentList = updatedList;
      } else {
        currentList = allLists.isNotEmpty ? allLists.first : null;
      }
    } else {
      final savedId = prefs.getString('last_active_list_id');
      if (savedId != null) {
        final savedList = await _dataManager.getList(savedId);
        currentList =
            savedList ?? (allLists.isNotEmpty ? allLists.first : null);
      } else {
        currentList = allLists.isNotEmpty ? allLists.first : null;
      }
    }

    if (currentList != null) {
      allItems = List.from(currentList!.items);

      // Make sure all tags used by items exist in the main list
      bool tagsUpdated = false;
      for (var item in allItems) {
        for (var tag in item.tags) {
          if (!currentList!.tags.contains(tag)) {
            currentList!.tags.add(tag);
            tagsUpdated = true;
          }
        }
      }
      if (tagsUpdated) {
        await _dataManager.saveList(currentList!);
      }
      await prefs.setString('last_active_list_id', currentList!.id);
    } else {
      allItems = [];
      await prefs.remove('last_active_list_id');
    }
    notifyListeners();
  }

  Future<void> switchList(String listId) async {
    final list = await _dataManager.getList(listId);
    if (list != null) {
      currentList = list;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_list_id', listId);
      await loadLists();
    }
  }

  void setFilter(String filter) {
    currentFilter = filter;
    notifyListeners();
  }

  void setTagFilter(String tag) {
    currentTagFilter = tag;
    notifyListeners();
  }

  List<ToDoItem> getFilteredItems(String section) {
    if (currentList == null) return [];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final nextWeek = startOfDay.add(const Duration(days: 7));

    // Base filter
    var list = allItems
        .where((item) {
          if (currentFilter == 'current') {
            return item.startDateTime == null ||
                item.startDateTime!.isBefore(now) ||
                item.startDateTime!.isAtSameMomentAs(now);
          }
          if (currentFilter == 'due') {
            return item.dueDateTime != null &&
                (item.dueDateTime!.isBefore(now) ||
                    item.dueDateTime!.isAtSameMomentAs(now));
          }
          if (currentFilter == 'radar') {
            return item.dueDateTime != null &&
                item.dueDateTime!.isAfter(
                  startOfDay.subtract(const Duration(seconds: 1)),
                ) &&
                item.dueDateTime!.isBefore(nextWeek);
          }
          return true; // 'all' - which should show everything unless completed filter applies
        })
        .where((item) {
          if (!showCompletedItems && item.isDone) return false;
          if (currentTagFilter != 'All' &&
              !item.tags.contains(currentTagFilter))
            return false;
          return true;
        })
        .toList();

    // Sort primarily by priority (descending, high first)
    // Sort secondarily by due date (ascending, soonest first)
    list.sort((a, b) {
      int priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      // If same priority, sort by due date
      if (a.dueDateTime == null && b.dueDateTime == null) return 0;
      if (a.dueDateTime == null) return 1; // null dates go to bottom
      if (b.dueDateTime == null) return -1;
      return a.dueDateTime!.compareTo(b.dueDateTime!);
    });

    // Section grouping
    switch (section) {
      case 'Overdue':
        return list
            .where(
              (i) =>
                  i.dueDateTime != null &&
                  i.dueDateTime!.isBefore(startOfDay) &&
                  !i.isDone,
            )
            .toList();
      case 'Due':
        return list
            .where(
              (i) =>
                  i.dueDateTime != null &&
                  i.dueDateTime!.isAfter(
                    startOfDay.subtract(const Duration(seconds: 1)),
                  ) &&
                  i.dueDateTime!.isBefore(
                    startOfDay.add(const Duration(days: 1)),
                  ) &&
                  !i.isDone,
            )
            .toList();
      case 'Tomorrow':
        return list
            .where(
              (i) =>
                  i.dueDateTime != null &&
                  i.dueDateTime!.isAfter(
                    startOfDay
                        .add(const Duration(days: 1))
                        .subtract(const Duration(seconds: 1)),
                  ) &&
                  i.dueDateTime!.isBefore(
                    startOfDay.add(const Duration(days: 2)),
                  ) &&
                  !i.isDone,
            )
            .toList();
      case 'Further Out':
        return list
            .where(
              (i) =>
                  i.dueDateTime != null &&
                  i.dueDateTime!.isAfter(
                    startOfDay
                        .add(const Duration(days: 2))
                        .subtract(const Duration(seconds: 1)),
                  ) &&
                  !i.isDone,
            )
            .toList();
      case 'No Due Date':
        return list.where((i) => i.dueDateTime == null && !i.isDone).toList();
      case 'Completed':
        return list.where((i) => i.isDone).toList();
      default:
        return [];
    }
  }

  Future<void> toggleItemDone(ToDoItem item, bool? isDone) async {
    if (currentList == null) return;

    // Find the item and update
    final index = currentList!.items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      currentList!.items[index].isDone = isDone ?? false;

      // Update local cache
      allItems = List.from(currentList!.items);

      // Save
      await _dataManager.saveList(currentList!);
      notifyListeners();
    }
  }

  Future<void> saveOrUpdateItem(ToDoItem item) async {
    if (currentList == null) return;

    final index = currentList!.items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      currentList!.items[index] = item;
    } else {
      currentList!.items.add(item);
    }

    allItems = List.from(currentList!.items);
    await _dataManager.saveList(currentList!);
    notifyListeners();
  }

  void toggleShowCompletedItems() {
    showCompletedItems = !showCompletedItems;
    notifyListeners(); // Will trigger UI refresh
  }

  Future<void> deleteCompletedItems() async {
    if (currentList == null) return;
    currentList!.items.removeWhere((item) => item.isDone);
    allItems = List.from(currentList!.items);
    await _dataManager.saveList(currentList!);
    notifyListeners();
  }

  Future<void> deleteItem(ToDoItem item) async {
    if (currentList == null) return;
    currentList!.items.removeWhere((i) => i.id == item.id);
    allItems = List.from(currentList!.items);
    await _dataManager.saveList(currentList!);
    notifyListeners();
  }

  Future<void> addListTag(String tag) async {
    if (currentList == null) return;
    if (!currentList!.tags.contains(tag)) {
      currentList!.tags.add(tag);
      await _dataManager.saveList(currentList!);
      notifyListeners();
    }
  }

  Future<void> updateListTag(String oldTag, String newTag) async {
    if (currentList == null) return;

    // Update in list
    final tagIndex = currentList!.tags.indexOf(oldTag);
    if (tagIndex != -1) {
      if (currentList!.tags.contains(newTag)) {
        // If the new tag already exists, just remove the old one from the list
        // to avoid duplicates, but update the items below to use the new tag.
        currentList!.tags.remove(oldTag);
      } else {
        currentList!.tags[tagIndex] = newTag;
      }

      // Update in all items
      for (var item in currentList!.items) {
        if (item.tags.contains(oldTag)) {
          item.tags.remove(oldTag);
          if (!item.tags.contains(newTag)) {
            item.tags.add(newTag);
          }
        }
      }
      allItems = List.from(currentList!.items);
      await _dataManager.saveList(currentList!);
      notifyListeners();
    }
  }

  Future<void> deleteListTag(String tag) async {
    if (currentList == null) return;

    final removed = currentList!.tags.remove(tag);
    if (removed) {
      // Remove from all items
      for (var item in currentList!.items) {
        item.tags.remove(tag);
      }
      allItems = List.from(currentList!.items);
      await _dataManager.saveList(currentList!);
      notifyListeners();
    }
  }
}
