import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../data/data_manager.dart';
import '../../data/todo_models.dart';
import 'package:uuid/uuid.dart';

class ListManagerPageLogic extends ChangeNotifier {
  final DataManager _dataManager = getIt<DataManager>();
  List<ToDoList> lists = [];

  ListManagerPageLogic() {
    loadLists();
  }

  Future<void> loadLists() async {
    lists = await _dataManager.getLists();
    notifyListeners();
  }

  Future<void> createList(String name) async {
    if (name.trim().isEmpty) return;
    final newList = ToDoList(id: const Uuid().v4(), name: name.trim());
    await _dataManager.saveList(newList);
    await loadLists();
  }

  Future<void> updateList(ToDoList list) async {
    await _dataManager.saveList(list);
    await loadLists();
  }

  Future<void> deleteList(String listId) async {
    if (lists.length <= 1) return; // Cannot delete the last list
    await _dataManager.deleteList(listId);
    await loadLists();
  }
}
