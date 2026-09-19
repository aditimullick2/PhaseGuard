import os
import torch
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig
from trl import SFTTrainer

# Configurations
MODEL_NAME = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
DATASET_PATH = "dataset_augmented.jsonl"
OUTPUT_DIR = "./finetuned_scam_model_v2"

# Load dataset
try:
    dataset = load_dataset("json", data_files=DATASET_PATH, split="train")
    print(f"Dataset loaded: {len(dataset)} examples")
except Exception as e:
    print(f"Error loading dataset: {e}")
    raise

def format_instruction(example):
    prompt = f"""<|system|>
You are an expert scam detection AI. You extract fake claims and classify phone calls.</s>
<|user|>
{example['instruction']}

Transcript: {example['input']}</s>
<|assistant|>
{example['output']}</s>"""
    return {"text": prompt}

dataset = dataset.map(format_instruction)

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = "right"

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    torch_dtype=torch.float16,
    device_map="auto"
)

peft_config = LoraConfig(
    lora_alpha=16,
    lora_dropout=0.1,
    r=8,
    bias="none",
    task_type="CAUSAL_LM",
)

training_arguments = TrainingArguments(
    output_dir=OUTPUT_DIR,
    num_train_epochs=5,      
    per_device_train_batch_size=2,
    gradient_accumulation_steps=4,
    optim="paged_adamw_32bit",
    save_steps=50,
    logging_steps=10,
    learning_rate=1e-4,
    weight_decay=0.001,
    fp16=True,              
    max_grad_norm=0.3,
    max_steps=-1,
    warmup_steps=10,
    lr_scheduler_type="cosine",
    report_to="none",
)

trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    peft_config=peft_config,
    tokenizer=tokenizer,
    args=training_arguments,
    dataset_text_field="text",
    max_seq_length=512,
)

print("Starting Model Training on GPU...")
trainer.train()

trainer.model.save_pretrained(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)
print("Training Complete! Download the finetuned_scam_model folder.")
