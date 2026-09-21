import json
import logging
import os
from typing import Any

from groq import AsyncGroq

from factcheck.search import execute_resilient_search

logger = logging.getLogger(__name__)

class FactCheckVerifier:
    def __init__(self):
        self.api_key = os.getenv("GROQ_API_KEY", "")
        self.client = None
        if not self.api_key:
            logger.warning("GROQ_API_KEY not set. FactCheckVerifier will not be able to call Groq API.")
        else:
            try:
                self.client = AsyncGroq(api_key=self.api_key)
            except Exception as e:
                logger.error(f"Error initializing AsyncGroq: {e}")
        self.model = "llama-3.1-8b-instant"

    async def verify_transcript(self, transcript: str) -> dict[str, Any]:
        """
        Orchestrates the entire fact-checking flow:
        1. Extract claim and form search query.
        2. Execute resilient 3-tier search.
        3. Synthesize final verdict using the search context.
        """
        if not self.api_key:
            logger.warning("GROQ_API_KEY is not configured. Using local heuristic mock for L3.")
            tl = transcript.lower()
            # Comprehensive scam keyword patterns for mock L3
            SCAM_PATTERNS = [
                # Authority / Impersonation
                "fbi", "cbi", "cyber cell", "police", "arrest", "warrant", "investigation",
                "drug trafficking", "digital arrest", "press 1", "fir darj",
                # Financial fraud
                "registration fee", "processing fee", "pay fee", "pay fine", "registration charge",
                "loan approved", "loan fee", "transfer fee", "security deposit",
                "lottery", "won", "prize", "claim", "tax to claim", "lucky draw",
                "fixed deposit scheme", "guaranteed return", "crypto scheme", "annual return on investment",
                "200 percent", "double your money", "bonus", "nbfc scheme",
                # Courier / Customs
                "fedex", "customs", "parcel", "bluedart", "dhl", "undeclared",
                # OTP / Account
                "otp", "verify", "block", "suspend", "aadhar", "kyc",
                "share karein", "batao", "send otp", "account band",
                # Remote access
                "anydesk", "teamviewer", "install app", "download app", "remote",
                "secure your phone", "access your device",
                # Family emergency / Extortion
                "hospital mein hoon", "dawai", "2000 rupees bhej", "video viral", "video record", "share kar dunga",
                "emergency bhej", "accident mein", "bail", "jail", "sextortion", "kuch galat",
                # Electricity / Utility
                "electricity disconnected", "power cut", "utility blocked", "bijli connection kaat", "bill update nahi",
                # Investment / Jobs
                "guaranteed interest", "nidhi company", "investment scheme", "work from home job", "data entry",
            ]
            SAFE_PATTERNS = [
                "no rush", "no urgency", "official website", "visit branch",
                "never share otp", "we will never ask", "voluntary",
                "just reminder", "fyi", "for your information",
                "good morning", "how are you", "dinner", "lunch",
                "invoice", "review the pdf", "reschedule", "meeting",
                "fixed deposit maturing", "renewing",
                "delivery partner", "five minutes away", "near your location",
            ]
            scam_score = sum(1 for p in SCAM_PATTERNS if p in tl)
            safe_score = sum(1 for p in SAFE_PATTERNS if p in tl)
            is_scam = scam_score >= 1 and safe_score == 0
            confidence = min(0.99, 0.5 + scam_score * 0.12 - safe_score * 0.15)
            return {
                "is_scam": is_scam,
                "confidence": max(0.0, confidence),
                "risk_level": "HIGH" if scam_score >= 2 else ("MEDIUM" if scam_score == 1 else "LOW"),
                "title": f"Mock L3 Detection (scam_score={scam_score}, safe_score={safe_score})",
                "explanation": f"GROQ_API_KEY missing. Local heuristic mock: {scam_score} scam patterns, {safe_score} safe patterns.",
                "source_used": "mock_api_fallback"
            }

        # Step 1: Claim Extraction
        search_query = await self._extract_claim(transcript)
        if not search_query:
             logger.info("No actionable claim found in transcript.")
             return {"error": "No actionable claim found", "is_scam": False}

        logger.info(f"Extracted search query: {search_query}")

        # Step 2: Search Execution
        search_result = await execute_resilient_search(search_query)
        logger.info(f"Search completed. Tier used: {search_result.get('source_tier')}")

        if not search_result.get("success"):
            logger.warning("Search failed to retrieve context.")
            return {"error": "Failed to retrieve search results"}

        # Step 3: Verdict Synthesis
        verdict = await self._synthesize_verdict(transcript, search_result)
        return verdict

    async def _extract_claim(self, transcript: str) -> str:
        """
        Extract entity/claim and form a targeted search query from the transcript.
        """
        prompt = f"""
Given the following transcript from a phone call, identify any suspicious claims (e.g., demands for money, fake hiring fees, digital arrest threats). 
If a suspicious claim exists, extract the core entities and formulate a concise web search query to verify the claim's authenticity (e.g., official policy of the company).
If no suspicious claim is found, return an empty string.

Transcript:
"{transcript}"

Respond ONLY with the search query text, or empty string. Do not include quotes or conversational text.
"""
        try:
            response = await self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are an expert scam detection AI."},
                    {"role": "user", "content": prompt}
                ],
                model=self.model,
                temperature=0.1,
                max_tokens=50
            )
            query = response.choices[0].message.content.strip()
            return query
        except Exception as e:
            logger.error(f"Error during claim extraction: {e}")
            return ""

    async def _synthesize_verdict(self, transcript: str, search_result: dict) -> dict[str, Any]:
        """
        Synthesize the final verdict using Llama-3.3 based on transcript and search context.
        """
        context = search_result.get("context", "")
        source_tier = search_result.get("source_tier", "Unknown")
        
        prompt = f"""
You are an expert scam detection AI. Analyze the phone call transcript and the provided web search context to determine if the call is a scam.

Transcript:
"{transcript}"

Web Search Context (Source: {source_tier}):
"{context}"

Return a JSON object strictly adhering to this format:
{{
  "is_scam": true/false,
  "confidence": 0.0 to 1.0,
  "risk_level": "CRITICAL" | "HIGH" | "MEDIUM" | "LOW",
  "title": "Short title describing the detection",
  "explanation": "Brief explanation of why it is or is not a scam, referencing the policy/context",
  "source_used": "{source_tier}"
}}

Respond ONLY with valid JSON.
"""
        try:
            response = await self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are a precise JSON-producing AI. Produce only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                model=self.model,
                temperature=0.1,
                response_format={"type": "json_object"}
            )
            
            content = response.choices[0].message.content.strip()
            verdict_json = json.loads(content)
            
            # Ensure the source used accurately reflects the search tier
            verdict_json["source_used"] = source_tier
            
            return verdict_json
        except Exception as e:
            logger.error(f"Error during verdict synthesis: {e}")
            return {"error": "Failed to synthesize verdict"}

