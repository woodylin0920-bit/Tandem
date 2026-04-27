# Bootstrap shared-seed idempotency fix + test artifact cleanup

## Goal

修 bootstrap.sh shared memory seeding 的 idempotency bug，並清掉 T-1a-β promote 測試遺留的 user-level 殘檔（這 bug 害 Phase 0 follow-up test-bootstrap 3 fail）。

## Execution profile

- model: sonnet
- effort: low（單檔 < 10 行邏輯改 + cleanup + verify + archive）
- 1 commit (bootstrap fix) + 1 commit (archive) = 2 commits

## Background

Phase 0 follow-up（archive `2026-04-27-tandem-phase-0-followup.md`）卡在 test-bootstrap 3 fail：缺 `feedback_terse_zh.md` / `feedback_workflow_split.md` / `feedback_model_split.md` 在新 bootstrap 出來的 project memory dir。

Root cause：
- `~/.claude-work/_shared/memory/` 已存在（T-1a-β promote conflict test 17:13 留的殘檔，內含 `MEMORY.md` + `pre_shared.md` placeholder）
- bootstrap.sh L567：`if [ ! -d "$SHARED_MEM" ]; then ... seed ...; fi` — dir 存在就整段 skip，3 個 SHARED_SEEDS 永遠不會補
- 後續 `memory.sh sync` 從空（除了 placeholder）的 shared 同步到 project → 3 個 feedback 檔當然不存在 → test fail

兩層問題：
1. user-level state 污染（test artifact 沒掃）
2. bootstrap 不夠 idempotent（dir 在 ≠ seeds 都在）

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: 清 user-level test 殘檔

```bash
SHARED_MEM="$HOME/.claude-work/_shared/memory"

echo "--- 殘檔 ---"
ls -la "$SHARED_MEM"

# 只清 placeholder/test artifact，保留 dir 結構
rm -f "$SHARED_MEM/pre_shared.md"
rm -f "$SHARED_MEM/MEMORY.md"

# 確認沒誤刪別的（理論上整個 dir 只有這兩個，因為 user 還沒跑 promote 真的搬東西進來）
ls -la "$SHARED_MEM"
echo "--- after cleanup ---"

# 注意：dir 本身不刪 — 留著正好驗 step 3 的 fix（idempotent re-seed）
```

### Step 3: Fix bootstrap.sh L567 — per-file seed check

當前邏輯（bootstrap.sh L567-578）：

```bash
if [ ! -d "$SHARED_MEM" ]; then
    mkdir -p "$SHARED_MEM"
    for f in "${SHARED_SEEDS[@]}"; do
        cp "$HARNESS_DIR/templates/memory/$f" "$SHARED_MEM/"
    done
    cat > "$SHARED_MEM/MEMORY.md" <<'EOF'
- [terse Mandarin updates](feedback_terse_zh.md) — reply in 繁中, 1-2 sentences, mid-task pings = status check not stop
- [planning-here, execute-elsewhere workflow](feedback_workflow_split.md) — this window plans + writes prompts; user runs them via /inbox in separate Sonnet session.
- [model split: Opus plans, Sonnet executes](feedback_model_split.md) — terminal=Opus 4.7 (planning), terminal=Sonnet (executor). Make execution prompts very explicit.
EOF
    echo "[bootstrap] Seeded shared memory at $SHARED_MEM (first time)"
fi
```

改成：

```bash
# Ensure shared dir exists
mkdir -p "$SHARED_MEM"

# Seed each missing file (idempotent — only copies if not already present)
seeded_any=0
for f in "${SHARED_SEEDS[@]}"; do
    if [ ! -f "$SHARED_MEM/$f" ]; then
        cp "$HARNESS_DIR/templates/memory/$f" "$SHARED_MEM/"
        seeded_any=1
    fi
done

# Seed shared MEMORY.md if missing (don't clobber user edits)
if [ ! -f "$SHARED_MEM/MEMORY.md" ]; then
    cat > "$SHARED_MEM/MEMORY.md" <<'EOF'
- [terse Mandarin updates](feedback_terse_zh.md) — reply in 繁中, 1-2 sentences, mid-task pings = status check not stop
- [planning-here, execute-elsewhere workflow](feedback_workflow_split.md) — this window plans + writes prompts; user runs them via /inbox in separate Sonnet session.
- [model split: Opus plans, Sonnet executes](feedback_model_split.md) — terminal=Opus 4.7 (planning), terminal=Sonnet (executor). Make execution prompts very explicit.
EOF
    seeded_any=1
fi

[ "$seeded_any" = "1" ] && echo "[bootstrap] Seeded missing shared memory files at $SHARED_MEM"
```

