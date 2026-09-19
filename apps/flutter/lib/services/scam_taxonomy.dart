/// Local scam taxonomy engine for offline detection.
/// When backend is unavailable, matches transcript text against known scam patterns
/// and returns a risk verdict matching the backend FactCheckUpdate schema.

class ScamTaxonomy {
  // Scam patterns indexed by category
  static const Map<String, List<String>> patterns = {
    'IRS_IMPERSONATION': [
      'irs',
      'back taxes',
      'tax refund',
      'federal agent',
      'tax evasion',
      'audit',
      'return tax',
      'penalty',
    ],
    'DIGITAL_ARREST': [
      'warrant',
      'arrest warrant',
      'police',
      'federal agent',
      'dea agent',
      'fbi agent',
      'law enforcement',
      'court order',
      'legal action',
    ],
    'IMPERSONATION': [
      'google',
      'microsoft',
      'apple',
      'amazon',
      'paypal',
      'bank of america',
      'wells fargo',
      'citibank',
      'social security',
      'medicare',
      'representative',
      'security team',
    ],
    'ROMANCE_SCAM': [
      'love',
      'relationship',
      'boyfriend',
      'girlfriend',
      'marry',
      'wedding',
      'military',
      'overseas',
      'need money',
      'send money',
      'wire transfer',
    ],
    'TECH_SUPPORT': [
      'virus',
      'malware',
      'infected',
      'hacked',
      'update',
      'antivirus',
      'technical support',
      'computer repair',
      'blue screen',
    ],
    'FINANCIAL_THREAT': [
      'wire transfer',
      'gift card',
      'amazon card',
      'itunes card',
      'google play',
      'best buy card',
      'money transfer',
      'cryptocurrency',
      'bitcoin',
      'account frozen',
      'unauthorized transaction',
    ],
  };

  /// Analyze text for scam keywords and return offline verdict.
  /// Returns a map matching FactCheckUpdate schema.
  static Map<String, dynamic> analyzeOffline(String text) {
    if (text.isEmpty) {
      return {
        'status': 'UNCERTAIN',
        'message': 'No transcript to analyze',
        'category': 'UNKNOWN',
        'confidence': 0.0,
      };
    }

    final lower = text.toLowerCase();
    final matches = <String, int>{};

    // Count keyword matches per category
    for (final entry in patterns.entries) {
      final category = entry.key;
      final keywords = entry.value;
      int count = 0;
      for (final keyword in keywords) {
        if (lower.contains(keyword)) {
          count++;
        }
      }
      if (count > 0) {
        matches[category] = count;
      }
    }

    if (matches.isEmpty) {
      return {
        'status': 'SAFE',
        'message': 'No known scam patterns detected in transcript',
        'category': 'CLEAN',
        'confidence': 0.95,
      };
    }

    // Find top-scoring category
    String topCategory = matches.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    int topScore = matches[topCategory]!;

    // Confidence based on match count and pattern overlap
    double confidence = (topScore / 5.0).clamp(0.0, 1.0);
    String status = confidence >= 0.6 ? 'CRITICAL' : 'WARNING';

    return {
      'status': status,
      'message': 'Offline analysis: Detected $topCategory pattern (${topScore} keywords matched)',
      'category': topCategory,
      'confidence': confidence,
    };
  }

  /// Quick check: does this text contain any known scam indicators?
  static bool isSuspicious(String text) {
    if (text.isEmpty) return false;
    final verdict = analyzeOffline(text);
    return verdict['status'] == 'CRITICAL' || verdict['status'] == 'WARNING';
  }

  /// Get all categories for debugging
  static List<String> getCategories() => patterns.keys.toList();
}
