import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/realtime_scam_detection.dart';
import '../services/audio_streaming.dart';
// import '../services/local_stt_service.dart';  // Gradle build issues - use backend Whisper STT
import '../services/scam_detector.dart';
import '../theme/tokens.dart';

/// Demo screen for real-time scam detection
/// 
/// Shows how to integrate backend AI scam detection with mobile app
/// Uses native AudioRecord with speakerphone for in-call audio capture
class ScamDetectionDemo extends StatefulWidget {
  const ScamDetectionDemo({super.key});

  @override
  State<ScamDetectionDemo> createState() => _ScamDetectionDemoState();
}

class _ScamDetectionDemoState extends State<ScamDetectionDemo> {
  final RealtimeScamDetection _scamDetection = RealtimeScamDetection();
  late final AudioStreaming _audioStreaming;
  // final LocalSttService _localSttService = LocalSttService();  // Gradle build issues - use backend Whisper STT
  
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _hasPermission = false;
  bool _isSpeakerphoneOn = false;
  String _status = 'Idle';
  String _transcript = '';
  String _lastAlert = '';
  String _callId = '';
  String _audioSource = 'MIC';
  double _audioAmplitude = 0.0;
  
  // Local DSP metrics
  double _localTremorScore = 0.0;
  double _localPhaseDispersion = 0.0;

  // Local NLP metrics
  // String _localTranscript = '';  // Gradle build issues - use backend Whisper STT
  
  @override
  void initState() {
    super.initState();
    _audioStreaming = AudioStreaming(scamDetection: _scamDetection);
    // _localSttService.initialize();  // Gradle build issues - use backend Whisper STT
    _setupEventListeners();
    _checkPermissions();
  }
  
  void _setupEventListeners() {
    // Listen for scam alerts
    _scamDetection.alertController.listen((alert) {
      setState(() {
        _lastAlert = alert['message'] ?? 'Unknown alert';
      });
      
      // Show alert dialog
      _showScamAlert(alert);
    });
    
    // Listen for transcript updates
    _scamDetection.transcriptStream.listen((text) {
      setState(() {
        _transcript += ' $text';
      });
    });
    
    // Listen for local offline STT transcript
    // _localSttService.transcriptStream.listen((text) {  // Gradle build issues - use backend Whisper STT
    //   setState(() {
    //     _localTranscript = text;
    //
    //     // Pass to ScamDetector (Keyword Rules Engine)
    //     final scamResult = ScamDetector.detectScam(_localTranscript);
    //     if (scamResult.isScam) {
    //        _lastAlert = "LOCAL NLP ALERT: ${scamResult.reasoning}";
    //        _status = 'LOCAL SCAM KEYWORDS DETECTED!';
    //     }
    //   });
    // });
    
    // Listen for general events
    _scamDetection.eventStream.listen((event) {
      final type = event['type'];
      
      setState(() {
        switch (type) {
          case 'connected':
            _status = 'Connected to backend';
            _callId = event['call_id'] ?? '';
            break;
          case 'disconnected':
            _status = 'Disconnected';
            break;
          case 'error':
            _status = 'Error: ${event['message']}';
            break;
          case 'factcheck_update':
            final status = event['status'] ?? '';
            if (status == 'CRITICAL') {
              _status = 'SCAM DETECTED!';
            } else if (status == 'VERIFYING') {
              _status = 'Analyzing...';
            } else {
              _status = 'Safe';
            }
            break;
        }
      });
    });

    // Listen for local DSP events
    _audioStreaming.localDspStream.listen((dspResult) {
      setState(() {
        if (dspResult['metrics'] != null) {
          _localTremorScore = dspResult['metrics']['tremor_score'] ?? 0.0;
          _localPhaseDispersion = dspResult['metrics']['phase_dispersion'] ?? 0.0;
        }

        if (dspResult['is_synthetic'] == true) {
           _lastAlert = "LOCAL ALERT: ${dspResult['reason']}";
           _status = 'LOCAL DEEPFAKE DETECTED!';
        }
      });
    });
  }
  
