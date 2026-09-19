# -*- coding: utf-8 -*-
"""
MEGA DATASET - All possible Indian phone scam patterns
Covers: All variations, languages (Hindi/English/Hinglish), 
tones (aggressive/polite/urgent/friendly), STT noise, regional dialects
"""
import json
import os
import random

INSTRUCTION = "Analyze the following phone call transcript and extract scam claims. Output JSON with 'category', 'is_scam' and 'reasoning'."
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(SCRIPT_DIR, "..", "ai_training", "dataset.jsonl")

data = []
def add(category, is_scam, transcript, reasoning):
    data.append((category, is_scam, transcript, reasoning))

# ══════════════════════════════════════════════════════════════
#  DIGITAL ARREST — every angle: CBI, NCB, ED, Customs, RBI,
#  Interpol, Supreme Court, Income Tax, Foreign Parcel
# ══════════════════════════════════════════════════════════════
add("DIGITAL_ARREST", True, "Main Enforcement Directorate se Inspector Verma bol raha hoon. Aapka naam hawala transaction mein aaya hai. Aapko abhi Skype pe aa ke apna statement dena hoga, call mat kaatna warna immediately arrest ho jayenge.", "ED impersonation + instant arrest threat + forced video statement = digital arrest.")
add("DIGITAL_ARREST", True, "Sir, yeh Income Tax Investigation Wing Delhi hai. Aapne pichle teen saal mein undisclosed income chhupayi hai. Abhi ek crore tax arrears baki hain. Ye call mat kaatna, hum aapko digital custody mein le rahe hain.", "IT department impersonation with undisclosed income fabrication and digital custody threat.")
add("DIGITAL_ARREST", True, "Hello, Interpol Mumbai desk se bol raha hoon. Aapka passport number ek international drug trafficking ring se linked hai. Aap abhi WhatsApp video call pe aayein aur camera on rakhein, ye mandatory hai.", "Interpol impersonation with passport-linked drug trafficking claim demanding video surveillance.")
add("DIGITAL_ARREST", True, "Supreme Court ka contempt notice aapko issue hua hai. Case number SC-2024-4471. Agar aap 2 ghante mein apna statement online record nahi karte toh non-bailable warrant execute ho jayega.", "Fake Supreme Court contempt notice with case number to sound legitimate, pressuring online statement recording.")
add("DIGITAL_ARREST", True, "Yeh RBI Fraud Cell hai. Aapke account se 47 lakh ke suspicious transactions hue hain. Account freeze ho raha hai, aap call mat katein, hum aapko digital hold pe rakh rahe hain verification ke liye.", "RBI impersonation with fabricated suspicious transactions leading to fake 'digital hold'.")
add("DIGITAL_ARREST", True, "Sir I am from the National Cyber Crime Reporting Portal. Your IP address was used to access CSAM content. This is a non-bailable offence. Stay on the line or our team will reach your address in 20 minutes.", "Extreme fear tactic using CSAM allegation tied to IP address with countdown threat of physical arrest.")
add("DIGITAL_ARREST", True, "Aapke naam pe teen mobile numbers issue hue hain jinka use terrorist communication mein hua hai. Main NIA headquarters se bol raha hoon. Aapko abhi video call pe verification deni hogi warna team dispatch ho rahi hai.", "NIA impersonation with terrorism-linked phone numbers and urgent video verification demand.")
add("DIGITAL_ARREST", True, "Sir your Aadhaar was found on a dark web marketplace being sold. Central Cyber Intelligence Bureau is investigating. Do not inform anyone about this call or it will be treated as obstruction of justice.", "CCIB impersonation (fake agency) with dark web Aadhaar sale story and secrecy instruction.")
add("DIGITAL_ARREST", True, "Mujhe judge sahab ki taraf se aapko inform karna tha ki aapke khilaf bail cancel ki application reject hui hai. Aapko is case mein ek settlement amount 2 lakh bharni hogi tabhie ghar pe rahe sakte hain.", "Fake judge/court settlement demand under threat of bail cancellation to extract money.")
add("DIGITAL_ARREST", True, "Yeh call CBI ke Special Crimes Unit se hai. Ek company ke naam pe aapke PAN se shell companies banayi gayi hain. Aapko digital remand pe liya ja raha hai, apna phone neeche mat rakhein.", "Shell company fraud allegation tied to PAN, combined with digital remand instruction.")

# ══════════════════════════════════════════════════════════════
#  UPI / PAYMENT FRAUD — QR, collect request, fake payment proof,
#  wrong transfer, cashback, reward, scratch card
# ══════════════════════════════════════════════════════════════
add("UPI_COLLECT_FRAUD", True, "Bhai tune cycle becha na OLX pe? Main khareedna chahta hoon. Tera GPay number de, main abhi collect request bhejta hoon, tu accept kar apna pin daalke, 8000 seedha aa jayenge.", "OLX vehicle sale UPI collect fraud — victim tricked into accepting debit as credit.")
add("UPI_COLLECT_FRAUD", True, "Sir maine aapke account mein galti se 5000 rupaye bhej diye hain, please wapas kar dijiye is UPI pe, mere baap beemar hain urgent hai.", "Reverse UPI scam — claims a mistaken transfer was made and pressures victim to return money that was never received.")
add("UPI_COLLECT_FRAUD", True, "Aapko PhonePe ki taraf se Diwali bonus mila hai 3000 rupaye, sirf apna UPI PIN daalo is notification mein aur amount credit ho jayega.", "Fake festival bonus notification requiring PIN entry which actually debits the account.")
add("UPI_COLLECT_FRAUD", True, "Mere paas aapke purane sim ka pending refund hai 1200 rupaye, mujhe aapka Paytm number do aur wo QR code scan karo jo main bhej raha hoon, refund mil jayega.", "Fake telecom refund via QR scan — entering PIN on a payment QR sends money out.")
add("UPI_COLLECT_FRAUD", True, "Sir aapka scratch card reward 5000 rupaye ka nikla hai Jio ki taraf se, claim karne ke liye ye link pe jaayein aur apna UPI PIN enter kar ke verify karein.", "Fake telecom scratch card reward requiring UPI PIN entry on a phishing link.")
add("UPI_COLLECT_FRAUD", True, "Bhaiya main army mein hoon, aapka old Quikr ad dekha second hand laptop ke liye. Main full price dunga 25000, advance send kar raha hoon, aap bhi ek 10 rupaye ka test transfer karo taaki NEFT link ho.", "Fake army buyer on Quikr asking seller to do a 'test transfer' — first step in extracting money.")
add("UPI_COLLECT_FRAUD", True, "Aapne humari app se last month jo order kiya tha uska cashback process nahi hua, 800 rupaye ka hai, is UPI collect request ko accept karo pin daalo cashback aa jayega.", "Fake e-commerce cashback via collect request that debits rather than credits.")
add("UPI_COLLECT_FRAUD", True, "Tumhara purana BSNL number tha na, uska security deposit 1500 refund ho raha hai, mujhe account number aur ek small confirmation payment of 1 rupee ka link bhej raha hoon usse pay karo verification ke liye.", "Phishing via a fake 1-rupee 'confirmation' link that harvests card/UPI credentials.")

