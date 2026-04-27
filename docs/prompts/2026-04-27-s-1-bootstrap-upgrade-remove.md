# S-1: bootstrap.sh `--upgrade-existing` + `--remove` modes

## Goal

讓 `bootstrap.sh` 多兩個模式：
1. `--upgrade-existing` — 把 woody-harness framework 反向 sync 到既有 target project
2. `--remove` — 從 target 把 framework 乾淨拔掉（保留 user 內容 + memory）

兩個模式都**預設 dry-run**，加 `--apply` 才真寫。

## Execution profile

- model: sonnet
- effort: medium-large
- 4 commits（upgrade / remove / docs / archive）

## Background context（Sonnet 你需要知道的）

woody-harness 是 self-use first 的 workflow harness。`bootstrap.sh <name>` 建新專案並 copy framework files（scripts, slash commands, settings.json, CLAUDE/RESUME templates, memory seed）。

**問題 1（upgrade）**：existing target 早期 bootstrap 過後，woody-harness 升級了（多了 statusline / /sync / notify-blocked / memory.sh），target 拿不到。手動 copy 不可持續。

**問題 2（remove）**：要徹底拔掉 woody-harness 沒有正規方式，user 容易誤刪自己的 CLAUDE.md / 心血 memory。

兩個都在 `bootstrap.sh` 裡實作，不另開 script。

---

## Design A: `--upgrade-existing`（已和 user 拍板）

### CLI

```bash
bash bootstrap.sh --upgrade-existing /path/to/target          # dry-run（預設）
bash bootstrap.sh --upgrade-existing /path/to/target --apply  # 真寫
```

### 4 段檔案分類

| 類別 | 行為 | 檔案清單 |
|---|---|---|
| 🟢 OVERWRITE | 直接覆蓋（dry-run 顯示 diff） | `.claude/commands/inbox.md`, `resume.md`, `sync.md`, `codex-audit.md`, `phase-gate.md`<br>`scripts/archive-prompts.sh`, `memory.sh`, `statusline.sh`, `session-briefing.sh`, `notify-blocked.sh` |
| 🟡 MERGE | jq union | `.claude/settings.json` |
| 🟠 SKIP-if-modified | hash 比對：相同 → no-op；不同 → skip + 印 diff hint | `docs/prompts/README.md` |
| 🔴 NEVER | 永不 touch | `CLAUDE.md`, `RESUME.md`, `.gitignore`, `docs/prompts/_inbox.md`, `~/.claude-work/projects/*/memory/` |

### settings.json merge 邏輯（jq）

Target + framework union：
- `permissions.allow`: 兩邊陣列 union 去重
- `hooks.SessionStart[].hooks[]`: 用 `command` 字串 dedupe，framework 沒 + target 有 → 保留；framework 有 → 確保存在
- `hooks.Notification[].hooks[]`: 同上
- `statusLine`: framework 有設且 target 沒設 → 加；target 已設 → 保留 target
- 其他 user 自定 top-level keys：保留

範例 jq filter：
```bash
jq -s '
  .[0] as $target | .[1] as $fw |
  $target * $fw |
  .permissions.allow = (($target.permissions.allow // []) + ($fw.permissions.allow // []) | unique) |
  .hooks.SessionStart = (($target.hooks.SessionStart // []) + ($fw.hooks.SessionStart // []) | unique_by(.hooks[0].command)) |
  .hooks.Notification = (($target.hooks.Notification // []) + ($fw.hooks.Notification // []) | unique_by(.hooks[0].command)) |
  .statusLine = ($target.statusLine // $fw.statusLine)
' "$TARGET/.claude/settings.json" "$HARNESS_DIR/.claude/settings.json"
```

merge 完做 JSON validate (`python3 -c "import json; json.load(open('...'))"`) 才寫入。

### Pre-flight checks

1. path 必須存在 → 否則 abort
2. target 是 git repo（`.git/` 存在）→ 否則 abort（要求 `git init`）
3. target 是 woody-harness project（`.claude/commands/inbox.md` 存在）→ 否則 abort：「This doesn't look like a woody-harness project. Run `bash bootstrap.sh <name>` first.」
4. target working tree clean → 否則 warn 但繼續

### Dry-run 輸出格式

```
[upgrade] Target: /path/to/target
[upgrade] Framework: /path/to/woody-harness

Would overwrite (N):
  scripts/statusline.sh                  [diff: +12 -3]
  .claude/commands/sync.md               [new file]
  ...

Would merge .claude/settings.json:
  + permissions.allow (+2 entries: "Bash(say:*)", "Bash(bash scripts/notify-blocked.sh:*)")
  + hooks.Notification (new key, 1 entry)
  = hooks.SessionStart (already up-to-date)

Skipped — user-modified (M):
  docs/prompts/README.md   [hash differs from framework]
    → diff: diff /path/to/target/docs/prompts/README.md /path/to/harness/templates/prompts/README.md

Up-to-date (K):
  scripts/memory.sh, .claude/commands/inbox.md, ...

Run with --apply to actually write changes.
```

