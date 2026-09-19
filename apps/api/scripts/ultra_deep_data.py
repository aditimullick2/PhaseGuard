# -*- coding: utf-8 -*-
"""
ULTRA DEEP DATASET - Edge cases, regional languages, partial transcripts,
interrupted calls, noise-heavy STT outputs, new 2024-2025 scam patterns
"""
import json, os

INSTRUCTION = "Analyze the following phone call transcript and extract scam claims. Output JSON with 'category', 'is_scam' and 'reasoning'."
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(SCRIPT_DIR, "..", "ai_training", "dataset.jsonl")

data = []
def add(cat, scam, text, reason):
    data.append((cat, scam, text, reason))

# ─── EDGE CASE: Partial/interrupted STT transcripts (model must still catch it) ───
add("DIGITAL_ARREST", True, "Sir main CBI se... hello aap sun rahe hain? Haan toh aapka parcel customs mein... drugs mila hai... aapko digital... hello? Haan haan main hoon, aapko arrest...", "Fragmented STT output of a digital arrest call; model must detect intent from partial phrases.")
add("UPI_COLLECT_FRAUD", True, "...to bas ye jo request aayi hai GPay pe usko... haan accept karo aur pin... paisa aa jayega turant... hello?", "Incomplete UPI collect fraud transcript; 'accept karo aur pin' is a strong scam signal even without full context.")
add("KYC_SIM_BLOCK", True, "Aapka number band... TRAI ne... OTP jo aaya hai... share karo... 2 minute mein... warna...", "Heavily truncated KYC/SIM disconnection threat; key phrases 'OTP share karo' and 'warna' indicate scam.")
add("FAMILY_EMERGENCY", True, "Papa... accident... hospital... paisa... 40,000... please... abhi... kisi ko mat...", "Minimal-word distress call; combination of 'accident + hospital + paisa + kisi ko mat batana' is family emergency scam signature.")
add("SEXTORTION", True, "Tumhara video... maine record... 20,000... nahi diya toh... contacts ko... bhej dunga...", "Fragmented sextortion threat; key nouns 'video + record + contacts + bhej dunga' are unambiguous scam markers.")

# ─── EDGE CASE: Scammer tries to SOUND LEGITIMATE with formal language ───
add("DIGITAL_ARREST", True, "Good afternoon sir. I am calling on behalf of the Special Task Force of the Central Bureau of Investigation, Mumbai division. Case reference number is CBI/SCT/2024/00847. Your Aadhaar number ending in 4521 is linked to a suspicious transaction of 84 lakh rupees flagged by Financial Intelligence Unit. This is a courtesy call before we proceed with the legal notices. Please do not share this call information with anyone as it may hamper the investigation.", "Highly formal language with fake case number and FIU reference — scammers use official-sounding details to bypass skepticism.")
add("INVESTMENT_FRAUD", True, "Good morning, this is Arvind Sharma calling from Motilal Oswal Wealth Management, our registered AMFI number is ARN-47821. We have identified a structured product with capital protection and 24% annualized returns, available exclusively to HNI clients with a minimum ticket size of 5 lakh. The subscription window closes tomorrow.", "Uses real-sounding AMFI registration number, established broker name, and HNI framing to appear credible — a sophisticated investment fraud.")
add("VISHING_BANK_OTP", True, "Sir this is the Reserve Bank of India Financial Inclusion helpdesk. We are implementing a new 2-factor security protocol on all accounts above 1 lakh balance as per RBI circular 2024-115. To activate the new security layer, please confirm the OTP sent to your registered number. This is mandatory.", "Cites a fabricated RBI circular with a number to sound regulatory — a sophisticated bank OTP vishing attempt.")

# ─── EDGE CASE: Scammer is AGGRESSIVE / abusive ───
add("LOAN_HARASSMENT", True, "Teri maa ki kasam agar aaj paisa nahi aaya toh teri colony mein 10 log bhejunga, teri biwi aur bache sab ke saamne tamasha karunga. Tu samjha nahi kya hum log hain.", "Aggressive abusive language with family threat — extreme end of loan app recovery harassment.")
add("DIGITAL_ARREST", True, "Aap bahut bada mistake kar rahe ho call kaatke! Abhi 5 minute mein hamare officers aapke ghar ke bahar honge! Last chance de raha hoon, abhi UPI karo warna handcuffs mein jayenge!", "Escalated aggression after a disconnect attempt — scammer uses urgency and physical arrest threat to re-engage victim.")
add("SEXTORTION", True, "Saale 1 ghante se message nahi kiya, abhi tere saare relatives ko video bhej deta hoon, dekh le apni izzat ki liye kya karta hai tu. 5000 abhi bhej warna khatam.", "Abusive tone sextortion using time pressure and relationship damage threat to force immediate payment.")

