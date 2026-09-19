import re

transcript = "या प्रेट कार्ड डिटेल्स"
pattern = re.compile(r"कार्ड\s*(?:नंबर|डिटेल|सीवीवी|पिन|कोड)", re.IGNORECASE)
print("Match 1:", pattern.search(transcript))

transcript2 = "we require to provide and your bank account details as well as ya pret card details de se vividio at the back of your card"
pattern2 = re.compile(r"card\s+(?:number|no|details|verification|verify|cvv|pin|code)", re.IGNORECASE)
print("Match 2:", pattern2.search(transcript2))

pattern3 = re.compile(r"bank\s+account\s+details", re.IGNORECASE)
print("Match 3:", pattern3.search(transcript2))

pattern4 = re.compile(r"(?:bank\s+)?account\s+(?:number|details|info|password)", re.IGNORECASE)
print("Match 4:", pattern4.search(transcript2))
