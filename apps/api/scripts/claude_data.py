# -*- coding: utf-8 -*-
import json
import os

INSTRUCTION = "Analyze the following phone call transcript and extract scam claims. Output JSON with 'category', 'is_scam' and 'reasoning'."

data = []

def add(category, is_scam, transcript, reasoning):
    data.append((category, is_scam, transcript, reasoning))

# ---------------- DIGITAL_ARREST (7) ----------------
add("DIGITAL_ARREST", True,
"Sir main CBI se bol raha hoon, aapka Aadhar card ek parcel ke saath Mumbai customs mein pakda gaya hai jisme narcotics mila hai. Aapko is call ko disconnect nahi karna hai, hum aapko video call pe le rahe hain digital arrest ke liye.",
"Impersonates CBI/Customs, claims illegal parcel with narcotics, forces victim to stay on video call under threat of arrest - classic digital arrest scam.")

add("DIGITAL_ARREST", True,
"This is Officer Rakesh Sharma from Mumbai Cyber Crime Cell. Your mobile number and Aadhaar are linked to a money laundering case. Do not hang up, keep your camera on, else a warrant will be issued and police will come to your house right now.",
"Fake police/cyber cell officer threatens arrest and demands victim stay on camera, a hallmark digital arrest tactic.")

add("DIGITAL_ARREST", True,
"Namaste, main FedEx courier company se bol raha hoon, aapke naam se ek parcel Iran jaa raha tha jisme 5 passport aur drugs mile hain. Ab main aapko Narcotics Control Bureau ko transfer kar raha hoon, line pe rahiyega.",
"Fake FedEx-to-NCB transfer script used to build fear before extorting money, typical FedEx digital arrest scam chain.")

add("DIGITAL_ARREST", True,
"Aap ke against Delhi mein ek FIR file hui hai sir, non-bailable warrant issue ho gaya hai. Agar aap abhi Skype pe apna statement record nahi karwate to team aapke office aa jayegi arrest karne.",
"Threatens fake FIR/non-bailable warrant and demands recorded statement over video call - pressure tactic of digital arrest fraud.")

add("DIGITAL_ARREST", True,
"Sir ye Andheri police station se call hai, aapka bank account ek terror funding case mein flag hua hai. Jab tak verification complete nahi hoti aap ye call disconnect nahi kar sakte, na hi kisi ko is baare mein bata sakte hain.",
"Instructs victim not to disconnect or tell anyone, isolating them - key manipulation tactic seen in digital arrest / terror funding scam calls.")

add("DIGITAL_ARREST", True,
"Good afternoon, I am calling from the Customs Department, Chennai. A package under your Aadhaar number contains 200 grams of MDMA. This is a serious case under NDPS Act, please stay connected while I connect you to the investigating officer.",
"Fake customs department claim about drugs in a parcel linked to Aadhaar, transferring to a fake officer - digital arrest pattern.")

add("DIGITAL_ARREST", True,
"Aapka number ek cybercrime complaint mein involve hai, hum aapse UPI se pehle 50,000 rupaye refundable security deposit lenge verification ke liye, warna hum aapko abhi arrest kar lenge is call pe hi.",
"Demands money as 'refundable deposit' under threat of immediate arrest during the call - financial extraction is the endgame of digital arrest scams.")

# ---------------- KYC_SIM_BLOCK (7) ----------------
add("KYC_SIM_BLOCK", True,
"Dear customer, your SIM card KYC has not been updated as per new TRAI guidelines, your number will be permanently disconnected within two hours. Press 9 now to speak to executive and share the O T P sent to your registered mobile.",
"Classic auto-dialer TRAI KYC scam pressuring victim into pressing a key and sharing OTP, which allows SIM-swap or fraud.")

add("KYC_SIM_BLOCK", True,
"Sir aapka Aadhar link bank account se hat gaya hai, agar aaj hi re-KYC nahi kiya to account freeze ho jayega. Mujhe apna Aadhar number aur us pe aaya hua verification code bata dijiye jaldi.",
"Requests Aadhaar number plus an OTP-like verification code under threat of account freeze - a KYC re-verification scam.")

add("KYC_SIM_BLOCK", True,
"This is from the telecom department, your PAN card has been used to issue nine SIM cards illegally in Jharkhand and one is being used for terrorist activity. To clear your name, connect to Delhi Police by pressing 1.",
"Fabricated PAN-linked illegal SIM claim used as a lead-in to a fake police transfer, common combined KYC/digital-arrest script.")

