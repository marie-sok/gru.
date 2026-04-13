// TODO Implement this library.
import 'package:flutter/material.dart';

import 'lib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var FlutterWindowManager;
  await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  runApp(const MyApp());
}
