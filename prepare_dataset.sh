#!/bin/bash
# Prepare a RoboTwin LeRobot v3.0 dataset for lingbot-vla WITHOUT the RoboTwin simulator pipeline,
# by using robbyant's already-converted LeRobot **v2.1** datasets on the Hub and upgrading to v3.0.
#
#   robbyant/robotwin-clean-and-aug-lerobot
#     lerobot_robotwin_eef_clean_50/<task>-demo_clean_collect_200-50/   (50-demo clean, v2.1)
#     lerobot_robotwin_eef_aug_500/<task>-aloha-agilex_randomized_500-1000/ (randomized, v2.1)
#
# Flow:  download v2.1  ->  (optional merge multiple tasks)  ->  convert v2.1->v3.0 (in place in the
# lerobot cache)  ->  train with `--data.train_path <REPO_ID>`.
#
# NOTE: run on the server AFTER install_uv.sh (lerobot must be importable). The HF download is
# verified; the convert/cache wiring uses lerobot v0.4.2 CLIs (convert lands v3.0 in place at
# HF_LEROBOT_HOME/<repo_id>, backing up v2.1 to <repo_id>_old). Verify the printed train_path loads.
set -euo pipefail

PY=".venv/bin/python"
HF_DS="robbyant/robotwin-clean-and-aug-lerobot"
SUBSET="${SUBSET:-lerobot_robotwin_eef_clean_50}"          # or: lerobot_robotwin_eef_aug_500
TASK="${1:-click_bell-demo_clean_collect_200-50}"          # a per-task dir under ${SUBSET}
STAGE="${STAGE:-./data_stage}"
REPO_ID="robotwin_${TASK%%-*}"                             # e.g. robotwin_click_bell
export HF_LEROBOT_HOME="${HF_LEROBOT_HOME:-${HF_HOME:-$HOME/.cache/huggingface}/lerobot}"
DEST="${HF_LEROBOT_HOME}/${REPO_ID}"

echo "Task=${TASK}  -> repo_id=${REPO_ID}  -> ${DEST}"

# 1) Download just this task's v2.1 dataset (no RoboTwin sim needed).
${PY} scripts/download_hf_data.py --repo_id "${HF_DS}" --local_dir "${STAGE}" \
    --allow_patterns "${SUBSET}/${TASK}/*"

# 2) Place it where lerobot resolves a bare repo_id (HF_LEROBOT_HOME/<repo_id>).
rm -rf "${DEST}" "${DEST}_old" "${DEST}_v30"
mkdir -p "$(dirname "${DEST}")"
cp -r "${STAGE}/${SUBSET}/${TASK}" "${DEST}"

# 3) Upgrade v2.1 -> v3.0 in place (root defaults to HF_LEROBOT_HOME/repo_id, which we just filled,
#    so this does NOT hit the Hub). v3.0 ends up at ${DEST}, v2.1 backup at ${DEST}_old.
${PY} -m lerobot.datasets.v30.convert_dataset_v21_to_v30 --repo-id "${REPO_ID}"

echo
echo "Dataset ready (LeRobot v3.0): ${DEST}"
echo "Train with:"
echo "  --data.train_path ${REPO_ID} --data.data_name robotwin \\"
echo "  --data.norm_stats_file assets/norm_stats/robotwin_50.json"
echo
echo "--- Optional: joint 5-task training (merge in v2.1, then convert once) ---------------------"
echo "# After downloading several tasks into \${STAGE}/\${SUBSET}/ , merge them (same embodiment):"
echo "#   ${PY} scripts/merge_lerobot_v21.py \\"
echo "#       --sources \${STAGE}/\${SUBSET}/open_microwave-...,\${STAGE}/\${SUBSET}/click_bell-...,... \\"
echo "#       --output \${HF_LEROBOT_HOME}/robotwin_5tasks"
echo "#   ${PY} -m lerobot.datasets.v30.convert_dataset_v21_to_v30 --repo-id robotwin_5tasks"
echo "#   train with: --data.train_path robotwin_5tasks"
