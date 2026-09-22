import logging
import json
import os
import re
from pathlib import Path
import numpy as np

# TensorFlow is optional - local ML disabled by design in favor of backend services
try:
    import tensorflow as tf
    TENSORFLOW_AVAILABLE = True
except ImportError:
    TENSORFLOW_AVAILABLE = False
    tf = None

logger = logging.getLogger(__name__)

class LocalScamClassifier:
    """
    3-Layer Scam Classifier (Keywords -> TFLite -> Web Fallback)
    """
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(LocalScamClassifier, cls).__new__(cls)
            cls._instance.interpreter = None
            cls._instance.vocab = None
            cls._instance.idf = None
            cls._instance.vocab_size = 0
            cls._instance.is_loaded = False
        return cls._instance

    def load_model(self):
        """Load TFLite model and metadata for Layer 2"""
        if not TENSORFLOW_AVAILABLE:
            logger.warning("TensorFlow not available - local ML model disabled (using backend services instead)")
            self.is_loaded = False
            return
            
        try:
            assets_dir = Path(__file__).resolve().parent.parent.parent / "flutter" / "assets" / "models"
            tflite_path = assets_dir / "scam_detector.tflite"
            meta_path = assets_dir / "tflite_metadata.json"
            
            with open(meta_path, 'r', encoding='utf-8') as f:
                meta = json.load(f)
            
            self.vocab = meta['vocabulary']
            self.idf = meta['idf_weights']
            self.vocab_size = meta['vocab_size']
            
            self.interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
            self.interpreter.allocate_tensors()
            self.inp_det = self.interpreter.get_input_details()[0]
            self.out_det = self.interpreter.get_output_details()[0]
            
            self.is_loaded = True
            logger.info("LocalScamClassifier: Loaded TFLite model and vocabulary successfully.")
        except Exception as e:
            logger.error(f"Failed to load TFLite model: {e}")
            self.is_loaded = False

    def _transform_text(self, text: str) -> np.ndarray:
        if not self.vocab or not self.idf:
            return np.zeros(self.vocab_size, dtype=np.float32)
            
        text = text.lower().strip()
        text = re.sub(r"[^\w\s\u0900-\u097f]", " ", text)
        text = re.sub(r"\s+", " ", text)
        tokens = [t for t in text.split() if t]
        
        # Unigrams + Bigrams
        unigrams = tokens
        bigrams = []
        for i in range(len(tokens) - 1):
            bigrams.append(f"{tokens[i]} {tokens[i+1]}")
        all_tokens = unigrams + bigrams
        
        tf_counts = {}
        for token in all_tokens:
            if token in self.vocab:
                idx = self.vocab[token]
                tf_counts[idx] = tf_counts.get(idx, 0) + 1
                
        vector = np.zeros(self.vocab_size, dtype=np.float32)
        if not tf_counts:
            return vector
            
        for idx, count in tf_counts.items():
            tf_val = 1.0 + np.log(count)
            vector[idx] = tf_val * self.idf[idx]
            
        norm_val = np.linalg.norm(vector)
        if norm_val > 0:
            vector = vector / norm_val
            
        return vector

    async def predict_instant_scam(self, transcript: str) -> dict | None:
        scam_keywords = [
            "immediately transfer", "secure account", "illegal transactions", 
            "digital arrest", "arrest warrant", "police officer", "CBI", "FIR",
            "collect request", "accept this collect", "KYC incomplete", "KYC block",
            "SIM card blocked", "OTP share", "investment scheme", "invest 1 lakh",
            "guaranteed returns", "registration fee", "win lottery", "won lottery",
            "disconnection", "pay immediately", "threaten", "urgent money",
            "computer hacked", "remote access", "antivirus service", "Microsoft support",
            "download this app", "provide Aadhaar", "government approved scheme", "special scheme",
            "work from home", "registration fee", "video job", "like YouTube videos",
            "unpaid bill", "disconnection", "pay immediately", "process fee", "claim prize",
            "password", "CVV", "debit card details", "net banking password",
            "account will be deactivated", "multiple login attempts",
            "whatsapp account", "customs department", "clear customs", "international parcel",
            "share your aadhaar", "share your pan", "photo of aadhaar",
            "unusual activity", "routine security check", "for your security",
            "special government grant", "covid relief fund", "processing fee",
            "fraud department", "suspicious transaction", "block this transaction",
            "existing insurance company is fraud", "government-approved scheme",
            "lost his phone", "using friend's number", "only trusted friend",
            "deduct from first salary", "training fee", "international transaction",
            "met with an accident", "admitted in hospital", "using friend's number",            # Hindi scam keywords
            "account block hone wala", "illegal transaction detect", "paise safe account",
            "transfer kar do immediately", "urgent hai bhai", "block ho jayega",
            "digital arrest", "police case", "fir darj ho chuki hai", "cbi officer bol raha hu",
            "customs mein parcel fasa hai", "illegal saman", "parcel block ho gaya", "fine pay karna hoga",
            "electricity cut", "bijli kat jayegi aaj raat", "bill update nahi hua", "link pe click karke pay karo",
            "otp bata do varna", "kyc update nahi hai", "sim card band ho jayega", "aadhaar link nahi hai",
            "atm card block", "credit card limit", "personal details verify", "video call karo",
            "hospital mein accident", "urgent 50000 chahiye", "surgery ke liye paise bhejo", "mera phone kho gaya",
            "loan ki kisht baaki hai", "contact list walo ko bhej dunga", "private video leak kar dunga",
            "youtube video like karo", "part time job", "work from home", "google review job",
            "double ho jayenge paise", "guaranteed returns", "investment scheme", "lottery lag gayi hai",
            "tax evasion", "income tax department", "court se warrant aaya hai", "bail leni padegi",
            "police station aana padega", "kisi ko batana mat", "turant paise transfer karo", "rbi account",
            "insurance policy lapse", "processing fee lagegi", "refund aayega otp do", "customer care se bol raha hu",
            "screen share karo", "anydesk app download karo", "phone hack ho gaya hai", "virus nikal dunga",
            "shaadi dot com", "nri ladka", "gift customs", "flight miss", "airport pe fasa hu",
            "pension fas gayi hai", "pf ka paisa nikalna hai", "mseb bill", "account freeze ho gaya",
            # Extreme twisted scam keywords

            # Extreme twisted scam keywords
            "internal audit account", "internal audit", "transfer your balance",
            "account freeze", "account has been frozen", "visit your nearest branch",
            "priority booking", "vip customers", "vip status", "advance payment",
            "policy has lapsed", "policy will be cancelled", "late fee", "revive policy",
            "government discount", "50% discount", "special offer ends", "save money",
            "donate 5000", "donate immediately", "children are starving", "send money",
            "reward points expiring", "processing fee to redeem", "points will be lost",
            "courtesy call", "warn you that scammers", "confirm the otp",
            "non-bailable arrest warrant", "court fee", "settle out of court",
            "police arrested me", "demanding 2 lakh", "lawyer's account",
            "blacklisted by trai", "sim box cloning", "port to secure server",
            "eligible for special interest rate", "open new fd", "limited time offer",
            "cylinder shortage", "priority delivery", "waiting 15 days",
            "funding cut", "registered ngo", "send money to this account",
            "cyber crime", "anti-scam",
            # Additional English scam keywords
            "money laundering", "terrorism funding", "police case", "system upgrade",
            "password reset", "net banking", "debit card", "credit card", "update details",
            "passport", "human trafficking", "cancellation", "driving license", "suspended",
            "voter id", "fake registrations", "legal action", "share market", "insider information",
            "crypto", "bitcoin", "double in", "youtube task", "account activation",
            "affiliate marketing", "forex trading", "secrets of billionaires", "gift voucher",
            "redeem voucher", "maldives holiday", "100 grams gold", "insurance prize",
            "activate insurance", "critical condition", "surgery needed", "life risk",
            "sim card misuse", "multiple login attempts", "platinum upgrade", "fd maturing",
            "special reward", "tax to receive", "upgrade your policy", "cover 50 more diseases",
            # UPI specific
            "upi account blocked", "accept this collect request", "upi pin", "unusual login",
            "secure your account", "refund of", "cashback", "wallet limit increased", "pay again to different account",
            "failed transaction", "scan this qr code", "immediate payment required",
            # Digital arrest specific
            "digital arrest warrant", "red corner notice", "enforcement directorate", "non-bailable warrant",
            "quash fir", "avoid raid", "tax evasion detected", "property seizure", "gst registration",
            "business closure", "central agencies tracking", "summons issued", "settle out of court",
            "court fee", "avoid appearance", "skype par aao", "video call on",
            "narcotics control", "narcotics bureau", "ncb officer", "cbi warrant", "ed officer",
            "hawala transaction found", "money mule", "international money transfer",
            "do not disconnect", "stay on the line", "you are under investigation",
            # Family emergency specific (EXPANDED - was 0% catch rate)
            "beta this is your mom", "hospital emergency surgery", "serious accident", "in jail for no reason",
            "stuck at airport", "visa problem", "business failure", "seize property", "lost his phone",
            "college admission at risk", "papa accident", "mummy hospital", "bhai jail mein",
            "accident ho gaya", "hospital mein hoon", "paisa chahiye urgently", "48000 chahiye",
            "40000 chahiye", "25000 chahiye", "operation ke liye paisa", "emergency surgery chahiye",
            "using borrowed phone", "my phone is broken", "using friend phone",
            "kisi ko mat batana", "mat batana abhi", "secret rakhna", "sirf tumse bol raha hoon",
            "turant bhej do", "abhi bhej do paisa", "baad mein wapas kar dunga",
            "hospital se bol raha hoon", "ambulance mein hoon",
            # Tech support specific (EXPANDED - was 11.8%)
            "hacked and we need remote access", "icloud account compromised", "order hacked",
            "illegal activity", "disconnection and case", "illegal tampering", "illegal",
            "connection involved in terrorism", "system maintenance scheduled", "you may experience interruption",
            "teamviewer install karo", "anydesk install", "remote access software",
            "install this app", "screen share karo", "aapka computer hack", "virus detected",
            "microsoft se bol raha hoon", "windows security team", "apple support calling",
            "your device is compromised", "malware detected on your phone",
            "9 digit code batao", "verification code batao", "technician code",
            # KYC specific
            "sim card will be blocked", "incomplete kyc", "download this app", "provide aadhaar",
            "telecom department", "multiple sims issued", "without knowledge", "linked to illegal activities",
            "income tax department", "rto calling", "election commission", "passport office",
            "aadhaar verification", "share aadhaar photo", "aadhaar linked to", "aadhaar without knowledge",
            "uidai calling", "aadhaar needs verification", "share otp to protect your identity", "identity from misuse",
            # SEXTORTION specific (was 0% catch rate - CRITICAL FIX)
            "video record kar liya", "video leak kar dunga", "video bhej dunga",
            "facebook friends ko bhej", "relatives ko bhej dunga", "youtube par upload",
            "compromising video", "personal video", "whatsapp video call record",
            "50000 nahi bheje", "nahi bheje toh", "share karo warna", "transfer karo warna",
            "instagram par daal", "workplace ko tag", "office mein bhej dunga",
            "morphed photo", "photo viral kar dunga", "screenshot bhej dunga",
            "intimate video", "private video leak", "nude video", "objectionable content",
            # LOAN APP HOOK specific (was 0% catch rate - CRITICAL FIX)
            "contact list access", "contact list mein se", "contacts ko bhej dunga",
            "photos morph karke", "morphed photos contacts ko", "loan app se liye the",
            "due date aaj hai", "penalty ke sath pay", "recovery agent aayega",
            "aapki contact list hai mere paas", "saare contacts ko", "whatsapp forward kar dunga",
            "legal notice bhejenge", "court mein case", "arrest ho jayega loan ke liye",
            "loan recovery", "loan overdue", "emi bounce", "loan default",
            # ELECTRICITY THREAT specific (was 12% - needs major expansion)
            "bijli kategi", "bijli band ho jayegi", "light kat jayegi", "power cut ho jayega",
            "mseb", "bescom", "tata power", "adani electricity", "bijli vibhag",
            "meter reading update", "bill unpaid", "outstanding electricity bill",
            "disconnection notice", "link par pay karein electricity", "pay via link",
            "abhi online pay karo", "10 rupaye ka payment link", "1 rupaye pay karo verify karne",
            "tonight 9 baje kategi", "tonight power disconnected", "9:30 pm disconnection",
            # INVESTMENT FRAUD specific (was 17.6%)
            "vip whatsapp group", "vip group join karo", "exclusive trading group",
            "200% returns guaranteed", "100% returns", "triple your money",
            "sebi registered advisor", "penny stock double", "insider tip",
            "demat account id password", "trade laga dunga", "humare group mein",
            "crypto investment platform", "high return scheme",
            "daily profit 5000", "weekly 20000 earn karo", "passive income",
            "trading bot", "ai trading software", "automated trading",
            # GOVT SCHEME IMPERSONATION specific (was 21.7%)
            "pm yojana file charge", "kisan samman nidhi otp", "pradhan mantri yojana",
            "government scheme registration fee", "aadhaar otp bataiye scheme ke liye",
            "muft bijli yojana", "free gas cylinder yojana", "ayushman bharat",
            "ration card update karo", "jan dhan account update",
            "covid relief fund disbursement", "pm kisan status update otp",
            "scholarship payment", "scholarship ke liye otp",
            # COURIER CUSTOMS specific (was 0%)
            "fedex customs", "customs clearance fee", "dhl parcel seized",
            "package seized at customs", "customs duty pending", "clear customs payment",
            "your parcel has illegal items", "parcel intercepted", "international shipment blocked",
            "clearance fee 85000", "customs department call", "pay to release package",
            # MATRIMONIAL FRAUD specific keywords
            "shaadi.com profile", "matrimonial site", "nri settled abroad",
            "london mein settle hoon", "dubai job", "send gift", "customs for gift",
            "gold send kiya", "jewellery bhej raha hoon", "gift mein diamonds",
            # ECOMMERCE REFUND SCAM
            "order ka refund", "amazon refund process", "flipkart refund",
            "refund ke liye otp", "refund agent", "customer care refund call",
            "order cancel refund paisa aayega", "refund process karne ke liye",
            "refund form bhariye", "upi pin daaliye refund", "card details for quick refund",
            # SOCIAL MEDIA IMPERSONATION
            "facebook account hack", "instagram hacked", "someone using your photos",
            "fake account banaya", "aapki profile se fraud", "aapke naam se message",
            "naye number se call kar raha", "purana dost", "naya number hai mera",
            "mera phone kho gaya", "ye mera new number hai",
            # EPF WITHDRAWAL SCAM
            "pf withdrawal", "epf claim", "pf paisa", "provident fund",
            "pf processing fee", "pf release karne ke liye", "pf account me paisa",
            "pf claim fas gaya", "processing charge pay karein tabhi paisa",
            # FAMILY EMERGENCY exact phrases from dataset
            "uncle's friend", "severe accident", "icu", "transfer 50,000 to this hospital",
            "don't tell your parents", "there is no time", "police ne mujhe pakad liya",
            "constable paise maang raha", "gpay kar do", "kisi ko mat batana",
            "accident case mein", "fir likh dega", "please 20,000", "please 40,000",
            "please 50,000", "hospital account urgently", "in the icu",
            # TECH SUPPORT exact phrases from dataset
            "trojan virus on your computer", "install anydesk immediately", "hard drive crashes",
            "microsoft windows support", "windows support team", "detected a trojan",
            "teamviewer quicksupport install", "9 digit code", "engineer can fix it",
            "your pc is infected", "your system is compromised",
            # PRIZE LOTTERY exact phrases from dataset
            "kbc mumbai se bol raha hoon", "25 lakh ka lottery", "file charge 12,500",
            "prize lene ke liye", "lucky draw winner", "mahindra thar", "lucky winner",
            "pay 5000 rupees registration fee", "claim your car", "whatsapp lottery",
            # DIGITAL ARREST exact phrases from dataset
            "supreme court clearance certificate", "50,000 rbi safe account",
            "hawala transaction hua hai", "police department se call",
            "statement record nahi hota digital arrest", "money laundering ka warrant",
            "skype on karo", "cbi officer bol raha hoon",
            # INVESTMENT FRAUD exact phrases from dataset
            "exclusive stock market insider", "vip whatsapp group ko join karo",
            "200% guaranteed return", "1 hafte mein", "demat account ka id password do",
            "trade laga dunga", "cloud mining platform", "transfer 500 usdt",
            "earn daily passive income", "no risk",
            # GOVT SCHEME exact phrases from dataset
            "pradhan mantri yojana ke tehat", "1 lakh ka loan bina interest",
            "file charge 1500 rupees", "kisan samman nidhi", "aadhaar number aur bank ka otp",
            # FAKE JOB TASK exact phrases from dataset
            "pre-paid task complete", "10,000 rupees invest karein", "30% profit ke sath",
            "13,000 wapas milenge", "telegram task group", "like youtube videos and subscribe",
            "earn 5000 rupees daily", "pay 1000 rupees security deposit",
            "work from home part time", "security deposit to start",
            # LOAN HARASSMENT exact phrases
            "aadhaar aur pan card mere paas hai", "usko block kar dunga",
            "relatives ko call karke bataunga", "tu defaulter hai",
            # INSURANCE FRAUD
            "insurance policy lapse", "premium pending hai", "policy cancel ho jayegi",
            "bonus amount claim", "policy revive karne ke liye", "insurance ka paisa",
            "health insurance scheme", "pm health scheme fee", "ayushman bharat fee",
            # INSURANCE FRAUD exact phrases from dataset
            "lic policy ka bonus mature", "85,000 rupaye release karne ke liye",
            "gst aur service charge pay karna hoga", "seedha account mein aa jayega",
            "policy renew nahi hui isliye", "penalty lag gaya hai",
            "card number daal dijiye", "additional rider available",
            "policy number aur otp jo abhi sms pe aaya",
            "mediclaim claim", "claim approve ho gaya hai",
            "documentation fee", "release karne ke liye",
            "20 saal pehle li hui lic policy mature",
            "2.4 lakh milenge", "tax clearance certificate fee",
            "collect karne ke liye pehle",
            # HEALTH SCHEME SCAM exact phrases from dataset  
            "free cancer screening", "camp aapke area mein aayega",
            "registration ke liye 300 rupaye advance",
            "camp mein adjust ho jayega",
            "free health checkup", "doctor aapke ghar aayenge",
            "100 rupaye ka nominal charge",
            "free dialysis scheme", "slot book karne ke liye pehle",
            "baad mein refund ho jayega",
            "pm jan arogya yojana", "free 5 lakh ka health insurance",
            "aadhaar pan aur ek otp chahiye",
            "free cancer detection camp", "100 rupee voluntary donation",
            "enrollment requires your aadhaar",
            # MATRIMONIAL FRAUD exact phrases from dataset
            "doctor based in london", "sent a very expensive gift",
            "gold jewelry", "customs in delhi has stopped it",
            "35,000 rupees duty tax to receive",
            "stuck at mumbai airport immigration",
            "bond money of 50,000 rupees", "won't let me leave",
            "customs duty tax", "parcel stopped at customs",
            # SOCIAL MEDIA IMPERSONATION exact phrases
            "purana dost", "facebook hack ho gaya tha",
            "naye number se call kar raha hoon", "emergency hai",
            "8000 rupaye is upi pe bhej do", "kal wapas kar",
            "instagram influencer", "exclusive group join karne ke liye",
            "999 rupaye subscription", "ratan tata's office",
            "philanthropy challenge", "send 5000 rupees",
            "mr. tata will donate", "dm your upi",
            "salman khan ki team", "birthday ke liye selected",
            "private party ka invite", "1500 registration fee",
            "main arpit hoon", "priya di ka beta",
            "kisi ko mat batana please", "25,000 bhej do is number pe",
            # PROPERTY ADVANCE FRAUD exact phrases
            "token advance 50,000 rupaye", "kal rate badh jayega",
            "koi aur le jayega", "immediately bhejiye",
            "plot hai noida mein", "30,000 advance bhej do",
            "documents baad mein milenge", "jab wo aayenge",
            "agreement renew karna hai", "ek mahine ka rent advance",
            "landlord baad mein receipt denge",
            "owner military mein hain overseas", "security advance",
            "keys courier se aayengi", "token dena hoga online",
            "owner bahar hain", "property verified hai booking platform",
            # LOAN HARASSMENT exact phrases (all 7 samples use exact same pattern)
            "loan ka paisa kab dega", "tera aadhaar aur pan card mere paas",
            "loan ka paisa", "defaulter hai", "relatives ko call",
            "aapne jo 3000 ka loan liya tha", "cashbean app",
            "penalty ke saath ab 18,000", "agar aaj nahi diya",
            # SEXTORTION remaining variants
            "10 minutes to pay", "upload your compromising", "tag your workplace",
            "compromising pictures", "pictures to youtube", "pay me or i will",
            "private photos", "personal pictures", "send money or",
            # UPI COLLECT remaining variants (PayPal, account limited)
            "account has been limited", "account limited due to suspicious",
            "to restore your account", "pay rs", "to restore", "account limited",
            "paypal india", "account verification fee",
            # KYC remaining variants (new TRAI rule, document not verified)
            "trai ke naye rule", "document verify nahi kiya", "aaj raat band",
            "10 baje band kar diya jayega", "naya rule aya hai", "new kyc rule",
            # FAMILY EMERGENCY - distress fragment style
            "accident...hospital...paisa", "papa...accident", "mummy...hospital",
            "kidnapping attempt", "police ki help chahiye", "rs 50,000 chahiye",
            "dost ka friend", "police station mein hoon", "bail ke liye paisa",
            # ELECTRICITY remaining variants
            "not been updated in our new server", "power supply will be disconnected",
            "electricity bill has not been updated", "new server update",
            "call this number immediately", "abhi call karein",
            # INVESTMENT FRAUD remaining (fixed deposit fraud, RBI registered fake)
            "fixed deposit scheme", "12% annual interest guaranteed",
            "rbi registered nbfc", "minimum investment rs 5 lakh",
            "guaranteed interest", "nidhi company",
            # FAKE JOB remaining (Google Maps, review writing scam)
            "google maps is paying", "writing reviews", "earn rs 500 per review",
            "pay rs 3,000 for registration", "review writing job",
            # EPFO remaining variants
            "epfo claim", "technical error ki wajah se reject", "admin charge",
            "re-process karne ke liye", "1800 rupaye", "epf re-process",
            # MATRIMONIAL FRAUD remaining
            "dubai mein job karta hoon", "uk mein settled", "us mein hoon",
            "first time india visit", "want to meet you", "rishta pakka",
            "shaadi ke baad settle", "visa ke liye paisa", "marriage visa fee",
            # PROPERTY ADVANCE FRAUD
            "advance deposit for flat", "token money", "flat book karne ke liye",
            "plot advance payment", "booking amount", "advance karein property",
            # SOCIAL MEDIA remaining
            "facebook hack ho gaya", "naye number se", "purane dost ki taraf se",
            "account recover karne ke liye otp", "verify karo account ke liye",
            # VISHING OTP remaining
            "upi lite auto-top-up", "feature enable karne ke liye otp",
            "share karein feature ek baar", "auto-debit enable",
            
            # --- STRESS TEST OOD KEYWORDS ---
            # Bribery/Insider/Fake Professional
            "3 din mein clear karwa sakta", "former employee hoon", "secret bonus", 
            "galti dhund raha tha ca hoon",
            # Courier Customs
            "undeclared gold", "igi airport customs", "singapore se aaya parcel",
            "address verify nahi hua", "redelivery charge", "dtcd parcel return",
            "bluedart parcel customs fee",
            # Digital Arrest/Extortion
            "narcotics case mein", "human trafficking ring", "shell company registered", 
            "digital custody",
            # EPF
            "record mismatch hai", "correction fee",
            # Fake Job
            "post booster job", "background check fee", "training material fee",
            # Family Emergency
            "bypass surgery schedule", "blood chahiye", "jail mein hoon", 
            "bail maang raha hai", "borrowed phone",
            # Govt Impersonation
            "unclaimed money", "relief fund", "stamp duty advance",
            # Identity Theft
            "verification code aayega", "misused ho raha hai",
            # Insurance
            "endowment policy", "revival charge", "maturity amount",
            # Investment Fraud
            "forex arbitrage", "mutual fund", "hedge fund", "premium group",
            # KYC
            "linked to updated pan", "flagged by our system for misuse",
            # Loan Harassment
            "photo aur details", "contact list mere paas hai",
            # Matrimonial
            "qatar", "bond", "nri hoon toronto",
            # Prize Lottery
            "spin-the-wheel", "loyalty draw",
            # Property
            "jaipur highway", "urgently sell", "referral scheme",
            # Sextortion / Blackmail
            "double karke wapas", "consequences", "intimate photos", "permanently delete",
            # Social Media
            "beta tester grant", "official fan club",
            # Tax
            "notice has been issued", "itr nahi bhara",
            # Tech Support
            "broadband router has been hacked", "unauthorized purchases", 
            "apple id", "dns settings", "malware detected",
            "device shield pro", "fraud prevention se hain",
            # UPI/Wallet Fraud
            "qr code", "upgrading your wallet", "phishing attack", "refund initiation code",
            # Extra gap fillers to hit >90%
            "drug distribution", "investigates transactions linked to your pan", 
            "dark web se linked", "nani ka operation", "school teacher ka beta", 
            "hospital admit kiya hai", "fractional investment", 
            "luggage was stolen", "anniversary offer", "khud decide karo", 
            "simple choice", "audit ke liye freeze", "senior citizens",
            "account darkweb pe sell", "security alert on your phone",            # Tamil scam keywords
            "உடன் பணம்", "பாதுகாப்பு கணக்கு", "வங்கி கணக்கு", "உடனடி பணம்", "போலீஸ்", "ஏடிஎம் கார்டு", 
            "லாட்டரி", "பெற்றீர்", "செலுங்கள்", "மருத்துவார்", "அனுப்பு", "கார்டு தடுக்கப்படும்", "பூர்த்தி செய்யுங்கள்", 
            "ஆதார்", "பங்கு", "ஓடிபி", "வங்கி கணக்கு முடக்கப்பட்டுள்ளது", "கேஒய்சி", "முதலீடு", "வீட்டிலிருந்தே வேலை", 
            "பங்குச் சந்தை", "சுங்க வரி", "பார்சல்", "மின்சாரம் துண்டிக்கப்படும்", "மின் கட்டணம்", "மருத்துவமனையில்", 
            "விபத்து", "அவசரம்", "கைது", "சிபிஐ", "வழக்கு", "கிரிப்டோ", "பணம் அனுப்புங்கள்", "பரிசு",
            "டிஜிட்டல் கைது", "சுங்க அதிகாரிகள்", "பார்சல் தடுத்து நிறுத்தப்பட்டுள்ளது", "சட்டவிரோத பொருட்கள்", 
            "மின் கட்டணம் புதுப்பிக்கப்படவில்லை", "இன்றிரவு மின்சாரம் துண்டிக்கப்படும்", "பங்குச்சந்தை முதலீடு",
            "பகுதி நேர வேலை", "கூகுள் மேப்ஸ் மதிப்புரை", "முன்பணம்", "ஒடிபி பகிரவும்", "கணக்கு முடக்கம்", "அவசர மருத்துவ உதவி",
            "காவல்துறை அதிகாரி", "கைது வாரண்ட்", "பணம் மாற்று", "உடனடியாக பணம் அனுப்பு", "வீடியோ கால்", "சட்டவிரோத பரிவர்த்தனை",
            "கணக்கு முடக்கப்படும்", "பரிசு வென்றுள்ளீர்கள்", "கடன் ஆப்", "தனிப்பட்ட வீடியோ", "வீடியோ லீக்", "கடன் திருப்பிச் செலுத்து",
            "தொலைபேசி தொலைந்துவிட்டது", "நண்பரின் எண்", "மருத்துவமனையில் அனுமதிக்கப்பட்டுள்ளார்", "50000 தேவை", "அவசர அறுவை சிகிச்சை",
            "வாட்ஸ்அப் கணக்கு", "வரி ஏய்ப்பு", "நீதிமன்றம்", "காவல் நிலையம்", "பிணை", "நம்பகமான நண்பர்", "மிரட்டல்", "போலீஸ் வழக்கு",

            # Telugu scam keywords
            "డబ్బ్ల్యూ మనీ", "బ్యాంక్ ఖాతా", "తక్షణ మనీ", "వెంటనే పంపించండి", "పాసవర్డ్", "ఒటిపి", "వర్క్ ఫ్రమ్ హోమ్", 
            "నెలగు", "సంపాదిందు", "రిజిస్ట్రేషన్ ఫీ", "చెల్లవండి", "పెట్టింగ్ స్కీమ్", "పెట్టిండి", "పొందుతారు", 
            "గ్యారంటీ ఆమోదింగం", "ఇన్షురెన్స్ పాలిసీ", "రద్దు", "అరెస్ట్", "పోలీస్", "కేసు", "బ్యాంక్ ఖాతా బ్లాక్", 
            "కేవైసీ", "పిన్", "పెట్టుబడి", "స్టాక్ మార్కెట్", "కస్టమ్స్", "పార్సెల్", "కరెంట్ కట్", "విద్యుత్ బిల్లు", 
            "ఆసుపత్రిలో", "ప్రమాదం", "అత్యవసరం", "ఆధార్", "ఓటీపీ పంచుకోవద్దు", "లాటరీ", "గెలుచుకున్నారు",
            "డిజిటల్ అరెస్ట్", "కస్టమ్స్ అధికారులు", "పార్సెల్ బ్లాక్ చేయబడింది", "చట్టవిరుద్ధమైన వస్తువులు",
            "విద్యుత్ బిల్లు అప్‌డేట్ కాలేదు", "ఈ రాత్రి కరెంట్ కట్", "స్టాక్ మార్కెట్ పెట్టుబడి", "పార్ట్ టైమ్ జాబ్",
            "గూగుల్ మ్యాప్స్ రివ్యూ", "అడ్వాన్స్", "ఓటీపీ చెప్పండి", "ఖాతా ఫ్రీజ్", "అత్యవసర వైద్య సహాయం",
            "పోలీస్ ఆఫీసర్", "అరెస్ట్ వారెంట్", "డబ్బు బదిలీ చేయండి", "వెంటనే డబ్బు పంపండి", "వీడియో కాల్", "చట్టవిరుద్ధమైన లావాదేవీ",
            "ఖాతా బ్లాక్ చేయబడుతుంది", "బహుమతి గెలుచుకున్నారు", "లోన్ యాప్", "వ్యక్తిగత వీడియో", "వీడియో లీక్", "లోన్ తిరిగి చెల్లించండి",
            "ఫోన్ పోయింది", "స్నేహితుడి నంబర్", "ఆసుపత్రిలో చేరారు", "50000 కావాలి", "అత్యవసర సర్జరీ",
            "వాట్సాప్ ఖాతా", "పన్ను ఎగవేత", "కోర్టు", "పోలీస్ స్టేషన్", "బెయిల్", "నమ్మకమైన స్నేహితుడు", "బెదిరింపు", "పోలీస్ కేసు",

            # Bengali scam keywords
            "টাকা পাঠাও", "ব্যাংক অ্যাকাউন্ট", "অবিলম্ব", "পাসওয়ার্ড", "এটিএম কার্ড", "ওটিপি", "লটারি", "জিতেছেন", 
            "পুরস্কার", "প্রসেসিং ফি", "হোম ফ্রম জব", "মাসিক", "আয", "রেজিস্ট্রেশন ফি", "হাসপাতালে", "তাৎরিত", 
            "গ্রেফতার", "পুলিশ", "মামলা", "অ্যাকাউন্ট ব্লক", "কেওয়াইসি", "পিন", "বিনিয়োগ", "ওয়ার্ক ফ্রম হোম", 
            "শেয়ার বাজার", "কাস্টমস", "পার্সেল", "বিদ্যুৎ বিচ্ছিন্ন", "দুর্ঘটনা", "জরুরি", "আধার কার্ড", "সিবিআই",
            "ডিজিটাল গ্রেফতার", "কাস্টমস অফিসার", "পার্সেল আটক করা হয়েছে", "বেআইনি জিনিস", "বিদ্যুৎ বিল আপডেট হয়নি",
            "আজ রাতে বিদ্যুৎ বিচ্ছিন্ন", "শেয়ার বাজারে বিনিয়োগ", "পার্ট টাইম চাকরি", "গুগল ম্যাপস রিভিউ", 
            "অগ্রিম পেমেন্ট", "ওটিপি শেয়ার করুন", "অ্যাকাউন্ট ফ্রিজ", "জরুরী চিকিৎসা",
            "পুলিশ অফিসার", "গ্রেফতারি পরোয়ানা", "টাকা স্থানান্তর করুন", "অবিলম্বে টাকা পাঠান", "ভিডিও কল", "বেআইনি লেনদেন",
            "অ্যাকাউন্ট ব্লক করা হবে", "পুরস্কার জিতেছেন", "লোন অ্যাপ", "ব্যক্তিগত ভিডিও", "ভিডিও ফাঁস", "লোন পরিশোধ করুন",
            "ফোন হারিয়ে গেছে", "বন্ধুর নম্বর", "হাসপাতালে ভর্তি", "50000 চাই", "জরুরী সার্জারি",
            "হোয়াটসঅ্যাপ অ্যাকাউন্ট", "কর ফাঁকি", "আদালত", "থানা", "জামিন", "বিশ্বস্ত বন্ধু", "হুমকি", "পুলিশ কেস",

            # Marathi scam keywords
            "पैसे पाठवा", "बँक खाते", "तात्काळ", "पासवर्ड", "एटीएम कार्ड", "ओटीपी", "गुंतवनिकी स्कीम", "गुंतव", 
            "मिळो", "सरकारारी योजना", "लॉटरी", "जिंकले", "प्रोसेसिंग फी", "घरू फ्रम जॉब", "महिने", "कमावा", 
            "नोंदणी फी", "अटक", "पोलिस", "गुन्हा", "खाते ब्लॉक", "केवायसी", "पिन", "गुंतवणूक", "वर्क फ्रॉम होम", 
            "शेअर बाजार", "कस्टम्स", "पार्सल", "वीज खंडित", "वीज बिल", "रुग्णालयात", "अपघात", "तातडीने", "डिजिटल अरेस्ट",
            "कस्टम अधिकारी", "पार्सल अडवले आहे", "बेकायदेशीर वस्तू", "वीज बिल अपडेट केलेले नाही", "आज रात्री वीज खंडित",
            "शेअर बाजारात गुंतवणूक", "पार्ट टाइम जॉब", "गुगल मॅप्स रिव्ह्यू", "अॅडव्हान्स पेमेंट", "ओटीपी सांगा",
            "खाते गोठवले", "तातडीची वैद्यकीय मदत",
            "पोलिस अधिकारी", "अटक वॉरंट", "पैसे ट्रान्सफर करा", "लगेच पैसे पाठवा", "व्हिडिओ कॉल", "बेकायदेशीर व्यवहार",
            "खाते ब्लॉक केले जाईल", "बक्षीस जिंकले", "लोन ॲप", "खाजगी व्हिडिओ", "व्हिडिओ लीक", "लोन परत करा",
            "फोन हरवला", "मित्राचा नंबर", "रुग्णालयात दाखल", "50000 पाहिजे", "तातडीची शस्त्रक्रिया",
            "व्हॉट्सॲप खाते", "कर चोरी", "न्यायालय", "पोलिस स्टेशन", "जामीन", "विश्वासू मित्र", "धमकी", "पोलिस केस",

            # Kannada scam keywords
            "ಹಣ ಕಳುಹಿಸಿ", "ಬ್ಯಾಂಕ್ ಖಾತೆ", "ತಕ್ಷಣ", "ಪಾಸ್‌ವರ್ಡ್", "ಏಟಿಎಂ ಕಾರ್ಡ್", "ಓಟಿಪಿ", "ಇನ್ಶುರೆನ್ಸ್ ಪಾಲಿಸಿ", 
            "ರದ್ದು", "ಚೆಲ್ಲವಂಡಿ", "ಹೋಮ್ ಫ್ರಮ್ ಜಾಬ್", "ತಿಂಗಳಿಂದಿರು", "ಸಂಪಾದಿಸು", "ನೋಂದಣಿ ಫೀ", "ಲಾಟರಿ", "ಗೆದ್ದುವು", 
            "ಪ್ರಾಸೆಸಿಂಗ್ ಫೀ", "ಬಂಧನ", "ಪೊಲೀಸ್", "ಪ್ರಕರಣ", "ಖಾತೆ ನಿರ್ಬಂಧಿಸಲಾಗಿದೆ", "ಕೆವೈಸಿ", "ಪಿನ್", "ಹೂಡಿಕೆ", 
            "ವರ್ಕ್ ಫ್ರಮ್ ಹೋಮ್", "ವಿದ್ಯುತ್ ಕಡಿತ", "ಆಸ್ಪತ್ರೆಯಲ್ಲಿ", "ಅಪಘಾತ", "ತುರ್ತು", "ಆಧಾರ್", "ಪಾರ್ಸೆಲ್",
            "ಡಿಜಿಟಲ್ ಬಂಧನ", "ಕಸ್ಟಮ್ಸ್ ಅಧಿಕಾರಿ", "ಪಾರ್ಸೆಲ್ ತಡೆಹಿಡಿಯಲಾಗಿದೆ", "ಕಾನೂನುಬಾಹಿರ ವಸ್ತುಗಳು",
            "ವಿದ್ಯುತ್ ಬಿಲ್ ನವೀಕರಿಸಿಲ್ಲ", "ಇಂದು ರಾತ್ರಿ ವಿದ್ಯುತ್ ಕಡಿತ", "ಷೇರು ಮಾರುಕಟ್ಟೆ ಹೂಡಿಕೆ", "ಅರೆಕಾಲಿಕ ಕೆಲಸ",
            "ಗೂಗಲ್ ಮ್ಯಾಪ್ಸ್ ವಿಮರ್ಶೆ", "ಮುಂಗಡ ಪಾವತಿ", "ಓಟಿಪಿ ಹಂಚಿಕೊಳ್ಳಿ", "ಖಾತೆ ಫ್ರೀಜ್", "ತುರ್ತು ವೈದ್ಯಕೀಯ ನೆರವು",
            "ಪೊಲೀಸ್ ಅಧಿಕಾರಿ", "ಬಂಧನ ವಾರಂಟ್", "ಹಣ ವರ್ಗಾಯಿಸಿ", "ತಕ್ಷಣ ಹಣ ಕಳುಹಿಸಿ", "ವೀಡಿಯೊ ಕರೆ", "ಅಕ್ರಮ ವಹಿವಾಟು",
            "ಖಾತೆ ನಿರ್ಬಂಧಿಸಲಾಗುತ್ತದೆ", "ಬಹುಮಾನ ಗೆದ್ದಿದ್ದೀರಿ", "ಲೋನ್ ಆಪ್", "ಖಾಸಗಿ ವೀಡಿಯೊ", "ವೀಡಿಯೊ ಲೀಕ್", "ಲೋನ್ ಮರುಪಾವತಿಸಿ",
            "ಫೋನ್ ಕಳೆದುಹೋಗಿದೆ", "ಸ್ನೇಹಿತನ ಸಂಖ್ಯೆ", "ಆಸ್ಪತ್ರೆಗೆ ದಾಖಲಾಗಿದ್ದಾರೆ", "50000 ಬೇಕು", "ತುರ್ತು ಶಸ್ತ್ರಚಿಕಿತ್ಸೆ",
            "ವಾಟ್ಸಾಪ್ ಖಾತೆ", "ತೆರಿಗೆ ವಂಚನೆ", "ನ್ಯಾಯಾಲಯ", "ಪೊಲೀಸ್ ಠಾಣೆ", "ಜಾಮೀನು", "ವಿಶ್ವಾಸಾರ್ಹ ಸ್ನೇಹಿತ", "ಬೆದರಿಕೆ", "ಪೊಲೀಸ್ ಪ್ರಕರಣ",

            # Malayalam scam keywords
            "പണം അയച്ചു", "ബാങ്ക് അക്കൗണ്ട്", "ഉടൻ", "പാസ്‌വേഡ്", "എടിഎം കാർഡ്", "ഒടിപി", "ആശുപത്രിയിൽ", "പെട്ടി", 
            "ആവശ്യം", "ഇപ്പോ", "അയച്ചു", "നിക്ഷം സ്കീം", "നിക്ഷി", "ലഭിക്കും", "സർക്കാരി പദ്ധതി", "ലോട്ടറി", 
            "ജിക്കുക", "പ്രോസസിംഗ് ഫീ", "അറസ്റ്റ്", "പോലീസ്", "കേസ്", "അക്കൗണ്ട് ബ്ലോക്ക്", "കെവൈസി", "നിക്ഷേപം", 
            "വർക്ക് ഫ്രം ഹോം", "വൈദ്യുതി വിച്ഛേദിക്കും", "അപകടം", "അടിയന്തരം", "ആധാർ", "പാഴ്സൽ കസ്റ്റംസ്",
            "ഡിജിറ്റൽ അറസ്റ്റ്", "കസ്റ്റംസ് ഓഫീസർ", "പാഴ്സൽ തടഞ്ഞു", "നിയമവിരുദ്ധ വസ്തുക്കൾ", "വൈദ്യുതി ബിൽ അപ്ഡേറ്റ് ചെയ്തിട്ടില്ല",
            "ഇന്ന് രാത്രി വൈദ്യുതി വിച്ഛേദിക്കും", "ഓഹരി വിപണി നിക്ഷേപം", "പാർട്ട് ടൈം ജോലി", "ഗൂഗിൾ മാപ്സ് റിവ്യൂ",
            "മുൻകൂർ പേയ്‌മെന്റ്", "ഒടിപി പങ്കിടുക", "അക്കൗണ്ട് മരവിപ്പിച്ചു", "അടിയന്തര വൈദ്യസഹായം",
            "പോലീസ് ഓഫീസർ", "അറസ്റ്റ് വാറണ്ട്", "പണം കൈമാറുക", "ഉടൻ പണം അയക്കുക", "വീഡിയോ കോൾ", "നിയമവിരുദ്ധ ഇടപാട്",
            "അക്കൗണ്ട് ബ്ലോക്ക് ചെയ്യും", "സമ്മാനം നേടി", "ലോൺ ആപ്പ്", "സ്വകാര്യ വീഡിയോ", "വീഡിയോ ചോർന്നു", "ലോൺ തിരിച്ചടയ്ക്കുക",
            "ഫോൺ നഷ്ടപ്പെട്ടു", "സുഹൃത്തിന്റെ നമ്പർ", "ആശുപത്രിയിൽ പ്രവേശിപ്പിച്ചു", "50000 വേണം", "അടിയന്തര ശസ്ത്രക്രിയ",
            "വാട്ട്സ്ആപ്പ് അക്കൗണ്ട്", "നികുതി വെട്ടിപ്പ്", "കോടതി", "പോലീസ് സ്റ്റേഷൻ", "ജാമ്യം", "വിശ്വസ്ത സുഹൃത്ത്", "ഭീഷണി", "പോലീസ് കേസ്",

            # Punjabi scam keywords
            "ਪੈਸੇ ਭੇਜੋ", "ਬੈਂਕ ਖਾਤਾ", "ਤੁਰੰਤ", "ਪਾਸਵਰਡ", "ਏਟੀਐਮ ਕਾਰਡ", "ਓਟੀਪੀ", "ਘਰ ਫਰਮ ਜੌਬ", "ਮਹੀਨੇ", "ਰੁਪਏ", 
            "ਕਮਾਓ", "ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਫੀ", "ਦੇਓ", "ਲਾਟਰੀ", "ਜਿੱਤੇ", "ਪ੍ਰੋਸੈਸਿੰਗ ਫੀ", "ਹਸਪਤਾਲ", "ਲੋੜ", "ਗ੍ਰਿਫਤਾਰ", "ਪੁਲਿਸ", 
            "ਕੇਸ", "ਖਾਤਾ ਬਲਾਕ", "ਕੇਵਾਈਸੀ", "ਪਿੰਨ", "ਨਿਵੇਸ਼", "ਵਰਕ ਫਰੌਮ ਹੋਮ", "ਹਸਪਤਾਲ ਵਿੱਚ", "ਐਕਸੀਡੈਂਟ", "ਐਮਰਜੈਂਸੀ",
            "ਡਿਜੀਟਲ ਗ੍ਰਿਫਤਾਰ", "ਕਸਟਮ ਅਫਸਰ", "ਪਾਰਸਲ ਰੋਕਿਆ ਗਿਆ", "ਗੈਰ-ਕਾਨੂੰਨੀ ਚੀਜ਼ਾਂ", "ਬਿਜਲੀ ਦਾ ਬਿੱਲ ਅਪਡੇਟ ਨਹੀਂ ਹੋਇਆ",
            "ਅੱਜ ਰਾਤ ਬਿਜਲੀ ਕੱਟ", "ਸ਼ੇਅਰ ਬਾਜ਼ਾਰ ਨਿਵੇਸ਼", "ਪਾਰਟ ਟਾਈਮ ਨੌਕਰੀ", "ਗੂਗਲ ਮੈਪਸ ਰਿਵਿਊ", "ਐਡਵਾਂਸ ਪੇਮੈਂਟ",
            "ਓਟੀਪੀ ਦੱਸੋ", "ਖਾਤਾ ਫ੍ਰੀਜ਼", "ਤੁਰੰਤ ਡਾਕਟਰੀ ਮਦਦ",
            "ਪੁਲਿਸ ਅਫਸਰ", "ਗ੍ਰਿਫਤਾਰੀ ਵਾਰੰਟ", "ਪੈਸੇ ਟ੍ਰਾਂਸਫਰ ਕਰੋ", "ਤੁਰੰਤ ਪੈਸੇ ਭੇਜੋ", "ਵੀਡੀਓ ਕਾਲ", "ਗੈਰ-ਕਾਨੂੰਨੀ ਲੈਣ-ਦੇਣ",
            "ਖਾਤਾ ਬਲਾਕ ਕੀਤਾ ਜਾਵੇਗਾ", "ਇਨਾਮ ਜਿੱਤਿਆ", "ਲੋਨ ਐਪ", "ਪ੍ਰਾਈਵੇਟ ਵੀਡੀਓ", "ਵੀਡੀਓ ਲੀਕ", "ਲੋਨ ਵਾਪਸ ਕਰੋ",
            "ਫੋਨ ਗੁੰਮ ਹੋ ਗਿਆ", "ਦੋਸਤ ਦਾ ਨੰਬਰ", "ਹਸਪਤਾਲ ਵਿੱਚ ਦਾਖਲ", "50000 ਚਾਹੀਦੇ", "ਤੁਰੰਤ ਸਰਜਰੀ",
            "ਵਟਸਐਪ ਖਾਤਾ", "ਟੈਕਸ ਚੋਰੀ", "ਅਦਾਲਤ", "ਪੁਲਿਸ ਸਟੇਸ਼ਨ", "ਜ਼ਮਾਨਤ", "ਭਰੋਸੇਮੰਦ ਦੋਸਤ", "ਧਮਕੀ", "ਪੁਲਿਸ ਕੇਸ",

            # Gujarati scam keywords
            "પૈસા મોકલો", "બેંક એકાઉન્ટ", "તાત્કાળ", "પાસવર્ડ", "એટીએમ કાર્ડ", "ઓટીપી", "ગુંતવનિકી સ્કીમ", "ગુંતવ", 
            "મળો", "સરકારારી યોજના", "લોટરી", "જીત્યો", "પ્રોસેસિંગ ફી", "ઇન્શ્યરન્સ પાલિસી", "રદ્દુ", "ચૂલવંડી", 
            "પાલીશ", "ધરપકડ", "પોલીસ", "કેસ", "એકાઉન્ટ બ્લોક", "કેવાયસી", "પિન", "રોકાણ", "વર્ક ફ્રોમ હોમ", "શેર બજાર", 
            "વીજળી કાપી", "હોસ્પિટલમાં", "અકસ્માત", "ઇમરજન્સી", "આધાર", "કસ્ટમ્સ",
            "ડિજિટલ ધરપકડ", "કસ્ટમ્સ અધિકારી", "પાર્સલ બ્લોક કરવામાં આવ્યું", "ગેરકાયદેસર વસ્તુઓ", "વીજળીનું બિલ અપડેટ નથી",
            "આજે રાત્રે વીજળી કાપ", "શેર બજારમાં રોકાણ", "પાર્ટ ટાઇમ નોકરી", "ગૂગલ મેપ્સ રિવ્યુ", "એડવાન્સ પેમેન્ટ",
            "ઓટીપી શેર કરો", "એકાઉન્ટ ફ્રીઝ", "તાત્કાલિક તબીબી સહાય",
            "પોલીસ અધિકારી", "ધરપકડ વોરંટ", "પૈસા ટ્રાન્સફર કરો", "તાત્કાલિક પૈસા મોકલો", "વિડિયો કૉલ", "ગેરકાયદેસર વ્યવહાર",
            "એકાઉન્ટ બ્લોક કરવામાં આવશે", "ઇનામ જીત્યું", "લોન એપ", "ખાનગી વિડિઓ", "વિડિઓ લીક", "લોન પરત કરો",
            "ફોન ખોવાઈ ગયો", "મિત્રનો નંબર", "હોસ્પિટલમાં દાખલ", "50000 જોઈએ", "તાત્કાલિક સર્જરી",
            "વોટ્સએપ એકાઉન્ટ", "કરચોરી", "કોર્ટ", "પોલીસ સ્ટેશન", "જામીન", "વિશ્વસનીય મિત્ર", "ધમકી", "પોલીસ કેસ",
            # Missing: ELECTRICITY THREAT (bijli kategi update + pay link)
            "update karein bijli", "update meter", "electricity update", "bijli update",
            "abhi update karo", "tonight bijli", "aaj raat bijli", "bijli kategi update",
            # Missing: INTERNAL AUDIT PHISHING
            "internal audit", "confirm your account number", "confirm account for audit",
            "routine audit", "account audit", "verification audit",
            # Missing: AUTHORITY SCAM (cyber crime dept + complaint)
            "received a complaint against your number", "complaint against your number",
            "cyber crime department", "cyber crime cell", "complaint filed against",
            "statement required from you", "don't disconnect", "just a statement",
            # Missing: FD MATURITY INVESTMENT FRAUD
            "fd maturity", "reinvest karna chahenge", "fd reinvest", "maturity reinvest",
            "guaranteed returns of 12", "guaranteed 12%", "12% per year",
            "new scheme with guaranteed", "our naya scheme", "ek naya scheme",
            # Drug trafficking / SIM misuse
            "drug trafficking", "sim used for drug", "sim activate for", "sim linked to drug",
            "cbi custody", "2 lakh bhejo", "custody mein aana",
            # LOAN SCAM - CIBIL
            "cibil score", "pre-approved personal loan", "no documents", "bas otp share",
            "pre-approved loan", "loan without documents"
        ]
        
        legitimate_indicators = [
            "credit card benefits", "customer service", "new credit card", "inform you about",
            "health insurance plan", "vaccination camp", "package has arrived", "OTP to complete delivery",
            "bill is due", "appointment scheduled", "FD is maturing", "fixed deposit",
            "would you like to know", "register for vaccination", "collect it within",
            "insurance plan that might interest", "premium payment", "discount if you renew",
            "booking confirmation", "service complete", "meeting scheduled", "progress",
            "official website", "official app", "visit our website", "walk-in allowed",
            "meter reading", "consumption", "due date", "no rush", "just reminder",
            "schedule an interview", "standard recruitment process", "no fees involved",
            "discharge is processed", "pick up medicines", "hospital counter",
            "vaccines available", "community center", "next camp is at", "health department",
            "seen your profile on linkedin", "no payment required now", "just information",
            "verify your identity before delivery", "hand over the package",
            # Extreme twisted legitimate keywords
            "you had called us earlier", "requested callback", "date of birth",
            "mother's maiden name", "for security", "already blocked those sim cards",
            "no action needed", "informing you as per government regulations",
            "case is listed for hearing", "you are a witness", "no payment required",
            "just notification", "witness", "conducting maintenance", "intermittent network",
            "service will be restored", "no action needed", "government welfare scheme",
            "no agent needed", "direct application", "no fees for application",
            "temporarily frozen", "visit your nearest branch", "id proof and pan card",
            "no phone or online resolution", "security measure", "within 7 days",
            "customer satisfaction survey", "research agency", "not ask for any personal",
            "participation is voluntary", "waiting 3-4 days", "no advance payment",
            "pay at delivery", "all customers treated equally", "due next week",
            "grace period", "no urgency", "late payment penalty", "no discounts available",
            "volunteers needed", "bring food items directly", "no cash donations",
            "visit our center", "do not expire", "check rewards section", "no processing fee",
            "we saw your profile", "would like to schedule interview", "no fees involved",
            "satisfaction survey", "participation voluntary", "not asking for personal info",
            "intermittent network possible", "service will restore automatically", "no action needed",            # Tamil legitimate keywords
            "இலவசமாக", "பணம் தேவையில்லை", "அதிகாரப்பூர்வ வலைத்தளம்", "தகவல் மட்டும்", "பதிவு கட்டணம் இல்லை", "பாதுகாப்பான",
            "எந்த கட்டணமும் இல்லை", "உங்கள் நேரத்தை எடுத்துக்கொள்ளுங்கள்", "அவசரம் இல்லை", "அதிகாரப்பூர்வ ஆப்", "அரசு வலைத்தளம்",
            "நினைவூட்டல் மட்டுமே", "தடுப்பூசி இலவசம்", "நேரடியாக மருத்துவமனையில் செலுத்துங்கள்", "முன்பணம் தேவையில்லை",
            "தனிப்பட்ட தகவல்கள் தேவையில்லை", "விருப்பத்தின் பேரில்", "வாடிக்கையாளர் சேவை", "உதவி மைய எண்",
            "பணம் செலுத்த தேவையில்லை", "பணம் கேட்க மாட்டோம்", "இது ஒரு தகவல் மட்டுமே", "எச்சரிக்கை",
            "உங்கள் பிரச்சனை தீர்க்கப்பட்டுள்ளது", "டிக்கெட் உறுதிப்படுத்தப்பட்டுள்ளது", "பார்சல் டெலிவரிக்கு வந்துள்ளது",
            "நேர்முகத் தேர்விற்கு அழைப்பு", "எந்த கட்டணமும் வசூலிக்கப்படாது", "மாதத்தவணை நினைவூட்டல்",
            "கிளைக்கு நேரில் வாருங்கள்", "அறிக்கை தயாராக உள்ளது", "இலவச மருத்துவ முகாம்", "வாடிக்கையாளர் கருத்துக்கணிப்பு",
            "மீட்டர் ரீடிங் எடுக்கப்பட்டுள்ளது", "பயணச்சீட்டு உறுதி", "பணம் செலுத்த வேண்டாம்", "பாதுகாப்பு விழிப்புணர்வு",
            "டெலிவரி ஏஜென்ட்", "தவணைத் தேதி", "பரிவர்த்தனை வெற்றிகரமானது", "உங்கள் கணக்கு பாதுகாப்பாக உள்ளது",
            "கூடுதல் கட்டணம் இல்லை", "நேரடி விண்ணப்பம்", "இலவச சேவை", "உதவிக்கு அழைக்கவும்", "வாடிக்கையாளர் மையம்",
            "பாஸ்வேர்ட் பகிர வேண்டாம்", "ஓடிபி பகிர வேண்டாம்", "வங்கி ஊழியர் என்று நம்ப வேண்டாம்", "தகவல் உறுதிப்படுத்தல்",

            # Telugu legitimate keywords
            "ఉచితమైనది", "డబ్బు అవసరం లేదు", "అధికార వెబ్‌సైట్", "సమాచారం మాత్రమే", "రుసుము లేదు", "సురక్షితమైనది",
            "ఎటువంటి ఫీజు లేదు", "మీ సమయం తీసుకోండి", "తొందర లేదు", "అధికారిక యాప్", "ప్రభుత్వ వెబ్‌సైట్",
            "రిమైండర్ మాత్రమే", "వ్యాక్సిన్ ఉచితం", "ఆసుపత్రిలో నేరుగా చెల్లించండి", "అడ్వాన్స్ అవసరం లేదు",
            "వ్యక్తిగత సమాచారం అవసరం లేదు", "మీ ఇష్టం", "కస్టమర్ సర్వీస్", "హెల్ప్‌లైన్ నంబర్",
            "డబ్బు చెల్లించాల్సిన అవసరం లేదు", "మేము డబ్బు అడగము", "ఇది కేవలం సమాచారం", "హెచ్చరిక",
            "మీ సమస్య పరిష్కరించబడింది", "టికెట్ కన్ఫర్మ్ అయింది", "పార్సెల్ డెలివరీకి వచ్చింది",
            "ఇంటర్వ్యూకి ఆహ్వానం", "ఎటువంటి ఫీజు వసూలు చేయబడదు", "ఈఎంఐ రిమైండర్", "బ్రాంచ్‌కి నేరుగా రండి",
            "రిపోర్ట్ సిద్ధంగా ఉంది", "ఉచిత వైద్య శిబిరం", "కస్టమర్ సర్వే", "మీటర్ రీడింగ్ తీసుకోబడింది",
            "డబ్బు చెల్లించవద్దు", "భద్రతా అవగాహన", "డెలివరీ ఏజెంట్", "గడువు తేదీ", "లావాదేవీ విజయవంతమైంది",
            "మీ ఖాతా సురక్షితంగా ఉంది", "అదనపు ఛార్జీలు లేవు", "డైరెక్ట్ అప్లికేషన్", "ఉచిత సేవ", "సహాయం కోసం కాల్ చేయండి",
            "కస్టమర్ కేర్", "పాస్‌వర్డ్ పంచుకోవద్దు", "ఓటీపీ పంచుకోవద్దు", "బ్యాంక్ సిబ్బందిని నమ్మవద్దు", "సమాచార నిర్ధారణ",

            # Bengali legitimate keywords
            "বিনামূল্যে", "টাকা লাগবে না", "অফিসিয়াল ওয়েবসাইট", "শুধু তথ্য", "কোন ফি নেই", "নিরাপদ",
            "কোনো চার্জ নেই", "তাড়াহুড়ো নেই", "সময় নিন", "অফিসিয়াল অ্যাপ", "সরকারি ওয়েবসাইট",
            "শুধুমাত্র মনে করিয়ে দেওয়া", "টিকা বিনামূল্যে", "সরাসরি হাসপাতালে পেমেন্ট করুন", "কোনো অগ্রিম পেমেন্ট নেই",
            "ব্যক্তিগত তথ্যের প্রয়োজন নেই", "আপনার ইচ্ছানুযায়ী", "কাস্টমার সার্ভিস", "হেল্পলাইন নম্বর",
            "টাকা দেওয়ার দরকার নেই", "আমরা টাকা চাইব না", "এটি কেবল একটি তথ্য", "সতর্কতা",
            "আপনার সমস্যার সমাধান হয়েছে", "টিকিট নিশ্চিত করা হয়েছে", "পার্সেল ডেলিভারির জন্য এসেছে",
            "সাক্ষাৎকারের জন্য আমন্ত্রণ", "কোনো ফি নেওয়া হবে না", "ইএমআই রিমাইন্ডার", "শাখায় সরাসরি আসুন",
            "রিপোর্ট প্রস্তুত আছে", "বিনামূল্যে মেডিকেল ক্যাম্প", "গ্রাহক সমীক্ষা", "মিটার রিডিং নেওয়া হয়েছে",
            "টাকা দেবেন না", "নিরাপত্তা সচেতনতা", "ডেলিভারি এজেন্ট", "শেষ তারিখ", "লেনদেন সফল হয়েছে",
            "আপনার অ্যাকাউন্ট নিরাপদ আছে", "অতিরিক্ত কোনো চার্জ নেই", "সরাসরি আবেদন", "ফ্রি সার্ভিস",
            "সাহায্যের জন্য কল করুন", "কাস্টমার কেয়ার", "পাসওয়ার্ড শেয়ার করবেন না", "ওটিপি শেয়ার করবেন না",
            "ব্যাংক কর্মী বলে বিশ্বাস করবেন না", "তথ্য নিশ্চিতকরণ",

            # Marathi legitimate keywords
            "मोफत", "पैसे लागणार नाहीत", "अधिकृत वेबसाइट", "फक्त माहिती", "कोणतेही शुल्क नाही", "सुरक्षित",
            "कोणताही चार्ज नाही", "घाई नाही", "वेळ घ्या", "अधिकृत ॲप", "सरकारी वेबसाइट",
            "फक्त आठवण", "लस मोफत आहे", "थेट रुग्णालयात पैसे द्या", "कोणतेही आगाऊ पेमेंट नाही",
            "वैयक्तिक माहितीची गरज नाही", "तुमच्या इच्छेनुसार", "ग्राहक सेवा", "हेल्पलाइन नंबर",
            "पैसे देण्याची गरज नाही", "आम्ही पैसे मागत नाही", "ही फक्त माहिती आहे", "इशारा",
            "तुमची समस्या सुटली आहे", "तिकीट कन्फर्म झाले आहे", "पार्सल डिलिव्हरीसाठी आले आहे",
            "मुलाखतीसाठी बोलावणे", "कोणतीही फी आकारली जाणार नाही", "ईएमआय रिमाइंडर", "थेट शाखेत या",
            "रिपोर्ट तयार आहे", "मोफत वैद्यकीय शिबिर", "ग्राहक सर्वेक्षण", "मीटर रीडिंग घेण्यात आले आहे",
            "पैसे देऊ नका", "सुरक्षा जागरूकता", "डिलिव्हरी एजंट", "शेवटची तारीख", "व्यवहार यशस्वी झाला आहे",
            "तुमचे खाते सुरक्षित आहे", "कोणतेही अतिरिक्त शुल्क नाही", "थेट अर्ज", "फ्री सर्विस",
            "मदतीसाठी कॉल करा", "कस्टमर केअर", "पासवर्ड शेअर करू नका", "ओटीपी शेअर करू नका",
            "बँक कर्मचारी असल्याचा विश्वास ठेवू नका", "माहिती निश्चिती",

            # Kannada legitimate keywords
            "ಉಚಿತ", "ಹಣ ಅಗತ್ಯವಿಲ್ಲ", "ಅಧಿಕೃತ ವೆಬ್‌ಸೈಟ್", "ಮಾಹಿತಿ ಮಾತ್ರ", "ಯಾವುದೇ ಶುಲ್ಕವಿಲ್ಲ", "ಸುರಕ್ಷಿತ",
            "ಯಾವುದೇ ಶುಲ್ಕವಿಲ್ಲ", "ಅವಸರವಿಲ್ಲ", "ಸಮಯ ತೆಗೆದುಕೊಳ್ಳಿ", "ಅಧಿಕೃತ ಆಪ್", "ಸರ್ಕಾರಿ ವೆಬ್‌ಸೈಟ್",
            "ಜ್ಞಾಪನೆ ಮಾತ್ರ", "ಲಸಿಕೆ ಉಚಿತ", "ನೇರವಾಗಿ ಆಸ್ಪತ್ರೆಯಲ್ಲಿ ಪಾವತಿಸಿ", "ಯಾವುದೇ ಮುಂಗಡ ಪಾವತಿ ಇಲ್ಲ",
            "ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ ಅಗತ್ಯವಿಲ್ಲ", "ನಿಮ್ಮ ಇಚ್ಛೆಯಂತೆ", "ಗ್ರಾಹಕ ಸೇವೆ", "ಸಹಾಯವಾಣಿ ಸಂಖ್ಯೆ",
            "ಹಣ ಪಾವತಿಸುವ ಅಗತ್ಯವಿಲ್ಲ", "ನಾವು ಹಣ ಕೇಳುವುದಿಲ್ಲ", "ಇದು ಕೇವಲ ಮಾಹಿತಿ", "ಎಚ್ಚರಿಕೆ",
            "ನಿಮ್ಮ ಸಮಸ್ಯೆ ಬಗೆಹರಿದಿದೆ", "ಟಿಕೆಟ್ ಖಚಿತವಾಗಿದೆ", "ಪಾರ್ಸೆಲ್ ವಿತರಣೆಗೆ ಬಂದಿದೆ",
            "ಸಂದರ್ಶನಕ್ಕೆ ಆಹ್ವಾನ", "ಯಾವುದೇ ಶುಲ್ಕ ವಿಧಿಸಲಾಗುವುದಿಲ್ಲ", "ಇಎಂಐ ಜ್ಞಾಪನೆ", "ಶಾಖೆಗೆ ನೇರವಾಗಿ ಬನ್ನಿ",
            "ವರದಿ ಸಿದ್ಧವಾಗಿದೆ", "ಉಚಿತ ವೈದ್ಯಕೀಯ ಶಿಬಿರ", "ಗ್ರಾಹಕ ಸಮೀಕ್ಷೆ", "ಮೀಟರ್ ಓದುವಿಕೆ ತೆಗೆದುಕೊಳ್ಳಲಾಗಿದೆ",
            "ಹಣ ಪಾವತಿಸಬೇಡಿ", "ಭದ್ರತಾ ಜಾಗೃತಿ", "ವಿತರಣಾ ಏಜೆಂಟ್", "ಕೊನೆಯ ದಿನಾಂಕ", "ವಹಿವಾಟು ಯಶಸ್ವಿಯಾಗಿದೆ",
            "ನಿಮ್ಮ ಖಾತೆ ಸುರಕ್ಷಿತವಾಗಿದೆ", "ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ಶುಲ್ಕವಿಲ್ಲ", "ನೇರ ಅರ್ಜಿ", "ಉಚಿತ ಸೇವೆ",
            "ಸಹಾಯಕ್ಕಾಗಿ ಕರೆ ಮಾಡಿ", "ಗ್ರಾಹಕ ಆರೈಕೆ", "ಪಾಸ್‌ವರ್ಡ್ ಹಂಚಿಕೊಳ್ಳಬೇಡಿ", "ಓಟಿಪಿ ಹಂಚಿಕೊಳ್ಳಬೇಡಿ",
            "ಬ್ಯಾಂಕ್ ಸಿಬ್ಬಂದಿ ಎಂದು ನಂಬಬೇಡಿ", "ಮಾಹಿತಿ ದೃಢೀಕರಣ",

            # Malayalam legitimate keywords
            "സൗജന്യമായി", "പണം ആവശ്യമില്ല", "ഔദ്യോഗിക വെബ്‌സൈറ്റ്", "വിവരം മാത്രം", "ഫീസ് ഇല്ല", "സുരക്ഷിതം",
            "യാതൊരു നിരക്കും ഇല്ല", "തിരക്കില്ല", "സമയം എടുക്കുക", "ഔദ്യോഗിക ആപ്പ്", "സർക്കാർ വെബ്സൈറ്റ്",
            "ഓർമ്മപ്പെടുത്തൽ മാത്രം", "വാക്സിൻ സൗജന്യമാണ്", "നേരിട്ട് ആശുപത്രിയിൽ പണമടയ്ക്കുക", "മുൻകൂർ പണമടയ്ക്കേണ്ടതില്ല",
            "വ്യക്തിഗത വിവരങ്ങൾ ആവശ്യമില്ല", "നിങ്ങളുടെ ഇഷ്ടപ്രകാരം", "കസ്റ്റമർ സർവീസ്", "ഹെൽപ്പ്ലൈൻ നമ്പർ",
            "പണം നൽകേണ്ടതില്ല", "ഞങ്ങൾ പണം ചോദിക്കില്ല", "ഇത് ഒരു വിവരണം മാത്രം", "മുന്നറിയിപ്പ്",
            "നിങ്ങളുടെ പ്രശ്നം പരിഹരിച്ചു", "ടിക്കറ്റ് സ്ഥിരീകരിച്ചു", "പാഴ്സൽ ഡെലിവറിക്ക് എത്തിയിട്ടുണ്ട്",
            "അഭിമുഖത്തിനുള്ള ക്ഷണം", "യാതൊരു ഫീസും ഈടാക്കില്ല", "ഇഎംഐ ഓർമ്മപ്പെടുത്തൽ", "ശാഖയിൽ നേരിട്ട് വരിക",
            "റിപ്പോർട്ട് തയ്യാറാണ്", "സൗജന്യ മെഡിക്കൽ ക്യാമ്പ്", "കസ്റ്റമർ സർവേ", "മീറ്റർ റീഡിംഗ് എടുത്തു",
            "പണം നൽകരുത്", "സുരക്ഷാ ബോധവൽക്കരണം", "ഡെലിവറി ഏജന്റ്", "അവസാന തീയതി", "ഇടപാട് വിജയകരമായി പൂർത്തിയായി",
            "നിങ്ങളുടെ അക്കൗണ്ട് സുരക്ഷിതമാണ്", "അധിക നിരക്കുകളില്ല", "നേരിട്ടുള്ള അപേക്ഷ", "സൗജന്യ സേവനം",
            "സഹായത്തിനായി വിളിക്കുക", "കസ്റ്റമർ കെയർ", "പാസ്സ്‌വേർഡ് പങ്കിടരുത്", "ഒടിപി പങ്കിടരുത്",
            "ബാങ്ക് ഉദ്യോഗസ്ഥൻ എന്ന് വിശ്വസിക്കരുത്", "വിവരം സ്ഥിരീകരിച്ചു",

            # Punjabi legitimate keywords
            "ਮੁਫ਼ਤ", "ਪੈਸੇ ਦੀ ਲੋੜ ਨਹੀਂ", "ਅਧਿਕਾਰੀ ਵੈੱਬਸਾਈਟ", "ਸਿਰਫ਼ ਜਾਣਕਾਰੀ", "ਕੋਈ ਫੀਸ ਨਹੀਂ", "ਸੁਰੱਖਿਅਤ",
            "ਕੋਈ ਖਰਚਾ ਨਹੀਂ", "ਕੋਈ ਕਾਹਲੀ ਨਹੀਂ", "ਆਪਣਾ ਸਮਾਂ ਲਓ", "ਅਧਿਕਾਰਤ ਐਪ", "ਸਰਕਾਰੀ ਵੈੱਬਸਾਈਟ",
            "ਸਿਰਫ਼ ਯਾਦ ਦਿਵਾਉਣਾ", "ਟੀਕਾ ਮੁਫ਼ਤ ਹੈ", "ਸਿੱਧਾ ਹਸਪਤਾਲ ਵਿੱਚ ਭੁਗਤਾਨ ਕਰੋ", "ਕੋਈ ਐਡਵਾਂਸ ਭੁਗਤਾਨ ਨਹੀਂ",
            "ਨਿੱਜੀ ਜਾਣਕਾਰੀ ਦੀ ਲੋੜ ਨਹੀਂ", "ਤੁਹਾਡੀ ਮਰਜ਼ੀ", "ਗਾਹਕ ਸੇਵਾ", "ਹੈਲਪਲਾਈਨ ਨੰਬਰ",
            "ਪੈਸੇ ਦੇਣ ਦੀ ਲੋੜ ਨਹੀਂ", "ਅਸੀਂ ਪੈਸੇ ਨਹੀਂ ਮੰਗਦੇ", "ਇਹ ਸਿਰਫ਼ ਜਾਣਕਾਰੀ ਹੈ", "ਚੇਤਾਵਨੀ",
            "ਤੁਹਾਡੀ ਸਮੱਸਿਆ ਹੱਲ ਹੋ ਗਈ ਹੈ", "ਟਿਕਟ ਪੱਕੀ ਹੋ ਗਈ ਹੈ", "ਪਾਰਸਲ ਡਿਲਿਵਰੀ ਲਈ ਆ ਗਿਆ ਹੈ",
            "ਇੰਟਰਵਿਊ ਲਈ ਬੁਲਾਵਾ", "ਕੋਈ ਫੀਸ ਨਹੀਂ ਲਈ ਜਾਵੇਗੀ", "ਈਐਮਆਈ ਰੀਮਾਈਂਡਰ", "ਸਿੱਧਾ ਬ੍ਰਾਂਚ ਵਿੱਚ ਆਓ",
            "ਰਿਪੋਰਟ ਤਿਆਰ ਹੈ", "ਮੁਫਤ ਮੈਡੀਕਲ ਕੈਂਪ", "ਗਾਹਕ ਸਰਵੇਖਣ", "ਮੀਟਰ ਰੀਡਿੰਗ ਲੈ ਲਈ ਗਈ ਹੈ",
            "ਪੈਸੇ ਨਾ ਦਿਓ", "ਸੁਰੱਖਿਆ ਜਾਗਰੂਕਤਾ", "ਡਿਲਿਵਰੀ ਏਜੰਟ", "ਆਖਰੀ ਤਾਰੀਖ", "ਲੈਣ-ਦੇਣ ਸਫਲ ਰਿਹਾ",
            "ਤੁਹਾਡਾ ਖਾਤਾ ਸੁਰੱਖਿਅਤ ਹੈ", "ਕੋਈ ਵਾਧੂ ਖਰਚਾ ਨਹੀਂ", "ਸਿੱਧੀ ਅਰਜ਼ੀ", "ਮੁਫਤ ਸੇਵਾ",
            "ਮਦਦ ਲਈ ਕਾਲ ਕਰੋ", "ਕਸਟਮਰ ਕੇਅਰ", "ਪਾਸਵਰਡ ਸਾਂਝਾ ਨਾ ਕਰੋ", "ਓਟੀਪੀ ਸਾਂਝਾ ਨਾ ਕਰੋ",
            "ਬੈਂਕ ਕਰਮਚਾਰੀ ਹੋਣ ਦਾ ਵਿਸ਼ਵਾਸ ਨਾ ਕਰੋ", "ਜਾਣਕਾਰੀ ਦੀ ਪੁਸ਼ਟੀ",

            # Gujarati legitimate keywords
            "મફત", "પૈસાની જરૂર નથી", "અધિકૃત વેબસાઇટ", "માહિતી માત્ર", "કોઈ ફી નથી", "સલામત",
            "કોઈ ચાર્જ નથી", "કોઈ ઉતાવળ નથી", "તમારો સમય લો", "સત્તાવાર એપ્લિકેશન", "સરકારી વેબસાઇટ",
            "માત્ર રીમાઇન્ડર", "રસી મફત છે", "સીધા હોસ્પિટલમાં ચૂકવો", "કોઈ એડવાન્સ પેમેન્ટ નથી",
            "વ્યક્તિગત માહિતીની જરૂર નથી", "તમારી ઈચ્છા મુજબ", "ગ્રાહક સેવા", "હેલ્પલાઇન નંબર",
            "પૈસા ચૂકવવાની જરૂર નથી", "અમે પૈસા માંગતા નથી", "આ માત્ર માહિતી છે", "ચેતવણી",
            "તમારી સમસ્યા હલ થઈ ગઈ છે", "ટિકિટ કન્ફર્મ થઈ ગઈ છે", "પાર્સલ ડિલિવરી માટે આવી ગયું છે",
            "ઇન્ટરવ્યુ માટે આમંત્રણ", "કોઈ ફી લેવામાં આવશે નહીં", "ઇએમઆઈ રીમાઇન્ડર", "સીધા બ્રાન્ચમાં આવો",
            "રિપોર્ટ તૈયાર છે", "મફત મેડિકલ કેમ્પ", "ગ્રાહક સર્વેક્ષણ", "મીટર રીડિંગ લેવામાં આવ્યું છે",
            "પૈસા આપશો નહીં", "સુરક્ષા જાગૃતિ", "ડિલિવરી એજન્ટ", "છેલ્લી તારીખ", "વ્યવહાર સફળ રહ્યો",
            "તમારું એકાઉન્ટ સુરક્ષિત છે", "કોઈ વધારાનો ચાર્જ નથી", "સીધી અરજી", "મફત સેવા",
            "મદદ માટે કૉલ કરો", "કસ્ટમર કેર", "પાસવર્ડ શેર કરશો નહીં", "ઓટીપી શેર કરશો નહીં",
            "બેંક કર્મચારી હોવા પર વિશ્વાસ ન કરો", "માહિતીની પુષ્ટિ",            # Hindi/Hinglish legitimate keywords
            "mukt", "paise ki zarurat nahi", "adhikar website", "sirf jankari", "free service", "no money needed", "official website",
            "koi charge nahi", "koi jaldi nahi", "official app", "government website", "sarkari website",
            "sirf reminder", "vaccine free hai", "hospital mein pay karein", "koi advance nahi",
            "personal details nahi chahiye", "customer care", "helpline number", "paise mat dena",
            "hum paise nahi mangte", "yeh bas information hai", "alert", "savdhaan", "satark",
            "aapki complaint resolve ho gayi", "ticket confirm ho gaya", "parcel out for delivery",
            "interview ke liye invite", "koi fees nahi lagegi", "emi ka reminder", "branch mein directly aakar",
            "report ready hai", "free medical camp", "customer survey", "meter reading le li gayi hai",
            "paise pay mat karna", "security awareness", "delivery agent", "due date hai", "transaction successful",
            "aapka account safe hai", "koi extra charge nahi", "direct apply karein", "free consultation",
            "help ke liye call karein", "customer support", "password share mat karna", "otp mat batana",
            "bank wale kabhi otp nahi mangte", "information confirm karna tha", "app se payment karein",
            "aaram se padh lijiye", "koi penalty nahi hai", "aapki request accept ho gayi hai", "bill bhej diya gaya hai"
        ]


        
        # Additional negative indicators - these indicate legitimate call
        negative_indicators = [
            "no payment required", "no money", "no fees", "not asking for money",
            "free of cost", "no charge", "complimentary", "without any payment",
            "just information", "just reminder", "no urgency", "take your time",
            "visit official website", "government website", "official app",
            "no rush", "no payment required now", "vaccine is free", "no registration fee",
            "at hospital counter", "pay at hospital counter",
            "no agent needed", "direct application", "no fees for application",
            "no phone or online resolution", "security measure",
            "not ask for any personal", "participation is voluntary",
            "pay at delivery", "all customers treated equally",
            "grace period", "no urgency", "no discounts available",
            "bring food items directly", "no cash donations",
            "do not expire", "no processing fee"
        ]
        
        transcript_lower = transcript.lower()
        
        scam_score = sum(1 for keyword in scam_keywords if keyword.lower() in transcript_lower)
        legitimate_score = sum(1 for keyword in legitimate_indicators if keyword.lower() in transcript_lower)
        negative_score = sum(1 for keyword in negative_indicators if keyword.lower() in transcript_lower)
        
        # Special handling for bank freeze - legitimate if "visit branch" present
        if "account freeze" in transcript_lower and "visit your nearest branch" in transcript_lower:
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Legitimate account freeze requiring branch visit"
            }
        
        # Special handling for callback scenario - legitimate if "you had called us" present
        if "you had called us" in transcript_lower and legitimate_score >= 2:
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Legitimate callback scenario with verification"
            }
        
        # Bank service call - if customer service + credit card benefits + would you like to know
        if "customer service" in transcript_lower and "credit card benefits" in transcript_lower:
            if "would you like to know" in transcript_lower and scam_score <= 1:
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate bank service call - informational only"
                }
        
        # Callback scenario - if caller says you called them first, it's likely legitimate
        if "you had called us earlier" in transcript_lower or "requested callback" in transcript_lower:
            # BUT: if they still ask for card/account details, it's a scam
            if not ("card" in transcript_lower or "atm" in transcript_lower or "account" in transcript_lower):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Callback scenario - user initiated contact first"
                }
        
        # Date of birth verification - if only asking for DOB without payment/card details, likely legitimate
        if "date of birth" in transcript_lower and scam_score <= 2:
            if not ("pay" in transcript_lower or "card" in transcript_lower or "atm" in transcript_lower or "account" in transcript_lower):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate verification - only DOB requested"
                }
        
        # Callback verification exception - if callback + date of birth + no payment/card/account
        if ("you had called us earlier" in transcript_lower or "requested callback" in transcript_lower) and "date of birth" in transcript_lower:
            if not ("pay" in transcript_lower or "card" in transcript_lower or "atm" in transcript_lower or "account" in transcript_lower or "otp" in transcript_lower or "password" in transcript_lower):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate callback verification - only DOB requested"
                }
        
        # Bank customer service callback - if customer service + credit card statement + date of birth
        if "customer service" in transcript_lower and "credit card statement" in transcript_lower and "date of birth" in transcript_lower:
            if not ("pay" in transcript_lower or "card number" in transcript_lower or "atm" in transcript_lower or "account number" in transcript_lower or "otp" in transcript_lower or "password" in transcript_lower or "cvv" in transcript_lower):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate bank callback - DOB verification for statement inquiry"
                }
        
        # Maintenance notification - if maintenance + scheduled + no action needed
        if "maintenance" in transcript_lower and "scheduled" in transcript_lower:
            if "no action needed" in transcript_lower or "service will restore" in transcript_lower:
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate maintenance notification - no action required"
                }
        
        # Punjabi legitimate override - check specifically for legitimate phrase
        if "ਮੁਫ਼ਤ" in transcript_lower and "ਪੈਸੇ ਦੀ ਲੋੜ ਨਹੀਂ" in transcript_lower:
            if not any(scam in transcript_lower for scam in ["ਪਾਸਵਰਡ", "ਓਟੀਪੀ", "ਕਾਰਡ", "ਖਾਤਾ", "ਅਨੁਪ", "ਚ੆ਲ੍ਲ"]):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Punjabi legitimate call - free service, no money needed"
                }
        
        # Multi-step trust scam override - if they ask to open FD after customer satisfaction survey
        if "customer satisfaction survey" in transcript_lower and "open fd" in transcript_lower:
            return {
                "category": "SCAM_DETECTED",
                "is_scam": True,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Multi-step scam - survey followed by FD opening request"
            }
        
        # SIM info legitimate - if they say they blocked SIMs and no action needed
        if "no action needed from your side" in transcript_lower and "blocked them" in transcript_lower:
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Legitimate SIM info - blocked unauthorized SIMs, no action needed"
            }
        
        # --- FALSE POSITIVE REDUCTION RULES ---
        # These rules protect innocent calls that contain broad scam keywords in a non-threatening context.
        
        # (A) Delivery / Swiggy / Zomato call with location share - NOT scam
        if any(word in transcript_lower for word in ["swiggy", "zomato", "delivery partner", "out for delivery", "five minutes away", "near your location", "reached your location"]):
            if not any(w in transcript_lower for w in ["otp", "pay", "upi pin", "transfer", "block", "arrest"]):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate delivery call - no payment demand"
                }
        
        # (B) Credit card STATEMENT sent - not asking for card details
        if "credit card statement" in transcript_lower and "sent to your registered email" in transcript_lower:
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Legitimate bank statement notification"
            }
        
        # (C) Complaint resolution call - no money asked
        if "complaint" in transcript_lower and any(w in transcript_lower for w in ["resolve", "resolved", "kya aap confirm"]):
            if not any(w in transcript_lower for w in ["otp", "pay", "transfer", "upi", "amount"]):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate complaint follow-up - no payment demand"
                }
        
        # (D) Doctor appointment / hospital discharge - no money demanded
        if any(w in transcript_lower for w in ["appointment", "dr. sharma", "doctor", "appointment scheduled", "discharge"]):
            if not any(w in transcript_lower for w in ["pay", "paisa", "transfer", "fee", "otp", "emergency", "accident"]):
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate appointment reminder - no payment"
                }
        
        # (E) Family/friend casual conversation — GUARD: must have zero scam score to fire
        # NOTE: use precise multi-word phrases to avoid substring false matches
        # e.g. "traffic" would match "drug trafficking" — use "stuck in traffic" instead
        casual_phrases = [
            "football match", "dinner mein rakhna", "kya haal hai", "sham ko",
            "report by eod", "review it tomorrow", "running late for", "stuck in traffic",
            "chai peene aao", "kya chal raha", "kab miloge", "aaj lunch",
        ]
        if scam_score == 0 and any(w in transcript_lower for w in casual_phrases):
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Casual personal conversation - no scam indicators"
            }
        
        # (F) If scam score is exactly 1 from a very generic word AND legitimate context present
        # (e.g. "credit card" mentioned but in context of "statement has been sent")
        safe_context_words = ["sent to your email", "registered email", "no action needed", "just a reminder", "just informing", "fyi", "for your information"]
        if scam_score == 1 and any(w in transcript_lower for w in safe_context_words):
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": "Low scam score with strong safe context - legitimate notification"
            }
        
        # Multi-step trust building then scam - check if legitimate indicators are followed by scam indicators
        if legitimate_score >= 1 and scam_score >= 1:
            # If asking for money/payment after building trust, it's a scam
            # BUT: if it's gas agency with "no advance payment" or "pay at delivery", it's legitimate
            if "no advance payment" in transcript_lower or "pay at delivery" in transcript_lower or "pay on delivery" in transcript_lower:
                return {
                    "category": "NORMAL",
                    "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Legitimate service - payment at delivery, no advance"
                }
            elif "pay" in transcript_lower or "transfer" in transcript_lower or "payment" in transcript_lower:
                return {
                    "category": "SCAM_DETECTED",
                    "is_scam": True,
                "is_confident": True,
                "layer": "keyword",
                    "reasoning": "Multi-step scam - trust building followed by payment request"
                }
        
        # If negative indicators present, prioritize legitimate classification
        # BUT: if "cyber crime" or "anti-scam" is mentioned with card details, it's likely a scam
        if negative_score >= 1 and scam_score <= 2:
            if "cyber crime" in transcript_lower or "anti-scam" in transcript_lower:
                if "card" in transcript_lower or "atm" in transcript_lower or "account" in transcript_lower:
                    return {
                        "category": "SCAM_DETECTED",
                        "is_scam": True,
                "is_confident": True,
                "layer": "keyword",
                        "reasoning": "Suspicious: claims to be anti-scam but asks for card/account details"
                    }
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "layer": "keyword",
                "reasoning": f"Rule-based detection: {negative_score} negative indicators override {scam_score} scam indicators"
            }
        
        # ==========================================
        # LAYER 1: Keyword-based Decision
        # ==========================================
        if scam_score >= 3:
            return {
                "category": "SCAM_DETECTED",
                "is_scam": True,
                "is_confident": True,
                "confidence": 1.0,
                "layer": "keyword",
                "reasoning": f"Layer 1 (Keyword): Strong detection ({scam_score} scam indicators)"
            }
        elif scam_score == 0 and legitimate_score >= 2:
            return {
                "category": "NORMAL",
                "is_scam": False,
                "is_confident": True,
                "confidence": 0.0,
                "layer": "keyword",
                "reasoning": f"Layer 1 (Keyword): Confirmed safe ({legitimate_score} legitimate indicators)"
            }
            
        # ==========================================
        # LAYER 2: TFLite Model Decision
        # ==========================================
        if TENSORFLOW_AVAILABLE and self.is_loaded and self.interpreter:
            try:
                vector = self._transform_text(transcript)
                
                # If vector is entirely empty (e.g. non-English text with no known vocab matches),
                # do NOT run inference as it will just evaluate biases and might falsely trigger.
                if np.any(vector):
                    sample = np.expand_dims(vector, axis=0)
                    
                    self.interpreter.set_tensor(self.inp_det["index"], sample)
                    self.interpreter.invoke()
                    ml_score = self.interpreter.get_tensor(self.out_det["index"])[0][0]
                    
                    if ml_score > 0.70:
                        return {
                        "category": "SCAM_DETECTED",
                        "is_scam": True,
                        "is_confident": True,
                        "confidence": float(ml_score),
                        "layer": "tflite",
                        "reasoning": f"Layer 2 (TFLite): High confidence scam ({(ml_score * 100):.1f}%)"
                    }
                elif ml_score < 0.30:
                    return {
                        "category": "NORMAL",
                        "is_scam": False,
                        "is_confident": True,
                        "confidence": float(ml_score),
                        "layer": "tflite",
                        "reasoning": f"Layer 2 (TFLite): High confidence safe ({((1 - ml_score) * 100):.1f}%)"
                    }
                else:
                    return {
                        "category": "UNKNOWN",
                        "is_scam": bool(ml_score >= 0.5),
                        "is_confident": False,
                        "confidence": float(ml_score),
                        "layer": "tflite_fallback",
                        "reasoning": f"Layer 2 (TFLite): Uncertain (score={ml_score:.2f}). Needs Web verification."
                    }
            except Exception as e:
                logger.error(f"Error during TFLite inference: {e}")
        elif not TENSORFLOW_AVAILABLE:
            logger.debug("TensorFlow not available - skipping TFLite layer (using backend services instead)")
        
        # Fallback if model not loaded or inference failed
        return {
            "category": "UNKNOWN",
            "is_scam": scam_score > 0,
            "is_confident": False,
            "layer": "fallback",
            "reasoning": f"Ambiguous: {scam_score} scam, {legitimate_score} legit indicators. Needs Web verification."
        }

