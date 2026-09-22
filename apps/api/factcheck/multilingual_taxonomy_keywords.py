"""
factcheck/multilingual_taxonomy_keywords.py — Clean multilingual keyword mappings.

This file contains ONLY the MULTILINGUAL_KEYWORDS dictionary to avoid
circular import issues. Uses string keys for categories.
"""

from typing import Dict, List
from enum import Enum


class Language(str, Enum):
    """Supported languages with support levels."""
    # Tier 1: VERIFIED (Whisper-large-v3 supports)
    EN = "en"
    HI = "hi"  # Hindi (Devanagari)
    HI_ROMAN = "hi_roman"  # Roman Hindi
    HINGLISH = "hinglish"  # Hindi-English code-switching
    UR = "ur"  # Urdu
    BN = "bn"  # Bengali
    AS = "as"  # Assamese
    TA = "ta"  # Tamil
    TE = "te"  # Telugu
    MR = "mr"  # Marathi
    GU = "gu"  # Gujarati
    KN = "kn"  # Kannada
    ML = "ml"  # Malayalam
    PA = "pa"  # Punjabi
    OR = "or"  # Odia
    
    # Tier 2: EXPERIMENTAL (may need fallback)
    NE = "ne"  # Nepali
    SD = "sd"  # Sindhi
    SA = "sa"  # Sanskrit
    BHO = "bho"  # Bhojpuri
    
    # Tier 3: UNVERIFIED (requires real-device testing)
    KOK = "kok"  # Konkani
    KS = "ks"  # Kashmiri
    MAI = "mai"  # Maithili
    DOI = "doi"  # Dogri
    MNI = "mni"  # Manipuri
    BRX = "brx"  # Bodo
    SAT = "sat"  # Santali


