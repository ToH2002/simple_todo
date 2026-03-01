import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../services/caldav_service.dart';
import '../../data/data_manager.dart';
import '../../data/todo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rrule/rrule.dart';

class TodoListPageManager extends ChangeNotifier {
  final DataManager _dataManager = getIt<DataManager>();

  List<ToDoList> allLists = [];
  ToDoList? currentList;
  List<ToDoItem> allItems = [];
  String currentFilter = 'current';
  String currentTagFilter = 'All'; // 'All' means no tag filter applied
  bool showCompletedItems = false;
  bool isSyncing = false;

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

  Future<void> syncCurrentList() async {
    if (currentList == null ||
        !currentList!.syncEnabled ||
        currentList!.calDavUrl == null)
      return;

    isSyncing = true;
    notifyListeners();

    try {
      final calDavService = getIt<CalDavService>();
      final updatedList = await calDavService.syncList(currentList!);

      // Save the merged data to storage
      await _dataManager.saveList(updatedList);

      // Reload the local UI state
      currentList = updatedList;
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
    } catch (e) {
      print('Manual sync failed: $e');
    } finally {
      isSyncing = false;
      notifyListeners();
    }
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
        .where((item) => !item.isDeleted)
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
      int weightA = a.priority == Priority.none ? -1 : a.priority.index;
      int weightB = b.priority == Priority.none ? -1 : b.priority.index;
      int priorityComparison = weightB.compareTo(weightA);
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
      if (isDone == true &&
          currentList!.items[index].recurringRule != null &&
          currentList!.items[index].recurringRule!.isNotEmpty) {
        bool rollOver = false;
        try {
          final ruleString = currentList!.items[index].recurringRule!;
          final fromDoneDate = ruleString.startsWith('X-FROM-DONE-DATE=TRUE;');
          final actualRuleStr = ruleString
              .replaceAll('X-FROM-DONE-DATE=TRUE;', '')
              .replaceAll('RRULE:', '');
          final safeParseStr = 'RRULE:$actualRuleStr';
          final rrule = RecurrenceRule.fromString(safeParseStr);

          final baseDate = fromDoneDate
              ? DateTime.now()
              : (currentList!.items[index].dueDateTime ?? DateTime.now());

          final instances = rrule.getInstances(
            start: baseDate.copyWith(microsecond: 0).toUtc(),
            after: baseDate.copyWith(microsecond: 0).toUtc(),
            includeAfter: false,
          );

          if (instances.isNotEmpty) {
            final nextDate = instances.first.toLocal();

            DateTime? nextDueDate = nextDate; // We only update the Due Date now

            String? newRuleString = currentList!.items[index].recurringRule;
            bool reachedEnd = false;

            if (rrule.count != null && rrule.count! > 0) {
              int newCount = rrule.count! - 1;
              if (newCount == 0) {
                reachedEnd = true;
              } else {
                final updatedRule = rrule.copyWith(count: newCount);
                newRuleString =
                    (fromDoneDate ? 'X-FROM-DONE-DATE=TRUE;' : '') +
                    updatedRule.toString().replaceAll('RRULE:', '');
              }
            }

            if (!reachedEnd) {
              // Due date is updated, start date logic is left alone
              currentList!.items[index].dueDateTime = nextDueDate;
              currentList!.items[index].recurringRule = newRuleString;
              currentList!.items[index].isDone = false; // Stay incomplete
              rollOver = true;
            }
          }
        } catch (e) {
          print('Error rolling over recurring task: \$e');
        }

        if (!rollOver) {
          currentList!.items[index].isDone = true;
        }
      } else {
        currentList!.items[index].isDone = isDone ?? false;
      }

      currentList!.items[index].lastModified = DateTime.now();

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

    if (currentList!.syncEnabled) {
      for (var item in currentList!.items) {
        if (item.isDone) {
          item.isDeleted = true;
          item.lastModified = DateTime.now();
        }
      }
    } else {
      currentList!.items.removeWhere((item) => item.isDone);
    }

    allItems = List.from(currentList!.items);
    await _dataManager.saveList(currentList!);
    notifyListeners();
  }

  Future<void> deleteItem(ToDoItem item) async {
    if (currentList == null) return;

    if (currentList!.syncEnabled) {
      final index = currentList!.items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        currentList!.items[index].isDeleted = true;
        currentList!.items[index].lastModified = DateTime.now();
      }
    } else {
      currentList!.items.removeWhere((i) => i.id == item.id);
    }

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