# ─── EDGE CASE: Scammer plays VICTIM to build trust ───
add("UPI_COLLECT_FRAUD", True, "Bhai bahut bura hua mujhe, galti se aapke account mein mera paisa chala gaya, main ek garib maa baap ka beta hoon, please meri madad karo, 5000 wapas kar do UPI pe, mujhe bahut zaroorat hai.", "Scammer plays a sympathetic victim of a 'wrong transfer' — emotional manipulation to trigger a money return that was never received.")
add("FAMILY_EMERGENCY", True, "Didi main bahut rota hoon aajkal, bhai ko bahut buri bimari hai, doctor ne bola operation karna padega, humari condition bahut kharab hai, please 15000 udhaar do, main zaroor lautunga.", "Uses emotional distress framing of a sick family member to solicit a 'loan' rather than a direct scam demand — harder to detect.")

# ─── EDGE CASE: Scammer builds TRUST over multiple 'calls' (voice pattern) ───
add("INVESTMENT_FRAUD", True, "Sir ye main hoon Anuj, wahi jo 2 hafte pehle stock tips diya tha, aapko yaad hai na 500 rupaye ka profit hua tha? Ab ek bada opportunity aaya hai, 50,000 lagao, 1.5 lakh 10 din mein milenge.", "References a previous small win to build credibility before requesting a large investment — pig butchering scam pattern.")
add("MATRIMONIAL_FRAUD", True, "Hi my love, it's been 3 months we are talking, I have never felt this way before. I am coming to India next month to meet your family. But today I had a small problem at the bank, my account got frozen, can you lend me 8000 for a week?", "Long-term emotional grooming culminating in a financial request framed as a temporary loan — romance/matrimonial fraud peak extraction phase.")

# ─── 2024-2025 NEW SCAM PATTERNS ───
add("DIGITAL_ARREST", True, "Sir aap WhatsApp pe hain? Main aapko ek government portal ka link bhejta hoon, usme apna Aadhaar aur photo upload karke digital custody affidavit sign karna hoga, ye mandatory legal step hai.", "New variant: digital arrest now involves fake government portal links for 'affidavit signing' — collecting biometrics online.")
add("FAKE_JOB_TASK", True, "Welcome to the AI training task platform. You will be rating AI chatbot responses. Each task pays 200 rupees. To activate your account, pay a one-time platform fee of 1500 rupees via the link below.", "2024 pattern: AI chatbot rating task scam — uses the AI hype to lure victims into a fake platform with activation fees.")
add("INVESTMENT_FRAUD", True, "Bhai ye AI trading bot hai, ChatGPT se zyada powerful hai, automatically trade karta hai Nifty50 mein, 8% weekly return guaranteed, bas 20,000 ka API key subscription lena hoga.", "2024 AI trading bot investment scam exploiting LLM/ChatGPT hype to sell fake trading subscriptions.")
add("CRYPTO_SCAM", True, "Sir aapka aadhar-linked UPI ab CBDC digital rupee se link ho sakta hai, early adopters ko 2x value milega, pehle 5000 ka CBDC wallet activate karo is link se, RBI approved hai.", "2024 pattern: CBDC (Digital Rupee) scam exploiting lack of public awareness about India's CBDC rollout.")
add("KYC_SIM_BLOCK", True, "Your DigiLocker account shows incomplete verification. As per new MeitY guidelines, all citizens must complete biometric re-verification by this Friday. Click the link and allow camera access to complete the process.", "2024 MeitY/DigiLocker impersonation scam capturing facial biometrics via a fake re-verification link.")
add("TECH_SUPPORT", True, "Sir aapke phone ka IMEI number blacklist ho gaya hai DOT ke naye database mein, aapko 2 ghante mein factory reset karna padega ya aapka number permanently deactivate ho jayega, hum remote se reset karwa sakte hain.", "New DOT IMEI blacklist scam — forces factory reset urgency to install a backdoor app during 'remote assistance'.")
add("SOCIAL_MEDIA_IMPERSONATION", True, "Hi, I am from Meta Verified team, your account has been flagged for impersonation by another user, to protect your account please share the 6-digit login code we just sent to your email immediately.", "Meta Verified impersonation scam stealing Instagram/Facebook 2FA code to take over the victim's account.")
add("FAKE_JOB_TASK", True, "Bhai Google Maps review karne ka kaam hai, 30 reviews daily, 150 rupaye per review, 4500 roz kamao, lekin pehle 2000 ka wallet load karna hoga activate karne ke liye, aaj hi join karo.", "2024 Google Maps fake review task scam with unrealistic per-review pay and upfront wallet loading.")
add("VISHING_BANK_OTP", True, "Sir aapka UPI Lite auto-top-up feature enable karne ke liye ek OTP aa raha hai phone pe, wo share karein, feature ek baar on ho jayegi phir automatically top up hota rahega.", "UPI Lite feature impersonation scam — OTP shared actually authorizes a money transfer, not a feature activation.")
add("INVESTMENT_FRAUD", True, "Bhai sovereign gold bond ka ek backdated allotment available hua hai, sirf 50 slots hain, 2021 ka price par milega, 40% discount hai aaj ke rate pe, 1 lakh invest karo aaj hi bank NEFT karke.", "Fake backdated Sovereign Gold Bond allotment with a steep discount — exploits SGB awareness for investment fraud.")

