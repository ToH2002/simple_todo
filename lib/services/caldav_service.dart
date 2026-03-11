import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:caldav/caldav.dart';
import '../data/todo_models.dart';
import 'caldav/vtodo.dart';
import 'caldav/vtodo_service.dart';
import 'service_locator.dart';
import 'sync_logger.dart';

class CalDavConnectionResult {
  final bool success;
  final String message;
  final bool isRootUrl;
  final List<Map<String, String>>
  discoveredCalendars; // [{ 'id': url, 'name': display }]

  CalDavConnectionResult({
    required this.success,
    required this.message,
    this.isRootUrl = false,
    this.discoveredCalendars = const [],
  });
}

class CalDavService {
  /// Test the connection credentials and determine if the URL is a direct calendar or a root DAV folder.
  Future<CalDavConnectionResult> testConnection({
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final client = CalDavClient(
        baseUrl: url,
        username: username,
        password: password,
      );

      // 1. Initial connection probe
      // Try to fetch the specific URL as a direct calendar first.
      try {
        final calendarUri = Uri.parse(url);
        final directCalendar = await client.getCalendar(calendarUri);

        // Success! We confirmed it's a direct calendar link because it resolved to a valid Calendar object.
        return CalDavConnectionResult(
          success: true,
          message: 'Success! Verified direct calendar connection.',
          isRootUrl: false,
          discoveredCalendars: [
            {
              'id': directCalendar.href?.toString() ?? '',
              'name':
                  directCalendar.displayName?.toString() ?? 'Unnamed Calendar',
            },
          ],
        );
      } catch (e) {
        // 2. Fallback probe
        // It failed to resolve as a direct calendar collection. It might be a root/principal URL.
        try {
          final calendars = await client.getCalendars();

          if (calendars.isNotEmpty) {
            // Success! It's a root URL returning multiple valid calendars.
            return CalDavConnectionResult(
              success: true,
              message: 'Successfully connected to CalDAV root directory.',
              isRootUrl: true,
              discoveredCalendars: calendars
                  .map(
                    (c) => <String, String>{
                      'id': c.href?.toString() ?? '',
                      'name': c.displayName?.toString() ?? 'Unnamed Calendar',
                    },
                  )
                  .toList(),
            );
          } else {
            return CalDavConnectionResult(
              success: true,
              message:
                  'Connected, but no calendars were found at this address.',
              isRootUrl: true,
            );
          }
        } catch (innerE) {
          // Both probes failed.
          return CalDavConnectionResult(
            success: false,
            message:
                'Connection failed. URL is neither a valid Calendar nor a DAV Root: $innerE',
          );
        }
      }
    } catch (e) {
      return CalDavConnectionResult(
        success: false,
        message: 'Network error or invalid credentials: $e',
      );
    }
  }

