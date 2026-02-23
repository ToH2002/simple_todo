import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/todo_list_page/todo_list_page.dart';

import '../../services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    double? width = prefs.getDouble('window_width');
    double? height = prefs.getDouble('window_height');
    double? x = prefs.getDouble('window_x');
    double? y = prefs.getDouble('window_y');

    WindowOptions windowOptions = WindowOptions(
      size: Size(width ?? 800, height ?? 600),
      center: (x == null || y == null),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
    });
  }

  runApp(const SimpleTodoApp());
}

class SimpleTodoApp extends StatefulWidget {
  const SimpleTodoApp({super.key});

  @override
  State<SimpleTodoApp> createState() => _SimpleTodoAppState();
}

class _SimpleTodoAppState extends State<SimpleTodoApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _saveWindowRect() async {
    final prefs = await SharedPreferences.getInstance();
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
    await prefs.setDouble('window_x', position.dx);
    await prefs.setDouble('window_y', position.dy);
  }

  @override
  void onWindowMoved() {
    _saveWindowRect();
  }

  @override
  void onWindowResized() {
    _saveWindowRect();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple ToDo Mock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
      ),
      home: const TodoListPage(),
    );
  }
}
