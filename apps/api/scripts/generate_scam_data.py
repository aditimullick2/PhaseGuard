import os
import json
import random

# Get the absolute path of the directory containing the script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Navigate up to api directory and then into ai_training
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "..", "ai_training", "dataset.jsonl")

# Massive dataset of Indian Scams
SCAMS = [
    # 1. TELECOM / TRAI DISCONNECTION
    ("This is a call from the Telecom Regulatory Authority of India. All your mobile numbers will be disconnected in 2 hours due to illegal activity. Press 9 to speak with our executive.", "KYC_SIM_BLOCK"),
    ("Aapka Airtel number block kiya ja raha hai TRAI ki taraf se, kyunki aapke naam par 9 illegal SIM card issue hue hain. Verify karne ke liye Aadhaar number batayein.", "KYC_SIM_BLOCK"),
    ("Hello, customer care se bol raha hoon. Aapka Jio number band hone wala hai. 10 minute mein KYC update nahi kiya toh network chala jayega. OTP share karein.", "KYC_SIM_BLOCK"),

    # 2. DIGITAL ARREST / FEDEX / CUSTOMS
    ("Hello sir, I am calling from Mumbai Customs. Your FedEx parcel containing 5 expired passports and MDMA has been intercepted. You are under digital arrest.", "DIGITAL_ARREST"),
    ("Main CBI officer bol raha hoon. Aapke khilaf money laundering ka warrant hai. Skype on karo, jab tak statement record nahi hota digital arrest mein rahoge.", "DIGITAL_ARREST"),
    ("Police department se call hai. Aapke account se hawala transaction hua hai. Aapko Supreme Court clearance certificate ke liye 50,000 RBI safe account me transfer karne honge.", "DIGITAL_ARREST"),
    ("This is FedEx customer support. Your package to Taiwan was seized. Please pay the customs clearance fee of 85,000 rupees immediately or police will be dispatched.", "COURIER_CUSTOMS"),

    # 3. TASK SCAMS (YOUTUBE / TELEGRAM)
    ("Welcome! We are hiring for part-time work from home. You just need to like YouTube videos and subscribe to channels. Earn 5000 rupees daily. Pay 1000 rupees security deposit to start.", "FAKE_JOB_TASK"),
    ("Telegram task group mein aapka swagat hai. Pre-paid task complete karne ke liye 10,000 rupees invest karein, aapko 30% profit ke sath 13,000 wapas milenge.", "FAKE_JOB_TASK"),
    ("Sir aapka resume Naukri.com par shortlist hua hai. Direct interview schedule karne ke liye 2500 processing fee pay kijiye.", "HR_RECRUITER_SCAM"),

    # 4. INVESTMENT / STOCK MARKET / CRYPTO
    ("Ye ek exclusive stock market insider tip hai. Hamare VIP WhatsApp group ko join karo. Hum 200% guaranteed return dete hain 1 hafte mein.", "INVESTMENT_FRAUD"),
    ("Sir, main SEBI registered advisor hoon. Aaj ye penny stock double hone wala hai. Apne demat account ka id password do, main trade laga dunga.", "INVESTMENT_FRAUD"),
    ("Join our crypto cloud mining platform. Just transfer 500 USDT to this wallet address and earn daily passive income of 50 dollars. No risk.", "CRYPTO_SCAM"),

    # 5. BANKING / KYC / CREDIT CARD
    ("Dear customer, your SBI YONO account will be blocked today because your PAN card is not updated. Click the link in SMS to update KYC now.", "KYC_SIM_BLOCK"),
    ("HDFC bank se baat kar raha hoon. Aapke credit card par 50,000 reward points expire ho rahe hain. Redeem karne ke liye OTP batayein.", "CREDIT_CARD_UPGRADE"),
    ("Sir aapka credit card ka limit 5 lakh hone wala hai free mein. Verification ke liye card ke peeche likha CVV number aur expiry date bataiye.", "CREDIT_CARD_UPGRADE"),

    # 6. UPI / QR CODE / OLX FRAUD
    ("Sir, main OLX se sofa khareedne ke liye ready hoon. Maine aapko ek QR code bheja hai WhatsApp par. Usko GPay se scan karke apna UPI PIN daaliye, paisa aapke account me aa jayega.", "UPI_COLLECT_FRAUD"),
    ("Aapko PhonePe par 1999 rupees ka cashback mila hai. Claim karne ke liye 'Pay' button dabayein aur apna UPI PIN enter karein.", "UPI_COLLECT_FRAUD"),
    ("Sir main army officer bol raha hoon. Mujhe aapka saman kharidna hai. Hum defense account se pay karte hain toh aapko pehle 5 rupees bhej kar verify karna hoga.", "UPI_COLLECT_FRAUD"),

    # 7. ELECTRICITY BILL THREAT
    ("Dear consumer, your MSEB electricity power will be disconnected at 9:30 PM tonight because your previous month bill was not updated. Call this number immediately.", "ELECTRICITY_THREAT"),
    ("Main bijli vibhag se bol raha hoon. Aapka bill update nahi hua hai. Light abhi kat jayegi. Turant is link par 10 rupaye ka payment karein update ke liye.", "ELECTRICITY_THREAT"),

    # 8. EPFO / INCOME TAX REFUND
    ("Aapka PF withdrawal claim fas gaya hai. Processing charge 2000 rupees pay karein tabhi paisa account me aayega.", "EPF_WITHDRAWAL_SCAM"),
    ("Income tax department se call hai. Aapka 25,000 ka ITR refund pending hai. Bank account details verify karne ke liye OTP dijiye.", "INCOME_TAX_REFUND"),

    # 9. LOTTERY / KBC
    ("Namaskar, main KBC Mumbai se bol raha hoon. Aapke WhatsApp number par 25 lakh ka lottery laga hai. File charge 12,500 jama karein prize lene ke liye.", "PRIZE_LOTTERY"),
    ("Congratulations! You have been selected as the lucky winner of a Mahindra Thar in our lucky draw. Pay 5000 rupees registration fee to claim your car.", "PRIZE_LOTTERY"),

    # 10. FAMILY EMERGENCY / AI VOICE CLONE
    ("Beta, I am your uncle's friend. He had a severe accident and is in the ICU. Please transfer 50,000 to this hospital account urgently. Don't tell your parents, there is no time.", "FAMILY_EMERGENCY"),
    ("Papa, police ne mujhe pakad liya hai ek accident case mein. Constable paise maang raha hai varna FIR likh dega. Please 20,000 is number par GPay kar do. Kisi ko mat batana.", "FAMILY_EMERGENCY"),

    # 11. SEXTORTION / BLACKMAIL
    ("Maine tumhara ek personal video record kar liya hai WhatsApp video call par. Agar tumne mujhe 50,000 nahi bheje toh main ye video tumhare saare Facebook friends aur relatives ko bhej dunga.", "SEXTORTION"),
    ("You have 10 minutes to pay me, or I will upload your compromising pictures to YouTube and tag your workplace.", "SEXTORTION"),

    # 12. INSTANT LOAN APP HARASSMENT
    ("Tumne loan app se paise liye the, aaj due date hai. Agar abhi penalty ke sath pay nahi kiya toh tumhari photos morph karke tumhare saare contacts ko bhej dunga. Maine tumhari contact list access kar li hai.", "LOAN_APP_HOOK"),
    ("Loan ka paisa kab dega? Tera Aadhaar aur PAN card mere paas hai, usko block kar dunga aur tere relatives ko call karke bataunga ki tu defaulter hai.", "LOAN_HARASSMENT"),

    # 13. PM YOJANA / GOVT SCHEME
    ("Pradhan Mantri Yojana ke tehat aapko 1 lakh ka loan bina interest ke mil raha hai. Bas file charge 1500 rupees jama karwayein.", "GOVT_SCHEME_IMPERSONATION"),
    ("Aapko kisan samman nidhi ka paisa nahi mila hai? Apna Aadhaar number aur bank ka OTP bataiye hum abhi chalu karwa dete hain.", "GOVT_SCHEME_IMPERSONATION"),

    # 14. CUSTOMER CARE / REFUND SCAM
    ("Sir, main Swiggy customer care se hoon. Aapka refund process karne ke liye ek link bheja hai, usme apna UPI PIN daaliye refund receive karne ke liye.", "ECOMMERCE_REFUND_SCAM"),
    ("IRCTC refund department. Aapki cancelled train ka paisa atka hua hai. Apna card detail aur CVV bataiye hum manual refund initiate kar rahe hain.", "RAILWAY_IRCTC_REFUND"),
    ("IndiGo airlines support. Aapki flight cancel hui hai. Refund form bhariye aur validation ke liye OTP share kijiye.", "FAKE_CUSTOMER_CARE"),

    # 15. TECH SUPPORT / REMOTE ACCESS
    ("Hi, this is Microsoft Windows support. We detected a Trojan virus on your computer. Please install AnyDesk immediately so our engineer can fix it before your hard drive crashes.", "TECH_SUPPORT"),
    ("Sir, aapka bank account hack ho gaya hai. Mujhe apne phone mein TeamViewer QuickSupport install karke 9-digit code bataiye, main theek kar doonga.", "TECH_SUPPORT"),
    
    # 16. MATRIMONY SCAMS
    ("Hi dear, I am a doctor based in London. I have sent a very expensive gift for you and gold jewelry. But customs in Delhi has stopped it. You need to pay them 35,000 rupees duty tax to receive the parcel.", "MATRIMONIAL_FRAUD")
]