  /// Performs a 2-way sync between a local `ToDoList` and the remote CalDAV server.
  /// Strategy:
  /// 1. Fetch all remote VTODOs.
  /// 2. Compare against local items by ID.
  /// 3. If remote is newer or local doesn't exist, update/create local.
  /// 4. If local is newer or remote doesn't exist, update/create remote.
  /// 5. Tag Syncing: The tags array of the `ToDoList` is stored in a hidden `_TagList` item.
  Future<ToDoList> syncList(ToDoList localList) async {
    if (!localList.syncEnabled || localList.calDavUrl == null) {
      return localList;
    }

    final logger = getIt<SyncLogger>();

    try {
      final client = CalDavClient(
        baseUrl: localList.calDavUrl!,
        username: localList.calDavUsername ?? '',
        password: localList.calDavPassword ?? '',
      );

      // WebDAV operates on the directory level for our custom query
      final calendarUri = Uri.parse(localList.calDavUrl!);

      // Instantiate our custom VTodo service utilizing the authenticated Dio client inside CalDavClient
      final vTodoService = VTodoService(client.dio);

      // 1. Pull remote state
      final remoteTodos = await vTodoService.getTodos(calendarUri);
      final remoteMap = {for (var t in remoteTodos) t.uid: t};

      // 2. Prepare local state
      final updatedLocalItems = <ToDoItem>[];

      // Start tracking the exact time this sync cycle began in UTC
      final currentSyncStart = DateTime.now().toUtc();
      final lastSync =
          (localList.lastSync ?? DateTime.fromMillisecondsSinceEpoch(0))
              .toUtc();

      await logger.logConnect(
        localList.calDavUrl!,
        localList.calDavUsername ?? 'anonymous',
      );

      // Track which remote items we've processed
      final processedRemoteIds = <String>{};

      // 3. Evaluate local items against remote
      for (final localItem in localList.items) {
        final remoteMatch = remoteMap[localItem.id];

        if (remoteMatch != null) {
          processedRemoteIds.add(remoteMatch.uid);
        }

        if (localItem.isDeleted) {
          if (remoteMatch != null) {
            try {
              if (remoteMatch.href != null) {
                await vTodoService.delete(remoteMatch);
                await logger.logUpdate(
                  'DELETE',
                  localItem.id,
                  localItem.title,
                  lastModified: localItem.lastModified,
                );
              }
            } catch (e) {
              await logger.logError('Sync Delete', e.toString());
              updatedLocalItems.add(
                localItem,
              ); // Keep it local to retry next time
            }
          }
          continue; // Item successfully deleted remotely (or never existed), so we drop it.
        }

        if (remoteMatch != null) {
          // Compare modification timestamps
          final localTime = localItem.lastModified.toUtc();
          final remoteTime = (remoteMatch.lastModified ?? remoteMatch.dtstamp)
              .toUtc();

          final localChanged = localTime.isAfter(lastSync);
          final remoteChanged = remoteTime.isAfter(lastSync);

          if (!localChanged && remoteChanged) {
            // Remote wins
            updatedLocalItems.add(
              remoteMatch.toLocalItem(formatListId: localList.id),
            );
          } else if (localChanged && !remoteChanged) {
            // Local wins
            try {
              final updatedVTodo = VTodo.fromToDoItem(localItem);
              await vTodoService.update(
                VTodo.fromIcalendar(
                  updatedVTodo.toIcalendar(),
                  href: remoteMatch.href,
                  etag: remoteMatch.etag,
                ),
              );
              await logger.logUpdate(
                'UPDATE',
                localItem.id,
                localItem.title,
                lastModified: localItem.lastModified,
              );
            } catch (e) {
              await logger.logError('Sync Update', e.toString());
            }
            updatedLocalItems.add(localItem);
          } else if (!localChanged && !remoteChanged) {
            // Unchanged on both sides
            updatedLocalItems.add(localItem);
          } else {
            // Collision (localChanged && remoteChanged)
            final proposedLocalItem = remoteMatch.toLocalItem(
              formatListId: localList.id,
            );

            // Compare critical fields deeply to avoid superfluous conflict spam
            bool isIdentical =
                localItem.title == proposedLocalItem.title &&
                localItem.description == proposedLocalItem.description &&
                localItem.isDone == proposedLocalItem.isDone &&
                localItem.priority == proposedLocalItem.priority &&
                localItem.dueDateTime == proposedLocalItem.dueDateTime &&
                localItem.startDateTime == proposedLocalItem.startDateTime;

            if (isIdentical) {
              final localTags = List.from(localItem.tags)..sort();
              final remoteTags = List.from(proposedLocalItem.tags)..sort();
              isIdentical = localTags.join(',') == remoteTags.join(',');
            }

            if (isIdentical) {
              // Content perfectly identical despite both having independent un-synced edits.
              updatedLocalItems.add(localItem);
            } else {
              // True Conflict Detected!
              // Strategy: Rename local item as a [CONFLICT] clone, adopt remote item as primary.
              final conflictItem = ToDoItem(
                id: const Uuid().v4(),
                listId: localItem.listId,
                title: '[CONFLICT] ${localItem.title}',
                description: localItem.description,
                isDone: localItem.isDone,
                priority: localItem.priority,
                tags: localItem.tags,
                createDateTime: DateTime.now(),
                lastModified: DateTime.now(),
                startDateTime: localItem.startDateTime,
                dueDateTime: localItem.dueDateTime,
                recurringRule: localItem.recurringRule,
              );

              updatedLocalItems.add(proposedLocalItem);
              updatedLocalItems.add(conflictItem);

              // Immediately upload the new conflict item to the server to pair it
              try {
                await vTodoService.create(
                  calendarUri,
                  VTodo.fromToDoItem(conflictItem),
                );
                await logger.logUpdate(
                  'CONFLICT DUPLICATE',
                  conflictItem.id,
                  conflictItem.title,
                  lastModified: conflictItem.lastModified,
                );
              } catch (e) {
                await logger.logError('Push Conflict', e.toString());
              }
            }
          }
        } else {
          // Local exists, remote does not.
          final localTime = localItem.lastModified.toUtc();
          // If local item has NOT been modified since last sync, it means it previously
          // existed on remote (we synced it), but now it's missing from remote -> deleted remotely!
          if (localTime.isAfter(lastSync)) {
            // Local item was created or modified recently. Push to remote.
            final newVTodo = VTodo.fromToDoItem(localItem);
            try {
              await vTodoService.create(calendarUri, newVTodo);
              await logger.logUpdate(
                'CREATE',
                localItem.id,
                localItem.title,
                lastModified: localItem.lastModified,
              );
              updatedLocalItems.add(localItem); // Keep local
            } catch (e) {
              await logger.logError('Sync Create', e.toString());
              updatedLocalItems.add(localItem);
            }
          } else {
            // Item deleted on server. Drop locally by NOT adding it to updatedLocalItems.
            await logger.logUpdate(
              'REMOTE DROPPED',
              localItem.id,
              localItem.title,
              lastModified: localItem.lastModified,
            );
          }
        }
      }

      // 4. Evaluate remaining remote items (These exist on server but not locally -> Pull them down)
      for (final remoteItem in remoteTodos) {
        if (!processedRemoteIds.contains(remoteItem.uid)) {
          // Skip legacy Master Tag List items
          if (remoteItem.uid == '\$MASTER_TAG_LIST\$') {
            continue;
          }

          final newLocalItem = remoteItem.toLocalItem(
            formatListId: localList.id,
          );
          await logger.logUpdate(
            'PULL DOWN',
            newLocalItem.id,
            newLocalItem.title,
            lastModified: newLocalItem.lastModified,
          );
          updatedLocalItems.add(newLocalItem);
        }
      }

      await logger.logInfo('Sync Complete for ${localList.name}');

      // Return the updated list object (Does not automatically save to JSON, the UI controller handled that)
      return ToDoList(
        id: localList.id,
        name: localList.name,
        color: localList.color,
        items: updatedLocalItems,
        tags: localList.tags,
        syncEnabled: localList.syncEnabled,
        calDavUrl: localList.calDavUrl,
        calDavUsername: localList.calDavUsername,
        calDavPassword: localList.calDavPassword,
        calDavCalendarId: localList.calDavCalendarId,
        lastSync: currentSyncStart,
      );
    } catch (e) {
      try {
        await getIt<SyncLogger>().logError('Sync Failure', e.toString());
      } catch (_) {}
      // On hard failure, return the unmodified local list to prevent data loss.
      return localList;
    }
  }
}
