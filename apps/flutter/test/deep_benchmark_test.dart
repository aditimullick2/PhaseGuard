import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/utils/test_dataset.dart';
import 'package:phaseguard/services/model_comparator.dart';
import 'package:phaseguard/services/llama_scam_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Run Deep Benchmark in Terminal', () async {
    print('==================================================');
    print('🚀 STARTING DEEP BENCHMARK (Terminal Mode) 🚀');
    print('==================================================\n');

    final llama = LlamaScamDetector();
    final comparator = ModelComparator(llama);

    // 1. Rule-Based
    print('🟢 Running Rule-Based Engine (Fast)...');
    final ruleRes = await comparator.runRuleBasedTest();
    print('✅ Rule-Based Done!');
    print('   Accuracy: ${ruleRes.accuracy.toStringAsFixed(1)}% (${ruleRes.passedTests}/${ruleRes.totalTests})');
    print('   Total Time: ${ruleRes.totalTimeMs}ms (Avg: ${ruleRes.avgTimePerTestMs.toStringAsFixed(1)}ms / test)\n');

    // 2. LLM
    print('🟣 Running Local LLM (SmolLM2-135M)...');
    print('   (Loading model and running inferences, this may take time...)');
    
    try {
      final llmRes = await comparator.runLocalLLMTest((current, total) {
        print('   -> LLM Inference: $current / $total');
      });

      print('\n✅ LLM Done!');
      print('   Accuracy: ${llmRes.accuracy.toStringAsFixed(1)}% (${llmRes.passedTests}/${llmRes.totalTests})');
      print('   Total Time: ${llmRes.totalTimeMs}ms (Avg: ${llmRes.avgTimePerTestMs.toStringAsFixed(1)}ms / test)\n');

      print('==================================================');
      print('🏆 FINAL COMPARISON 🏆');
      print('==================================================');
      print('Rule-Based: ${ruleRes.accuracy.toStringAsFixed(1)}% Accuracy | ${ruleRes.avgTimePerTestMs.toStringAsFixed(1)}ms avg speed');
      print('Local LLM:  ${llmRes.accuracy.toStringAsFixed(1)}% Accuracy | ${llmRes.avgTimePerTestMs.toStringAsFixed(1)}ms avg speed');
      
      print('\nFailed Test Cases (Rule-Based):');
      for (var res in ruleRes.executionDetails.where((r) => !r.isPass)) {
        print(' - [${res.testCase.isScam ? "Expected: SCAM" : "Expected: NORMAL"}] ${res.testCase.transcript} | Result: ${res.actualCategory}');
      }

      print('\nFailed Test Cases (Local LLM):');
      for (var res in llmRes.executionDetails.where((r) => !r.isPass)) {
        print(' - [${res.testCase.isScam ? "Expected: SCAM" : "Expected: NORMAL"}] ${res.testCase.transcript} | Result: ${res.actualCategory}');
        if (res.error != null) print('   Error: ${res.error}');
      }
    } catch (e) {
      print('❌ Error running LLM in terminal test: $e');
      print('Note: NDK/C++ models sometimes fail to initialize in headless test environments depending on Windows DLL availability.');
    }
  }, timeout: const Timeout(Duration(minutes: 5))); // Allow 5 mins for LLM
}
