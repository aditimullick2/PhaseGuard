"""
Web API endpoint for scam detection fallback
This is used when local model fails or is uncertain
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from verifier import FactCheckVerifier
import asyncio

app = FastAPI()

class ScamRequest(BaseModel):
    transcript: str

verifier = FactCheckVerifier()

@app.on_event("startup")
async def startup():
    print("Loading FactCheckVerifier (LLM-based web fallback)...")
    print("Classifier loaded successfully!")

@app.post("/predict")
async def predict(request: ScamRequest):
    try:
        # Deep fact-check via the verification pipeline
        result = await verifier.verify_transcript(request.transcript)
        
        # If the result has an error, default to uncertain
        if "error" in result and "is_scam" not in result:
             return {
                 "is_scam": False,
                 "category": "UNKNOWN",
                 "reasoning": result["error"],
                 "confidence": 0.0
             }
             
        return {
            "is_scam": result.get("is_scam", False),
            "category": result.get("title", "UNKNOWN"),
            "reasoning": result.get("explanation", ""),
            "confidence": result.get("confidence", 0.5)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "healthy", "verifier_loaded": True}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
