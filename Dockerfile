# ✅ 公网可拉取的基础镜像（含 PyTorch/CUDA/cuDNN）
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

WORKDIR /

# ---- 0) 系统与Python依赖（与你现有保持一致）----
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl wget unzip file poppler-utils ca-certificates libglib2.0-0 libgl1 build-essential \
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
  pdf2image \
  tqdm \
  requests

# ---- 1) 下载 & 解压到 /opt/dots_ocr_src（采纳GPT建议）----
RUN set -eux; \
  curl -fL https://codeload.github.com/rednote-hilab/dots.ocr/zip/refs/heads/master -o /tmp/dotsocr.zip; \
  file /tmp/dotsocr.zip; \
  unzip -q /tmp/dotsocr.zip -d /opt; \
  mv /opt/dots.ocr-master /opt/dots_ocr_src; \
  test -f /opt/dots_ocr_src/setup.py; \
  rm -f /tmp/dotsocr.zip

# ---- 2) 在含 setup.py 的目录里安装（采纳GPT建议）----
WORKDIR /opt/dots_ocr_src
RUN pip install -U pip setuptools wheel && \
  if [ -f requirements.txt ]; then pip install -r requirements.txt; fi && \
  python -m pip install -e . -vvv

# ---- 3) 立即验证包可导入（采纳GPT建议）----
RUN python - <<'PY'
import importlib.util
spec = importlib.util.find_spec("dots_ocr")
print("find_spec('dots_ocr') ->", spec)
if spec is None:
    raise SystemExit("❌ cannot import dots_ocr")
PY

# ---- 4) 用 huggingface_hub 把模型权重打进镜像（避免运行时再拉）----
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

# ---- 5) 设置环境变量（根据README指示，采纳GPT建议）----
# 设置模型路径环境变量（目录名不要带点）
ENV hf_model_path=/weights/DotsOCR
# 设置Python路径，让Python能找到模型和源码（直接赋值，不引用未定义变量）
ENV PYTHONPATH=/weights/DotsOCR:/opt/dots_ocr_src

# ---- 6) 构建期自检：验证环境配置和模块搜索路径----
RUN python - <<'PY'
import os, sys, importlib.util
print("PYTHONPATH=", os.getenv("PYTHONPATH"))
print("hf_model_path=", os.getenv("hf_model_path"))
print("find_spec(dots_ocr) ->", importlib.util.find_spec("dots_ocr"))
print("find_spec(DotsOCR) ->", importlib.util.find_spec("DotsOCR"))
print("Available modules in /weights/DotsOCR:")
weights_dir = "/weights/DotsOCR"
if os.path.exists(weights_dir):
    for item in os.listdir(weights_dir):
        print(f"  - {item}")
PY

# 复制你的处理脚本
WORKDIR /
COPY rp_handler.py /

CMD ["python3", "-u", "rp_handler.py"]
