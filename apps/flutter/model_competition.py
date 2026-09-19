import json
import time
import urllib.request
import urllib.parse
import sys

# 30 Test Cases (15 Scams, 15 Legitimate)
TEST_CASES = [
    {"transcript": "Hello this is calling from RBI. Your bank account has been linked to illegal transactions. Please transfer your money to our secure account immediately.", "is_scam": True, "category": "RBI_SCAM"},
    {"transcript": "Hello, this is calling from bank. Your UPI account is blocked. Please accept this collect request of 5000 rupees to unblock.", "is_scam": True, "category": "UPI_FRAUD"},
    {"transcript": "This is police officer Sharma from CBI. We have issued a digital arrest warrant against you for money laundering. Pay 1 lakh immediately.", "is_scam": True, "category": "DIGITAL_ARREST"},
    {"transcript": "Hello beta, this is your uncle speaking. I am in the hospital and need urgent money for surgery. Please transfer 50000 rupees.", "is_scam": True, "category": "FAMILY_EMERGENCY"},
    {"transcript": "Mera package deliver nahi hua, custom duty pay karni hai 500 rupees warna parcel seized ho jayega.", "is_scam": True, "category": "COURIER_SCAM"},
    {"transcript": "Aapki LIC policy lapse hone wali hai. Penalty bachane ke liye is link pe click karke 2000 rupees pay karein.", "is_scam": True, "category": "INSURANCE_FRAUD"},
    {"transcript": "Hello I am from child care NGO. We need urgent donation for orphan kids. Please send money.", "is_scam": True, "category": "CHARITY_SCAM"},
    {"transcript": "Sir aapka electricity bill pending hai. Aaj raat 9 baje bijli kategi. Update karne ke liye call karein.", "is_scam": True, "category": "ELECTRICITY_THREAT"},
    {"transcript": "Congratulations! Aapne 25 lakh ki lottery jeeti hai KBC se. Processing fee 10000 rupees jama karayein.", "is_scam": True, "category": "LOTTERY_SCAM"},
    {"transcript": "Aapka KYC incomplete hai. Account freeze ho jayega. Apna aadhar card number aur OTP share karein.", "is_scam": True, "category": "KYC_SCAM"},
    {"transcript": "Join our VIP Whatsapp group for guaranteed 200% returns in trading. Minimum investment 50000.", "is_scam": True, "category": "INVESTMENT_FRAUD"},
    {"transcript": "Maine aapka video record kar liya hai. 50000 nahi bheje toh sabhi whatsapp contacts ko leak kar dunga.", "is_scam": True, "category": "SEXTORTION"},
    {"transcript": "Sir aapke credit card pe 15000 reward points expire ho rahe hain. Redeem karne ke liye OTP batayein.", "is_scam": True, "category": "REWARD_POINTS_SCAM"},
    {"transcript": "Hello, we are from Microsoft Support. Your computer has a virus. Give us remote access to fix it.", "is_scam": True, "category": "TECH_SUPPORT_SCAM"},
    {"transcript": "Mera ek dost hai jiska account block ho gaya hai, maine aapke account me 10000 bheje hain, please usko forward kar do.", "is_scam": True, "category": "MONEY_MULE_SCAM"},
    
    {"transcript": "Hello, this is calling from HDFC Bank customer service. We are calling to inform you about your new credit card benefits. Would you like to know more?", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hi, this is Amazon delivery. I am at your gate with your package.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hello, just a reminder that your health insurance premium is due next month.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hi, I am calling from HelpAge India. Would you be interested in making a regular donation for the elderly?", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Sir, aapka Swiggy order pick up ho gaya hai, 10 minute me pahuch raha hu.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Your Tata Sky recharge was successful. Your new balance is 450 rupees.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hello beta, main uncle bol raha hu. Kal shaam ko ghar aa jana dinner ke liye.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hi, this is your dentist's office calling to confirm your appointment for tomorrow at 10 AM.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Aapka electricity bill 1500 rupees generate hua hai. Due date 25th Jan hai.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Sir aapka internet connection theek ho gaya hai. Abhi speed aa rahi hai na?", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hello, main Jio customer care se bol rahi hu. Aapka current plan expire hone wala hai.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hi, your Uber driver is waiting outside.", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Aapki car ki servicing due hai next week. Appointment book karna chahenge?", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Hello, we noticed a login from a new device on your Gmail account. Was this you?", "is_scam": False, "category": "NORMAL"},
    {"transcript": "Sir, aapke HDFC account me 5000 rupees credit hue hain salary aayi hai.", "is_scam": False, "category": "NORMAL"}
]

SYSTEM_PROMPT = 'You are a scam detector. Reply ONLY with JSON: {"is_scam":true/false,"category":"SCAM|NORMAL","confidence":0.0-1.0,"reasoning":"short reason"}'

def extract_json(text):
    s = text.find('{')
    e = text.rfind('}')
    if s == -1 or e <= s: return None
    return text[s:e+1]

def run_ollama_inference(model_name, prompt):
    url = "http://localhost:11434/api/generate"
    data = {
        "model": model_name,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.1,
            "num_predict": 100,
            "num_ctx": 512
        }
    }
    
    req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
    
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result.get('response', '')
    except Exception as e:
        print(f"Ollama API Error: {e}")
        return ""

