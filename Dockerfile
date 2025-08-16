FROM python:3.10-slim

WORKDIR /

# Install system dependencies
RUN apt-get update && apt-get install -y \
  git \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
  runpod \
  torch \
  torchvision \
  transformers \
  Pillow \
  accelerate \
  flash-attn \
  qwen-vl-utils

# Install dots.ocr from GitHub
RUN pip install --no-cache-dir git+https://github.com/rednote-hilab/dots.ocr.git

# Copy your handler file
COPY rp_handler.py /

# Start the container
CMD ["python3", "-u", "rp_handler.py"]