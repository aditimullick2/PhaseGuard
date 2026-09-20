import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// App Configuration from Environment Variables
class AppConfig {
  static bool _isLoaded = false;

  // Agora Configuration
  static String get agoraAppId {
    if (!_isLoaded) {
      return const String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
    }
    return dotenv.env['AGORA_APP_ID'] ??
        const String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
  }

  static String get agoraAppCert {
    if (!_isLoaded) {
      return const String.fromEnvironment('AGORA_APP_CERT', defaultValue: '');
    }
    return dotenv.env['AGORA_APP_CERT'] ??
        const String.fromEnvironment('AGORA_APP_CERT', defaultValue: '');
  }

  // Backend Configuration
  static String get backendUrl {
    if (!_isLoaded) {
      return const String.fromEnvironment('PHASEGUARD_BACKEND_URL', defaultValue: 'https://phaseguard.onrender.com');
    }
    return dotenv.env['PHASEGUARD_BACKEND_URL'] ??
        const String.fromEnvironment('PHASEGUARD_BACKEND_URL', defaultValue: 'https://phaseguard.onrender.com');
  }

  // Firebase Configuration
  static String get firebaseApiKey {
    if (!_isLoaded) {
      return const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    }
    return dotenv.env['FIREBASE_API_KEY'] ??
        const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  }

  static String get firebaseProjectId {
    if (!_isLoaded) {
      return const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    }
    return dotenv.env['FIREBASE_PROJECT_ID'] ??
        const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  }

  static String get firebaseAuthDomain {
    if (!_isLoaded) {
      return const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
    }
    return dotenv.env['FIREBASE_AUTH_DOMAIN'] ??
        const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
  }

  static String get firebaseStorageBucket {
    if (!_isLoaded) {
      return const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
    }
    return dotenv.env['FIREBASE_STORAGE_BUCKET'] ??
        const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
  }

  static String get firebaseMessagingSenderId {
    if (!_isLoaded) {
      return const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
    }
    return dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ??
        const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  }

  static String get firebaseAppId {
    if (!_isLoaded) {
      return const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
    }
    return dotenv.env['FIREBASE_APP_ID'] ??
        const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  }

  static bool get isConfigured {
    return agoraAppId.isNotEmpty && firebaseProjectId.isNotEmpty;
  }

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
      _isLoaded = true;
      debugPrint('[AppConfig] Environment variables loaded successfully');
    } catch (e) {
      debugPrint('[AppConfig] Note: .env file not found or could not be loaded: $e');
      _isLoaded = true; // Set to true even if failed to prevent repeated attempts
    }
  }

  static void printConfig() {
    debugPrint('=== PhaseGuard Configuration ===');
    debugPrint('Agora App ID: ${agoraAppId.isNotEmpty ? "SET" : "NOT SET"}');
    debugPrint('Backend URL: $backendUrl');
    debugPrint('Firebase Project ID: ${firebaseProjectId.isNotEmpty ? firebaseProjectId : "NOT SET"}');
    debugPrint('Firebase Auth Domain: ${firebaseAuthDomain.isNotEmpty ? firebaseAuthDomain : "NOT SET"}');
    debugPrint('Firebase Storage Bucket: ${firebaseStorageBucket.isNotEmpty ? firebaseStorageBucket : "NOT SET"}');
    debugPrint('===================================');
  }
}
