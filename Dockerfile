FROM python:3.10-slim

WORKDIR /

# Install minimal system dependencies with better error handling
RUN apt-get clean && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  git \
  build-essential \
  poppler-utils \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

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

# Install basic scientific computing packages
RUN pip install --no-cache-dir \
  numpy \
  pandas \
  requests \
  tqdm \
  scipy \
  matplotlib \
  opencv-python-headless \
  PyMuPDF \
  pdf2image

# Install dots.ocr dependencies first (without flash-attn)
RUN pip install --no-cache-dir \
  gradio \
  gradio_image_annotation \
  openai \
  qwen_vl_utils \
  modelscope

# Try to install dots.ocr with --no-deps to avoid flash-attn compilation
RUN pip install --no-cache-dir --no-deps git+https://github.com/rednote-hilab/dots.ocr.git || \
  echo "dots.ocr installation failed, will try alternative approach"

# Copy your handler file
COPY rp_handler.py /

# Start the container
CMD ["python3", "-u", "rp_handler.py"]