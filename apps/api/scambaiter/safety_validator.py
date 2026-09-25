"""
scambaiter/safety_validator.py — Two-layer safety filter for agent-generated questions.

Layer 1: Block questions that ask for real credentials/PINs/OTPs.
Layer 2: Block questions that impersonate authority or make threats.

⚠️  IMPORTANT — Hindi/Devanagari coverage is BEST-EFFORT, not guaranteed.
    Hindi STT transcripts of spoken scam calls have significant spelling/phrasing
    variance. These patterns catch common forms but a native Hindi speaker should
    audit them before relying on them in production.

    What these patterns DO guarantee: Latin-script output from the LLM is fully
    covered. The Devanagari patterns add a meaningful extra layer but are not exhaustive.
"""

import re
import logging
from typing import Tuple, Optional

logger = logging.getLogger(__name__)

# ── Layer 1: Block credential-harvesting questions ────────────────────────────
# Covers both Latin-script (guaranteed) and Devanagari (best-effort).

_SENSITIVE_CREDENTIALS_PATTERNS = [
    # Latin-script (LLM output — comprehensive)
    re.compile(r"\b(otp|pin|cvv|password|passcode)\b", re.IGNORECASE),
    re.compile(r"authentication\s+code", re.IGNORECASE),
    re.compile(r"card\s+number", re.IGNORECASE),
    re.compile(r"account\s+number", re.IGNORECASE),
    re.compile(r"secret\s+(code|number|key)", re.IGNORECASE),

    # Devanagari / Hindi forms (best-effort — needs native speaker review)
    # OTP: ओ.टी.पी., ओटीपी, OTP (already caught by Latin rule above)
    re.compile(r"ओ\.?टी\.?पी\.?"),
    re.compile(r"ओटीपी"),
    # PIN: पिन, पासवर्ड
    re.compile(r"पिन\s*(नंबर|बताइए|दें|दो|क्या है)?"),
    re.compile(r"पासवर्ड"),
    # ATM / card number: कार्ड नंबर, एटीएम नंबर
    re.compile(r"कार्ड\s*नंबर"),
    re.compile(r"एटीएम\s*(नंबर|पिन|कार्ड)"),
    # Account number: खाता नंबर, अकाउंट नंबर
    re.compile(r"खाता\s*(नंबर|संख्या)"),
    re.compile(r"अकाउंट\s*नंबर"),
    # CVV: सीवीवी
    re.compile(r"सीवीवी"),
]

# ── Layer 2: Block self-referential impersonation and explicit threats ─────────
# Intent: stop the agent from saying "I am with CBI" or "you will be arrested".
# NOT intended to block clarifying questions ABOUT authorities (e.g. "which station?").

_DANGEROUS_BEHAVIOR_PATTERNS = [
    # Latin-script self-impersonation
    re.compile(
        r"\b(i am|i'm|we are|we're|this is|speaking|calling)\s+(with|from|the|as)\s+"
        r"(police|cbi|fbi|irs|ed|enforcement|government|court|judge|magistrate)\b",
        re.IGNORECASE,
    ),
    # Latin-script explicit threats
    re.compile(r"\b(will arrest|put you in jail|send police|issue warrant|file fir)\b", re.IGNORECASE),
    re.compile(r"\b(kill|hurt|threaten|sue you)\b", re.IGNORECASE),

    # Devanagari self-impersonation (best-effort)
    # "मैं पुलिस/CBI/ED से हूँ" / "हम पुलिस हैं"
    re.compile(r"(मैं|हम)\s+(पुलिस|सीबीआई|ईडी|कोर्ट|सरकार)\s+(से|का|की|के)\s+(हूँ|हैं|बोल)"),
    re.compile(r"(पुलिस|सीबीआई|ईडी)\s+से\s+बात\s+कर\s*रहे?\s+हैं?"),
    # "आपको गिरफ्तार किया जाएगा" / "आप गिरफ्तार होंगे"
    re.compile(r"गिरफ्तार\s+(किया\s+जाएगा|होंगे|करेंगे)"),
    # "वारंट जारी होगा"
    re.compile(r"वारंट\s+(जारी|निकाल)"),
]


def validate_question(question: str) -> Tuple[bool, Optional[str]]:
    """
    Validates a question the agent wants to speak aloud.

    Returns
    -------
    (True, None)          — question is safe, use it as-is.
    (False, replacement)  — question is unsafe; use replacement instead.

    The replacement is always a safe, open-ended probe so the agent doesn't
    go silent on a live call.
    """
    if not question or not question.strip():
        return False, "Could you explain a bit more about why you are calling?"

    for pattern in _SENSITIVE_CREDENTIALS_PATTERNS:
        if pattern.search(question):
            logger.warning(
                "SafetyValidator: BLOCKED — credential-harvesting question: %r", question[:120]
            )
            return False, "Could you explain a bit more about why you are calling?"

    for pattern in _DANGEROUS_BEHAVIOR_PATTERNS:
        if pattern.search(question):
            logger.warning(
                "SafetyValidator: BLOCKED — impersonation/threat question: %r", question[:120]
            )
            return False, "Could you explain a bit more about why you are calling?"

    return True, None
