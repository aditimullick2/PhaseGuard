"""
i18n/language_router.py — Multi-language detection for all Indian languages.

Problem:
  Real Indian scam calls happen in 22+ languages (Hindi, Bengali, Tamil, Telugu,
  Marathi, Gujarati, Kannada, Punjabi, Malayalam, Odia, Urdu, etc.).
  A pure English STT/LLM pipeline misses key scam phrases delivered in any
  Indian language or Hinglish code-switching.

Solutions implemented here:
  1. Script-based detection: Unicode block patterns for each Indian script
     (most reliable — Devanagari, Bengali, Tamil, Telugu, etc. are distinct).
  2. Hinglish keyword detection: Roman-script Indian scam terms.
  3. langdetect fallback: probabilistic language detection for Romanized text.
  4. STT hint: passes correct ISO 639-1 language code to Whisper so it
     transcribes accurately in the detected language.
  5. UNKNOWN/UNCERTAIN handling for low-confidence detections.

Supported languages (VERIFIED - Whisper-large-v3 supports):
  Tier 1:
  - English (en)
  - Hindi (hi)
  - Odia (or)
  - Bengali (bn)
  - Assamese (as)
  - Marathi (mr)
  - Gujarati (gu)
  - Punjabi (pa)
  - Urdu (ur)
  - Tamil (ta)
  - Telugu (te)
  - Kannada (kn)
  - Malayalam (ml)

  Tier 2 (EXPERIMENTAL - may need fallback):
  - Nepali (ne)
  - Sindhi (sd)
  - Sanskrit (sa)
  - Bhojpuri (bho)

  Tier 3 (UNVERIFIED - requires real-device testing):
  - Konkani (kok)
  - Kashmiri (ks)
  - Maithili (mai)
  - Dogri (doi)
  - Manipuri (mni)
  - Bodo (brx)
  - Santali (sat)

Note: EXPERIMENTAL/UNVERIFIED languages will fall back to UNKNOWN or nearest
      verified language if Whisper does not support them reliably.
"""

from __future__ import annotations

import logging
import re
from typing import TypedDict

logger = logging.getLogger(__name__)

# ── Unicode script patterns for each Indian language ──────────────────────────
# These are DEFINITIVE signals — if these characters appear, we know the language.

_SCRIPT_PATTERNS: dict[str, tuple[str, re.Pattern, str]] = {
    # (whisper_lang_code, pattern, support_level)
    # support_level: "VERIFIED", "EXPERIMENTAL", "UNVERIFIED"
    
    # Tier 1: VERIFIED (Whisper-large-v3 supports)
    "hi": ("hi", re.compile(r"[\u0900-\u097F]"), "VERIFIED"),      # Devanagari (Hindi/Marathi/Nepali)
    "bn": ("bn", re.compile(r"[\u0980-\u09FF]"), "VERIFIED"),      # Bengali
    "ta": ("ta", re.compile(r"[\u0B80-\u0BFF]"), "VERIFIED"),      # Tamil
    "te": ("te", re.compile(r"[\u0C00-\u0C7F]"), "VERIFIED"),      # Telugu
    "gu": ("gu", re.compile(r"[\u0A80-\u0AFF]"), "VERIFIED"),      # Gujarati
    "kn": ("kn", re.compile(r"[\u0C80-\u0CFF]"), "VERIFIED"),      # Kannada
    "ml": ("ml", re.compile(r"[\u0D00-\u0D7F]"), "VERIFIED"),      # Malayalam
    "pa": ("pa", re.compile(r"[\u0A00-\u0A7F]"), "VERIFIED"),      # Gurmukhi (Punjabi)
    "or": ("or", re.compile(r"[\u0B00-\u0B7F]"), "VERIFIED"),      # Odia
    "ur": ("ur", re.compile(r"[\u0600-\u06FF]"), "VERIFIED"),      # Arabic/Urdu script
    "as": ("as", re.compile(r"[\u0980-\u09FF]"), "VERIFIED"),      # Assamese (same as Bengali block)
    
    # Tier 2: EXPERIMENTAL (may need fallback to nearest verified language)
    "ne": ("ne", re.compile(r"[\u0900-\u097F]"), "EXPERIMENTAL"),  # Nepali (Devanagari)
    "sd": ("sd", re.compile(r"[\u0600-\u06FF]"), "EXPERIMENTAL"),  # Sindhi (Arabic script)
    "sa": ("sa", re.compile(r"[\u0900-\u097F]"), "EXPERIMENTAL"),  # Sanskrit (Devanagari)
    "bho": ("hi", re.compile(r"[\u0900-\u097F]"), "EXPERIMENTAL"), # Bhojpuri (uses Hindi Devanagari)
    
    # Tier 3: UNVERIFIED (requires real-device testing)
    # Note: Some of these may not have distinct Unicode blocks or Whisper support
    "kok": ("hi", re.compile(r"[\u0900-\u097F]"), "UNVERIFIED"),    # Konkani (uses Devanagari)
    "ks": ("ur", re.compile(r"[\u0600-\u06FF]"), "UNVERIFIED"),      # Kashmiri (Arabic script)
    "mai": ("hi", re.compile(r"[\u0900-\u097F]"), "UNVERIFIED"),    # Maithili (uses Devanagari)
    "doi": ("hi", re.compile(r"[\u0900-\u097F]"), "UNVERIFIED"),    # Dogri (uses Devanagari)
    "mni": ("bn", re.compile(r"[\uABC0-\uABFF]"), "UNVERIFIED"),    # Manipuri (Meitei script)
    "brx": ("bn", re.compile(r"[\u0980-\u09FF]"), "UNVERIFIED"),    # Bodo (uses Devanagari)
    "sat": ("bn", re.compile(r"[\u1C50-\u1C7F]"), "UNVERIFIED"),    # Santali (Ol Chiki script)
}

