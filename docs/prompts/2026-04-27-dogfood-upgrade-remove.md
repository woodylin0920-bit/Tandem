# Dogfood: bootstrap.sh `--upgrade-existing` + `--remove` (real-world scenarios)

## Goal

S-1 加的 `--upgrade-existing` 跟 `--remove` 模式只在 mktemp sandbox 裡跑過 happy path（5/5 PASS）。這次**真的拿來操**，跑多種 realistic scenarios，找：
- dry-run 清單漏列 / 不夠清楚的地方
- jq merge / reverse-merge 在真實 user 改過的 settings.json 上的 bug
- hash-compare skip-if-modified 直覺對不對
- output 訊息誤導 / 格式醜
- corner cases（idempotency、re-upgrade、remove-after-upgrade）

**這輪不修任何 framework code** — 只跑、只記錄、只寫 report。發現的 bug/UX 問題 → 給 planner 排下一輪。

## Execution profile

- model: sonnet
- effort: medium（純驗證 + 觀察 + 寫 report）
- 2 commits（dogfood report / archive）

## Background context

S-1 ship 的兩個模式：
- `bash bootstrap.sh --upgrade-existing <path> [--apply]`
- `bash bootstrap.sh --remove <path> [--apply]`

兩者預設 dry-run，pre-flight 檢查 path 存在 + woody-harness project + (upgrade only) git repo + clean tree。

User 目前**沒有其他既有 bootstrap 過的真實專案**可以 dogfood，所以這輪用「人造舊版本專案」模擬。

---

## Commit 1: `docs: dogfood report — bootstrap upgrade/remove scenarios (2026-04-28)`

### A. 建測試環境

```bash
HARNESS=/Users/woody/Desktop/repo/public/woody-harness
TMPROOT=$(mktemp -d -t wh-dogfood-XXXXXX)
echo "TMPROOT=$TMPROOT"
```

所有 scenarios 跑在 $TMPROOT 下，最後完整清掉。

### B. 跑 4 個 scenarios（每個都記錄觀察）

#### Scenario 1: 「3 個月前 bootstrap 的舊專案」

模擬 user 早期 bootstrap、之後 woody-harness 升了 r3+r4+r5+S-1+rename 但 user 沒升。

```bash
# 建 baseline
cd $TMPROOT
bash $HARNESS/bootstrap.sh aged-project
cd aged-project

# 模擬「舊版本」狀態：砍掉所有 r3+r4+r5+rename 的產物
rm -f .claude/commands/sync.md
rm -f .claude/commands/brief.md
rm -f scripts/statusline.sh
rm -f scripts/notify-blocked.sh
rm -f scripts/session-briefing.sh
rm -f scripts/memory.sh
rm -f scripts/test-bootstrap.sh

# settings.json 改成只有 4d 那時候的版本（拿掉 statusLine + hooks + r4 permissions）
cat > .claude/settings.json <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(osascript:*)",
      "Bash(bash scripts/archive-prompts.sh:*)"
    ]
  }
}
EOF

# Commit「舊狀態」當基準
git add -A && git commit -q -m "simulate aged 4d-era state"

cd $HARNESS
```

跑 dry-run + 記錄：
```bash
bash $HARNESS/bootstrap.sh --upgrade-existing "$TMPROOT/aged-project" 2>&1 | tee /tmp/wh-dogfood-s1-dry.txt
```

→ **記錄觀察**到 report：dry-run 清單清楚嗎？哪些檔案標 "new file"、哪些 "diff"？settings.json merge 預期的 +N 數字對嗎？哪段訊息看起來怪？

跑 --apply：
```bash
bash $HARNESS/bootstrap.sh --upgrade-existing "$TMPROOT/aged-project" --apply 2>&1 | tee /tmp/wh-dogfood-s1-apply.txt
cd "$TMPROOT/aged-project"
git diff HEAD --stat
```

→ **記錄觀察**：實際寫入的檔案數 vs dry-run 預測對得上嗎？git diff 結果直覺嗎？

