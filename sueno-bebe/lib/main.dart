import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controllers/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final AppController controller = AppController();
  await controller.initialize();
  runApp(
    ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: const SleepBabyApp(),
    ),
  );
}