add("KYC_SIM_BLOCK", True,
"Namaskar, main Vodafone Idea customer care se bol raha hoon, aapka connection kal band ho jayega kyunki e-KYC pending hai, please apna 12 digit Aadhar number aur ATM card ka pichla hissa likha CVV bata dijiye verify karne ke liye.",
"Legitimate telecom KYC never requires ATM CVV - asking for CVV alongside Aadhaar reveals this as a scam impersonating a telecom operator.")

add("KYC_SIM_BLOCK", True,
"Sir your bank locker and account will be blocked tomorrow as your video KYC is incomplete. Kindly download this screen sharing app that I am sending on WhatsApp so our officer can complete the process remotely.",
"Requests installation of a screen-sharing app for 'remote KYC' - a technique that enables full device takeover, indicating fraud.")

add("KYC_SIM_BLOCK", True,
"Aapka number aaj raat 10 baje band kar diya jayega TRAI ke naye rule ke wajah se, kyunki aapne apna document verify nahi kiya. Turant apna bank account number aur Aadhar bata kar recharge history verify karwaiye.",
"TRAI has no authority over bank accounts; combining fake disconnection threat with a request for bank details signals scam intent.")

add("KYC_SIM_BLOCK", True,
"Good morning ma'am, this is UIDAI department calling, your Aadhaar biometric has been misused in Assam for opening a fraudulent bank account. Please confirm your Aadhaar and share the OTP to freeze the misuse immediately.",
"UIDAI does not call individuals to 'freeze misuse' via OTP; this is impersonation to extract Aadhaar-linked OTP for fraud.")

# ---------------- UPI_COLLECT_FRAUD (7) ----------------
add("UPI_COLLECT_FRAUD", True,
"Hi bhai, maine tumhara OLX pe wala sofa dekha hai, main advance bhejta hoon. Maine ek U P I collect request bheja hai, bas usko accept karke apna pin daal dena, paisa turant aa jayega.",
"Scammer sends a UPI collect request disguised as a payment and asks victim to enter PIN, which actually authorizes a debit, not a credit - classic OLX UPI fraud.")

add("UPI_COLLECT_FRAUD", True,
"Sir maine aapka product buy karna hai cash on delivery ki jagah, main abhi ek link bhejta hoon Google Pay pe, aap sirf request accept kar dena approve karke, paise seedha aa jayenge.",
"Victim is asked to 'approve' a payment request to receive money, which is a manipulation - approving a collect request sends money out, not in.")

add("UPI_COLLECT_FRAUD", True,
"Congratulations, aapko is mahine ka cashback mila hai 2500 rupaye ka apne Paytm wallet mein, bas is QR code ko scan karke apna UPI pin verify kar dijiye claim karne ke liye.",
"Scanning a QR and entering UPI PIN to 'receive' cashback actually debits money; QR scan is never required to receive funds.")

add("UPI_COLLECT_FRAUD", True,
"Bhaiya wo washing machine ka jo ad daala tha aapne Facebook Marketplace pe, main army officer hoon posted Kashmir mein, main advance payment karta hoon aapko, ek chhota sa form fill karke UPI details confirm kar dijiye.",
"Fake army-officer buyer persona plus request to 'confirm' UPI details via a form is a known marketplace advance-payment scam pattern.")

add("UPI_COLLECT_FRAUD", True,
"Namaste sir, main aapko refund bhej raha hoon jo galti se dusre account mein chala gaya tha, please ye jo notification aaya hai usko allow kar dijiye aur pin enter kar dijiye taaki refund process ho sake.",
"A 'refund' that requires entering your UPI PIN to a notification is actually a collect request draining money, not returning it.")

add("UPI_COLLECT_FRAUD", True,
"Hello, main Instagram se aapka handmade jewellery order kar raha tha, maine advance ke liye request bheji hai apki UPI ID pe, kripya accept kar dijiye jaldi mera time nikal raha hai.",
"Pressuring the seller to quickly accept an unknown 'request' is a common tactic in social-media marketplace UPI fraud.")

add("UPI_COLLECT_FRAUD", True,
"Sir aapki cycle ke liye maine 15000 rupay bhej diye hain lekin galti se ek rupay kam gaya, us collect request ko accept karke pura amount le lijiye, phir main baaki paisa alag se bhej dunga.",
"Uses confusion around a small discrepancy to convince the seller to accept a fraudulent collect request for a larger amount.")

