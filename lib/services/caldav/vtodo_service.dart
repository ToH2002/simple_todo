import 'package:dio/dio.dart';
import 'package:caldav/caldav.dart'
    show
        Calendar,
        CalDavException,
        ConflictException,
        NotFoundException,
        AuthenticationException,
        ForbiddenException;
import 'vtodo.dart';
// Note: We need the raw DioWebDavClient. Since the package obscures it, we must import it dynamically or instantiate it.
// The `caldav` package internally uses its own DioWebDavClient, but exposed the raw Dio client via `CalDavClient.dio`.
import 'package:xml/xml.dart'; // We'll manually parse the MultiStatus XML

/// A custom service to handle VTODO entities since the standard `caldav` package
/// only supports VEVENT handling out-of-the-box.
class VTodoService {
  final Dio _dio;

  VTodoService(this._dio);

  /// Fetch all VTODO entries within a specific calendar directory
  Future<List<VTodo>> getTodos(Uri calendarHref) async {
    final body = _buildVTodoQuery();

    try {
      final response = await _dio.request(
        calendarHref.toString(),
        options: Options(
          method: 'REPORT',
          headers: {
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
        ),
        data: body,
      );

      return _parseMultiStatusXml(response.data, calendarHref);
    } on DioException catch (e) {
      throw _mapException(e, 'Failed to fetch VTODOs');
    }
  }

  /// Create a new VTODO entry
  Future<VTodo> create(Uri calendarHref, VTodo todo) async {
    final eventPath = calendarHref.resolve('${todo.uid}.ics');

    try {
      final response = await _dio.put(
        eventPath.toString(),
        data: todo.toIcalendar(),
        options: Options(
          headers: {
            'If-None-Match': '*', // Only create if not exists
            'Content-Type': 'text/calendar; charset=utf-8',
          },
        ),
      );

      final etag = response.headers.value('etag');
      return VTodo.fromIcalendar(
        todo.toIcalendar(),
        href: eventPath,
        etag: etag,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 412)
        throw const ConflictException('VTODO already exists');
      throw _mapException(e, 'Failed to create VTODO');
    }
  }

  /// Update an existing VTODO entry
  Future<VTodo> update(VTodo todo) async {
    if (todo.href == null)
      throw const CalDavException('VTODO href is required for update');

    try {
      final headers = {'Content-Type': 'text/calendar; charset=utf-8'};
      if (todo.etag != null) {
        headers['If-Match'] = todo.etag!;
      }

      final response = await _dio.put(
        todo.href.toString(),
        data: todo.toIcalendar(),
        options: Options(headers: headers),
      );

      final newEtag = response.headers.value('etag');
      return VTodo.fromIcalendar(
        todo.toIcalendar(),
        href: todo.href,
        etag: newEtag,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 412) {
        throw const ConflictException(
          'VTODO modified by another client. Sync required.',
        );
      }
      throw _mapException(e, 'Failed to update VTODO');
    }
  }

  /// Delete a VTODO entirely
  Future<void> delete(VTodo todo) async {
    // print('trying to delete: ${todo.summary}');
    // print('etag: ${todo.etag}');
    // print('href: ${todo.href}');
    if (todo.href == null) {
      throw const CalDavException('VTODO href is required for delete');
    }

    try {
      final headers = <String, String>{};
      if (todo.etag != null) {
        headers['If-Match'] = todo.etag!;
      }

      final _ = await _dio.request<String>(
        todo.href.toString(),
        options: Options(
          method: 'DELETE',
          headers: headers.isNotEmpty ? headers : null,
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return; // Already deleted
      if (e.response?.statusCode == 412) {
        throw const ConflictException(
          'VTODO modified by another client. Sync required.',
        );
      }
      throw _mapException(e, 'Failed to delete VTODO');
    }
  }

  // --- XML Processing and Mapping ---

  List<VTodo> _parseMultiStatusXml(String rawXml, Uri calendarHref) {
    if (rawXml.isEmpty) return [];
    final results = <VTodo>[];

    try {
      final document = XmlDocument.parse(rawXml);
      final responses = document.findAllElements('d:response').isNotEmpty
          ? document.findAllElements('d:response')
          : document.findAllElements(
              'response',
            ); // Handle namespacing gracefully

      for (var response in responses) {
        // Extract href
        final hrefNodeList = response.findElements('d:href');
        final hrefNode = hrefNodeList.isNotEmpty
            ? hrefNodeList.first
            : response.findElements('href').firstOrNull;
        if (hrefNode == null) continue;

        final itemHref = calendarHref.resolve(hrefNode.innerText);

        // Extract ETag
        final getEtagNodeList = response.findAllElements('d:getetag');
        final getEtagNode = getEtagNodeList.isNotEmpty
            ? getEtagNodeList.first
            : response.findAllElements('getetag').firstOrNull;
        final etag = getEtagNode?.innerText;

        // Extract raw calendar-data (.ics string)
        final calDataList = response.findAllElements('cal:calendar-data');
        final calDataNode = calDataList.isNotEmpty
            ? calDataList.first
            : response.findAllElements('calendar-data').firstOrNull;

        if (calDataNode != null && calDataNode.innerText.isNotEmpty) {
          final parsedTodo = VTodo.fromIcalendar(
            calDataNode.innerText,
            href: itemHref,
            etag: etag,
          );
          results.add(parsedTodo);
        }
      }
    } catch (e) {
      print('XML Parsing Error in VTodoService: $e');
    }

    return results;
  }

  String _buildVTodoQuery() {
    return '''<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VTODO"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>''';
  }

  CalDavException _mapException(DioException e, String context) {
    switch (e.response?.statusCode) {
      case 401:
        return const AuthenticationException();
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      default:
        return CalDavException(
          '\$context: \${e.message}',
          statusCode: e.response?.statusCode,
        );
    }
  }
}
