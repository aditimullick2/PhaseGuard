import 'package:flutter/material.dart';
import '../services/llama_scam_detector.dart';
import '../services/model_comparator.dart';
import '../theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';

class DeepTestScreen extends StatefulWidget {
  const DeepTestScreen({super.key});

  @override
  State<DeepTestScreen> createState() => _DeepTestScreenState();
}

class _DeepTestScreenState extends State<DeepTestScreen> {
  final LlamaScamDetector _llamaDetector = LlamaScamDetector();
  late ModelComparator _comparator;

  bool _isRunning = false;
  String _statusText = 'Ready to start deep test...';
  double _progress = 0.0;

  ModelComparisonResult? _ruleBasedResult;
  ModelComparisonResult? _llmResult;

  @override
  void initState() {
    super.initState();
    _comparator = ModelComparator(_llamaDetector);
  }

  Future<void> _runDeepTest() async {
    setState(() {
      _isRunning = true;
      _ruleBasedResult = null;
      _llmResult = null;
      _progress = 0.0;
      _statusText = 'Running Rule-Based Engine (Fast)...';
    });

    // 1. Run Rule-Based
    final ruleBased = await _comparator.runRuleBasedTest();
    if (mounted) {
      setState(() {
        _ruleBasedResult = ruleBased;
        _statusText = 'Rule-Based done. Starting Local LLM Inference (This will take a while)...';
      });
    }

    // 2. Run Local LLM
    final llm = await _comparator.runLocalLLMTest((current, total) {
      if (mounted) {
        setState(() {
          _progress = current / total;
          _statusText = 'LLM Inference: Test $current of $total...';
        });
      }
    });

    if (mounted) {
      setState(() {
        _llmResult = llm;
        _isRunning = false;
        _statusText = 'Deep Testing Complete!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Test Lab'),
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(PgSpace.screenH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_ruleBasedResult != null || _llmResult != null)
                        _buildComparisonDashboard(),
                      
                      const SizedBox(height: PgSpace.l),
                      
                      if (_ruleBasedResult != null && _llmResult != null)
                        _buildDetailedResultsList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GlassCard(
      margin: const EdgeInsets.all(PgSpace.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Benchmarking Models'),
          const SizedBox(height: PgSpace.s),
          const Text(
            'This will run 30 diverse test cases (15 scams, 15 normal) against both the rule-based engine and the on-device SmolLM2 LLM.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: PgSpace.m),
          if (_isRunning) ...[
            Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, color: PgColors.primary)),
            const SizedBox(height: PgSpace.s),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ] else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('START DEEP TEST'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PgColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _runDeepTest,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildComparisonDashboard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildModelResultCard(
            'Rule-Based',
            _ruleBasedResult,
            Colors.blue,
          ),
        ),
        const SizedBox(width: PgSpace.s),
        Expanded(
          child: _buildModelResultCard(
            'Local LLM',
            _llmResult,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildModelResultCard(String title, ModelComparisonResult? result, Color themeColor) {
    if (result == null) {
      return GlassCard(
        padding: const EdgeInsets.all(PgSpace.m),
        child: Center(
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: PgSpace.m),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(PgSpace.m),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16)),
          const Divider(),
          const SizedBox(height: PgSpace.s),
          
          // Accuracy Circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: result.accuracy / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: _getAccuracyColor(result.accuracy),
                ),
              ),
              Text(
                '${result.accuracy.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          
          const SizedBox(height: PgSpace.m),
          _buildStatRow('Passed', '${result.passedTests}/${result.totalTests}', Icons.check_circle, Colors.green),
          _buildStatRow('Failed', '${result.failedTests}', Icons.cancel, Colors.red),
          _buildStatRow('Avg Time', '${result.avgTimePerTestMs.toStringAsFixed(0)} ms', Icons.timer, Colors.orange),
          _buildStatRow('Total', '${(result.totalTimeMs / 1000).toStringAsFixed(1)} s', Icons.schedule, Colors.blueGrey),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDetailedResultsList() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Detailed Analysis'),
          const SizedBox(height: PgSpace.m),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ruleBasedResult!.executionDetails.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final ruleRes = _ruleBasedResult!.executionDetails[index];
              final llmRes = _llmResult!.executionDetails[index];
              final isExpectedScam = ruleRes.testCase.isScam;
              
              return ExpansionTile(
                title: Text(
                  'Test ${index + 1}: ${isExpectedScam ? "Scam" : "Normal"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  ruleRes.testCase.transcript,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                leading: Icon(
                  isExpectedScam ? Icons.warning : Icons.verified,
                  color: isExpectedScam ? Colors.red : Colors.green,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(PgSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transcript: "${ruleRes.testCase.transcript}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                        const SizedBox(height: PgSpace.m),
                        
                        // Rule-based result row
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ruleRes.isPass ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: ruleRes.isPass ? Colors.green : Colors.red),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Rule-Based: ${ruleRes.actualIsScam ? "SCAM" : "NORMAL"} (${ruleRes.actualCategory})', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('${ruleRes.timeTakenMs}ms', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: PgSpace.s),
                        
                        // LLM result row
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: llmRes.isPass ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: llmRes.isPass ? Colors.green : Colors.red),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Local LLM: ${llmRes.actualIsScam ? "SCAM" : "NORMAL"} (${llmRes.actualCategory})', 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('${llmRes.timeTakenMs}ms', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              if (llmRes.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Error: ${llmRes.error}', style: const TextStyle(color: Colors.red, fontSize: 10)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _llamaDetector.dispose();
    super.dispose();
  }
}