# ══════════════════════════════════════════════════════════════
#  KYC / SIM BLOCK — TRAI, Airtel, Jio, BSNL, Vi, UIDAI,
#  bank KYC, video KYC, biometric update
# ══════════════════════════════════════════════════════════════
add("KYC_SIM_BLOCK", True, "Sir aapka Vi number kal permanently deactivate ho raha hai, new telecom policy ke tehat re-verification mandatory hai. Apna Aadhaar OTP share karein jo abhi aaya hai, 2 minute ka kaam hai.", "Vi telecom impersonation with urgent Aadhaar OTP demand under fake deactivation policy.")
add("KYC_SIM_BLOCK", True, "Hello, main DoT (Department of Telecom) se bol raha hoon. Your number will be disconnected in 24 hours unless you complete your digital KYC. Open mAadhaar app and share the 6 digit face authentication code with me.", "Fake DoT call requesting mAadhaar face auth code — enables Aadhaar-linked service impersonation.")
add("KYC_SIM_BLOCK", True, "Aapka SBI account ka video KYC incomplete hai, hum aapko ek link bhejenge WhatsApp pe, uss link pe aapko apni photo aur PAN card ki photo upload karni hogi, baad mein OTP bhi aayega.", "Bank video KYC phishing via WhatsApp link collecting documents + OTP for account takeover.")
add("KYC_SIM_BLOCK", True, "Aapka Aadhaar biometric lock enable nahi hai isliye koi bhi aapka Aadhaar misuse kar sakta hai. Hum aapko free mein lock karwa denge, bas apna Aadhaar number aur fingerprint scan link share karein.", "Fake Aadhaar biometric lock service requesting Aadhaar number and biometric data for identity theft.")
add("KYC_SIM_BLOCK", True, "Main BSNL helpdesk se hoon, aapka landline number deactivate ho raha hai, new digital system mein migrate karne ke liye apna registered mobile OTP share karein.", "Fake BSNL migration requiring OTP — enables SIM swap or account compromise.")
add("KYC_SIM_BLOCK", True, "Yeh Airtel fraud prevention team hai. Kisi ne aapke naam pe postpaid connection le liya hai, usse block karne ke liye aap apna Aadhaar number aur last 4 digits of PAN confirm karein.", "Fake Airtel fraud prevention impersonation collecting Aadhaar + PAN for identity theft.")
add("KYC_SIM_BLOCK", True, "Sir aapke phone pe linked sare UPI apps kal raat close ho jayenge agar KYC update nahi hua, please is app link pe jaake apna selfie aur aadhaar scan upload kar dijiye.", "Fake UPI KYC deadline pushing victim to a phishing app to upload biometrics and Aadhaar.")

# ══════════════════════════════════════════════════════════════
#  FAKE JOB / TASK SCAM — Telegram tasks, WFH, internship,
#  government job, typing work, ad posting, data entry
# ══════════════════════════════════════════════════════════════
add("FAKE_JOB_TASK", True, "Bhai part time kaam chahiye? Hamare pass online typing ka kaam hai, 40 paise per word milte hain, daily 500-1000 kama sakte ho. Bas pehle 500 rupaye ka registration fee dena hoga ek baar.", "Typing job scam with per-word pay promise but upfront registration fee requirement.")
add("FAKE_JOB_TASK", True, "Hello, I am calling from TCS digital hiring team. You are shortlisted for a backend developer role, 8 LPA, work from home. Please pay 2000 rupees as background verification charge within today.", "Impersonates TCS HR to charge a fake background verification fee for a non-existent job.")
add("FAKE_JOB_TASK", True, "Aapko Zomato delivery partner banana chahte hain hum, aapke area mein slot available hai, joining ke liye 1500 rupaye ka registration aur ID verification charge dena hoga online.", "Fake Zomato delivery partner onboarding scam with upfront registration charge.")
add("FAKE_JOB_TASK", True, "Main ek NGO se hoon, hum housewives ko ghar baithe envelope packing ka kaam dete hain, 15000 mahine milte hain, bas 800 rupaye ka material deposit dena hoga jo kaam ke sath adjust ho jayega.", "Classic envelope stuffing home job scam requiring material deposit before any work is given.")
add("FAKE_JOB_TASK", True, "Telegram task #47: Aaj ka pre-paid task hai 5000 rupaye invest karo ek e-commerce product review karne ke liye, iske 7500 return milenge account mein 30 minutes mein, confirm karein.", "Telegram pre-paid investment task scam with guaranteed inflated return promise.")
add("FAKE_JOB_TASK", True, "Sir aapka government job notification aa gaya hai, Group D railways mein aapka naam select hua hai, appointment letter ke liye 3500 rupaye ka demand draft banwana hoga is account mein.", "Fake railway Group D job offer requiring demand draft payment for a fabricated appointment letter.")
add("FAKE_JOB_TASK", True, "Aapko digital marketing executive ki job mili hai ek startup mein, 20000 per month, remote, lekin training module ke liye 1200 rupaye pay karne honge pehle, phir salary shuru.", "Fake startup job offer with a mandatory paid training module before the non-existent job begins.")
add("FAKE_JOB_TASK", True, "Bhai Instagram pe ad posting ka kaam hai, per post 200 rupaye milenge, 20 post daily kar sakte ho, daily 4000 kama sakte hain. Bas starter kit ke liye 999 rupaye dene honge.", "Instagram ad posting job scam with a high-income promise requiring a starter kit purchase.")

