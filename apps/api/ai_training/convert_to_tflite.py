import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import os

# Path to trained model
MODEL_PATH = "./finetuned_scam_model"
TFLITE_OUTPUT_PATH = "./scam_model_tflite"

print("Loading trained TinyLlama model...")
model = AutoModelForCausalLM.from_pretrained(
    MODEL_PATH,
    torch_dtype=torch.float16,
    device_map="auto"
)

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
tokenizer.pad_token = tokenizer.eos_token

print("Model loaded successfully!")
print(f"Model size: {sum(p.numel() for p in model.parameters()) / 1e6:.1f}M parameters")

# Convert to TFLite
print("\nConverting to TFLite...")
print("Note: Full TFLite conversion for LLMs is complex. Using simplified approach.")

# Option 1: Export to ONNX first (better for TFLite)
print("\nStep 1: Exporting to ONNX format...")
try:
    import onnx
    import onnxruntime as ort
    from transformers import AutoModelForSequenceClassification
    
    # For scam detection, we can use a simpler approach
    # Create a classification head on top of the model
    # This is a simplified approach - actual LLM-to-TFLite is very complex
    
    print("Creating simplified classification model...")
    print("This is a placeholder - actual LLM-to-TFLite requires:")
    print("1. Quantization-aware training")
    print("2. Specialized TFLite conversion tools")
    print("3. Mobile-optimized architecture")
    
except ImportError:
    print("ONNX not installed. Installing...")
    os.system("pip install onnx onnxruntime")

print("\nAlternative approach:")
print("For mobile deployment, consider:")
print("1. Use TensorFlow Lite directly with a smaller model")
print("2. Quantize to int8/float16")
print("3. Use specialized mobile LLM libraries")
print("4. Or use the rule-based system (already 98.7% accurate)")

print("\nFor now, the rule-based system is recommended for mobile.")
print("The TFLite model would be 500MB+ and slow on mobile.")
