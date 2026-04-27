# T-1a-α: shared memory layer foundation (symlinks, sync, bootstrap)

## Goal

兌現「Claude 跨專案越用越懂你」招牌的**第一階段**：建立 `~/.claude-work/_shared/memory/` shared 層 + sync 工具 + bootstrap 改 seed 邏輯。**這輪不動 user 既有 memory dir**（包含 woody-harness 自己的 memory）— 純加 infra，user 自己決定何時跑 sync。

T-1a-β（搬移工具 promote + dogfood 自己的 memory）下輪再做。

## Execution profile

- model: sonnet
- effort: medium-large（多檔、單元 + 整合驗證、新概念）
- 4 commits（memory.sh sync / bootstrap.sh / docs / archive）

## Background context

- 現況：每個 project 的 memory 完全獨立，user 偏好（terse 繁中、planner-direct hot-path 等）綁在 project，跨專案不繼承
- 願景：shared layer 存使用者偏好/規則/錯誤經驗，project 只放專案特定 state
- User 已拍板（Q1-Q6 + 實作 Q-α/β）：
  - Shared 在 `~/.claude-work/_shared/memory/`
  - **Symlinks** 機制（project memory dir 放 symlink 指向 shared 真檔）
  - Project 真檔同名 → 視為 override，sync 印 warn
  - 衝突時 project 贏，shared 不變
  - 拆兩輪：α 基礎建設（這輪）+ β 搬移工具（下輪）

---

## Commit 1: `feat: scripts/memory.sh sync — symlink shared layer + regenerate combined MEMORY.md`

修改 `scripts/memory.sh`，加 `sync` subcommand。

### A. sync 行為

```bash
bash scripts/memory.sh sync
```

從當前 git repo root 跑（用 `memory_dir_for_repo` 既有 helper 取 project memory dir）。

**步驟**：

1. **Pre-flight**：
   - `proj_mem` 存在（不存在 → error: "no project memory dir for $(pwd) — run bootstrap.sh first"）
   - `shared_mem=$HOME/.claude-work/_shared/memory` 存在（不存在 → error: "no shared layer at $shared_mem — run bootstrap.sh on a new project to seed it, or manually mkdir + populate"）

2. **掃 shared，建 symlinks**：
   - 對 `$shared_mem/*.md`（不含 `MEMORY.md`）：
     - `name=$(basename $f)`
     - `target="$proj_mem/$name"`
     - 4 種情境：
       - target 不存在 → `ln -s ../../../_shared/memory/$name $target` → 加進 `linked` 陣列
       - target 是 symlink 且指向對的 shared 路徑 → 跳過 → 加進 `already_linked` 陣列
       - target 是 symlink 但指向別處（壞的 symlink）→ `rm $target && ln -s ../../../_shared/memory/$name $target` → 加進 `relinked` 陣列
       - target 是 real file（不是 symlink）→ skip + warn → 加進 `overridden` 陣列

3. **重生 `$proj_mem/MEMORY.md` 為合併索引**：

   讀現有 `MEMORY.md`（如果有）— 用 marker 切兩段：
   - `<!-- BEGIN shared -->` ... `<!-- END shared -->`：自動生成段，內容 = shared MEMORY.md 的所有 entries
   - `<!-- BEGIN project-local -->` ... `<!-- END project-local -->`：保留段，原樣留下原 project 寫的 entries

   **首次跑**（既有 MEMORY.md 沒 marker）：
   - 整個現有 MEMORY.md 內容當作 project-local section（user 之前手寫的 project-specific entries）
   - 上面加 shared section（從 shared MEMORY.md 拷過來）
   - 結構：
     ```markdown
     <!-- BEGIN shared (auto-managed by scripts/memory.sh sync — do not edit between markers) -->
     <copy entries from shared MEMORY.md verbatim>
     <!-- END shared -->

     <!-- BEGIN project-local (you can edit this section freely) -->
     <existing MEMORY.md content (whole file, before any modifications)>
     <!-- END project-local -->
     ```

   **後續跑**（已有 marker）：
   - shared section 整段重生（從當前 shared MEMORY.md）
   - project-local section 一字不改 preserve

   **override entries**：如果某個 memory 在 project 是 real file（override shared），把 entry 加在 project-local section 結尾，加 `[OVERRIDE]` 標記：
   ```
   - [feedback_terse_zh (project override)](feedback_terse_zh.md) [OVERRIDE] — local version of shared/feedback_terse_zh.md
   ```
   （只有 sync 偵測到 override 時才加；如 project-local section 已有此 entry 不重複加。）

