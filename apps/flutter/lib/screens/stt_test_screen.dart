import 'package:flutter/material.dart';

/// SttTestScreen — STT Testing UI for Flutter App
///
/// This screen allows testing:
/// 1. Local STT (Whisper TFLite)
/// 2. Backend STT (Groq Whisper)
/// 3. Hybrid STT (Local + Backend)
class SttTestScreen extends StatefulWidget {
  const SttTestScreen({super.key});

  @override
  State<SttTestScreen> createState() => _SttTestScreenState();
}

class _SttTestScreenState extends State<SttTestScreen> {
  // final OfflineSttService _offlineStt = OfflineSttService();
  // final HybridSttService _hybridStt = HybridSttService();

  bool _isOfflineInitialized = false;
  final bool _isProcessing = false;
  String _transcript = '';
  String _source = '';
  String _status = 'STT services not available';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() => _status = 'Initializing offline STT...');
    
    const offlineInit = false; // Mocked
    setState(() {
      _isOfflineInitialized = offlineInit;
      _status = 'Offline STT Failed';
    });
  }

  Future<void> _testOfflineStt() async {
    if (!_isOfflineInitialized) {
      _showError('Offline STT not initialized');
      return;
    }

    setState(() => _status = 'Testing offline STT...');

    try {
      // Use app assets for testing
      // final result = await _offlineStt.transcribeAudioFile(
      //   'assets/models/test_audio.mp3'
      // );
      const result = 'Mock offline transcript';

      setState(() {
        _transcript = result;
        _source = 'Local (Whisper TFLite)';
        _status = 'Done';
      });
    } catch (e) {
      _showError('Offline STT error: $e');
    }
  }

  Future<void> _testBackendStt() async {
    setState(() => _status = 'Testing backend STT...');

    try {
      // Test with a simple message
      setState(() {
        _transcript = 'Backend STT test (requires actual audio file)';
        _source = 'Backend (Groq Whisper)';
        _status = 'Demo Mode';
      });
    } catch (e) {
      _showError('Backend STT error: $e');
    }
  }

  Future<void> _testHybridStt() async {
    setState(() => _status = 'Testing hybrid STT...');

    try {
      setState(() {
        _transcript = 'Hybrid STT test (requires actual audio file)';
        _source = 'Hybrid (Local + Backend)';
        _status = 'Demo Mode';
      });
    } catch (e) {
      _showError('Hybrid STT error: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _status = 'Error';
      _transcript = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STT Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isOfflineInitialized 
                            ? Icons.check_circle 
                            : Icons.error,
                          color: _isOfflineInitialized 
                            ? Colors.green 
                            : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOfflineInitialized 
                            ? 'Offline STT Initialized' 
                            : 'Offline STT Not Ready',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Buttons
            ElevatedButton(
              onPressed: _isProcessing ? null : _testOfflineStt,
              child: const Text('Test Offline STT (Whisper TFLite)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isProcessing ? null : _testBackendStt,
              child: const Text('Test Backend STT (Groq Whisper)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isProcessing ? null : _testHybridStt,
              child: const Text('Test Hybrid STT (Local + Backend)'),
            ),
            const SizedBox(height: 16),

            // Transcript Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source: $_source',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _transcript.isEmpty 
                        ? 'No transcript yet' 
                        : _transcript,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For Real Testing on Android Device:\n'
                      '1. Connect Android phone via USB\n'
                      '2. Run: flutter run\n'
                      '3. Place test_audio.mp3 in app storage\n'
                      '4. Navigate to Settings → Test Local STT\n'
                      '5. Test each STT method\n\n'
                      'Current Status:\n'
                      '- Whisper TFLite model: READY (40.49 MB)\n'
                      '- Backend STT: Working (Groq Whisper)\n'
                      '- Local STT: Needs audio preprocessing setup',
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

  @override
  void dispose() {
    super.dispose();
  }
}
