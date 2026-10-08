import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import 'app.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Insforge.initialize(url: Config.baseUrl, anonKey: Config.anonKey);
  runApp(const DenuPeApp());
}