# ---------------- FAKE_JOB_TASK (7) ----------------
add("FAKE_JOB_TASK", True,
"Hi, we are hiring for part time online work, you just need to like and subscribe YouTube videos, for every 5 videos you get 50 rupees, join our Telegram group to get task links and payment proof daily.",
"Classic Telegram 'like and earn' task scam that later asks for upfront deposits to unlock higher-paying tasks.")

add("FAKE_JOB_TASK", True,
"Sir aapka resume Naukri site se select hua hai Amazon warehouse ke liye packing job ke liye, salary 22000 fix hai, bas processing fee 499 rupaye online jama karwa dijiye documents verify hone ke baad.",
"Legitimate companies do not charge a 'processing fee' for a job offer - this is a recruitment fraud pattern.")

add("FAKE_JOB_TASK", True,
"Welcome to our task group, aaj ka task hai kisi hotel ko 5 star rating dena app mein, iske liye pehle aapko 1000 rupaye recharge karna hoga jisse aapka wallet activate ho aur commission milna shuru ho.",
"Requires upfront 'recharge' before any earning, a hallmark of the hotel/product rating task investment scam run via Telegram.")

add("FAKE_JOB_TASK", True,
"Ma'am I am HR from an MNC, we are recruiting data entry operators for work from home, no interview needed, just pay a refundable security amount of 999 for the laptop software license we provide.",
"Genuine data-entry roles rarely skip interviews and never charge for 'software license' as a refundable deposit - typical WFH job scam.")

add("FAKE_JOB_TASK", True,
"Bhai maine dekha tune apna number Instagram pe daala tha job ke liye, humare paas ek simple task hai crypto app pe recharge karke usko complete karna hai, first task free hai baad mein tera paisa double hoke aayega.",
"Combines fake job framing with a crypto-recharge task; promising doubled returns after a 'free' first task is a lure into a Ponzi-style task scam.")

add("FAKE_JOB_TASK", True,
"Congratulations, you have been shortlisted for a Google certified digital marketing internship, kindly pay 1500 rupees registration fee within one hour to confirm your seat as slots are limited.",
"Urgency plus an upfront 'registration fee' for an internship is a red flag typical of fake internship/job scams.")

add("FAKE_JOB_TASK", True,
"Hello sir, aap online rating jobs ke liye eligible hain, roz ke 3000 se 5000 kama sakte hain sirf apps download karke review dene se, sabse pehle apna wallet 2000 rupaye se load kariye taaki commission credit ho sake.",
"Promises unrealistic daily income and demands upfront wallet loading, a well-known task-based investment/job fraud script.")

# ---------------- INVESTMENT_FRAUD (6) ----------------
add("INVESTMENT_FRAUD", True,
"Sir hamara SEBI registered analyst team hai, humne pichle mahine members ko 40 percent return diya hai stock tips se, aap sirf 10,000 rupaye leke humare premium Telegram group join kar lijiye, guaranteed profit hai.",
"Falsely claims SEBI registration and guarantees fixed high returns, both classic red flags of stock-tip investment fraud.")

add("INVESTMENT_FRAUD", True,
"Bhai crypto mein ek naya coin launch ho raha hai, abhi invest karoge to 3 din mein paisa triple ho jayega, main khud apna sara paisa laga chuka hoon, tum bhi is wallet address pe bhej do.",
"Promises tripling of money in days via an unverified crypto coin, an unrealistic-return investment scam pattern.")

add("INVESTMENT_FRAUD", True,
"Good evening sir, this is from a leading trading firm, we provide intraday tips with 90 percent accuracy, join our VIP plan for 25000 rupees and we guarantee minimum 5000 profit daily.",
"Guaranteeing daily fixed profits from intraday trading is not possible in real markets and is a hallmark of trading tip fraud.")

add("INVESTMENT_FRAUD", True,
"Maine apni FD tudwa ke jo app mein invest kiya tha wahan se 3 lakh nikal liye hain ek hafte mein, tum bhi try karo yaar, mera senior tumhe personally guide karega bas ek chhota account activation charge lagega.",
"Uses a testimonial-style pitch plus an 'activation charge' to lure victims into a fake investment app, a common referral-based investment scam.")

