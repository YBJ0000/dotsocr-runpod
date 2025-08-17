FROM python:3.10-slim

WORKDIR /

# 安装系统级依赖
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    unzip \
    libgl1-mesa-glx \
    libglib2.0-0 \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# 升级 pip 和安装 wheel
RUN pip install --upgrade pip setuptools wheel

# 安装核心依赖
RUN pip install --no-cache-dir runpod

# 安装 PyTorch (CPU 版本)
RUN pip install --no-cache-dir \
    torch torchvision --index-url https://download.pytorch.org/whl/cpu

# 安装 dots.ocr 的基础依赖（除了 flash-attn）
RUN pip install --no-cache-dir \
    gradio \
    gradio_image_annotation \
    PyMuPDF \
    openai \
    qwen_vl_utils \
    transformers==4.51.3 \
    huggingface_hub \
    modelscope \
    accelerate \
    Pillow \
    numpy \
    scipy \
    matplotlib \
    opencv-python-headless \
    pdf2image

# 安装预编译的 flash-attn（避免编译问题）
RUN pip install --no-cache-dir \
    https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.0.8/flash_attn-2.7.4.post1+cu126torch2.7-cp310-cp310-linux_x86_64.whl || \
    echo "flash-attn installation failed, continuing without it"

# 安装 dots.ocr（这次应该能成功）
RUN pip install --no-cache-dir git+https://github.com/rednote-hilab/dots.ocr.git

# 复制你的 handler 文件
COPY rp_handler.py /

# 启动容器
CMD ["python3", "-u", "rp_handler.py"]