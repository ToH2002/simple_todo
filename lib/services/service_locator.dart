import 'package:get_it/get_it.dart';
import '../data/data_manager.dart';
import '../data/settings_manager.dart';
import 'caldav_service.dart';
import 'sync_logger.dart';
import '../pages/todo_list_page/consolidated_due_list_logic.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Register DataManager implementation
  final dataManager = LocalDataManager();
  await dataManager.init(); // Initialize the data layer
  getIt.registerSingleton<DataManager>(dataManager);

  // Register CalDavService
  getIt.registerSingleton<CalDavService>(CalDavService());

  // Register SyncLogger
  final syncLogger = SyncLogger();
  await syncLogger.init();
  getIt.registerSingleton<SyncLogger>(syncLogger);

  // Register SettingsManager
  getIt.registerSingleton<SettingsManager>(SettingsManager());

  // Register Consolidated Due List Logic (singleton so that it shares state)
  getIt.registerSingleton<ConsolidatedDueListLogic>(ConsolidatedDueListLogic());
}
