import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../data/settings_manager.dart';
import '../sync_log_page/sync_log_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsManager _settings = getIt<SettingsManager>();
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'User Experience',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Consolidated "Due" List'),
                subtitle: const Text(
                  'Show a dynamic virtual list consolidating all tasks due today or overdue.',
                ),
                value: _settings.showConsolidatedDueList,
                onChanged: (val) =>
                    _settings.updateSettings(showConsolidatedDueList: val),
              ),
              SwitchListTile(
                title: const Text('Quick List Selector'),
                subtitle: const Text(
                  'Pin a slidable bar at the bottom to quickly swap between active lists.',
                ),
                value: _settings.showQuickListSelector,
                onChanged: (val) =>
                    _settings.updateSettings(showQuickListSelector: val),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Synchronization',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Always Sync All'),
                subtitle: const Text(
                  'Sync all enabled lists concurrently when manually pulling down to refresh.',
                ),
                value: _settings.alwaysSyncAll,
                onChanged: (val) =>
                    _settings.updateSettings(alwaysSyncAll: val),
              ),
              SwitchListTile(
                title: const Text('Auto-Sync in Background'),
                subtitle: const Text(
                  'Periodically synchronize lists while the application is open.',
                ),
                value: _settings.autoSync,
                onChanged: (val) => _settings.updateSettings(autoSync: val),
              ),
              if (_settings.autoSync)
                ListTile(
                  title: const Text('Sync Frequency'),
                  subtitle: Text('Every ${_settings.syncFrequency} minutes'),
                  trailing: DropdownButton<int>(
                    value: _settings.syncFrequency,
                    items: [1, 3, 5, 10, 15, 30, 60].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value min'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _settings.updateSettings(syncFrequency: val);
                      }
                    },
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('View Sync Logs'),
                subtitle: const Text(
                  'Inspect background CalDAV interactions and network errors.',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SyncLogPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'Version $_version',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