# Multilingual keyword mappings by category
# Structure: {category: {language: [keywords]}}
# Using string keys for categories to avoid circular import
MULTILINGUAL_KEYWORDS: Dict[str, Dict[Language, List[str]]] = {
    "OTP_REQUEST": {
        Language.EN: [
            "otp", "one time password", "verification code", "verify code",
            "auth code", "security code", "6 digit code", "verification pin",
        ],
        Language.HI: [
            "ओटीपी", "वन टाइम पासवर्ड", "वेरिफिकेशन कोड", "सिक्योरिटी कोड",
            "प्रमाणीकरण कोड", "छह अंक का कोड",
        ],
        Language.HI_ROMAN: [
            "otp", "one time password", "verification code", "batao",
            "batado", "bata dijiye", "share karo",
        ],
        Language.HINGLISH: [
            "otp batao", "otp bata do", "verification code batao",
            "apna otp share karo", "6 digit code batao",
        ],
        Language.OR: [
            "ଓଟିପି", "ଭାନ୍ ଟାଇମ୍ ପାସଭୱର୍ଡଭ", "ଭେରିଫିକେସନ୍ କୋଡ୍",
            "ସିକ୍ୟୁରିଟି କୋଡ୍", "ପ୍ରମାଣୀକରଣ କୋଡ୍",
        ],
        Language.BN: [
            "ওটিপি", "এককালীন পাসওয়ার্ড", "যাচাই কোড", "নিরাপত্তা কোড",
        ],
        Language.TA: [
            "ஓடிபி", "ஒருமுறை கடவுச்சொல்", "சரிபார்ப்பு குறியீடு",
        ],
        Language.TE: [
            "ఓటీపీ", "వన్ టైమ్ పాస్‌వర్డ్", "ధృవీకరణ కోడ్",
        ],
        Language.MR: [
            "ओटीपी", "वन टाइम पासवर्ड", "पडताळणी कोड",
        ],
        Language.GU: [
            "ઓટીપી", "વન ટાઈમ પાસવર્ડ", "ચકાસણી કોડ",
        ],
        Language.PA: [
            "ਓਟੀਪੀ", "ਵਨ ਟਾਈਮ ਪਾਸਵਰਡ", "ਪੁਸ਼ਟੀ ਕੋਡ",
        ],
        Language.UR: [
            "او ٹی پی", "ون ٹائم پاس ورڈ", "تصدیق کوڈ",
        ],
        Language.KN: [
            "ಒಟಿಪಿ", "ಒನ್ ಟೈಮ್ ಪಾಸ್‌ವರ್ಡ್", "ಪರಿಶೀಲನೆ ಕೋಡ್",
        ],
        Language.ML: [
            "ഒടിപി", "വൺ ടൈം പാസ്‌വേഡ്", "സ്ഥിരീകരണ കോഡ്",
        ],
        Language.AS: [
            "ওটিপি", "এককালীন পাছৱৰ্ড", "পৰীক্ষা কোড",
        ],
    },
    
    "BANK_ACCOUNT_REQUEST": {
        Language.EN: [
            "bank account", "account number", "account details", "bank details",
            "share your account", "give me your account", "account information",
        ],
        Language.HI: [
            "बैंक खाता", "खाता नंबर", "अकाउंट नंबर", "बैंक विवरण",
            "अपना खाता बताओ", "अकाउंट डिटेल्स",
        ],
        Language.HI_ROMAN: [
            "bank account", "khata number", "account number", "batado",
            "batao", "share karo",
        ],
        Language.HINGLISH: [
            "bank account batao", "account number share karo",
            "apna account details bata do",
        ],
        Language.OR: [
            "ବ�ୟାଙ୍କ ଖାତା", "ଖାତା ନମ୍ବର", "ଆକାଉଣ୍ଟ ବିବରଣ�ୀ",
        ],
        Language.BN: [
            "ব্যাংক অ্যাকাউন্ট", "অ্যাকাউন্ট নম্বর", "ব্যাংকের বিবরণ",
        ],
        Language.TA: [
            "வங்கி கணக்கு", "கணக்கு எண்", "வங்கி விவரங்கள்",
        ],
        Language.TE: [
            "బ్యాంకు ఖాతా", "ఖాతా సంఖ్య", "బ్యాంకు వివరాలు",
        ],
        Language.UR: [
            "بینک اکاؤنٹ", "اکاؤنٹ نمبر", "بینک کی تفصیلات",
        ],
    },
    
    "UPI_REQUEST": {
        Language.EN: [
            "upi", "upi id", "upi pin", "google pay", "phonepe",
            "paytm", "bhim", "share upi", "upi details",
        ],
        Language.HI: [
            "यूपीआई", "यूपीआई आईडी", "यूपीआई पिन", "गूगल पे",
            "फोनपे", "पेटीएम", "भीम", "यूपीआई शेयर करो",
        ],
        Language.HI_ROMAN: [
            "upi", "upi id", "google pay", "phonepe", "paytm",
            "share karo", "batao",
        ],
        Language.HINGLISH: [
            "upi id batao", "upi pin share karo", "google pay details bata do",
        ],
        Language.OR: [
            "ୟୁପିଆଇ", "ୟୁପିଆଇ ଆଇଡି", "ଗୁଗଲ୍ ପେ",
        ],
        Language.BN: [
            "ইউপিআই", "ইউপিআই আইডি", "গুগল পে",
        ],
        Language.TA: [
            "யுபிஐ", "யுபிஐ ஐடி", "கூகிள் பே",
        ],
        Language.TE: [
            "యుపిఐ", "యుపిఐ ఐడి", "గూగుల్ పే",
        ],
        Language.UR: [
            "یو پی آئی", "یو پی آئی آئی ڈی", "گوگل پے",
        ],
    },
    
    "PIN_REQUEST": {
        Language.EN: [
            "pin", "pin number", "debit card pin", "atm pin",
            "share your pin", "give me your pin", "enter pin",
        ],
        Language.HI: [
            "पिन", "पिन नंबर", "डेबिट कार्ड पिन", "एटीएम पिन",
            "अपना पिन बताओ", "पिन शेयर करो",
        ],
        Language.HI_ROMAN: [
            "pin", "pin number", "atm pin", "batao", "batado",
        ],
        Language.HINGLISH: [
            "pin batao", "atm pin share karo", "apna pin bata do",
        ],
        Language.OR: [
            "ପିନ୍", "ପିନଭ୍ ନମ୍ବର", "ଏଟ�ିଏମ୍ ପିନଭ",
        ],
        Language.BN: [
            "পিন", "পিন নম্বর", "এটিএম পিন",
        ],
        Language.TA: [
            "பின்", "பின் எண்", "ஏடிஎம் பின்",
        ],
        Language.UR: [
            "پن", "پن نمبر", "اے ٹی ایم پن",
        ],
    },
    
    "AADHAAR_REQUEST": {
        Language.EN: [
            "aadhaar", "aadhar", "aadhaar number", "aadhaar card",
            "share aadhaar", "aadhaar details",
        ],
        Language.HI: [
            "आधार", "आधार नंबर", "आधार कार्ड", "आधार शेयर करो",
        ],
        Language.HI_ROMAN: [
            "aadhaar", "aadhar", "aadhaar number", "share karo",
        ],
        Language.HINGLISH: [
            "aadhaar batao", "aadhaar card details bata do",
        ],
        Language.OR: [
            "ଆଧାର", "ଆଧାର ନମ୍ବର", "ଆଧାର କାର�ଡ",
        ],
        Language.BN: [
            "আধার", "আধার নম্বর", "আধার কার্ড",
        ],
        Language.TA: [
            "ஆதார்", "ஆதார் எண்", "ஆதார் கார்டு",
        ],
        Language.UR: [
            "آدھار", "آدھار نمبر", "آدھار کارڈ",
        ],
    },
    
    "ACCOUNT_BLOCK_THREAT": {
        Language.EN: [
            "account blocked", "account frozen", "account suspended",
            "your account is blocked", "account will be blocked",
            "freeze your account", "suspend your account",
        ],
        Language.HI: [
            "खाता ब्लॉक", "खाता फ्रीज", "खाता निलंबित",
            "आपका खाता ब्लॉक है", "खाता बंद हो जाएगा",
        ],
        Language.HI_ROMAN: [
            "account blocked", "account frozen", "band ho jayega",
            "block ho gaya hai",
        ],
        Language.HINGLISH: [
            "account block ho gaya hai", "account freeze kar diya jayega",
            "apna account block hone wala hai",
        ],
        Language.OR: [
            "ଖାତା ବଭ୍ଲକ୍", "ଖାତା ଫ୍ରିଜ୍", "ଖାତା ବ���ଦ ହୋଇଯିବ",
        ],
        Language.BN: [
            "অ্যাকাউন্ট ব্লক করা", "অ্যাকাউন্ট ফ্রিজ",
        ],
        Language.TA: [
            "கணக்கு தடுக்கப்பட்டது", "கணக்கு முடக்கப்படும்",
        ],
        Language.UR: [
            "اکاؤنٹ بلاک", "اکاؤنٹ فریز",
        ],
    },
    
    "POLICE_SCAM": {
        Language.EN: [
            "police", "fbi", "cid", "crime branch", "cyber police",
            "police complaint", "arrest warrant", "legal action",
        ],
        Language.HI: [
            "पुलिस", "पुलिस शिकायत", "गिरफ्तारी", "वारंट",
            "कानूनी कार्रवाई", "साइबर पुलिस",
        ],
        Language.HI_ROMAN: [
            "police", "giraftari", "warrant", "complaint",
            "legal action",
        ],
        Language.HINGLISH: [
            "police warrant hai", "giraftari ho jayegi", "legal action lenge",
        ],
        Language.OR: [
            "ପୋଲିସ୍", "ପୋଲିସ୍ ଅଭିଯୋଗ", "ଗିରଫ୍ତାରୀ",
        ],
        Language.BN: [
            "পুলিশ", "পুলিশ অভিযোগ", "গ্রেফতার",
        ],
        Language.TA: [
            "போலீஸ்", "போலீஸ் புகார்", "கைது",
        ],
        Language.UR: [
            "پولیس", "پولیس شکایت", "گرفتاری",
        ],
    },
    
    "BANK_IMPERSONATION": {
        Language.EN: [
            "bank", "rbi", "sbi", "hdfc", "icici", "axis bank",
            "bank manager", "bank officer", "from bank",
        ],
        Language.HI: [
            "बैंक", "आरबीआई", "एसबीआई", "बैंक मैनेजर",
            "बैंक अधिकारी", "बैंक से",
        ],
        Language.HI_ROMAN: [
            "bank", "rbi", "sbi", "bank manager", "bank se",
        ],
        Language.HINGLISH: [
            "bank se call hai", "rbi ne notice bheja hai",
            "bank manager bol rahe hain",
        ],
    },
    
    "URGENT_PAYMENT": {
        Language.EN: [
            "urgent payment", "immediate payment", "pay now",
            "pay immediately", "transfer now", "send money now",
        ],
        Language.HI: [
            "तत्काल भुगतान", "फौरन भुगतान", "अभी भुगतान करो",
            "पैसे भेजो", "तुरंत पैसे भेजो",
        ],
        Language.HI_ROMAN: [
            "urgent payment", "abhi pay karo", "furan pay karo",
            "paisa bhejo",
        ],
        Language.HINGLISH: [
            "urgent payment karo", "abhi paisa transfer karo",
            "furan paisa bhej do",
        ],
    },
    
    "THREAT": {
        Language.EN: [
            "arrest", "jail", "legal action", "court case",
            "police case", "criminal case", "go to jail",
            "arrest warrant", "imprisonment",
        ],
        Language.HI: [
            "गिरफ्तार", "जेल", "कानूनी कार्रवाई", "कोर्ट केस",
            "पुलिस केस", "जेल जाओगे",
        ],
        Language.HI_ROMAN: [
            "giraftari", "jail", "legal action", "court case",
            "jail jayoge",
        ],
        Language.HINGLISH: [
            "giraftari ho jayegi", "jail mein daal denge",
            "court case ho jayega",
        ],
    },
}
