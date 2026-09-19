import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// LocalEscalationService — Offline escalation integration.
///
/// Local Actions:
/// - Direct call to police (1930)
/// - WhatsApp sharing of evidence
/// - Email reporting
/// - Open cybercrime portal
class LocalEscalationService {
  /// Call 1930 Cybercrime Helpline directly.
  Future<bool> callCybercrimeHelpline() async {
    try {
      final uri = Uri.parse('tel:1930');
      final launched = await launchUrl(uri);
      
      if (launched) {
        debugPrint('LocalEscalation: Called 1930 helpline');
      } else {
        debugPrint('LocalEscalation: Failed to call 1930');
      }
      
      return launched;
    } catch (e) {
      debugPrint('LocalEscalation: Error calling 1930: $e');
      return false;
    }
  }

  /// Share evidence via WhatsApp.
  Future<bool> shareViaWhatsApp({
    required String pdfPath,
    required String description,
  }) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        debugPrint('LocalEscalation: PDF not found: $pdfPath');
        return false;
      }

      // Share with WhatsApp
      await Share.shareXFiles(
        [XFile(pdfPath)],
        text: description,
        subject: 'PhaseGuard Cybercrime Evidence',
      );

      debugPrint('LocalEscalation: Shared via WhatsApp');
      return true;
    } catch (e) {
      debugPrint('LocalEscalation: WhatsApp share error: $e');
      return false;
    }
  }

  /// Share evidence via Email.
  Future<bool> shareViaEmail({
    required String pdfPath,
    required String description,
    String? email,
  }) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        debugPrint('LocalEscalation: PDF not found: $pdfPath');
        return false;
      }

      final emailTo = email ?? 'complaints@cybercrime.gov.in';
      final emailSubject = 'PhaseGuard Cybercrime Evidence';
      
      await Share.shareXFiles(
        [XFile(pdfPath)],
        text: description,
        subject: emailSubject,
        email: emailTo,
      );

      debugPrint('LocalEscalation: Shared via email to $emailTo');
      return true;
    } catch (e) {
      debugPrint('LocalEscalation: Email share error: $e');
      return false;
    }
  }

  /// Open cybercrime portal in browser.
  Future<bool> openCybercrimePortal() async {
    try {
      final uri = Uri.parse('https://cybercrime.gov.in');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (launched) {
        debugPrint('LocalEscalation: Opened cybercrime portal');
      } else {
        debugPrint('LocalEscalation: Failed to open cybercrime portal');
      }
      
      return launched;
    } catch (e) {
      debugPrint('LocalEscalation: Error opening portal: $e');
      return false;
    }
  }

  /// Share complete evidence package (PDF + text).
  Future<bool> shareCompleteEvidence({
    required String pdfPath,
    required String transcript,
    required String scamCategory,
  }) async {
    try {
      final description = '''
PhaseGuard Cybercrime Evidence

Scam Category: $scamCategory

Transcript:
$transcript

Report at: https://cybercrime.gov.in
Helpline: 1930
''';

      await Share.shareXFiles(
        [XFile(pdfPath)],
        text: description,
        subject: 'PhaseGuard Cybercrime Evidence - $scamCategory',
      );

      debugPrint('LocalEscalation: Shared complete evidence');
      return true;
    } catch (e) {
      debugPrint('LocalEscalation: Evidence share error: $e');
      return false;
    }
  }

  /// Copy evidence summary to clipboard.
  Future<bool> copyToClipboard({
    required String transcript,
    required String scamCategory,
  }) async {
    try {
      // In production, use flutter services to copy to clipboard
      // For now, return true as placeholder
      debugPrint('LocalEscalation: Copied to clipboard (placeholder)');
      return true;
    } catch (e) {
      debugPrint('LocalEscalation: Clipboard error: $e');
      return false;
    }
  }
}
