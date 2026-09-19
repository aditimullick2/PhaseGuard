import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/services/scam_detector.dart';

void main() {
  group('ScamDetector Tests', () {
    test('Detects RBI scam', () {
      final result = ScamDetector.detectScam(
        'Hello this is calling from RBI. Your bank account has been linked to illegal transactions. Please transfer your money to our secure account immediately.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects UPI fraud', () {
      final result = ScamDetector.detectScam(
        'Hello, this is calling from bank. Your UPI account is blocked. Please accept this collect request of 5000 rupees to unblock.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects digital arrest scam', () {
      final result = ScamDetector.detectScam(
        'This is police officer Sharma from CBI. We have issued a digital arrest warrant against you for money laundering. Pay 1 lakh immediately.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects family emergency scam', () {
      final result = ScamDetector.detectScam(
        'Hello beta, this is your uncle speaking. I am in the hospital and need urgent money for surgery. Please transfer 50000 rupees.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies legitimate bank service as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is calling from HDFC Bank customer service. We are calling to inform you about your new credit card benefits. Would you like to know more?',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Classifies legitimate delivery as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is calling from delivery service. Your package has arrived at the hub. We need to verify your identity before delivery. Please share the OTP sent to your phone.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Detects double-bluff scam', () {
      final result = ScamDetector.detectScam(
        'Hello, I am calling from Cyber Crime Cell. We have detected that scammers are calling you pretending to be from banks. For your protection, we need to verify your account is safe. Please share your last 4 digits of ATM card.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects insurance policy lapse threat', () {
      final result = ScamDetector.detectScam(
        'Hello, your health insurance policy has lapsed due to non-payment. All your hospital claims will be rejected now. To revive policy immediately, you need to pay 15000 rupees now.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies legitimate insurance reminder as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is from insurance company. Your health insurance premium is due next week. Amount is 12000 rupees. You can pay through our app. No urgency, you have time.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Detects charity donation scam', () {
      final result = ScamDetector.detectScam(
        'Hello, calling from orphanage. 50 children have no food tonight due to funding cut. Please donate 5000 rupees to feed them. Send money to this account immediately.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies legitimate charity as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is from registered NGO. We are organizing food donation drive next Sunday. Volunteers needed. If you want to donate, you can bring food items directly to our center.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Detects Hinglish scam', () {
      final result = ScamDetector.detectScam(
        'Hello bhai, RBI se call hai. Aapka account block hone wala hai. Illegal transaction detect hui hai. Apne paise ko safe account me transfer kar do immediately.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects fake government discount scam', () {
      final result = ScamDetector.detectScam(
        'Hello, electricity department calling. Due to COVID, government is offering 50% discount on pending bills if paid today. Your pending bill is 8000 rupees. Pay only 4000 rupees today.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies legitimate electricity bill as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is from electricity board. Your bill for this month is 4500 rupees. Due date is 20th. Late payment penalty will apply after due date. No discounts available.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Handles bank freeze scenario correctly', () {
      final result = ScamDetector.detectScam(
        'Hello, this is from bank compliance department. Your account has been temporarily frozen due to suspicious transaction pattern. Please visit your nearest branch with ID proof.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Detects bank internal account scam', () {
      final result = ScamDetector.detectScam(
        'Hello, I am branch manager of your bank. Our internal audit found some discrepancy in your account. To avoid account freeze, you need to transfer your balance to our internal audit account temporarily.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects credit card reward points scam', () {
      final result = ScamDetector.detectScam(
        'Hello, calling from credit card rewards department. You have 50000 reward points expiring tomorrow. To redeem, you need to pay 2000 rupees processing fee.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies legitimate rewards as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is from credit card rewards team. You have 50000 reward points in your account. These points do not expire. You can redeem for shopping through our official app.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Handles callback scenario correctly', () {
      final result = ScamDetector.detectScam(
        'Hello, I am calling from your bank customer service. You had called us earlier about your credit card statement. Is this correct? Good. Can you confirm your date of birth for security?',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Detects gas agency scam', () {
      final result = ScamDetector.detectScam(
        'Hello, calling from gas agency. Due to cylinder shortage, we are offering priority booking for VIP customers. If you pay 2000 rupees advance, you will get priority delivery.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies legitimate gas agency as normal', () {
      final result = ScamDetector.detectScam(
        'Hello, this is from gas agency. Your next cylinder booking is due. You can book through our official app. No advance payment needed. Pay at delivery.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    // Multilingual tests
    test('Detects Tamil scam', () {
      final result = ScamDetector.detectScam(
        'வணக்கார கணக்கில் பிரச்சனை உள்ளது. உடனே பணம் பாதுகாப்பு கணக்குக்கு மாற்றவுங்கள்.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Classifies Tamil legitimate as normal', () {
      final result = ScamDetector.detectScam(
        'இலவசமாக சேவை. பணம் தேவையில்லை. அதிகாரப்பூர்வ வலைத்தளத்தில் விவரங்கள் உள்ளன.',
      );
      expect(result.isScam, false);
      expect(result.category, 'NORMAL');
    });

    test('Detects Telugu scam', () {
      final result = ScamDetector.detectScam(
        'రెండిరెండో డబ్బ్ల్యూ మనీ. తక్షణంగా వెంటనే పంపించండి. పాసవర్డ్ చెపండి.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects Bengali scam', () {
      final result = ScamDetector.detectScam(
        'ব্যাংক অ্যাকাউন্টে সমস্যা. অবিলম্বে টাকা পাঠাও. পাসওয়ার্ড দাও.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects Marathi scam', () {
      final result = ScamDetector.detectScam(
        'बँक खात्यात समस्या. तात्काळ पैसे पाठवा. पासवर्ड द्या.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects Kannada scam', () {
      final result = ScamDetector.detectScam(
        'ಬ್ಯಾಂಕ್ ಖಾತೆಯಲಿ ಸಮಸ್ಯೆ. ತಕ್ಷಣ ಹಣ ಕಳುಹಿಸಿ. ಪಾಸ್‌ವರ್ಡ್ ನೀಡಿ.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects Malayalam scam', () {
      final result = ScamDetector.detectScam(
        'ബാങ്ക് അക്കൗണ്ടിൽ പ്രശ്നമുണ്ട്. ഉടൻ പണം അയച്ചു. പാസ്‌വേഡ് നൽകുക.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects Punjabi scam', () {
      final result = ScamDetector.detectScam(
        'ਬੈਂਕ ਖਾਤੇ ਵਿੱਚ ਸਮੱਸਿਆ. ਤੁਰੰਤ ਪੈਸੇ ਭੇਜੋ. ਪਾਸਵਰਡ ਦਿਓ.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });

    test('Detects Gujarati scam', () {
      final result = ScamDetector.detectScam(
        'બેંક એકાઉન્ટમાં સમસ્યા. તાત્કાળ પૈસા મોકલો. પાસવર્ડ આપો.',
      );
      expect(result.isScam, true);
      expect(result.category, 'SCAM_DETECTED');
    });
  });
}
