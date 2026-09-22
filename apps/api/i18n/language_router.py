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

Supported languages:
  Hindi (hi), Bengali (bn), Tamil (ta), Telugu (te), Marathi (mr),
  Gujarati (gu), Kannada (kn), Punjabi (pa), Malayalam (ml), Odia (or),
  Urdu (ur), Assamese (as), Nepali (ne), Sindhi (sd), Sanskrit (sa).

Whisper-large-v3 natively supports all of the above.
"""

from __future__ import annotations

import logging
import re
from typing import TypedDict

logger = logging.getLogger(__name__)

# ── Unicode script patterns for each Indian language ──────────────────────────
# These are DEFINITIVE signals — if these characters appear, we know the language.

_SCRIPT_PATTERNS: dict[str, tuple[str, re.Pattern]] = {
    # (whisper_lang_code, pattern)
    "hi": ("hi", re.compile(r"[\u0900-\u097F]")),          # Devanagari (Hindi/Marathi/Nepali)
    "bn": ("bn", re.compile(r"[\u0980-\u09FF]")),          # Bengali
    "ta": ("ta", re.compile(r"[\u0B80-\u0BFF]")),          # Tamil
    "te": ("te", re.compile(r"[\u0C00-\u0C7F]")),          # Telugu
    "gu": ("gu", re.compile(r"[\u0A80-\u0AFF]")),          # Gujarati
    "kn": ("kn", re.compile(r"[\u0C80-\u0CFF]")),          # Kannada
    "ml": ("ml", re.compile(r"[\u0D00-\u0D7F]")),          # Malayalam
    "pa": ("pa", re.compile(r"[\u0A00-\u0A7F]")),          # Gurmukhi (Punjabi)
    "or": ("or", re.compile(r"[\u0B00-\u0B7F]")),          # Odia
    "ur": ("ur", re.compile(r"[\u0600-\u06FF]")),          # Arabic/Urdu script
    "as": ("as", re.compile(r"[\u0980-\u09FF]")),          # Assamese (same as Bengali block)
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
    detected_lang: str            # ISO 639-1 code: 'hi', 'bn', 'ta', etc.
    detected_script: str | None   # Script name: 'devanagari', 'bengali', etc.
    has_indian_script: bool       # True if any Indian script character found
    hinglish_confidence: float    # 0–1 estimate of Indian language mixing
    recommended_llm_lang: str     # Language label for LLM prompt routing
    stt_language_hint: str | None # Language hint for Whisper STT


def detect_language(text: str) -> LanguageDetectionResult:
    """
    Detect the language/script in a transcript segment.
    Supports all 15+ Indian languages via Unicode script detection.

    Parameters
    ----------
    text : str
        Transcript text (may be Hinglish/mixed/any Indian language).

    Returns
    -------
    LanguageDetectionResult dict with Whisper language hint.
    """
    # ── Step 1: Unicode script detection (most reliable) ──────────────────────
    detected_script: str | None = None
    script_lang: str | None = None

    for lang_code, (whisper_code, pattern) in _SCRIPT_PATTERNS.items():
        if pattern.search(text):
            detected_script = lang_code
            script_lang = whisper_code
            break  # First match wins (scripts are non-overlapping)

    has_indian_script = detected_script is not None

    # ── Step 2: Keyword-based confidence for Romanized Indian text ─────────────
    text_lower = text.lower()
    keyword_hits = sum(1 for kw in _INDIAN_SCAM_KEYWORDS if kw in text_lower)
    hinglish_confidence = min(1.0, keyword_hits / max(1, len(_INDIAN_SCAM_KEYWORDS) * 0.3))

    # Check for Marathi-specific keywords (distinguish from Hindi Devanagari)
    marathi_hits = sum(1 for kw in _MARATHI_KEYWORDS if kw in text_lower)
    if marathi_hits >= 2 and detected_script == "hi":
        script_lang = "mr"  # Likely Marathi not Hindi

    # ── Step 3: langdetect + English heuristic ──────────────────────────────
    detected_lang = "hi"  # Default to Hindi for India market
    is_pure_english = False

    if not has_indian_script:
        # Check if the text is purely ASCII (strong English signal)
        printable_chars = [c for c in text if c.strip()]
        if printable_chars:
            ascii_ratio = sum(1 for c in printable_chars if ord(c) < 128) / len(printable_chars)
            # If >95% ASCII AND no Indian keywords -> likely pure English
            if ascii_ratio > 0.95 and hinglish_confidence == 0.0:
                is_pure_english = True
                detected_lang = "en"

        if not is_pure_english:
            try:
                from langdetect import detect  # type: ignore[import]
                raw_lang = detect(text) if len(text.strip()) > 20 else "hi"
                detected_lang = _LANGDETECT_TO_WHISPER.get(raw_lang, "hi")
            except Exception:
                detected_lang = "hi"
    else:
        detected_lang = script_lang or "hi"

    # ── Step 4: Determine Whisper STT hint ────────────────────────────────────
    if has_indian_script and script_lang:
        # Script detected → use exact language code (most accurate)
        stt_hint = script_lang
        recommended_llm_lang = script_lang
    elif hinglish_confidence > 0.15:
        # Romanized Indian text detected → Hindi/Hinglish mode
        stt_hint = "hi"
        recommended_llm_lang = "hinglish"
    elif is_pure_english:
        # Pure English (>95% ASCII, no Indian keywords) → let Whisper auto-detect
        stt_hint = None  # None = Whisper auto-detect (best for English)
        recommended_llm_lang = "en"
    else:
        # Ambiguous / no clear signal → default 'hi' for India market
        # Prevents hallucination (Spanish/Korean) on short/silent segments
        stt_hint = "hi"
        recommended_llm_lang = detected_lang

    logger.debug(
        "Language detection: script=%r lang=%r hinglish_conf=%.2f stt_hint=%r",
        detected_script, detected_lang, hinglish_confidence, stt_hint,
    )

    return LanguageDetectionResult(
        detected_lang=detected_lang,
        detected_script=detected_script,
        has_indian_script=has_indian_script,
        hinglish_confidence=hinglish_confidence,
        recommended_llm_lang=recommended_llm_lang,
        stt_language_hint=stt_hint,
    )


def get_multilingual_system_prompt_addon(lang: str = "hinglish") -> str:
    """
    Additional system prompt text for multi-language Indian call analysis.
    Instructs the LLM to handle the detected language correctly.
    """
    prompts = {
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
        "ta": (
            "\nIMPORTANT: This transcript is in Tamil. Parse Tamil text accurately. "
            "Key scam terms: 'panam'=money, 'bank account'=bank account, "
            "'police'=police, 'court notice'=court notice."
        ),
        "te": (
            "\nIMPORTANT: This transcript is in Telugu. Parse Telugu text accurately. "
            "Identify scam-related claims about money, police, courts, or government schemes."
        ),
        "bn": (
            "\nIMPORTANT: This transcript is in Bengali. Parse Bengali text accurately. "
            "Key scam terms: 'taka'=money, 'bank'=bank, 'police'=police."
        ),
        "mr": (
            "\nIMPORTANT: This transcript is in Marathi. Parse Marathi text accurately. "
            "Key scam terms: 'paise'=money, 'bank'=bank, 'police'=police, 'court'=court."
        ),
        "gu": (
            "\nIMPORTANT: This transcript is in Gujarati. Parse Gujarati text accurately. "
            "Identify scam-related claims about money, police, courts, or government schemes."
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