4. **Print summary**：
   ```
   [sync] Project: /path/to/project
   [sync] Shared: /Users/woody/.claude-work/_shared/memory (N files)

   Linked (M): list (or "(none)" if empty)
     feedback_terse_zh.md
     feedback_workflow_split.md
     ...
   Already linked (K): silent count "(K already in sync)"
   Relinked (R): list (or "(none)")
   Overridden by project (O): list (or "(none)")
     feedback_terse_zh.md   [project file kept; shared entry shadowed]

   MEMORY.md regenerated: shared section (N entries) + project-local section preserved.

   Done.
   ```

### B. 為什麼 symlink 用 `../../../_shared/memory/<name>`

`proj_mem` = `$HOME/.claude-work/projects/<slug>/memory/`
要到 `$HOME/.claude-work/_shared/memory/<name>`：
- `..` → `<slug>/`
- `../..` → `projects/`
- `../../..` → `.claude-work/`
- `../../../_shared/memory/<name>` ✓

→ 用 relative symlink 比較 portable（user 將 `~/.claude-work` 整個移走也不壞）。

### C. Verification

```bash
HARNESS=$(pwd)
TMP=$(mktemp -d -t wh-t1a-XXXXXX)

# 1. shared 不存在 → sync 該 fail with informative msg
mkdir -p "$TMP/proj1/.git"
cd "$TMP/proj1"
mkdir -p "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')/memory"
out=$(bash "$HARNESS/scripts/memory.sh" sync 2>&1) && fail=0 || fail=1
[ "$fail" = "1" ] && echo "$out" | grep -q "no shared layer" && echo "PASS: sync rejects missing shared" || { echo "FAIL: $out"; exit 1; }

# 2. 建 shared 後，sync 該成功
mkdir -p "$HOME/.claude-work/_shared/memory"
cp "$HARNESS/templates/memory/feedback_terse_zh.md" "$HOME/.claude-work/_shared/memory/"
cp "$HARNESS/templates/memory/feedback_workflow_split.md" "$HOME/.claude-work/_shared/memory/"
cat > "$HOME/.claude-work/_shared/memory/MEMORY.md" <<'EOF'
- [terse Mandarin updates](feedback_terse_zh.md) — reply in 繁中
- [planning-here, execute-elsewhere](feedback_workflow_split.md) — Opus plans...
EOF

bash "$HARNESS/scripts/memory.sh" sync 2>&1 | tee /tmp/wh-t1a-sync.txt
grep -q "Linked" /tmp/wh-t1a-sync.txt && echo "PASS: sync runs"
test -L "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')/memory/feedback_terse_zh.md" && echo "PASS: symlink created" || { echo "FAIL"; exit 1; }
readlink "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')/memory/feedback_terse_zh.md" | grep -q "_shared/memory/feedback_terse_zh.md" && echo "PASS: symlink points to shared" || { echo "FAIL"; exit 1; }

# 3. MEMORY.md 有 markers
grep -q "BEGIN shared" "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')/memory/MEMORY.md" && echo "PASS: BEGIN shared marker"
grep -q "END project-local" "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')/memory/MEMORY.md" && echo "PASS: END project-local marker"

# 4. 重複跑 sync（idempotency）
bash "$HARNESS/scripts/memory.sh" sync 2>&1 | tee /tmp/wh-t1a-sync2.txt
grep -q "already in sync" /tmp/wh-t1a-sync2.txt && echo "PASS: idempotent" || { echo "FAIL"; exit 1; }

# 5. 衝突：建 real file 覆蓋 shared
echo "# my override" > "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')/memory/feedback_terse_zh.md"
# 但這會把 symlink 蓋掉... 重 sync 看 warn
bash "$HARNESS/scripts/memory.sh" sync 2>&1 | tee /tmp/wh-t1a-sync3.txt
# Hmm wait — overwriting symlink with `>` will follow it and overwrite the SHARED file. Use `rm` first then write
# Re-do correctly:
# (清掉測試)

# 清理
cd "$HARNESS"
rm -rf "$TMP" "$HOME/.claude-work/projects/$(echo "$TMP/proj1" | sed 's|/|-|g')"
rm -rf "$HOME/.claude-work/_shared/memory"  # 全乾淨，待 commit 2 重新 seed
rm -f /tmp/wh-t1a-sync*.txt
```

