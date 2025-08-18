# ✅ 公网可拉取的基础镜像（含 PyTorch/CUDA/cuDNN）
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

WORKDIR /

# ---- OS 依赖（尽量精简）----
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  git curl wget unzip poppler-utils \
  libglib2.0-0 libgl1 \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

ENV PIP_NO_CACHE_DIR=1 \
  PYTHONUNBUFFERED=1

# ---- Python 构建工具 / ninja（若需兜底编译会用到）----
RUN python -m pip install -U pip setuptools wheel packaging ninja

# ---- FlashAttention 预编译 wheel（跳过源码编译）----
# 适配 torch2.3 + cu12.x + py3.10；尝试 cxx11abi TRUE/FALSE 两种二进制
ARG FA_VER=2.7.4.post1
ARG PYTAG=cp310-cp310
RUN set -eux; \
  BASE="https://github.com/Dao-AILab/flash-attention/releases/download/v${FA_VER}"; \
  pip install --no-build-isolation \
  ${BASE}/flash_attn-${FA_VER}+cu12torch2.3cxx11abiTRUE-${PYTAG}-linux_x86_64.whl \
  || pip install --no-build-isolation \
  ${BASE}/flash_attn-${FA_VER}+cu12torch2.3cxx11abiFALSE-${PYTAG}-linux_x86_64.whl \
  || (export MAX_JOBS=2; pip install --no-build-isolation flash-attn==${FA_VER})

# （可选）装 xformers 作为回退
RUN pip install --extra-index-url https://download.pytorch.org/whl/cu121 xformers==0.0.25.post1 || true

# ---- 其余 Python 依赖（用较稳妥的版本上限）----
# 说明：transformers 固定到较新但稳定的版本，避免与 modelscope/qwen_vl_utils 冲突
RUN pip install \
  runpod \
  "transformers<=4.43.3" \
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

# ---- 安装 huggingface_hub 用于下载模型权重----
RUN pip install huggingface_hub

# ---- 用 huggingface_hub 下载模型权重到 /weights/DotsOCR----
RUN python - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="rednote-hilab/dots.ocr",
    local_dir="/weights/DotsOCR",
    local_dir_use_symlinks=False
)
PY

# ---- 设置环境变量和PYTHONPATH（官方要求）----
ENV hf_model_path=/weights/DotsOCR \
  PYTHONPATH=/weights:$PYTHONPATH

# ---- 安装 dots.ocr 代码，包含所有依赖----
RUN pip install git+https://github.com/rednote-hilab/dots.ocr.git

# 复制你的处理脚本
COPY rp_handler.py /

CMD ["python3", "-u", "rp_handler.py"]