# ══════════════════════════════════════════════════════════════
#  INVESTMENT FRAUD — stock tips, mutual fund, real estate,
#  ponzi, referral MLM, fixed deposit fraud
# ══════════════════════════════════════════════════════════════
add("INVESTMENT_FRAUD", True, "Sir hum ek SEBI registered PMS firm hain, minimum ticket 2 lakh hai, last 12 months mein 180% return diya hai humare clients ko, aaj hi demat account transfer karein paisa.", "Fake SEBI-registered PMS firm with fabricated 180% annual return to lure large investments.")
add("INVESTMENT_FRAUD", True, "Yeh ek MLM opportunity hai jisme aap 5 logo ko join karein toh 50,000 rupaye mahine kamaoge passively. Pehle 10,000 ka starter pack kharidna hoga ek baar sirf.", "Multi-level marketing pyramid scheme requiring a starter pack purchase and recruitment.")
add("INVESTMENT_FRAUD", True, "Sir main ek commodity trading firm se hoon, MCX pe crude oil ka signal hai aaj, 1 lakh invest karo, shaam tak 40,000 profit pakka hai, main personally guarantee de raha hoon.", "Fake commodity trading signal with personal profit guarantee, a clear investment fraud red flag.")
add("INVESTMENT_FRAUD", True, "Bhai ek fixed deposit jaisi scheme hai jisme bank se 3x return milta hai, 6 mahine mein, totally legal, government backed, sirf 25,000 chahiye shuru karne ke liye.", "Fake 'government-backed' FD scheme promising 3x returns in 6 months — a Ponzi lure.")
add("INVESTMENT_FRAUD", True, "Hum ek real estate investment pool chalate hain, 5000 rupaye mein ek share milta hai, plot Pune ke bahar develop ho raha hai, 2 saal mein 3 guna value ho jayegi, 100% legal.", "Fractional real estate scam with guaranteed land appreciation and no verifiable project details.")
add("INVESTMENT_FRAUD", True, "Sir ye P2P lending app hai, aap paisa lagao 15% monthly return aayega, already 50,000 members hain, main khud 2 lakh laga chuka hoon, RBI approved hai ye platform.", "Fake P2P lending app with 15% monthly returns falsely claiming RBI approval.")
add("INVESTMENT_FRAUD", True, "Main ek stock analyst hoon, kal Nifty 500 points upar jayega, mere premium signals se aaj tak kisi ne loss nahi khaya, ek month ke liye 5000 membership dena hoga bas.", "Guaranteed Nifty prediction with loss-free track record claim — classic unregistered stock tip fraud.")

# ══════════════════════════════════════════════════════════════
#  FAMILY EMERGENCY — hospital, jail, accident, robbery,
#  stranded, AI clone voice patterns
# ══════════════════════════════════════════════════════════════
add("FAMILY_EMERGENCY", True, "Dada ji main hoon Rohit, mera phone toot gaya, ek dost ke phone se bol raha hoon, main train mein hoon aur purse chori ho gaya, please 3000 rupaye bhej do is number pe.", "Impersonates a grandchild stranded on a train with a stolen wallet to extract emergency money.")
add("FAMILY_EMERGENCY", True, "Hello uncle, I am Priya's friend. She met with an accident near Pune highway, she is in surgery right now, hospital is asking for 40,000 advance payment. She told me to call you, please transfer urgently.", "Uses a friend-of-victim narrative to reach family for emergency hospital payment.")
add("FAMILY_EMERGENCY", True, "Sir main Sanjay Nagar Police station se bol raha hoon, aapke bete ko ek fight mein pakda gaya hai, zamin ke liye 20,000 chahiye abhi nahi diye toh raat bhar lock up mein rahenge.", "Fake police station lockup call demanding bail money for a fabricated fight arrest.")
add("FAMILY_EMERGENCY", True, "Papa main bahut mushkil mein hoon, drugs case mein ghira gaya hoon, dost ne set up kiya mujhe, waqeel ne 50,000 manga hai abhi ke abhi, please kisi ko mat batana.", "Child impersonation in a fabricated drugs sting, demanding lawyer fee and secrecy from other family.")
add("FAMILY_EMERGENCY", True, "Mummy ye main hoon Divya, office trip pe thi, mera bag chori ho gaya hotel mein, passport, cash sab, please 15000 NEFT karo is account mein, main kal wapas aakar return karungi.", "Daughter impersonation stranded on business trip with stolen documents, requesting NEFT transfer.")
add("FAMILY_EMERGENCY", True, "Bhaiya aapke pitaji ko heart attack aya hai, hum Fortis mein admit kar rahe hain, ICU bed ke liye 60,000 ka advance chahiye abhi ke abhi, please koi bhi account batao paisa bhej denge.", "Fake hospital emergency ICU advance payment demand for a father's fabricated heart attack.")
add("FAMILY_EMERGENCY", True, "Sir your daughter has been detained at the airport. She is trying to travel with an unverified visa. To avoid deportation and legal case, please transfer 35,000 as a security deposit right now.", "Airport immigration detention scam targeting parents of travelling adult children.")

# ══════════════════════════════════════════════════════════════
#  SEXTORTION — all angles: real video, fake AI video, threat
#  to contacts, LinkedIn, boss, family members
# ══════════════════════════════════════════════════════════════
add("SEXTORTION", True, "Maine ek AI tool se aapki social media photos use karke ek compromising video banaya hai jo bilkul real lagta hai. Agar 25000 nahi bheje toh is video ko aapki company ke HR ko email karunga.", "AI-generated deepfake video threat used for sextortion even without an actual compromising video.")
add("SEXTORTION", True, "Tumne mujhse video call pe kuch dekha tha, wo maine record kiya aur screenshot bhi liye, tum 30 minute mein 10000 nahi bheje toh sab Facebook aur Instagram pe jaa jayega publicly.", "Screenshot + video recording threat via a past video call demanding quick payment.")
add("SEXTORTION", True, "Hello sir, main ek girl thi jo tumse online mili thi, tumne mujhe jo video bheja tha wo mere paas hai, agar paisa nahi diya to main tumhari wife ko forward kar dungi with a message.", "Intimate content forwarded to a spouse threat to exploit marriage-related fear and pay ransom.")
add("SEXTORTION", True, "Bhai teri boss ko teri woh raat wali photo send karne wala hoon agar tune mujhe aaj 15000 nahi bheje. Tujhe naukri se nikaala jayega, soch le.", "Workplace-targeted sextortion threatening to send compromising content to the victim's boss.")
add("SEXTORTION", True, "You have 1 hour. Pay 200 dollars in Bitcoin to this wallet or the video of you on the adult site goes to all your Instagram followers. I have their list already.", "Cryptocurrency sextortion with a public platform distribution threat and countdown timer.")
add("SEXTORTION", True, "Sir kuch din pehle aapne ek unknown number se video call receive ki thi, us mein kuch aisa capture hua jo aapke relatives ke liye acceptable nahi hoga. Mujhe 8000 do warna family group mein daal dunga.", "Fake video capture claim from an unknown call, targeting family reputation to extort money.")

