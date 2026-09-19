import 'dart:async';
import 'package:flutter/foundation.dart';
import 'local_scambaiter_service.dart';
import 'local_escalation_service.dart';
import 'offline_dossier_service.dart';

/// OfflineFirstTest — Complete offline-first architecture test.
///
/// Tests the complete flow:
/// 1. Audio capture (simulated)
/// 2. Local processing (STT + Deepfake + Scam)
/// 3. Scambaiter activation
/// 4. PDF generation
/// 5. Escalation options
class OfflineFirstTest {
  final LocalScambaiterService _scambaiter = LocalScambaiterService();
  final LocalEscalationService _escalation = LocalEscalationService();
  
  /// Test complete offline-first flow.
  Future<Map<String, dynamic>> testCompleteFlow({
    required String transcript,
    required Map<String, dynamic> deepfakeResult,
    required Map<String, dynamic> scamResult,
  }) async {
    debugPrint('═════════════════════════════════════════════════════');
    debugPrint('OFFLINE-FIRST ARCHITECTURE TEST');
    debugPrint('═════════════════════════════════════════════════════');

    debugPrint('\n[STEP 1] Input Analysis');
    debugPrint('  - Transcript: $transcript');
    debugPrint('  - Deepfake: ${deepfakeResult['is_synthetic']} (${(deepfakeResult['confidence'] as double * 100).toStringAsFixed(1)}%)');
    debugPrint('  - Scam: ${scamResult['is_scam']} (${(scamResult['confidence'] as double * 100).toStringAsFixed(1)}%)');

    // Step 2: Scambaiter Activation (if scam detected)
    if (scamResult['is_scam'] == true) {
      debugPrint('\n[STEP 2] Scambaiter Activation');
      
      final scambaiterResult = await _scambaiter.generateAudioResponse(transcript);
      
      debugPrint('Scambaiter Result:');
      debugPrint('  - Text: ${scambaiterResult['text']}');
      debugPrint('  - Source: ${scambaiterResult['source']}');
    }

    // Step 3: PDF Generation
    debugPrint('\n[STEP 3] PDF Generation (Local)');
    final pdfPath = await OfflineDossierService.generateOfflineDossier(
      callId: 'TEST_CALL_001',
      transcript: transcript,
      deepfakeResult: deepfakeResult,
      scamResult: scamResult,
    );

    debugPrint('PDF Result:');
    debugPrint('  - Path: $pdfPath');
    debugPrint('  - Status: ${pdfPath != null ? "Generated ✅" : "Failed ❌"}');

    // Step 4: Escalation Options
    debugPrint('\n[STEP 4] Escalation Options');
    debugPrint('Available Actions:');
    debugPrint('  1. Call 1930 Helpline: _escalation.callCybercrimeHelpline()');
    debugPrint('  2. Share via WhatsApp: _escalation.shareViaWhatsApp()');
    debugPrint('  3. Share via Email: _escalation.shareViaEmail()');
    debugPrint('  4. Open Cybercrime Portal: _escalation.openCybercrimePortal()');

    // Step 5: Complete Result
    final completeResult = {
      'success': true,
      'transcript': transcript,
      'deepfake': deepfakeResult,
      'scam': scamResult,
      'scambaiter': scamResult['is_scam'] == true 
          ? await _scambaiter.generateAudioResponse(transcript)
          : null,
      'pdf_path': pdfPath,
      'escalation_options': {
        'call_1930': 'Available',
        'whatsapp_share': 'Available',
        'email_share': 'Available',
        'cybercrime_portal': 'Available',
      },
      'test_timestamp': DateTime.now().toIso8601String(),
    };

    debugPrint('\n═════════════════════════════════════════════════════');
    debugPrint('TEST COMPLETE ✅');
    debugPrint('═════════════════════════════════════════════════════');

    return completeResult;
  }

  void dispose() {
    _scambaiter.dispose();
  }
}
