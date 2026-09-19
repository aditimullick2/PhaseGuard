# -*- coding: utf-8 -*-
"""
Extra scam categories not yet in the dataset:
- MATRIMONIAL_FRAUD
- GOVT_SCHEME_IMPERSONATION
- INSURANCE_FRAUD
- COURIER_REDELIVERY
- ECOMMERCE_REFUND_SCAM
- SHARE_MARKET_IPO
- PROPERTY_ADVANCE_FRAUD
- AADHAAR_UPDATE_SCAM
- VISHING_BANK_OTP
- TOURIST_TRAVEL_SCAM
- SOCIAL_MEDIA_IMPERSONATION
- CHARITY_DONATION_FRAUD
- HEALTH_SCHEME_SCAM
- MILITARY_ROMANCE_SCAM
- RATION_CARD_SCAM
"""
import json
import os

INSTRUCTION = "Analyze the following phone call transcript and extract scam claims. Output JSON with 'category', 'is_scam' and 'reasoning'."

data = []

def add(category, is_scam, transcript, reasoning):
    data.append((category, is_scam, transcript, reasoning))

# -------- MATRIMONIAL_FRAUD (5) --------
add("MATRIMONIAL_FRAUD", True,
"Hello, I am Dr. Anand from London, I saw your profile on Shaadi.com and I am very interested. I have sent you a gift parcel with gold jewellery and an iPhone but it is stuck at Delhi customs. Please pay 28,000 as customs duty to release it.",
"Fake NRI doctor romance scam via matrimony site leads to fake parcel at customs demanding duty payment - a standard matrimonial fraud pattern.")

add("MATRIMONIAL_FRAUD", True,
"Hi, mujhe tumse shaadi karni hai, main Dubai mein engineer hoon, ab main India aa raha hoon lekin mera wallet aur passport chori ho gaya, please mujhe 15,000 rupaye airport pe bhej do main wapas kar dunga.",
"Classic overseas romance scam where scammer fabricates a travel emergency to extract money before meeting in person.")

add("MATRIMONIAL_FRAUD", True,
"Namaste, main army colonel hoon Siachen mein posted, humari baat ho rahi hai pichle ek mahine se, main serious hoon tumse, please meri beti ki operation ke liye thodi madad karo, 30,000 bhej do, main aate hi wapas karunga.",
"Impersonates a military officer to gain trust via long-term emotional grooming, then invents a medical emergency to extract money.")

add("MATRIMONIAL_FRAUD", True,
"Main Canada mein settled hoon, tumse shaadi karna chahta hoon, mere rishtedar chahte hain ki pehle hum ek traditional ceremony kare, bas unhe 10,000 rupaye bhej do gift ke taur par, hum baad mein settle kar lenge.",
"Romance scammer impersonating a Canada-based NRI requests a 'ceremony gift' payment to family as a trust-building but money-extracting move.")

add("MATRIMONIAL_FRAUD", True,
"Sweetheart I am stuck at Mumbai airport immigration, they are asking for bond money of 50,000 rupees or they won't let me into India, please transfer immediately I will pay you back as soon as I come out.",
"Airport immigration bond money demand from an online romance partner is a textbook advance-fee matrimonial scam tactic.")

# -------- GOVT_SCHEME_IMPERSONATION (5) --------
add("GOVT_SCHEME_IMPERSONATION", True,
"Namaskar, main PM Awas Yojana ke office se bol raha hoon, aapka naam waiting list mein aaya hai, free mein ghar milega, bas processing fee 2500 rupaye bhejiye registration confirm karne ke liye.",
"No government housing scheme charges a 'processing fee' via phone - this is a well-known PM Awas Yojana impersonation scam.")

add("GOVT_SCHEME_IMPERSONATION", True,
"Sir aapko sarkar ki taraf se 1 lakh ka kisan credit loan milega zero interest pe, simply apna Aadhaar aur bank account number bata dijiye aur 500 rupaye ka registration charge pay karein abhi.",
"Fake government agricultural loan scheme demanding Aadhaar plus bank details and an upfront charge is a rural phishing scam.")

add("GOVT_SCHEME_IMPERSONATION", True,
"Aapne Ayushman Bharat card ke liye apply kiya tha, card ready hai, courier karne ke liye 200 rupaye ka charge online pay kariye, link bhej raha hoon abhi WhatsApp pe.",
"Ayushman Bharat cards are issued free; demanding a courier charge and sending a WhatsApp link signals a phishing attempt.")

