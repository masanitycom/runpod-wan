#!/bin/bash
# RunPod ComfyUI (runpod/comfyui テンプレ) で Wan Animate 2 蒸留版を回す一発セットアップ v4
#
# 使い方（RunPod の Jupyter → Terminal で 1 行）:
#   curl -sL https://raw.githubusercontent.com/masanitycom/runpod-wan/main/setup_wan_animate2.sh | bash
#
# やること: ComfyUI 更新 → VHS をローカルと同じ版に固定 → モデル4本DL →
#           ワークフロー JSON を GitHub から取ってきて workflows に配置 → ComfyUI 再起動
# 10分放置。最後に「ComfyUI 起動確認 OK」が出たら 8188 を開く。ワークフロー一覧に wan_animate2 が入っている。
#
# ローカルの D:\runpod_wan を更新したら git push するだけで次回から反映される。
set -e

# ======== ここだけ自分用に書き換える ========
REPO_RAW=https://raw.githubusercontent.com/masanitycom/runpod-wan/main
WORKFLOW_NAME=wan_animate2.json
# ローカル(デスクトップ版 ComfyUI)の VHS バージョン。PowerShell で
#   Select-String -Path D:\ComfyUI\ComfyUI\custom_nodes\ComfyUI-VideoHelperSuite\pyproject.toml -Pattern version
VHS_VERSION=1.7.9
# ============================================

# ---- ComfyUI の場所 ----
if [ -d /workspace/runpod-slim/ComfyUI ]; then
  COMFY=/workspace/runpod-slim/ComfyUI
elif [ -d /workspace/ComfyUI ]; then
  COMFY=/workspace/ComfyUI
else
  COMFY=$(find / -maxdepth 4 -type d -name ComfyUI -path "*workspace*" 2>/dev/null | head -1)
fi
echo "ComfyUI: $COMFY"

# ---- venv の python ----
PY=$(ls -d $COMFY/.venv*/bin/python 2>/dev/null | head -1)
[ -z "$PY" ] && PY=$(which python3)
echo "python: $PY"

# ---- 起動引数を控える ----
ORIG_ARGS=$(ps -eo args | grep "[m]ain.py" | head -1 | sed 's/^[^ ]*python[^ ]* //')
[ -z "$ORIG_ARGS" ] && ORIG_ARGS="main.py --listen 0.0.0.0 --port 8188 --enable-cors-header"
echo "起動引数: $ORIG_ARGS"

# ---- 1. ComfyUI 本体を最新に ----
echo "== ComfyUI 更新 =="
cd $COMFY
git fetch -q origin
git reset -q --hard origin/master
$PY -m pip install -q -r requirements.txt 2>&1 | grep -v notice || true

# ---- 2. VideoHelperSuite（ローカルと同じバージョンに固定）----
echo "== VHS 導入 (version $VHS_VERSION) =="
cd $COMFY/custom_nodes
VHS_DIR=""
for d in comfyui-videohelpersuite ComfyUI-VideoHelperSuite; do
  [ -d "$d" ] && VHS_DIR="$d" && break
done
if [ -z "$VHS_DIR" ]; then
  VHS_DIR=comfyui-videohelpersuite
  git clone -q https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git $VHS_DIR
fi
cd $VHS_DIR
git fetch -q --all --tags
VHS_COMMIT=$(git log --format=%H -S"version = \"$VHS_VERSION\"" -- pyproject.toml | tail -1)
if [ -n "$VHS_COMMIT" ]; then
  git checkout -q $VHS_COMMIT
else
  echo "WARN: VHS $VHS_VERSION が履歴にない。最新で続行（Load Video の値を目視確認すること）"
  git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null || true
  git pull -q || true
fi
echo "VHS version: $(grep -m1 '^version' pyproject.toml)"
$PY -m pip install -q -r requirements.txt 2>&1 | grep -v notice || true
cd $COMFY/custom_nodes

# ---- 3. モデル4本 ----
echo "== モデル DL =="
cd $COMFY/models
mkdir -p diffusion_models text_encoders clip_vision vae
BASE=https://huggingface.co/Comfy-Org/Wan-Animate-2/resolve/main
dl () {
  if [ -f "$1/$2" ]; then echo "skip $2"; else
    wget -q --show-progress -c -O "$1/$2" "$BASE/$1/$2"
  fi
}
dl diffusion_models wan_animate_2_distill_int8_convrot.safetensors
dl text_encoders    umt5_xxl_fp8_e4m3fn_scaled.safetensors
dl clip_vision      clip_vision_h.safetensors
dl vae              Wan2_1_VAE_bf16.safetensors

# ---- 4. ワークフロー JSON（GitHub から取得。/workspace に手置きした json があればそれも配置）----
echo "== ワークフロー配置 =="
mkdir -p $COMFY/user/default/workflows
curl -sfL "$REPO_RAW/$WORKFLOW_NAME" -o "$COMFY/user/default/workflows/$WORKFLOW_NAME" \
  && echo "workflow: $WORKFLOW_NAME (GitHub)" \
  || echo "WARN: GitHub から $WORKFLOW_NAME を取得できなかった"
for f in /workspace/*.json; do
  [ -f "$f" ] && cp -f "$f" $COMFY/user/default/workflows/ && echo "workflow: $(basename $f) (/workspace)"
done

# ---- 5. ComfyUI 再起動 ----
echo "== ComfyUI 再起動 =="
pkill -f "main.py" || true
sleep 3
cd $COMFY
nohup $PY $ORIG_ARGS > /workspace/comfy_restart.log 2>&1 &

# ---- 6. 起動待ち ----
echo -n "起動待ち"
for i in $(seq 1 60); do
  if curl -s -o /dev/null http://127.0.0.1:8188/; then
    echo; echo "== ComfyUI 起動確認 OK。8188 を開く =="; exit 0
  fi
  echo -n "."; sleep 3
done
echo; echo "== 3分待っても応答なし。tail -30 /workspace/comfy_restart.log を確認 =="