驗證：
```bash
test -f .claude/commands/sync.md && echo "PASS: sync.md restored"
test -f .claude/commands/brief.md && echo "PASS: brief.md installed (post-rename)"
test -f scripts/statusline.sh && echo "PASS: statusline restored"
bash scripts/statusline.sh && echo "PASS: statusline runs"
python3 -c "import json; d=json.load(open('.claude/settings.json')); assert d.get('statusLine'); assert 'hooks' in d; print('PASS: settings.json has statusLine + hooks')"
```

→ **記錄觀察**：哪些驗證 PASS？哪些 FAIL？

#### Scenario 2: 「user 客製化過某個 framework template」

```bash
cd $TMPROOT
bash $HARNESS/bootstrap.sh customized
cd customized

# user 客製化 docs/prompts/README.md（對 framework 加自己的註解）
echo "" >> docs/prompts/README.md
echo "## My team's convention" >> docs/prompts/README.md
echo "We always run /codex-audit before merging." >> docs/prompts/README.md
git add -A && git commit -q -m "user customization in prompts/README.md"

# 加一條 user-only permission（模擬 user 加了自己的 tool）
python3 -c "
import json
p = '.claude/settings.json'
d = json.load(open(p))
d['permissions']['allow'].append('Bash(jq:*)')
d['permissions']['allow'].append('Bash(my-custom-tool:*)')
json.dump(d, open(p,'w'), indent=2)
"
git add -A && git commit -q -m "user-only permissions added"

cd $HARNESS
```

跑 upgrade：
```bash
bash $HARNESS/bootstrap.sh --upgrade-existing "$TMPROOT/customized" 2>&1 | tee /tmp/wh-dogfood-s2-dry.txt
bash $HARNESS/bootstrap.sh --upgrade-existing "$TMPROOT/customized" --apply 2>&1 | tee /tmp/wh-dogfood-s2-apply.txt
```

→ **重點觀察**：
- `docs/prompts/README.md` 該被列在「Skipped — user-modified」嗎？user 期望看到 diff hint 對嗎？hint 命令真的能跑嗎？
- `Bash(jq:*)`、`Bash(my-custom-tool:*)` upgrade 後還在嗎？（jq 應該被去重視為跟 framework 一樣，my-custom-tool 一定要保留）

驗證：
```bash
cd "$TMPROOT/customized"
grep -q "My team's convention" docs/prompts/README.md && echo "PASS: user customization preserved"
python3 -c "import json; d=json.load(open('.claude/settings.json')); assert 'Bash(my-custom-tool:*)' in d['permissions']['allow']; print('PASS: user-only permission preserved')"
```

#### Scenario 3: 「重複跑 upgrade」（idempotency）

```bash
# 上面 Scenario 1 跑完後（已 upgrade 一次），再跑一次 dry-run
cd $HARNESS
bash $HARNESS/bootstrap.sh --upgrade-existing "$TMPROOT/aged-project" 2>&1 | tee /tmp/wh-dogfood-s3.txt
```

→ **重點觀察**：
- 預期：「Up-to-date (N): everything」、Would overwrite (0)、Would merge: nothing changed
- 實際呢？有沒有錯誤地把已是最新的檔案標為「would overwrite」？
- jq merge 是不是 idempotent？跑兩次會不會結果不一樣？

#### Scenario 4: 「Remove 拔光」

```bash
bash $HARNESS/bootstrap.sh --remove "$TMPROOT/customized" 2>&1 | tee /tmp/wh-dogfood-s4-dry.txt
bash $HARNESS/bootstrap.sh --remove "$TMPROOT/customized" --apply 2>&1 | tee /tmp/wh-dogfood-s4-apply.txt
```

→ **重點觀察**：
- Reverse-merge 後 user-only permissions（jq, my-custom-tool）保留？
- `docs/prompts/README.md` 因 user 改過 → 該 skip 不刪？
- `CLAUDE.md` / `RESUME.md` 沒被動？
- Empty dirs (`scripts/`, `.claude/commands/`, 可能 `.claude/`) 真的被 rmdir？
- Memory dir 完整保留？
- Output 「Memory dir location」訊息有印出嗎？