> **重要**：上面 verification step 5 跳過 conflict 測試，因為 mock 衝突需要先 `rm` symlink 再 write，否則會破壞 shared 真檔。Sonnet 你**重寫 step 5**正確的測試方式：先 `rm "$proj_mem/feedback_terse_zh.md"`（移除 symlink）再 `echo "override" > "$proj_mem/feedback_terse_zh.md"`（寫真檔），然後跑 sync 看是否印 "Overridden by project (1)" + symlink 沒被蓋回去（real file 仍在）。
>
> 跑完務必清乾淨（包括 `~/.claude-work/_shared/memory`，因為 commit 2 還會重 seed 一次）。

要全 PASS 才 commit 1。

---

## Commit 2: `feat: bootstrap.sh seeds _shared/ on first run + new project memory only has project-specific + auto-sync`

修改 `bootstrap.sh`。

### A. 新邏輯

現在 bootstrap 會：
```bash
mkdir -p "$MEM_DIR"
cp "$HARNESS_DIR/templates/memory/MEMORY.md" "$MEM_DIR/MEMORY.md"
cp "$HARNESS_DIR/templates/memory/feedback_terse_zh.md" "$MEM_DIR/"
cp "$HARNESS_DIR/templates/memory/feedback_workflow_split.md" "$MEM_DIR/"
cp "$HARNESS_DIR/templates/memory/feedback_model_split.md" "$MEM_DIR/"
cp "$HARNESS_DIR/templates/memory/env_paths.md" "$MEM_DIR/"
sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$MEM_DIR"/env_paths.md 2>/dev/null || true
```

改成：

```bash
SHARED_MEM="$HOME/.claude-work/_shared/memory"

# 分類 seed 檔
SHARED_SEEDS=(feedback_terse_zh.md feedback_workflow_split.md feedback_model_split.md)
PROJECT_SEEDS=(env_paths.md)  # 含 {{PROJECT_NAME}} 替換的就放這

# 1. 第一次 bootstrap：seed _shared/（如已存在不動）
if [ ! -d "$SHARED_MEM" ]; then
    mkdir -p "$SHARED_MEM"
    for f in "${SHARED_SEEDS[@]}"; do
        cp "$HARNESS_DIR/templates/memory/$f" "$SHARED_MEM/"
    done
    # 建 shared MEMORY.md（從 templates/memory/MEMORY.md 抽 shared seed 對應的 entries）
    # 簡化做法：直接生成新的 shared MEMORY.md，不從 templates/memory/MEMORY.md 抽
    cat > "$SHARED_MEM/MEMORY.md" <<'EOF'
- [terse Mandarin updates](feedback_terse_zh.md) — reply in 繁中, 1-2 sentences, mid-task pings = status check not stop
- [planning-here, execute-elsewhere workflow](feedback_workflow_split.md) — this window plans + writes prompts; user runs them via /inbox in separate Sonnet session.
- [model split: Opus plans, Sonnet executes](feedback_model_split.md) — terminal=Opus 4.7 (planning), terminal=Sonnet (executor). Make execution prompts very explicit.
EOF
    echo "[bootstrap] Seeded shared memory at $SHARED_MEM (first time)"
fi

# 2. Project memory dir：只放 project seeds
mkdir -p "$MEM_DIR"
for f in "${PROJECT_SEEDS[@]}"; do
    cp "$HARNESS_DIR/templates/memory/$f" "$MEM_DIR/"
done
sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$MEM_DIR"/env_paths.md 2>/dev/null || true

# 3. 建初始 project MEMORY.md with markers + project-local seed entry
cat > "$MEM_DIR/MEMORY.md" <<'EOF'
<!-- BEGIN shared (auto-managed by scripts/memory.sh sync — do not edit between markers) -->
<!-- END shared -->

<!-- BEGIN project-local (you can edit this section freely) -->
- [environment paths](env_paths.md) — bash + markdown only (no venv); macOS BSD sed quirks
<!-- END project-local -->
EOF

# 4. 跑 sync 把 shared 拉進來
cd "$PROJECT_DIR"
bash scripts/memory.sh sync >/dev/null 2>&1 || echo "[bootstrap] WARN: memory sync failed (run 'bash scripts/memory.sh sync' manually)"
cd - > /dev/null
```

