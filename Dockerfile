# ✅ 公网可拉取的基础镜像（含 PyTorch/CUDA/cuDNN）
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

WORKDIR /

# ---- 0) 系统与Python依赖（与你现有保持一致）----
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl wget unzip file poppler-utils ca-certificates libglib2.0-0 libgl1 build-essential \
  && rm -rf /var/lib/apt/lists/*

ENV PIP_NO_CACHE_DIR=1 PIP_DEFAULT_TIMEOUT=120 PYTHONUNBUFFERED=1

# ---- 1) 先把 numpy 钉成 <2，避免后续包把它升级到2.x（采纳GPT建议）----
RUN pip install -U "pip>=24.0" setuptools wheel && \
  pip install "numpy<2"

# ---- 2) 预先固定大头依赖，避免后续解析带偏----
# 使用已知兼容的PyTorch版本组合，确保与dots.ocr兼容
RUN pip install "torch==2.2.0" "torchvision==0.17.0" "torchaudio==2.2.0" --index-url https://download.pytorch.org/whl/cu121
RUN pip install "opencv-python-headless" "pillow" "scipy"

# 验证PyTorch和torchvision版本匹配
RUN python -c "import torch, torchvision; print(f'PyTorch: {torch.__version__}'); print(f'TorchVision: {torchvision.__version__}'); assert torch.__version__.startswith('2.2.0'), 'PyTorch version mismatch'; assert torchvision.__version__.startswith('0.17.0'), 'TorchVision version mismatch'"

# ---- 3) 强制禁用FlashAttention2，使用SDPA替代----
# 设置环境变量强制transformers使用SDPA而不是FlashAttention2
ENV TRANSFORMERS_ATTN_IMPLEMENTATION=sdpa
ENV TRANSFORMERS_NO_FLASH_ATTENTION=1
ENV TORCH_BACKENDS_CUDA_SDPA_KERNEL=1

# ---- 4) 如果想要一点注意力加速，保留 xformers（有预编译轮子，安装成本低）----
RUN pip install --extra-index-url https://download.pytorch.org/whl/cu121 xformers==0.0.25.post1 || true

# ---- 4) 安装 dots.ocr 要求的依赖（版本匹配，采纳GPT建议）----
RUN pip install \
  transformers==4.51.3 \
  huggingface_hub \
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
  requests \
  runpod

# ---- 5) 下载 & 解压到 /opt/dots_ocr_src（采纳GPT建议）----
RUN set -eux; \
  curl -fL https://codeload.github.com/rednote-hilab/dots.ocr/zip/refs/heads/master -o /tmp/dotsocr.zip; \
  file /tmp/dotsocr.zip; \
  unzip -q /tmp/dotsocr.zip -d /opt; \
  mv /opt/dots.ocr-master /opt/dots_ocr_src; \
  test -f /opt/dots_ocr_src/setup.py; \
  rm -f /tmp/dotsocr.zip

# ---- 6) 在含 setup.py 的目录里安装（采纳GPT建议）----
WORKDIR /opt/dots_ocr_src

# 1) 先钉死 numpy<2（用 constraints 双保险）
RUN pip install -U "pip>=24.0" setuptools wheel && pip install "numpy<2"

# 2) 过滤上游 requirements.txt 中的 flash-attn，并确保 numpy<2 存在
RUN set -eux; \
  # constraints：强制所有后续安装都遵循 numpy<2
  echo 'numpy<2' > /tmp/pins.txt; \
  if [ -f requirements.txt ]; then \
  # 删除 flash-attn 相关行（大小写/连字符都兼容）
  sed -i -E '/^[[:space:]]*([Ff]lash[-_][Aa]ttn)([[:space:]=<>!].*)?$/d' requirements.txt; \
  # 若 requirements.txt 里没写 numpy，则追加一行
  grep -qiE '^[[:space:]]*numpy' requirements.txt || echo 'numpy<2' >> requirements.txt; \
  # 按约束安装
  PIP_CONSTRAINT=/tmp/pins.txt pip install -r requirements.txt; \
  fi

# 3) 安装 dots_ocr 源码（editable）
RUN python -m pip install -e . -vvv --root-user-action=ignore

# 4) 立即验证可导入
RUN python - <<'PY'
import importlib.util
spec = importlib.util.find_spec("dots_ocr")
print("find_spec('dots_ocr') ->", spec)
if spec is None:
    raise SystemExit("❌ cannot import dots_ocr")
print("✅ dots_ocr import OK")

# 验证FlashAttention2被禁用，SDPA被启用
import os
print("Environment variables:")
print(f"TRANSFORMERS_ATTN_IMPLEMENTATION: {os.getenv('TRANSFORMERS_ATTN_IMPLEMENTATION', 'NOT_SET')}")
print(f"TRANSFORMERS_NO_FLASH_ATTENTION: {os.getenv('TRANSFORMERS_NO_FLASH_ATTENTION', 'NOT_SET')}")
print(f"TORCH_BACKENDS_CUDA_SDPA_KERNEL: {os.getenv('TORCH_BACKENDS_CUDA_SDPA_KERNEL', 'NOT_SET')}")

# 强制设置环境变量
os.environ["TRANSFORMERS_ATTN_IMPLEMENTATION"] = "sdpa"
os.environ["TRANSFORMERS_NO_FLASH_ATTENTION"] = "1"
os.environ["TORCH_BACKENDS_CUDA_SDPA_KERNEL"] = "1"

print("✅ Environment variables set to disable FlashAttention2 and enable SDPA")
PY

# ---- 7) 用 huggingface_hub 把模型权重打进镜像（避免运行时再拉）----
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

# ---- 8) 设置环境变量（根据README指示，采纳GPT建议）----
# 设置模型路径环境变量（目录名不要带点）
ENV hf_model_path=/weights/DotsOCR
# 设置Python路径，让Python能找到模型和源码（直接赋值，不引用未定义变量）
ENV PYTHONPATH=/weights/DotsOCR:/opt/dots_ocr_src
# 强制禁用FlashAttention2，使用SDPA替代
ENV TRANSFORMERS_ATTN_IMPLEMENTATION=sdpa
ENV TRANSFORMERS_NO_FLASH_ATTENTION=1
ENV TORCH_BACKENDS_CUDA_SDPA_KERNEL=1

# ---- 9) 构建期自检：验证环境配置和模块搜索路径----
RUN python - <<'PY'
import os, sys, importlib.util
print("PYTHONPATH=", os.getenv("PYTHONPATH"))
print("hf_model_path=", os.getenv("hf_model_path"))
print("find_spec(dots_ocr) ->", importlib.util.find_spec("dots_ocr"))
print("find_spec(DotsOCR) ->", importlib.util.find_spec("DotsOCR"))

# 验证FlashAttention2禁用状态
print("FlashAttention2禁用状态:")
print(f"TRANSFORMERS_ATTN_IMPLEMENTATION: {os.getenv('TRANSFORMERS_ATTN_IMPLEMENTATION')}")
print(f"TRANSFORMERS_NO_FLASH_ATTENTION: {os.getenv('TRANSFORMERS_NO_FLASH_ATTENTION')}")
print(f"TORCH_BACKENDS_CUDA_SDPA_KERNEL: {os.getenv('TORCH_BACKENDS_CUDA_SDPA_KERNEL')}")

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
