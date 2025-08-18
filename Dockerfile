# ✅ 公网可拉取的基础镜像（含 PyTorch/CUDA/cuDNN）
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

WORKDIR /

# ---- 0) 基础依赖（合并到前面相同位置）----
RUN apt-get update && apt-get install -y --no-install-recommends \
  git git-lfs curl wget unzip poppler-utils ca-certificates build-essential \
  libglib2.0-0 libgl1 \
  && rm -rf /var/lib/apt/lists/* && git lfs install

ENV PIP_NO_CACHE_DIR=1 PIP_DEFAULT_TIMEOUT=120 PYTHONUNBUFFERED=1

# ---- 1) 先固定 PyTorch / 基础 Python 依赖（按你的 CUDA 基镜像选择）----
# 注意：CUDA 12.x 可用 2.3/2.4
RUN pip install --upgrade pip setuptools wheel
RUN pip install "torch==2.3.1" --extra-index-url https://download.pytorch.org/whl/cu121
RUN pip install "opencv-python-headless" "pillow" "numpy" "scipy" "transformers>=4.41" "huggingface_hub>=0.23"

# 这些是很多基于 pyproject 的包在构建时需要的元依赖
RUN pip install "setuptools_scm" "build" "packaging" "ninja" "cmake"

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

# ---- 2) 安装 dots.ocr（去掉隔离、增加重试、锁定commit）----
# 有些仓库在 build isolation 下会找不到动态生成的版本号等，这里关闭隔离并给重试。
ARG DOTSOCR_REF=main   # 你也可以改成具体commit以提高确定性
RUN bash -lc '\
  for i in 1 2 3; do \
  pip install --no-build-isolation --verbose \
  "git+https://github.com/rednote-hilab/dots.ocr.git@${DOTSOCR_REF}" && exit 0; \
  echo "dots.ocr install failed, retry $i..." >&2; sleep 10; \
  done; \
  echo "dots.ocr install failed after retries" >&2; exit 1'

# ---- 3) 下载模型权重到镜像中（用 huggingface_hub，避免 git-lfs 大文件坑）----
ARG HF_TOKEN=""
ENV HUGGINGFACE_HUB_TOKEN=$HF_TOKEN

RUN python - <<'PY'
import os, time, sys
from huggingface_hub import snapshot_download
repo_id = "rednote-hilab/dots.ocr"  # ✅ 正确 repo_id（小写、带点）
target  = "/weights/DotsOCR"        # 目录名不要带点
tok     = os.getenv("HUGGINGFACE_HUB_TOKEN") or None
for i in range(3):
    try:
        snapshot_download(
            repo_id=repo_id,
            local_dir=target,
            local_dir_use_symlinks=False,
            token=tok
        )
        print("Downloaded:", repo_id, "->", target)
        break
    except Exception as e:
        print("Download failed try", i+1, ":", e, file=sys.stderr)
        if i == 2:
            raise
        time.sleep(10)
PY

ENV hf_model_path=/weights/DotsOCR
ENV PYTHONPATH=/weights:$PYTHONPATH

# 复制你的处理脚本
COPY rp_handler.py /

CMD ["python3", "-u", "rp_handler.py"]
