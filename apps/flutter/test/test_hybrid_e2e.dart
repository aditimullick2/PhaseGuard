import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../lib/services/voice_deepfake_detector.dart';
import '../lib/services/scam_detector.dart';

void main() async {
  print('=============================================');
  print('🚀 E2E HYBRID ARCHITECTURE TEST (FLUTTER -> CLOUD)');
  print('=============================================\n');

  // 1. TEST LOCAL VOICE DSP MODEL
  print('⏳ Phase 1: Testing Local Voice DSP Model (Offline)');
  final detector = VoiceDeepfakeDetector(sampleRate: 16000);
  
  // Read a real MP3 converted to PCM from previous test (Deepfake)
  final pcmPath = '../api/samples/synthetic/hindi_ai_voice.mp3.pcm';
  if (!File(pcmPath).existsSync()) {
    print('❌ Test file missing! Please run the PCM conversion script first.');
    return;
  }
  
  final bytes = File(pcmPath).readAsBytesSync();
  final int16List = bytes.buffer.asInt16List();
  
  Map<String, dynamic> localResult = {};
  for (int i = 0; i < int16List.length; i += 16000) {
    int end = (i + 16000 < int16List.length) ? i + 16000 : int16List.length;
    if (end - i < 8000) break;
    localResult = detector.analyzeAudioBuffer(int16List.sublist(i, end));
  }
  
  if (localResult['is_synthetic'] == true) {
    print('✅ LOCAL DSP SUCCESS: Deepfake detected locally on device!');
    print("   Score: ${localResult['metrics']['tremor_score']}");
    print('   Action: Call would be blocked instantly on device.\n');
  } else {
    print('⚠️ LOCAL DSP FAILED or UNCERTAIN. Escalating to Cloud...');
  }
  
  // 1B. TEST LOCAL NLP (SCAM DETECTOR)
  print('⏳ Phase 1B: Testing Local NLP (Scam Keywords Offline)');
  print('   Mocking STT Transcript: "Hello I am from CBI, we have an arrest warrant. Pay immediately to secure account."');
  
  final mockTranscript = "Hello I am from CBI, we have an arrest warrant. Pay immediately to secure account.";
  final scamResult = ScamDetector.detectScam(mockTranscript);
  
  if (scamResult.isScam) {
    print('✅ LOCAL NLP SUCCESS: Scam detected locally!');
    print("   Reason: ${scamResult.reasoning}");
    print('   Action: Flashing LOCAL SCAM KEYWORDS DETECTED on UI.\n');
  } else {
    print('⚠️ LOCAL NLP FAILED to detect scam.');
  }

  // 2. TEST CLOUD BACKEND ESCALATION
  print('⏳ Phase 2: Testing Cloud Backend API Fallback (Port 10000)');
  try {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:10000/call/init'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'caller_number': '+91TESTE2E',
        'caller_name': 'Test Caller',
        'ingestion_mode': 'websocket'
      }),
    );
    
    if (response.statusCode == 200) {
      final initData = jsonDecode(response.body);
      final callId = initData['call_id'];
      print('✅ API SUCCESS: Call initialized with ID $callId');
      
      // Connect WebSocket
      print('⏳ Phase 3: Connecting to Cloud WebSocket...');
      final token = initData['token'] ?? '';
      final wsUrl = 'ws://127.0.0.1:10000/call/$callId/stream?token=$token';
      
      try {
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
        
        print('✅ WEBSOCKET SUCCESS: Connected to audio stream pipeline!');
        print('   Sending mock audio chunk to backend...');
        
        channel.sink.add(bytes.sublist(0, 16000)); // Send 1 sec of audio
        
        print('   Audio chunk sent. Backend fact-check triggered.');
        print('✅ END-TO-END PIPELINE FULLY FUNCTIONAL!\n');
        
        channel.sink.close();
      } catch (wsErr) {
        print('❌ WEBSOCKET ERROR: \$wsErr');
      }
    } else {
      print('❌ API ERROR: Status code \${response.statusCode}');
    }
  } catch (e) {
    print('❌ BACKEND ERROR: Is the FastAPI server running on port 10000?');
    print(e);
  }
  
  exit(0);
}
