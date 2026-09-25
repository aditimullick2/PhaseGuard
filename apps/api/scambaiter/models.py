from typing import Literal, Optional
from pydantic import BaseModel


class AgentAction(BaseModel):
    """
    Structured action the agent decides to take for one scambaiter turn.

    The LLM must produce reason BEFORE question — the forced ordering improves
    question specificity on Groq models empirically. Both fields are optional
    so failed/partial parses don't hard-crash validation.

    action:
        ASK_QUESTION      — speak a specific question derived from caller's last utterance
        COUNTER_QUESTION  — stay in-persona, deflect with a confused/clarifying probe
                            (used when there's no new concrete detail to pin down yet)
        WAIT              — caller is mid-sentence / nothing actionable yet
        END_CONVERSATION  — max turns reached or caller revealed enough
        ESCALATE          — pattern indicates serious immediate danger (rare)
        NO_ACTION         — parse failure / undecidable
    """

    action: Literal[
        "ASK_QUESTION",
        "COUNTER_QUESTION",
        "WAIT",
        "END_CONVERSATION",
        "ESCALATE",
        "NO_ACTION",
    ]
    language: str = "hi"  # ISO 639-1 code of intended response language
    # reasoning fields — model fills these BEFORE question, improves output quality
    reason: Optional[str] = None           # e.g. "caller mentioned case number XYZ-123"
    target_fact: Optional[str] = None      # specific token/claim to probe
    risk_relevance: Optional[str] = None   # why this question matters forensically
    # output field
    question: Optional[str] = None         # the actual spoken question or counter-question
    confidence: float = 0.0
