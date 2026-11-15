import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'screens/Tambah_tugas_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await SharedPreferences.getInstance();
  await NotificationService().init();
  runApp(const MyStoreApp());
}