add("INVESTMENT_FRAUD", True,
"Namaste, aap humari IPO allotment scheme ke liye eligible hain, guaranteed listing gain milega, bas is link pe apna demat detail aur ek chhota processing amount daal dijiye slot confirm karne ke liye.",
"No legitimate IPO allotment requires an upfront 'processing amount' outside official broker channels - indicates fraud.")

add("INVESTMENT_FRAUD", True,
"Hello sir main aapko ek forex trading group mein add kar raha hoon jahan expert log signal dete hain, pehle hafte mein hi log double paisa nikal rahe hain, aap bhi 5000 se start kar sakte hain.",
"Forex 'signal groups' promising doubling of capital in a week are a widely reported investment scam format.")

# ---------------- FAMILY_EMERGENCY (6) ----------------
add("FAMILY_EMERGENCY", True,
"Mumma please help me, mera accident ho gaya hai highway pe, police mujhe pakad ke le ja rahi hai, doctor bol raha hai turant paise nahi diye to operation nahi hoga, please 40,000 bhej do is number pe.",
"Uses distress and urgency, likely AI voice-cloned or impersonated child's voice, demanding immediate money transfer without verification.")

add("FAMILY_EMERGENCY", True,
"Sir this is Apollo Hospital calling, your son had a bike accident and he is unconscious, we need an advance of 25000 rupees right now before we can start emergency surgery, please transfer to this UPI immediately.",
"Hospitals in genuine emergencies do not ask for UPI transfer over a cold call before treatment - classic hospital emergency scam.")

add("FAMILY_EMERGENCY", True,
"Papa main jail mein hoon, maine galti se ek accident kar diya, police wale case wapas lene ke liye 15000 maang rahe hain abhi ke abhi, please kisi ko mat batana bas paisa bhej do.",
"Instructing secrecy from other family members combined with urgent bail-money demand is a hallmark of the fake arrest/accident scam.")

add("FAMILY_EMERGENCY", True,
"Beta, tumhari behen ka accident ho gaya hai aur wo ICU mein hai, mujhe abhi paise nahi mil rahe, tum turant 20000 bhej do is number pe warna unko admit nahi karenge.",
"Fabricated family medical emergency demanding instant money transfer to an unfamiliar number is a common voice-based emergency scam.")

add("FAMILY_EMERGENCY", True,
"Hi dad it's me, I lost my phone that's why calling from a friend's number, I'm stuck at the toll and need 5000 rupees urgently transferred to this UPI, I'll explain everything later.",
"Caller avoids verification by citing a 'lost phone' and demands urgent small payment, a technique used in AI-voice-clone family scams.")

add("FAMILY_EMERGENCY", True,
"Nani main bahut mushkil mein hoon, mera purse cheen liya kisi ne station pe, ticket ke paise bhi nahi hain ghar aane ke, please turant kuch paisa bhej do isi number ke UPI pe.",
"Emotional urgency and request to send money to an unfamiliar UPI without verifying identity indicates a family-emergency scam.")

# ---------------- SEXTORTION (5) ----------------
add("SEXTORTION", True,
"Hi, main tumhara video call record kar chuka hoon jisme tum nude the, agar tumne mujhe abhi 20,000 rupaye nahi bheje to main ye video tumhare saare contacts aur Facebook friends ko bhej dunga.",
"Threatens to distribute a recorded compromising video to contacts unless money is paid - a direct sextortion/blackmail scam.")

add("SEXTORTION", True,
"Sir I have your intimate video from yesterday's call, screenshots bhi hain, share karne se pehle 15000 bhej do warna tumhare office group mein bhi bhej dunga isko.",
"Explicit blackmail threatening to share intimate content with the victim's workplace unless paid - classic sextortion.")

add("SEXTORTION", True,
"Tumne mujhe video call pe jo dekha tha wo maine record kar liya hai, ab agar meri baat nahi maani to tumhari maa ke number pe bhi bhej dunga ye video, socho izzat ka kya hoga.",
"Explicitly threatens to send recorded content to a family member to coerce compliance - a manipulative sextortion tactic.")

add("SEXTORTION", True,
"Hello, this is a courtesy call before I upload our video call recording online, you have one hour to send 500 dollars in crypto or it goes live on adult sites with your name tagged.",
"Demands crypto payment under threat of publishing recorded content publicly - textbook sextortion demand with a countdown to pressure the victim.")

add("SEXTORTION", True,
"Bhai tere jaise professional log ki naukri chali jayegi agar ye video LinkedIn pe chala gaya, isliye chup chap 10000 bhej de, warna consequences bahut bura hoga tere liye.",
"Threatens career damage via a compromising video to extort money, a targeted sextortion approach aimed at professionals.")

