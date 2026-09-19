class ScamDetector {
  // Scam keywords
  static const List<String> scamKeywords = [
    "immediately transfer",
    "secure account",
    "illegal transactions",
    "digital arrest",
    "arrest warrant",
    "police officer",
    "CBI",
    "FIR",
    "collect request",
    "accept this collect",
    "KYC incomplete",
    "KYC block",
    "SIM card blocked",
    "OTP share",
    "investment scheme",
    "invest 1 lakh",
    "guaranteed returns",
    "registration fee",
    "win lottery",
    "won lottery",
    "disconnection",
    "pay immediately",
    "threaten",
    "urgent money",
    "computer hacked",
    "remote access",
    "antivirus service",
    "Microsoft support",
    "download this app",
    "provide Aadhaar",
    "government approved scheme",
    "special scheme",
    "work from home",
    "registration fee",
    "video job",
    "like YouTube videos",
    "unpaid bill",
    "disconnection",
    "pay immediately",
    "process fee",
    "claim prize",
    "password",
    "CVV",
    "debit card details",
    "net banking password",
    "account will be deactivated",
    "multiple login attempts",
    "whatsapp account",
    "customs department",
    "clear customs",
    "international parcel",
    "share your aadhaar",
    "share your pan",
    "photo of aadhaar",
    "unusual activity",
    "routine security check",
    "for your security",
    "special government grant",
    "covid relief fund",
    "processing fee",
    "fraud department",
    "suspicious transaction",
    "block this transaction",
    "existing insurance company is fraud",
    "government-approved scheme",
    "lost his phone",
    "using friend's number",
    "only trusted friend",
    "deduct from first salary",
    "training fee",
    "international transaction",
    "met with an accident",
    "admitted in hospital",
    "using friend's number",
    // Hindi scam keywords
    "account block hone wala",
    "illegal transaction detect",
    "paise safe account",
    "transfer kar do immediately",
    "urgent hai bhai",
    "block ho jayega",
    // Extreme twisted scam keywords
    "internal audit account",
    "internal audit",
    "transfer your balance",
    "account has been frozen",
    "priority booking",
    "vip customers",
    "vip status",
    "advance payment",
    "policy has lapsed",
    "policy will be cancelled",
    "late fee",
    "revive policy",
    "government discount",
    "50% discount",
    "special offer ends",
    "save money",
    "donate 5000",
    "donate immediately",
    "children are starving",
    "send money",
    "reward points expiring",
    "processing fee to redeem",
    "points will be lost",
    "courtesy call",
    "warn you that scammers",
    "confirm the otp",
    "non-bailable arrest warrant",
    "court fee",
    "settle out of court",
    "police arrested me",
    "demanding 2 lakh",
    "lawyer's account",
    "blacklisted by trai",
    "sim box cloning",
    "port to secure server",
    "eligible for special interest rate",
    "open new fd",
    "limited time offer",
    "cylinder shortage",
    "priority delivery",
    "waiting 15 days",
    "funding cut",
    "registered ngo",
    "send money to this account",
    "cyber crime",
    "anti-scam",
    // Additional English scam keywords
    "money laundering",
    "terrorism funding",
    "police case",
    "system upgrade",
    "password reset",
    "net banking",
    "debit card",
    "credit card",
    "update details",
    "passport",
    "human trafficking",
    "cancellation",
    "driving license",
    "suspended",
    "voter id",
    "fake registrations",
    "legal action",
    "share market",
    "insider information",
    "crypto",
    "bitcoin",
    "double in",
    "youtube task",
    "account activation",
    "affiliate marketing",
    "forex trading",
    "secrets of billionaires",
    "gift voucher",
    "redeem voucher",
    "maldives holiday",
    "100 grams gold",
    "insurance prize",
    "activate insurance",
    "critical condition",
    "surgery needed",
    "life risk",
    "sim card misuse",
    "multiple login attempts",
    "platinum upgrade",
    "fd maturing",
    "special reward",
    "tax to receive",
    // Tamil scam keywords
    "உடன் பணம்",
    "பாதுகாப்பு கணக்கு",
    "வங்கி கணக்கு",
    "உடனடி பணம்",
    "போலீஸ் எண்",
    "ஏடிஎம் கார்டு",
    "லாட்டரி",
    "பெற்றீர்",
    "செலுங்கள்",
    "மருத்துவார்",
    "அனுப்பு",
    "கார்டு தடுக்கப்படும்",
    "பூர்த்தி செய்யுங்கள்",
    "ஆதார்",
    "பங்கு",
    // Telugu scam keywords
    "డబ్బ్ల్యూ మనీ",
    "బ్యాంక్ ఖాతా",
    "తక్షణ మనీ",
    "వెంటనే పంపించండి",
    "పాస్‌వర్డ్",
    "ఒటిపి",
    "వర్క్ ఫ్రమ్ హోమ్",
    "నెలగు",
    "సంపాదిందు",
    "రిజిస్ట్రేషన్ ఫీ",
    "చెల్లవండి",
    "పెట్టింగ్ స్కీమ్",
    "పెట్టిండి",
    "పొందుతారు",
    "గ్యారంటీ ఆమోదింగం",
    "ఇన్షురెన్స్ పాలిసీ",
    "రద్దు",
    // Bengali scam keywords
    "টাকা পাঠাও",
    "ব্যাংক অ্যাকাউন্ট",
    "অবিলম্ব",
    "পাসওয়ার্ড",
    "এটিএম কার্ড",
    "ওটিপি",
    "লটারি",
    "জিতেছেন",
    "পুরস্কার",
    "প্রসেসিং ফি",
    "হোম ফ্রম জব",
    "মাসিক",
    "আয",
    "রেজিস্ট্রেশন ফি",
    "হাসপাতালে",
    "তাৎরিত",
    // Marathi scam keywords
    "पैसे पाठवा",
    "बँक खाते",
    "तात्काळ",
    "पासवर्ड",
    "एटीएम कार्ड",
    "ओटीपी",
    "गुंतवनिकी स्कीम",
    "गुंतव",
    "मिळो",
    "सरकारारी योजना",
    "लॉटरी",
    "जिंकले",
    "प्रोसेसिंग फी",
    "घरू फ्रम जॉब",
    "महिने",
    "कमावा",
    "नोंदणी फी",
    // Kannada scam keywords
    "ಹಣ ಕಳುಹಿಸಿ",
    "ಬ್ಯಾಂಕ್ ಖಾತೆ",
    "ತಕ್ಷಣ",
    "ಪಾಸ್‌ವರ್ಡ್",
    "ಏಟಿಎಂ ಕಾರ್ಡ್",
    "ಓಟಿಪಿ",
    "ಇನ್ಶುರೆನ್ಸ್ ಪಾಲಿಸಿ",
    "ರದ್ದು",
    "ಚೆಲ್ಲವಂಡಿ",
    "ಹೋಮ್ ಫ್ರಮ್ ಜಾಬ್",
    "ತಿಂಗಳಿಂದಿರು",
    "ಸಂಪಾದಿಸು",
    "ನೋಂದಣಿ ಫೀ",
    "ಲಾಟರಿ",
    "ಗೆದ್ದುವು",
    "ಪ್ರಾಸೆಸಿಂಗ್ ಫೀ",
    // Malayalam scam keywords
    "പണം അയച്ചു",
    "ബാങ്ക് അക്കൗണ്ട്",
    "ഉടൻ",
    "പാസ്‌വേഡ്",
    "എടിഎം കാർഡ്",
    "ഒടിപി",
    "ആശുപത്രിയിൽ",
    "പെട്ടി",
    "ആവശ്യം",
    "ഇപ്പോ",
    "അയച്ചു",
    "നിക്ഷം സ്കീം",
    "നിക്ഷി",
    "ലഭിക്കും",
    "സർക്കാരി പദ്ധതി",
    "ലോട്ടറി",
    "ജിക്കുക",
    "പ്രോസസിംഗ് ഫീ",
    // Punjabi scam keywords
    "ਪੈਸੇ ਭੇਜੋ",
    "ਬੈਂਕ ਖਾਤਾ",
    "ਤੁਰੰਤ",
    "ਪਾਸਵਰਡ",
    "ਏਟੀਐਮ ਕਾਰਡ",
    "ਓਟੀਪੀ",
    "ਘਰ ਫਰਮ ਜੌਬ",
    "ਮਹੀਨੇ",
    "ਰੁਪਏ",
    "ਕਮਾਓ",
    "ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਫੀ",
    "ਦੇਓ",
    "ਲਾਟਰੀ",
    "ਜਿੱਤੇ",
    "ਪ੍ਰੋਸੈਸਿੰਗ ਫੀ",
    "ਹਸਪਤਾਲ",
    "ਲੋੜ",
    // Gujarati scam keywords
    "પૈસા મોકલો",
    "બેંક એકાઉન્ટ",
    "તાત્કાળ",
    "પાસવર્ડ",
    "એટીએમ કાર્ડ",
    "ઓટીપી",
    "ગુંતવનિકી સ્કીમ",
    "ગુંતવ",
    "મળો",
    "સરકારારી યોજના",
    "લોટરી",
    "જીત્યો",
    "પ્રોસેસિંગ ફી",
    "ઇન્શ્યરન્સ પાલિસી",
    "રદ્દુ",
    "ચૂલવંડી",
    "પાલીશ"
  ];

  // Legitimate indicators
  static const List<String> legitimateIndicators = [
    "credit card benefits",
    "customer service",
    "new credit card",
    "inform you about",
    "health insurance plan",
    "vaccination camp",
    "package has arrived",
    "OTP to complete delivery",
    "bill is due",
    "appointment scheduled",
    "FD is maturing",
    "fixed deposit",
    "would you like to know",
    "register for vaccination",
    "collect it within",
    "insurance plan that might interest",
    "premium payment",
    "discount if you renew",
    "booking confirmation",
    "service complete",
    "meeting scheduled",
    "progress",
    "official website",
    "official app",
    "visit our website",
    "walk-in allowed",
    "meter reading",
    "consumption",
    "due date",
    "no rush",
    "just reminder",
    "schedule an interview",
    "standard recruitment process",
    "no fees involved",
    "discharge is processed",
    "pick up medicines",
    "hospital counter",
    "vaccines available",
    "community center",
    "next camp is at",
    "health department",
    "seen your profile on linkedin",
    "no payment required now",
    "just information",
    "verify your identity before delivery",
    "hand over the package",
    // Extreme twisted legitimate keywords
    "you had called us earlier",
    "requested callback",
    "date of birth",
    "mother's maiden name",
    "for security",
    "already blocked those sim cards",
    "no action needed",
    "informing you as per government regulations",
    "case is listed for hearing",
    "you are a witness",
    "no payment required",
    "just notification",
    "witness",
    "conducting maintenance",
    "intermittent network",
    "service will be restored",
    "no action needed",
    "government welfare scheme",
    "no agent needed",
    "direct application",
    "no fees for application",
    "temporarily frozen",
    "visit your nearest branch",
    "id proof and pan card",
    "no phone or online resolution",
    "security measure",
    "within 7 days",
    "customer satisfaction survey",
    "research agency",
    "not ask for any personal",
    "participation is voluntary",
    "waiting 3-4 days",
    "no advance payment",
    "pay at delivery",
    "all customers treated equally",
    "due next week",
    "grace period",
    "no urgency",
    "late payment penalty",
    "no discounts available",
    "volunteers needed",
    "bring food items directly",
    "no cash donations",
    "visit our center",
    "do not expire",
    "check rewards section",
    "no processing fee"
  ];

  // Negative indicators - these indicate legitimate call
  static const List<String> negativeIndicators = [
    "no payment required",
    "no money",
    "no fees",
    "not asking for money",
    "free of cost",
    "no charge",
    "complimentary",
    "without any payment",
    "just information",
    "just reminder",
    "no urgency",
    "take your time",
    "visit official website",
    "government website",
    "official app",
    "no rush",
    "no payment required now",
    "vaccine is free",
    "no registration fee",
    "at hospital counter",
    "pay at hospital counter",
    "no agent needed",
    "direct application",
    "no fees for application",
    "no phone or online resolution",
    "security measure",
    "not ask for any personal",
    "participation is voluntary",
    "pay at delivery",
    "all customers treated equally",
    "grace period",
    "no urgency",
    "no discounts available",
    "bring food items directly",
    "no cash donations",
    "do not expire",
    "no processing fee",
    // Tamil legitimate keywords
    "இலவசமாக",
    "பணம் தேவையில்லை",
    "அதிகாரப்பூர்வ வலைத்தளம்",
    "தகவல் மட்டும்",
    // Telugu legitimate keywords
    "ఉచితమైనది",
    "డబ్బ్ల్యూ అవసరం లేదు",
    "అధికార వెబ్‌సైట్",
    "సమాచారం మాత్రమే",
    // Bengali legitimate keywords
    "বিনামূল্যে",
    "টাকা লাগবে না",
    "অফিসিয়াল ওয়েবসাইট",
    "শুধু তথ্য",
    // Marathi legitimate keywords
    "मोफत",
    "पैसे लागणार नाहीत",
    "अधिकृत वेबसाइट",
    "फक्त माहिती",
    // Kannada legitimate keywords
    "ಉಚಿತ",
    "ಹಣ ಅಗತ್ಯವಿಲ್ಲ",
    "ಅಧಿಕೃತ ವೆಬ್‌ಸೈಟ್",
    "ಮಾಹಿತಿ ಮಾತ್ರ",
    // Malayalam legitimate keywords
    "സൗജന്യമായി",
    "പണം ആവശ്യമില്ല",
    "ഔദ്യോഗിക വെബ്‌സൈറ്റ്",
    "വിവരം മാത്രം",
    // Punjabi legitimate keywords
    "ਮੁਫ਼ਤ",
    "ਪੈਸੇ ਦੀ ਲੋੜ ਨਹੀਂ",
    "ਅਧਿਕਾਰੀ ਵੈੱਬਸਾਈਟ",
    "ਸਿਰਫ਼ ਜਾਣਕਾਰੀ",
    // Gujarati legitimate keywords
    "મફત",
    "પૈસાની જરૂર નથી",
    "અધિકૃત વેબસાઇટ",
    "માહિતી માત્ર"
  ];

  static ScamResult detectScam(String transcript) {
    final transcriptLower = transcript.toLowerCase();

    int scamScore = 0;
    int legitimateScore = 0;
    int negativeScore = 0;

    // Count scam keywords
    for (final keyword in scamKeywords) {
      if (transcriptLower.contains(keyword.toLowerCase())) {
        scamScore++;
      }
    }

    // Count legitimate indicators
    for (final indicator in legitimateIndicators) {
      if (transcriptLower.contains(indicator.toLowerCase())) {
        legitimateScore++;
      }
    }

    // Count negative indicators
    for (final indicator in negativeIndicators) {
      if (transcriptLower.contains(indicator.toLowerCase())) {
        negativeScore++;
      }
    }

    // Special handling for bank freeze - legitimate if "visit branch" present
    if (transcriptLower.contains("account freeze") ||
        transcriptLower.contains("temporarily frozen")) {
      if (transcriptLower.contains("visit your nearest branch") ||
          transcriptLower.contains("visit branch")) {
        return ScamResult(
          isScam: false,
          category: "NORMAL",
          reasoning: "Legitimate account freeze requiring branch visit",
          scamScore: scamScore,
          legitimateScore: legitimateScore,
          negativeScore: negativeScore,
        );
      }
    }

    // Special handling for callback scenario - legitimate if "you had called us" present
    if (transcriptLower.contains("you had called us") && legitimateScore >= 2) {
      return ScamResult(
        isScam: false,
        category: "NORMAL",
        reasoning: "Legitimate callback scenario with verification",
        scamScore: scamScore,
        legitimateScore: legitimateScore,
        negativeScore: negativeScore,
      );
    }

    // If negative indicators present, prioritize legitimate classification
    // BUT: if "cyber crime" or "anti-scam" is mentioned with card details, it's likely a scam
    if (negativeScore >= 1 && scamScore <= 2) {
      if (transcriptLower.contains("cyber crime") ||
          transcriptLower.contains("anti-scam")) {
        if (transcriptLower.contains("card") ||
            transcriptLower.contains("atm") ||
            transcriptLower.contains("account")) {
          return ScamResult(
            isScam: true,
            category: "SCAM_DETECTED",
            reasoning: "Suspicious: claims to be anti-scam but asks for card/account details",
            scamScore: scamScore,
            legitimateScore: legitimateScore,
            negativeScore: negativeScore,
          );
        }
      }
      return ScamResult(
        isScam: false,
        category: "NORMAL",
        reasoning:
            "Rule-based detection: $negativeScore negative indicators override $scamScore scam indicators",
        scamScore: scamScore,
        legitimateScore: legitimateScore,
        negativeScore: negativeScore,
      );
    }
    
    // High legitimate score overrides single scam keyword
    if (legitimateScore >= 3 && scamScore <= 1) {
      return ScamResult(
        isScam: false,
        category: "NORMAL",
        reasoning: "Rule-based detection: High legitimate score ($legitimateScore) overrides low scam score ($scamScore)",
        scamScore: scamScore,
        legitimateScore: legitimateScore,
        negativeScore: negativeScore,
      );
    }

    // Rule-based decision
    if (scamScore >= 1) {
      return ScamResult(
        isScam: true,
        category: "SCAM_DETECTED",
        reasoning: "Rule-based detection: $scamScore scam indicators found",
        scamScore: scamScore,
        legitimateScore: legitimateScore,
        negativeScore: negativeScore,
      );
    } else if (legitimateScore >= 2) {
      return ScamResult(
        isScam: false,
        category: "NORMAL",
        reasoning: "Rule-based detection: $legitimateScore legitimate indicators found",
        scamScore: scamScore,
        legitimateScore: legitimateScore,
        negativeScore: negativeScore,
      );
    }

    // Conservative fallback
    return ScamResult(
      isScam: scamScore > 0,
      category: "UNKNOWN",
      reasoning:
          "Ambiguous: $scamScore scam, $legitimateScore legitimate, $negativeScore negative indicators",
      scamScore: scamScore,
      legitimateScore: legitimateScore,
      negativeScore: negativeScore,
    );
  }
}

class ScamResult {
  final bool isScam;
  final String category;
  final String reasoning;
  final int scamScore;
  final int legitimateScore;
  final int negativeScore;

  ScamResult({
    required this.isScam,
    required this.category,
    required this.reasoning,
    required this.scamScore,
    required this.legitimateScore,
    required this.negativeScore,
  });

  @override
  String toString() {
    return 'ScamResult(isScam: $isScam, category: $category, reasoning: $reasoning)';
  }

  Map<String, dynamic> toJson() {
    return {
      'is_scam': isScam,
      'category': category,
      'reasoning': reasoning,
      'scam_score': scamScore,
      'legitimate_score': legitimateScore,
      'negative_score': negativeScore,
    };
  }
}