add("GOVT_SCHEME_IMPERSONATION", True,
"Hello sir, government ne COVID relief fund ke 5000 rupaye aapke liye approve kiye hain, claim karne ke liye apna bank account number aur IFSC code share kariye aur ek OTP bhi aayega confirm karna hoga.",
"Fake government COVID relief fund claims requesting bank details and OTP are credential harvesting scams targeting pandemic-relief expectations.")

add("GOVT_SCHEME_IMPERSONATION", True,
"Main labour ministry se bol raha hoon, EPFO ne apke PF account mein 3500 bonus credit kiya hai, lene ke liye apna UPI PIN ek notification mein aayega usse approve kar dijiye.",
"EPFO never asks you to approve a UPI notification to receive a bonus; this is a UPI collect fraud disguised as a government scheme.")

# -------- INSURANCE_FRAUD (4) --------
add("INSURANCE_FRAUD", True,
"Sir aapki LIC policy ka bonus mature ho gaya hai, 85,000 rupaye release karne ke liye pehle 3500 rupaye ka GST aur service charge pay karna hoga, phir seedha account mein aa jayega.",
"Legitimate LIC bonus payments are never contingent on upfront GST or service charges - a standard insurance surrender/bonus scam.")

add("INSURANCE_FRAUD", True,
"Namaste, main Star Health insurance se bol raha hoon, aapki policy renew nahi hui isliye ek Rs 499 ka penalty lag gaya hai, pay karne ke liye ye link open karke apna card number daal dijiye.",
"Fake penalty demand for a health insurance policy non-renewal sent via a link requesting card details - a phishing/insurance scam.")

add("INSURANCE_FRAUD", True,
"Sir aapne jo policy li thi uski terms mein ek additional rider available hai jo free mein add kar sakte hain, bas apna policy number aur OTP jo abhi SMS pe aaya hai wo bata do.",
"Requests OTP from an SMS under the guise of adding a 'free policy rider'; the OTP is used to alter or surrender the policy fraudulently.")

add("INSURANCE_FRAUD", True,
"Hello ma'am, aapka mediclaim claim 70,000 ka approve ho gaya hai, release karne ke liye pehle documentation fee 2000 rupaye online bhejiye, baaki refund ho jayegi sab.",
"Demanding a 'documentation fee' before releasing an approved insurance claim is a fraudulent claim settlement scam.")

# -------- COURIER_REDELIVERY (3) --------
add("COURIER_REDELIVERY", True,
"Your Amazon delivery could not be completed today, to reschedule please click the link sent via SMS and pay a 49 rupee redelivery fee using your card details to confirm the slot.",
"Amazon and Delhivery never charge redelivery fees via SMS links; requesting card details for a redelivery is a phishing courier scam.")

add("COURIER_REDELIVERY", True,
"Sir aapka parcel kal deliver nahi ho saka, iske liye ek chhoti si amount 29 rupaye deni hogi new delivery window book karne ke liye, link pe click karke card se pay kar dijiye.",
"A small redelivery charge demanded via a link is a classic smishing/vishing courier scam designed to harvest payment card data.")

add("COURIER_REDELIVERY", True,
"Aapka international parcel customs mein ruka hua hai, import duty 3200 rupaye online pay karein is link pe, nahi toh parcel wapas bhej diya jayega sender ko.",
"Fabricated customs duty demand for an unexpected international parcel via a payment link - a well-documented parcel interception scam.")

# -------- ECOMMERCE_REFUND_SCAM (4) --------
add("ECOMMERCE_REFUND_SCAM", True,
"Main Flipkart customer care se bol raha hoon, aapne jo return request daala tha uska refund process karne ke liye mujhe apka debit card number aur OTP chahiye verification ke liye.",
"Refund processing never requires card number or OTP from the customer; this is a fake Flipkart support phishing call.")

add("ECOMMERCE_REFUND_SCAM", True,
"Hello sir, Meesho se bol raha hoon, aapka order cancel ho gaya, refund 2-3 din mein aayega lekin ek verification step ke liye ye link click karke apna UPI PIN enter karein.",
"Entering a UPI PIN on a link for a refund is a debit action, not a credit - a classic refund fraud tactic using fake e-commerce support.")

add("ECOMMERCE_REFUND_SCAM", True,
"Ma'am your Myntra order was returned but refund stuck, to initiate manually please share your net banking login ID so we can directly credit to your account from our payment gateway.",
"No e-commerce company asks for net banking login credentials to process a refund; this is account takeover via fake customer support.")

