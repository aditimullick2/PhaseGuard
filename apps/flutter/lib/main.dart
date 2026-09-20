import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'screens_new/app_navigation.dart';
import 'screens_new/call/name_selection_screen.dart';
import 'services/auth_service.dart';
import 'services/call_signaling_service.dart';
import 'services/in_app_calling_service.dart';
import 'services/phone_call_monitor.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print configuration
  AppConfig.printConfig();

  // Initialize Firebase (graceful if google-services.json is pending)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[PhaseGuard] Firebase initialization note: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CallSignalingService()),
        ChangeNotifierProvider(create: (_) => InAppCallingService()),
      ],
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
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to main screen after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.security,
                  size: 120,
                  color: Color(0xFF00E676),
                );
              },
            ),
            const SizedBox(height: 24),
            // App Name
            const Text(
              'PhaseGuard',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            const Text(
              'Real-Time Scam & Deepfake Protection',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8B949E),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapServices());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final auth = context.read<AuthService>();
    auth.setAppLifecycleState(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthService>();
    final isInForeground = state == AppLifecycleState.resumed;
    auth.setAppLifecycleState(isInForeground);
  }

  Future<void> _bootstrapServices() async {
    final session = context.read<SessionController>();
    session.attachPhoneMonitor();

    // Anonymous authentication for in-app calling
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        debugPrint('[PhaseGuard] Auth note: $e');
      }
    }

    if (!mounted) return;

    // Initialize Agora calling service in Testing Mode
    final calling = context.read<InAppCallingService>();
    try {
      await calling.initialize();
    } catch (e) {
      debugPrint('[PhaseGuard] Agora init note: $e');
    }

    if (Platform.isAndroid) {
      await Permission.phone.request();
      await Permission.notification.request();
      await Permission.microphone.request();
    }

    try {
      await PhoneCallMonitor.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    
    // Show name selection screen if user has auto-generated name
    if (auth.isAuthenticated && auth.hasAutoGeneratedName) {
      return const NameSelectionScreen();
    }
    
    return const AppNavigation();
  }
}