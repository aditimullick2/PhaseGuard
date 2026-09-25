from typing import Any, Dict, Optional
import logging
from core.config import get_settings

logger = logging.getLogger(__name__)

class QuestionPlanner:
    def plan(self, context: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        agent = context.get("agent", {})
        questions_asked = agent.get("questions_asked", 0)
        max_questions = agent.get("max_questions", get_settings().max_agent_turns)

        if questions_asked >= max_questions:
            logger.info("QuestionPlanner: Max questions reached (%d). Returning None.", questions_asked)
            return None
        
        # Check if anything changed since last turn
        # We can track 'last_processed_turn_id' or 'turn_number' vs some recorded state.
        # For simplicity, if caller speech hasn't advanced, we skip.
        # But wait, this is evaluated per turn, so it's always a new caller speech.
        # If the caller's extracted claim is identical to last turn (nothing new), we should return None.
        
        # Determine priority plan
        contradictions = context.get("conversation", {}).get("contradictions", [])
        if contradictions:
            return {"priority": 6, "focus": "Address a recorded contradiction", "details": contradictions[-1]}

        caller = context.get("caller", {})
        if not caller.get("claimed_organization") and not caller.get("claimed_identity"):
            return {"priority": 1, "focus": "Clarify caller identity/organization claim"}
            
        scenario = context.get("scenario", {})
        if not scenario.get("reason_for_call"):
            return {"priority": 2, "focus": "Clarify reason for call"}
            
        if not scenario.get("requested_action"):
            return {"priority": 3, "focus": "Clarify requested action"}
            
        if not scenario.get("urgency") or scenario.get("urgency") == "UNKNOWN":
            return {"priority": 4, "focus": "Clarify claimed urgency"}
            
        if not scenario.get("claimed_reference_number") and not scenario.get("claimed_case_number"):
            return {"priority": 5, "focus": "Clarify reference/case information"}
            
        return {"priority": 7, "focus": "Verify other safely-questionable details"}
