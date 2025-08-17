FROM nvcr.io/nvidia/pytorch:24.02-py3

WORKDIR /

# 安装系统依赖
RUN apt-get update && \
    apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# 升级 pip 和安装 wheel
RUN pip install --upgrade pip setuptools wheel

# 安装核心依赖
RUN pip install --no-cache-dir runpod

# PyTorch 已经包含在基础镜像中，无需重新安装

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