add("ECOMMERCE_REFUND_SCAM", True,
"Sir Amazon pe aapne jo order kiya tha wo defective nikla, hum turant 1500 rupaye refund bhej rahe hain, bas apna GPay number aur ek collect request accept kar lo jo abhi aa rahi hai.",
"Refund delivered via a UPI collect request that the victim must 'accept' is a reversed payment fraud - accepting debits money, not credits.")

# -------- PROPERTY_ADVANCE_FRAUD (3) --------
add("PROPERTY_ADVANCE_FRAUD", True,
"Sir ye flat bilkul sahi hai aapke liye, rate bhi bahut accha hai, lekin aaj hi token advance 50,000 rupaye online dena hoga, kal rate badh jayega aur koi aur le jayega, immediately bhejiye.",
"Artificial urgency around a property deal demanding immediate token money transfer online is a hallmark of property advance fraud.")

add("PROPERTY_ADVANCE_FRAUD", True,
"Main property dealer hoon, ek plot hai Noida mein 5 lakh mein, owner bahar hain, aap pehle 30,000 advance bhej do confirm karne ke liye, documents baad mein milenge jab wo aayenge.",
"Requesting advance payment for a property without meeting the owner or verifying documents is a property booking fraud pattern.")

add("PROPERTY_ADVANCE_FRAUD", True,
"Aapka ghar jo kiraye pe diya hai uska agreement renew karna hai, pehle ek mahine ka rent advance is account mein bhejiye, landlord baad mein aapko receipt denge.",
"Fake landlord or property manager collecting advance rent to an unverified account before documentation is a rental advance scam.")

# -------- VISHING_BANK_OTP (4) --------
add("VISHING_BANK_OTP", True,
"Main ICICI bank RBI helpline se bol raha hoon, aapke account pe suspicious login attempt hua hai, account secure karne ke liye aapke phone pe ek OTP aayega, wo mujhe batayein.",
"RBI and banks never ask for OTPs over phone; sharing an OTP to 'secure' an account gives the fraudster full transaction authorization.")

add("VISHING_BANK_OTP", True,
"Sir aapka SBI debit card block hone wala hai, hum ise 5 minute mein unblock kar denge, bas apna 16 digit card number, expiry date aur CVV confirm kar dijiye humse.",
"Sharing complete card details (number, expiry, CVV) to an unsolicited caller enables card-not-present fraud - never do this for any bank.")

add("VISHING_BANK_OTP", True,
"Aapke account se ek 35,000 ka unauthorized transaction hua hai, hum usse reverse karenge, ek OTP aayega please share karein taaki hum amount wapas kar sakein.",
"An OTP shared to 'reverse' a transaction actually authorizes a new fraudulent transfer - a reversal scam using bank impersonation.")

add("VISHING_BANK_OTP", True,
"Hello, this is your bank's fraud prevention team, we detected unusual activity on your account, to verify it's you please confirm your internet banking password and the OTP we just sent.",
"No bank's fraud prevention team asks for your internet banking password - this is a credential harvesting vishing call.")

# -------- TOURIST_TRAVEL_SCAM (3) --------
add("TOURIST_TRAVEL_SCAM", True,
"Sir aapka Shimla holiday package 40 percent off mein available hai sirf aaj ke liye, advance 5000 rupaye abhi pay kariye link pe, seat confirm ho jayegi aur baaki hotel pe collect ho jayega.",
"Time-limited discount travel package demanding immediate online advance with no verifiable operator details is a classic travel booking scam.")

add("TOURIST_TRAVEL_SCAM", True,
"Main MakeMyTrip se bol raha hoon, aapki Goa flight cancel ho gayi hai, full refund ke liye apna booking ID aur card last 4 digits bata dijiye verification ke liye.",
"Fake travel portal cancellation call requesting booking and card details is a phishing attempt exploiting travel anxiety.")

add("TOURIST_TRAVEL_SCAM", True,
"Congratulations, aapne hamari travel quiz mein ek free Dubai trip jeeti hai, bas registration ke liye 1500 rupaye processing fee pay kariye aur passport details bhejiye.",
"Unsolicited prize trips requiring processing fees and passport details are advance-fee/identity-theft travel scams.")

# -------- SOCIAL_MEDIA_IMPERSONATION (3) --------
add("SOCIAL_MEDIA_IMPERSONATION", True,
"Hi, main tumhara purana dost Vikram bol raha hoon, mera Facebook hack ho gaya tha isliye naye number se call kar raha hoon, abhi emergency hai, please 8000 rupaye is UPI pe bhej do main kal wapas kar dunga.",
"Impersonates a known contact on a new number claiming social media was hacked to urgently request money - a classic social media impersonation scam.")

