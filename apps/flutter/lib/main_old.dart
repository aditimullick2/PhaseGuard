import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/calls_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/phone_call_monitor.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/incoming_call_overlay.dart';

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
  int _currentIndex = 0;

  final _screens = [
    const HomeScreen(),
    const CallsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

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
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          const IncomingCallOverlay(),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Consumer<SessionController>(
                builder: (context, session, _) {
                  return FloatingActionButton.extended(
                    heroTag: 'demo_overlay',
                    onPressed: session.toggleDemoOverlay,
                    backgroundColor: PgColors.bgSecondary,
                    foregroundColor: PgColors.lightBlue,
                    icon: Icon(
                      session.overlayVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(
                      session.overlayVisible ? 'Hide overlay' : 'Show overlay',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF021024),
        selectedItemColor: const Color(0xFF5483B3),
        unselectedItemColor: const Color(0xFF7DA0CA),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
