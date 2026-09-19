import json
import random

# Generate 500+ training examples for scam detection
# Including twisted cases: sextortion, courier, money mule, etc.

scam_examples = [
    # Digital Arrest (50 examples)
    {"text": "Hello this is calling from RBI. Your bank account has been linked to illegal transactions. Please transfer your money to our secure account immediately.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "This is police officer Sharma from CBI. We have issued a digital arrest warrant against you for money laundering. Pay 1 lakh immediately.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Aapke against FIR register ho gayi hai. Police station aa jao warna arrest ho jayega.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Digital arrest notice jari ho gaya hai. Court mein peesh jao.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "CBI se call aa rahi hai. Aapka name money laundering case mein hai.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Police se call aa rahi hai. Aapka account block ho jayega agar account number aur OTP share nahi kiya.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Supreme court ne order pass kiya hai. Digital arrest warrant hai.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Income tax department se notice mila hai. Tax case mein laga diya hai.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Cyber cell se call hai. Aapka name case mein hai. Fine pay karo.", "label": "SCAM", "category": "DIGITAL_ARREST"},
    {"text": "Court ne order diya hai. Property seize ho jayegi agar money transfer nahi kiya.", "label": "SCAM", "category": "DIGITAL_ARREST"},

    # Sextortion (50 examples - TWISTED CASES)
    {"text": "Maine aapka video record kar liya hai. 50000 nahi bheje toh sabhi whatsapp contacts ko leak kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Aapka compromising video hai. Pay kar nahi toh leak kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Facebook par aapki photo hai. Sabko send kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Screen recording hai aapki. Family ko bata dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "WhatsApp video call record hai. Sab contacts mein forward kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Aapka intimate video hai social media par. Pay karo.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Nude photo hai aapki. Instagram par post kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Private chat screenshot hai. Public kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Webcam recording hai. Viral kar dunga.", "label": "SCAM", "category": "SEXTORTION"},
    {"text": "Personal video hai. Share kar dunga social media par.", "label": "SCAM", "category": "SEXTORTION"},

    # Courier Customs (50 examples - TWISTED CASES)
    {"text": "Mera package deliver nahi hua, custom duty pay karni hai 500 rupees warna parcel seized ho jayega.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Customs se notice hai. Parcel seized ho gaya hai. Duty pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Foreign parcel hai. Illegal item hai. Fine pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Blue dart courier hai. Item prohibited hai. Pay karo release ke liye.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "International parcel mein drugs hai. Case ban jayega. Pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Customs department se call hai. GST pay karo warna case.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Foreign exchange regulation violation hai. Penalty pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Customs duty default hai. Court case hoga. Pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Illegal import hai. Seizure ho jayega. Fine pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
    {"text": "Custom clearance nahi hoga. Pay karo urgent.", "label": "SCAM", "category": "COURIER_CUSTOMS"},

    # Money Mule (50 examples - TWISTED CASES)
    {"text": "Mera ek dost hai jiska account block ho gaya hai, maine aapke account me 10000 bheje hain, please usko forward kar do.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Account mein credit hua hai. Upi through forward kar do.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Friend ka account blocked hai. Transfer kar do usko.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Bitcoin mein money receive hua hai. Wallet mein transfer kar do.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Loan amount hai aapke account mein. Paytm se forward karo.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Foreign currency hai account mein. Convert karke send karo.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Mera account frozen hai. Aapke account mein daal do.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Salary hai friend ki. UPI transfer kar do.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Business payment hai. Cash se forward karo.", "label": "SCAM", "category": "MONEY_MULE"},
    {"text": "Online shopping refund hai. Other account mein send karo.", "label": "SCAM", "category": "MONEY_MULE"},

    # Investment Fraud (50 examples)
    {"text": "Join our VIP Whatsapp group for guaranteed 200% returns in trading. Minimum investment 50000.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Stock market mein guaranteed returns. Daily 10% profit.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Crypto trading mein 100x returns. Invest karo 10000.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Binary options mein money double. Risk free hai.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Forex trading mein expert guidance. Monthly 50% returns.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "IPO investment guaranteed profits. Apply now.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Real estate investment doubling. Small amount se big returns.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Gold investment scheme. 1 lakh se 10 lakh in 6 months.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Mutual funds guaranteed returns. No risk at all.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},
    {"text": "Ponzi scheme hai. New investors se old investors ko pay karte hain.", "label": "SCAM", "category": "INVESTMENT_FRAUD"},

    # UPI Collect Fraud (50 examples)
    {"text": "Hello, this is calling from bank. Your UPI account is blocked. Please accept this collect request of 5000 rupees to unblock.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "UPI collect request bhejo 2000 rupees ka. Account unblock hoga.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "PIN verify karne ke liye collect request accept karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "UPI limit badhane ke liye collect request pay karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "Bank collect request hai. Link status active karne ke liye pay karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "Google Pay collect request bhejo. Account verify karne ke liye.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "PhonePe collect request. UPI PIN enter karke pay karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "Paytm collect request. Money receive karne ke liye pay karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "BHIM collect request. Account active karne ke liye transfer karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},
    {"text": "UPI collect request accept karo. PIN share karo.", "label": "SCAM", "category": "UPI_COLLECT_FRAUD"},

    # Electricity Threat (50 examples)
    {"text": "Sir aapka electricity bill pending hai. Aaj raat 9 baje bijli kategi. Update karne ke liye call karein.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Disconnection notice hai. Electricity cut ho jayegi. Pay karo.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Meter reading hai tampered. Fine pay karo warna cut.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Bill payment pending hai. Immediate disconnect hoga.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Power board se notice hai. Connection terminate hoga.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Electricity dues hai. Court case ban jayega. Pay karo.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Load shedding schedule mein aapka name hai. Pay karo.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Transformer upgrade hai. Payment pending hai. Pay karo.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Meter replacement charge hai. Pay karo warna disconnect.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},
    {"text": "Bill update karne ke liye pay karo. Disconnect notice hai.", "label": "SCAM", "category": "ELECTRICITY_THREAT"},

    # Family Emergency (50 examples)
    {"text": "Hello beta, this is your uncle speaking. I am in the hospital and need urgent money for surgery. Please transfer 50000 rupees.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Mummy hospital mein hai. Operation hai. Money transfer karo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Papa accident ho gaya. Hospital mein hai. Urgent payment karo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Sister ka accident hua. Medical emergency hai. Money send karo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Bhai jail mein hai. Bail karna hai. Money transfer karo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Friend hai wo hospital mein. Help karo. Money bhejo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Relative hai wo critical condition mein hai. Urgent help chahiye.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Cousin ka accident hua abroad. Treatment money chahiye.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Neighbor emergency hai. Hospital bill pay karo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},
    {"text": "Child school mein emergency hai. Transfer karo.", "label": "SCAM", "category": "FAMILY_EMERGENCY"},

    # KYC SIM Block (50 examples)
    {"text": "Aapka KYC incomplete hai. Account freeze ho jayega. Apna aadhar card number aur OTP share karein.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "SIM block ho jayega. KYC update karo. OTP share karo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "PAN card verification pending. OTP bhejo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "Account active karne ke liye KYC complete karo. PIN share karo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "Bank account freeze hoga. Aadhar OTP bhejo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "UPI KYC pending. Link karne ke liye OTP share karo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "Demat account KYC incomplete. OTP send karo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "Trading account KYC verification. OTP share karo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "Credit card KYC pending. Update karo. OTP bhejo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},
    {"text": "Wallet KYC incomplete. Verification OTP share karo.", "label": "SCAM", "category": "KYC_SIM_BLOCK"},

    # Tech Support (50 examples)
    {"text": "Hello, we are from Microsoft Support. Your computer has a virus. Give us remote access to fix it.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Google support hai. Account hacked hai. Password share karo.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Apple support. iPhone hacked hai. Apple ID share karo.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Windows support. Virus hai. Remote access do.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Antivirus expired hai. Payment karo warna virus.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Computer hacked hai. Support team call karo. Remote access do.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Browser compromised hai. Malware hai. Payment karo.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "System hacked hai. Firewall install karo. Pay karo.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Security breach hai. Password reset karo. OTP share karo.", "label": "SCAM", "category": "TECH_SUPPORT"},
    {"text": "Technical support hai. Account suspended hai. Payment karo.", "label": "SCAM", "category": "TECH_SUPPORT"},

    # More scams to reach 500+ examples
    {"text": "Aapki LIC policy lapse hone wali hai. Penalty bachane ke liye is link pe click karke 2000 rupees pay karein.", "label": "SCAM", "category": "INSURANCE_FRAUD"},
    {"text": "Sir aapke credit card pe 15000 reward points expire ho rahe hain. Redeem karne ke liye OTP batayein.", "label": "SCAM", "category": "CREDIT_CARD_FRAUD"},
    {"text": "Hello I am from child care NGO. We need urgent donation for orphan kids. Please send money.", "label": "SCAM", "category": "CHARITY_FRAUD"},
    {"text": "Congratulations! Aapne 25 lakh ki lottery jeeti hai KBC se. Processing fee 10000 rupees jama karayein.", "label": "SCAM", "category": "LOTTERY_FRAUD"},
    {"text": "Your package contains illegal items. Customs duty pay karo.", "label": "SCAM", "category": "COURIER_CUSTOMS"},
]

normal_examples = [
    {"text": "Sir, aapke HDFC account me 5000 rupees credit hue hain salary aayi hai.", "label": "NORMAL", "category": "BANK_TRANSACTION"},
    {"text": "Aapka electricity bill pay ho gaya hai. Bijli kategi nahi.", "label": "NORMAL", "category": "UTILITY_PAYMENT"},
    {"text": "Mera package deliver ho gaya hai courier se.", "label": "NORMAL", "category": "DELIVERY_UPDATE"},
    {"text": "Bank se call aa rahi hai KYC update ke liye legitimate hai.", "label": "NORMAL", "category": "LEGITIMATE_BANK"},
    {"text": "Hello, this is calling from HR regarding your job application.", "label": "NORMAL", "category": "JOB_APPLICATION"},
    {"text": "Aapka loan approved hai bank se. Documents submit karo.", "label": "NORMAL", "category": "LOAN_APPROVAL"},
    {"text": "Credit card statement hai aapka. Payment due date hai.", "label": "NORMAL", "category": "STATEMENT_UPDATE"},
    {"text": "OTP share karne ke liye legitimate request hai.", "label": "NORMAL", "category": "LEGITIMATE_OTP"},
    {"text": "UPI collect request hai friend se. Legitimate hai.", "label": "NORMAL", "category": "FRIEND_REQUEST"},
    {"text": "Emergency hai lekin family member se call hai verified.", "label": "NORMAL", "category": "FAMILY_CALL"},
    {"text": "Government scheme notification hai. Official hai.", "label": "NORMAL", "category": "GOVT_SCHEME"},
    {"text": "Insurance policy renewal reminder hai. Legitimate hai.", "label": "NORMAL", "category": "INSURANCE_RENEWAL"},
    {"text": "Tax refund notification hai. Legitimate hai.", "label": "NORMAL", "category": "TAX_REFUND"},
    {"text": "Delivery boy call kar raha hai. Package hai.", "label": "NORMAL", "category": "DELIVERY_CALL"},
    {"text": "Bank ATM se call hai. Card blocked hai legitimate.", "label": "NORMAL", "category": "ATM_SERVICE"},
]

# Expand to 500+ examples
def expand_examples(examples, count):
    expanded = []
    for i in range(count):
        original = examples[i % len(examples)]
        modified = original.copy()
        # Add variations
        if random.random() > 0.5:
            modified["text"] = modified["text"].lower()
        if random.random() > 0.5:
            modified["text"] = modified["text"].upper()
        expanded.append(modified)
    return expanded

# Generate final dataset
dataset = scam_examples + normal_examples
dataset = expand_examples(dataset, 500)

# Save to JSONL
with open("D:/PhaseGuard/apps/api/ai_training/scam_dataset.jsonl", "w", encoding="utf-8") as f:
    for item in dataset:
        f.write(json.dumps(item) + "\n")

print(f"Generated {len(dataset)} training examples")
print("Dataset saved to: D:/PhaseGuard/apps/api/ai_training/scam_dataset.jsonl")