> 注意：原本 bootstrap 在 `cd "$PROJECT_DIR"` 之後才設 `MEM_DIR`，整段流程重排時保持 `MEM_DIR` 變數已定義。具體 line 數字看當前 bootstrap.sh 結構決定。

### B. 不動 `--upgrade-existing` 跟 `--remove`

T-1a-α 範圍**只包含新 bootstrap flow + sync 工具**。Upgrade / remove 模式不動，因為：
- 既有專案的 memory 是 user 心血，不該 upgrade 自動改 layout
- T-1a-β 會專門做遷移（promote helper）

### C. Verification

```bash
HARNESS=$(pwd)
TMP=$(mktemp -d -t wh-t1a-bootstrap-XXXXXX)
cd "$TMP"

# 確保 _shared/ 是乾淨的（避免之前 commit 1 殘留干擾）
rm -rf "$HOME/.claude-work/_shared/memory"

# 1. 第一次 bootstrap
bash "$HARNESS/bootstrap.sh" proj-A
test -d "$HOME/.claude-work/_shared/memory" && echo "PASS: _shared/ created" || { echo "FAIL"; exit 1; }
test -f "$HOME/.claude-work/_shared/memory/feedback_terse_zh.md" && echo "PASS: shared has feedback_terse_zh"
test -f "$HOME/.claude-work/_shared/memory/MEMORY.md" && echo "PASS: shared has MEMORY.md"

# 2. Project memory 結構
SLUG_A=$(echo "$TMP/proj-A" | sed 's|/|-|g')
PMEM_A="$HOME/.claude-work/projects/$SLUG_A/memory"
test -L "$PMEM_A/feedback_terse_zh.md" && echo "PASS: feedback_terse_zh is symlink"
test -f "$PMEM_A/env_paths.md" && ! test -L "$PMEM_A/env_paths.md" && echo "PASS: env_paths is real file"
grep -q "BEGIN shared" "$PMEM_A/MEMORY.md" && echo "PASS: project MEMORY.md has markers"
grep -q "{{PROJECT_NAME}}" "$PMEM_A/env_paths.md" && { echo "FAIL: env_paths still has placeholder"; exit 1; } || echo "PASS: env_paths substituted"
grep -q "proj-A" "$PMEM_A/env_paths.md" && echo "PASS: env_paths mentions proj-A" || { echo "FAIL"; exit 1; }

# 3. 第二次 bootstrap（_shared/ 已存在不動）
SHARED_TS_BEFORE=$(stat -f "%m" "$HOME/.claude-work/_shared/memory/feedback_terse_zh.md")
sleep 1
bash "$HARNESS/bootstrap.sh" proj-B
SHARED_TS_AFTER=$(stat -f "%m" "$HOME/.claude-work/_shared/memory/feedback_terse_zh.md")
[ "$SHARED_TS_BEFORE" = "$SHARED_TS_AFTER" ] && echo "PASS: _shared/ not re-seeded on 2nd bootstrap"

# 4. 兩個 project 的 symlink 都指向同一份 shared
SLUG_B=$(echo "$TMP/proj-B" | sed 's|/|-|g')
PMEM_B="$HOME/.claude-work/projects/$SLUG_B/memory"
ls -l "$PMEM_A/feedback_terse_zh.md" | grep -q "_shared/memory/feedback_terse_zh.md"
ls -l "$PMEM_B/feedback_terse_zh.md" | grep -q "_shared/memory/feedback_terse_zh.md"
echo "PASS: both projects symlink to same shared file"

# 5. test-bootstrap.sh 沒壞（既有 32 checks 全綠）
bash "$HARNESS/scripts/test-bootstrap.sh" && echo "PASS: test-bootstrap 32/32" || { echo "FAIL"; exit 1; }

# 6. bash -n
bash -n "$HARNESS/bootstrap.sh" && echo "PASS: bash -n bootstrap"

# 清理
cd "$HARNESS"
rm -rf "$TMP" "$HOME/.claude-work/projects/$SLUG_A" "$HOME/.claude-work/projects/$SLUG_B"
rm -rf "$HOME/.claude-work/_shared/memory"
```

