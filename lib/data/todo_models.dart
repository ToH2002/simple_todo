import 'package:flutter/material.dart';

enum Priority { low, normal, high, none }

class ToDoItem {
  final String id;
  final String listId; // Link to its parent list
  final String title;
  final String description;
  bool isDone;
  final Priority priority;
  final List<String> tags;
  final DateTime createDateTime;
  final DateTime? startDateTime;
  final DateTime? dueDateTime;
  final String? recurringRule;

  ToDoItem({
    required this.id,
    required this.listId,
    required this.title,
    this.description = '',
    this.isDone = false,
    this.priority = Priority.none,
    this.tags = const [],
    required this.createDateTime,
    this.startDateTime,
    this.dueDateTime,
    this.recurringRule,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'title': title,
      'description': description,
      'isDone': isDone,
      'priority': priority.index,
      'tags': tags,
      'createDateTime': createDateTime.toIso8601String(),
      'startDateTime': startDateTime?.toIso8601String(),
      'dueDateTime': dueDateTime?.toIso8601String(),
      'recurringRule': recurringRule,
    };
  }

  factory ToDoItem.fromJson(Map<String, dynamic> json) {
    return ToDoItem(
      id: json['id'],
      listId: json['listId'] ?? 'default',
      title: json['title'],
      description: json['description'] ?? '',
      isDone: json['isDone'] ?? false,
      priority: Priority.values.elementAt(
        json['priority'] ?? Priority.none.index,
      ),
      tags: List<String>.from(json['tags'] ?? []),
      createDateTime: DateTime.parse(json['createDateTime']),
      startDateTime: json['startDateTime'] != null
          ? DateTime.parse(json['startDateTime'])
          : null,
      dueDateTime: json['dueDateTime'] != null
          ? DateTime.parse(json['dueDateTime'])
          : null,
      recurringRule: json['recurringRule'],
    );
  }
}

class ToDoList {
  final String id;
  final String name;
  final Color color;
  final List<ToDoItem>
  items; // Hold the items here for a self-contained file payload
  final List<String> tags; // Available tags for this list

  // Phase 3: CalDAV Metadata
  bool syncEnabled;
  String? calDavUrl;
  String? calDavUsername;
  String? calDavPassword;
  String? calDavCalendarId;

  ToDoList({
    required this.id,
    required this.name,
    this.color = Colors.blue,
    List<ToDoItem>? items,
    List<String>? tags,
    this.syncEnabled = false,
    this.calDavUrl,
    this.calDavUsername,
    this.calDavPassword,
    this.calDavCalendarId,
  }) : items = items ?? [],
       tags = tags ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'items': items.map((e) => e.toJson()).toList(),
      'tags': tags,
      'syncEnabled': syncEnabled,
      'calDavUrl': calDavUrl,
      'calDavUsername': calDavUsername,
      'calDavPassword': calDavPassword,
      'calDavCalendarId': calDavCalendarId,
    };
  }

  factory ToDoList.fromJson(Map<String, dynamic> json) {
    return ToDoList(
      id: json['id'],
      name: json['name'],
      color: Color(json['color'] ?? Colors.blue.value),
      items: json['items'] != null
          ? (json['items'] as List).map((i) => ToDoItem.fromJson(i)).toList()
          : [],
      tags: List<String>.from(json['tags'] ?? []),
      syncEnabled: json['syncEnabled'] ?? false,
      calDavUrl: json['calDavUrl'],
      calDavUsername: json['calDavUsername'],
      calDavPassword: json['calDavPassword'],
      calDavCalendarId: json['calDavCalendarId'],
    );
  }
}
