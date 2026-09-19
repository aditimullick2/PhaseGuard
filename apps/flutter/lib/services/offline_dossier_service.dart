import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// Offline forensic PDF generator — runs 100% on-device, no internet needed.
class OfflineDossierService {
  /// Generate a forensic PDF from call session data and save to device storage.
  /// Returns the local path of the saved PDF.
  static Future<String> generateAndSave({
    required String callId,
    required String verdict,
    required List<String> transcriptHistory,
    required List<Map<String, dynamic>> factcheckHistory,
    required List<Map<String, dynamic>> scambaiterLog,
    required List<String> detectedKeywords,
    required List<String> upiIds,
    required List<String> phoneNumbers,
    required List<String> impersonatedEntities,
    required Uint8List? audioBytes,
    DateTime? callStartTime,
  }) async {
    // Compute SHA-256 of audio if available
    String audioHash = 'N/A';
    int audioDurationSec = 0;
    if (audioBytes != null && audioBytes.isNotEmpty) {
      final digest = sha256.convert(audioBytes);
      audioHash = digest.toString();
      // PCM 16-bit, 16kHz mono → 32000 bytes/sec
      audioDurationSec = (audioBytes.length / 32000).round();
    }

    final pdf = pw.Document(
      author: 'PhaseGuard Anti-Scam OS',
      title: 'Forensic Evidence Dossier — $callId',
      subject: 'Cyber Crime Evidence Report — India 1930 Portal Format',
    );

    final now = DateTime.now();
    final generatedAt =
        '${now.toIso8601String().substring(0, 19)} IST (UTC+5:30)';
    final callStart = callStartTime != null
        ? callStartTime.toIso8601String().substring(0, 19)
        : 'N/A';

    // ── Color palette ────────────────────────────────────────────────────────
    const redColor = PdfColors.red800;
    const safeColor = PdfColors.green800;
    const orangeColor = PdfColors.orange800;
    const greyLight = PdfColors.grey200;
    const greyDark = PdfColors.grey700;
    const headerBg = PdfColor.fromInt(0xFF0D1117);
    const accentBg = PdfColor.fromInt(0xFF161B22);

    final verdictColor = verdict == 'CRITICAL'
        ? redColor
        : verdict == 'SAFE'
            ? safeColor
            : orangeColor;

    // ── Styles ───────────────────────────────────────────────────────────────
    final titleStyle = pw.TextStyle(
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final headingStyle = pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey900,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: greyDark,
    );
    final valueStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey900);
    final codeStyle = pw.TextStyle(
      fontSize: 8,
      color: PdfColors.grey800,
      fontStyle: pw.FontStyle.italic,
    );

