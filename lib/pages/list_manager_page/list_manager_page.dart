import 'package:flutter/material.dart';
import '../list_settings_page/list_settings_page.dart';
import 'list_manager_page_logic.dart';

class ListManagerPage extends StatefulWidget {
  const ListManagerPage({Key? key}) : super(key: key);

  @override
  State<ListManagerPage> createState() => _ListManagerPageState();
}

class _ListManagerPageState extends State<ListManagerPage> {
  late ListManagerPageLogic _manager;

  @override
  void initState() {
    super.initState();
    _manager = ListManagerPageLogic();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New ToDo List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'List Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _manager.createList(controller.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Lists'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(
                context,
                true,
              ), // Returning true instructs previous page to refresh
            ),
          ),
          body: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _manager.lists.length,
            onReorder: _manager.reorderLists,
            itemBuilder: (context, index) {
              final list = _manager.lists[index];
              return ListTile(
                key: ValueKey(list.id),
                leading: Icon(Icons.list_alt, color: list.color),
                title: Text(list.name),
                subtitle: Text(
                  list.calDavUrl != null && list.calDavUrl!.isNotEmpty
                      ? (list.syncEnabled
                            ? 'CalDav (sync)'
                            : 'CalDav (sync off)')
                      : 'Local Only',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ListSettingsPage(currentList: list),
                    ),
                  ).then((_) => _manager.loadLists());
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ListSettingsPage(currentList: list),
                          ),
                        ).then((_) => _manager.loadLists());
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _manager.lists.length > 1
                          ? () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete List?'),
                                  content: Text(
                                    'Are you sure you want to permanently delete "\${list.name}" and all its ToDo items?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                _manager.deleteList(list.id);
                              }
                            }
                          : null, // Disable delete if it's the last list
                    ),
                    const SizedBox(width: 8),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateDialog,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
