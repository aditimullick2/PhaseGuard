import 'package:flutter/foundation.dart' show debugPrint;

/// App Configuration from Environment Variables
/// 
/// For development: Use .env file or --dart-define
/// For production: Use --dart-define to pass values
/// Mobile devices: --dart-define required (.env not packaged)
class AppConfig {
  // Agora Configuration
  static String get agoraAppId {
    return const String.fromEnvironment('AGORA_APP_ID', defaultValue: '5d8ed074e92b4c51b1aa80c5746178f0');
  }

  static String get agoraAppCert {
    return const String.fromEnvironment('AGORA_APP_CERT', defaultValue: '7222c223f53c4f9693e845e98f30de7f');
  }

  // Backend Configuration
  static String get backendUrl {
    return const String.fromEnvironment('PHASEGUARD_BACKEND_URL', defaultValue: 'https://phaseguard.onrender.com');
  }

  // Firebase Configuration
  static String get firebaseApiKey {
    return const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyCSbRjDvyjfQbXmIRgZwXU0Y-EXK1_Dgbg');
  }

  static String get firebaseProjectId {
    return const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'phaseguard-7675a');
  }

  static String get firebaseAuthDomain {
    return const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'phaseguard-7675a.firebaseapp.com');
  }

  static String get firebaseStorageBucket {
    return const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'phaseguard-7675a.firebasestorage.app');
  }

  static String get firebaseMessagingSenderId {
    return const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '733823100953');
  }

  static String get firebaseAppId {
    return const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:733823100953:android:7aca3507baf21a13312288');
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
