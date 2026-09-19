"""
Convert TinyLlama model to llama.cpp format for mobile deployment
This is much more practical than TFLite for LLMs
"""

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import os
import subprocess

MODEL_PATH = "./finetuned_scam_model"
LLAMACPP_OUTPUT = "./tinyllama_scam_llamacpp"

print("Loading TinyLlama model...")
model = AutoModelForCausalLM.from_pretrained(
    MODEL_PATH,
    torch_dtype=torch.float16,
    device_map="auto"
)

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
tokenizer.pad_token = tokenizer.eos_token

print("Model loaded successfully!")

# Save in HF format for llama.cpp conversion
print("\nSaving in HuggingFace format...")
output_hf = "./tinyllama_scam_hf"
os.makedirs(output_hf, exist_ok=True)

model.save_pretrained(output_hf)
tokenizer.save_pretrained(output_hf)

print(f"Model saved to {output_hf}")

print("\nConverting to llama.cpp format...")
print("This requires llama.cpp tools. Installing...")

# Clone llama.cpp if not exists
if not os.path.exists("llama.cpp"):
    subprocess.run(["git", "clone", "https://github.com/ggerganov/llama.cpp.git"])

# Convert using llama.cpp tools
convert_cmd = [
    "python", "llama.cpp/convert.py",
    output_hf,
    "--outfile", f"{LLAMACPP_OUTPUT}/ggml-model-f16.gguf",
    "--outtype", "f16"
]

print(f"Running: {' '.join(convert_cmd)}")
try:
    subprocess.run(convert_cmd, check=True)
    print(f"\nConversion successful! Model saved to {LLAMACPP_OUTPUT}")
    
    # Quantize to smaller size
    print("\nQuantizing to Q4_K_M (smaller, faster)...")
    quantize_cmd = [
        "llama.cpp/quantize",
        f"{LLAMACPP_OUTPUT}/ggml-model-f16.gguf",
        f"{LLAMACPP_OUTPUT}/ggml-model-q4_k_m.gguf",
        "Q4_K_M"
    ]
    subprocess.run(quantize_cmd, check=True)
    
    print(f"\nQuantized model saved!")
    print(f"Size: {os.path.getsize(f'{LLAMACPP_OUTPUT}/ggml-model-q4_k_m.gguf') / (1024*1024):.1f} MB")
    
except Exception as e:
    print(f"Error during conversion: {e}")
    print("\nManual steps:")
    print("1. Install llama.cpp: git clone https://github.com/ggerganov/llama.cpp.git")
    print("2. Convert: python llama.cpp/convert.py tinyllama_scam_hf --outfile model.gguf")
    print("3. Quantize: ./llama.cpp/quantize model.gguf model-q4.gguf Q4_K_M")

print("\nFor Flutter integration:")
print("Use llama_dart package: https://pub.dev/packages/llama_dart")
print("Or flutter_llama package: https://pub.dev/packages/flutter_llama")
