import 'dart:io';

void main() {
  final roaming = Platform.environment['APPDATA'];
  if (roaming != null) {
    final possibleDirs = [
      '$roaming\\com.cornerapps\\simple_todo',
      '$roaming\\com.cornerapps.simple_todo',
      '$roaming\\com.cornerapps\\simpleToDo',
      '$roaming\\simple_todo',
    ];
    for (final p in possibleDirs) {
      final dir = Directory(p);
      if (dir.existsSync()) {
        print('Found dir: $p');
        for (final file in dir.listSync(recursive: true)) {
          print(file.path);
          if (file.path.endsWith('.json')) {
            print(File(file.path).readAsStringSync());
          }
        }
      }
    }
  }
}
