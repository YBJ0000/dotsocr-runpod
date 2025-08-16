FROM python:3.10-slim

WORKDIR /

# Install system dependencies
RUN apt-get update && apt-get install -y \
  git \
  build-essential \
  wget \
  curl \
  libgl1-mesa-glx \
  libglib2.0-0 \
  libsm6 \
  libxext6 \
  libxrender-dev \
  libgomp1 \
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

# Install additional dependencies that dots.ocr might need
RUN pip install --no-cache-dir \
  opencv-python-headless \
  numpy \
  scipy \
  matplotlib

# For now, skip dots.ocr installation to get basic build working
# RUN pip install --no-cache-dir --verbose git+https://github.com/rednote-hilab/dots.ocr.git
RUN echo "dots.ocr installation skipped for now - will add later"

# Copy your handler file
COPY rp_handler.py /

# Start the container
CMD ["python3", "-u", "rp_handler.py"]