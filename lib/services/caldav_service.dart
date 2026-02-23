import 'package:caldav/caldav.dart';

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
}