def run_benchmark(display_name, ollama_model_name):
    print(f"\n==================================================")
    print(f"🚀 RUNNING {display_name} 🚀")
    print(f"==================================================")
    
    passed = 0
    total_time = 0
    failed_details = []

    for i, tc in enumerate(TEST_CASES):
        transcript = tc['transcript']
        expected_scam = tc['is_scam']
        
        prompt = f"<|im_start|>system\n{SYSTEM_PROMPT}<|im_end|>\n<|im_start|>user\nCall transcript: \"{transcript}\"<|im_end|>\n<|im_start|>assistant\n"
        
        start_time = time.time()
        
        output_text = run_ollama_inference(ollama_model_name, prompt)
        
        end_time = time.time()
        time_taken_ms = (end_time - start_time) * 1000
        total_time += time_taken_ms
        
        json_str = extract_json(output_text)
        
        is_pass = False
        actual_is_scam = False
        
        if json_str:
            try:
                data = json.loads(json_str)
                actual_is_scam = bool(data.get('is_scam', False))
                is_pass = (actual_is_scam == expected_scam)
            except:
                actual_is_scam = ('"is_scam": true' in json_str or '"is_scam":true' in json_str)
                is_pass = (actual_is_scam == expected_scam)
        else:
            actual_is_scam = ('true' in output_text.lower() and 'scam' in output_text.lower())
            is_pass = (actual_is_scam == expected_scam)
        
        if is_pass:
            passed += 1
        else:
            failed_details.append({
                "transcript": transcript,
                "expected": expected_scam,
                "actual": actual_is_scam,
                "output": output_text.strip()
            })
            
        sys.stdout.write(f"\rTest {i+1}/30: {'✅ PASS' if is_pass else '❌ FAIL'} | {time_taken_ms:.0f}ms    ")
        sys.stdout.flush()

    accuracy = (passed / len(TEST_CASES)) * 100
    avg_time = total_time / len(TEST_CASES)
    
    print(f"\n\n🏆 {display_name} RESULTS 🏆")
    print(f"Accuracy: {accuracy:.1f}% ({passed}/{len(TEST_CASES)})")
    print(f"Average Speed: {avg_time:.0f}ms per test")
    print(f"Failed Cases: {len(failed_details)}")
    for f in failed_details:
        exp = "SCAM" if f['expected'] else "NORMAL"
        act = "SCAM" if f['actual'] else "NORMAL"
        print(f" - [Expected: {exp} | Actual: {act}] {f['transcript']}")
        print(f"   Raw Output: {f['output']}")
        
    return {"accuracy": accuracy, "avg_time": avg_time}

if __name__ == "__main__":
    print("Starting Model Competition: 2.1GB TinyLlama vs 100MB SmolLM2 (Powered by Ollama)\n")
    
    # Warm up Ollama for the heavy model to avoid first-inference penalty
    print("Warming up HEAVYWEIGHT model...")
    run_ollama_inference("tinyllama_scam", "hello")
    
    res1 = run_benchmark(
        "HEAVYWEIGHT: TinyLlama (2.1 GB)", 
        "tinyllama_scam"
    )
    
    # Warm up Ollama for the light model
    print("\nWarming up LIGHTWEIGHT model...")
    run_ollama_inference("smollm2_scam", "hello")
    
    res2 = run_benchmark(
        "LIGHTWEIGHT: SmolLM2 (100 MB)", 
        "smollm2_scam"
    )
    
    print("\n==================================================")
    print("🥊 FINAL SHOWDOWN 🥊")
    print("==================================================")
    print(f"TinyLlama (2.1GB) -> Accuracy: {res1['accuracy']:.1f}% | Speed: {res1['avg_time']:.0f}ms")
    print(f"SmolLM2 (100MB)   -> Accuracy: {res2['accuracy']:.1f}% | Speed: {res2['avg_time']:.0f}ms")
    
    winner_acc = "TinyLlama (2.1GB)" if res1['accuracy'] > res2['accuracy'] else "SmolLM2 (100MB)" if res2['accuracy'] > res1['accuracy'] else "TIE"
    winner_spd = "SmolLM2 (100MB)" if res2['avg_time'] < res1['avg_time'] else "TinyLlama (2.1GB)"
    
    print(f"\n🏅 Winner (Accuracy): {winner_acc}")
    print(f"🏅 Winner (Speed): {winner_spd}")
