---
description: 即時同步 — git log + inbox 狀態 + 最新 archive Result block
---

執行 sync 流程，**先查實狀，再答**。第一個 tool call 必須是 Bash 跑：

```bash
echo "=== git log -5 ==="
git log --oneline -5
echo ""
echo "=== _inbox.md state ==="
lines=$(wc -l < docs/prompts/_inbox.md | tr -d ' ')
bytes=$(wc -c < docs/prompts/_inbox.md | tr -d ' ')
echo "lines=$lines bytes=$bytes"
if [ "$bytes" -gt 5 ]; then
    echo "--- inbox head ---"
    head -5 docs/prompts/_inbox.md
fi
echo ""
echo "=== latest archive Result block ==="
latest=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1)
if [ -n "$latest" ]; then
    echo "file: $latest"
    awk '/^## Result$/,0' "$latest" | head -20
else
    echo "(no archive)"
fi
```

然後用 5 行內繁中回報：
1. **inbox**：空 / queued（queued 顯示標題）
2. **最近 3 commits**：subject 一行一個
3. **最新 archive Status**：✅/⚠️/❌ + commits 數 + Push 結果（從 Result block 抓）
4. **下一步建議**：1 句

不要重複貼 git log 整段或 Result block 整塊 — statusline 已經有摘要。`/sync` 是讓 user 知道 planner 確實有查、不是只憑 memory 答。