# ---------------- ELECTRICITY_THREAT (6) ----------------
add("ELECTRICITY_THREAT", True,
"Dear consumer, your electricity bill has not been updated in our new server, your power supply will be disconnected tonight at 9:30 PM, to avoid this press 1 to speak to our billing executive immediately.",
"Automated urgent disconnection threat pushing victim to press a key and connect to a fraudster posing as a billing executive - typical BESCOM/MSEB scam.")

add("ELECTRICITY_THREAT", True,
"Sir aapka last month ka bill pending dikha raha hai humare system mein, aaj raat tak jama nahi kiya to connection kaat diya jayega, please turant is number pe UPI se 1450 rupaye bhej dijiye.",
"Legitimate electricity boards do not collect dues via a random personal UPI number - a strong scam indicator combined with disconnection threat.")

add("ELECTRICITY_THREAT", True,
"This is MSEB department, aapke meter mein tampering detect hui hai, agar aap abhi fine 2000 rupaye online nahi bharte to hum FIR file karke aapka connection permanently disconnect kar denge.",
"Uses fabricated 'meter tampering' allegation and threatens FIR to pressure an immediate online fine payment - electricity scam pattern.")

add("ELECTRICITY_THREAT", True,
"Namaste sir, aapke ghar ka smart meter update nahi hua hai isliye kal se bijli band ho jayegi, please humein apna consumer number aur registered mobile ka OTP bata dijiye update ke liye.",
"Requesting an OTP for a 'smart meter update' is unnecessary for genuine electricity boards and indicates credential theft attempt.")

add("ELECTRICITY_THREAT", True,
"Sir bijli office se bol rahe hain, aapne KYC nahi karwaya connection ka, isliye 2 ghante mein supply cut ho jayegi, humari app download kariye aur remote access dijiye taaki hum aapka bill correct kar sakein.",
"Requesting remote access app installation for a billing 'correction' is a technique to hijack the victim's device, not standard utility practice.")

add("ELECTRICITY_THREAT", True,
"Good evening, this is from the electricity board control room, your area has unpaid dues from six months, to prevent disconnection at midnight, transfer 3200 rupees now to this Paytm number I am sending.",
"Directing bill payment to a personal Paytm number under threat of midnight disconnection is a fraudulent electricity bill scam.")

# ---------------- PRIZE_LOTTERY (6) ----------------
add("PRIZE_LOTTERY", True,
"Congratulations sir, aapka number KBC lucky draw mein select hua hai 25 lakh rupaye ka, prize claim karne ke liye pehle 5000 rupaye processing fee GST ke roop mein jama karni hogi.",
"Fake KBC lottery win requiring an upfront 'processing fee' before releasing a prize is one of the most common lottery scams in India.")

add("PRIZE_LOTTERY", True,
"Hello ma'am, aapko Amazon ke anniversary sale mein ek iPhone 15 jeet gaya hai lucky draw mein, bas delivery charge ke 999 rupaye is link pe pay kar dijiye taaki hum aapko courier bhej sakein.",
"Legitimate giveaways never ask winners to pay a 'delivery charge' upfront - a classic prize scam mechanism.")

add("PRIZE_LOTTERY", True,
"Sir apka number humari company ki 10th anniversary lucky draw mein aaya hai, aapne 12 lakh rupaye aur ek car jeeti hai, is amount ko release karwane ke liye pehle income tax clearance fee bharni hogi.",
"Demanding a fake 'income tax clearance fee' before releasing prize money is a well-documented lottery/prize fraud tactic.")

add("PRIZE_LOTTERY", True,
"Namaste, main KBC head office Mumbai se bol raha hoon, aapka WhatsApp number lottery mein select hua hai 35 lakh rupaye ka, kripya apna bank account number aur Aadhar bhej dijiye verification ke liye.",
"Fabricated claim of representing KBC head office and requesting bank/Aadhaar details for a 'lottery' is a phishing-driven prize scam.")

add("PRIZE_LOTTERY", True,
"Sir aapko diwali dhamaka offer mein gold coin jeeta hai humari company ki taraf se, bas iske liye aapko ek chhota registration form bharna hoga aur 500 rupaye ka token amount dena hoga.",
"Requesting a 'token amount' for an unsolicited festival prize win is a standard lottery scam pattern targeting seasonal excitement.")

