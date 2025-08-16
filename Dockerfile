FROM python:3.10-slim

WORKDIR /

# Use Chinese mirror sources for better stability and speed
RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#http://mirrors.tuna.tsinghua.edu.cn/ubuntu/#g' /etc/apt/sources.list && \
  sed -i 's#http://security.ubuntu.com/ubuntu/#http://mirrors.tuna.tsinghua.edu.cn/ubuntu/#g' /etc/apt/sources.list

# Install minimal system dependencies with better error handling
RUN apt-get clean && \
  apt-get update -o Acquire::AllowInsecureRepositories=true && \
  apt-get install -y --no-install-recommends \
  git \
  build-essential \
  libgl1-mesa-glx \
  libglib2.0-0 \
  libsm6 \
  libxext6 \
  libxrender-dev \
  libgomp1 \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

# Use Chinese PyPI mirror for better stability
RUN pip install --upgrade pip setuptools wheel -i https://pypi.tuna.tsinghua.edu.cn/simple/

# Install core dependencies step by step
RUN pip install --no-cache-dir runpod -i https://pypi.tuna.tsinghua.edu.cn/simple/

# Install PyTorch (CPU version for compatibility)
RUN pip install --no-cache-dir \
  torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install transformers and related packages
RUN pip install --no-cache-dir \
  transformers \
  Pillow \
  accelerate \
  -i https://pypi.tuna.tsinghua.edu.cn/simple/

# Install basic scientific computing packages
RUN pip install --no-cache-dir \
  numpy \
  opencv-python-headless \
  scipy \
  matplotlib \
  pandas \
  requests \
  tqdm \
  -i https://pypi.tuna.tsinghua.edu.cn/simple/

# For now, skip dots.ocr installation to get basic build working
# RUN pip install --no-cache-dir --verbose git+https://github.com/rednote-hilab/dots.ocr.git
RUN echo "dots.ocr installation skipped for now - will add later"

# Copy your handler file
COPY rp_handler.py /

# Start the container
CMD ["python3", "-u", "rp_handler.py"]