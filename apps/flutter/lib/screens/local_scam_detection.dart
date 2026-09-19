import 'dart:async';
import 'package:flutter/material.dart';
import '../services/llama_scam_detector.dart';
import '../services/scam_detector.dart';
import '../theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';

class LocalScamDetectionScreen extends StatefulWidget {
  const LocalScamDetectionScreen({super.key});

  @override
  State<LocalScamDetectionScreen> createState() =>
      _LocalScamDetectionScreenState();
}

class _LocalScamDetectionScreenState extends State<LocalScamDetectionScreen> {
  final TextEditingController _transcriptController = TextEditingController();
  final LlamaScamDetector _llamaDetector = LlamaScamDetector();

  Map<String, dynamic>? _lastResult;
  bool _isAnalyzing = false;

  // Model download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _modelReady = false;
  String _modelSource = 'checking...';

  StreamSubscription<double>? _progressSub;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    // Check if model already copied to storage
    final ready = await _llamaDetector.isModelReady();

    if (ready) {
      setState(() {
        _modelSource = 'local_llm (device storage)';
      });
      // Load silently in background
      await _llamaDetector.loadModel();
      if (mounted) {
        setState(() {
          _modelReady = _llamaDetector.isLoaded;
          _modelSource = _modelReady ? 'local_llm ✅' : 'rule_based_fallback';
        });
      }
    } else {
      // Need to copy from assets — subscribe to progress stream
      _progressSub = _llamaDetector.copyProgress.listen((progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _isDownloading = progress < 1.0;
          });
        }
      });

      setState(() {
        _isDownloading = true;
        _modelSource = 'copying model from app assets...';
      });

      await _llamaDetector.loadModel();

      await _progressSub?.cancel();

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _modelReady = _llamaDetector.isLoaded;
          _modelSource = _modelReady
              ? 'local_llm ✅ (TinyLlama-1.1B Q4)'
              : 'rule_based_fallback (download failed)';
        });
      }
    }
  }

  Future<void> _analyzeTranscript() async {
    if (_transcriptController.text.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _lastResult = null;
    });

    Map<String, dynamic> result;

    if (_modelReady) {
      // Real LLM inference
      result = await _llamaDetector.detectScam(_transcriptController.text);
    } else {
      // Rule-based fallback while model loads/downloads
      await Future.delayed(const Duration(milliseconds: 80));
      final scamResult = ScamDetector.detectScam(_transcriptController.text);
      result = {
        'is_scam': scamResult.isScam,
        'category': scamResult.category,
        'reasoning': scamResult.reasoning,
        'confidence': scamResult.isScam ? 0.85 : 0.10,
        'source': 'rule_based_fallback',
      };
    }

    if (mounted) {
      setState(() {
        _lastResult = result;
        _isAnalyzing = false;
      });
    }
  }

  void _testWithExample(String transcript) {
    _transcriptController.text = transcript;
    _analyzeTranscript();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Scam Detection'),
        backgroundColor: PgColors.primary,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: PgColors.screenGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PgSpace.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Model Status Banner ────────────────────────────────────
                _buildModelStatusBanner(),
                const SizedBox(height: PgSpace.l),

                // ── Transcript Input ───────────────────────────────────────
                const SectionTitle('Transcript Analysis'),
                const SizedBox(height: PgSpace.m),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _transcriptController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Enter call transcript here...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: PgSpace.m),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isAnalyzing || _isDownloading)
                              ? null
                              : _analyzeTranscript,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PgColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _isAnalyzing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _modelReady
                                      ? 'Analyze with LLM'
                                      : 'Analyze (Rule-based)',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PgSpace.l),

                // ── Quick Examples ─────────────────────────────────────────
                const SectionTitle('Quick Test Examples'),
                const SizedBox(height: PgSpace.m),
                _buildExampleButton('RBI Scam',
                    'Hello this is calling from RBI. Your bank account has been linked to illegal transactions. Please transfer your money to our secure account immediately.'),
                _buildExampleButton('Legitimate Bank',
                    'Hello, this is calling from HDFC Bank customer service. We are calling to inform you about your new credit card benefits.'),
                _buildExampleButton('Family Emergency',
                    'Hello beta, this is your uncle speaking. I am in the hospital and need urgent money for surgery.'),
                _buildExampleButton('Digital Arrest',
                    'Main CBI officer bol raha hoon. Aapke naam pe illegal transaction pakdi gayi hai. Digital arrest warrant issue ho gaya hai.'),
                const SizedBox(height: PgSpace.l),

                // ── Result ────────────────────────────────────────────────
                if (_lastResult != null) ...[
                  const SectionTitle('Analysis Result'),
                  const SizedBox(height: PgSpace.m),
                  _buildResultCard(_lastResult!),
                ],
                const SizedBox(height: PgSpace.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelStatusBanner() {
    if (_isDownloading) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: PgSpace.s),
                const Expanded(
                  child: Text(
                    'Downloading TinyLlama model (one-time)...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: PgSpace.s),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey.shade300,
              color: PgColors.primary,
            ),
            const SizedBox(height: PgSpace.s),
            const Text(
              '~670 MB download (Wi-Fi recommended). Rule-based detection active meanwhile.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final color = _modelReady ? Colors.green : Colors.orange;
    final icon = _modelReady ? '🧠' : '⚡';
    final label = _modelReady
        ? 'TinyLlama-1.1B Q4 — On-device LLM active'
        : 'Rule-based detector active (model loading...)';

    return GlassCard(
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: PgSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  'Source: $_modelSource',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final isScam = result['is_scam'] == true;
    final category = result['category'] ?? 'UNKNOWN';
    final reasoning = result['reasoning'] ?? '';
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final source = result['source'] ?? 'unknown';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verdict
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: PgSpace.s, horizontal: PgSpace.m),
            decoration: BoxDecoration(
              color: isScam
                  ? Colors.red.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isScam ? Colors.red : Colors.green, width: 1),
            ),
            child: Text(
              isScam ? '🚨 SCAM DETECTED' : '✅ LOOKS LEGITIMATE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isScam ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: PgSpace.m),
          _buildRow('Category', category),
          _buildRow(
              'Confidence', '${(confidence * 100).toStringAsFixed(0)}%'),
          _buildRow('Source', source),
          const SizedBox(height: PgSpace.s),
          const Divider(),
          const SizedBox(height: PgSpace.s),
          Text(
            reasoning,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PgSpace.s),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildExampleButton(String label, String transcript) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PgSpace.s),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _testWithExample(transcript),
          style: OutlinedButton.styleFrom(
            foregroundColor: PgColors.primary,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _llamaDetector.dispose();
    _transcriptController.dispose();
    super.dispose();
  }
}
