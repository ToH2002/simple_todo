import 'package:flutter/material.dart';
import '../../data/todo_models.dart';
import 'package:uuid/uuid.dart';

import '../../services/service_locator.dart';
import '../../data/data_manager.dart';

class TodoEditorPageManager extends ChangeNotifier {
  final ToDoItem? initialItem;
  final String listId;

  late String title;
  late String description;
  late Priority priority;
  DateTime? startDate;
  DateTime? dueDate;
  List<String> tags = [];

  TodoEditorPageManager({this.initialItem, required this.listId}) {
    title = initialItem?.title ?? '';
    description = initialItem?.description ?? '';
    priority = initialItem?.priority ?? Priority.normal;
    startDate = initialItem?.startDateTime;
    dueDate = initialItem?.dueDateTime;
    tags = List.from(initialItem?.tags ?? []);
    prioritizeTags();
  }

  void prioritizeTags() {
    loadAvailableTags();
  }

  List<String> availableTags = [];

  Future<void> loadAvailableTags() async {
    final dataManager = getIt<DataManager>();
    final list = await dataManager.getList(listId);
    if (list != null) {
      final Set<String> combinedTags = {};
      combinedTags.addAll(list.tags);
      combinedTags.addAll(tags);
      availableTags = combinedTags.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      notifyListeners();
    }
  }

  Future<void> addNewTagToList(String tag) async {
    final text = tag.trim();
    if (text.isEmpty) return;

    final dataManager = getIt<DataManager>();
    final list = await dataManager.getList(listId);
    if (list != null) {
      if (!list.tags.contains(text)) {
        list.tags.add(text);
        await dataManager.saveList(list);
        availableTags = List.from(list.tags);
      }
      addTag(text); // Also add to the item's current selected tags
    }
  }

  void updateTitle(String newTitle) {
    title = newTitle;
    notifyListeners();
  }

  void updateDescription(String newDescription) {
    description = newDescription;
    notifyListeners();
  }

  void setPriority(Priority newPriority) {
    priority = newPriority;
    notifyListeners();
  }

  void setStartDate(DateTime? date) {
    startDate = date;
    notifyListeners();
  }

  void setDueDate(DateTime? date) {
    dueDate = date;
    notifyListeners();
  }

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      notifyListeners();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    notifyListeners();
  }

  ToDoItem compileItem() {
    return ToDoItem(
      id: initialItem?.id ?? const Uuid().v4(),
      listId: initialItem?.listId ?? listId,
      title: title,
      description: description,
      isDone: initialItem?.isDone ?? false,
      priority: priority,
      tags: tags,
      createDateTime: initialItem?.createDateTime ?? DateTime.now(),
      lastModified: DateTime.now(),
      startDateTime: startDate,
      dueDateTime: dueDate,
      recurringRule: initialItem?.recurringRule,
    );
  }

  bool get isValid => title.trim().isNotEmpty;
}
