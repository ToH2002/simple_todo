import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class SyncLogger {
  File? _logFile;
  int? _lastLogDay;

  Future<void> init() async {
    final rootDir = await getApplicationSupportDirectory();
    final logDir = Directory('${rootDir.path}/logs');
    if (!logDir.existsSync()) {
      await logDir.create(recursive: true);
    }
    _logFile = File('${logDir.path}/sync_log.txt');

    if (_logFile!.existsSync()) {
      // Determine the day the file was last modified
      final stat = await _logFile!.stat();
      _lastLogDay = stat.modified.toLocal().day;
    }
  }

  Future<void> _checkRollover() async {
    if (_logFile == null) await init();

    final currentDay = DateTime.now().day;
    if (_lastLogDay != null && _lastLogDay != currentDay) {
      if (_logFile!.existsSync()) {
        await _logFile!.writeAsString('', mode: FileMode.write); // Wipe clean
      }
    }
    _lastLogDay = currentDay;
  }

  Future<void> logConnect(String url, String username) async {
    await _checkRollover();
    await _append('[CONNECT] ${_time()} - Connecting to $url as $username\n');
  }

  Future<void> logUpdate(
    String action,
    String itemId,
    String itemName, {
    DateTime? lastModified,
  }) async {
    await _checkRollover();
    final timeStr = lastModified != null
        ? ' (modified: ${lastModified.toIso8601String()})'
        : '';
    await _append('[$action] ${_time()} - $itemId - "$itemName"$timeStr\n');
  }

  Future<void> logError(String context, String errorDetails) async {
    await _checkRollover();
    await _append('[ERROR] ${_time()} - $context: $errorDetails\n');
  }

  Future<void> logInfo(String info) async {
    await _checkRollover();
    await _append('[INFO] ${_time()} - $info\n');
  }

  Future<void> _append(String text) async {
    if (_logFile == null) await init();
    print(text.trim()); // Also print to debug console
    try {
      await _logFile!.writeAsString(text, mode: FileMode.append);
    } catch (e) {
      print('Failed to write to sync log: $e');
    }
  }

  Future<String> readLog() async {
    if (_logFile == null) await init();
    if (!_logFile!.existsSync()) return 'No sync logs available for today.';
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  String _time() {
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }
}