`--apply`：執行所有 OVERWRITE + MERGE，最後印「Done. N files written. Run `git -C $target diff` to inspect.」

---

## Design B: `--remove`（user 拍板 = 輕度 (a)）

### CLI

```bash
bash bootstrap.sh --remove /path/to/target          # dry-run（預設）
bash bootstrap.sh --remove /path/to/target --apply  # 真刪
```

### 行為（光譜輕度）

| 類別 | 行為 | 檔案 |
|---|---|---|
| 🟢 DELETE | 直接刪 | `.claude/commands/{inbox,resume,sync,codex-audit,phase-gate}.md`<br>`scripts/{archive-prompts,memory,statusline,session-briefing,notify-blocked}.sh`<br>`docs/prompts/_inbox.md`（不論空非空都刪 — user 應在 remove 前處理 queued prompt） |
| 🟡 REVERSE-MERGE | settings.json 拔掉 framework 的 hooks/permissions/statusLine，保留 user 加的；如果結果是 `{}` 或只剩空 `permissions.allow:[]` → 整檔刪 | `.claude/settings.json` |
| 🟠 DELETE-if-pristine | hash 比對 = framework 原版 → 刪；user 改過 → skip + 印 diff hint | `docs/prompts/README.md` |
| 🔴 NEVER | 永不 touch | `CLAUDE.md`, `RESUME.md`, `.gitignore`<br>`~/.claude-work/projects/<slug>/memory/`（user 心血）<br>`docs/prompts/_archive/`（user 歷史歸檔）<br>其他 user 加的檔案 |

### Empty dir cleanup

刪檔後 if 空：`scripts/` → rmdir；`.claude/commands/` → rmdir；`.claude/` 也空 → rmdir。`docs/prompts/` 因為通常還有 `_archive/` → 留著。

### settings.json reverse-merge 邏輯（jq）

把 framework 的東西拔掉：
- `permissions.allow`: 從 target 移除「framework allow 陣列裡有的條目」
- `hooks.SessionStart[].hooks[]`: 移除 command 等於 framework 那條的（`bash scripts/session-briefing.sh ...`）；如果 SessionStart 變空陣列 → 拔掉整個 key
- `hooks.Notification[].hooks[]`: 同上（`bash scripts/notify-blocked.sh`）
- `statusLine`: 如果 target.statusLine == framework.statusLine → 拔掉 key；user 自己改過 → 保留
- 拔完後若 settings.json 是 `{}` 或只剩 `{"permissions":{"allow":[]}}` 之類空殼 → 整檔 rm

範例 jq filter（你可調）：
```bash
jq -s '
  .[0] as $target | .[1] as $fw |
  $target |
  .permissions.allow = (($target.permissions.allow // []) - ($fw.permissions.allow // [])) |
  .hooks.SessionStart = ([($target.hooks.SessionStart // [])[] | .hooks |= map(select(.command != ($fw.hooks.SessionStart[0].hooks[0].command // "__nope__")))] | map(select(.hooks | length > 0))) |
  .hooks.Notification = ([($target.hooks.Notification // [])[] | .hooks |= map(select(.command != ($fw.hooks.Notification[0].hooks[0].command // "__nope__")))] | map(select(.hooks | length > 0))) |
  if .statusLine == $fw.statusLine then del(.statusLine) else . end |
  if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end |
  if (.hooks.Notification | length) == 0 then del(.hooks.Notification) else . end |
  if .hooks == {} then del(.hooks) else . end |
  if (.permissions.allow | length) == 0 then del(.permissions.allow) else . end |
  if .permissions == {} then del(.permissions) else . end
' "$TARGET/.claude/settings.json" "$HARNESS_DIR/.claude/settings.json"
```

驗證：merge 完 JSON validate；如果結果是 `{}` → rm 整檔。

### Pre-flight checks

1. path 必須存在 → abort
2. target 是 woody-harness project（`.claude/commands/inbox.md` 存在）→ 否則 abort：「Not a woody-harness project, nothing to remove.」
3. git repo + clean tree：warn 但繼續（不強制，因為 user 可能想 remove 後直接 commit "remove woody-harness"）

### Dry-run 輸出格式

