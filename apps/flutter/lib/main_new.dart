import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'screens_new/app_navigation.dart';
import 'services/phone_call_monitor.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SessionController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhaseGuard',
      theme: PgTheme.data(),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapCallProtection());
  }

  Future<void> _bootstrapCallProtection() async {
    final session = context.read<SessionController>();
    session.attachPhoneMonitor();
    if (Platform.isAndroid) {
      await Permission.phone.request();
      await Permission.notification.request();
    }
    try {
      await PhoneCallMonitor.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return const AppNavigation();
  }
}
