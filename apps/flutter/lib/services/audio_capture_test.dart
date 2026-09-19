import 'package:flutter/material.dart';
import 'screen_audio_capture.dart';

/// Test screen for screen audio capture functionality
/// This helps verify the implementation works on your device
class AudioCaptureTestScreen extends StatefulWidget {
  const AudioCaptureTestScreen({super.key});

  @override
  State<AudioCaptureTestScreen> createState() => _AudioCaptureTestScreenState();
}

class _AudioCaptureTestScreenState extends State<AudioCaptureTestScreen> {
  final ScreenAudioCapture _audioCapture = ScreenAudioCapture();
  bool _isCapturing = false;
  bool _isAvailable = false;
  String _status = 'Checking availability...';
  String _deviceInfo = 'Loading...';
  int _audioBytesReceived = 0;
  double _audioLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final available = await _audioCapture.isAvailable();
      final deviceInfo = await _audioCapture.getDeviceInfo();
      
      setState(() {
        _isAvailable = available;
        _status = available ? 'Available' : 'Not available';
        _deviceInfo = deviceInfo.toString();
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _deviceInfo = 'Error getting device info';
      });
    }
  }

  Future<void> _toggleCapture() async {
    if (_isCapturing) {
      await _audioCapture.stop();
      setState(() {
        _isCapturing = false;
        _status = 'Stopped';
        _audioBytesReceived = 0;
        _audioLevel = 0.0;
      });
    } else {
      final success = await _audioCapture.requestPermissionAndStart(sampleRate: 16000);
      if (success) {
        setState(() {
          _isCapturing = true;
          _status = 'Capturing...';
        });
        
        // Listen to audio stream
        _audioCapture.audioStream.listen((audioData) {
          setState(() {
            _audioBytesReceived += audioData.length;
            // Calculate simple audio level (RMS approximation)
            _audioLevel = _calculateAudioLevel(audioData);
          });
        });
      } else {
        setState(() {
          _status = 'Permission denied or failed';
        });
      }
    }
  }

  double _calculateAudioLevel(List<int> audioData) {
    if (audioData.isEmpty) return 0.0;
    
    // Simple RMS calculation for audio level visualization
    double sum = 0.0;
    for (int i = 0; i < audioData.length; i += 2) {
      // 16-bit PCM, skip every other byte for simplicity
      if (i + 1 < audioData.length) {
        final sample = (audioData[i + 1] << 8) | audioData[i];
        // Convert to signed 16-bit
        final signedSample = sample > 32767 ? sample - 65536 : sample;
        sum += signedSample * signedSample;
      }
    }
    
    final rms = (sum / (audioData.length / 2)).abs();
    return (rms / 32768.0) * 100.0; // Normalize to 0-100
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Audio Capture Test'),
        backgroundColor: const Color(0xFF0D0D12),
      ),
      body: Container(
        color: const Color(0xFF0D0D12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: const Color(0xFF14141C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isAvailable ? Icons.check_circle : Icons.error,
                          color: _isAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Screen Audio Capture',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: $_status',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isAvailable ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Device Info
            Card(
              color: const Color(0xFF14141C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _deviceInfo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Capture Control
            Card(
              color: const Color(0xFF14141C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isAvailable ? _toggleCapture : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCapturing ? Colors.red : Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        _isCapturing ? 'Stop Capture' : 'Start Capture',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Audio Stats
            Card(
              color: const Color(0xFF14141C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Audio Level Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audio Level',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: _audioLevel / 100.0,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Bytes Received
                    Text(
                      'Bytes Received: $_audioBytesReceived',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Sample Rate: ${_audioCapture.sampleRate} Hz',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Card(
              color: const Color(0xFF14141C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Start a phone call\n'
                      '2. Enable screen capture\n'
                      '3. Speak during the call\n'
                      '4. Watch audio level indicator\n'
                      '5. If audio level rises, capture is working',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}