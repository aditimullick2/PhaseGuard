"""
Merge LoRA adapter with base model to create full model
Then convert to GGUF for mobile
"""

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import os

BASE_MODEL = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
LORA_ADAPTER = "./finetuned_scam_model"
FULL_MODEL_OUTPUT = "./tinyllama_scam_full_model"

print("Loading base model...")
base_model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.float16,
    device_map="auto"
)

print("Loading LoRA adapter...")
model = PeftModel.from_pretrained(base_model, LORA_ADAPTER)

print("Merging LoRA weights...")
model = model.merge_and_unload()

print("Saving full model...")
os.makedirs(FULL_MODEL_OUTPUT, exist_ok=True)
model.save_pretrained(FULL_MODEL_OUTPUT)

tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
tokenizer.pad_token = tokenizer.eos_token
tokenizer.save_pretrained(FULL_MODEL_OUTPUT)

print(f"\nFull model saved to {FULL_MODEL_OUTPUT}")
print("Now you can convert this to GGUF using llama.cpp")
