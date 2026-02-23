import 'package:get_it/get_it.dart';
import '../data/data_manager.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Register DataManager implementation
  final dataManager = LocalDataManager();
  await dataManager.init(); // Initialize the data layer
  getIt.registerSingleton<DataManager>(dataManager);
}