驗證：
```bash
cd "$TMPROOT/customized"
test -f CLAUDE.md && echo "PASS: CLAUDE.md preserved"
test -f RESUME.md && echo "PASS: RESUME.md preserved"
test -f docs/prompts/README.md && grep -q "My team's convention" docs/prompts/README.md && echo "PASS: customized README skipped"
test ! -f .claude/commands/inbox.md && echo "PASS: framework commands removed"
test ! -d scripts && echo "PASS: empty scripts/ dir removed"
SLUG=$(echo "$TMPROOT/customized" | sed 's|/|-|g')
test -d "$HOME/.claude-work/projects/$SLUG/memory" && echo "PASS: memory preserved"
# settings.json 該保留 user-only permissions OR 整檔被刪
if [ -f .claude/settings.json ]; then
    python3 -c "import json; d=json.load(open('.claude/settings.json')); assert 'Bash(my-custom-tool:*)' in d.get('permissions',{}).get('allow',[]); print('PASS: user-only permission preserved')"
else
    echo "INFO: settings.json deleted (user had no remaining keys)"
fi
```

### C. 寫 report

新增 `docs/dogfood/2026-04-28-upgrade-remove.md`（如 `docs/dogfood/` 不存在 → `mkdir -p`）：

```markdown
# Dogfood: bootstrap.sh upgrade/remove (2026-04-28)

**Span**: S-1 + polish-r5 + rename shipped → S-1 production-validated against 4 scenarios.
**Tester**: sonnet executor in dogfood inbox round.

## Scenarios run

| # | Scenario | Status |
|---|---|---|
| 1 | Aged 4d-era project upgraded to current | ✅ / ⚠️ / ❌ |
| 2 | User-customized project upgraded (preserves customization) | ✅ / ⚠️ / ❌ |
| 3 | Re-upgrade idempotency | ✅ / ⚠️ / ❌ |
| 4 | Remove after upgrade (full lifecycle) | ✅ / ⚠️ / ❌ |

## Findings — bugs / regressions

> List concrete bugs found. Each entry: severity (P0 / P1 / P2), what happened, repro snippet, proposed fix sketch.

- (none) / <list>

## Findings — UX awkwardness

> Things that work but feel weird. Each entry: what's awkward, what user might expect instead.

- <list>

## Findings — missing / unclear output

> Where the dry-run / apply output didn't tell user enough.

- <list>

## What worked well

> Things to preserve when refactoring.

- <list>

## Suggested next round

> What planner should consider for next inbox.

- <list>

## Raw output references

- Scenario 1 dry-run: `/tmp/wh-dogfood-s1-dry.txt` (excerpt below)
- Scenario 1 apply: `/tmp/wh-dogfood-s1-apply.txt` (excerpt below)
- Scenario 2 dry-run: `/tmp/wh-dogfood-s2-dry.txt`
- Scenario 2 apply: `/tmp/wh-dogfood-s2-apply.txt`
- Scenario 3 dry-run: `/tmp/wh-dogfood-s3.txt`
- Scenario 4 dry-run: `/tmp/wh-dogfood-s4-dry.txt`
- Scenario 4 apply: `/tmp/wh-dogfood-s4-apply.txt`

### Scenario 1 dry-run excerpt

\`\`\`
<paste 20-30 lines from /tmp/wh-dogfood-s1-dry.txt — the most informative chunk>
\`\`\`

### Scenario 2 dry-run excerpt (skip-if-modified)

\`\`\`
<paste the "Skipped — user-modified" section>
\`\`\`

### Scenario 4 dry-run excerpt (reverse-merge)

\`\`\`
<paste the reverse-merge + memory preservation message section>
\`\`\`
```

填寫指引：
- **Findings — bugs**：用 P0（功能壞）/ P1（行為錯但 user 能繞過）/ P2（cosmetic）。如果**沒找到 bug**，明確寫 "(none)"，不要編造。
- **UX awkwardness**：例如「dry-run 用 `+12 -3` diff 但不顯示是哪 12 行」、「skipped 訊息的 diff 命令太長/太複雜」、「Memory dir location 訊息埋太深」、「empty `scripts/` 沒 rmdir 訊息但實際 rmdir 了」之類。
- **What worked well**：例如「skip-if-modified 邏輯直覺正確」、「memory dir 真的沒被動」、「dry-run 預設保護 user 不誤刪」。

