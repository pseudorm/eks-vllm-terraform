# syntax=docker/dockerfile:1.7
#
# Lean ComfyUI image for EKS GPU nodes.
#
# Leanness decisions:
#   - python:3.11-slim base instead of nvidia/cuda:*-runtime. The PyTorch cu12x
#     wheels bundle their own CUDA runtime libraries, and the NVIDIA container
#     toolkit / k8s device plugin injects the driver at runtime. The CUDA base
#     image would add several GB of duplicate toolkit for no benefit.
#   - Multi-stage: git, compilers and pip caches stay in the builder. Only the
#     virtualenv and the ComfyUI source land in the final layer.
#   - No models, custom_nodes or outputs baked in — those are PVC mounts
#     (see deployment-backend.yaml).
#
# Build:
#   docker build -f comfyui.dockerfile -t comfy-backend:latest .
#   (build context is unused — nothing is COPYed from it)

ARG PYTHON_VERSION=3.12
# Declared before the first FROM (global scope) so the stage-2 FROM below
# can reference it — an ARG declared inside a stage is only visible to
# stages built FROM that stage, not to later independent FROM lines.
ARG NVIDIA_CUDA_IMAGE_VERSION=13.0.3-cudnn-runtime-ubuntu24.04

# ---------------------------------------------------------------------------
# Stage 1 — builder
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Use the system Python across both stages
ENV UV_PYTHON_DOWNLOADS=0

# Pin these for reproducible builds. COMFYUI_REF accepts a tag or commit SHA;
# `master` is convenient for dev but is NOT reproducible — pin before prod.
# ARG COMFYUI_REF=master
# CUDA wheel channel. cu124 covers Ada/Hopper (L4, L40S, A10G, H100).
ARG PYTORCH_SUPPORTED_CUDA_VERSION=130
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu${PYTORCH_SUPPORTED_CUDA_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# git is builder-only. build-essential is needed by a few sdist-only deps.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

# Shallow clone — no history in the final image.
# WORKDIR /src
# RUN git clone --depth 1 --branch "${COMFYUI_REF}" \
#      https://github.com/Comfy-Org/ComfyUI.git /src/ComfyUI \
#  || (git clone --filter=blob:none https://github.com/Comfy-Org/ComfyUI.git /src/ComfyUI \
#      && git -C /src/ComfyUI checkout --detach "${COMFYUI_REF}") \
#  && rm -rf /src/ComfyUI/.git
WORKDIR /src
RUN git clone https://github.com/Comfy-Org/ComfyUI.git /src/ComfyUI

# Self-contained venv so the runtime stage needs no pip resolution.
RUN uv venv /opt/venv --python=${PYTHON_VERSION}
ENV PATH="/opt/venv/bin:${PATH}"

# torch first, from the CUDA channel, so requirements.txt cannot pull the
# CPU-only wheel from PyPI as a transitive dependency.
RUN uv pip install --extra-index-url "${TORCH_INDEX_URL}" \
     -r /src/ComfyUI/requirements.txt

# Drop test suites and bytecode caches from site-packages.
RUN find /opt/venv -type d -name '__pycache__' -prune -exec rm -rf {} + \
 && find /opt/venv -type d -name 'tests' -prune -exec rm -rf {} + \
 && find /opt/venv -type d -name 'test' -prune -exec rm -rf {} +

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive

# libgl1 + libglib2.0-0 are the OpenCV shared-object deps that most custom
# nodes expect. libgomp1 is required by onnxruntime / some upscalers.
# Everything else stays out.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libgl1 \
      libglib2.0-0 \
      libgomp1 \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Matches PYTORCH_CUDA_ALLOC_CONF in deployment-backend.yaml; the env var
    # there overrides this, this is just a sane default for local runs.
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    COMFYUI_PORT=8188

# Non-root. UID 1000 so PVC-mounted dirs are writable with fsGroup: 1000.
# Ubuntu 24.04 base images ship a default user/group already on 1000
# (e.g. "ubuntu"), so reclaim it before creating ours.
RUN if getent group 1000 >/dev/null; then groupdel "$(getent group 1000 | cut -d: -f1)"; fi \
 && if getent passwd 1000 >/dev/null; then userdel -r "$(getent passwd 1000 | cut -d: -f1)" 2>/dev/null || true; fi \
 && groupadd --gid 1000 comfy \
 && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin comfy

COPY --from=builder --chown=1000:1000 /opt/venv /opt/venv
COPY --from=builder --chown=1000:1000 /src/ComfyUI /app

WORKDIR /app

# ComfyUI resolves models/, output/, custom_nodes/, input/, temp/, user/
# relative to the repo root, so /app lines up with the PVC mountPaths.
# Pre-create them owned by comfy: the three PVC-backed dirs need correct
# ownership for the mount, and input/temp/user are written at runtime.
RUN mkdir -p /app/models /app/output /app/custom_nodes /app/input /app/temp /app/user \
 && chown -R 1000:1000 /app

USER 1000:1000

EXPOSE 8188

# /system_stats is served by the ComfyUI API and needs no model to be loaded,
# so it is a valid readiness signal. Adjust/remove if you define k8s probes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python -c "import urllib.request,os,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:'+os.environ['COMFYUI_PORT']+'/system_stats',timeout=4).status==200 else 1)"

# --listen 0.0.0.0 is required for the k8s Service to reach the pod.
# Exec form so ComfyUI receives SIGTERM directly on pod termination.
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