add("SOCIAL_MEDIA_IMPERSONATION", True,
"Main Instagram influencer Riya hoon, aapko meri fan list mein add kar raha hoon, mere exclusive group join karne ke liye 999 rupaye subscription pay kariye is link pe.",
"Fake celebrity/influencer paid group subscription demanded via a link is a social media impersonation monetization scam.")

add("SOCIAL_MEDIA_IMPERSONATION", True,
"Hello uncle, main Arpit hoon, Priya di ka beta, meri car accident ho gayi aur hospital mein admit hoon, kisi ko mat batana please, abhi 25,000 bhej do is number pe.",
"Uses a family relation name + secrecy instruction + urgent money request combination, hallmark of social media profile-based impersonation scams.")

# -------- HEALTH_SCHEME_SCAM (3) --------
add("HEALTH_SCHEME_SCAM", True,
"Sir aapko sarkar ki taraf se free cancer screening ka call hai, camp aapke area mein aayega, bas registration ke liye 300 rupaye advance dena hoga jo camp mein adjust ho jayega.",
"Legitimate government health camps are free with no advance; charging a 'registration fee' for a free health camp is a health scheme scam.")

add("HEALTH_SCHEME_SCAM", True,
"Namaste, hum ek NGO se hain, aapke area mein free health checkup chal raha hai, doctor aapke ghar aayenge, bas apna Aadhaar number aur 100 rupaye ka nominal charge dena hoga.",
"Free health camps don't collect Aadhaar numbers and nominal fees via phone; combined request signals a phishing/money scam.")

add("HEALTH_SCHEME_SCAM", True,
"Hello sir, aapka naam free dialysis scheme mein aaya hai government hospital ka, slot book karne ke liye pehle 1000 rupaye deposit kariye, baad mein refund ho jayega.",
"A government-funded dialysis scheme would never require upfront deposits for slot booking - a health-targeted advance-fee scam.")

# -------- MILITARY_ROMANCE_SCAM (3) --------
add("MILITARY_ROMANCE_SCAM", True,
"Hi, I am Colonel James Anderson posted in Syria with UN peacekeeping forces. I found your profile online and I am very interested. I have some gold bars I want to send to India, please help me pay the shipping and customs.",
"Classic military romance scam where an impersonated foreign soldier requests customs payment for gold 'being shipped' - an advance-fee fraud.")

add("MILITARY_ROMANCE_SCAM", True,
"Main BSF jawaan hoon border pe posted, humne bohot dosti ki hai pichle 2 mahine mein, main leave le raha hoon milne aane ke liye lekin camp se bahar nikalne ke liye 20,000 ki zaroorat hai, please bhej do.",
"Long-term emotional grooming by a fake Indian soldier leading to a 'camp exit fee' demand is a localized military romance scam.")

add("MILITARY_ROMANCE_SCAM", True,
"Hi dear, I am a US army doctor in Afghanistan, I have 2 million dollars in savings I want to transfer to India before I retire, I need a trusted person to help, you will get 30 percent for helping, just pay the transfer fees.",
"Fake US military doctor with large overseas savings needing a local partner to pay transfer fees is a classic advance-fee military romance fraud.")

# -------- RATION_CARD_SCAM (3) --------
add("RATION_CARD_SCAM", True,
"Namaste, main PDS department se bol raha hoon, aapka ration card link nahi hua Aadhaar se, kal se ration band ho jayega, abhi apna Aadhaar number aur registered mobile OTP bataiye link karne ke liye.",
"Government ration card Aadhaar linking does not happen via OTP shared over phone - this is a phishing scam targeting rural beneficiaries.")

add("RATION_CARD_SCAM", True,
"Sir government ne free ration 6 mahine ke liye extend kiya hai, aapka naam list mein hai, confirm karne ke liye 200 rupaye processing fee bhejiye is number pe, warna naam list se hat jayega.",
"Free government ration schemes have no processing fee for existing cardholders - demand for any fee is a ration scheme fraud signal.")

add("RATION_CARD_SCAM", True,
"Aapka new ration card ready hai, home delivery ke liye 150 rupaye delivery charge dena hoga, is UPI pe bhej do, kal tak card mil jayega.",
"Ration cards are distributed free through fair price shops or government offices - a 'delivery charge' via UPI is a scam.")

