import 'dart:async';
import 'package:flutter/foundation.dart';

/// LocalScambaiterService — Offline scambaiter (text-based).
///
/// Offline-First Approach:
/// - Uses confused-elderly persona responses
/// - No audio generation (text-only for now)
/// - "Ramesh Ji" confused-elderly persona
/// - Audio can be added later with backend TTS
class LocalScambaiterService {
  bool _isProcessing = false;
  
  final StreamController<Map<String, dynamic>> _responseController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get responseStream => _responseController.stream;
  bool get isProcessing => _isProcessing;

  /// Confused-elderly persona responses (offline fallback)
  static const Map<String, String> _offlineResponses = {
    'default': 'Arey bhai, mujhe samajh nahi aa raha, zara slowly bolo na...',
    'digital_arrest': 'Arre wah! Digital arrest? Main toh retired schoolteacher hoon Lucknow se. Mera bank account? Wo toh sirf pension ka hai. Aap zara detail mein batao kya hua?',
    'bank_freeze': 'Bank account freeze? Main toh abhi abhi pension nikala tha. Kya kuch gadbad ho gaya? Main confuse ho gaya hoon. Aap batao main kya karoon?',
    'police': 'Police? Main toh kabhi jail gaya nahi. Main seedha insaan hoon. Aap confusion hain na? Main bolta nahi, mujhe mera beta bolta hai sab cheezein.',
    'money': 'Paise? Main toh retired hoon, savings thodi bahut hain. Lekin scam ke baare mein suna hai. Aap real police ho ya fake? Mujhe maloom nahi.',
    'urgent': 'Urgent? Main toh abhi hospital se nikla tha. Mera dil bahut darr raha hai. Aap zara pehle sahi number do na.',
  };

  /// Generate scambaiter response text.
  String generateResponse(String callerSpeech) {
    final speechLower = callerSpeech.toLowerCase();
    
    // Detect scam type and return appropriate response
    if (speechLower.contains('digital arrest') || speechLower.contains('arrest')) {
      return _offlineResponses['digital_arrest']!;
    } else if (speechLower.contains('bank') && speechLower.contains('freeze')) {
      return _offlineResponses['bank_freeze']!;
    } else if (speechLower.contains('police') || speechLower.contains('cbi')) {
      return _offlineResponses['police']!;
    } else if (speechLower.contains('money') || speechLower.contains('paisa') || speechLower.contains('rupees')) {
      return _offlineResponses['money']!;
    } else if (speechLower.contains('urgent') || speechLower.contains('emergency')) {
      return _offlineResponses['urgent']!;
    } else {
      return _offlineResponses['default']!;
    }
  }

  /// Generate scambaiter response (text-only for now).
  Future<Map<String, dynamic>> generateAudioResponse(String callerSpeech) async {
    if (_isProcessing) {
      debugPrint('LocalScambaiter: Already processing, please wait');
      return {'error': 'Already processing'};
    }

    try {
      _isProcessing = true;
      debugPrint('LocalScambaiter: Generating response...');

      // Generate text response
      final responseText = generateResponse(callerSpeech);
      debugPrint('LocalScambaiter: Response: $responseText');

      final result = {
        'success': true,
        'text': responseText,
        'audio_path': null, // Audio generation requires backend TTS
        'source': 'local_text',
        'processing_time': DateTime.now().toIso8601String(),
      };

      _responseController.add(result);
      return result;
    } catch (e) {
      debugPrint('LocalScambaiter: Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _responseController.close();
  }
}
