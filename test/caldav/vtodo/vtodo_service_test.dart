import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import '../../../lib/services/caldav/vtodo.dart';
import '../../../lib/services/caldav/vtodo_service.dart';

void main() {
  group('VTodoService Network Integration', () {
    late Dio dio;
    late VTodoService service;

    final calendarUri = Uri.parse('http://example.com/caldav/todos/');

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://example.com/caldav/todos/'));
      service = VTodoService(dio);
    });

    test('getTodos processes MultiStatus XML and parses VTODOs', () async {
      // Represents a standard CalDAV REPORT response carrying a VTODO child
      const mockXmlResponse = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns" xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/">
    <d:response>
        <d:href>/caldav/todos/test-uid-1.ics</d:href>
        <d:propstat>
            <d:prop>
                <d:getetag>"12345-abcde"</d:getetag>
                <cal:calendar-data>BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTODO
UID:test-uid-1
SUMMARY:Wash the car
STATUS:NEEDS-ACTION
PRIORITY:5
END:VTODO
END:VCALENDAR</cal:calendar-data>
            </d:prop>
            <d:status>HTTP/1.1 200 OK</d:status>
        </d:propstat>
    </d:response>
</d:multistatus>''';

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'REPORT') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 207,
                  data: mockXmlResponse,
                  headers: Headers.fromMap({
                    Headers.contentTypeHeader: [
                      'application/xml; charset=utf-8',
                    ],
                  }),
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final todos = await service.getTodos(calendarUri);

      expect(todos.length, 1);
      final todo = todos.first;

      expect(todo.uid, 'test-uid-1');
      expect(todo.summary, 'Wash the car');
      expect(todo.status, 'NEEDS-ACTION');
      expect(todo.priority, 5);
      expect(todo.etag, '"12345-abcde"');
      expect(todo.href?.path, '/caldav/todos/test-uid-1.ics');
    });
  });
}
