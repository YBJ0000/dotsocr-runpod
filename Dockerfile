FROM python:3.10-slim

WORKDIR /

# Install system dependencies
RUN apt-get update && apt-get install -y \
  git \
  build-essential \
  wget \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install wheel
RUN pip install --upgrade pip setuptools wheel

# Install core dependencies step by step
RUN pip install --no-cache-dir runpod

# Install PyTorch (CPU version for compatibility)
RUN pip install --no-cache-dir \
  torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install transformers and related packages
RUN pip install --no-cache-dir \
  transformers \
  Pillow \
  accelerate

# Try to install dots.ocr from GitHub (this should pull its own dependencies)
RUN pip install --no-cache-dir git+https://github.com/rednote-hilab/dots.ocr.git

# Copy your handler file
COPY rp_handler.py /

# Start the container
CMD ["python3", "-u", "rp_handler.py"]