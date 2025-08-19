# ✅ 公网可拉取的基础镜像（含 PyTorch/CUDA/cuDNN）
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

WORKDIR /

# ---- 0) 系统与Python依赖（与你现有保持一致）----
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl wget unzip poppler-utils ca-certificates libglib2.0-0 libgl1 build-essential \
  && rm -rf /var/lib/apt/lists/*

ENV PIP_NO_CACHE_DIR=1 PIP_DEFAULT_TIMEOUT=120 PYTHONUNBUFFERED=1

RUN pip install --upgrade pip setuptools wheel
# 预先固定大头依赖，避免后续解析带偏
RUN pip install "torch==2.3.1" --extra-index-url https://download.pytorch.org/whl/cu121
RUN pip install "opencv-python-headless" "pillow" "numpy" "scipy" "transformers>=4.41" "huggingface_hub>=0.23"

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
  accelerate \
  gradio \
  gradio_image_annotation \
  PyMuPDF \
  openai \
  qwen_vl_utils \
  modelscope \
  matplotlib \
  pdf2image

# ---- 1) 下载 dots.ocr 源码 zip → /opt/dots_ocr_src（codeload + 严格校验 + 重试）----
RUN set -eux; \
  for i in 1 2 3; do \
  curl -fsSL "https://codeload.github.com/rednote-hilab/dots.ocr/zip/refs/heads/main" -o /tmp/dotsocr.zip \
  && file /tmp/dotsocr.zip \
  && unzip -tq /tmp/dotsocr.zip \
  && unzip -q /tmp/dotsocr.zip -d /opt \
  && mv /opt/dots.ocr-main /opt/dots_ocr_src \
  && rm -f /tmp/dotsocr.zip && break \
  || { echo "download/unzip failed try $i"; rm -f /tmp/dotsocr.zip; sleep 10; }; \
  done

# ---- 3) 用 huggingface_hub 把模型权重打进镜像（避免运行时再拉）----
ARG HF_TOKEN=""
ENV HUGGINGFACE_HUB_TOKEN=$HF_TOKEN

RUN python - <<'PY'
import os, time, sys
from huggingface_hub import snapshot_download
repo_id = "rednote-hilab/dots.ocr"      # ✅ 正确 repo_id（小写、带点）
target  = "/weights/DotsOCR"            # 目录名不要带点
tok     = os.getenv("HUGGINGFACE_HUB_TOKEN") or None
for i in range(3):
    try:
        snapshot_download(repo_id=repo_id, local_dir=target, local_dir_use_symlinks=False, token=tok)
        print("Downloaded:", repo_id, "->", target)
        break
    except Exception as e:
        print("Download failed try", i+1, ":", e, file=sys.stderr)
        if i == 2: raise
        time.sleep(10)
PY

# ---- 4) 设置环境变量（放在源码解压和权重下载之后，CMD之前）----
ENV hf_model_path=/weights/DotsOCR
ENV PYTHONPATH=/opt/dots_ocr_src:/weights:$PYTHONPATH

# 复制你的处理脚本
COPY rp_handler.py /

CMD ["python3", "-u", "rp_handler.py"]