add("PRIZE_LOTTERY", True,
"Hello sir, this is from an international lucky draw organized by a UK based company, you have won 50,000 dollars, to transfer the amount to India we need you to pay currency conversion charges first.",
"Requiring upfront 'currency conversion charges' for a foreign lottery prize is a long-running advance-fee lottery fraud scheme.")

# ---------------- TECH_SUPPORT (6) ----------------
add("TECH_SUPPORT", True,
"Sir this is Microsoft technical support, we have detected a virus on your computer sending your bank details to hackers, please download AnyDesk right now so our engineer can clean your system remotely.",
"Microsoft does not proactively call users about viruses; requesting AnyDesk install for remote 'cleaning' is a classic tech support scam to gain device control.")

add("TECH_SUPPORT", True,
"Namaste, aapke laptop se ek suspicious activity report aaya hai humare server pe, hum aapko TeamViewer install karwa denge taaki hum dekh sakein kya problem hai, isse aapka data safe rahega.",
"Unsolicited claim of detecting laptop issues followed by a TeamViewer install request is a common remote-access tech support scam.")

add("TECH_SUPPORT", True,
"Sir your bank account is linked to your computer and it shows signs of hacking, install this remote access app immediately and share the code shown on screen so we can secure your net banking.",
"Sharing a remote access session code with an unsolicited caller who claims to 'secure net banking' is a well-known device takeover scam.")

add("TECH_SUPPORT", True,
"Hello, main Amazon technical department se bol raha hoon, aapke account se ek unauthorized 35000 rupaye ka order place hua hai, cancel karne ke liye humein AnyDesk se apka screen dekhna hoga.",
"Fake unauthorized order claim used as a pretext to request remote screen access - designed to eventually steal banking credentials.")

add("TECH_SUPPORT", True,
"Sir aapke antivirus ki subscription expire ho gayi hai aur system compromise ho gaya hai, refund process karne ke liye pehle apna net banking open kariye aur humein screen share kar dijiye.",
"Combining a fake expired subscription with a request to open net banking during a screen share is designed to steal login credentials.")

add("TECH_SUPPORT", True,
"This is Norton support calling, we found malware trying to access your card details, to fix this for free just install our remote tool and provide the OTP that will come for verification purpose.",
"No legitimate antivirus support requires an OTP for 'verification' during a remote fix - this OTP is used to authorize fraudulent transactions.")

# ---------------- LOAN_HARASSMENT (6) ----------------
add("LOAN_HARASSMENT", True,
"Tumne jo loan liya tha app se wo default ho gaya hai, agar aaj tak paisa nahi diya to hum tumhari saari contact list ko morphed photo bhej denge aur tumhare office mein bhi phone karenge.",
"Threatens to send morphed photos to contacts and harass workplace over a loan default - a well-documented instant loan app harassment tactic.")

add("LOAN_HARASSMENT", True,
"Sir aapne jo instant loan app se paisa liya tha uska interest bahut badh gaya hai, ab aapko 24 ghante mein double amount dena hoga warna hum aapke family members ko call karke badnaam kar denge.",
"Threatens to contact and defame family members to coerce inflated repayment - characteristic of predatory loan app harassment.")

add("LOAN_HARASSMENT", True,
"You took a 5000 rupee loan from our app last month, now with penalty it has become 45000, pay immediately or we will leak your Aadhaar photo and personal data to everyone in your phone contacts.",
"Disproportionate penalty escalation combined with threats to leak personal data to contacts is typical of illegal loan app recovery harassment.")

add("LOAN_HARASSMENT", True,
"Madam aapka loan account bahut overdue hai, humare paas aapki gallery ka access hai jab aapne app install kiya tha permissions diye the, agar paisa nahi diya to sab kuch WhatsApp pe daal denge.",
"Claims access to victim's gallery via app permissions and threatens to distribute private photos - a severe form of loan app extortion.")

add("LOAN_HARASSMENT", True,
"Aapne jo 2000 rupaye ka quick loan liya tha wo ab 20000 ho gaya hai charges ke saath, kal tak nahi diya to hum aapke ghar ke bahar recovery agent bhej denge aur society mein poster laga denge.",
"Threatening to send recovery agents and publicly shame the victim in their society over a small inflated loan is an illegal harassment tactic.")