# ══════════════════════════════════════════════════════════════
#  ELECTRICITY / UTILITY THREAT — BESCOM, MSEB, TATA Power,
#  gas, water, smart meter, meter tampering
# ══════════════════════════════════════════════════════════════
add("ELECTRICITY_THREAT", True, "Aapka bijli ka meter reading galat report hua tha pichle 6 mahine se, ab ek saath 8400 rupaye arrears ban gaye hain, aaj raat 8 baje se pehle is number pe Paytm karo warna line kaat di jayegi.", "Fake electricity arrears demand payable to a personal Paytm number under disconnection threat.")
add("ELECTRICITY_THREAT", True, "Sir main TATA Power se bol raha hoon, aapka commercial meter tampered hai, electrical inspector kal aayenge, FIR se bachne ke liye 5000 on-the-spot settlement karo is UPI pe.", "Fake TATA Power meter tampering allegation with FIR threat to extract settlement payment.")
add("ELECTRICITY_THREAT", True, "Madam aapka gas connection aaj band hone wala hai kyunki aapne safety audit form submit nahi kiya, abhi 200 rupaye online bhejkar form reactivate karo, link bhej raha hoon.", "Fake gas connection suspension requiring online payment for a fabricated safety audit form.")
add("ELECTRICITY_THREAT", True, "Aapke area ka electricity load shedding schedule change ho raha hai, ye avoid karne ke liye smart meter upgrade mandatory ho gaya hai, 1200 rupaye upgrade fee bhejiye is account mein.", "Fake smart meter upgrade fee demand to avoid a fabricated load shedding inconvenience.")
add("ELECTRICITY_THREAT", True, "Yeh Jal Board se call hai, aapka water connection KYC pending hai, kal se paani supply rok di jayegi, apna consumer ID aur Aadhaar number verify karke OTP share karein.", "Fake water board KYC with Aadhaar + OTP demand threatening water supply suspension.")

# ══════════════════════════════════════════════════════════════
#  PRIZE / LOTTERY — KBC, Amazon, Jio, scratch, foreign lottery,
#  car, gold, overseas
# ══════════════════════════════════════════════════════════════
add("PRIZE_LOTTERY", True, "Sir aapka number Sony Entertainment Television ke lucky draw mein select hua hai, KBC Special Prize 10 lakh ka, collect karne ke liye pehle 7500 ka TDS government account mein jama karna hoga.", "Fake KBC/Sony prize requiring TDS payment before release — advance-fee lottery fraud.")
add("PRIZE_LOTTERY", True, "Aapko Jio ke 10th anniversary mein ek Maruti Swift car jeeti hai, car ki RC transfer ke liye 12,000 rupaye documentation charge dena hoga, kal tak confirm karein.", "Fake Jio anniversary car prize with RC transfer documentation fee demand.")
add("PRIZE_LOTTERY", True, "Hello ma'am, this is from Dubai Shopping Festival, your mobile number won 1,50,000 UAE Dirham, to claim please share your bank SWIFT code and pay 25,000 rupees for international wire processing.", "International lottery win requiring SWIFT code and wire processing fee — classic advance-fee foreign lottery.")
add("PRIZE_LOTTERY", True, "Aapne last month ek online survey fill ki thi, usme aap lucky winner hain 50,000 Amazon gift card ka, claim karne ke liye aapka GST number chahiye aur 2000 rupaye processing fee.", "Fake survey prize with GST number + processing fee demand — hybrid phishing lottery scam.")
add("PRIZE_LOTTERY", True, "Sir your number has been selected by our sponsor for a 2-night Maldives holiday package. Confirm by paying 3000 token money and we will send your voucher within 24 hours.", "Fake holiday package prize requiring a non-refundable token money payment to confirm.")

# ══════════════════════════════════════════════════════════════
#  TECH SUPPORT — Microsoft, Apple, Google, bank antivirus,
#  ISP router hack, phone virus
# ══════════════════════════════════════════════════════════════
add("TECH_SUPPORT", True, "Hello this is Apple Support. Your iCloud account is being accessed from Russia. To secure it immediately, share your Apple ID password and the 6-digit verification code sent to your device.", "Fake Apple Support requesting Apple ID password + 2FA code to take over the victim's account.")
add("TECH_SUPPORT", True, "Sir aapka internet router hack ho gaya hai, hum aapke ISP se bol rahe hain. Aap ye IP address type karein browser mein aur hum remotely router reset karenge, baad mein apna WiFi password change karke mujhe bata dena.", "Fake ISP router hack requiring the victim to access a remote URL and then share a new password.")
add("TECH_SUPPORT", True, "Aapke Android phone mein ek banking Trojan detect hua hai jo aapke GPay aur PhonePe ke credentials chura raha hai. Hum Google Security se bol rahe hain, is APK file ko install karo jo hum bhej rahe hain WhatsApp pe.", "Fake Google Security pushing a malicious APK via WhatsApp under the guise of removing a banking Trojan.")
add("TECH_SUPPORT", True, "Sir your laptop IP address 103.55.12.84 is being used to send spam globally and has been blacklisted by Microsoft. Please allow remote access so we can run diagnostics and remove the malware within 10 minutes.", "Uses a specific fake IP to appear credible, then requests remote access to gain full device control.")
add("TECH_SUPPORT", True, "Hello, main Google Pay fraud detection team se hoon, aapke account se ek suspicious 14,000 ka transaction pending hai, usse block karne ke liye mujhe aapka login PIN share karna hoga abhi.", "Fake Google Pay fraud prevention team requesting login PIN to block a fabricated pending transaction.")

# ══════════════════════════════════════════════════════════════
#  LOAN HARASSMENT — instant app, fake recovery agents, blackmail,
#  disproportionate penalty, contact spam threats
# ══════════════════════════════════════════════════════════════
add("LOAN_HARASSMENT", True, "Aapne jo 3000 ka loan liya tha CashBean app se, uski due date kal thi aur penalty ke saath ab 18,000 ho gaya hai. Agar aaj nahi diya toh hum aapke 500 contacts ko ek message forward karenge.", "Predatory app penalty escalation from 3,000 to 18,000 with mass contact spam threat.")
add("LOAN_HARASSMENT", True, "Main recovery agent bol raha hoon, aapne jo loan diya tha uski 3rd default date aa gayi hai, kal hamare log aapke ghar aayenge outstanding recover karne, gaon mein sabko pata chal jayega.", "Physical visit threat + public shaming in local community to pressure loan repayment.")
add("LOAN_HARASSMENT", True, "Aapka loan NPA declare ho gaya hai, ab CIBIL score 300 pe aa jayega aur koi bhi bank loan nahi dega kabhi bhi agar aaj 5000 settle nahi kiye. Sirf 2 ghante hain aapke paas.", "CIBIL score destruction threat with a 2-hour countdown to pressure discounted settlement.")
add("LOAN_HARASSMENT", True, "Madam aapke number se hamare app ne aapki contacts download ki hain, gallery bhi access hai. Loan nahi diya toh aapki photos aur contacts dono ko use karenge, aap samajh gayi hain na.", "Explicit threat to weaponize contacts and photos harvested via loan app permissions.")
add("LOAN_HARASSMENT", True, "Sir aap court mein jaoge toh bhi kuch nahi hoga, hum bahar waale hain, recovery ke liye sab kuch karte hain. Agar 10,000 abhi nahi diye toh kal subah aapke office ke bahar 5 log honge.", "Intimidating office-premises physical threat combined with claim of operating outside the law.")