# Normal regular conversational patterns
NORMALS = [
    "Hi Rahul, are we still on for the meeting tomorrow at 10 AM? Let me know if you want to reschedule.",
    "Hey mom, I am running late today because of traffic. Please keep my dinner in the fridge, I'll eat when I get back.",
    "Swiggy delivery partner speaking. I have reached your location, can you please open the gate?",
    "Sir, you have an appointment with Dr. Sharma tomorrow at 5 PM. Please confirm if you will be coming.",
    "I'll send you the report by EOD. Can you review it tomorrow morning and give me your feedback?",
    "Haan bhai, kya haal hai? Aaj sham ko football match dekhne chalega kya?",
    "Your Uber driver is arriving in 2 minutes. The car number is DL 1C 1234. I am waiting near the pharmacy.",
    "Please find attached the invoice for the last quarter. Let me know if you have any questions about the billing.",
    "Let's schedule a catch-up next week. When are you free? My calendar is open on Thursday.",
    "I need a favor. Can you pick up some groceries on your way back home? We are out of milk and bread.",
    "Bhai wo presentation ka deck bhejna, kal boss ke samne review hai. Kuch changes the usme.",
    "Happy birthday! God bless you. Party kab de raha hai bhai?",
    "Hello sir, I am calling from the bank. Your credit card statement has been sent to your registered email address.",
    "Sir aapne jo complaint raise ki thi internet issue ke liye, wo resolve ho gayi hai. Kya aap confirm kar sakte hain?",
    "Mam aapka order dispatch ho gaya hai, kal tak deliver ho jayega. Koi issue ho toh toll-free number par call kar lijiyega."
]

