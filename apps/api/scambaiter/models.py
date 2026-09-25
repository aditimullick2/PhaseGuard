from typing import Literal, Optional
from pydantic import BaseModel

class AgentAction(BaseModel):
    action: Literal["ASK_QUESTION", "WAIT", "END_CONVERSATION", "ESCALATE", "NO_ACTION"]
    language: str
    question: Optional[str] = None
    target_fact: Optional[str] = None
    reason: Optional[str] = None
    risk_relevance: Optional[str] = None
    confidence: float = 0.0