  Future<void> _checkPermissions() async {
    final hasPermission = await _audioStreaming.checkPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
    
    if (!hasPermission) {
      _requestPermission();
    }
  }
  
  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    
    if (status.isGranted) {
      print('RECORD_AUDIO permission granted');
    } else {
      print('RECORD_AUDIO permission denied');
    }
  }
  
  Future<void> _initializeCall() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });
      
      await _scamDetection.initCall(
        callerNumber: '+91XXXXXXXXXX',
        ingestionMode: 'browser_mic',
      );
      
      setState(() {
        _isInitialized = true;
        _status = 'Ready to record';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed: $e';
      });
    }
  }
  
  Future<void> _startRecording() async {
    if (!_hasPermission) {
      _requestPermission();
      return;
    }
    
    // Check speakerphone first
    final speakerphoneOn = await _audioStreaming.checkSpeakerphone();
    setState(() {
      _isSpeakerphoneOn = speakerphoneOn;
    });
    
    if (!speakerphoneOn) {
      _showSpeakerphonePrompt();
      return;
    }
    
    try {
      final success = await _audioStreaming.startCapture(source: _audioSource);

      if (success) {
        // Start local STT
        // _localSttService.startListening();  // Gradle build issues - use backend Whisper STT

        setState(() {
          _isRecording = true;
          _status = 'Recording & Analyzing...';
        });
        
        // Get audio stats after a delay
        Future.delayed(const Duration(seconds: 2), () async {
          final stats = await _audioStreaming.getAudioStats();
          setState(() {
            _audioAmplitude = stats['averageAmplitude']?.toDouble() ?? 0.0;
          });
        });
      } else {
        setState(() {
          _status = 'Failed to start capture';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }
  
  void _stopRecording() async {
    await _audioStreaming.stopCapture();
    // await _localSttService.stopListening();  // Gradle build issues - use backend Whisper STT

    setState(() {
      _isRecording = false;
      _status = 'Recording stopped';
    });
  }
  
  void _showSpeakerphonePrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Speakerphone'),
        content: const Text(
          'PhaseGuard needs speakerphone enabled to capture both sides of the call. '
          'Please enable speakerphone in your phone\'s dialer, then tap "Continue".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Re-check speakerphone
              _checkSpeakerphoneAndStart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PgColors.accentBlue,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _checkSpeakerphoneAndStart() async {
    // Wait a moment for user to enable speakerphone
    await Future.delayed(const Duration(seconds: 2));
    
    final speakerphoneOn = await _audioStreaming.checkSpeakerphone();
    setState(() {
      _isSpeakerphoneOn = speakerphoneOn;
    });
    
    if (speakerphoneOn) {
      await _startRecording();
    } else {
      setState(() {
        _status = 'Speakerphone not enabled';
      });
    }
  }
  
  void _showScamAlert(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ SCAM DETECTED'),
        content: Text(alert['message'] ?? 'Potential scam detected'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ignore'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement escalation logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PgColors.crit,
            ),
            child: const Text('Report Scam'),
          ),
        ],
      ),
    );
  }
  
  void _switchAudioSource() async {
    final newSource = _audioSource == 'MIC' ? 'VOICE_RECOGNITION' : 'MIC';
    await _audioStreaming.switchAudioSource(newSource);
    setState(() {
      _audioSource = newSource;
    });
  }
  
  @override
  void dispose() {
    _audioStreaming.dispose();
    _scamDetection.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scam Detection Demo'),
        backgroundColor: PgColors.bgPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission Status
            Card(
              color: _hasPermission ? PgColors.safe.withValues(alpha: 0.2) : PgColors.crit.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _hasPermission ? Icons.check_circle : Icons.error,
                      color: _hasPermission ? PgColors.safe : PgColors.crit,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasPermission ? 'RECORD_AUDIO Permission Granted' : 'RECORD_AUDIO Permission Required',
                        style: TextStyle(
                          color: _hasPermission ? PgColors.safe : PgColors.crit,
                        ),
                      ),
                    ),
                    if (!_hasPermission)
                      ElevatedButton(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PgColors.accentBlue,
                        ),
                        child: const Text('Grant'),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Speakerphone Status
            Card(
              color: _isSpeakerphoneOn ? PgColors.safe.withValues(alpha: 0.2) : PgColors.mediumBlue.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isSpeakerphoneOn ? Icons.volume_up : Icons.volume_off,
                      color: _isSpeakerphoneOn ? PgColors.safe : PgColors.mediumBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isSpeakerphoneOn ? 'Speakerphone Enabled' : 'Speakerphone Disabled',
                        style: TextStyle(
                          color: _isSpeakerphoneOn ? PgColors.safe : PgColors.mediumBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status Card
            Card(
              color: PgColors.bgSecondary,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: PgColors.mediumBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _status.contains('SCAM') 
                            ? PgColors.crit 
                            : PgColors.white,
                      ),
                    ),
                    if (_callId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Call ID: $_callId',
                        style: TextStyle(
                          fontSize: 10,
                          color: PgColors.mediumBlue,
                        ),
                      ),
                    ],
                    if (_audioAmplitude > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Audio Amplitude: $_audioAmplitude',
                        style: TextStyle(
                          fontSize: 10,
                          color: PgColors.mediumBlue,
                        ),
                      ),
                    ],
                    // Show local DSP metrics if streaming
                    if (_isRecording) ...[
                      const SizedBox(height: 12),
                      const Divider(color: PgColors.mediumBlue),
                      const SizedBox(height: 8),
                      Text(
                        'ON-DEVICE DSP ANALYSIS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: PgColors.safe,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tremor Score: ${_localTremorScore.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _localTremorScore < 0.0001 ? PgColors.crit : PgColors.safe,
                        ),
                      ),
                      Text(
                        'Phase Dispersion: ${_localPhaseDispersion.toStringAsFixed(3)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _localPhaseDispersion < 1.0 ? PgColors.crit : PgColors.safe,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Controls
            if (!_isInitialized)
              ElevatedButton(
                onPressed: _initializeCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PgColors.accentBlue,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Initialize Backend Connection'),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isRecording ? _stopRecording : _startRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? PgColors.crit : PgColors.safe,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _scamDetection.disconnect(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PgColors.mediumBlue,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Audio Source: $_audioSource',
                        style: TextStyle(
                          fontSize: 12,
                          color: PgColors.mediumBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _switchAudioSource,
                        child: const Text('Switch'),
                      ),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Last Alert
            if (_lastAlert.isNotEmpty)
              Card(
                color: PgColors.crit.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: PgColors.crit),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastAlert,
                          style: const TextStyle(color: PgColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Transcripts Side-by-Side
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: PgColors.bgSecondary,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backend Transcript',
                              style: TextStyle(
                                fontSize: 12,
                                color: PgColors.mediumBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  _transcript.isEmpty
                                      ? 'Waiting for backend...'
                                      : _transcript,
                                  style: const TextStyle(color: PgColors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: PgColors.bgSecondary,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Local STT (Offline)',
                              style: TextStyle(
                                fontSize: 12,
                                color: PgColors.safe,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  'Local STT disabled due to Gradle build issues. Using backend Whisper STT (better accuracy).',
                                  style: const TextStyle(color: PgColors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
