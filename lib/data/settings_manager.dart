import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  bool showConsolidatedDueList = true;
  bool showQuickListSelector = true;
  bool alwaysSyncAll = false;
  bool autoSync = false;
  int syncFrequency = 3; // in minutes

  SettingsManager() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    showConsolidatedDueList = prefs.getBool('settings_showDueList') ?? true;
    showQuickListSelector = prefs.getBool('settings_showQuickSelector') ?? true;
    alwaysSyncAll = prefs.getBool('settings_alwaysSyncAll') ?? false;
    autoSync = prefs.getBool('settings_autoSync') ?? false;
    syncFrequency = prefs.getInt('settings_syncFrequency') ?? 3;

    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('settings_showDueList', showConsolidatedDueList);
    await prefs.setBool('settings_showQuickSelector', showQuickListSelector);
    await prefs.setBool('settings_alwaysSyncAll', alwaysSyncAll);
    await prefs.setBool('settings_autoSync', autoSync);
    await prefs.setInt('settings_syncFrequency', syncFrequency);

    notifyListeners();
  }

  void updateSettings({
    bool? showConsolidatedDueList,
    bool? showQuickListSelector,
    bool? alwaysSyncAll,
    bool? autoSync,
    int? syncFrequency,
  }) {
    if (showConsolidatedDueList != null)
      this.showConsolidatedDueList = showConsolidatedDueList;
    if (showQuickListSelector != null)
      this.showQuickListSelector = showQuickListSelector;
    if (alwaysSyncAll != null) this.alwaysSyncAll = alwaysSyncAll;
    if (autoSync != null) this.autoSync = autoSync;
    if (syncFrequency != null) this.syncFrequency = syncFrequency;

    saveSettings();
  }
}
