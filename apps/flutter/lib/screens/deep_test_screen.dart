import 'package:flutter/material.dart';
// import '../services/llama_scam_detector.dart';
// import '../services/model_comparator.dart';
import '../theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';

class DeepTestScreen extends StatefulWidget {
  const DeepTestScreen({super.key});

  @override
  State<DeepTestScreen> createState() => _DeepTestScreenState();
}

class _DeepTestScreenState extends State<DeepTestScreen> {
  // TODO: Implement deep test functionality when service files are available
  bool _isRunning = false;
  String _statusText = 'Deep test feature not yet implemented';

  Future<void> _runDeepTest() async {
    setState(() {
      _isRunning = true;
      _statusText = 'Feature coming soon...';
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isRunning = false;
        _statusText = 'Deep test feature not yet implemented';
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
                      const SizedBox(height: PgSpace.l),
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
            'Deep test feature coming soon. This will benchmark different scam detection models.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: PgSpace.m),
          if (_isRunning) ...[
            Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, color: PgColors.primary)),
            const SizedBox(height: PgSpace.s),
            const LinearProgressIndicator(),
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
}
