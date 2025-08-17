FROM nvidia/cuda:11.8-devel-ubuntu20.04

WORKDIR /

# 安装 Python 3.10 和系统依赖
RUN apt-get update && \
    apt-get install -y \
    python3.10 \
    python3.10-dev \
    python3.10-distutils \
    python3-pip \
    git \
    curl \
    wget \
    unzip \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# 设置 Python 3.10 为默认
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1

# 升级 pip 和安装 wheel
RUN python3 -m pip install --upgrade pip setuptools wheel

# 安装核心依赖
RUN pip install --no-cache-dir runpod

# 安装 PyTorch（CUDA 版本，匹配 CUDA 11.8）
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu118

# 安装 dots.ocr 的基础依赖
RUN pip install --no-cache-dir \
    transformers==4.51.3 \
    Pillow \
    accelerate \
    gradio \
    gradio_image_annotation \
    PyMuPDF \
    openai \
    qwen_vl_utils \
    modelscope \
    numpy \
    scipy \
    matplotlib \
    opencv-python-headless \
    pdf2image

# 现在应该能正常安装 flash-attn（有 CUDA 编译环境）
RUN pip install --no-cache-dir flash-attn==2.8.0.post2

# 安装 dots.ocr（这次应该能成功）
RUN pip install --no-cache-dir git+https://github.com/rednote-hilab/dots.ocr.git

# 复制你的 handler 文件
COPY rp_handler.py /

# 启动容器
CMD ["python3", "-u", "rp_handler.py"]