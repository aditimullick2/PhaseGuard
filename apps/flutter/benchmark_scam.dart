import 'dart:convert';
import 'dart:io';
import 'lib/services/scam_detector.dart';

void main() async {
  final file = File('../api/ai_training/dataset.jsonl');
  if (!await file.exists()) {
    print('Dataset not found!');
    return;
  }
  
  final lines = await file.readAsLines();
  int total = 0;
  int correct = 0;
  int truePositives = 0;
  int falsePositives = 0;
  int trueNegatives = 0;
  int falseNegatives = 0;
  
  print('Loading dataset of ${lines.length} samples...');
  
  final stopwatch = Stopwatch()..start();
  
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    
    try {
      final json = jsonDecode(line);
      final input = json['input'] as String;
      
      // Parse output format, it might be a JSON string or object
      bool expectedIsScam;
      if (json['output'] is String) {
        final outJson = jsonDecode(json['output']);
        expectedIsScam = outJson['is_scam'] == true;
      } else {
        expectedIsScam = json['output']['is_scam'] == true;
      }
      
      // Run detection
      final result = ScamDetector.detectScam(input);
      final actualIsScam = result.isScam;
      
      total++;
      if (actualIsScam == expectedIsScam) {
        correct++;
        if (actualIsScam) {
          truePositives++;
        } else {
          trueNegatives++;
        }
      } else {
        if (actualIsScam) {
          falsePositives++;
        } else {
          falseNegatives++;
        }
      }
    } catch (e) {
      print('Error parsing line: $e');
    }
  }
  
  stopwatch.stop();
  final elapsedMs = stopwatch.elapsedMilliseconds;
  final avgMs = elapsedMs / total;
  
  print('\n===== BENCHMARK RESULTS =====');
  print('Total Scenarios Tested: $total');
  print('Correct Predictions: $correct');
  print('Accuracy: ${(correct / total * 100).toStringAsFixed(2)}%');
  print('');
  print('True Positives (Scams caught): $truePositives');
  print('True Negatives (Normal passed): $trueNegatives');
  print('False Positives (Normal marked scam): $falsePositives');
  print('False Negatives (Scams missed): $falseNegatives');
  print('');
  print('Total Time: ${elapsedMs}ms');
  print('Average Time per detection: ${avgMs.toStringAsFixed(3)}ms');
  print('Speed: ${(1000 / avgMs).toStringAsFixed(0)} detections per second');
  print('=============================');
}