# Marathi uses same Devanagari script as Hindi but langdetect can distinguish
# For STT purposes, both use 'mr' or 'hi' — Whisper handles Marathi with 'mr'
_MARATHI_KEYWORDS = [
    "ahe", "nahi", "aahe", "ka", "pan", "tumi", "aplya", "sarkar",
    "rupaye", "paise", "bank", "khate",
]

# Common Indian scam keywords in Roman script (Hinglish + regional Romanization)
# NOTE: Only include words that are DISTINCTLY Indian/Hinglish.
# Do NOT add common English words (account, block, police, otp etc.) as they
# cause false-positives when detecting pure English text.
_INDIAN_SCAM_KEYWORDS = [
    # Distinctly Hindi/Hinglish (these won't appear in pure English)
    "aadhaar", "aadhar", "paisa", "paise", "rupaye", "rupaya",
    "giraftaar", "nahin", "nahi", "kyunki",
    "aap", "aapka", "aapko", "hamare",
    "sarkar", "sarkari", "yojana",
    "pradhan mantri", "pm modi",
    "digital arrest", "cbdt", "enforcement directorate",
    "band karo", "band ho", "pakad",
    # Tamil Romanized (distinctly Tamil)
    "vanakkam", "annai", "amma", "panam", "kaasu", "vazhangu",
    # Telugu Romanized (distinctly Telugu)
    "meeru", "bayam", "jagratha",
    # Bengali Romanized (distinctly Bengali)
    "taka", "jomi", "bari",
    # Gujarati Romanized (distinctly Gujarati)
    "tamara", "challan vikri",
    # Punjabi Romanized (distinctly Punjabi)
    "tussi", "kinne",
    # Marathi Romanized (distinctly Marathi)
    "tumhi", "aple",
]

# langdetect → Whisper language code mapping for Indian languages
_LANGDETECT_TO_WHISPER: dict[str, str] = {
    "hi": "hi",  # Hindi
    "bn": "bn",  # Bengali
    "ta": "ta",  # Tamil
    "te": "te",  # Telugu
    "mr": "mr",  # Marathi
    "gu": "gu",  # Gujarati
    "kn": "kn",  # Kannada
    "pa": "pa",  # Punjabi
    "ml": "ml",  # Malayalam
    "or": "or",  # Odia
    "ur": "ur",  # Urdu
    "as": "as",  # Assamese
    "ne": "ne",  # Nepali
    "sd": "sd",  # Sindhi
    "sa": "sa",  # Sanskrit
    # Romanized/Hinglish often mis-detected as:
    "en": "hi",  # Default to Hindi for India market
    "tl": "hi",  # Filipino often confused with Hinglish
    "id": "hi",  # Indonesian confused with Hinglish
}


