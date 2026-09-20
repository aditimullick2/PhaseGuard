import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

/// LocalScambaiterService — Scambaiter with AI voice generation and auto-activation.
///
/// Features:
/// - Uses confused-elderly persona responses
/// - Records 15 seconds of audio for scambaiter
/// - AI voice generation API integration (ElevenLabs, Play.ht, etc.)
/// - Auto-activates when scammer calls
/// - Personalized voice using voice IDs
class LocalScambaiterService {
  bool _isProcessing = false;
  bool _isRecording = false;
  int _recordingDuration = 0; // in seconds
  static const int maxRecordingDuration = 15; // 15 seconds as requested
  static const String aiVoiceApiUrl = 'https://api.elevenlabs.io/v1/text-to-speech'; // Example API
  
  final StreamController<Map<String, dynamic>> _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;
  Timer? _recordingTimer;
  String? _userVoiceId; // User's personalized voice ID

  Stream<Map<String, dynamic>> get responseStream => _responseController.stream;
  bool get isProcessing => _isProcessing;
  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;
  String? get userVoiceId => _userVoiceId;

  /// Confused-elderly persona responses (offline fallback)
  static const Map<String, String> _offlineResponses = {
    'default': 'Arey bhai, mujhe samajh nahi aa raha, zara slowly bolo na...',
    'digital_arrest': 'Arre wah! Digital arrest? Main toh retired schoolteacher hoon Lucknow se. Mera bank account? Wo toh sirf pension ka hai. Aap zara detail mein batao kya hua?',
    'bank_freeze': 'Bank account freeze? Main toh abhi abhi pension nikala tha. Kya kuch gadbad ho gaya? Main confuse ho gaya hoon. Aap batao main kya karoon?',
    'police': 'Police? Main toh kabhi jail gaya nahi. Main seedha insaan hoon. Aap confusion hain na? Main bolta nahi, mujhe mera beta bolta hai sab cheezein.',
    'money': 'Paise? Main toh retired hoon, savings thodi bahut hain. Lekin scam ke baare mein suna hai. Aap real police ho ya fake? Mujhe maloom nahi.',
    'urgent': 'Urgent? Main toh abhi hospital se nikla tha. Mera dil bahut darr raha hai. Aap zara pehle sahi number do na.',
  };

  /// Set user's personalized voice ID for AI voice generation
  void setUserVoiceId(String voiceId) {
    _userVoiceId = voiceId;
    debugPrint('LocalScambaiter: User voice ID set to $voiceId');
  }

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

  /// Generate AI voice using external API (ElevenLabs, Play.ht, etc.)
  Future<String?> generateAIVoice(String text, String apiKey) async {
    try {
      debugPrint('LocalScambaiter: Generating AI voice for: $text');
      
      // Example using ElevenLabs API
      final response = await http.post(
        Uri.parse(aiVoiceApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': apiKey,
        },
        body: jsonEncode({
          'text': text,
          'voice_id': _userVoiceId ?? 'default', // Use user's voice ID or default
          'model_id': 'eleven_multilingual_v2',
          'output_format': 'mp3_44100_128',
        }),
      );

      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final audioPath = '${tempDir.path}/ai_voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File(audioPath);
        await file.writeAsBytes(audioBytes);
        
        debugPrint('LocalScambaiter: AI voice generated successfully');
        return audioPath;
      } else {
        debugPrint('LocalScambaiter: AI voice generation failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('LocalScambaiter: AI voice generation error: $e');
      return null;
    }
  }

  /// Start 125 second audio recording for scambaiter
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('LocalScambaiter: Already recording');
      return false;
    }

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('LocalScambaiter: No microphone permission');
        return false;
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/scambaiter_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );

      _recordingPath = path;
      _isRecording = true;
      _recordingDuration = 0;

      // Start timer for 125 seconds
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
        if (_recordingDuration >= maxRecordingDuration) {
          stopRecording();
        }
      });

      debugPrint('LocalScambaiter: Started recording (max ${maxRecordingDuration}s)');
      _responseController.add({
        'event': 'recording_started',
        'path': _recordingPath,
        'max_duration': maxRecordingDuration,
      });

      return true;
    } catch (e) {
      debugPrint('LocalScambaiter: Recording error: $e');
      return false;
    }
  }

  /// Stop audio recording
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      final path = await _audioRecorder.stop();
      _isRecording = false;
      
      debugPrint('LocalScambaiter: Recording stopped (${_recordingDuration}s)');
      _responseController.add({
        'event': 'recording_stopped',
        'path': path,
        'duration': _recordingDuration,
      });

      return path;
    } catch (e) {
      debugPrint('LocalScambaiter: Stop recording error: $e');
      return null;
    }
  }

  /// Auto-activate scambaiter when scammer calls
  Future<bool> autoActivateOnScam(String callerSpeech, String aiApiKey) async {
    try {
      debugPrint('LocalScambaiter: Auto-activating on scam call');
      
      // Generate text response
      final responseText = generateResponse(callerSpeech);
      
      // Generate AI voice
      final aiVoicePath = await generateAIVoice(responseText, aiApiKey);
      
      // Start 15-second recording
      final recordingStarted = await startRecording();
      
      _responseController.add({
        'event': 'auto_activated',
        'text': responseText,
        'ai_voice_path': aiVoicePath,
        'recording_started': recordingStarted,
        'max_duration': maxRecordingDuration,
      });
      
      return true;
    } catch (e) {
      debugPrint('LocalScambaiter: Auto-activation error: $e');
      return false;
    }
  }

  /// Generate scambaiter response with audio recording
  Future<Map<String, dynamic>> generateAudioResponse(String callerSpeech) async {
    if (_isProcessing) {
      debugPrint('LocalScambaiter: Already processing, please wait');
      return {'error': 'Already processing'};
    }

    try {
      _isProcessing = true;
      debugPrint('LocalScambaiter: Generating response with audio...');

      // Generate text response
      final responseText = generateResponse(callerSpeech);
      debugPrint('LocalScambaiter: Response: $responseText');

      // Start audio recording for 15 seconds
      final recordingStarted = await startRecording();
      
      final result = {
        'success': true,
        'text': responseText,
        'audio_path': _recordingPath,
        'recording_started': recordingStarted,
        'max_duration': maxRecordingDuration,
        'source': 'local_text_with_audio',
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

  /// Get recorded audio file as bytes
  Future<Uint8List?> getRecordedAudio() async {
    if (_recordingPath == null) return null;
    
    try {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('LocalScambaiter: Error reading audio: $e');
      return null;
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _responseController.close();
  }
}