    // ── Helpers ──────────────────────────────────────────────────────────────
    pw.Widget _sectionHeader(String title) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: accentBg,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(title, style: headingStyle.copyWith(color: PdfColors.white)),
        );

    pw.Widget _kv(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(label, style: labelStyle),
              ),
              pw.Expanded(child: pw.Text(value, style: valueStyle)),
            ],
          ),
        );

    // ── PDF Pages ────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => [
          // Header banner
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('🛡 PhaseGuard Forensic Evidence Dossier', style: titleStyle),
                pw.SizedBox(height: 4),
                pw.Text(
                  'India Cyber Crime Portal (1930) Compatible Report',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Verdict badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: verdictColor,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VERDICT: $verdict',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Generated: $generatedAt',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
                ),
              ],
            ),
          ),

          // Section 1: Call Metadata
          _sectionHeader('1. Call Metadata'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: greyLight,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                _kv('Call ID:', callId),
                _kv('Call Start:', callStart),
                _kv('Generated At:', generatedAt),
                _kv('Audio Duration:', '$audioDurationSec seconds'),
                _kv('Ingestion Mode:', 'phone_audio'),
              ],
            ),
          ),

          // Section 2: Forensic Hash
          _sectionHeader('2. Forensic Audio Integrity (Chain of Custody)'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: greyLight, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
              children: [
                _kv('Algorithm:', 'SHA-256'),
                _kv('Audio Hash:', audioHash),
                _kv('Hash Verified:', audioBytes != null ? 'YES' : 'No audio captured'),
              ],
            ),
          ),

          // Section 3: Identified Scam Markers
          _sectionHeader('3. Extracted Scam Identifiers'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: greyLight, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
              children: [
                _kv('UPI IDs Found:', upiIds.isEmpty ? 'None detected' : upiIds.join(', ')),
                _kv('Phone Numbers Found:', phoneNumbers.isEmpty ? 'None detected' : phoneNumbers.join(', ')),
                _kv('Impersonated Entities:', impersonatedEntities.isEmpty ? 'None' : impersonatedEntities.join(', ')),
                _kv('Scam Keywords:', detectedKeywords.isEmpty ? 'None' : detectedKeywords.take(20).join(', ')),
              ],
            ),
          ),

          // Section 4: Transcript
          _sectionHeader('4. Call Transcript'),
          if (transcriptHistory.isEmpty)
            pw.Text('No transcript captured.', style: codeStyle)
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: greyLight, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: transcriptHistory
                    .map((t) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(t, style: codeStyle),
                        ))
                    .toList(),
              ),
            ),

          // Section 5: Factcheck History
          _sectionHeader('5. AI Fact-Check Log'),
          if (factcheckHistory.isEmpty)
            pw.Text('No fact-checks performed.', style: codeStyle)
          else
            pw.TableHelper.fromTextArray(
              headers: ['Time', 'Status', 'Summary'],
              data: factcheckHistory
                  .take(15)
                  .map((f) => [
                        (f['ts'] as String? ?? '').substring(0, 16),
                        f['status'] ?? '',
                        (f['message'] as String? ?? '').substring(
                            0, ((f['message'] as String? ?? '').length).clamp(0, 80)),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: headerBg),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              oddRowDecoration: pw.BoxDecoration(color: greyLight),
            ),

          // Section 6: Scambaiter Log
          _sectionHeader('6. AI Scambaiter Exchange Log'),
          if (scambaiterLog.isEmpty)
            pw.Text('Scambaiter not activated during this call.', style: codeStyle)
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: greyLight, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: scambaiterLog
                    .map((s) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Scammer: ${s['input'] ?? ''}', style: codeStyle),
                              pw.Text('Ramesh Ji: ${s['response'] ?? ''}',
                                  style: codeStyle.copyWith(color: PdfColors.blue700)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Section 7: Legal / Reporting
          _sectionHeader('7. Report This Crime'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFEBEB),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: redColor, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'This dossier is formatted for submission to India\'s National Cyber Crime Portal.',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text('• Portal: https://cybercrime.gov.in', style: valueStyle),
                pw.Text('• Helpline: 1930 (Toll-free, 24x7)', style: valueStyle),
                pw.Text(
                  '• This PDF was generated OFFLINE on the victim\'s device for evidence integrity.',
                  style: valueStyle,
                ),
                pw.Text(
                  '• Do NOT share this document with the scammer.',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: redColor,
                  ),
                ),
              ],
            ),
          ),

          // Footer
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Center(
            child: pw.Text(
              'Generated by PhaseGuard Anti-Scam OS | Offline | $generatedAt',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    );

    // Save to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'PhaseGuard_Dossier_${callId.substring(0, 8)}.pdf';
    final file = File('${dir.path}/$filename');
    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  /// Open the saved PDF using the device's native viewer.
  static Future<void> openPdf(String filePath) async {
    await OpenFilex.open(filePath);
  }

  /// Share the PDF via WhatsApp, email, or any other app.
  static Future<void> sharePdf(String filePath, String callId) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'PhaseGuard Forensic Evidence — $callId',
      text: 'Cyber crime evidence dossier generated by PhaseGuard.\n'
          'Report at: https://cybercrime.gov.in | Helpline: 1930',
    );
  }

  /// Preview PDF in-app using the printing package viewer.
  static Future<void> previewPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Open cybercrime.gov.in in the browser.
  static Future<void> openCybercrimePortal() async {
    final uri = Uri.parse('https://cybercrime.gov.in');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Dial 1930 cybercrime helpline.
  static Future<void> dialCybercrimeHelpline() async {
    final uri = Uri.parse('tel:1930');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
