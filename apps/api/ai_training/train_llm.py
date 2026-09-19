import os
import torch
from datasets import load_dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
)
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer

# Configurations
MODEL_NAME = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
DATASET_PATH = "dataset.jsonl"
OUTPUT_DIR = "./finetuned_scam_model"

def format_instruction(example):
    """Formats the instruction for the LLM."""
    prompt = f"""<|system|>
You are an expert scam detection AI. You extract fake claims and classify phone calls.</s>
<|user|>
{example['instruction']}

Transcript: {example['input']}</s>
<|assistant|>
{example['output']}</s>"""
    return {"text": prompt}

def main():
    print("🚀 Initializing PhaseGuard LLM Fine-Tuning Pipeline...")

    # 1. Load Dataset
    print(f"Loading dataset from {DATASET_PATH}...")
    dataset = load_dataset("json", data_files=DATASET_PATH, split="train")
    
    # Format the dataset using the instruction template
    dataset = dataset.map(format_instruction)

    # 2. Load Tokenizer
    print(f"Loading Tokenizer: {MODEL_NAME}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    # 3. Load Base Model (Using bfloat16 or float16 for efficiency)
    print(f"Loading Model: {MODEL_NAME}...")
    # For a hackathon laptop, we won't use 4-bit quantization by default to avoid bitsandbytes installation hell,
    # but in a real scenario you would add `quantization_config=BitsAndBytesConfig(...)`
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        torch_dtype=torch.float16,
        device_map="auto"
    )

    # 4. LoRA Configuration (Parameter Efficient Fine-Tuning)
    print("Setting up LoRA configuration...")
    peft_config = LoraConfig(
        lora_alpha=16,
        lora_dropout=0.1,
        r=8,
        bias="none",
        task_type="CAUSAL_LM",
    )
    
    # SFTTrainer will automatically apply get_peft_model when peft_config is provided

    from trl import SFTConfig, SFTTrainer

    # 5. Training Arguments using SFTConfig
    print("Setting up Training Arguments...")
    training_arguments = SFTConfig(
        output_dir=OUTPUT_DIR,
        num_train_epochs=3,      # Keep it small for hackathon demo
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        optim="adamw_torch",
        save_steps=10,
        logging_steps=2,
        learning_rate=2e-4,
        weight_decay=0.001,
        fp16=False,              # Set to true if you have a capable GPU
        bf16=False,              # Set to true if you have Ampere architecture (RTX 3000+)
        max_grad_norm=0.3,
        max_steps=-1,
        warmup_steps=10,
        lr_scheduler_type="cosine",
        report_to="none",         # Disable wandb for local testing
        dataset_text_field="text",
        max_length=512
    )

    # 6. Initialize SFTTrainer
    print("Initializing SFT Trainer...")
    trainer = SFTTrainer(
        model=model,
        train_dataset=dataset,
        peft_config=peft_config,
        processing_class=tokenizer,
        args=training_arguments,
    )

    # 7. Start Training
    print("🔥 Starting Model Training...")
    trainer.train()

    # 8. Save the Fine-Tuned Model
    print(f"💾 Saving model to {OUTPUT_DIR}...")
    trainer.model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)
    
    print("✅ Training Complete! The model is now ready to detect scams.")

if __name__ == "__main__":
    main()
