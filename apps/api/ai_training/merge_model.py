import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import os

# Paths
BASE_MODEL = "HuggingFaceTB/SmolLM2-135M"
LORA_ADAPTER = "D:/PhaseGuard/apps/api/ai_training/fine_tuned_smollm2"
MERGED_MODEL = "D:/PhaseGuard/apps/api/ai_training/merged_smollm2"
GGUF_OUTPUT = "D:/PhaseGuard/apps/api/ai_training/smollm2_gguf"

print("=== CONVERTING FINE-TUNED MODEL TO GGUF ===")
print(f"Base Model: {BASE_MODEL}")
print(f"LoRA Adapter: {LORA_ADAPTER}")
print(f"Merged Output: {MERGED_MODEL}")
print(f"GGUF Output: {GGUF_OUTPUT}")
print()

# Load base model
print("Loading base model...")
base_model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.float16,
    device_map="auto"
)
tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
print()

# Load LoRA adapter
print("Loading LoRA adapter...")
model = PeftModel.from_pretrained(base_model, LORA_ADAPTER)
print()

# Merge and save
print("Merging LoRA weights...")
model = model.merge_and_unload()
print()

# Save merged model
print("Saving merged model...")
model.save_pretrained(MERGED_MODEL)
tokenizer.save_pretrained(MERGED_MODEL)
print(f"Merged model saved to: {MERGED_MODEL}")
print()

print("=== MODEL MERGE COMPLETE ===")
print()
print("Next step: Use llama.cpp to convert to GGUF")
print()
print("Commands to run:")
print("1. Clone llama.cpp: git clone https://github.com/ggerganov/llama.cpp")
print("2. Build llama.cpp: cd llama.cpp && cmake -B build && cmake --build build")
print("3. Convert to GGUF: ./build/bin/convert-hf-to-gguf.py " + MERGED_MODEL + " --outfile " + GGUF_OUTPUT + "/smollm2.gguf --outtype q4_k_m")
print()
print("This will create a quantized GGUF model (~60-80 MB) suitable for mobile deployment")