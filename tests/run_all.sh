#!/usr/bin/env bash
# テストを全部走らせる。1 つでも失敗したら 0 以外で終わる。
#
#   ./tests/run_all.sh
#
# godot が PATH に無いときは GODOT=/path/to/godot を渡す。
set -u

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# 新しく足した class_name を登録し直す（しないと読み込めないことがある）。
"$GODOT" --headless --path . --editor --quit >/dev/null 2>&1

failed=0
for t in tests/test_*.gd; do
  echo "--- $t"
  out=$("$GODOT" --headless --path . --script "$t" 2>&1)
  status=$?
  echo "$out" | grep -v "^Godot Engine"
  if [ "$status" -ne 0 ]; then
    failed=1
  fi
  # 場面を抜けたあとも演出が動いていると、解放されたものを触って落ちる。
  # ヘッドレスではそれでも走り続けるので、ここで拾って失敗にする。
  if echo "$out" | grep -qE 'SCRIPT ERROR|Parameter "data.tree" is null|on a null value'; then
    echo "  失敗 スクリプトのエラーが出ている（上を見ること）"
    failed=1
  fi
  echo ""
done

if [ "$failed" -ne 0 ]; then
  echo "テストに失敗があります"
  exit 1
fi
echo "すべて通りました"
