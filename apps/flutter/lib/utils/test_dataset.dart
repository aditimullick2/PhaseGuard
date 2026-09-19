class TestCase {
  final String transcript;
  final bool isScam;
  final String category;

  TestCase(this.transcript, this.isScam, this.category);
}

class TestDataset {
  static final List<TestCase> cases = [
    // 🔴 SCAMS (15 cases)
    TestCase(
        "Hello this is calling from RBI. Your bank account has been linked to illegal transactions. Please transfer your money to our secure account immediately.",
        true,
        "RBI_SCAM"),
    TestCase(
        "Hello, this is calling from bank. Your UPI account is blocked. Please accept this collect request of 5000 rupees to unblock.",
        true,
        "UPI_FRAUD"),
    TestCase(
        "This is police officer Sharma from CBI. We have issued a digital arrest warrant against you for money laundering. Pay 1 lakh immediately.",
        true,
        "DIGITAL_ARREST"),
    TestCase(
        "Hello beta, this is your uncle speaking. I am in the hospital and need urgent money for surgery. Please transfer 50000 rupees.",
        true,
        "FAMILY_EMERGENCY"),
    TestCase(
        "Mera package deliver nahi hua, custom duty pay karni hai 500 rupees warna parcel seized ho jayega.",
        true,
        "COURIER_SCAM"),
    TestCase(
        "Aapki LIC policy lapse hone wali hai. Penalty bachane ke liye is link pe click karke 2000 rupees pay karein.",
        true,
        "INSURANCE_FRAUD"),
    TestCase(
        "Hello I am from child care NGO. We need urgent donation for orphan kids. Please send money.",
        true,
        "CHARITY_SCAM"),
    TestCase(
        "Sir aapka electricity bill pending hai. Aaj raat 9 baje bijli kategi. Update karne ke liye call karein.",
        true,
        "ELECTRICITY_THREAT"),
    TestCase(
        "Congratulations! Aapne 25 lakh ki lottery jeeti hai KBC se. Processing fee 10000 rupees jama karayein.",
        true,
        "LOTTERY_SCAM"),
    TestCase(
        "Aapka KYC incomplete hai. Account freeze ho jayega. Apna aadhar card number aur OTP share karein.",
        true,
        "KYC_SCAM"),
    TestCase(
        "Join our VIP Whatsapp group for guaranteed 200% returns in trading. Minimum investment 50000.",
        true,
        "INVESTMENT_FRAUD"),
    TestCase(
        "Maine aapka video record kar liya hai. 50000 nahi bheje toh sabhi whatsapp contacts ko leak kar dunga.",
        true,
        "SEXTORTION"),
    TestCase(
        "Sir aapke credit card pe 15000 reward points expire ho rahe hain. Redeem karne ke liye OTP batayein.",
        true,
        "REWARD_POINTS_SCAM"),
    TestCase(
        "Hello, we are from Microsoft Support. Your computer has a virus. Give us remote access to fix it.",
        true,
        "TECH_SUPPORT_SCAM"),
    TestCase(
        "Mera ek dost hai jiska account block ho gaya hai, maine aapke account me 10000 bheje hain, please usko forward kar do.",
        true,
        "MONEY_MULE_SCAM"),

    // 🟢 LEGITIMATE (15 cases)
    TestCase(
        "Hello, this is calling from HDFC Bank customer service. We are calling to inform you about your new credit card benefits. Would you like to know more?",
        false,
        "NORMAL"),
    TestCase(
        "Hi, this is Amazon delivery. I am at your gate with your package.",
        false,
        "NORMAL"),
    TestCase(
        "Hello, just a reminder that your health insurance premium is due next month.",
        false,
        "NORMAL"),
    TestCase(
        "Hi, I am calling from HelpAge India. Would you be interested in making a regular donation for the elderly?",
        false,
        "NORMAL"),
    TestCase(
        "Sir, aapka Swiggy order pick up ho gaya hai, 10 minute me pahuch raha hu.",
        false,
        "NORMAL"),
    TestCase(
        "Your Tata Sky recharge was successful. Your new balance is 450 rupees.",
        false,
        "NORMAL"),
    TestCase(
        "Hello beta, main uncle bol raha hu. Kal shaam ko ghar aa jana dinner ke liye.",
        false,
        "NORMAL"),
    TestCase(
        "Hi, this is your dentist's office calling to confirm your appointment for tomorrow at 10 AM.",
        false,
        "NORMAL"),
    TestCase(
        "Aapka electricity bill 1500 rupees generate hua hai. Due date 25th Jan hai.",
        false,
        "NORMAL"),
    TestCase(
        "Sir aapka internet connection theek ho gaya hai. Abhi speed aa rahi hai na?",
        false,
        "NORMAL"),
    TestCase(
        "Hello, main Jio customer care se bol rahi hu. Aapka current plan expire hone wala hai.",
        false,
        "NORMAL"),
    TestCase(
        "Hi, your Uber driver is waiting outside.",
        false,
        "NORMAL"),
    TestCase(
        "Aapki car ki servicing due hai next week. Appointment book karna chahenge?",
        false,
        "NORMAL"),
    TestCase(
        "Hello, we noticed a login from a new device on your Gmail account. Was this you?",
        false,
        "NORMAL"),
    TestCase(
        "Sir, aapke HDFC account me 5000 rupees credit hue hain salary aayi hai.",
        false,
        "NORMAL"),
  ];
}
