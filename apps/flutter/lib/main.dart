import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:provider/provider.dart' as provider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// PhaseGuard Imports
import 'screens/splash_screen.dart';
import 'providers/providers.dart';
import 'providers/locale_provider.dart';
import 'services/notification_service.dart';

// PhaseGuard Imports
import 'state/session_controller.dart';
import 'services/auth_service.dart' as pg_auth;
import 'services/call_signaling_service.dart';
import 'services/in_app_calling_service.dart';
import 'services/phone_call_monitor.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  AppConfig.printConfig();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[PhaseGuard] Firebase initialization note: $e');
  }

  // Register background FCM handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    riverpod.ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => SessionController()),
          provider.ChangeNotifierProvider(create: (_) => pg_auth.AuthService()),
          provider.ChangeNotifierProvider(create: (_) => CallSignalingService()),
          provider.ChangeNotifierProvider(create: (_) => InAppCallingService()),
        ],
        child: const PhaseGuardApp(),
      ),
    ),
  );
}

class PhaseGuardApp extends riverpod.ConsumerStatefulWidget {
  const PhaseGuardApp({super.key});

  @override
  riverpod.ConsumerState<PhaseGuardApp> createState() => _PhaseGuardAppState();
}

class _PhaseGuardAppState extends riverpod.ConsumerState<PhaseGuardApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // PhaseGuard Services Bootstrap
      _bootstrapPhaseGuardServices();

      // Initialize notification service
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize();

      // Initialize Agora engine early if App ID is configured
      final agoraAppId = ref.read(agoraAppIdProvider);
      final agoraAppCert = ref.read(agoraAppCertProvider);
      if (agoraAppId.isNotEmpty && agoraAppCert.isNotEmpty) {
        final callingService = ref.read(callingServiceProvider);
        await callingService.initialize(appId: agoraAppId, appCert: agoraAppCert);
      }

      // Update FCM token for the currently logged-in user
      _updateFcmToken();
    });
  }

  Future<void> _bootstrapPhaseGuardServices() async {
    final session = context.read<SessionController>();
    session.attachPhoneMonitor();

    // Anonymous authentication for in-app calling (PhaseGuard legacy auth fallback)
    final pgAuth = context.read<pg_auth.AuthService>();
    if (!pgAuth.isAuthenticated) {
      try {
        await pgAuth.signInAnonymously();
      } catch (e) {
        debugPrint('[PhaseGuard] Auth note: $e');
      }
    }

    if (!mounted) return;

    // Initialize PhaseGuard Agora calling service in Testing Mode
    final calling = context.read<InAppCallingService>();
    try {
      await calling.initialize();
    } catch (e) {
      debugPrint('[PhaseGuard] Agora init note: $e');
    }

    if (Platform.isAndroid) {
      try {
        await [
          Permission.phone,
          Permission.notification,
          Permission.microphone,
        ].request();
      } catch (e) {
        debugPrint('[PhaseGuard] Permission request note: $e');
      }
    }

    try {
      await PhoneCallMonitor.start();
    } catch (_) {}
  }

  Future<void> _updateFcmToken() async {
    try {
      final userAsync = await ref.read(currentUserModelProvider.future);
      if (userAsync != null) {
        final token = await ref.read(notificationServiceProvider).getFcmToken();
        if (token != null) {
          await ref.read(userServiceProvider).updateFcmToken(userAsync.uid, token);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final auth = context.read<pg_auth.AuthService>();
    auth.setAppLifecycleState(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final pgAuth = context.read<pg_auth.AuthService>();
    final isInForeground = state == AppLifecycleState.resumed;
    pgAuth.setAppLifecycleState(isInForeground);
    _handleLifecycle(state);
  }

  Future<void> _handleLifecycle(AppLifecycleState state) async {
    try {
      final userAsync = await ref.read(currentUserModelProvider.future);
      if (userAsync == null) return;

      final userService = ref.read(userServiceProvider);
      switch (state) {
        case AppLifecycleState.resumed:
          await userService.setUserOnline(userAsync.uid, true);
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          await userService.setUserOnline(userAsync.uid, false);
          break;
        case AppLifecycleState.inactive:
          break;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhaseGuard',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    const seedColor = Color(0xFF6C63FF); 
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0E1A),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1930),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1D2E),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252438),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3D3B5E), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: seedColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9A97C5)),
        hintStyle: const TextStyle(color: Color(0xFF6A6890)),
        prefixIconColor: const Color(0xFF9A97C5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seedColor,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1930),
        selectedItemColor: Color(0xFF6C63FF),
        unselectedItemColor: Color(0xFF6A6890),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}