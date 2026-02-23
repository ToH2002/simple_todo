import 'package:flutter/material.dart';
import '../../data/todo_models.dart';
import 'todo_editor_page_logic.dart';
import 'package:intl/intl.dart';
import '../../services/service_locator.dart';
import '../../data/data_manager.dart';

class TodoEditorPage extends StatefulWidget {
  final ToDoItem? item;
  final String listId;

  const TodoEditorPage({Key? key, this.item, required this.listId})
    : super(key: key);

  @override
  State<TodoEditorPage> createState() => _TodoEditorPageState();
}

class _TodoEditorPageState extends State<TodoEditorPage> {
  late TodoEditorPageManager _manager;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _manager = TodoEditorPageManager(
      initialItem: widget.item,
      listId: widget.listId,
    );
    _titleController = TextEditingController(text: _manager.title);
    _descriptionController = TextEditingController(text: _manager.description);

    _titleController.addListener(() {
      _manager.updateTitle(_titleController.text);
    });
    _descriptionController.addListener(() {
      _manager.updateDescription(_descriptionController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _manager.dispose();
    super.dispose();
  }

  Future<void> _showNewTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tag name'),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (tag != null && tag.trim().isNotEmpty) {
      _manager.addNewTagToList(tag);
    }
  }

  Future<void> _saveAndExit() async {
    if (!_manager.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final newItem = _manager.compileItem();
    final dataManager = getIt<DataManager>();
    final list = await dataManager.getList(widget.listId);
    if (list != null) {
      // Find and update or add new
      final idx = list.items.indexWhere((i) => i.id == newItem.id);
      if (idx != -1) {
        list.items[idx] = newItem;
      } else {
        list.items.add(newItem);
      }
      await dataManager.saveList(list);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Edit Item'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _manager.isValid ? _saveAndExit : null,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Priority',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<Priority>(
                  segments: [
                    ButtonSegment(
                      value: Priority.none,
                      label: Text(
                        'None',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    ButtonSegment(
                      value: Priority.low,
                      label: Text(
                        'Low',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    ButtonSegment(
                      value: Priority.normal,
                      label: Text(
                        'Normal',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    ButtonSegment(
                      value: Priority.high,
                      label: Text(
                        'High',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                  selected: {_manager.priority},
                  onSelectionChanged: (Set<Priority> newSelection) {
                    _manager.setPriority(newSelection.first);
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Dates',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDateSelectorRow(
                  context: context,
                  icon: Icons.play_arrow_outlined,
                  title: 'Start Date',
                  currentDate: _manager.startDate,
                  onDateChanged: _manager.setStartDate,
                ),
                const SizedBox(height: 12),
                _buildDateSelectorRow(
                  context: context,
                  icon: Icons.event,
                  title: 'Due Date',
                  currentDate: _manager.dueDate,
                  onDateChanged: _manager.setDueDate,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tags',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: <Widget>[
                    ...(_manager.availableTags.map(
                      (tag) => FilterChip(
                        label: Text(tag),
                        selected: _manager.tags.contains(tag),
                        onSelected: (selected) {
                          if (selected) {
                            _manager.addTag(tag);
                          } else {
                            _manager.removeTag(tag);
                          }
                        },
                      ),
                    )),
                    ActionChip(
                      label: const Text('+ New Tag'),
                      onPressed: () {
                        _showNewTagDialog(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSelectorRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required DateTime? currentDate,
    required Function(DateTime?) onDateChanged,
  }) {
    // Quick calculate dates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // End of week (Friday)
    int daysToFriday = DateTime.friday - today.weekday;
    if (daysToFriday < 0)
      daysToFriday += 7; // Next Friday if we are on Saturday
    if (daysToFriday == 0 && today.weekday == DateTime.friday)
      daysToFriday = 7; // Next Friday if today is Friday
    final endOfWeek = today.add(Duration(days: daysToFriday));

    // Next week (Monday)
    int daysToMonday = DateTime.monday - today.weekday;
    if (daysToMonday <= 0) daysToMonday += 7;
    final nextWeek = today.add(Duration(days: daysToMonday));

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: currentDate ?? today,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) onDateChanged(date);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[700]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  if (currentDate != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Text(
                            DateFormat('MMM d').format(currentDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => onDateChanged(null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Quick action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Today',
                  icon: const Icon(Icons.today, size: 20),
                  onPressed: () => onDateChanged(today),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 20,
                  color: Colors.amber[700],
                ),
                IconButton(
                  tooltip: 'Tomorrow',
                  icon: const Icon(Icons.wb_sunny_outlined, size: 20),
                  onPressed: () => onDateChanged(tomorrow),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 20,
                  color: Colors.blue[600],
                ),
                IconButton(
                  tooltip: 'End of Week (Fri)',
                  icon: const Icon(Icons.weekend_outlined, size: 20),
                  onPressed: () => onDateChanged(endOfWeek),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 20,
                  color: Colors.purple[400],
                ),
                IconButton(
                  tooltip: 'Next Week (Mon)',
                  icon: const Icon(Icons.next_week_outlined, size: 20),
                  onPressed: () => onDateChanged(nextWeek),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 20,
                  color: Colors.grey[700],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
