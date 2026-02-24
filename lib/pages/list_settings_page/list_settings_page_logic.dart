import 'package:flutter/material.dart';
import '../../data/todo_models.dart';
import '../../services/service_locator.dart';
import '../../data/data_manager.dart';
import '../../services/caldav_service.dart';

class ListSettingsPageLogic extends ChangeNotifier {
  final DataManager _dataManager = getIt<DataManager>();
  late ToDoList list;

  // Form states
  late TextEditingController nameController;
  late Color selectedColor;
  late bool syncEnabled;
  late TextEditingController urlController;
  late TextEditingController userController;
  late TextEditingController passController;

  // CalDAV feedback
  String testConnectionMessage = '';
  bool isTestingConnection = false;
  List<Map<String, String>> discoveredCalendars = [];

  void init(ToDoList initialList) {
    list = initialList;
    nameController = TextEditingController(text: list.name);
    selectedColor = list.color;
    syncEnabled = list.syncEnabled;
    urlController = TextEditingController(text: list.calDavUrl ?? '');
    userController = TextEditingController(text: list.calDavUsername ?? '');
    passController = TextEditingController(text: list.calDavPassword ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  void updateColor(Color newColor) {
    selectedColor = newColor;
    notifyListeners();
  }

  void toggleSync(bool value) {
    syncEnabled = value;
    notifyListeners();
  }

  void selectCalendar(String href) {
    urlController.text = href;
    discoveredCalendars = [];
    testConnectionMessage =
        'Calendar selected. You can test the connection again to verify.';
    notifyListeners();
  }

  Future<bool> saveChanges() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return false;

    final newUrl = urlController.text.trim().isEmpty
        ? null
        : urlController.text.trim();
    final urlChanged = list.calDavUrl != newUrl;

    // Map form fields back to list object
    list = ToDoList(
      id: list.id,
      name: name,
      color: selectedColor,
      items: list.items, // Keep items attached
      tags: list.tags,
      syncEnabled: syncEnabled,
      // Treat empty fields as nulls to clean JSON data up
      calDavUrl: newUrl,
      calDavUsername: userController.text.trim().isEmpty
          ? null
          : userController.text.trim(),
      calDavPassword: passController.text.trim().isEmpty
          ? null
          : passController.text.trim(),
      calDavCalendarId: list.calDavCalendarId, // Preserved
      lastSync: urlChanged ? null : list.lastSync,
    );

    await _dataManager.saveList(list);
    return true; // Return success to trigger pop
  }

  Future<void> testConnection() async {
    // Basic validation before we even try
    final url = urlController.text.trim();
    final user = userController.text.trim();
    final pass = passController.text.trim();

    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      testConnectionMessage =
          'Please enter Server URL, Username, and Password to test.';
      notifyListeners();
      return;
    }

    isTestingConnection = true;
    testConnectionMessage = 'Testing connection...';
    discoveredCalendars = [];
    notifyListeners();

    try {
      final service = CalDavService();
      final result = await service.testConnection(
        url: url,
        username: user,
        password: pass,
      );

      if (result.success) {
        if (result.isRootUrl && result.discoveredCalendars.isNotEmpty) {
          testConnectionMessage =
              'Success! Found ${result.discoveredCalendars.length} calendars.\nChoose one below:';
          discoveredCalendars = result.discoveredCalendars;
        } else {
          testConnectionMessage =
              'Success! Verified direct calendar connection.';
        }
      } else {
        testConnectionMessage = result.message;
      }
    } catch (e) {
      testConnectionMessage = 'Connection failed: $e';
    } finally {
      isTestingConnection = false;
      notifyListeners();
    }
  }
}