要全 PASS 才 commit 2。

---

## Commit 3: `docs: SHARED_MEMORY.md + README + REFERENCE.md updates`

### A. 新增 `docs/SHARED_MEMORY.md`

內容（直接照抄）：

```markdown
# Shared memory layer

woody-harness's shared memory layer means **Claude gets smarter as you work across projects**. Preferences, workflow rules, and lessons-learned that apply to *you* (not a specific repo) live once at `~/.claude-work/_shared/memory/` and are symlinked into every project.

## Layout

```
~/.claude-work/
├── _shared/memory/                    # user-level (your preferences, rules)
│   ├── MEMORY.md                      # shared index
│   ├── feedback_terse_zh.md           # real file
│   ├── feedback_workflow_split.md     # real file
│   └── ...
└── projects/<slug>/memory/            # project-local (state, history, decisions specific to one repo)
    ├── MEMORY.md                      # combined index (auto-maintained)
    ├── feedback_terse_zh.md           # symlink → ../../../_shared/memory/feedback_terse_zh.md
    ├── feedback_workflow_split.md     # symlink
    ├── env_paths.md                   # real file (project-specific content)
    ├── project_current_handoff.md     # real file
    └── project_*.md                   # other project-only memories
```

## Load order

Claude Code's auto-memory loads `~/.claude-work/projects/<slug>/memory/MEMORY.md`, which contains:

1. **`<!-- BEGIN shared --> ... <!-- END shared -->`** — entries from `~/.claude-work/_shared/memory/MEMORY.md`, auto-injected by `scripts/memory.sh sync`. Do not edit between markers (will be overwritten on next sync).
2. **`<!-- BEGIN project-local --> ... <!-- END project-local -->`** — your project-specific entries. Edit freely. Untouched by sync.

When a same-named file exists in both shared and project, **project wins** — sync detects the conflict, leaves the project file alone, and prints:
```
Overridden by project (1):
  feedback_terse_zh.md   [project file kept; shared entry shadowed]