# ══════════════════════════════════════════════════════════════
#  INSURANCE FRAUD — LIC maturity, health insurance, car claim,
#  fake agent, policy surrender
# ══════════════════════════════════════════════════════════════
add("INSURANCE_FRAUD", True, "Sir aapki 20 saal pehle li hui LIC policy mature ho gayi hai, 2.4 lakh milenge, collect karne ke liye pehle 4500 rupaye ka tax clearance certificate fee dena hoga NEFT se.", "Fake LIC policy maturity requiring advance tax clearance certificate payment.")
add("INSURANCE_FRAUD", True, "Aapki car insurance ka no-claim bonus 12,000 rupaye ban gaya hai, claim karne ke liye apna policy number, RC copy aur engine number share kariye, document fee 500 lagegi.", "Fake car insurance NCB claim collecting vehicle documents for identity or insurance fraud.")
add("INSURANCE_FRAUD", True, "Main Star Health ka agent hoon, aapki policy renew ho sakti hai 30% discount mein agar aaj hi online pay karein is link pe, offer sirf aaj tak valid hai.", "Fake insurance agent with a time-limited discount directing to a phishing payment link.")
add("INSURANCE_FRAUD", True, "Sir aapki mediclaim policy mein ek free upgrade available hai, mujhe bas aapka policy number aur Aadhaar confirm karna hoga, uske baad ek OTP aayega wo bhi share karein.", "Fake mediclaim upgrade requiring policy number, Aadhaar and OTP — a triple-credential harvest.")

# ══════════════════════════════════════════════════════════════
#  VISHING / BANK OTP — all banks, all methods
# ══════════════════════════════════════════════════════════════
add("VISHING_BANK_OTP", True, "Main Axis Bank credit card department se bol raha hoon, aapka card upgrade ho raha hai platinum pe free mein, process ke liye aapka current card number, expiry aur CVV ek baar confirm karein.", "Fake Axis Bank credit card upgrade collecting full card details for card-not-present fraud.")
add("VISHING_BANK_OTP", True, "Aapka HDFC bank account ek high-value suspicious transaction ki wajah se temporarily limited hai. Isse unlock karne ke liye net banking mein jaayein aur jo OTP aaye use mujhe padhke bataiye.", "HDFC account unlock scam where shared OTP authorizes a fraudulent transaction.")
add("VISHING_BANK_OTP", True, "Sir this is PNB fraud alert team. Someone is trying to add a new beneficiary of 75,000 rupees in your account. To block this, please share the OTP you just received immediately.", "Fake fraud alert OTP — OTP actually authorizes the beneficiary addition for fraud, not blocks it.")
add("VISHING_BANK_OTP", True, "Namaste, main Kotak Mahindra bank se hoon, aapka auto-debit mandate failed hua hai EMI ke liye, isse activate karne ke liye apna net banking ID aur password ek baar verbally confirm karein.", "Bank EMI mandate activation scam requesting full net banking credentials verbally.")
add("VISHING_BANK_OTP", True, "Hello mam, Canara Bank RD account mein ek bonus interest 2300 rupaye ka add hua hai, claim karne ke liye is IVR pe apna 4-digit ATM PIN dial karein.", "IVR-based ATM PIN harvesting disguised as a bank RD bonus claim process.")

# ══════════════════════════════════════════════════════════════
#  CRYPTO / NFT / TRADING APP SCAM
# ══════════════════════════════════════════════════════════════
add("CRYPTO_SCAM", True, "Bhai ek new DeFi project launch ho raha hai next week, pre-sale chal rahi hai, 1 ETH lagao aur 10x return milega listing pe, team fully doxxed hai, contract audit bhi hua hai, jaldi karo slots bhar rahe hain.", "DeFi presale scam with doxxed team and audit claims to appear legitimate, urgency to fill slots.")
add("CRYPTO_SCAM", True, "Sir aapka Binance withdrawal stuck hai kyunki aapka account unverified hai, verification ke liye 50 USDT fee dena hoga is wallet mein, uske baad aap apna 2 lakh wala withdrawal process kar sakte ho.", "Fake Binance verification fee blocking a large withdrawal — a crypto exchange impersonation scam.")
add("CRYPTO_SCAM", True, "Main ek crypto whale hoon, market mein kuch aisa hone wala hai jo publicly nahi pata, main 10 logo ko bataunga insider info aur unke paas 5000 lagao 48 ghante mein 25000 waapas milenge.", "Fake crypto whale with insider information promising 5x returns in 48 hours — pump-and-dump setup.")
add("CRYPTO_SCAM", True, "Aapko hamari app pe staking reward mila hai 3000 USDT ka, withdraw karne ke liye pehle gas fee 150 USDT deni hogi is address pe, phir poora amount release ho jayega.", "Fake crypto staking reward gated by a 'gas fee' payment that is just theft with no actual withdrawal.")
add("CRYPTO_SCAM", True, "Bhai ye P2E game hai play-to-earn, daily 2-3 ghante khelo aur 500 rupaye ka crypto earn karo, lekin pehle game character buy karna hoga 2000 mein, wo tumhara asset rehega.", "Play-to-earn NFT game requiring character purchase upfront — a common gaming-crypto hybrid scam.")

# ══════════════════════════════════════════════════════════════
#  MATRIMONIAL / ROMANCE SCAM — NRI, army, doctor, widower
# ══════════════════════════════════════════════════════════════
add("MATRIMONIAL_FRAUD", True, "Hi, I am a widower doctor settled in Canada with one child, I found your profile on Jeevansathi, I am very serious about marriage. I want to send you a diamond necklace as a token, please share your address and help me pay the customs duty.", "Classic NRI widower doctor matrimony scam leading to a parcel customs duty payment request.")
add("MATRIMONIAL_FRAUD", True, "Mujhe tumse pyaar ho gaya hai, main Mumbai aa raha hoon milne ke liye lekin mera ticket aur hotel ka paisa ek fraud mein chala gaya, please 12,000 bhej do main wapas kar dunga aate hi.", "Online romance leading to a travel-cost loan request before any in-person meeting.")
add("MATRIMONIAL_FRAUD", True, "I am a US citizen of Indian origin, very successful in real estate. I want to invest 50 lakhs in India but I need a trusted partner. I will send the money to you first, just pay the international wire activation fee of 15,000.", "NRI real estate investment partner scam requiring wire activation fee before a promised 50 lakh transfer.")