class LanguageDetectionResult(TypedDict):
    detected_lang: str            # ISO 639-1 code: 'hi', 'bn', 'ta', etc. or 'UNKNOWN'
    detected_script: str | None   # Script name: 'devanagari', 'bengali', etc.
    has_indian_script: bool       # True if any Indian script character found
    hinglish_confidence: float    # 0–1 estimate of Indian language mixing
    recommended_llm_lang: str     # Language label for LLM prompt routing
    stt_language_hint: str | None # Language hint for Whisper STT
    support_level: str            # 'VERIFIED', 'EXPERIMENTAL', 'UNVERIFIED'
    confidence: float             # Overall detection confidence (0-1)
    is_code_switched: bool        # True if multiple languages detected
    primary_language: str | None  # Primary language detected
    secondary_languages: list[str] # Secondary languages detected


def detect_language(text: str) -> LanguageDetectionResult:
    """
    Detect the language/script in a transcript segment.
    Supports all Indian languages via Unicode script detection.
    Returns UNKNOWN/UNCERTAIN for low-confidence detections.

    Parameters
    ----------
    text : str
        Transcript text (may be Hinglish/mixed/any Indian language).

    Returns
    -------
    LanguageDetectionResult dict with Whisper language hint and confidence.
    """
    # ── Step 0: Early exit for empty/short text ─────────────────────────────
    if not text or len(text.strip()) < 10:
        return LanguageDetectionResult(
            detected_lang="UNKNOWN",
            detected_script=None,
            has_indian_script=False,
            hinglish_confidence=0.0,
            recommended_llm_lang="en",
            stt_language_hint=None,  # Let Whisper auto-detect
            support_level="VERIFIED",
            confidence=0.0,
            is_code_switched=False,
            primary_language=None,
            secondary_languages=[],
        )

    # ── Step 1: Unicode script detection (most reliable) ──────────────────────
    detected_script: str | None = None
    script_lang: str | None = None
    support_level = "UNVERIFIED"
    detected_scripts = []  # Track all scripts for code-switching detection

    for lang_code, (whisper_code, pattern, supp_level) in _SCRIPT_PATTERNS.items():
        if pattern.search(text):
            detected_scripts.append(lang_code)
            if detected_script is None:
                detected_script = lang_code
                script_lang = whisper_code
                support_level = supp_level
            # Don't break - detect all scripts for code-switching

    has_indian_script = detected_script is not None
    is_code_switched = len(detected_scripts) > 1

    # ── Step 2: Keyword-based confidence for Romanized Indian text ─────────────
    text_lower = text.lower()
    keyword_hits = sum(1 for kw in _INDIAN_SCAM_KEYWORDS if kw in text_lower)
    hinglish_confidence = min(1.0, keyword_hits / max(1, len(_INDIAN_SCAM_KEYWORDS) * 0.3))

    # Check for Marathi-specific keywords (distinguish from Hindi Devanagari)
    marathi_hits = sum(1 for kw in _MARATHI_KEYWORDS if kw in text_lower)
    if marathi_hits >= 2 and detected_script == "hi":
        script_lang = "mr"  # Likely Marathi not Hindi
        detected_script = "mr"

    # ── Step 3: langdetect + English heuristic ──────────────────────────────
    detected_lang = "UNKNOWN"
    confidence = 0.0
    is_pure_english = False
    primary_language = None
    secondary_languages = []

    if not has_indian_script:
        # Check if the text is purely ASCII (strong English signal)
        printable_chars = [c for c in text if c.strip()]
        if printable_chars:
            ascii_ratio = sum(1 for c in printable_chars if ord(c) < 128) / len(printable_chars)
            # If >95% ASCII AND no Indian keywords -> likely pure English
            if ascii_ratio > 0.95 and hinglish_confidence == 0.0:
                is_pure_english = True
                detected_lang = "en"
                confidence = 0.95
                primary_language = "en"
                support_level = "VERIFIED"

        if not is_pure_english:
            # Romanized Indian text - use langdetect
            try:
                from langdetect import detect  # type: ignore[import]
                if len(text.strip()) > 20:
                    raw_lang = detect(text)
                    detected_lang = _LANGDETECT_TO_WHISPER.get(raw_lang, "UNKNOWN")
                    confidence = 0.6  # langdetect is probabilistic
                    primary_language = detected_lang
                    support_level = "EXPERIMENTAL"
                else:
                    # Too short for reliable detection
                    detected_lang = "UNKNOWN"
                    confidence = 0.2
            except Exception:
                detected_lang = "UNKNOWN"
                confidence = 0.0
    else:
        # Script detected - this is high confidence
        detected_lang = script_lang or "UNKNOWN"
        confidence = 0.9 if support_level == "VERIFIED" else 0.5
        primary_language = detected_lang
        
        # For EXPERIMENTAL/UNVERIFIED, consider fallback
        if support_level in ("EXPERIMENTAL", "UNVERIFIED"):
            confidence = 0.4
            secondary_languages = [detected_lang]  # Mark as secondary

    # ── Step 4: Handle code-switching ────────────────────────────────────────
    if is_code_switched:
        # Multiple scripts detected - this is code-switching
        # Use the first detected as primary, others as secondary
        secondary_languages = detected_scripts[1:]
        confidence = min(confidence, 0.7)  # Reduce confidence for mixed scripts

    # ── Step 5: Determine Whisper STT hint with UNKNOWN handling ─────────────
    stt_hint = None
    recommended_llm_lang = "en"

    if confidence < 0.3:
        # Low confidence - return UNKNOWN, let Whisper auto-detect
        detected_lang = "UNKNOWN"
        stt_hint = None
        recommended_llm_lang = "en"
        logger.info(
            "Language detection: LOW_CONFIDENCE (confidence=%.2f) -> UNKNOWN, auto-detect",
            confidence
        )
    elif support_level == "UNVERIFIED":
        # UNVERIFIED language - log warning, use nearest verified or auto-detect
        logger.warning(
            "Language detection: UNVERIFIED language %r detected, using auto-detect",
            detected_lang
        )
        stt_hint = None
        recommended_llm_lang = "en"
    elif support_level == "EXPERIMENTAL":
        # EXPERIMENTAL language - use with caution
        if confidence > 0.6:
            stt_hint = script_lang
            recommended_llm_lang = detected_lang
        else:
            stt_hint = None
            recommended_llm_lang = "en"
    elif has_indian_script and script_lang and support_level == "VERIFIED":
        # VERIFIED script detected → use exact language code (most accurate)
        stt_hint = script_lang
        recommended_llm_lang = script_lang
    elif hinglish_confidence > 0.15:
        # Romanized Indian text detected → Hindi/Hinglish mode
        stt_hint = "hi"
        recommended_llm_lang = "hinglish"
        detected_lang = "hi"
        primary_language = "hi"
        confidence = min(confidence + 0.2, 0.8)
    elif is_pure_english:
        # Pure English (>95% ASCII, no Indian keywords) → let Whisper auto-detect
        stt_hint = None
        recommended_llm_lang = "en"
    else:
        # Ambiguous / no clear signal → let Whisper auto-detect
        # DO NOT default to 'hi' - this was the bug
        stt_hint = None
        recommended_llm_lang = "en"
        detected_lang = "UNKNOWN"
        confidence = 0.1

    logger.debug(
        "Language detection: script=%r lang=%r confidence=%.2f support=%s stt_hint=%r code_switched=%s",
        detected_script, detected_lang, confidence, support_level, stt_hint, is_code_switched,
    )

    return LanguageDetectionResult(
        detected_lang=detected_lang,
        detected_script=detected_script,
        has_indian_script=has_indian_script,
        hinglish_confidence=hinglish_confidence,
        recommended_llm_lang=recommended_llm_lang,
        stt_language_hint=stt_hint,
        support_level=support_level,
        confidence=confidence,
        is_code_switched=is_code_switched,
        primary_language=primary_language,
        secondary_languages=secondary_languages,
    )