def generate_dataset():
    data = []
    
    # Generate a massive number of variations
    # We will loop 25 times over the SCAMS list to generate 1000+ scam examples
    for _ in range(25):
        for scam_text, category in SCAMS:
            # Add realistic conversational noise to make the model robust to STT transcripts
            noise_prefix = random.choice(["", "Hello?", "Can you hear me?", "Am I audible?", "Haan suniye.", "Sir, ", "Madam, ", "Ahem, "])
            noise_suffix = random.choice(["", " Do you understand?", " Is that clear?", " Boliye?", " Hello?"])
            
            # Simulate STT misspellings occasionally
            modified_text = scam_text
            if random.random() > 0.8:
                modified_text = modified_text.replace("UPI", "U P I").replace("OTP", "O T P")
            
            final_scam = f"{noise_prefix} {modified_text} {noise_suffix}".strip()
            
            output = {
                "category": category,
                "is_scam": True,
                "reasoning": f"Matches patterns and demands typical of {category}."
            }
            
            data.append({
                "instruction": "Analyze the following phone call transcript and extract scam claims. Output JSON with 'category', 'is_scam' and 'reasoning'.",
                "input": final_scam,
                "output": json.dumps(output)
            })

    # Add Normal calls
    # Loop 30 times over NORMALS to balance the dataset
    for _ in range(30):
        for normal_text in NORMALS:
            noise_prefix = random.choice(["", "Hi.", "Hello.", "Accha suno, "])
            final_normal = f"{noise_prefix} {normal_text}".strip()
            
            output = {
                "category": "UNKNOWN",
                "is_scam": False,
                "reasoning": "Normal conversation. No coercion, unusual demands, or threats detected."
            }
            
            data.append({
                "instruction": "Analyze the following phone call transcript and extract scam claims. Output JSON with 'category', 'is_scam' and 'reasoning'.",
                "input": final_normal,
                "output": json.dumps(output)
            })
            
    random.shuffle(data)
    
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        for item in data:
            f.write(json.dumps(item) + '\n')
            
    print(f"MASSIVE DATASET GENERATED: {len(data)} examples written to {OUTPUT_FILE}")
    print(f"Total Scams: {sum(1 for d in data if json.loads(d['output'])['is_scam'])}")
    print(f"Total Normal: {sum(1 for d in data if not json.loads(d['output'])['is_scam'])}")

if __name__ == "__main__":
    generate_dataset()
