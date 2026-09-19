# Use the official Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies (needed for audio processing, PyTorch, etc.)
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
# Using --no-cache-dir to save space
RUN pip install --no-cache-dir -r requirements.txt

# Create models directory so XTTS doesn't fail trying to create it
RUN mkdir -p /app/tts_models

# Copy the entire API application
COPY . .

# Expose port (Hugging Face Spaces expects port 7860 by default for Gradio/FastAPI)
EXPOSE 7860

# Ensure Python output is sent straight to terminal (unbuffered)
ENV PYTHONUNBUFFERED=1

# Run the FastAPI app using Uvicorn on 0.0.0.0 and port 7860
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