add("LOAN_HARASSMENT", True,
"Sir this is from the loan recovery department, your EMI has bounced, if not paid within 3 hours we will file a criminal case against you and inform your employer about your bad credit history.",
"Threatening a fabricated criminal case and unauthorized disclosure to an employer over a bounced EMI is a coercive loan harassment tactic.")

# ---------------- UNKNOWN / NORMAL (31) ----------------
add("UNKNOWN", False,
"Hi sir, your Swiggy order of butter chicken and naan is out for delivery, I am five minutes away, could you please share the OTP shown on your app so I can confirm the drop-off?",
"Routine food delivery confirmation using a delivery-app OTP for order verification, consistent with normal Swiggy delivery process.")

add("UNKNOWN", False,
"Bhai kal office meeting hai 11 baje, project ka status update dena hai, tu apna slide ready rakhna, main bhi apna part bhej dunga tujhe raat tak.",
"Ordinary workplace coordination between colleagues about a scheduled meeting and presentation preparation.")

add("UNKNOWN", False,
"Namaste sir, main Ola cab driver bol raha hoon, aapki pickup location pe pahunch gaya hoon, white color car hai, please bahar aa jaiye.",
"Standard cab driver call informing the passenger of arrival for pickup, a routine transportation interaction.")

add("UNKNOWN", False,
"Mumma, main aaj thoda late aaunga, traffic bahut hai, aap khana mat rukna mere liye, main aake kha lunga.",
"Casual family conversation about being late home due to traffic, no scam indicators present.")

add("UNKNOWN", False,
"Hello, yeh Zomato se call hai, aapka parcel deliver ho gaya hai gate pe, kripya check kar lijiye aur agar koi issue ho to app pe report kar dijiye.",
"Routine delivery confirmation call from a food delivery service with no financial or credential requests.")

add("UNKNOWN", False,
"Arre yaar weekend pe movie chalte hain kya, naya Bollywood wala aaya hai, tickets book kar loon kya BookMyShow pe?",
"Casual friendly conversation planning a weekend movie outing between friends.")

add("UNKNOWN", False,
"Good morning sir, this is Rina from HR, just confirming your interview slot tomorrow at 3 PM for the marketing executive role, please carry your original documents for verification.",
"Genuine HR communication confirming an interview appointment, with no fee or urgent payment demand.")

add("UNKNOWN", False,
"Beta school se bol rahe hain, kal parents teacher meeting hai subah 9 baje, kripya dono parents mein se koi ek aa jaye.",
"Routine school communication about a scheduled parent-teacher meeting.")

add("UNKNOWN", False,
"Hi, I'm calling from Urban Company, your AC service technician will arrive between 2 and 4 PM today as per your booking, please keep the unit accessible.",
"Standard home-service appointment confirmation call with no suspicious requests.")

add("UNKNOWN", False,
"Yaar tu bata raha tha na naya phone lena hai, chal is weekend saath chalte hain market, mujhe bhi ek case lena hai apne phone ke liye.",
"Casual banter between friends about shopping plans, entirely benign.")

add("UNKNOWN", False,
"Sir aapka LIC premium due date agle hafte hai, aap chahe to humari branch aake ya net banking se pay kar sakte hain, koi urgency nahi hai bas reminder tha.",
"Genuine, low-pressure insurance premium reminder from an agent without threats or urgent payment demands.")

add("UNKNOWN", False,
"Hello didi, gas cylinder book ho gaya hai, delivery agle do din mein ho jayegi, agar koi change chahiye to booking app pe update kar sakti hain.",
"Routine LPG cylinder booking confirmation call, a normal utility service interaction.")

add("UNKNOWN", False,
"Bro maine tujhe wo assignment ka doc bhej diya hai mail pe, dekh lena aur apna part add kar dena kal submission se pehle.",
"Everyday academic collaboration between classmates about an assignment submission.")

add("UNKNOWN", False,
"Good afternoon sir, this is Priya from the bank, I just wanted to inform you that your fixed deposit is maturing next month, would you like to renew it or should we process a payout to your savings account?",
"A bank relationship manager discussing an FD maturity option is a routine, non-urgent, legitimate customer service call.")

add("UNKNOWN", False,
"Aunty namaste, main plumber bol raha hoon, kal subah 10 baje aa jaunga tap fix karne, please ghar pe koi rahe.",
"Ordinary scheduling call from a plumber for a home repair appointment.")

