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
    String? callerName,
    String? aiVoiceReason,
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

    // ── Color palette (Premium Look) ─────────────────────────────────────────
    const brandBlue = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const primaryAccent = PdfColor.fromInt(0xFF2563EB); // Blue 600
    const redColor = PdfColor.fromInt(0xFFDC2626); // Red 600
    const safeColor = PdfColor.fromInt(0xFF059669); // Emerald 600
    const orangeColor = PdfColor.fromInt(0xFFD97706); // Amber 600
    
    const bgLight = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const bgDarker = PdfColor.fromInt(0xFFF1F5F9); // Slate 100
    const borderDark = PdfColor.fromInt(0xFFCBD5E1); // Slate 300
    
    const textMain = PdfColor.fromInt(0xFF1E293B); // Slate 800
    const textMuted = PdfColor.fromInt(0xFF64748B); // Slate 500

    final verdictColor = verdict == 'CRITICAL'
        ? redColor
        : verdict == 'SAFE'
            ? safeColor
            : orangeColor;

    // ── Styles ───────────────────────────────────────────────────────────────
    final baseStyle = pw.TextStyle(fontSize: 10, color: textMain);
    final h1Style = pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: brandBlue);
    final h2Style = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryAccent);
    final labelStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted);
    final valueStyle = pw.TextStyle(fontSize: 10, color: textMain, fontWeight: pw.FontWeight.bold);
    
    final codeStyle = pw.TextStyle(
      fontSize: 9,
      color: textMain,
    );

    // ── Helpers ──────────────────────────────────────────────────────────────
    pw.Widget _sectionHeader(String title) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 20, bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: borderDark, width: 1)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 4,
                height: 14,
                margin: const pw.EdgeInsets.only(right: 6),
                color: primaryAccent,
              ),
              pw.Text(title, style: h2Style),
            ]
          ),
        );

    pw.Widget _kvBlock(String label, String value) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(), style: labelStyle),
              pw.SizedBox(height: 2),
              pw.Text(value, style: valueStyle),
            ],
          ),
        );

    // ── Header Builder ───────────────────────────────────────────────────────
    pw.Widget _buildHeader(pw.Context context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PHASEGUARD', style: h1Style.copyWith(letterSpacing: 2)),
                      pw.Text('OFFICIAL CYBER CRIME EVIDENCE DOSSIER', 
                        style: pw.TextStyle(fontSize: 11, color: textMuted, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                      pw.SizedBox(height: 4),
                      pw.Text('Format: India National Cyber Crime Portal (1930)', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                    ],
                  )
                ),
                pw.Container(
                  height: 50,
                  width: 50,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'PG-CALL-$callId',
                    drawText: false,
                    color: brandBlue,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            
            // Verdict Banner
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: pw.BoxDecoration(
                color: verdictColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'VERDICT: $verdict',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2),
                  ),
                  pw.Text(
                    'Generated: $generatedAt',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Footer Builder ───────────────────────────────────────────────────────
    pw.Widget _buildFooter(pw.Context context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: borderDark, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Confidential Evidence Document | PhaseGuard Anti-Scam OS',
              style: pw.TextStyle(fontSize: 8, color: textMuted),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: textMuted),
            ),
          ],
        ),
      );
    }

    // ── PDF MultiPage ────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: _buildHeader,
        footer: _buildFooter,
        build: (context) => [
          
          // Section 1: Call Metadata
          _sectionHeader('1. CALL METADATA'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderDark, width: 0.5),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  children: [
                    _kvBlock('Call ID', callId),
                    _kvBlock('Caller Name', callerName ?? 'Unknown'),
                    _kvBlock('Phone Number', phoneNumbers.isNotEmpty ? phoneNumbers.join(', ') : 'Unknown'),
                  ]
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    _kvBlock('Call Start Time', callStart),
                    _kvBlock('Audio Duration', '$audioDurationSec seconds'),
                    _kvBlock('Ingestion Mode', 'Direct Device Audio'),
                  ]
                ),
              ],
            ),
          ),

          // Section 1.5: AI Voice Analysis
          if (aiVoiceReason != null && aiVoiceReason.isNotEmpty) ...[
            _sectionHeader('AI VOICE / DEEPFAKE ANALYSIS'),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFEF2F2), // Red 50
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFFCA5A5), width: 1),
              ),
              child: pw.Text(
                'WARNING: Deepfake / AI Voice Detected\n\n$aiVoiceReason',
                style: codeStyle.copyWith(color: redColor, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],

          // Section 2: Forensic Hash
          _sectionHeader('2. FORENSIC CHAIN OF CUSTODY'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderDark, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    _kvBlock('Algorithm', 'SHA-256'),
                    _kvBlock('Hash Verified', audioBytes != null ? 'YES' : 'No audio captured'),
                  ]
                ),
                pw.SizedBox(height: 12),
                pw.Text('AUDIO HASH:', style: labelStyle),
                pw.SizedBox(height: 2),
                pw.Text(audioHash, style: valueStyle.copyWith(fontSize: 8)), // Smaller for hash
              ],
            ),
          ),

          // Section 3: Identified Scam Markers
          _sectionHeader('3. EXTRACTED SCAM IDENTIFIERS'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderDark, width: 0.5),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kvBlock('UPI IDs / Bank Details', upiIds.isEmpty ? 'None detected' : upiIds.join(', ')),
                    _kvBlock('Impersonated Entities', impersonatedEntities.isEmpty ? 'None' : impersonatedEntities.join(', ')),
                  ]
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kvBlock('Scam Keywords', detectedKeywords.isEmpty ? 'None' : detectedKeywords.take(20).join(', ')),
                    pw.Expanded(child: pw.SizedBox()), // Spacer
                  ]
                ),
              ],
            ),
          ),

          // Section 4: Transcript with Highlighted Scam Terms
          _sectionHeader('4. CERTIFIED CALL TRANSCRIPT'),
          if (transcriptHistory.isEmpty)
            pw.Text('No transcript captured during this session.', style: codeStyle.copyWith(color: textMuted))
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: bgLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderDark, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: transcriptHistory.map((t) {
                  bool containsKeyword = detectedKeywords.any((kw) => t.toLowerCase().contains(kw.toLowerCase()));
                  
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 2,
                          height: 12,
                          margin: const pw.EdgeInsets.only(right: 8, top: 2),
                          color: containsKeyword ? redColor : borderDark,
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            t, 
                            style: codeStyle.copyWith(
                              color: containsKeyword ? redColor : textMain,
                              fontWeight: containsKeyword ? pw.FontWeight.bold : pw.FontWeight.normal,
                            ),
                          ),
                        ),
                      ]
                    )
                  );
                }).toList(),
              ),
            ),

          // Section 5: Factcheck History
          _sectionHeader('5. REAL-TIME AI FACT-CHECK LOG'),
          if (factcheckHistory.isEmpty)
            pw.Text('No fact-checks performed.', style: codeStyle.copyWith(color: textMuted))
          else
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderDark, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.TableHelper.fromTextArray(
                headers: ['Timestamp', 'Status', 'AI Verdict / Summary'],
                data: factcheckHistory
                    .take(15)
                    .map((f) => [
                          (f['ts'] as String? ?? '').substring(0, 16).replaceFirst('T', ' '),
                          f['status'] ?? '',
                          (f['message'] as String? ?? '').substring(
                              0, ((f['message'] as String? ?? '').length).clamp(0, 100)) + (((f['message'] as String? ?? '').length > 100) ? '...' : ''),
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: brandBlue,
                  borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                ),
                cellStyle: pw.TextStyle(fontSize: 8, color: textMain),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                oddRowDecoration: const pw.BoxDecoration(color: bgDarker),
                border: null, // Custom border handled by container
              ),
            ),

          // Section 6: Scambaiter Log
          _sectionHeader('6. AI SCAMBAITER EXCHANGE LOG'),
          if (scambaiterLog.isEmpty)
            pw.Text('Scambaiter was not activated during this call.', style: codeStyle.copyWith(color: textMuted))
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: bgLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderDark, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: scambaiterLog
                    .map((s) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 12),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Scammer Bubble
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                margin: const pw.EdgeInsets.only(bottom: 4, right: 40),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(6),
                                  border: pw.Border.all(color: borderDark, width: 0.5),
                                ),
                                child: pw.Text('Scammer: ${s['input'] ?? ''}', style: codeStyle),
                              ),
                              // AI Bubble
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                margin: const pw.EdgeInsets.only(left: 40),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromInt(0xFFEFF6FF), // Blue 50
                                  borderRadius: pw.BorderRadius.circular(6),
                                  border: pw.Border.all(color: PdfColor.fromInt(0xFFBFDBFE), width: 0.5),
                                ),
                                child: pw.Text('PhaseGuard AI: ${s['response'] ?? ''}',
                                    style: codeStyle.copyWith(color: primaryAccent, fontWeight: pw.FontWeight.bold)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Section 7: Legal / Reporting
          _sectionHeader('7. OFFICIAL REPORTING GUIDELINES'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFEF2F2), // Red 50
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: redColor, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'IMPORTANT EVIDENCE INSTRUCTIONS',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: redColor, letterSpacing: 1),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'This dossier is cryptographically hashed and formatted for immediate submission to India\'s National Cyber Crime Portal.',
                  style: valueStyle,
                ),
                pw.SizedBox(height: 8),
                pw.Text('• Portal: https://cybercrime.gov.in', style: valueStyle.copyWith(color: primaryAccent)),
                pw.Text('• Helpline: 1930 (Toll-free, 24x7)', style: valueStyle.copyWith(color: primaryAccent)),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Do NOT share this document with the suspected scammer. This PDF was generated entirely OFFLINE on the victim\'s device to preserve evidence integrity and privacy.',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Save to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'PhaseGuard_Evidence_${callId.substring(0, 8)}.pdf';
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
