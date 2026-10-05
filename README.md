# runpod_wan

Wan Animate 2（人物置き換え）を RunPod で回すための一式。このフォルダが唯一の正。

## フォルダの約束

- setup_wan_animate2.sh … RunPod セットアップ（GitHub 経由で実行、触らない）
- wan_animate2.json … ワークフロー。ComfyUI で改造したら必ずここに Export し直す
- refs/ … 参照画像（キャラ）。膝上〜全身・正面・9:16・無地背景
- drive/ … 駆動動画。10秒以上、16fps 換算で 161 フレーム使う
- output/ … RunPod から落とした mp4

refs / drive / output は git には入らない（.gitignore）。

## RunPod 手順（毎回これだけ）

1. Pods → Deploy。テンプレ ComfyUI - CUDA 13.0、RTX 4090、Region Any、Disk 150GB。Volume なし。
2. Connect → Jupyter Lab → Launcher 下の Terminal。
3. 下の 1 行を貼って Enter。10 分放置。

   curl -sL https://raw.githubusercontent.com/masanitycom/runpod-wan/main/setup_wan_animate2.sh | bash

4. 「ComfyUI 起動確認 OK」が出たら Connect → HTTP 8188。左の「ワークフロー」に wan_animate2 がある。
5. Load Video (Upload) で drive/ の動画、Load Image で refs/ の画像をアップロード。
6. Character Prompt（人物＋背景を明示、白壁など）と Post Prompt を書く。シード fixed。
7. 実行。720x1280・6 ステップ・9 秒で約 28 分。キューは RAM 31GB の台なら 1 本ずつ、終わるごとに Manager → Restart。
8. Jupyter の runpod-slim/ComfyUI/output から mp4 を右クリック → Download。全部落としたら Pod を Terminate。

## ローカルで何か変えたら

    cd D:\runpod_wan
    git add -A
    git commit -m "update"
    git push

次の Pod から自動で反映される。

## VHS のバージョンを上げたら

PowerShell で

    Select-String -Path D:\ComfyUI\ComfyUI\custom_nodes\ComfyUI-VideoHelperSuite\pyproject.toml -Pattern version

を見て、setup_wan_animate2.sh の VHS_VERSION を書き換えて push。
