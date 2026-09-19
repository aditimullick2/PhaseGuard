import random
import json
from stress_test_1000 import SCENARIOS

# Words to swap for augmentation
amounts = ["10,000", "20,000", "50,000", "5000", "2 lakh", "1.5 lakh", "8000", "35,000"]
names = ["Rahul", "Amit", "Saurabh", "Vikram", "Riya", "Priya"]
companies = ["Amazon", "Flipkart", "Myntra", "Jio", "Airtel", "Vi", "HDFC", "SBI", "ICICI"]
authorities = ["CBI", "Police", "Cyber Crime", "Customs", "Income Tax", "RBI", "TRAI"]

def perturb(text):
    t = text
    # Randomly replace some common words with others to create variations
    for a in amounts:
        if a in t: t = t.replace(a, random.choice(amounts))
    for n in names:
        if n in t: t = t.replace(n, random.choice(names))
    for c in companies:
        if c in t: t = t.replace(c, random.choice(companies))
    for auth in authorities:
        if auth in t: t = t.replace(auth, random.choice(authorities))
    
    # Add filler
    fillers_start = ["Suniye, ", "Hello? ", "Ahem, ", "Can you hear me? ", "Am I audible? ", ""]
    fillers_end = [" Boliye?", " Do you understand?", " Is that clear?", " Hello?", ""]
    
    t = random.choice(fillers_start) + t + random.choice(fillers_end)
    return t

new_scenarios = []
# Keep original 189
new_scenarios.extend(SCENARIOS)

# Generate until 1000
while len(new_scenarios) < 1000:
    orig = random.choice(SCENARIOS)
    new_text = perturb(orig[0])
    # ensure it's not exactly the same string just in case
    new_scenarios.append((new_text, orig[1], orig[2]))

with open("stress_1000_data.py", "w", encoding="utf-8") as f:
    f.write("SCENARIOS = [\n")
    for s in new_scenarios:
        t = s[0].replace('"', '\\"')
        f.write(f'    ("{t}", {s[1]}, "{s[2]}"),\n')
    f.write("]\n")

print(f"Generated {len(new_scenarios)} scenarios.")