# -------- CRYPTO_SCAM (4) --------
add("CRYPTO_SCAM", True,
"Bhai, main ek WhatsApp group mein hoon jahan ek Chinese expert crypto signals deti hai, 3 din mein mera 10,000 ka 35,000 ho gaya, tu bhi join kar, pehle is wallet mein USDT bhej.",
"Fake crypto expert signals group where early participants report gains to lure others - a classic pump-and-dump or Ponzi crypto scam.")

add("CRYPTO_SCAM", True,
"Sir ye NFT minting ka opportunity hai, sirf 5000 rupaye mein ek NFT buy karo aur 1 lakh mein sell karo marketplace pe, humare group mein sab kar rahe hain, slot limited hai.",
"Guaranteed NFT profit claims with limited slots and upfront investment are hallmarks of NFT-based investment fraud.")

add("CRYPTO_SCAM", True,
"Main ek crypto exchange ka admin hoon, hamare platform pe aapka account block ho gaya tha, unblock karne ke liye 2000 rupees verification fee deni hogi, phir aap withdraw kar sakte ho.",
"Charging a 'verification fee' to unblock a crypto account and allow withdrawals is a common exchange impersonation scam to extract additional money.")

add("CRYPTO_SCAM", True,
"Hi, aapko aaj ek trading bot ka access milega free mein, ye bot automatically 500 rupaye roz kamaata hai, bas pehle 10,000 ka wallet fund karo activate karne ke liye.",
"A trading bot promising guaranteed daily profit requiring wallet funding is a crypto Ponzi/advance-fee bot scam.")

# -------- EXTRA NORMALS (8) --------
add("UNKNOWN", False,
"Bhai aaj sham ko badminton khelne chalein kya, court book karna hoga pehle, main check karta hoon slots.",
"Normal casual conversation between friends about recreational sports planning.")

add("UNKNOWN", False,
"Hello sir, main aapke building ka maintenance contractor bol raha hoon, lift ka annual inspection kal hai, please 10 baje tak entrance khuli rakhein.",
"Routine building maintenance coordination call with no financial or credential request.")

add("UNKNOWN", False,
"Mummy main library mein hoon, raat 8 baje tak aa jaunga, khana mat rokna, main bahar se kha lunga.",
"Ordinary family communication about whereabouts and dinner plans, completely benign.")

add("UNKNOWN", False,
"Good morning, this is the passport office, your passport is ready for collection, please bring your original acknowledgement slip and ID proof, office timings are 10 AM to 5 PM.",
"Routine government passport collection intimation with no fees or OTP requests.")

add("UNKNOWN", False,
"Sir aapne jo paise bheje the freelance project ke liye, kaam complete ho gaya hai, final file Google Drive link pe bhej raha hoon, please check karein aur feedback dein.",
"Normal freelance project delivery communication between a client and service provider.")

add("UNKNOWN", False,
"Hi, your table for two is confirmed for 8 PM tonight at Spice Garden restaurant, please inform us in case of cancellation at least 2 hours before.",
"Routine restaurant table reservation confirmation, a standard hospitality industry call.")

add("UNKNOWN", False,
"Bhai college reunion hai next Sunday, sab log aa rahe hain, tu bhi confirm kar, venue Indiranagar mein hai, details group mein bhej raha hoon.",
"Casual social event planning for a college reunion, entirely normal conversation.")

add("UNKNOWN", False,
"Hello, this is Cloudtail seller support, your product listing has been temporarily deactivated due to a category compliance issue, please log in to Seller Central and upload the required certificate.",
"Legitimate Amazon seller support communication about a compliance issue with no unusual financial or OTP request.")

# --------- Write JSONL ---------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(SCRIPT_DIR, "..", "ai_training", "dataset.jsonl")

with open(out_path, "a", encoding="utf-8") as f:
    for category, is_scam, transcript, reasoning in data:
        output_obj = {"category": category, "is_scam": is_scam, "reasoning": reasoning}
        row = {
            "instruction": INSTRUCTION,
            "input": transcript,
            "output": json.dumps(output_obj, ensure_ascii=False)
        }
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

print(f"Appended {len(data)} new diverse scam/normal examples.")
scam_count = sum(1 for c, s, _, __ in data if s)
normal_count = sum(1 for c, s, _, __ in data if not s)
print(f"  Scam: {scam_count} | Normal: {normal_count}")
cats = set(c for c, _, __, ___ in data)
print(f"  New categories added: {cats}")
