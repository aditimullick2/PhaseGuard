import 'package:flutter/foundation.dart' show debugPrint;

/// App Configuration from Environment Variables
/// 
/// For development: Use .env file or --dart-define
/// For production: Use --dart-define to pass values
/// Mobile devices: --dart-define required (.env not packaged)
class AppConfig {
  // Agora Configuration
  static String get agoraAppId {
    return const String.fromEnvironment('AGORA_APP_ID', defaultValue: '16671f3cb5804cb5bf0cb11b4874df54');
  }

  static String get agoraAppCert {
    return const String.fromEnvironment('AGORA_APP_CERT', defaultValue: '7191dfc5b6d84aab8f5c49380c4db91f');
  }

  // Backend Configuration
  static String get backendUrl {
    return const String.fromEnvironment('PHASEGUARD_BACKEND_URL', defaultValue: 'https://phaseguard.onrender.com');
  }

  // Firebase Configuration
  static String get firebaseApiKey {
    return const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyB-nmhHQBdIYUoENBtzGPGwHMarUgsBZqw');
  }

  static String get firebaseProjectId {
    return const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'phaseguard-a5bfd');
  }

  static String get firebaseAuthDomain {
    return const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'phaseguard-a5bfd.firebaseapp.com');
  }

  static String get firebaseStorageBucket {
    return const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'phaseguard-a5bfd.firebasestorage.app');
  }

  static String get firebaseMessagingSenderId {
    return const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '1060611267670');
  }

  static String get firebaseAppId {
    return const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:1060611267670:android:8e05625c29b33f1b30eff7');
  }

  static bool get isConfigured {
    return agoraAppId.isNotEmpty && firebaseProjectId.isNotEmpty;
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
