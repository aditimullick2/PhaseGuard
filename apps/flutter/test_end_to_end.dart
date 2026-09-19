import 'dart:io';
import 'lib/services/hybrid_scam_detector.dart';

void main() async {
  final detector = HybridScamDetector();
  
  print('\n--- DEEP END-TO-END PIPELINE TEST ---\n');

  // Scenario 1: Basic Rule-Based Hit (Should return fast, local)
  print('SCENARIO 1: Basic Keyword Hit (Rule-Based Test)');
  print('Input: "CBI digital arrest warrant issued"');
  final res1 = await detector.detectScam('CBI digital arrest warrant issued');
  print('Result Source: \${res1['source']}');
  print('Is Scam: \${res1['is_scam']}');
  print('Reasoning: \${res1['reasoning']}\n');

  // Scenario 2: Twisted Scam passing Rule-Based, hitting Web Fact Check
  print('SCENARIO 2: Advanced FedEx Customs Scam (Web API Fallback)');
  print('Input: "Hello, your FedEx package is held at customs. Please pay the clearance fee."');
  final res2 = await detector.detectScam('Hello, your FedEx package is held at customs. Please pay the clearance fee.');
  print('Result Source: \${res2['source']}');
  print('Is Scam: \${res2['is_scam']}');
  print('Reasoning: \${res2['reasoning']}\n');

  // Scenario 3: Legitimate Complex Notification
  print('SCENARIO 3: Legitimate Bank Notification');
  print('Input: "Hello, HDFC bank reminding you of your due date next week."');
  final res3 = await detector.detectScam('Hello, HDFC bank reminding you of your due date next week.');
  print('Result Source: \${res3['source']}');
  print('Is Scam: \${res3['is_scam']}');
  print('Reasoning: \${res3['reasoning']}\n');
  
  if (res2['source'] == 'web') {
    print('✅ SUCCESS: System successfully fell back to Web API for complex scam fact-checking!');
  } else {
    print('❌ FAILED: Did not hit the web API fallback for scenario 2.');
  }
}