```

This lets you tweak a shared rule for one specific project without breaking it elsewhere.

## Workflow

### First-time setup

The first `bash bootstrap.sh <name>` run seeds `~/.claude-work/_shared/memory/` from `templates/memory/`. Subsequent bootstraps reuse the existing shared layer.

### Adding a new shared memory

1. Write the new memory file directly into `~/.claude-work/_shared/memory/foo.md`
2. Add an entry to `~/.claude-work/_shared/memory/MEMORY.md`
3. In each project where you want it active, run `bash scripts/memory.sh sync` — symlink + project MEMORY.md regen

### Adding a new project-local memory

Just create the file in `~/.claude-work/projects/<slug>/memory/foo.md` and add to the project-local section of `MEMORY.md`. No sync needed — sync only manages the shared section.

### Overriding a shared memory for one project

```bash
cd ~/path/to/some-project
rm "$HOME/.claude-work/projects/$(pwd | sed 's|/|-|g')/memory/feedback_terse_zh.md"   # remove symlink
echo "<override content>" > "$HOME/.claude-work/projects/$(pwd | sed 's|/|-|g')/memory/feedback_terse_zh.md"
bash scripts/memory.sh sync   # marks override + warns
```

### Migrating existing project memory to shared

(Coming in T-1a-β round) — `bash scripts/memory.sh promote` will walk through your project memory interactively and let you decide per file: promote to shared / keep local / delete.

## Safety

- `sync` never modifies real files in your project memory dir
- `sync` never deletes anything
- `sync` is idempotent — running twice is safe
- Conflicts (real local file with shared name) are reported, not auto-resolved
```

### B. README.md 改 2 處

**B1. "What you get" 列表加一條（在「Memory portability」之前）**：

```markdown
- **Cross-project shared memory** — your preferences, workflow rules, and lessons-learned live once at `~/.claude-work/_shared/memory/` and symlink into every project. Add a memory once, get it everywhere. See [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md).
```

**B2. Roadmap 段把 T-1a 從 [ ] 改成 [~]（in-progress：α shipped, β pending）**：

```markdown
- [~] **T-1a** — cross-project shared memory layer (α shipped: foundation; β pending: migration tooling)
```

### C. CHANGELOG.md `[Unreleased]` 加 entry

```markdown
### Added
- Shared memory layer at `~/.claude-work/_shared/memory/` — user-level preferences/rules/lessons that apply across all projects (T-1a-α foundation). New `bash scripts/memory.sh sync` subcommand symlinks shared into project memory dir + regenerates `MEMORY.md` as a combined index. `bootstrap.sh` seeds shared on first run; new project memory only contains project-specific files. See [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md). Migration tooling for existing projects coming in T-1a-β.
```

### D. docs/REFERENCE.md `Scripts` 段 `memory.sh` 行加 `sync` 子命令

找到表格中 memory.sh 那段，加一行：
```
| | `bash scripts/memory.sh sync` | Symlink shared layer into current project + regenerate combined MEMORY.md |
```

### E. Verification

```bash
test -f docs/SHARED_MEMORY.md && echo "PASS: SHARED_MEMORY.md exists" || { echo "FAIL"; exit 1; }
grep -q "Cross-project shared memory" README.md && echo "PASS: README mentions shared memory" || { echo "FAIL"; exit 1; }
grep -q "T-1a.*\[~\]\|\[~\].*T-1a" README.md && echo "PASS: T-1a marked in-progress" || { echo "FAIL"; exit 1; }
grep -q "Shared memory layer" CHANGELOG.md && echo "PASS: CHANGELOG entry"
grep -q "memory.sh sync" docs/REFERENCE.md && echo "PASS: REFERENCE updated"
```

---

