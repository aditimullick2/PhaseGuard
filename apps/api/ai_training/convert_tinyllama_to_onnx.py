"""
Convert TinyLlama from PyTorch to ONNX format
First step before TFLite conversion
"""

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import os

MODEL_PATH = "./finetuned_scam_model"
ONNX_OUTPUT = "./tinyllama_scam.onnx"

print("Loading TinyLlama model...")
model = AutoModelForCausalLM.from_pretrained(
    MODEL_PATH,
    torch_dtype=torch.float16,
    device_map="auto"
)

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
tokenizer.pad_token = tokenizer.eos_token

print("Model loaded successfully!")

# Prepare dummy input for export
dummy_input = tokenizer("Hello, this is a test", return_tensors="pt")

print("\nExporting to ONNX format...")
print("Note: Converting full LLM to ONNX is experimental and may not work perfectly")

try:
    # Export to ONNX
    torch.onnx.export(
        model,
        (dummy_input['input_ids'], dummy_input['attention_mask']),
        ONNX_OUTPUT,
        input_names=['input_ids', 'attention_mask'],
        output_names=['logits'],
        dynamic_axes={
            'input_ids': {0: 'batch_size', 1: 'sequence'},
            'attention_mask': {0: 'batch_size', 1: 'sequence'},
            'logits': {0: 'batch_size', 1: 'sequence'}
        },
        opset_version=17
    )
    
    print(f"ONNX model saved to {ONNX_OUTPUT}")
    print(f"Size: {os.path.getsize(ONNX_OUTPUT) / (1024*1024):.1f} MB")
    
except Exception as e:
    print(f"Error during ONNX export: {e}")
    print("\nThis is expected - LLMs to ONNX conversion is experimental")
    print("For mobile deployment, consider:")
    print("1. Using llama.cpp format (recommended)")
    print("2. Using a smaller model (BERT, DistilBERT)")
    print("3. Keeping rule-based system (98.7% accurate)")