# ─── REGIONAL / DIALECT VARIATIONS ───
add("DIGITAL_ARREST", True, "Bhai saab, main Mumbai police ka SI hoon, tumhara naam ek fraud case mein aa gaya hai, seedha mujhse baat karo, kisi ko batana mat, ek lakh deposit karo court ke naam pe online.", "Mumbai street-dialect digital arrest with SI impersonation and court deposit demand.")
add("UPI_COLLECT_FRAUD", True, "Anna, naan Google Pay-la oru collect request anuppinein, adhai accept panni PIN podu, paisa unoda account-la varum.", "Tamil-language OLX/marketplace UPI collect fraud — 'accept panni PIN podu' means 'accept and enter PIN'.")
add("KYC_SIM_BLOCK", True, "Namskar, main Airtel Bangalore se bolthiddeni, nimma SIM cancel aagatte, KYC update maadabekagide, Aadhaar number heli nimma OTP share maadi.", "Kannada-accented Airtel KYC scam demanding Aadhaar and OTP to cancel a SIM disconnection.")
add("FAMILY_EMERGENCY", True, "Amma, nenu Ravi ni, accident ayindi, hospital lo unnanu, turant 30,000 ante, ikkade andariki cheppakandi please.", "Telugu-language family emergency scam impersonating a son in a hospital needing immediate money.")
add("PRIZE_LOTTERY", True, "Namskar ji, assi Punjab da number lottery vich choose hoye aa, 10 lakh jeete ho, claim karne layi 3000 rupaye processing fee deo, aaj hi.", "Punjabi-language KBC-style lottery scam with processing fee demand.")
add("ELECTRICITY_THREAT", True, "Dada, aapnar bijli bill update hoy ni, aaj raat 9 tar por connection katiye nebo, ekhuni 1200 taka is number e pathiye din.", "Bengali-dialect electricity disconnection threat with immediate payment demand to a personal number.")
add("DIGITAL_ARREST", True, "Saab ji, main Delhi police da ASI hoon, aapde khilaf IPC 420 da warrant issue hoya hai, abhi bail amount 50,000 is UPI te transfer karo.", "Punjabi/Haryanvi-dialect fake Delhi police ASI demanding bail via UPI.")

# ─── MIXED LANGUAGE / CODE SWITCHING (very realistic for India) ───
add("DIGITAL_ARREST", True, "Hello sir, I am calling from CBI, aapka naam ek serious case mein involve hai, it's a non-bailable offence, aapko digital custody mein liya ja raha hai, please don't disconnect, it's very important for your safety.", "Hinglish code-switching digital arrest — mixing Hindi and English mid-sentence as real scammers do.")
add("INVESTMENT_FRAUD", True, "Bhai yaar suno, I have found a really solid opportunity, ek crypto project hai, team very strong hai, white paper dekh lena, 10x guaranteed hai in 3 months, 50,000 invest karo aaj hi.", "Casual Hinglish investment pitch mixing technical crypto jargon ('white paper') with colloquial language.")
add("TECH_SUPPORT", True, "Sir your system mein ek virus detect hua hai jo aapke net banking ke credentials capture kar raha hai, abhi AnyDesk install karo, hum 10 minutes mein clean kar denge bilkul free mein.", "Smooth Hinglish tech support scam — professional tone in English mixed with reassuring Hindi.")