def get_multilingual_system_prompt_addon(lang: str = "hinglish") -> str:
    """
    Additional system prompt text for multi-language Indian call analysis.
    Instructs the LLM to handle the detected language correctly.
    """
    prompts = {
        "en": (
            "\nIMPORTANT: This transcript is in English. Parse English text accurately. "
            "Identify scam-related claims about money, OTP, bank accounts, police, courts, "
            "or government schemes."
        ),
        "hi": (
            "\nIMPORTANT: This transcript is in Hindi. Parse Hindi text accurately. "
            "Key Hindi scam terms: 'giraftaar'=arrested, 'warrant'=arrest warrant, "
            "'paisa/paise'=money, 'khata'=account, 'band'=blocked, 'OTP daalo'=enter OTP, "
            "'PIN batao'=share PIN, 'CBI/police/court ne pakad liya'=caught by authorities."
        ),
        "hinglish": (
            "\nIMPORTANT: This transcript may contain Hindi, Hinglish (Hindi-English mix), "
            "or Roman-script Hindi. Parse all languages equally. Key Hindi scam terms:\n"
            "- 'giraftaar' = arrested, 'warrant' = arrest warrant\n"
            "- 'paisa/paise' = money, 'khata' = account, 'band' = blocked/closed\n"
            "- 'OTP daalo' = enter OTP, 'PIN batao' = share PIN\n"
            "- 'CBI/police/court ne pakad liya' = caught by authorities\n"
            "Treat Hinglish claims with the same seriousness as English ones."
        ),
        "or": (
            "\nIMPORTANT: This transcript is in Odia. Parse Odia text accurately. "
            "Key Odia scam terms: 'ପଇସା'=money, 'ବ୍ୟାଙ୍କ ଖାତା'=bank account, "
            "'ପୋଲିସ୍'=police, 'ଓଟିପି'=OTP."
        ),
        "bn": (
            "\nIMPORTANT: This transcript is in Bengali. Parse Bengali text accurately. "
            "Key scam terms: 'টাকা'=money, 'ব্যাংক'=bank, 'পুলিশ'=police."
        ),
        "as": (
            "\nIMPORTANT: This transcript is in Assamese. Parse Assamese text accurately. "
            "Key scam terms: 'টকা'=money, 'বেংক'=bank, 'পুলিচ'=police."
        ),
        "ta": (
            "\nIMPORTANT: This transcript is in Tamil. Parse Tamil text accurately. "
            "Key scam terms: 'பணம்'=money, 'வங்கி கணக்கு'=bank account, "
            "'போலீஸ்'=police, 'நீதிமன்ற அறிவிப்பு'=court notice."
        ),
        "te": (
            "\nIMPORTANT: This transcript is in Telugu. Parse Telugu text accurately. "
            "Identify scam-related claims about money, police, courts, or government schemes."
        ),
        "mr": (
            "\nIMPORTANT: This transcript is in Marathi. Parse Marathi text accurately. "
            "Key scam terms: 'पैसे'=money, 'बँक'=bank, 'पोलीस'=police, 'न्यायालय'=court."
        ),
        "gu": (
            "\nIMPORTANT: This transcript is in Gujarati. Parse Gujarati text accurately. "
            "Identify scam-related claims about money, police, courts, or government schemes."
        ),
        "pa": (
            "\nIMPORTANT: This transcript is in Punjabi. Parse Punjabi text accurately. "
            "Key scam terms: 'ਪੈਸੇ'=money, 'ਬੈਂਕ'=bank, 'ਪੁਲਿਸ'=police."
        ),
        "ur": (
            "\nIMPORTANT: This transcript is in Urdu. Parse Urdu text accurately. "
            "Key scam terms: 'پیسے'=money, 'بینک'=bank, 'پولیس'=police."
        ),
        "kn": (
            "\nIMPORTANT: This transcript is in Kannada. Parse Kannada text accurately. "
            "Key scam terms: 'ಹಣ'=money, 'ಬ್ಯಾಂಕು ಖಾತೆ'=bank account."
        ),
        "ml": (
            "\nIMPORTANT: This transcript is in Malayalam. Parse Malayalam text accurately. "
            "Key scam terms: 'പണം'=money, 'ബാങ്ക് അക്കൗണ്ട്'=bank account."
        ),
        "ne": (
            "\nIMPORTANT: This transcript is in Nepali. Parse Nepali text accurately. "
            "Key scam terms: 'पैसा'=money, 'बैंक'=bank, 'प्रहरी'=police."
        ),
    }
    return prompts.get(lang, prompts["hinglish"])


# Backward compatibility alias
def get_hinglish_system_prompt_addon() -> str:
    return get_multilingual_system_prompt_addon("hinglish")


# ── Bhashini API Integration — NOT WIRED FOR THIS BUILD ───────────────────────
# Bhashini (bhashini.gov.in) is the Government of India's language AI platform.
# It provides free APIs for ASR, translation, and TTS in 22 Indian languages.
# It is a PLANNED FUTURE UPGRADE PATH for deeper regional-language support.
#
# TO WIRE IN FUTURE:
#   1. Register at: https://bhashini.gov.in
#   2. Get BHASHINI_USER_ID, BHASHINI_API_KEY, BHASHINI_PIPELINE_ID
#   3. Add those to .env and implement a BhashiniClient class here.


async def get_bhashini_transcription(
    audio_base64: str,
    source_language: str = "hi",
) -> str | None:
    """
    Placeholder: Bhashini transcription is NOT WIRED in this build.
    Hindi/Hinglish is handled by Groq Whisper (native multilingual STT).
    Returns None always — callers should fall through to Groq.
    """
    logger.debug("Bhashini: not wired in this build — using Groq native multilingual STT")
    return None
