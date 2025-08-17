FROM nvcr.io/nvidia/pytorch:24.02-py3

WORKDIR /

# 系统依赖（尽量精简；poppler-utils 用于 PDF -> image）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget unzip poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Python 工具 & 加速编译（如果兜底需要）
ENV PIP_NO_CACHE_DIR=1
RUN pip install -U pip setuptools wheel packaging ninja

# ---- 安装 FlashAttention 预编译 wheel（与 torch2.3 + CUDA12.3 + py3.10 匹配）----
# 优先用 wheel，失败再换 ABI 变体，仍失败再尝试 cu12 命名，最后兜底源码编译（MAX_JOBS=2）
ARG FA_VER=2.7.4.post1
ARG PYTAG=cp310-cp310
RUN set -eux; \
    BASE="https://github.com/Dao-AILab/flash-attention/releases/download/v${FA_VER}"; \
    pip install --no-build-isolation \
      ${BASE}/flash_attn-${FA_VER}+cu123torch2.3cxx11abiTRUE-${PYTAG}-linux_x86_64.whl \
  || pip install --no-build-isolation \
      ${BASE}/flash_attn-${FA_VER}+cu123torch2.3cxx11abiFALSE-${PYTAG}-linux_x86_64.whl \
  || pip install --no-build-isolation \
      ${BASE}/flash_attn-${FA_VER}+cu12torch2.3cxx11abiTRUE-${PYTAG}-linux_x86_64.whl \
  || pip install --no-build-isolation \
      ${BASE}/flash_attn-${FA_VER}+cu12torch2.3cxx11abiFALSE-${PYTAG}-linux_x86_64.whl \
  || (export MAX_JOBS=2; pip install --no-build-isolation flash-attn==${FA_VER})
# -------------------------------------------------------------------------------

# 可选：装 xformers 作为回退（不同 CUDA 小版本均尝试；失败就跳过）
RUN pip install --extra-index-url https://download.pytorch.org/whl/cu123 xformers==0.0.25.post1 || \
    pip install --extra-index-url https://download.pytorch.org/whl/cu121 xformers==0.0.25.post1 || true

# 其余依赖（合并成一个层；注意：不要再在 requirements 里写 flash-attn 了）
RUN pip install --no-cache-dir \
    runpod \
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

# 安装 dots.ocr（保持最新版或你指定的 commit）
RUN pip install --no-cache-dir git+https://github.com/rednote-hilab/dots.ocr.git

# 复制 handler
COPY rp_handler.py /

CMD ["python3", "-u", "rp_handler.py"]
