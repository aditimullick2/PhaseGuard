# Merge datasets
with open('dataset.jsonl', 'r') as f1:
    lines1 = f1.readlines()
    
with open('legitimate_calls.jsonl', 'r') as f2:
    lines2 = f2.readlines()
    
with open('dataset_augmented.jsonl', 'w') as f3:
    f3.writelines(lines1)
    f3.writelines(lines2)
    
print(f'Total lines: {len(lines1) + len(lines2)}')
print(f'Original: {len(lines1)}, Added: {len(lines2)}')
