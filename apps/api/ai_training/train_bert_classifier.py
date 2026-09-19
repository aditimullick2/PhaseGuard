"""
BERT-based Scam Classifier for Mobile Deployment
This is much more suitable for mobile than TinyLlama
"""

import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification, TrainingArguments, Trainer
from datasets import load_dataset
import os

# Use a smaller BERT model suitable for mobile
MODEL_NAME = "distilbert-base-uncased"  # ~67MB, TFLite-friendly
OUTPUT_DIR = "./bert_scam_classifier"

print("Loading dataset...")
dataset = load_dataset("json", data_files="dataset.jsonl", split="train")

def preprocess_function(examples):
    return tokenizer(
        examples["input"],
        truncation=True,
        padding="max_length",
        max_length=128
    )

print("Loading tokenizer and model...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForSequenceClassification.from_pretrained(
    MODEL_NAME,
    num_labels=2  # scam vs not-scam
)

# Preprocess dataset
tokenized_dataset = dataset.map(preprocess_function, batched=True)

# Split into train/validation
train_dataset = tokenized_dataset.shuffle(seed=42).select(range(int(len(tokenized_dataset) * 0.8)))
eval_dataset = tokenized_dataset.shuffle(seed=42).select(range(int(len(tokenized_dataset) * 0.8), len(tokenized_dataset)))

training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    evaluation_strategy="epoch",
    save_strategy="epoch",
    learning_rate=2e-5,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=16,
    num_train_epochs=3,
    weight_decay=0.01,
    load_best_model_at_end=True,
    logging_dir="./logs",
)

def compute_metrics(eval_pred):
    predictions, labels = eval_pred
    predictions = predictions.argmax(axis=-1)
    from sklearn.metrics import accuracy_score, precision_recall_fscore_support
    accuracy = accuracy_score(labels, predictions)
    precision, recall, f1, _ = precision_recall_fscore_support(labels, predictions, average='binary')
    return {
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'f1': f1
    }

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    compute_metrics=compute_metrics,
)

print("Starting training...")
trainer.train()

print("Saving model...")
trainer.save_model(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)

print(f"\nTraining complete! Model saved to {OUTPUT_DIR}")
print("Model size: ~67MB (suitable for mobile)")
print("Next step: Convert to TFLite")
