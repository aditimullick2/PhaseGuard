"""
Convert scam dataset format for BERT classification
Prepare data for binary classification: scam vs not-scam
"""

import json
import os

# Load existing dataset
input_file = "dataset.jsonl"
output_file = "dataset_bert.jsonl"

print(f"Loading dataset from {input_file}...")
examples = []

with open(input_file, 'r', encoding='utf-8') as f:
    for line in f:
        if line.strip():
            data = json.loads(line)
            examples.append(data)

print(f"Loaded {len(examples)} examples")

# Convert to BERT format
bert_examples = []
for ex in examples:
    # Parse the output to determine if it's a scam
    output = json.loads(ex['output'])
    is_scam = output.get('is_scam', False)
    
    # Create binary classification example
    bert_example = {
        'text': ex['input'],  # Transcript
        'label': 1 if is_scam else 0  # 1 = scam, 0 = not-scam
    }
    bert_examples.append(bert_example)

# Save BERT dataset
with open(output_file, 'w', encoding='utf-8') as f:
    for ex in bert_examples:
        f.write(json.dumps(ex) + '\n')

print(f"Saved {len(bert_examples)} examples to {output_file}")

# Count classes
scam_count = sum(1 for ex in bert_examples if ex['label'] == 1)
not_scam_count = sum(1 for ex in bert_examples if ex['label'] == 0)

print(f"\nDataset statistics:")
print(f"Scam examples: {scam_count}")
print(f"Not-scam examples: {not_scam_count}")
print(f"Total: {len(bert_examples)}")
print(f"Balance: {scam_count/(len(bert_examples))*100:.1f}% scam")
