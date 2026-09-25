import re
import logging
from typing import Tuple, Optional

logger = logging.getLogger(__name__)

# Layer 1: Hardcoded regex rejecting sensitive credentials requests
_SENSITIVE_CREDENTIALS_PATTERNS = [
    re.compile(r"\b(otp|pin|cvv|password|passcode)\b", re.IGNORECASE),
    re.compile(r"authentication\s+code", re.IGNORECASE),
    re.compile(r"card\s+number", re.IGNORECASE),
    re.compile(r"account\s+number", re.IGNORECASE),
]

# Layer 2: Reject threats, harassment, authority impersonation, emergencies
_DANGEROUS_BEHAVIOR_PATTERNS = [
    re.compile(r"\b(police|cbi|fbi|arrest|warrant|prison|jail)\b", re.IGNORECASE),
    re.compile(r"\b(kill|hurt|threat|sue)\b", re.IGNORECASE),
    re.compile(r"emergency", re.IGNORECASE),
    re.compile(r"hospital|accident", re.IGNORECASE),
]

def validate_question(question: str) -> Tuple[bool, Optional[str]]:
    """
    Validates a generated question against safety rules.
    Returns (is_allowed, safe_replacement_question_if_rejected).
    """
    if not question:
        return False, "Could you tell me more about why you're calling?"

    for pattern in _SENSITIVE_CREDENTIALS_PATTERNS:
        if pattern.search(question):
            logger.warning("SafetyValidator: Rejected question due to sensitive credentials request: %r", question)
            return False, "Could you tell me more about why you're calling?"

    for pattern in _DANGEROUS_BEHAVIOR_PATTERNS:
        if pattern.search(question):
            logger.warning("SafetyValidator: Rejected question due to dangerous behavior/impersonation: %r", question)
            return False, "Could you tell me more about why you're calling?"

    return True, None