### D. 清理測試環境

```bash
# 清 mktemp dirs
rm -rf "$TMPROOT"

# 清對應的 memory dirs（dogfood 跑 bootstrap 會建 memory）
for slug in $(echo "$TMPROOT" | sed 's|/|-|g')-aged-project $(echo "$TMPROOT" | sed 's|/|-|g')-customized; do
    rm -rf "$HOME/.claude-work/projects/$slug"
done

# 清臨時 log
rm -f /tmp/wh-dogfood-s*.txt
```

> Output 已 paste 進 report，原始 log 不留。

---

## Verification（commit 前自己跑）

```bash
test -f docs/dogfood/2026-04-28-upgrade-remove.md && echo "PASS: report exists" || { echo "FAIL"; exit 1; }
grep -q "Scenario 1" docs/dogfood/2026-04-28-upgrade-remove.md && echo "PASS: scenarios documented" || { echo "FAIL"; exit 1; }
grep -q "Findings" docs/dogfood/2026-04-28-upgrade-remove.md && echo "PASS: findings section present" || { echo "FAIL"; exit 1; }
test ! -d "$TMPROOT" 2>/dev/null && echo "PASS: tmproot cleaned" || true   # $TMPROOT 已不在 shell var, 變通驗證

# 確認沒誤改 framework code
git diff --stat HEAD | grep -v "docs/dogfood\|docs/prompts/_inbox" && { echo "FAIL: unintended file changes"; exit 1; } || echo "PASS: only dogfood report + inbox modified"
```

要全 PASS 才 commit 1。

---

## Commit 2 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-dogfood-upgrade-remove.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify framework code（`bootstrap.sh`, `scripts/*`, `.claude/*`, `templates/*`, `RESUME.md`, `README.md`, `CHANGELOG.md` 等）。
2. **DO NOT** auto-fix bugs found — 純記錄、不修。修在下一輪。
3. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
4. 所有 mktemp 測試 dir 必須清乾淨（包括對應的 `~/.claude-work/projects/*` memory dir）。
5. 任何 scenario 的 verification 大量 FAIL → 不要中止測試，**繼續跑下一個 scenario**，把所有 finding 都記到 report；最後 commit 仍可 ship（report 本身就是 deliverable）。Block 只在「無法寫出 report」時才發生。
6. 用 mktemp dir 而不是固定路徑（避免污染 user 的工作目錄）。
7. 如果 dogfood 過程踩到 P0 bug 導致 test 中斷（例如 `bash bootstrap.sh` 直接 crash），記錄到 report，commit 仍 ship，user 看 report 排優先序。
8. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
9. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "dogfood done — see docs/dogfood/" with title "woody-harness"'`；無法寫 report → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped (report ready) | ❌ blocked (report not writable)
**Commits**: 2 (incl. archive)
<sha> docs: dogfood report — bootstrap upgrade/remove scenarios
<sha> chore: archive dogfood-upgrade-remove inbox prompt + result

**Scenarios**:
- 1. Aged 4d-era project upgraded: ✅ / ⚠️ / ❌
- 2. User-customized upgrade: ✅ / ⚠️ / ❌
- 3. Re-upgrade idempotency: ✅ / ⚠️ / ❌
- 4. Remove after upgrade: ✅ / ⚠️ / ❌

**Findings count**: P0=<n>, P1=<n>, P2=<n>, UX-awkward=<n>

**Cleanup**: ✅ tmp dirs + memory slugs removed / ⚠️ partial / ❌ failed

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped (report ready)
**Commits**: 2 (incl. archive)
c106eaa docs: dogfood report — bootstrap upgrade/remove scenarios (2026-04-28)
<archive-sha> chore: archive dogfood-upgrade-remove inbox prompt + result

**Scenarios**:
- 1. Aged 4d-era project upgraded: ✅
- 2. User-customized upgrade: ✅
- 3. Re-upgrade idempotency: ✅
- 4. Remove after upgrade: ✅

**Findings count**: P0=0, P1=0, P2=0, UX-awkward=5

**Cleanup**: ✅ tmp dirs + memory slugs removed

**Push**: ✅ pushed to origin/main
**Blockers**: none
