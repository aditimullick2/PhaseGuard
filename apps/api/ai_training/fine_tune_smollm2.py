import torch
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
from datasets import load_dataset
from peft import LoraConfig, get_peft_model, TaskType
import json

# Model: SmolLM2-135M (Small for mobile)
MODEL_NAME = "HuggingFaceTB/SmolLM2-135M"
DATASET_PATH = "D:/PhaseGuard/apps/api/ai_training/scam_dataset.jsonl"
OUTPUT_DIR = "D:/PhaseGuard/apps/api/ai_training/fine_tuned_smollm2"

# Training Configuration
BATCH_SIZE = 4
GRADIENT_ACCUMULATION_STEPS = 4
NUM_EPOCHS = 3
LEARNING_RATE = 2e-4
MAX_LENGTH = 512

print("=== SMOLLM2 FINE-TUNING FOR SCAM DETECTION ===")
print(f"Model: {MODEL_NAME}")
print(f"Dataset: {DATASET_PATH}")
print(f"Output: {OUTPUT_DIR}")
print()

# Check GPU availability
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device: {device}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
print()

# Load dataset
print("Loading dataset...")
with open(DATASET_PATH, "r", encoding="utf-8") as f:
    data = [json.loads(line) for line in f]

print(f"Loaded {len(data)} examples")
print(f"Scam examples: {sum(1 for item in data if item['label'] == 'SCAM')}")
print(f"Normal examples: {sum(1 for item in data if item['label'] == 'NORMAL')}")
print()

# Prepare training data with instruction format
def format_for_training(item):
    # Create instruction format
    text = item["text"]
    label = item["label"]
    category = item.get("category", "UNKNOWN")

    instruction = f"""Classify the following message as SCAM or NORMAL.

Message: {text}

Classification: {label}
Category: {category}"""

    return instruction

print("Formatting training data...")
formatted_data = [format_for_training(item) for item in data]

# Create HuggingFace dataset
from datasets import Dataset
dataset = Dataset.from_dict({"text": formatted_data})

# Split into train and validation
dataset = dataset.train_test_split(test_size=0.1, seed=42)
train_dataset = dataset["train"]
eval_dataset = dataset["test"]

print(f"Train samples: {len(train_dataset)}")
print(f"Eval samples: {len(eval_dataset)}")
print()

# Load tokenizer and model
print("Loading model and tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    torch_dtype=torch.float16,
    device_map="auto"
)
print()

# Configure LoRA
print("Configuring LoRA...")
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    lora_dropout=0.1,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    bias="none"
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
print()

# Tokenize dataset
def tokenize_function(examples):
    return tokenizer(
        examples["text"],
        truncation=True,
        max_length=MAX_LENGTH,
        padding="max_length"
    )

print("Tokenizing dataset...")
train_dataset = train_dataset.map(tokenize_function, batched=True)
eval_dataset = eval_dataset.map(tokenize_function, batched=True)

# Remove text column (keep only input_ids, attention_mask)
train_dataset = train_dataset.remove_columns(["text"])
eval_dataset = eval_dataset.remove_columns(["text"])

# Set format for PyTorch
train_dataset.set_format("torch")
eval_dataset.set_format("torch")
print()

# Training arguments
training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    num_train_epochs=NUM_EPOCHS,
    per_device_train_batch_size=BATCH_SIZE,
    per_device_eval_batch_size=BATCH_SIZE,
    gradient_accumulation_steps=GRADIENT_ACCUMULATION_STEPS,
    learning_rate=LEARNING_RATE,
    warmup_steps=100,
    logging_steps=10,
    save_steps=100,
    eval_steps=100,
    evaluation_strategy="steps",
    save_strategy="steps",
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    fp16=True,
    logging_dir=f"{OUTPUT_DIR}/logs",
    report_to="none",
)

# Data collator
data_collator = DataCollatorForLanguageModeling(
    tokenizer=tokenizer,
    mlm=False,
)

# Initialize trainer
print("Initializing trainer...")
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    data_collator=data_collator,
)

print("Starting training...")
print(f"Expected training time: ~30-60 minutes on RTX 4060")
print()

# Start training
trainer.train()

print("Training completed!")
print(f"Model saved to: {OUTPUT_DIR}")
print()

# Save the fine-tuned model
print("Saving final model...")
trainer.save_model(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)

print("=== FINE-TUNING COMPLETE ===")
print(f"Model saved at: {OUTPUT_DIR}")
print("Next step: Convert to GGUF for mobile deployment")