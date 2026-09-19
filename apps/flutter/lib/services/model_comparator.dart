import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/test_dataset.dart';
import '../services/scam_detector.dart';
import '../services/llama_scam_detector.dart';

class ModelComparisonResult {
  final String modelName;
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final double accuracy;
  final int totalTimeMs;
  final double avgTimePerTestMs;
  final List<TestExecutionResult> executionDetails;

  ModelComparisonResult({
    required this.modelName,
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.accuracy,
    required this.totalTimeMs,
    required this.avgTimePerTestMs,
    required this.executionDetails,
  });
}

class TestExecutionResult {
  final TestCase testCase;
  final bool actualIsScam;
  final String actualCategory;
  final bool isPass;
  final int timeTakenMs;
  final String? error;

  TestExecutionResult({
    required this.testCase,
    required this.actualIsScam,
    required this.actualCategory,
    required this.isPass,
    required this.timeTakenMs,
    this.error,
  });
}

class ModelComparator {
  final LlamaScamDetector _llamaDetector;

  ModelComparator(this._llamaDetector);

  Future<ModelComparisonResult> runRuleBasedTest() async {
    int passed = 0;
    int failed = 0;
    int totalTime = 0;
    List<TestExecutionResult> details = [];

    for (var testCase in TestDataset.cases) {
      final stopwatch = Stopwatch()..start();
      bool actualIsScam = false;
      String actualCategory = "UNKNOWN";
      String? errorMsg;
      bool isPass = false;

      try {
        // Run rule-based detection
        final result = ScamDetector.detectScam(testCase.transcript);
        actualIsScam = result.isScam;
        actualCategory = result.category;
        
        // Evaluate pass/fail based on isScam flag matching expected
        isPass = (actualIsScam == testCase.isScam);
        if (isPass) {
          passed++;
        } else {
          failed++;
        }
      } catch (e) {
        errorMsg = e.toString();
        failed++;
      }

      stopwatch.stop();
      final timeTaken = stopwatch.elapsedMilliseconds;
      totalTime += timeTaken;

      details.add(TestExecutionResult(
        testCase: testCase,
        actualIsScam: actualIsScam,
        actualCategory: actualCategory,
        isPass: isPass,
        timeTakenMs: timeTaken,
        error: errorMsg,
      ));
      
      // Small delay to prevent UI freeze
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return ModelComparisonResult(
      modelName: "Rule-Based Engine",
      totalTests: TestDataset.cases.length,
      passedTests: passed,
      failedTests: failed,
      accuracy: (passed / TestDataset.cases.length) * 100,
      totalTimeMs: totalTime,
      avgTimePerTestMs: totalTime / TestDataset.cases.length,
      executionDetails: details,
    );
  }

  Future<ModelComparisonResult> runLocalLLMTest(Function(int, int) onProgress) async {
    int passed = 0;
    int failed = 0;
    int totalTime = 0;
    List<TestExecutionResult> details = [];

    if (!_llamaDetector.isLoaded) {
      await _llamaDetector.loadModel();
    }

    int currentTest = 0;
    for (var testCase in TestDataset.cases) {
      currentTest++;
      onProgress(currentTest, TestDataset.cases.length);
      
      final stopwatch = Stopwatch()..start();
      bool actualIsScam = false;
      String actualCategory = "UNKNOWN";
      String? errorMsg;
      bool isPass = false;

      try {
        // Run LLM detection
        final result = await _llamaDetector.detectScam(testCase.transcript);
        actualIsScam = result['is_scam'] == true;
        actualCategory = result['category'] ?? "UNKNOWN";
        
        // Ensure result actually came from LLM, not rule-based fallback
        if (result['source'] != 'local_llm') {
          errorMsg = "Fell back to rule-based";
        }
        
        isPass = (actualIsScam == testCase.isScam);
        if (isPass) {
          passed++;
        } else {
          failed++;
        }
      } catch (e) {
        errorMsg = e.toString();
        failed++;
      }

      stopwatch.stop();
      final timeTaken = stopwatch.elapsedMilliseconds;
      totalTime += timeTaken;

      details.add(TestExecutionResult(
        testCase: testCase,
        actualIsScam: actualIsScam,
        actualCategory: actualCategory,
        isPass: isPass,
        timeTakenMs: timeTaken,
        error: errorMsg,
      ));
    }

    return ModelComparisonResult(
      modelName: "Local LLM (SmolLM2-135M)",
      totalTests: TestDataset.cases.length,
      passedTests: passed,
      failedTests: failed,
      accuracy: (passed / TestDataset.cases.length) * 100,
      totalTimeMs: totalTime,
      avgTimePerTestMs: totalTime / TestDataset.cases.length,
      executionDetails: details,
    );
  }
}
