import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// LocalSttService — On-device Speech-to-Text using speech_to_text package.
///
/// Uses Android's built-in SpeechRecognizer (no internet needed in offline mode).
/// Falls back gracefully if mic permission not granted or STT unavailable.
class LocalSttService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize STT — requests mic permission and checks availability.
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('LocalSTT error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (status) {
          debugPrint('LocalSTT status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );

      if (_isInitialized) {
        debugPrint('LocalSTT: ✅ Initialized successfully');
      } else {
        debugPrint('LocalSTT: ❌ Not available on this device');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('LocalSTT: Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening — results streamed via [transcriptStream].
  Future<void> startListening({String localeId = 'hi_IN'}) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_isListening) return;

    try {
      _isListening = true;
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _transcriptController.add(result.recognizedWords);
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
      );
      debugPrint('LocalSTT: Started listening (locale: $localeId)');
    } catch (e) {
      debugPrint('LocalSTT: startListening error: $e');
      _isListening = false;
    }
  }

  /// Stop listening.
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    _isListening = false;
    debugPrint('LocalSTT: Stopped listening');
  }

  /// Get list of available locales (Hindi, English, etc.)
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();
    return _speechToText.locales();
  }

  void dispose() {
    stopListening();
    _transcriptController.close();
  }
}
