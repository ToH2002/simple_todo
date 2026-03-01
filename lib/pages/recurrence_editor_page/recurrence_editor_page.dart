import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'recurrence_editor_page_logic.dart';

class RecurrenceEditorPage extends StatefulWidget {
  final String? initialRule;
  final DateTime dueDate;

  const RecurrenceEditorPage({
    Key? key,
    this.initialRule,
    required this.dueDate,
  }) : super(key: key);

  @override
  State<RecurrenceEditorPage> createState() => _RecurrenceEditorPageState();
}

class _RecurrenceEditorPageState extends State<RecurrenceEditorPage> {
  late RecurrenceEditorPageManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = RecurrenceEditorPageManager(
      initialRule: widget.initialRule,
      dueDate: widget.dueDate,
    );
    _manager.addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    _manager.dispose();
    super.dispose();
  }

  void _onManagerUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                'rule': _manager.compileRule(),
                'dueDate': _manager.dueDate,
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDueDateRow(),
            const SizedBox(height: 24),
            _buildRepeatPatternSection(),
            const SizedBox(height: 24),
            _buildRepeatEveryRow(),
            if (_manager.frequency == RecurrenceFrequency.weekly) ...[
              const SizedBox(height: 24),
              _buildWeeklyDaysRow(),
            ],
            if (_manager.frequency == RecurrenceFrequency.monthly) ...[
              const SizedBox(height: 24),
              _buildMonthlyOptions(),
            ],
            if (_manager.frequency != RecurrenceFrequency.none) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildNextRepeatFromSection(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildEndsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateRow() {
    return Row(
      children: [
        const SizedBox(
          width: 140, // Increased width to fit label
          child: Text('Next Due Date:', style: TextStyle(fontSize: 16)),
        ),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _manager.dueDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              _manager.setDueDate(date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              DateFormat('MMM d, yyyy').format(_manager.dueDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepeatPatternSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repeat pattern:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<RecurrenceFrequency>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(padding: EdgeInsets.zero),
            segments: const [
              ButtonSegment(
                value: RecurrenceFrequency.none,
                label: Text('None'),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.daily,
                label: Text('Daily'),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.weekly,
                label: Text('Weekly'),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.monthly,
                label: Text('Monthly'),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.yearly,
                label: Text('Yearly'),
              ),
            ],
            selected: {_manager.frequency},
            onSelectionChanged: (Set<RecurrenceFrequency> newSelection) {
              _manager.setFrequency(newSelection.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRepeatEveryRow() {
    String unit = '';
    switch (_manager.frequency) {
      case RecurrenceFrequency.none:
      case RecurrenceFrequency.daily:
        unit = 'day(s)';
        break;
      case RecurrenceFrequency.weekly:
        unit = 'week(s)';
        break;
      case RecurrenceFrequency.monthly:
        unit = 'month(s)';
        break;
      case RecurrenceFrequency.yearly:
        unit = 'year(s)';
        break;
    }

    return Row(
      children: [
        const Text('Repeat every ', style: TextStyle(fontSize: 16)),
        SizedBox(
          width: 60,
          child: TextFormField(
            initialValue: _manager.interval.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null && parsed > 0) {
                _manager.setInterval(parsed);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(unit, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildWeeklyDaysRow() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repeat on', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final isSelected = _manager.weeklyDays.contains(index + 1);
            return GestureDetector(
              onTap: () {
                _manager.toggleWeeklyDay(index + 1);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  days[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMonthlyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repeat on', style: TextStyle(fontSize: 14)),
        RadioListTile<MonthlyType>(
          title: Text('Day ${_manager.dueDate.day}'),
          value: MonthlyType.dayOfMonth,
          groupValue: _manager.monthlyType,
          onChanged: (val) => _manager.setMonthlyType(val!),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<MonthlyType>(
          title: Text(_manager.getNthWeekdayString()),
          value: MonthlyType.nthWeekday,
          groupValue: _manager.monthlyType,
          onChanged: (val) => _manager.setMonthlyType(val!),
          contentPadding: EdgeInsets.zero,
        ),
        if (_manager.isLastWeekOfMonth())
          RadioListTile<MonthlyType>(
            title: Text('Last ${_manager.getWeekdayString()}'),
            value: MonthlyType.lastWeekday,
            groupValue: _manager.monthlyType,
            onChanged: (val) => _manager.setMonthlyType(val!),
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildNextRepeatFromSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 140,
          child: Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('Next Repeat from', style: TextStyle(fontSize: 16)),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Due Date'),
                value: false,
                groupValue: _manager.repeatFromDoneDate,
                onChanged: (val) => _manager.setRepeatFromDoneDate(val!),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile<bool>(
                title: const Text('Done Date'),
                value: true,
                groupValue: _manager.repeatFromDoneDate,
                onChanged: (val) => _manager.setRepeatFromDoneDate(val!),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 80,
          child: Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('Ends', style: TextStyle(fontSize: 16)),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              RadioListTile<EndType>(
                title: const Text('Never'),
                value: EndType.never,
                groupValue: _manager.endType,
                onChanged: (val) => _manager.setEndType(val!),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile<EndType>(
                title: Row(
                  children: [
                    const Text('After '),
                    InkWell(
                      onTap: () async {
                        _manager.setEndType(EndType.untilDate);
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _manager.untilDate ??
                              DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          _manager.setUntilDate(date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _manager.untilDate != null
                              ? DateFormat(
                                  'MMM d, yyyy',
                                ).format(_manager.untilDate!)
                              : DateFormat(
                                  'MMM d, yyyy',
                                ).format(DateTime.now()),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                value: EndType.untilDate,
                groupValue: _manager.endType,
                onChanged: (val) => _manager.setEndType(val!),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile<EndType>(
                title: Row(
                  children: [
                    const Text('After '),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        initialValue: _manager.repetitionCount.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () {
                          _manager.setEndType(EndType.count);
                        },
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            _manager.setRepetitionCount(parsed);
                          }
                        },
                      ),
                    ),
                    const Text(' Repetition(s)'),
                  ],
                ),
                value: EndType.count,
                groupValue: _manager.endType,
                onChanged: (val) => _manager.setEndType(val!),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
