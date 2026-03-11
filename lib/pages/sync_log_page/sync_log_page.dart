import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../services/sync_logger.dart';

class SyncLogPage extends StatelessWidget {
  const SyncLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = getIt<SyncLogger>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Log')),
      body: FutureBuilder<String>(
        future: logger.readLog(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          final logText = snapshot.data ?? 'No logs found.';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              logText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
