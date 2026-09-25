import 'dart:async';
import 'package:flutter/material.dart';
// import '../services/llama_scam_detector.dart';
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

  Map<String, dynamic>? _lastResult;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _analyzeTranscript() async {
    if (_transcriptController.text.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _lastResult = null;
    });

    // Use rule-based detection
    await Future.delayed(const Duration(milliseconds: 80));
    final scamResult = ScamDetector.detectScam(_transcriptController.text);
    final result = {
      'is_scam': scamResult.isScam,
      'category': scamResult.category,
      'reasoning': scamResult.reasoning,
      'confidence': scamResult.isScam ? 0.85 : 0.10,
      'source': 'rule_based',
    };

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
                          onPressed: _isAnalyzing
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
                              : const Text('Analyze (Rule-based)'),
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: PgColors.primary),
              const SizedBox(width: PgSpace.s),
              const Expanded(
                child: Text(
                  'Local LLM model not available - using rule-based detection',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.s),
          const Text(
            'Rule-based scam detection is active. Local LLM integration coming soon.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
    _transcriptController.dispose();
    super.dispose();
  }
}