# ─── VERY SUBTLE / HARD TO DETECT SCAMS ───
add("INVESTMENT_FRAUD", True, "Hi sir, I am not selling anything, just wanted to share some information about how we are helping retail investors beat inflation. No commitment needed. Just a 10-minute call tomorrow?", "Subtle investment scam opener — denies selling, uses 'helping' language, sets up a follow-up call to avoid raising immediate alarms.")
add("FAKE_JOB_TASK", True, "Hello, we found your resume on Internshala, we have a paid internship in content writing, 8000 per month, 2 hours daily work from home, just fill this Google Form with your details and we will reach out.", "Subtle internship scam collecting PII via Google Form with no upfront fee — harvesting data for later fraud or phishing.")
add("MATRIMONIAL_FRAUD", True, "Hi, I saw your profile on the matrimony site, I liked it very much. I am not looking for anything serious immediately, just friendship first. Can we talk more?", "Very early stage romance scam opener — no scam signal yet but initiating trust-building for future extraction; model should flag as low-risk but monitor.")
add("SOCIAL_MEDIA_IMPERSONATION", True, "Hey, I wanted to reach you directly, I am a talent scout for a modeling agency, I saw your Instagram photos and I think you have great potential, we have a paid campaign next month, interested?", "Subtle social media talent scout scam — flattery-based approach to eventually charge a 'registration fee' or collect photos.")

# ─── NORMAL CALLS — Hard negatives (could look like scam but isn't) ───
add("UNKNOWN", False, "Hello sir, main aapke SBI account se bol raha hoon, aapka account statement ready hai, aap net banking pe login karke download kar sakte hain.", "Legitimate bank account statement notification with no credential request — directs to official channel.")
add("UNKNOWN", False, "Hi, this is the RTO office, your driving license renewal documents have been verified, please collect your new DL from our office within 30 days with your original ID proof.", "Legitimate RTO document collection notification — no fee or OTP involved.")
add("UNKNOWN", False, "Bhai, ek kaam tha, mujhe 2000 rupaye chahiye kal tak, salary aa gayi toh wapas kar dunga, meri car ka puncture hua hai highway pe.", "Friend asking for a small loan in an emergency — lacks scam indicators like urgency pressure, unknown number, or large sum.")
add("UNKNOWN", False, "Sir main aapke building ki lift company se bol raha hoon, AMC contract renew karna hai, please building secretary ko bol dena, main kal office aake documents de jaunga.", "Legitimate building maintenance AMC renewal follow-up — no financial transaction requested over phone.")
add("UNKNOWN", False, "Hello, main aapka insurance agent hoon Rajan, LIC ki taraf se, aapki maturity agle saal March mein hai, documents ready rakhna, ek baar milenge is mahine mein.", "Legitimate LIC agent proactively informing about policy maturity — no fee or OTP requested.")
add("UNKNOWN", False, "Namaste, Paytm KYC center se baat kar raha hoon, aapka KYC incomplete hai, aap nearest KYC center pe aa sakte hain apna ID le ke, centre ki list app mein hai.", "Legitimate Paytm KYC reminder directing to a physical centre — not requesting documents or OTP over phone.")
add("UNKNOWN", False, "Hello sir, main aapke colony ka milk supplier hoon, kal se milk rate 5 rupaye badh jaayegi, please inform karna chahta tha pehle se.", "Routine milk vendor rate increase notification — entirely benign, no financial fraud indicators.")
add("UNKNOWN", False, "Bhai wo presentation ke liye mujhe aaj raat tak data chahiye tha, bhej sakta hai kya? Boss subah meeting mein maangenge.", "Workplace deadline communication between colleagues — no scam elements.")
add("UNKNOWN", False, "Hello, I am from the National Health Mission, we are doing a door-to-door TB screening camp in your area next week, no charges, just wanted to inform you.", "Legitimate government health outreach with no fees, no OTP, no personal data collection over phone.")
add("UNKNOWN", False, "Sir, your mutual fund SIP of 5000 rupees has been successfully processed for this month. Your portfolio value is now 1.2 lakhs. For details, please log in to the AMC website.", "Legitimate MF SIP processing confirmation — directs to official website, no action required from victim.")

# ─── WRITE ───
with open(out_path, "a", encoding="utf-8") as f:
    for cat, scam, text, reason in data:
        out_obj = {"category": cat, "is_scam": scam, "reasoning": reason}
        row = {"instruction": INSTRUCTION, "input": text, "output": json.dumps(out_obj, ensure_ascii=False)}
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

sc = sum(1 for c, s, _, __ in data if s)
no = sum(1 for c, s, _, __ in data if not s)
print(f"Appended {len(data)} rows  |  Scam: {sc}  |  Normal (hard negatives): {no}")
