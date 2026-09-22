"""
factcheck/multilingual_taxonomy.py — Semantic scam categories with multilingual keyword support.

Design:
- Semantic categories (OTP_REQUEST, BANK_ACCOUNT, etc.) instead of flat keywords
- Language-aware keyword mappings for each category
- Support for all major Indian languages (Hindi, Odia, Bengali, Assamese, Tamil, Telugu, etc.)
- Code-switching support (mixed English+Indian languages)
- Transliteration variants (e.g., "OTP" = "ओटीपी" = "otp")
- UNKNOWN/UNCERTAIN handling for low-confidence matches

Categories:
- OTP_REQUEST
- BANK_ACCOUNT_REQUEST
- CARD_DETAILS_REQUEST
- PIN_REQUEST
- CVV_REQUEST
- CARD_NUMBER_REQUEST
- PASSWORD_REQUEST
- UPI_REQUEST
- KYC_REQUEST
- PERSONAL_INFORMATION_REQUEST
- AADHAAR_REQUEST
- PAN_REQUEST
- PAYMENT_REQUEST
- MONEY_TRANSFER
- REFUND_SCAM
- LOTTERY_SCAM
- PRIZE_SCAM
- INVESTMENT_SCAM
- LOAN_SCAM
- JOB_SCAM
- POLICE_SCAM
- CYBERCRIME_IMPERSONATION
- BANK_IMPERSONATION
- GOVERNMENT_IMPERSONATION
- REMOTE_ACCESS
- SCREEN_SHARING
- MALICIOUS_LINK
- QR_CODE_SCAM
- CALL_BACK_REQUEST
- THREAT
- ARREST_THREAT
- ACCOUNT_BLOCK_THREAT
- SIM_BLOCK_THREAT
- KYC_EXPIRY
- URGENT_ACTION
- FEAR_PRESSURE
- SECRECY_REQUEST
"""

from typing import Dict, List
from enum import Enum


class ScamCategory(str, Enum):
    """Semantic scam categories."""
    OTP_REQUEST = "OTP_REQUEST"
    BANK_ACCOUNT_REQUEST = "BANK_ACCOUNT_REQUEST"
    CARD_DETAILS_REQUEST = "CARD_DETAILS_REQUEST"
    PIN_REQUEST = "PIN_REQUEST"
    CVV_REQUEST = "CVV_REQUEST"
    CARD_NUMBER_REQUEST = "CARD_NUMBER_REQUEST"
    PASSWORD_REQUEST = "PASSWORD_REQUEST"
    UPI_REQUEST = "UPI_REQUEST"
    KYC_REQUEST = "KYC_REQUEST"
    PERSONAL_INFORMATION_REQUEST = "PERSONAL_INFORMATION_REQUEST"
    AADHAAR_REQUEST = "AADHAAR_REQUEST"
    PAN_REQUEST = "PAN_REQUEST"
    PAYMENT_REQUEST = "PAYMENT_REQUEST"
    MONEY_TRANSFER = "MONEY_TRANSFER"
    REFUND_SCAM = "REFUND_SCAM"
    LOTTERY_SCAM = "LOTTERY_SCAM"
    PRIZE_SCAM = "PRIZE_SCAM"
    INVESTMENT_SCAM = "INVESTMENT_SCAM"
    LOAN_SCAM = "LOAN_SCAM"
    JOB_SCAM = "JOB_SCAM"
    POLICE_SCAM = "POLICE_SCAM"
    CYBERCRIME_IMPERSONATION = "CYBERCRIME_IMPERSONATION"
    BANK_IMPERSONATION = "BANK_IMPERSONATION"
    GOVERNMENT_IMPERSONATION = "GOVERNMENT_IMPERSONATION"
    REMOTE_ACCESS = "REMOTE_ACCESS"
    SCREEN_SHARING = "SCREEN_SHARING"
    MALICIOUS_LINK = "MALICIOUS_LINK"
    QR_CODE_SCAM = "QR_CODE_SCAM"
    CALL_BACK_REQUEST = "CALL_BACK_REQUEST"
    THREAT = "THREAT"
    ARREST_THREAT = "ARREST_THREAT"
    ACCOUNT_BLOCK_THREAT = "ACCOUNT_BLOCK_THREAT"
    SIM_BLOCK_THREAT = "SIM_BLOCK_THREAT"
    KYC_EXPIRY = "KYC_EXPIRY"
    URGENT_ACTION = "URGENT_ACTION"
    FEAR_PRESSURE = "FEAR_PRESSURE"
    SECRECY_REQUEST = "SECRECY_REQUEST"
    UNKNOWN = "UNKNOWN"


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


# Import keywords from separate file to avoid circular import
from .multilingual_taxonomy_keywords import MULTILINGUAL_KEYWORDS as KEYWORDS_DICT

# Map string keys back to enum for public API
_CATEGORY_MAP = {cat.value: cat for cat in ScamCategory}