## Commit 4 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-t1a-alpha-shared-memory-foundation.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify woody-harness's own memory dir（`~/.claude-work/projects/-Users-woody-Desktop-repo-public-woody-harness/memory/`）— 這輪純加 infra，user 自己決定何時跑 sync。
2. **DO NOT** modify files outside這些：`scripts/memory.sh`（commit 1）、`bootstrap.sh`（commit 2）、`docs/SHARED_MEMORY.md`（新, commit 3）、`README.md`（commit 3）、`docs/REFERENCE.md`（commit 3）、`CHANGELOG.md`（commit 3）。
3. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
4. 任何 verification step FAIL → STOP + 印錯誤 + 不 commit broken state。
5. `--upgrade-existing` 跟 `--remove` 模式 **完全不動**（這輪不擴它們的 framework file inventory，也不加 shared 相關邏輯）。
6. `git mv` / `git add` 妥善處理。
7. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
8. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "T-1a-α shipped" with title "woody-harness"'`；失敗 → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。
9. 跑驗證時用的 `~/.claude-work/_shared/memory/` 要在最後**清乾淨**（不要污染 user 真實 environment；user 自己決定何時 seed shared）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 4 (incl. archive)
<sha> feat: scripts/memory.sh sync — symlink shared layer + regenerate combined MEMORY.md
<sha> feat: bootstrap.sh seeds _shared/ on first run + new project memory only has project-specific + auto-sync
<sha> docs: SHARED_MEMORY.md + README + REFERENCE.md + CHANGELOG updates
<sha> chore: archive t1a-alpha-shared-memory-foundation inbox prompt + result

**Verification — sync**:
- sync rejects missing shared with informative msg: PASS / FAIL
- sync creates symlinks pointing to ../../../_shared/memory/<name>: PASS / FAIL
- MEMORY.md has BEGIN/END markers: PASS / FAIL
- sync is idempotent (2nd run shows "already in sync"): PASS / FAIL
- override conflict (real local file + same-name shared): warn + don't overwrite local: PASS / FAIL

**Verification — bootstrap**:
- 1st bootstrap creates _shared/: PASS / FAIL
- 2nd bootstrap doesn't re-seed _shared/: PASS / FAIL
- new project has feedback_*.md as symlinks, env_paths.md as real file: PASS / FAIL
- two projects symlink to same shared file: PASS / FAIL
- env_paths {{PROJECT_NAME}} substituted: PASS / FAIL
- test-bootstrap.sh 32/32: PASS / FAIL
- bash -n bootstrap.sh: PASS / FAIL

**Verification — docs**:
- SHARED_MEMORY.md exists: PASS / FAIL
- README mentions cross-project shared memory: PASS / FAIL
- T-1a marked [~] in roadmap: PASS / FAIL
- CHANGELOG [Unreleased] entry: PASS / FAIL
- REFERENCE.md mentions sync subcommand: PASS / FAIL

**woody-harness own memory dir untouched**: PASS / FAIL (verify by ls timestamps + diff before/after)

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 4 (incl. archive)
510c75c feat: scripts/memory.sh sync — symlink shared layer + regenerate combined MEMORY.md
55cfae5 feat: bootstrap.sh seeds _shared/ on first run + new project memory only has project-specific + auto-sync
91c0576 docs: SHARED_MEMORY.md + README + REFERENCE.md + CHANGELOG updates
<archive-sha> chore: archive t1a-alpha-shared-memory-foundation inbox prompt + result

**Verification — sync**:
- sync rejects missing shared with informative msg: PASS
- sync creates symlinks pointing to ../../../_shared/memory/<name>: PASS
- MEMORY.md has BEGIN/END markers: PASS
- sync is idempotent (2nd run shows "already in sync"): PASS
- override conflict (real local file + same-name shared): warn + don't overwrite local: PASS

**Verification — bootstrap**:
- 1st bootstrap creates _shared/: PASS
- 2nd bootstrap doesn't re-seed _shared/: PASS
- new project has feedback_*.md as symlinks, env_paths.md as real file: PASS
- two projects symlink to same shared file: PASS
- env_paths {{PROJECT_NAME}} substituted: PASS
- test-bootstrap.sh 32/32: PASS
- bash -n bootstrap.sh: PASS

**Verification — docs**:
- SHARED_MEMORY.md exists: PASS
- README mentions cross-project shared memory: PASS
- T-1a marked [~] in roadmap: PASS
- CHANGELOG [Unreleased] entry: PASS
- REFERENCE.md mentions sync subcommand: PASS

**woody-harness own memory dir untouched**: PASS (all files had pre-session timestamps, no new files created)

**Push**: ✅ pushed to origin/main
**Blockers**: none