# ══════════════════════════════════════════════════════════════
#  GOVT SCHEME IMPERSONATION — PM, MNREGA, education,
#  scholarship, ration, pension, health
# ══════════════════════════════════════════════════════════════
add("GOVT_SCHEME_IMPERSONATION", True, "Aapki beti ka PM Scholarship apply hua hai, 48,000 rupaye approve ho gaye hain, disbursement ke liye apna bank account number, IFSC code aur ek OTP share karein jo abhi aayega.", "Fake PM scholarship disbursement collecting bank details + OTP for account drain.")
add("GOVT_SCHEME_IMPERSONATION", True, "Main MNREGA department se hoon, aapke account mein 90 din ki wages 9000 rupaye pending hain, claim karne ke liye Job Card number aur registered mobile OTP bata dijiye.", "Fake MNREGA pending wages collection using job card number + OTP phishing targeting rural workers.")
add("GOVT_SCHEME_IMPERSONATION", True, "Sir government ne senior citizen pension amount badha diya hai, aapko extra 3000 rupaye milenge per month, update ke liye apna pension account number aur Aadhaar link karne ke liye OTP share karein.", "Fake senior citizen pension increase claiming Aadhaar linking via OTP — targets elderly on fixed income.")
add("GOVT_SCHEME_IMPERSONATION", True, "Jandhan account holders ke liye free life insurance 2 lakh ka government de rahi hai, enroll karne ke liye 200 rupaye ka nominal enrollment fee dena hoga, link bhej raha hoon.", "Fake Jan Dhan linked insurance enrollment requiring a nominal fee — targets unbanked/low-income segment.")
add("GOVT_SCHEME_IMPERSONATION", True, "Aapke bachon ke liye Sukanya Samriddhi scheme mein extra maturity benefit available hai, claim karne ke liye apna account number aur guardian Aadhaar number confirm karein phone pe.", "Fake Sukanya Samriddhi benefit claim collecting scheme account + Aadhaar details for identity theft.")

# ══════════════════════════════════════════════════════════════
#  ECOMMERCE REFUND SCAM — Flipkart, Amazon, Meesho, Nykaa
# ══════════════════════════════════════════════════════════════
add("ECOMMERCE_REFUND_SCAM", True, "Main Nykaa customer support se hoon, aapka beauty product return request pending hai 45 din se, refund clear karne ke liye apna Paytm wallet number aur ek verification OTP share karein.", "Fake Nykaa support collecting Paytm number + OTP to drain linked wallet under refund pretext.")
add("ECOMMERCE_REFUND_SCAM", True, "Sir aapne jo Realme phone order kiya tha wo transit mein damage ho gaya, hum full refund de rahe hain, processing ke liye apna UPI ID aur ek test transaction of 1 rupee karein is link pe.", "Fake damage refund via a phishing link disguised as a 1-rupee test transaction.")
add("ECOMMERCE_REFUND_SCAM", True, "Hello ma'am, Snapdeal ki taraf se call hai, aapka COD order deliver nahi ho saka, refund ke liye apna account number aur IFSC dena hoga manual NEFT ke liye, OTP bhi aayega verify karna hoga.", "Fake COD order refund via NEFT requiring account credentials + OTP for account compromise.")

# ══════════════════════════════════════════════════════════════
#  PROPERTY / RENTAL FRAUD
# ══════════════════════════════════════════════════════════════
add("PROPERTY_ADVANCE_FRAUD", True, "Sir ye 2BHK flat Bangalore whitefield mein hai, rent 15000, fully furnished, owner military mein hain overseas, pehle ek mahine ka security advance 15000 bhejiye RTGS se, keys courier se aayengi.", "Classic remote landlord scam where owner is 'overseas military' to avoid in-person meeting, demands advance rent.")
add("PROPERTY_ADVANCE_FRAUD", True, "Ye farmhouse Lonavala mein book karna hai agle weekend ke liye? Abhi 5000 ka token dena hoga online, owner bahar hain lekin property verified hai booking platform pe.", "Fake holiday rental requiring non-refundable online token from an absent 'owner'.")
add("PROPERTY_ADVANCE_FRAUD", True, "Sir aapki loan application ke liye collateral property verify karni hogi, ek chhoti site visit fee 1500 rupaye online pay kariye, valuator aayega kal.", "Fake property valuation fee for a loan application — targets people seeking loans.")

# ══════════════════════════════════════════════════════════════
#  COURIER FRAUD — FedEx, DHL, India Post, Amazon Logistics
# ══════════════════════════════════════════════════════════════
add("COURIER_REDELIVERY", True, "This is DHL Express, your parcel from Germany is held at Mumbai customs, import duty of 6800 rupees must be paid online within 48 hours or it will be returned to sender, link is being sent to your registered number.", "Fake DHL import duty demand via SMS link for a parcel the victim didn't order — courier phishing.")
add("COURIER_REDELIVERY", True, "Aapka India Post Speed Post parcel deliver karne ki koshish ki gayi, aap ghar nahi the, redelivery ke liye is number pe callback karein aur 49 rupaye fee online bharein.", "Fake India Post redelivery fee collected via callback to a scammer's number, not an official portal.")
add("COURIER_REDELIVERY", True, "Sir aapka parcel CCTV mein damage hote hua dikha, insurance claim ke liye aapko apna full name, address, Aadhaar number aur bank account number submit karna hoga is form pe.", "Fake courier damage insurance claim form collecting complete identity + banking details.")

# ══════════════════════════════════════════════════════════════
#  TRAVEL / TOURIST SCAM — visa, hotel, cab, pilgrimage
# ══════════════════════════════════════════════════════════════
add("TOURIST_TRAVEL_SCAM", True, "Sir Char Dham yatra ke liye aapka slot confirm karne ke liye advance 3500 rupaye dena hoga IRCTC special package mein, seats limited hain, aaj raat 12 baje tak offer expire hota hai.", "Fake IRCTC Char Dham pilgrimage package with midnight urgency deadline for advance payment.")
add("TOURIST_TRAVEL_SCAM", True, "Main visa agent hoon, Canada student visa 90% guaranteed milti hai humare through, processing fee 25,000 rupaye hai, baaki baad mein, offer sirf aaj ke liye hai.", "Fake visa consultant with 90% guarantee and urgent same-day fee — immigration scam targeting students.")
add("TOURIST_TRAVEL_SCAM", True, "Sir aapki Shimla hotel booking confirmed hai, lekin owner ne last minute rate badha diya hai, extra 2000 abhi pay karein warna booking cancel ho jayegi 1 ghante mein.", "Last-minute hotel booking price hike scam to extract additional payment under cancellation threat.")