```
[remove] Target: /path/to/target

Would delete (N files):
  .claude/commands/inbox.md
  .claude/commands/resume.md
  ...
  scripts/statusline.sh
  ...
  docs/prompts/_inbox.md   [size: 1 byte]

Would reverse-merge .claude/settings.json:
  - permissions.allow (-5 entries: "Bash(osascript:*)", "Bash(say:*)", ...)
  - hooks.SessionStart (removed framework entry; user has 1 other → kept)
  - hooks.Notification (removed framework entry; key empty → deleted)
  - statusLine (matches framework → deleted)
  → result: {"permissions": {"allow": [...]}}  (still has user-only entries)

Skipped — user-modified (M):
  docs/prompts/README.md   [hash differs from framework, kept as-is]

Would remove empty dirs:
  scripts/, .claude/commands/

Would NOT touch:
  CLAUDE.md, RESUME.md, .gitignore
  docs/prompts/_archive/  (your prompt history)
  ~/.claude-work/projects/<slug>/memory/  (your memory — preserved)

Memory dir location (run manually if you want it gone):
  rm -rf ~/.claude-work/projects/<slug>/

Run with --apply to actually delete.
```

`--apply`：執行所有 DELETE / REVERSE-MERGE / rmdir，最後印「Done. N files deleted. Memory preserved at ~/.claude-work/projects/<slug>/.」

---

## Commits

### Commit 1: `feat: bootstrap.sh --upgrade-existing mode (dry-run by default)`

修改 `bootstrap.sh`：
- 偵測 `$1 == "--upgrade-existing"` → 進 upgrade flow，跳過原本 new-project flow
- Parse: `bash bootstrap.sh --upgrade-existing /path [--apply]`
- 實作 4 段分類 + jq merge + dry-run 輸出 + pre-flight
- 拆 bash function（`upgrade_dry_run`, `upgrade_apply`, `merge_settings_json`）讓邏輯清楚
- 不要破壞原本 `bash bootstrap.sh <new-name>` 行為

驗證（commit 前自己跑）：
```bash
TMP=$(mktemp -d)
cd "$TMP"
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh test-target

# 砍 sync.md 模擬舊版本
rm -f "$TMP/test-target/.claude/commands/sync.md"

# dry-run，預期 sync.md = "new file"
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh --upgrade-existing "$TMP/test-target"

# apply，預期 sync.md 回來
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh --upgrade-existing "$TMP/test-target" --apply
test -f "$TMP/test-target/.claude/commands/sync.md" && echo "PASS: sync.md restored" || { echo "FAIL"; exit 1; }

# settings.json merge 驗證
python3 -c "import json; d=json.load(open('$TMP/test-target/.claude/settings.json')); assert 'Bash(say:*)' in d['permissions']['allow']; print('PASS: settings.json merge')"

# modified-skip 驗證
echo "USER EDIT" >> "$TMP/test-target/docs/prompts/README.md"
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh --upgrade-existing "$TMP/test-target" | grep -q "user-modified" && echo "PASS: skip-if-modified" || { echo "FAIL"; exit 1; }

rm -rf "$TMP"
```

要全 PASS 才 commit。

### Commit 2: `feat: bootstrap.sh --remove mode (dry-run by default)`

修改 `bootstrap.sh`：
- 偵測 `$1 == "--remove"` → 進 remove flow
- Parse: `bash bootstrap.sh --remove /path [--apply]`
- 實作 DELETE / REVERSE-MERGE / DELETE-if-pristine / rmdir + pre-flight
- 拆 function（`remove_dry_run`, `remove_apply`, `reverse_merge_settings_json`）

驗證（commit 前自己跑）：
```bash
TMP=$(mktemp -d)
cd "$TMP"
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh test-rm

# 加一條 user-only permission，確認 remove 不誤刪
python3 -c "
import json
p='$TMP/test-rm/.claude/settings.json'
d=json.load(open(p))
d['permissions']['allow'].append('Bash(my-custom:*)')
json.dump(d, open(p,'w'), indent=2)
"

# dry-run
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh --remove "$TMP/test-rm"

# apply
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh --remove "$TMP/test-rm" --apply

# 驗證刪了
test ! -f "$TMP/test-rm/.claude/commands/inbox.md" && echo "PASS: inbox.md deleted" || { echo "FAIL"; exit 1; }
test ! -f "$TMP/test-rm/scripts/statusline.sh" && echo "PASS: statusline.sh deleted" || { echo "FAIL"; exit 1; }

# 驗證 user-only permission 保留 OR settings.json 整檔被刪都 OK
if [ -f "$TMP/test-rm/.claude/settings.json" ]; then
    python3 -c "import json; d=json.load(open('$TMP/test-rm/.claude/settings.json')); assert 'Bash(my-custom:*)' in d['permissions']['allow']; print('PASS: user-only permission kept')"
fi

# 驗證 user 內容沒被動
test -f "$TMP/test-rm/CLAUDE.md" && echo "PASS: CLAUDE.md preserved" || { echo "FAIL"; exit 1; }
test -f "$TMP/test-rm/RESUME.md" && echo "PASS: RESUME.md preserved" || { echo "FAIL"; exit 1; }

# 驗證 memory dir 沒被動（拼出 slug）
SLUG=$(echo "$TMP/test-rm" | sed 's|/|-|g')
test -d "$HOME/.claude-work/projects/$SLUG/memory" && echo "PASS: memory preserved" || { echo "FAIL"; exit 1; }

# 驗證 empty dirs 清掉
test ! -d "$TMP/test-rm/scripts" && echo "PASS: empty scripts/ removed" || { echo "FAIL"; exit 1; }

# 清理
rm -rf "$TMP"
rm -rf "$HOME/.claude-work/projects/$SLUG"
```