**注意**：
- 用 Edit tool，old_string 要精準對到 L567-578 那 12 行。
- shared MEMORY.md 已存在時**不覆蓋** — 因為 user 可能已經 promote 過 memory，那個 MEMORY.md 有 user content 不能 clobber（這是新行為，比舊版安全）。

### Step 4: 驗證 fix

```bash
# 4a. bash syntax
bash -n bootstrap.sh && echo "PASS: bootstrap syntax"

# 4b. test-bootstrap 應該全綠
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap 32/32" || { echo "FAIL: test-bootstrap"; exit 1; }

# 4c. shared dir 補回 3 個 seed
SHARED_MEM="$HOME/.claude-work/_shared/memory"
for f in feedback_terse_zh.md feedback_workflow_split.md feedback_model_split.md MEMORY.md; do
    [ -f "$SHARED_MEM/$f" ] && echo "PASS: $f present" || { echo "FAIL: $f missing"; exit 1; }
done

# 4d. fresh bootstrap smoke 在「shared 已存在」狀態下也 work
TMPCHK=$(mktemp -d)
cd "$TMPCHK"
bash ~/Desktop/repo/public/Tandem/bootstrap.sh tandem-idempotent-test
[ -f tandem-idempotent-test/CLAUDE.md ] && echo "PASS: fresh bootstrap CLAUDE.md"
SLUG_TS=$(echo "$TMPCHK/tandem-idempotent-test" | sed 's|/|-|g')
MEMDIR_TS="$HOME/.claude-work/projects/$SLUG_TS/memory"
[ -e "$MEMDIR_TS/feedback_terse_zh.md" ] && echo "PASS: feedback_terse_zh in new project"
[ -e "$MEMDIR_TS/feedback_workflow_split.md" ] && echo "PASS: feedback_workflow_split in new project"
[ -e "$MEMDIR_TS/feedback_model_split.md" ] && echo "PASS: feedback_model_split in new project"

# 清 throwaway
rm -rf "$TMPCHK" "$HOME/.claude-work/projects/$SLUG_TS"
cd ~/Desktop/repo/public/Tandem
```

要全 PASS 才繼續。

### Step 5: Commit fix

```bash
git add bootstrap.sh
git status --short  # 應該只有 bootstrap.sh M
git commit -m "fix: bootstrap.sh shared seeding now per-file idempotent

Old guard 'if [ ! -d \$SHARED_MEM ]' skipped seeding entirely when the
shared dir existed, even if seed files inside were missing. This bit
us after T-1a-β promote conflict tests left a placeholder dir behind
— subsequent bootstraps couldn't re-seed feedback_terse_zh / workflow
_split / model_split, breaking test-bootstrap on fresh projects.

Per-file check: ensure each SHARED_SEED exists, only copy if missing.
Shared MEMORY.md is preserved if already present (don't clobber user
content from real promote runs)."
```

### Step 6: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

## Hard rules

1. shared dir 本身**不刪**（避免影響真有 promoted memory 的場景；step 2 只刪 placeholder 兩個檔）
2. shared MEMORY.md 已存在時**不覆蓋** — fix 的關鍵安全行為，user 真 promote 過的內容不能被新 bootstrap 蓋掉
3. 任何 step FAIL → STOP 印錯誤、不強跑
4. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
5. 不 auto-queue 下一輪

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 2 (incl. archive)
<sha> fix: bootstrap.sh shared seeding now per-file idempotent
<sha> chore: archive bootstrap-shared-seed-idempotency inbox prompt + result

**Cleanup**:
- placeholder MEMORY.md removed: PASS / FAIL
- pre_shared.md removed: PASS / FAIL

**Fix verification**:
- bash -n bootstrap.sh: PASS / FAIL
- test-bootstrap.sh 32/32: PASS / FAIL
- 3 feedback seeds re-seeded into shared: PASS / FAIL
- shared MEMORY.md re-seeded: PASS / FAIL
- fresh bootstrap smoke (with shared pre-existing): PASS / FAIL
- new project memory has all 3 feedback symlinks/files: PASS / FAIL

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 2 (incl. archive)
2e75dc6 fix: bootstrap.sh shared seeding now per-file idempotent
4de8b16 chore: archive bootstrap-shared-seed-idempotency inbox prompt + result

**Cleanup**:
- placeholder MEMORY.md removed: PASS
- pre_shared.md removed: PASS

**Fix verification**:
- bash -n bootstrap.sh: PASS
- test-bootstrap.sh 32/32: PASS
- 3 feedback seeds re-seeded into shared: PASS
- shared MEMORY.md re-seeded: PASS
- fresh bootstrap smoke (with shared pre-existing): PASS
- new project memory has all 3 feedback symlinks/files: PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
