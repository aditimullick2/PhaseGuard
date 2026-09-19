# -*- coding: utf-8 -*-
"""
clean_and_import.py
Reads raw_paste.txt, fixes JSON issues, deduplicates, and appends
clean rows to dataset.jsonl
"""
import json, os, re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
raw_path   = os.path.join(SCRIPT_DIR, "..", "..", "..", "raw_paste.txt")
out_path   = os.path.join(SCRIPT_DIR, "..", "ai_training", "dataset.jsonl")

INSTRUCTION = ("Analyze the following phone call transcript and extract scam "
               "claims. Output JSON with 'category', 'is_scam' and 'reasoning'.")

# ── load existing inputs so we can deduplicate ──────────────────────────────
existing_inputs = set()
if os.path.exists(out_path):
    with open(out_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                existing_inputs.add(obj.get("input", "").strip()[:120])
            except Exception:
                pass
print(f"Existing rows: {len(existing_inputs)}")

# ── helpers ──────────────────────────────────────────────────────────────────
def fix_output_json(raw_output: str) -> dict | None:
    """Try several strategies to parse the output field."""
    raw_output = raw_output.strip().strip('"').strip("'")
    # strategy 1: direct parse
    try:
        return json.loads(raw_output)
    except Exception:
        pass
    # strategy 2: fix unescaped inner quotes by using regex extraction
    cat   = re.search(r'"category"\s*:\s*"([^"]+)"',   raw_output)
    scam  = re.search(r'"is_s?_?scam"\s*:\s*(true|false)', raw_output, re.I)
    rsn   = re.search(r'"reasoning"\s*:\s*"(.*?)"(?:\s*[},]|$)', raw_output, re.DOTALL)
    if cat and scam:
        return {
            "category":  cat.group(1),
            "is_scam":   scam.group(1).lower() == "true",
            "reasoning": rsn.group(1).replace('\\"', '"') if rsn else ""
        }
    return None


def try_parse_line(line: str):
    """Parse one JSONL line using robust regex extraction to bypass invalid JSON."""
    line = line.strip()
    if not line or not line.startswith("{"):
        return None
    
    # Extract input
    inp_match = re.search(r'"input"\s*:\s*"(.*?)"\s*,\s*"output"', line)
    if not inp_match:
        inp_match = re.search(r'"input"\s*:\s*"(.*?)"\s*(?:,|})', line)
    
    inp = inp_match.group(1) if inp_match else ""
    if not inp:
        return None
        
    # Extract category, is_scam, reasoning
    cat = re.search(r'"category"\s*:\s*"?([A-Za-z_]+)"?', line)
    scam = re.search(r'"is_scam"\s*:\s*(true|false)', line, re.I)
    
    # Reasoning can be tricky. Try to grab everything after "reasoning": " until the end of the line minus trailing junk
    rsn_match = re.search(r'"reasoning"\s*:\s*"(.*)', line)
    if not rsn_match:
        return None
        
    rsn_str = rsn_match.group(1)
    # clean up trailing junk like "} or "}"} or "}
    rsn_str = re.sub(r'"?\s*}"?\s*}"?\s*$', '', rsn_str)
    rsn_str = re.sub(r'"?}$', '', rsn_str)
    
    if not cat or not scam:
        return None
        
    out_dict = {
        "category": cat.group(1).upper(),
        "is_scam": scam.group(1).lower() == "true",
        "reasoning": rsn_str
    }
    
    return inp, out_dict


# ── main import loop ─────────────────────────────────────────────────────────
if not os.path.exists(raw_path):
    print(f"ERROR: {raw_path} not found. Save the pasted data there first.")
    exit(1)

added   = 0
skipped = 0
errors  = 0

with open(raw_path, encoding="utf-8", errors="replace") as rf, \
     open(out_path, "a", encoding="utf-8") as wf:
    for lineno, line in enumerate(rf, 1):
        result = try_parse_line(line)
        if result is None:
            errors += 1
            continue
        inp, out_dict = result
        key = inp.strip()[:120]
        if key in existing_inputs:
            skipped += 1
            continue
        row = {
            "instruction": INSTRUCTION,
            "input":       inp,
            "output":      json.dumps(out_dict, ensure_ascii=False)
        }
        wf.write(json.dumps(row, ensure_ascii=False) + "\n")
        existing_inputs.add(key)
        added += 1

print(f"\nDone!")
print(f"  Added   : {added}")
print(f"  Skipped (duplicate): {skipped}")
print(f"  Errors  : {errors}")

total = sum(1 for _ in open(out_path, encoding="utf-8") if _.strip())
print(f"  TOTAL rows in dataset.jsonl: {total}")