# ══════════════════════════════════════════════════════════════
#  SOCIAL MEDIA IMPERSONATION
# ══════════════════════════════════════════════════════════════
add("SOCIAL_MEDIA_IMPERSONATION", True, "Hi this is Ratan Tata's office. We are running a philanthropy challenge on Instagram, send 5000 rupees and Mr. Tata will donate 50,000 in your name to charity. DM your UPI details.", "Fake Ratan Tata charity matching scam on social media — celebrity impersonation for donations.")
add("SOCIAL_MEDIA_IMPERSONATION", True, "Bhai main Salman Khan ki team se hoon, unke birthday ke liye selected 100 fans ko ek private party ka invite milega, confirmation ke liye 1500 registration fee bhejni hogi is account mein.", "Fake Bollywood celebrity team charging a registration fee for a fabricated private fan event.")
add("SOCIAL_MEDIA_IMPERSONATION", True, "Hi, yeh Ananya Sharma hoon, Instagram pe 2M followers hain, main aapko paid collaboration de rahi hoon 5000 per post, pehle hamari agency ko 1000 ka onboarding fee do.", "Fake influencer collaboration agency charging onboarding fee upfront — social media creator scam.")

# ══════════════════════════════════════════════════════════════
#  MILITARY / ROMANCE SCAM
# ══════════════════════════════════════════════════════════════
add("MILITARY_ROMANCE_SCAM", True, "Hi I am Major Rahul Singh, Indian Army, Ladakh border. We have been talking for 2 months now and I trust you completely. I found some cash in an operation, I need your help to transfer it to India, you get 30%.", "Indian army officer romance scam with operation-cash transfer proposition requiring victim's bank details.")
add("MILITARY_ROMANCE_SCAM", True, "Darling I am applying for leave to come meet you but the army requires a civilian bond of 20,000 from someone in India. Can you please pay it, I will return it as soon as I land.", "Fake civilian bond payment demand from a military romance scammer to extract money before meeting.")

# ══════════════════════════════════════════════════════════════
#  HEALTH / CHARITY / DONATION SCAM
# ══════════════════════════════════════════════════════════════
add("HEALTH_SCHEME_SCAM", True, "Sir PM Jan Arogya Yojana ke tehat aapko free 5 lakh ka health insurance milega, process ke liye aapka Aadhaar, PAN aur ek OTP chahiye, main abhi link bhej raha hoon.", "Fake PM-JAY enrollment collecting Aadhaar, PAN and OTP for identity theft and insurance fraud.")
add("HEALTH_SCHEME_SCAM", True, "Hello, we are from an NGO conducting free cancer detection camp in your area, enrollment requires your Aadhaar and a 100 rupee voluntary donation for camp logistics.", "Health camp NGO scam collecting Aadhaar for identity theft plus a 'voluntary donation' for money.")
add("CHARITY_DONATION_FRAUD", True, "Main Kedarnath flood relief fund se bol raha hoon, hum victims ke liye paisa collect kar rahe hain, 500 rupaye ki donation karein is QR code se, 80G tax benefit bhi milega.", "Fake disaster relief fund collecting donations via QR code with a tax benefit lure.")
add("CHARITY_DONATION_FRAUD", True, "Hello sir, main ek cancer patient ke liye crowdfunding kar raha hoon, Ketto pe campaign hai, seedha mere personal UPI pe bhejiye faster hoga aur sab paisa patient ko milega.", "Fake cancer patient charity bypassing a legitimate crowdfunding platform to collect directly on personal UPI.")

# ══════════════════════════════════════════════════════════════
#  RATION / RURAL-TARGETED SCAM
# ══════════════════════════════════════════════════════════════
add("RATION_CARD_SCAM", True, "Main panchayat office se bol raha hoon, new ration card mein naam add karne ke liye 150 rupaye ka processing fee lagega, aaj hi dena hoga warna list close ho jayegi.", "Fake panchayat ration card name addition fee targeting rural beneficiaries with a closing deadline.")
add("RATION_CARD_SCAM", True, "Aapke ration card mein sarkari scheme ke tehat free cylinder ka benefit add ho raha hai, activate karne ke liye apna gas consumer number aur OTP jo aaya hai wo batayein.", "Fake free LPG cylinder benefit activation collecting gas consumer number + OTP.")

# ══════════════════════════════════════════════════════════════
#  EPF / PF / PENSION SCAM
# ══════════════════════════════════════════════════════════════
add("EPF_WITHDRAWAL_SCAM", True, "Sir aapka EPFO claim ek technical error ki wajah se reject ho gaya hai, re-process karne ke liye 1800 rupaye ka admin charge online pay karna hoga, link bhej raha hoon.", "Fake EPFO claim re-processing fee — EPFO never charges fees for claim corrections.")
add("EPF_WITHDRAWAL_SCAM", True, "Namaskar, EPFO helpdesk se call hai. Aapke PF mein employer ne last 6 mahine ka contribution nahi daala, isko recover karne ke liye hum court notice bhej sakte hain, pehle aap apni UAN aur password share karein.", "Fake EPFO helpdesk collecting UAN + password under a fabricated employer contribution dispute.")
add("EPF_WITHDRAWAL_SCAM", True, "Main NPS se bol raha hoon, aapki pension 60 saal ke baad start hogi lekin early exit possible hai 50,000 processing fee dekar, interested ho to bank details share karo.", "Fake NPS early exit scheme charging processing fee — NPS premature exit has no such direct fee mechanism.")

