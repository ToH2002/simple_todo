import 'package:flutter/material.dart';
import '../../data/todo_models.dart';
import 'list_settings_page_logic.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

class ListSettingsPage extends StatefulWidget {
  final ToDoList currentList;

  const ListSettingsPage({Key? key, required this.currentList})
    : super(key: key);

  @override
  State<ListSettingsPage> createState() => _ListSettingsPageState();
}

class _ListSettingsPageState extends State<ListSettingsPage> {
  late ListSettingsPageLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = ListSettingsPageLogic();
    _logic.init(widget.currentList);
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
  }

  Future<void> _showColorPickerDialog() async {
    final Color newColor = await showColorPickerDialog(
      context,
      _logic.selectedColor,
      title: Text(
        'Select List Color',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      width: 40,
      height: 40,
      spacing: 5,
      runSpacing: 5,
      borderRadius: 4,
      wheelDiameter: 155,
      wheelWidth: 16,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      actionButtons: const ColorPickerActionButtons(
        okButton: true,
        closeButton: true,
        dialogActionButtons: false,
      ),
    );
    _logic.updateColor(newColor);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _logic,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: _logic.selectedColor,
            foregroundColor:
                ThemeData.estimateBrightnessForColor(_logic.selectedColor) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black,
            title: const Text('List Configuration'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  final saved = await _logic.saveChanges();
                  if (saved && mounted) {
                    Navigator.pop(context, true);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty')),
                    );
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'General Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _logic.nameController,
                  decoration: const InputDecoration(
                    labelText: 'List Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('List Theme Color'),
                  subtitle: const Text('Used for icons and Main Header'),
                  trailing: ColorIndicator(
                    width: 44,
                    height: 44,
                    borderRadius: 4,
                    color: _logic.selectedColor,
                    onSelectFocus: false,
                    onSelect: () => _showColorPickerDialog(),
                  ),
                  onTap: _showColorPickerDialog,
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CalDAV Synchronization',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: _logic.syncEnabled,
                      onChanged: _logic.toggleSync,
                      activeColor: _logic.selectedColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                IgnorePointer(
                  ignoring: !_logic.syncEnabled,
                  child: Opacity(
                    opacity: _logic.syncEnabled ? 1.0 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _logic.urlController,
                          decoration: const InputDecoration(
                            labelText:
                                'Server URL (ex: https://server.com/dav/)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _logic.userController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _logic.passController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _logic.isTestingConnection
                              ? null
                              : _logic.testConnection,
                          icon: _logic.isTestingConnection
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_check),
                          label: Text(
                            _logic.isTestingConnection
                                ? 'Testing...'
                                : 'Test Connection',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),

                        if (_logic.testConnectionMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _logic.testConnectionMessage,
                              style: TextStyle(
                                color:
                                    _logic.testConnectionMessage.contains(
                                          'failed',
                                        ) ||
                                        _logic.testConnectionMessage.contains(
                                          'Please',
                                        )
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                            ),
                          ),
                        if (_logic.discoveredCalendars.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Available Calendars:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _logic.discoveredCalendars.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final cal = _logic.discoveredCalendars[index];
                                return ListTile(
                                  title: Text(cal['name'] ?? 'Unnamed'),
                                  subtitle: Text(cal['id'] ?? ''),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () =>
                                      _logic.selectCalendar(cal['id']!),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