add("UNKNOWN", False,
"Hey, are we still on for the badminton match this evening at 6? I've booked the court already, just bring your racket.",
"Casual friendly conversation confirming a recreational sports plan, no scam elements.")

add("UNKNOWN", False,
"Sir aapki car service ho gayi hai, aap sham tak aake le ja sakte hain showroom se, bill counter pe ready rahega.",
"Routine vehicle service completion notification from a service center.")

add("UNKNOWN", False,
"Beta tumhari dadi poochh rahi thi tum kab aa rahe ho ghar, unko bahut yaad aa rahi hai tumhari, ek baar phone kar lena unse.",
"Warm, ordinary family conversation with no financial or urgent request involved.")

add("UNKNOWN", False,
"Hi, this is from the salon, just confirming your appointment for a haircut and facial tomorrow at 5 PM, please arrive 10 minutes early.",
"Standard beauty salon appointment confirmation call.")

add("UNKNOWN", False,
"Sir maine aapko jo flat dikhaya tha Sunday ko, uska owner ready hai negotiate karne ke liye, aap kab free hain milne ke liye baat karne?",
"Genuine real estate agent follow-up about property viewing and negotiation, a normal business interaction.")

add("UNKNOWN", False,
"Yaar cricket match dekhne chalen kya stadium, mere paas do extra tickets hain, tu aur Rohit aa jao Saturday ko.",
"Casual social invitation between friends to attend a cricket match.")

add("UNKNOWN", False,
"Good evening, this is the pediatric clinic, just reminding you that your child's vaccination appointment is scheduled for tomorrow at 11 AM, please carry the vaccination card.",
"Routine medical appointment reminder from a clinic, entirely benign.")

add("UNKNOWN", False,
"Bhai maine tera diya hua laptop charger office mein hi chhod diya galti se, kal le aaunga tere liye, sorry yaar.",
"Everyday casual conversation about a forgotten item between colleagues or friends.")

add("UNKNOWN", False,
"Namaste sir, aapka newspaper subscription renew karna hai agle mahine se, please bata dijiye kaunsa plan continue karna hai aapko.",
"Routine newspaper subscription renewal inquiry, a normal customer service interaction.")

add("UNKNOWN", False,
"Hi, we're the caterers for your event next weekend, just calling to finalize the menu, would you like to add one more starter to the list?",
"Standard event-planning coordination call from a catering vendor, with no scam indicators.")

add("UNKNOWN", False,
"Beta office se nikal raha hoon, thoda traffic hai, tum log khana shuru kar do, main pahunch ke kha lunga.",
"Casual family update about being on the way home, an everyday conversation.")

add("UNKNOWN", False,
"Sir this is the gym reception, just letting you know your membership expires in three days, you can renew at the front desk anytime this week.",
"Genuine gym membership renewal reminder with no urgency-based coercion or payment link.")

add("UNKNOWN", False,
"Arre yaar tera birthday agle hafte hai na, plan kya hai, ghar pe party rakhein ya bahar chalein sab log?",
"Friendly casual conversation about planning a birthday celebration.")

add("UNKNOWN", False,
"Namaste ma'am, main society ka watchman bol raha hoon, aapka courier aaya hai gate pe, koi le jayega ya main upar bhej doon?",
"Routine building security call about a courier delivery, an ordinary residential interaction.")

add("UNKNOWN", False,
"Hi, this is your child's school van driver, we're running about ten minutes late today due to traffic near the signal, just wanted to inform you in advance.",
"Standard, benign notification from a school van service about a minor delay.")

add("UNKNOWN", False,
"Sir aapne jo washing machine order ki thi wo kal deliver ho jayegi, installation team bhi saath mein aayegi set up karne ke liye, koi specific time chahiye kya?",
"Routine appliance delivery and installation scheduling call from a retailer, with no financial red flags.")

# --------- Write JSONL ---------
# Changed output path to append to existing dataset.jsonl
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(SCRIPT_DIR, "..", "ai_training", "dataset.jsonl")

# Use append mode "a" so we don't overwrite the 1425 rows!
with open(out_path, "a", encoding="utf-8") as f:
    for category, is_scam, transcript, reasoning in data:
        output_obj = {"category": category, "is_scam": is_scam, "reasoning": reasoning}
        row = {
            "instruction": INSTRUCTION,
            "input": transcript,
            "output": json.dumps(output_obj, ensure_ascii=False)
        }
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

print(f"Appended {len(data)} highly-detailed Claude examples to dataset.jsonl")