# ══════════════════════════════════════════════════════════════
#  MISCELLANEOUS NEW PATTERNS
# ══════════════════════════════════════════════════════════════
add("FAKE_CUSTOMER_CARE", True, "Aapne Google pe humara number search kiya tha Reliance Jio ke liye, main official helpdesk hoon, aapki complaint solve karne ke liye apna account password aur registered email share karein.", "Fake customer care found via Google search — a common SEO poisoning scam to harvest login credentials.")
add("FAKE_CUSTOMER_CARE", True, "Hello, this is Amazon Pay helpdesk, your cashback of 1200 rupees is stuck, to release it please install this app I'm sending and give it accessibility permission so I can manually credit it.", "Fake Amazon Pay support pushing a malicious accessibility-enabled app to take over device.")
add("HR_RECRUITER_SCAM", True, "Aapka LinkedIn profile dekha maine, hamare company ko ek data analyst chahiye, salary 18 LPA, remote, lekin ek psychometric test ka fee 999 rupaye online pay karna hoga candidate ko, refundable hai.", "Fake LinkedIn recruiter requiring candidate to pay for a refundable psychometric test — HR scam.")
add("HR_RECRUITER_SCAM", True, "Congratulations, your profile has been shortlisted for an overseas opportunity in Dubai, salary AED 8000, but medical fitness certificate from our empanelled doctor costs 3500 rupees, mandatory before visa processing.", "Fake overseas job offer requiring payment for a mandatory medical certificate before visa — job scam.")
add("INCOME_TAX_REFUND", True, "Income Tax department se call hai, aapka 18,000 ka refund pending hai ek technical issue ki wajah se, update ke liye apna bank account IFSC aur net banking password confirm karein.", "Fake IT refund requiring net banking password — IT department never asks for passwords.")
add("INCOME_TAX_REFUND", True, "Sir aapke PAN card pe ek notice generate hua hai, penalty avoid karne ke liye 5000 rupaye settle payment ke roop mein jama karein is link pe aaj hi.", "Fake income tax penalty settlement link — IT notices are sent by post/e-filing portal, not payment links.")
add("RAILWAY_IRCTC_REFUND", True, "Main IRCTC se bol raha hoon, aapki Rajdhani train cancel hui hai, 4200 ka refund stuck hai technical issue mein, mujhe aapka transaction ID aur net banking OTP share karna hoga manually process karne ke liye.", "Fake IRCTC agent manually processing train cancellation refund by collecting net banking OTP.")

# ══════════════════════════════════════════════════════════════
#  NORMAL CALLS — Very diverse, all walks of life
# ══════════════════════════════════════════════════════════════
normals = [
    ("Hi, main aapka CA hoon, ITR filing ki deadline aane wali hai, documents ready hain toh share kar dijiye email pe, main file kar dunga.", "Legitimate CA communication about tax filing deadline with no suspicious requests."),
    ("Namaste, main aapke area ki society secretary bol rahi hoon, maintenance fee ka reminder dena tha, aap convenient time pe bank transfer kar sakte hain.", "Routine housing society maintenance fee reminder with no urgency or suspicious payment method."),
    ("Hello sir, I am from the research department of a leading university, we are conducting a survey on digital literacy, would you like to participate? It takes 5 minutes and is completely voluntary.", "Legitimate academic survey call with no financial request or personal credential collection."),
    ("Yaar interview mein kya puchha, bata na, main kal jaaunga same company mein, koi special preparation chahiye kya?", "Casual conversation between friends about an upcoming job interview preparation."),
    ("Sir aapka prani doctor appointment kal subah 9 baje confirm hai apne dog ke vaccination ke liye, please thoda jaldi aa jaiye.", "Routine veterinary appointment confirmation call, entirely benign."),
    ("Beta tuition class time change ho gayi hai, ab Monday 5 baje ki jagah 6 baje hogi, aaj hi teacher ne bataya.", "Normal tuition schedule change communication from a parent or coordinator."),
    ("Hi, this is the dry cleaner, your saree and suit is ready for pickup, we are open till 9 PM today.", "Routine dry cleaning pickup notification."),
    ("Bhai loan sanction ho gaya hai tera, 5 lakh personal loan HDFC ne approve kiya hai, kal branch jaake documents sign karne hain.", "Legitimate loan approval notification from a known person, likely a bank employee friend."),
    ("Hello, main aapke naye neighbor hoon flat 304 se, bas introduce karna tha, agar koi zaroorat ho toh bata dena.", "Friendly introduction call from a new neighbor, entirely benign."),
    ("Sir aapne jo article submit kiya tha journal mein, editorial board ne review ke liye accept kiya hai, ek minor revision chahiye section 3 mein.", "Legitimate academic journal peer review acceptance communication."),
    ("Hi, I am from the alumni association, we are organizing a 10-year reunion dinner next month, interested in attending? Registration is free.", "Alumni association event invitation with no monetary request."),
    ("Mummy, train 2 ghante late hai, raat ko pahunchungi, please door mat aana station, main cab le lungi.", "Casual family travel update call, benign."),
    ("Bhaiya wo Rohini wala flat ka agreement ready hai, kyaa kal 11 baje lawyer ke paas aa sakte ho sign karne ke liye?", "Legitimate property deal completion call from a known broker or lawyer."),
    ("Hi sir, this is the school principal's office calling, your son has been selected for the state-level science olympiad, congratulations, please submit the consent form by Friday.", "Legitimate school achievement notification requiring a consent form, no fee mentioned."),
    ("Sir aapki EMI account se successfully deduct ho gayi hai, aapke loan mein 34 EMIs remaining hain, thank you for being a valued customer.", "Bank automated post-EMI deduction confirmation SMS or call — entirely routine."),
    ("Arre yaar, kab aayega Delhi? Bahut dino se mila nahi, plan bana, mere ghar rukna, mummy ne bola hai.", "Casual friend catch-up call with an invitation to visit, no financial elements."),
    ("Hi, I'm calling from the blood bank, you are a registered donor, we have an urgent requirement for B positive blood, would you be available tomorrow morning?", "Legitimate blood bank urgent donor call — entirely altruistic, no financial request."),
    ("Sir main aapka insurance advisor hoon, aapki term plan ki nominee details update karni hain, kab milunga aapko?", "Legitimate insurance advisor follow-up for nominee details update — standard service."),
    ("Bhai wo cricket match ka ticket online aa gaya hai kya? Main check kar raha tha par sold out dikha raha hai.", "Casual sports-related conversation between friends, no scam indicators."),
    ("Hello, this is from the municipal corporation, your property tax payment has been received and receipt has been sent to your registered email.", "Routine municipal property tax payment confirmation — entirely legitimate."),
]
for transcript, reasoning in normals:
    add("UNKNOWN", False, transcript, reasoning)

# ══════════════════════════════════════════════════════════════
#  WRITE TO FILE
# ══════════════════════════════════════════════════════════════
with open(out_path, "a", encoding="utf-8") as f:
    for category, is_scam, transcript, reasoning in data:
        output_obj = {"category": category, "is_scam": is_scam, "reasoning": reasoning}
        row = {
            "instruction": INSTRUCTION,
            "input": transcript,
            "output": json.dumps(output_obj, ensure_ascii=False)
        }
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

scam_count  = sum(1 for c, s, _, __ in data if s)
normal_count = sum(1 for c, s, _, __ in data if not s)
cats = sorted(set(c for c, _, __, ___ in data))
print(f"Appended {len(data)} rows  |  Scam: {scam_count}  |  Normal: {normal_count}")
print(f"Categories: {cats}")
