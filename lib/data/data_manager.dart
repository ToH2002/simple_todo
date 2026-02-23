import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'todo_models.dart';

abstract class DataManager {
  Future<void> init();
  Future<List<ToDoList>> getLists();
  Future<ToDoList?> getList(String listId);
  Future<void> saveList(ToDoList list);
  Future<void> deleteList(String listId);
}

class LocalDataManager implements DataManager {
  final Map<String, ToDoList> _lists = {};
  bool _initialized = false;
  late final Directory _storageDir;

  @override
  Future<void> init() async {
    if (_initialized) return;

    final rootDir = await getApplicationSupportDirectory();
    _storageDir = Directory('${rootDir.path}/lists');

    if (!_storageDir.existsSync()) {
      await _storageDir.create(recursive: true);

      // MIGRATION: Move old files from rootDir into lists/ subdirectory
      try {
        final oldFiles = rootDir.listSync().whereType<File>().where(
          (f) =>
              f.path.endsWith('.json') &&
              !f.path.endsWith('shared_preferences.json'),
        );
        for (final file in oldFiles) {
          final fileName = file.uri.pathSegments.last;
          await file.copy('${_storageDir.path}/$fileName');
          await file.delete();
        }
      } catch (e) {
        print('Migration error: $e');
      }
    }

    await _loadFromDisk();
    _initialized = true;

    // Seed dummy data if empty
    if (_lists.isEmpty) {
      final defaultList = ToDoList(id: 'default', name: 'Personal');
      await saveList(defaultList);
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final files = _storageDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.json'),
      );
      for (final file in files) {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        if (jsonMap.containsKey('id') && jsonMap['id'] != null) {
          final list = ToDoList.fromJson(jsonMap);
          _lists[list.id] = list;
        }
      }
    } catch (e) {
      print('Error loading lists from disk: $e');
    }
  }

  Future<void> _saveToDisk(ToDoList list) async {
    try {
      final file = File('${_storageDir.path}/${list.id}.json');
      final content = jsonEncode(list.toJson());
      await file.writeAsString(content);
    } catch (e) {
      print('Error saving list ${list.id} to disk: $e');
    }
  }

  @override
  Future<List<ToDoList>> getLists() async {
    await init();
    return _lists.values.toList();
  }

  @override
  Future<ToDoList?> getList(String listId) async {
    await init();
    return _lists[listId];
  }

  @override
  Future<void> saveList(ToDoList list) async {
    await init();
    _lists[list.id] = list;
    await _saveToDisk(list);
  }

  @override
  Future<void> deleteList(String listId) async {
    await init();
    _lists.remove(listId);
    final file = File('${_storageDir.path}/$listId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
