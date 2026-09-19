import asyncio
import httpx
import json
import time
import sys
import os

# Ensure apps/api is in python path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from factcheck.local_llm import LocalScamClassifier

# Load Test Cases
def load_test_cases():
    return [
        {"text": "Hello this is Amazon customer service your account is suspended due to illegal activity", "expected": True},
        {"text": "Sir this is Delhi Police cyber cell, you have a digital arrest warrant for money laundering. Pay penalty immediately.", "expected": True},
        {"text": "Hi, I am stuck in traffic. Let's reschedule our meeting.", "expected": False},
        {"text": "Your OTP is 492011. Do not share this with anyone. If you didn't request this, contact support.", "expected": False},
        {"text": "Maa meri tabiyat theek nahi hai, dawai laani hai, is number par 2000 rupees bhej do please.", "expected": True},
        {"text": "This is FBI. You are under investigation for drug trafficking. Press 1 to speak to an agent.", "expected": True},
        {"text": "Bhai maine tera invoice bheja hai email pe. Ek baar verify kar lena.", "expected": False},
        {"text": "Your loan of Rs 5,00,000 is approved. Pay Rs 5000 registration fee to get the amount.", "expected": True},
        {"text": "Maine apne friend ko 5000 rupees bheje via UPI for rent.", "expected": False},
        {"text": "We noticed suspicious activity. Download AnyDesk app so we can secure your phone.", "expected": True},
        {"text": "Can you download the PDF document I sent you and review the changes?", "expected": False},
        {"text": "Electricity board warning: Your power will be cut tonight at 9 PM. Call this number immediately.", "expected": True},
        {"text": "You won the Kaun Banega Crorepati lottery of 25 Lakhs! Pay tax to claim.", "expected": True},
        {"text": "I got an email saying I won a lottery but I know it's a scam so I ignored it.", "expected": False},
        {"text": "Hello beta, this is uncle Sharma, my son is in hospital, I lost my wallet, transfer money.", "expected": True},
        {"text": "Aapka aadhar card block hone wala hai. KYC update karne ke liye 1 dabayein.", "expected": True},
        {"text": "Please provide your Aadhar card for the office joining formalities.", "expected": False},
        {"text": "Dear customer, your credit card reward points are expiring. Click link to redeem.", "expected": True},
        {"text": "Hello, I am calling from ICICI bank to remind you about your upcoming credit card payment.", "expected": False},
        {"text": "Sir I am an internal auditor calling regarding a discrepancy in your recent expense report.", "expected": True},
        {"text": "Your fixed deposit is maturing today. Are we renewing it?", "expected": False},
        {"text": "We are transferring your call to the cyber crime authority regarding the FIR against your number.", "expected": True},
        {"text": "If you invest in this crypto scheme you will get 200 percent return in 10 days.", "expected": True}
    ]

async def run_e2e_tests():
    print("[START] Starting Hybrid E2E Test Suite...")
    print("L1: Keyword Rules Engine (Local)")
    print("L2: TFLite Offline Model (Local)")
    print("L3: FastAPI Web Backend Fallback (Remote)")
    
    test_cases = load_test_cases()
    clf = LocalScamClassifier()
    clf.load_model()
    
    correct = 0
    l3_hits = 0
    start_time = time.time()
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        for idx, case in enumerate(test_cases):
            text = case["text"]
            expected = case["expected"]
            
            # Layer 1 & 2 (Local App Simulation)
            local_res = await clf.predict_instant_scam(text)
            
            # Map confidence based on local_res since not all returns have 'confidence' key
            if "confidence" in local_res:
                l2_conf = local_res["confidence"]
            else:
                l2_conf = 1.0 if local_res.get("is_scam", False) else 0.0
                if not local_res.get("is_confident", True):
                    l2_conf = 0.5 # Force uncertain
            
            # Hybrid routing logic as defined in HybridScamDetector.dart
            if l2_conf > 0.70:
                prediction = True
                layer = "L1/L2-Local"
            elif l2_conf < 0.30:
                prediction = False
                layer = "L1/L2-Local"
            else:
                # Layer 3 (Web API Fallback)
                try:
                    res = await client.post("http://localhost:8000/api/scam/analyze", json={"text": text})
                    res.raise_for_status()
                    data = res.json()
                    prediction = data.get("is_scam", False)
                    layer = "L3-Web-API"
                    l3_hits += 1
                except Exception as e:
                    print(f"L3 Request failed: {e}")
                    prediction = l2_conf >= 0.5
                    layer = "L2-Fallback"

            is_correct = (prediction == expected)
            if is_correct:
                correct += 1
                
            icon = "[PASS]" if is_correct else "[FAIL]"
            print(f"{icon} [{layer}] Expected: {expected} | Pred: {prediction} | Text: {text[:60]}...")
            
    end_time = time.time()
    accuracy = (correct / len(test_cases)) * 100
    print("\n--- E2E Hybrid Test Results ---")
    print(f"Total Cases: {len(test_cases)}")
    print(f"Correct: {correct}")
    print(f"Accuracy: {accuracy:.1f}%")
    print(f"L3 Fallback Hits (Uncertain locally): {l3_hits}")
    print(f"Execution Time: {end_time - start_time:.2f}s")
    
    if accuracy >= 95:
        print("[SUCCESS] Entire Hybrid System is functioning optimally!")
    else:
        print("[WARNING] E2E Accuracy below threshold.")
        print("          Note: Since GROQ_API_KEY is missing, L3 Web API is using a basic mock, which lowers accuracy.")

if __name__ == "__main__":
    asyncio.run(run_e2e_tests())