要全 PASS 才 commit。

### Commit 3: `docs: UPGRADE.md + REMOVE.md + README + CHANGELOG entries`

- 新增 `docs/UPGRADE.md` — 4 段分類表 + 範例 dry-run/apply 輸出 + 何時用
- 新增 `docs/REMOVE.md` — 行為說明 + memory 不刪的提醒 + 範例輸出
- 修改 `README.md`：在 Bootstrap 段後加「Upgrade existing projects → docs/UPGRADE.md」、「Remove woody-harness → docs/REMOVE.md」兩個 link
- 修改 `CHANGELOG.md`：在 `[Unreleased]` 下加 `### Added` 條目；如果沒 `[Unreleased]` section 就建一個

### Commit 4 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/s-1-bootstrap-upgrade-remove.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify files outside這些：`bootstrap.sh`（commit 1+2）、`docs/UPGRADE.md`（新, commit 3）、`docs/REMOVE.md`（新, commit 3）、`README.md`（commit 3）、`CHANGELOG.md`（commit 3）。
2. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP，等 user 拍板。
3. 任何驗證 step 失敗 → STOP + 印錯誤 + 不要 commit broken code。
4. settings.json 任何 merge / reverse-merge 完務必 JSON validate，invalid 就 abort 不寫。
5. 用 bash 內建工具（jq, shasum / sha256sum, python3 for JSON validate, sed, diff）。**不要**裝 npm / pip 套件。
6. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
7. Remove 模式 **絕對不要** 碰 `~/.claude-work/projects/*/memory/`。
8. 通知：commit 1+2+3 都成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "S-1 done" with title "woody-harness"'`；任何 commit 驗證失敗 → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 4 (incl. archive)
<sha> <subject>
<sha> <subject>
<sha> <subject>
<sha> <subject>

**Verification — upgrade**:
- new-project flow 沒壞 (`bash bootstrap.sh test-fresh-$$` 能跑完): PASS / FAIL
- dry-run on degraded target (砍 sync.md) shows "new file": PASS / FAIL
- --apply 真寫: PASS / FAIL
- settings.json merge 保留 user-only permission: PASS / FAIL
- modified file (README edited) skipped + diff hint: PASS / FAIL

**Verification — remove**:
- --apply 真刪 inbox.md / statusline.sh: PASS / FAIL
- user-only permission 保留 OR settings.json 整檔被刪: PASS / FAIL
- CLAUDE.md / RESUME.md 沒被動: PASS / FAIL
- memory dir 沒被動: PASS / FAIL
- empty scripts/ dir 清掉: PASS / FAIL

**Syntax**: `bash -n bootstrap.sh` PASS

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 4 (incl. archive)
5dcba87 feat: bootstrap.sh --upgrade-existing mode (dry-run by default)
893ccf2 feat: bootstrap.sh --remove mode (dry-run by default)
52d635d docs: UPGRADE.md + REMOVE.md + README + CHANGELOG entries
<this commit> chore: archive s-1-bootstrap-upgrade-remove inbox prompt + result

**Verification — upgrade**:
- new-project flow 沒壞 (`bash bootstrap.sh test-target` 能跑完): PASS
- dry-run on degraded target (砍 sync.md) shows "new file": PASS
- --apply 真寫: PASS (sync.md restored)
- settings.json merge 保留 user-only permission: PASS (`Bash(say:*)` present after merge)
- modified file (README edited) skipped + diff hint: PASS (output contains "user-modified")

**Verification — remove**:
- --apply 真刪 inbox.md / statusline.sh: PASS
- user-only permission 保留 OR settings.json 整檔被刪: PASS (`Bash(my-custom:*)` kept after reverse-merge)
- CLAUDE.md / RESUME.md 沒被動: PASS
- memory dir 沒被動: PASS (`~/.claude-work/projects/<slug>/memory` survives)
- empty scripts/ dir 清掉: PASS

**Syntax**: `bash -n bootstrap.sh` PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
