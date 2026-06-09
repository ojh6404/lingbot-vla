#!/bin/bash
# uv-only install for lingbot-vla (NO conda). Python 3.12 + PyTorch 2.9.0 + CUDA 12.8.
#
# lingbot pins torch==2.8.0 (setup.py) and torchcodec==0.6.0 (requirements.txt, torch-2.8 only).
# overrides_uv.txt forces the torch 2.9 / cu128 stack so `uv pip install` keeps it everywhere.
#
# Prereqs on the server:
#   - uv on PATH
#   - CUDA 12.8 toolkit (nvcc) for the flash-attn BUILD step only (torch ships its own runtime).
#     e.g. `module load cuda/12.8`
#
# Usage:  bash install_uv.sh    (from the repo root)
set -euo pipefail

PYTHON_VERSION=3.12
TORCH_CUDA_INDEX="https://download.pytorch.org/whl/cu128"

# 1) venv (uv fetches CPython 3.12 itself -- no conda).
uv venv --python "${PYTHON_VERSION}" .venv
export VIRTUAL_ENV="$(pwd)/.venv"
PY="${VIRTUAL_ENV}/bin/python"
UVPIP="uv pip install --python ${PY} --override overrides_uv.txt"

# 2) torch 2.9.0 trio from the CUDA 12.8 index FIRST (so it is already satisfied for later steps).
uv pip install --python "${PY}" --index-url "${TORCH_CUDA_INDEX}" \
    torch==2.9.0 torchvision==0.24.0 torchaudio==2.9.0

# 3) LeRobot v0.4.2 (pinned tarball). --override keeps torch at 2.9 if lerobot requests otherwise.
${UVPIP} "https://github.com/huggingface/lerobot/archive/refs/tags/v0.4.2.tar.gz"

# 4) submodules (MoGe, lingbot-depth).
git submodule update --init --recursive --remote

# 5) lingbotvla package + its deps. --override rewrites the torch==2.8.0 / torchcodec==0.6.0 pins
#    to the 2.9 stack; the already-installed cu128 torch satisfies them (no re-download).
${UVPIP} -e .

# 6) vision-model submodules (lingbot-depth has conflicting deps -> --no-deps, as in install.sh).
${UVPIP} -e ./lingbotvla/models/vla/vision_models/lingbot-depth/ --no-deps
${UVPIP} -e ./lingbotvla/models/vla/vision_models/MoGe/

# 7) flash-attn 2.8.3. Try a source build against the installed torch 2.9 (needs nvcc/CUDA 12.8 +
#    the venv build deps). If that fails (no nvcc, too slow, OOM), fall back to a prebuilt wheel
#    matching exactly this stack: cu128 / torch2.9 / cp312 (Python 3.12) / linux_x86_64.
#    NOTE: the prebuilt wheel is cp312-specific -- if you change PYTHON_VERSION, pick the matching
#    cpXY wheel from https://github.com/mjun0812/flash-attention-prebuild-wheels/releases
FA_PREBUILT="https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.9.0/flash_attn-2.8.3+cu128torch2.9-cp312-cp312-linux_x86_64.whl"
${UVPIP} ninja packaging wheel setuptools
if ! uv pip install --python "${PY}" flash-attn==2.8.3 --no-build-isolation; then
    echo ">>> flash-attn source build failed; installing prebuilt wheel (cu128/torch2.9/cp312)..."
    uv pip install --python "${PY}" "${FA_PREBUILT}"
fi

echo
echo "Done. Sanity check:"
echo "  ${PY} -c 'import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())'"
echo "Run training with:  uv run --no-project bash train.sh tasks/vla/train_lingbotvla.py ..."
echo "  (or: source .venv/bin/activate && bash train.sh ...)"
