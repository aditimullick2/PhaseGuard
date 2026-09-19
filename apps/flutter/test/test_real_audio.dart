import 'dart:io';
import 'dart:typed_data';
import '../lib/services/voice_deepfake_detector.dart';

void main() async {
  final detector = VoiceDeepfakeDetector(sampleRate: 16000);
  
  final apiPath = '../api/samples';
  
  Future<void> testDirectory(String name, String path) async {
    print('\n=========================================');
    print(' TESTING FOLDER: $name');
    print('=========================================');
    
    final dir = Directory(path);
    if (!dir.existsSync()) {
      print('Directory not found: $path');
      return;
    }
    
    final files = dir.listSync().where((f) => f.path.endsWith('.pcm')).toList();
    
    int total = files.length;
    int synthCount = 0;
    
    for (var file in files) {
      final bytes = File(file.path).readAsBytesSync();
      
      // Convert to Int16List
      final int16List = bytes.buffer.asInt16List();
      
      // Since it's a full audio file, let's process it in 1-second chunks (16000 samples)
      // to mimic the real-time buffer
      Map<String, dynamic> finalRes = {};
      
      for (int i = 0; i < int16List.length; i += 16000) {
        int end = (i + 16000 < int16List.length) ? i + 16000 : int16List.length;
        if (end - i < 8000) break; // Skip if too short
        
        final chunk = int16List.sublist(i, end);
        finalRes = detector.analyzeAudioBuffer(chunk);
      }
      
      String result = finalRes['is_synthetic'] == true ? "DEEPFAKE" : "HUMAN   ";
      double confidence = finalRes['confidence'] ?? 0.0;
      if (finalRes['is_synthetic'] == true) synthCount++;
      
      String basename = file.path.split(Platform.pathSeparator).last.replaceAll('.mp3.pcm', '');
      if (basename.length > 35) basename = basename.substring(0, 35) + '...';
      
      print('[$result] (conf: ${confidence.toStringAsFixed(2)}) - $basename');
      print("          Reason: ${finalRes['reason']}");
      print("          Metrics: ${finalRes['metrics']}");
      print('');
    }
    
    print('--- SUMMARY FOR $name ---');
    print('Total files: $total');
    print('Marked as Synthetic: $synthCount');
  }

  await testDirectory('SYNTHETIC AI VOICES', '../api/samples/synthetic');
  await testDirectory('REAL USER VOICES', '../api/samples/user_voices');
}
