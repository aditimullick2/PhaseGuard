import re
import sys
import os

raw_path = os.path.join(os.path.dirname(__file__), "..", "..", "..", "raw_paste.txt")
with open(raw_path, encoding="utf8") as f:
    for line in f:
        line = line.strip()
        if not line: continue
        
        # Test regexes
        cat = re.search(r'[\'"]category[\'"]\s*:\s*[\'"]?([A-Za-z_]+)[\'"]?', line)
        scam = re.search(r'[\'"]is_scam[\'"]\s*:\s*(true|false)', line, re.I)
        
        inp_match = re.search(r'"input"\s*:\s*"(.*?)"\s*,\s*"output"', line)
        if not inp_match:
            inp_match = re.search(r'"input"\s*:\s*"(.*?)"\s*(?:,|})', line)
            
        print(f"Line: {line[:50]}...")
        print(f"  Input: {bool(inp_match)}")
        print(f"  Cat: {cat.group(1) if cat else None}")
        print(f"  Scam: {scam.group(1) if scam else None}")
        break
