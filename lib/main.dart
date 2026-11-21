import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final storePath = '${dir.path}/foodplaner.json';
  runApp(FoodPlanerApp(storePath: storePath));
}
