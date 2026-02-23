import 'package:flutter/material.dart';
import '../../data/todo_models.dart';
import '../todo_editor_page/todo_editor_page.dart';
import '../list_manager_page/list_manager_page.dart';
import 'todo_list_page_logic.dart';
import 'package:intl/intl.dart';

class TodoListPage extends StatefulWidget {
  const TodoListPage({Key? key}) : super(key: key);

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  late TodoListPageManager _manager;
  final FocusNode _dropdownFocusNode = FocusNode();
  Offset _tapPosition = Offset.zero;
  final loadButtonKey = GlobalKey();

  void _showContextMenu(BuildContext context, ToDoItem item, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        _manager.deleteItem(item);
      }
    });
  }

  void _showTagEditorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TagEditorDialog(manager: _manager),
    );
  }

  @override
  void initState() {
    super.initState();
    _manager = TodoListPageManager();
  }

  @override
  void dispose() {
    _dropdownFocusNode.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        if (_manager.currentList == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: _manager.currentList!.color,
            foregroundColor:
                ThemeData.estimateBrightnessForColor(
                      _manager.currentList!.color,
                    ) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black,
            title: Text(_manager.currentList!.name),
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings),
                onSelected: (value) async {
                  if (value == 'toggle_completed') {
                    _manager.toggleShowCompletedItems();
                  } else if (value == 'delete_completed') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Completed Items?'),
                        content: const Text(
                          'Are you sure you want to delete all completed items from this list? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      _manager.deleteCompletedItems();
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'toggle_completed',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Show Completed Items'),
                        if (_manager.showCompletedItems)
                          Icon(
                            Icons.check,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete_completed',
                    child: Text(
                      'Delete Completed Items',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: _manager.currentList!.color),
                  child: Text(
                    'Simple ToDo',
                    style: TextStyle(
                      color:
                          ThemeData.estimateBrightnessForColor(
                                _manager.currentList!.color,
                              ) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 24,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'My Lists',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ..._manager.allLists.map((list) {
                  return ListTile(
                    leading: Icon(Icons.list, color: list.color),
                    title: Text(list.name),
                    selected: _manager.currentList?.id == list.id,
                    selectedTileColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    onTap: () {
                      _manager.switchList(list.id);
                      Navigator.pop(context); // Close drawer
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Manage Lists'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ListManagerPage(),
                      ),
                    ).then((shouldRefresh) {
                      if (shouldRefresh == true) {
                        _manager.loadLists();
                      }
                    });
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.label),
                  title: const Text('Tag Editor'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _showTagEditorDialog(context);
                  },
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionHeader('Overdue', 'Overdue'),
                    _buildSectionHeader('Due', 'Due Today'),
                    _buildSectionHeader('Tomorrow', 'Tomorrow'),
                    _buildSectionHeader('Further Out', 'Further Out'),
                    _buildSectionHeader('No Due Date', 'No Due Date'),
                    _buildSectionHeader('Completed', 'Completed'),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TodoEditorPage(listId: _manager.currentList!.id),
                ),
              ).then((_) async {
                await _manager.loadLists();
                _manager.setFilter(_manager.currentFilter);
              });
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final tags = List<String>.from(_manager.currentList?.tags ?? [])
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Create the dropdown items
    final dropdownItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'All',
        child: Text(
          'All Categories',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ];
    dropdownItems.addAll(
      tags.map(
        (tag) => DropdownMenuItem(
          value: tag,
          child: Text(tag, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildChip('Current', 'current'),
                  const SizedBox(width: 8),
                  _buildChip('Due', 'due'),
                  const SizedBox(width: 8),
                  _buildChip('Radar', 'radar'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: loadButtonKey,
            onPressed: _onCategoriesButton,
            icon: _manager.currentTagFilter == 'All'
                ? Icon(Icons.filter_alt_off)
                : Icon(Icons.filter_alt, color: Colors.red),
          ),
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 4),
          //   decoration: BoxDecoration(
          //     border: Border.all(color: Colors.grey.shade300),
          //     borderRadius: BorderRadius.circular(8),
          //   ),
          //   child: DropdownButtonHideUnderline(
          //     child: DropdownButton<String>(
          //       focusNode: _dropdownFocusNode,
          //       value: _manager.currentTagFilter,
          //       items: dropdownItems,
          //       onChanged: (value) {
          //         if (value != null) {
          //           _manager.setTagFilter(value);
          //           _dropdownFocusNode.unfocus();
          //         }
          //       },
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  void _onCategoriesButton() async {
    final tags = List<String>.from(_manager.currentList?.tags ?? [])
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Create the dropdown items

    final popupMenuItems = <PopupMenuItem<String>>[
      PopupMenuItem(value: 'All', child: Text('All Categories')),
    ];

    popupMenuItems.addAll(
      tags.map((tag) => PopupMenuItem(value: tag, child: Text(tag))),
    );

    final buttonBox =
        loadButtonKey.currentContext?.findRenderObject() as RenderBox;

    final popupStart = buttonBox.localToGlobal(Offset.zero);

    var res = await showMenu<String>(
      context: context,
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 50),
      ),
      position: RelativeRect.fromLTRB(
        popupStart.dx,
        popupStart.dy + buttonBox.size.height,
        popupStart.dx + 50,
        popupStart.dy + 200,
      ),
      items: popupMenuItems,
    );
    if (res != null) {
      _manager.setTagFilter(res);
    }
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _manager.currentFilter == value;
    return FilterChip(
      label: Text(
        label,
        overflow: TextOverflow.visible,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        _manager.setFilter(value);
      },
      showCheckmark: false,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
    );
  }

  Widget _buildSectionHeader(String sectionKey, String title) {
    final items = _manager.getFilteredItems(sectionKey);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.grey[200],
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        ...items.map((item) => _buildTodoItem(item)),
      ],
    );
  }

  Widget _buildTodoItem(ToDoItem item) {
    Color getPriorityColor(Priority priority) {
      switch (priority) {
        case Priority.high:
          return Colors.red;
        case Priority.normal:
          return Colors.amber;
        case Priority.low:
          return Colors.blue;
        case Priority.none:
          return Colors.grey;
      }
    }

    final priorityColor = getPriorityColor(item.priority);

    return Listener(
      onPointerDown: (event) => _tapPosition = event.position,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showContextMenu(context, item, details.globalPosition);
        },
        onLongPress: () {
          _showContextMenu(context, item, _tapPosition);
        },
        child: ListTile(
          leading: Checkbox(
            value: item.isDone,
            activeColor: priorityColor,
            side: BorderSide(color: priorityColor, width: 2.0),
            onChanged: (bool? value) {
              _manager.toggleItemDone(item, value);
            },
          ),
          title: Text(
            item.title,
            style: TextStyle(
              decoration: item.isDone ? TextDecoration.lineThrough : null,
              color: item.isDone ? Colors.grey : Colors.black,
            ),
          ),
          subtitle: item.tags.isNotEmpty
              ? Row(
                  children:
                      (List<String>.from(item.tags)..sort(
                            (a, b) =>
                                a.toLowerCase().compareTo(b.toLowerCase()),
                          ))
                          .map(
                            (tag) => Padding(
                              padding: const EdgeInsets.only(
                                right: 4.0,
                                top: 4.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                )
              : null,
          trailing: item.dueDateTime != null
              ? _buildSmartDateText(item.dueDateTime!, item.isDone)
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TodoEditorPage(
                  item: item,
                  listId: _manager.currentList!.id,
                ),
              ),
            ).then((_) async {
              await _manager.loadLists();
              _manager.setFilter(_manager.currentFilter);
            });
          },
        ),
      ),
    );
  }

  Widget _buildSmartDateText(DateTime date, bool isDone) {
    if (isDone) {
      return Text(
        DateFormat('MMM d').format(date),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    final difference = targetDate.difference(today).inDays;

    String text;
    Color color;

    if (difference < 0) {
      text = difference == -1 ? 'Yesterday' : DateFormat('MMM d').format(date);
      color = Colors.red[800]!;
    } else if (difference == 0) {
      text = 'Today';
      color = Colors.amber[800]!;
    } else if (difference == 1) {
      text = 'Tomorrow';
      color = Colors.blue[800]!;
    } else {
      text = DateFormat('MMM d').format(date);
      color = Colors.blue[800]!;
    }

    return Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
    );
  }
}

class _TagEditorDialog extends StatefulWidget {
  final TodoListPageManager manager;

  const _TagEditorDialog({required this.manager});

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  final TextEditingController _addController = TextEditingController();
  String? _editingTag;
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _addController.text.trim();
    if (text.isNotEmpty && !widget.manager.currentList!.tags.contains(text)) {
      widget.manager.addListTag(text);
      _addController.clear();
      setState(() {});
    }
  }

  void _saveEdit(String oldTag) {
    final text = _editController.text.trim();
    if (text.isNotEmpty && text != oldTag) {
      widget.manager.updateListTag(oldTag, text);
    }
    setState(() {
      _editingTag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tags = List<String>.from(widget.manager.currentList?.tags ?? [])
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return AlertDialog(
      title: const Text('Tag Editor'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      labelText: 'New Tag Name',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addTag),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  if (_editingTag == tag) {
                    return ListTile(
                      title: TextField(
                        controller: _editController,
                        decoration: const InputDecoration(isDense: true),
                        autofocus: true,
                        onSubmitted: (_) => _saveEdit(tag),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _saveEdit(tag),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _editingTag = null;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return ListTile(
                    title: Text(tag),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            setState(() {
                              _editingTag = tag;
                              _editController.text = tag;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Tag?'),
                                content: Text('Remove "$tag" from all items?'),
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
                              widget.manager.deleteListTag(tag);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Re-load list to reflect potentially updated tag names in the main list view.
            widget.manager.loadLists();
            widget.manager.setFilter(widget.manager.currentFilter);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
