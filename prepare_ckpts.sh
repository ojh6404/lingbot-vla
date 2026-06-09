#!/bin/bash
# Download the checkpoints lingbot-vla needs (robotwin, non-depth path). Run after install_uv.sh.
# Usage:  bash prepare_ckpts.sh [CKPT_DIR]     (default CKPT_DIR=./ckpts)
set -euo pipefail

PY=".venv/bin/python"
CKPT_DIR="${1:-./ckpts}"

# download_hf_model.py saves to <CKPT_DIR>/<repo-name>, e.g. ./ckpts/lingbot-vla-4b
${PY} scripts/download_hf_model.py --repo_id robbyant/lingbot-vla-4b        --local_dir "${CKPT_DIR}"
${PY} scripts/download_hf_model.py --repo_id Qwen/Qwen2.5-VL-3B-Instruct    --local_dir "${CKPT_DIR}"

# Depth variant only (configs/vla/*_depth.yaml) -- uncomment if you train with depth:
# ${PY} scripts/download_hf_model.py --repo_id Ruicheng/moge-2-vitb-normal              --local_dir "${CKPT_DIR}"
# ${PY} scripts/download_hf_model.py --repo_id robbyant/lingbot-depth-pretrain-vitl-14  --local_dir "${CKPT_DIR}"

echo
echo "Checkpoints ready:"
echo "  ${CKPT_DIR}/lingbot-vla-4b           (--model.model_path)"
echo "  ${CKPT_DIR}/Qwen2.5-VL-3B-Instruct   (--model.tokenizer_path)"
