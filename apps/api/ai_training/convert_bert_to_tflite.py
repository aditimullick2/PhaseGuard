"""
Convert BERT scam classifier to TFLite for mobile deployment
"""

import tensorflow as tf
from transformers import TFAutoModelForSequenceClassification, AutoTokenizer
import os

BERT_MODEL_PATH = "./bert_scam_classifier"
TFLITE_OUTPUT_PATH = "./bert_scam_classifier_tflite"

print("Loading BERT model in TensorFlow format...")
try:
    model = TFAutoModelForSequenceClassification.from_pretrained(BERT_MODEL_PATH)
    tokenizer = AutoTokenizer.from_pretrained(BERT_MODEL_PATH)
    print("Model loaded successfully!")
except Exception as e:
    print(f"Error loading model: {e}")
    print("Make sure to train the BERT model first using train_bert_classifier.py")
    print("Then convert the PyTorch model to TensorFlow first:")
    print("  from transformers import AutoModelForSequenceClassification")
    print("  pt_model = AutoModelForSequenceClassification.from_pretrained('./bert_scam_classifier')")
    print("  pt_model.save_pretrained('./bert_scam_classifier_tf')")
    exit(1)

print("\nConverting to TFLite...")

# Create a concrete function
@tf.function(input_signature=[tf.TensorSpec(shape=[1, 128], dtype=tf.int32, name='input_ids'),
                               tf.TensorSpec(shape=[1, 128], dtype=tf.int32, name='attention_mask')])
def serve(input_ids, attention_mask):
    return model(input_ids, attention_mask=attention_mask)

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_concrete_functions(
    [serve.get_concrete_function()]
)

# Optimize for mobile
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]

# Enable quantization (int8) for smaller size
converter.experimental_new_quantizer = True

# Convert
tflite_model = converter.convert()

# Save
os.makedirs(TFLITE_OUTPUT_PATH, exist_ok=True)
tflite_path = os.path.join(TFLITE_OUTPUT_PATH, "scam_classifier.tflite")
with open(tflite_path, 'wb') as f:
    f.write(tflite_model)

print(f"\nTFLite model saved to: {tflite_path}")
print(f"Model size: {os.path.getsize(tflite_path) / (1024*1024):.1f} MB")

# Save tokenizer for mobile
tokenizer.save_pretrained(TFLITE_OUTPUT_PATH)

print("\nTFLite conversion complete!")
print("Next: Integrate into Flutter using tflite_flutter package")
