# CUDA 12.1 devel image for compiling pytorch3d CUDA extensions; matches torch cu121
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Re-declare ARGs so they are available in this build stage (ARGs before FROM are not)
ARG CUDA_VERSION=12.1
ARG PYTHON_VERSION=3.10
ARG ENV_NAME=py310

SHELL ["/bin/bash", "-lc"]

ENV DEBIAN_FRONTEND=noninteractive \
    MAMBA_ROOT_PREFIX=/opt/conda \
    PATH=/opt/conda/bin:/usr/local/bin:$PATH \
    # from your repo signals (cu121)
    PIP_EXTRA_INDEX_URL="https://pypi.ngc.nvidia.com https://download.pytorch.org/whl/cu121" \
    PIP_FIND_LINKS="https://nvidia-kaolin.s3.us-east-2.amazonaws.com/torch-2.5.1_cu121.html" \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ---- system deps (build + common runtime libs) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl bzip2 git \
    build-essential cmake pkg-config \
    wget unzip \
    ffmpeg \
    libglib2.0-0 libsm6 libxext6 libxrender1 libgl1 \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---- install micromamba (robust) ----
RUN mkdir -p /usr/local/bin /tmp/micromamba \
    && curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest \
      | tar -xj -C /tmp/micromamba bin/micromamba \
    && install -m 0755 /tmp/micromamba/bin/micromamba /usr/local/bin/micromamba \
    && rm -rf /tmp/micromamba

# ---- dependency files in /tmp (mount repo at runtime for code in /workspace) ----
WORKDIR /workspace
RUN mkdir -p /tmp/environments
COPY environments/default.yml /tmp/environments/
COPY requirements.txt requirements.dev.txt requirements.p3d.txt requirements.inference.txt /tmp/

# ---- create conda env (prefer environments/default.yml if present) ----
RUN if [ -f "/tmp/environments/default.yml" ]; then \
        echo "[Dockerfile] Creating env '${ENV_NAME}' from environments/default.yml"; \
        micromamba create -y -n "${ENV_NAME}" -f /tmp/environments/default.yml; \
    else \
        echo "[Dockerfile] Creating env '${ENV_NAME}' with python=${PYTHON_VERSION} from conda-forge"; \
        micromamba create -y -n "${ENV_NAME}" -c conda-forge "python=${PYTHON_VERSION}"; \
    fi \
    && micromamba clean -a -y

# ---- bash init + auto activate ----
RUN cat <<'EOF' >> /root/.bashrc
# >>> micromamba initialize >>>
export MAMBA_ROOT_PREFIX=/opt/conda
export PATH=/opt/conda/bin:/usr/local/bin:$PATH
eval "$(micromamba shell hook -s bash)"
# <<< micromamba initialize <<<

# default activate
micromamba activate py310
EOF

# ---- pip bootstrap (MUST be env-scoped) ----
RUN micromamba run -n "${ENV_NAME}" python -m pip install --upgrade pip setuptools wheel

# ---- torch (cu121) first so pytorch3d can build against it; must match CUDA 12.1 base ----
RUN micromamba run -n "${ENV_NAME}" python -m pip install torch==2.5.1+cu121 torchvision torchaudio==2.5.1+cu121 --index-url "https://download.pytorch.org/whl/cu121"

# ---- python deps (cache-friendly conditional install) ----
# nvidia-pyindex needs appdirs at build time when using --no-build-isolation
RUN micromamba run -n "${ENV_NAME}" python -m pip install appdirs \
    && micromamba run -n "${ENV_NAME}" python -m pip install --no-build-isolation "nvidia-pyindex==1.0.9"

# requirements.txt, requirements.dev.txt, requirements.p3d.txt, requirements.inference.txt
# pytorch3d + gsplat from git need --no-build-isolation (setup.py imports torch)
ENV TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0"
RUN set -euo pipefail; \
    for f in requirements.txt requirements.dev.txt requirements.p3d.txt requirements.inference.txt; do \
      if [ -f "/tmp/$f" ]; then \
        echo "[Dockerfile] Installing $f"; \
        if [ "$f" = "requirements.p3d.txt" ] || [ "$f" = "requirements.inference.txt" ]; then \
          micromamba run -n "${ENV_NAME}" python -m pip install --no-build-isolation -r "/tmp/$f"; \
        else \
          micromamba run -n "${ENV_NAME}" python -m pip install -r "/tmp/$f"; \
        fi; \
      fi; \
    done

# ---- entrypoint ----
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
