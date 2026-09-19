import json
import os

transcript_path = r"C:\Users\mr baddy\.gemini\antigravity-ide\brain\c460b3ec-182a-4e2b-a1c6-80a3da321fe9\.system_generated\logs\transcript_full.jsonl"
output_path = r"d:\PhaseGuard\raw_paste.txt"

data_to_write = []

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            step = json.loads(line)
            if step.get('type') == 'USER_INPUT':
                content = step.get('content', '')
                if '{"instruction":' in content or 'add(' in content:
                    data_to_write.append(content)
        except Exception as e:
            pass

print(f"Found {len(data_to_write)} user messages containing data.")
with open(output_path, 'w', encoding='utf-8') as f:
    for content in data_to_write:
        f.write(content + "\n")
print(f"Wrote extracted data to {output_path}")