def detect_scam_category(
    transcript: str,
    detected_language: Language = Language.EN,
) -> tuple[ScamCategory, float, List[str]]:
    """
    Detect scam category from transcript using multilingual keywords.
    
    Parameters
    ----------
    transcript : str
        Transcript text to analyze.
    detected_language : Language
        Detected language of the transcript.
    
    Returns
    -------
    tuple (category, confidence, matched_keywords)
        category: Detected scam category
        confidence: Match confidence (0.0-1.0)
        matched_keywords: List of keywords that matched
    """
    if not transcript or not transcript.strip():
        return ScamCategory.UNKNOWN, 0.0, []
    
    transcript_lower = transcript.lower()
    
    # Try detected language first
    language_attempts = [detected_language]
    
    # Fallback to English if no keywords for detected language
    if detected_language not in [lang for cat in KEYWORDS_DICT.values() for lang in cat]:
        language_attempts.append(Language.EN)
    
    # Also try HINGLISH as fallback for Indian languages
    if detected_language in [Language.HI, Language.HI_ROMAN, Language.OR, Language.BN, 
                             Language.TA, Language.TE, Language.MR, Language.GU, 
                             Language.PA, Language.UR, Language.KN, Language.ML, Language.AS]:
        language_attempts.extend([Language.HINGLISH, Language.EN])
    
    # For EXPERIMENTAL/UNVERIFIED languages, add script-based fallbacks
    if detected_language in [Language.NE, Language.SD, Language.SA, Language.BHO, 
                             Language.KOK, Language.KS, Language.MAI, Language.DOI, 
                             Language.MNI, Language.BRX, Language.SAT]:
        # Fall back to nearest verified language based on script
        if detected_language in [Language.NE, Language.SA, Language.BHO, Language.KOK, 
                                Language.MAI, Language.DOI]:
            language_attempts.extend([Language.HI, Language.HINGLISH, Language.EN])
        elif detected_language in [Language.SD, Language.KS]:
            language_attempts.extend([Language.UR, Language.EN])
        elif detected_language in [Language.MNI, Language.BRX, Language.SAT]:
            language_attempts.extend([Language.BN, Language.EN])
    
    best_category = ScamCategory.UNKNOWN
    best_confidence = 0.0
    best_matches = []
    
    for language in language_attempts:
        for category_str, lang_keywords in KEYWORDS_DICT.items():
            if language not in lang_keywords:
                continue
            
            keywords = lang_keywords[language]
            matches = [kw for kw in keywords if kw.lower() in transcript_lower]
            
            if matches:
                # Confidence based on number of matches
                confidence = min(1.0, len(matches) / 2.0)
                
                if confidence > best_confidence:
                    # Map string back to enum
                    best_category = _CATEGORY_MAP.get(category_str, ScamCategory.UNKNOWN)
                    best_confidence = confidence
                    best_matches = matches
    
    return best_category, best_confidence, best_matches


def get_category_description(category: ScamCategory) -> str:
    """Get human-readable description for a scam category."""
    descriptions = {
        ScamCategory.OTP_REQUEST: "Caller is asking for OTP/verification code",
        ScamCategory.BANK_ACCOUNT_REQUEST: "Caller is asking for bank account details",
        ScamCategory.CARD_DETAILS_REQUEST: "Caller is asking for card details",
        ScamCategory.PIN_REQUEST: "Caller is asking for PIN",
        ScamCategory.CVV_REQUEST: "Caller is asking for CVV",
        ScamCategory.CARD_NUMBER_REQUEST: "Caller is asking for card number",
        ScamCategory.PASSWORD_REQUEST: "Caller is asking for password",
        ScamCategory.UPI_REQUEST: "Caller is asking for UPI details",
        ScamCategory.KYC_REQUEST: "Caller is asking for KYC documents",
        ScamCategory.PERSONAL_INFORMATION_REQUEST: "Caller is asking for personal information",
        ScamCategory.AADHAAR_REQUEST: "Caller is asking for Aadhaar",
        ScamCategory.PAN_REQUEST: "Caller is asking for PAN",
        ScamCategory.PAYMENT_REQUEST: "Caller is demanding payment",
        ScamCategory.MONEY_TRANSFER: "Caller is asking for money transfer",
        ScamCategory.REFUND_SCAM: "Caller is offering fake refund",
        ScamCategory.LOTTERY_SCAM: "Caller is offering fake lottery/prize",
        ScamCategory.PRIZE_SCAM: "Caller is offering fake prize",
        ScamCategory.INVESTMENT_SCAM: "Caller is offering fake investment",
        ScamCategory.LOAN_SCAM: "Caller is offering fake loan",
        ScamCategory.JOB_SCAM: "Caller is offering fake job",
        ScamCategory.POLICE_SCAM: "Caller is impersonating police",
        ScamCategory.CYBERCRIME_IMPERSONATION: "Caller is impersonating cybercrime",
        ScamCategory.BANK_IMPERSONATION: "Caller is impersonating a bank",
        ScamCategory.GOVERNMENT_IMPERSONATION: "Caller is impersonating government",
        ScamCategory.REMOTE_ACCESS: "Caller is asking for remote access",
        ScamCategory.SCREEN_SHARING: "Caller is asking for screen sharing",
        ScamCategory.MALICIOUS_LINK: "Caller is asking to click malicious link",
        ScamCategory.QR_CODE_SCAM: "Caller is asking to scan QR code",
        ScamCategory.CALL_BACK_REQUEST: "Caller is asking for callback",
        ScamCategory.THREAT: "Caller is making threats",
        ScamCategory.ARREST_THREAT: "Caller is threatening arrest",
        ScamCategory.ACCOUNT_BLOCK_THREAT: "Caller claims account is blocked/suspended",
        ScamCategory.SIM_BLOCK_THREAT: "Caller claims SIM will be blocked",
        ScamCategory.KYC_EXPIRY: "Caller claims KYC has expired",
        ScamCategory.URGENT_ACTION: "Caller is demanding urgent action",
        ScamCategory.FEAR_PRESSURE: "Caller is using fear pressure",
        ScamCategory.SECRECY_REQUEST: "Caller is asking for secrecy",
        ScamCategory.UNKNOWN: "Unknown scam pattern",
    }
    return descriptions.get(category, "Unknown scam pattern")
