"""
scambaiter/question_planner.py — Determines WHAT the agent should probe next.

Returns a "plan" dict passed into the LLM prompt so it can generate a
specific question grounded in the caller's last utterance. The plan is
intentionally terse — the LLM fills in the actual question wording.

Priority ordering (lower number = higher priority):
  1  Contradiction detected (scammer changed their story — highest value)
  2  Category-aware primary slot (scam-type-specific identity question)
  3  Reason for call / claimed problem
  4  Requested action (what scammer wants victim to DO)
  5  Urgency / deadline
  6  Reference / case number
  7  Secondary scam-specific follow-up
  8  Open-ended generic probe (fallback — always fires rather than going silent)
"""

from typing import Any, Dict, Optional
import logging

logger = logging.getLogger(__name__)

# Scam-category → primary identity slot to fill first.
# Values are plain-English descriptions fed directly into the LLM plan.
_CATEGORY_PRIMARY_SLOT: dict[str, str] = {
    "DIGITAL_ARREST":   "Clarify which police station or department the caller claims to represent",
    "UPI_FRAUD":        "Clarify which bank or payment platform the caller claims to be from",
    "KYC_SIM_BLOCK":    "Clarify which telecom operator or bank the caller claims represents",
    "LOTTERY_PRIZE":    "Clarify which lottery or government scheme the caller is referencing",
    "TECH_SUPPORT":     "Clarify which company the caller claims to be calling from",
    "LOAN_FRAUD":       "Clarify which financial institution or NBFC the caller is claiming to represent",
    "INVESTMENT_FRAUD": "Clarify which company or scheme name the caller is pitching",
    "CUSTOMS_PARCEL":   "Clarify which courier company or customs office the caller claims to be from",
    "UNKNOWN":          "Clarify caller identity — who they are and which organization they represent",
}


def _latest_category(security: dict) -> str:
    """Return the most recent non-UNKNOWN scam category detected, or 'UNKNOWN'."""
    for cat in reversed(security.get("scam_categories", [])):
        if cat and cat != "UNKNOWN":
            return cat
    return "UNKNOWN"


def _detect_cross_turn_contradictions(ctx: dict, extracted: dict | None) -> list[dict]:
    """
    Compare current turn's extracted fields against what was recorded in prior turns.
    Returns a list of newly detected contradiction dicts (may be empty).
    """
    contradictions = []
    if not extracted:
        return contradictions

    caller = ctx.get("caller", {})
    scenario = ctx.get("scenario", {})

    # Check organization claim drift
    current_org = extracted.get("claimed_authority")
    prior_org = caller.get("claimed_organization")
    if current_org and prior_org and current_org.lower() != prior_org.lower():
        contradictions.append({
            "type": "ORGANIZATION_CONFLICT",
            "prior": prior_org,
            "current": current_org,
            "probe": f"Earlier you said you were from '{prior_org}', now you say '{current_org}' — which is it?",
        })

    # Check entity/name drift
    current_entities = extracted.get("entities_claimed", [])
    prior_identity = caller.get("claimed_identity")
    if current_entities and prior_identity and current_entities[0].lower() != prior_identity.lower():
        contradictions.append({
            "type": "IDENTITY_CONFLICT",
            "prior": prior_identity,
            "current": current_entities[0],
            "probe": f"You mentioned '{prior_identity}' before, but now you're saying '{current_entities[0]}'.",
        })

    # Check demand/action drift
    current_demands = extracted.get("demands", [])
    prior_action = scenario.get("requested_action")
    if current_demands and prior_action and current_demands[0].lower() != prior_action.lower():
        contradictions.append({
            "type": "DEMAND_CONFLICT",
            "prior": prior_action,
            "current": current_demands[0],
            "probe": f"First you asked for '{prior_action}', now you're asking for '{current_demands[0]}'.",
        })

    return contradictions


class QuestionPlanner:
    def plan(
        self,
        context: Dict[str, Any],
        extracted: dict | None = None,
        history_snippet: str = "",
    ) -> Optional[Dict[str, Any]]:
        """
        Produce a plan dict for the LLM prompt. Returns None only when the
        hard turn cap is reached (triggers END_CONVERSATION, not silence).

        Parameters
        ----------
        context        : session.conversation_context
        extracted      : output of ClaimExtractor.extract() for this turn
        history_snippet: last N turns as a formatted string, for contradiction detection
        """
        from core.config import get_settings
        cfg = get_settings()

        agent = context.get("agent", {})
        questions_asked = agent.get("questions_asked", 0)
        max_questions = agent.get("max_questions", cfg.max_agent_turns)

        if questions_asked >= max_questions:
            logger.info("QuestionPlanner: turn cap reached (%d/%d)", questions_asked, max_questions)
            return None  # caller: trigger END_CONVERSATION

        security = context.get("security", {})
        caller = context.get("caller", {})
        scenario = context.get("scenario", {})
        conversation = context.get("conversation", {})

        # ── Cross-turn contradiction detection (richer than old category-only check) ──
        new_contradictions = _detect_cross_turn_contradictions(context, extracted)
        if new_contradictions:
            conversation.setdefault("contradictions", []).extend(new_contradictions)
            latest = new_contradictions[-1]
            return {
                "priority": 1,
                "focus": "Address a detected contradiction in the caller's story",
                "contradiction_type": latest["type"],
                "prior_claim": latest["prior"],
                "current_claim": latest["current"],
                "suggested_probe": latest["probe"],
                "history": history_snippet,
            }

        # ── Category-aware primary slot ────────────────────────────────────────
        category = _latest_category(security)
        if not caller.get("claimed_organization") and not caller.get("claimed_identity"):
            return {
                "priority": 2,
                "focus": _CATEGORY_PRIMARY_SLOT.get(category, _CATEGORY_PRIMARY_SLOT["UNKNOWN"]),
                "scam_category": category,
                "history": history_snippet,
            }

        # ── Reason for call ────────────────────────────────────────────────────
        if not scenario.get("reason_for_call") and not scenario.get("claimed_problem"):
            return {
                "priority": 3,
                "focus": "Ask what the specific problem or reason for this call is",
                "scam_category": category,
                "history": history_snippet,
            }

        # ── Requested action / demand ──────────────────────────────────────────
        if not scenario.get("requested_action"):
            return {
                "priority": 4,
                "focus": "Ask what specifically the caller wants you to do right now",
                "scam_category": category,
                "history": history_snippet,
            }

        # ── Urgency / deadline ─────────────────────────────────────────────────
        if not scenario.get("urgency") or scenario.get("urgency") == "UNKNOWN":
            return {
                "priority": 5,
                "focus": "Ask why this is urgent and what the deadline or consequence is",
                "scam_category": category,
                "history": history_snippet,
            }

        # ── Reference / case number ────────────────────────────────────────────
        if not scenario.get("claimed_reference_number") and not scenario.get("claimed_case_number"):
            return {
                "priority": 6,
                "focus": "Ask for the specific case number, reference number, or document they are using",
                "scam_category": category,
                "history": history_snippet,
            }

        # ── Generic open-ended follow-up (always fires instead of silence) ─────
        return {
            "priority": 8,
            "focus": (
                "Generate a natural COUNTER_QUESTION in-character as a confused elderly person. "
                "The question must be directly about a specific word, number, or name the caller "
                "just mentioned in their last utterance — not a generic probe."
            ),
            "scam_category": category,
            "history": history_snippet,
        }
