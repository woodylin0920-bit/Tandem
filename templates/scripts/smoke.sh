#!/usr/bin/env bash
# Real-machine smoke test runner.
# 跟 pytest 不同：smoke 是「人在硬體前親自確認 user-perceivable 行為」
# Pre-condition: driver 自動，每個 test case 仍需 user 手動觀察 + 回答 ✅/❌

set -euo pipefail

PROJECT_NAME="{{PROJECT_NAME}}"

echo "=========================================="
echo "  $PROJECT_NAME — Real-Machine Smoke Test"
echo "=========================================="
echo ""
echo "你會被問 N 個 yes/no 問題，每個需要實機觀察。"
echo "卡住任何一個 → ❌ 表示對應 P0 還沒修好。"
echo ""

ask() {
    local question="$1"
    read -p "$question (y/n): " ans
    case "$ans" in
        y|Y|yes) echo "✅ pass"; return 0 ;;
        *) echo "❌ FAIL"; exit 1 ;;
    esac
}

# === Test 1: 範例 — 啟動就有 user-visible signal ===
echo ""
echo "--- Test 1: 啟動信號 ---"
echo "請在另一個 terminal 執行："
echo "  $PROJECT_NAME --some-cmd"
echo "等啟動 + 第一個 user-visible signal 出現"
ask "聽到/看到/感到啟動信號了嗎？"

# === Test 2: 範例 — 失敗 path 會發出 user-visible 警示 ===
echo ""
echo "--- Test 2: 失敗反饋 ---"
echo "在另一 terminal 殺掉必要 daemon："
echo "  brew services stop {{REQUIRED_DAEMON}}"
echo "然後在主程式觸發需要該 daemon 的功能"
ask "user 有沒有得到失敗信號（TTS / UI / 震動）？"

# === Test 3+ (專案特定): ===
# 加你的 smoke test...

echo ""
echo "=========================================="
echo "  ✅ 全部 smoke test 通過"
echo "=========================================="
