# Phase C: lessons loop — auto-extract on archive + extract/review workflow

## Goal

兌現「跨專案 self-improving AI 副手」招牌願景：archive flow 偵測 ❌/Blocker/FAIL/keyword 訊號 → 自動 append raw signal 到 `~/.claude-work/_shared/lessons-staging.md` → user 跑 `scripts/lessons.sh extract` 用 headless claude 把 raw 提煉成 candidate lesson → 跑 `scripts/lessons.sh review` 一條條 promote 到 shared memory（仿 `memory.sh promote` UX）。

statusline + briefing 顯示 pending lesson 數量讓 user 知道有東西可 review。

## Execution profile

- model: sonnet
- effort: medium（5 個 surface 同時動，但每處 mechanical edit；lessons.sh 是新檔但邏輯線性）
- 5 commits + archive = 6

## Phase C 拍板（9 條，全部已定調）

| # | 軸 | 拍板 |
|---|---|---|
| 1 | 觸發哲學 | **B** — passive auto-extract on archive |
| 2 | 觸發點 | **C** — archive only + verification FAIL detection |
| 3 | detection 規則 | **B** — Status ❌ / Blockers ≠ none / FAIL line / "next time"/"should"/"lesson" keyword |
| 4 | staging 位置 | **C** — `~/.claude-work/_shared/lessons-staging.md` |
| 5 | review UX | **B** — `scripts/lessons.sh review` |
| 6 | extraction 架構 | **C** — 兩段式 `lessons.sh extract` (headless claude refines raw → candidate) → `review` |
| 7 | promote 預設層 | **A** — default = shared (Enter = shared) |
| 8 | discovery | **A+B** — statusline pending count + briefing 帶狀態 |
| 9 | scope | **A** — 1 輪打包 |

## Background context

- 現役 wedge 三條：plan/execute split + cross-vendor gates + cross-project memory layer
- 撞 gstack 的 `/retro`，本 feature 用 `lessons.sh` 不開 `/lessons` slash command（避免命名衝突 + slash command 範圍應留給 user-invoked operations）
- `~/.claude-work/_shared/memory/` shared layer 已上線，新 lesson promote 直接進去（順著現有架構，不需 promote helper）
- 21 個 archived rounds 已存在，`archive-prompts.sh` 是穩定整合點

## Files to create / edit

新檔：
- `scripts/lessons.sh`（subcommands：count / extract / review / list）
- `docs/LESSONS.md`（feature doc）

改檔：
- `scripts/archive-prompts.sh`（加 detect_lessons + append_raw_to_staging）
- `scripts/statusline.sh`（加 lessons pending segment）
- `scripts/session-briefing.sh`（加 lessons staging mention）
- `bootstrap.sh`（copy lessons.sh）
- `docs/REFERENCE.md`（加 lessons.sh + LESSONS.md 列）
- `docs/MEMORY_SYSTEM.md`（cross-link lessons workflow）
- `scripts/test-bootstrap.sh`（assert lessons.sh + dry-run）

## Staging file format spec（**必讀**）

`~/.claude-work/_shared/lessons-staging.md` 是 append-only state machine，每個 entry 都用 HTML comment marker 包：

```markdown
<!-- BEGIN entry id=<archive-basename> state=raw timestamp=<ISO 8601> -->
- archive: docs/prompts/_archive/2026-04/2026-04-27-foo.md
- status: ❌ blocked
- signals:
  - "**Blockers**: dirty working tree blocked step 3"
  - "FAIL: test-bootstrap line 23"
  - "next time: pre-flight should abort, not warn"
- excerpt: |
    <Result block 內容直接複製>
<!-- END entry -->
```

**state machine**：
- `state=raw` — archive-prompts.sh detect 完直接 append，內容是原始訊號 + Result block excerpt
- `state=candidate` — `lessons.sh extract` 把 raw 餵給 headless claude refine 後改寫成 candidate entry：
  ```markdown
  <!-- BEGIN entry id=<archive-basename> state=candidate timestamp=<ISO 8601> -->
  ---
  name: <AI 提的 lesson name>
  description: <AI 提的 lesson description>
  type: feedback
  source-archive: docs/prompts/_archive/2026-04/2026-04-27-foo.md
  ---
  
  <lesson body — 含 Why: / How to apply: 兩段，符合 feedback memory 慣例>
  <!-- END entry -->
  ```
- `state=promoted` — `lessons.sh review` 跑 promote 後，entry 從 staging 移除（不留 promoted state，乾淨）；`lesson body + frontmatter` 寫入 `~/.claude-work/_shared/memory/<slug>.md` + 在 shared/MEMORY.md append 索引
- `state=deleted` — review 跑 delete 直接從 staging 移除

`id=<archive-basename>` 用作 dedup key — archive-prompts.sh 偵測前先檢查 staging 是否已含同 id entry，已存在則 skip（防止 archive 重跑產生重複）。

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }
[ ! -f scripts/lessons.sh ] || { echo "FAIL: scripts/lessons.sh already exists — abort"; exit 1; }
[ ! -f docs/LESSONS.md ] || { echo "FAIL: docs/LESSONS.md already exists — abort"; exit 1; }
[ -d "$HOME/.claude-work/_shared" ] || { echo "FAIL: shared layer dir missing — run bootstrap.sh on a project first to seed"; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: 創建 scripts/lessons.sh（新檔）

用 Write tool 建 `scripts/lessons.sh`，含 5 個 subcommand：`help` / `count` / `list` / `extract` / `review`。完整內容：

```bash
#!/usr/bin/env bash
# lessons.sh — auto-extracted lesson candidates from archive flow.
# State machine: raw (appended by archive-prompts.sh) → candidate (refined by `extract`) → promoted/deleted (by `review`).
# Usage:
#   bash scripts/lessons.sh count             # how many entries pending (any state)
#   bash scripts/lessons.sh list              # list all entries with state
#   bash scripts/lessons.sh extract           # raw → candidate via headless claude
#   bash scripts/lessons.sh review            # candidate → promoted (shared memory) / deleted (interactive)
set -euo pipefail

STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
SHARED_MEM="$HOME/.claude-work/_shared/memory"

cmd="${1:-help}"

ensure_staging() {
    mkdir -p "$(dirname "$STAGING")"
    [ -f "$STAGING" ] || : > "$STAGING"
}

count_entries() {
    local state="${1:-}"
    [ -f "$STAGING" ] || { echo 0; return; }
    if [ -z "$state" ]; then
        grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null || echo 0
    else
        grep -c "^<!-- BEGIN entry .*state=$state" "$STAGING" 2>/dev/null || echo 0
    fi
}

list_entries() {
    [ -f "$STAGING" ] || { echo "(no staging file yet)"; return; }
    awk '/^<!-- BEGIN entry/ {
        match($0, /id=([^ ]+)/, id)
        match($0, /state=([^ ]+)/, st)
        printf "  %s  state=%s\n", id[1], st[1]
    }' "$STAGING"
}

# Read full entry block by id
read_entry() {
    local id="$1"
    awk -v id="$id" '
        $0 ~ "^<!-- BEGIN entry id="id" " {grab=1}
        grab {print}
        $0 == "<!-- END entry -->" && grab {grab=0; exit}
    ' "$STAGING"
}

# Remove entry block by id
remove_entry() {
    local id="$1"
    local tmp
    tmp=$(mktemp)
    awk -v id="$id" '
        $0 ~ "^<!-- BEGIN entry id="id" " {skip=1; next}
        skip && $0 == "<!-- END entry -->" {skip=0; next}
        !skip {print}
    ' "$STAGING" > "$tmp"
    mv "$tmp" "$STAGING"
}

# List ids by state
ids_with_state() {
    local state="$1"
    [ -f "$STAGING" ] || return
    awk -v st="$state" '
        $0 ~ "^<!-- BEGIN entry " && $0 ~ "state="st {
            match($0, /id=([^ ]+)/, id)
            print id[1]
        }
    ' "$STAGING"
}

# Replace entry by id with new content (multi-line). new_content already includes BEGIN/END markers.
replace_entry() {
    local id="$1"
    local new_content="$2"
    local tmp
    tmp=$(mktemp)
    awk -v id="$id" -v new="$new_content" '
        $0 ~ "^<!-- BEGIN entry id="id" " {print new; skip=1; next}
        skip && $0 == "<!-- END entry -->" {skip=0; next}
        !skip {print}
    ' "$STAGING" > "$tmp"
    mv "$tmp" "$STAGING"
}

# Read a single key without echo (for prompts)
read_key() {
    local ans rc
    while true; do
        IFS= read -r -n 1 ans
        rc=$?
        if [ $rc -ne 0 ] && [ -z "$ans" ]; then
            printf 'q'; return
        fi
        case "$ans" in
            $'\n'|$'\r'|'') continue ;;
            *) printf '%s' "$ans"; return ;;
        esac
    done
}

case "$cmd" in
    help|--help|-h)
        cat <<'HELP'
lessons.sh — auto-extracted lesson candidates from archive flow.

Subcommands:
  count             pending entries (all states)
  list              list entries with state
  extract           refine raw entries into candidates via headless claude
  review            interactive promote/delete on candidates (default = shared)

Staging: ~/.claude-work/_shared/lessons-staging.md
HELP
        ;;
    count)
        ensure_staging
        n=$(count_entries)
        n_raw=$(count_entries raw)
        n_cand=$(count_entries candidate)
        echo "$n total ($n_raw raw, $n_cand candidate)"
        ;;
    list)
        ensure_staging
        n=$(count_entries)
        if [ "$n" = 0 ]; then
            echo "(no entries — staging clean)"
        else
            echo "$n entries:"
            list_entries
        fi
        ;;
    extract)
        ensure_staging
        ids=$(ids_with_state raw)
        if [ -z "$ids" ]; then
            echo "(no raw entries to extract — staging clean or all already candidates)"
            exit 0
        fi
        if ! command -v claude >/dev/null 2>&1; then
            echo "WARN: 'claude' CLI not found in PATH — extract step needs it" >&2
            echo "Fallback: paste raw entries below into your planner Opus session manually:" >&2
            for id in $ids; do
                echo ""
                echo "--- raw entry: $id ---"
                read_entry "$id"
            done
            exit 1
        fi
        for id in $ids; do
            echo "Extracting: $id"
            raw_block=$(read_entry "$id")
            prompt=$(cat <<EOF
You are extracting a feedback lesson from a Tandem inbox archive that hit problems mid-run.

Read the raw signals below and produce a single feedback memory entry that:
- Has a short evocative name (under 60 chars)
- Has a one-line description capturing the rule
- Body has two sections: '**Why:**' (root cause / motivation) and '**How to apply:**' (concrete future actions)
- Stays under 200 words total

Output ONLY the markdown body (frontmatter + body). Do not include BEGIN/END markers, do not include explanation.

Frontmatter format:
\`\`\`
---
name: <name>
description: <description>
type: feedback
source-archive: <archive path from raw>
---

<body>
\`\`\`

Raw signals:
$raw_block
EOF
)
            refined=$(claude -p "$prompt" 2>/dev/null) || {
                echo "  ERROR: claude CLI failed for $id — leaving as raw" >&2
                continue
            }
            ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            new_entry="<!-- BEGIN entry id=$id state=candidate timestamp=$ts -->
$refined
<!-- END entry -->"
            replace_entry "$id" "$new_entry"
            echo "  → candidate ready"
        done
        echo ""
        echo "Done. Run 'bash scripts/lessons.sh review' to promote/delete."
        ;;
    review)
        ensure_staging
        ids=$(ids_with_state candidate)
        if [ -z "$ids" ]; then
            echo "(no candidates to review — run 'lessons.sh extract' first if you have raw entries)"
            exit 0
        fi
        n_promoted=0; n_deleted=0; n_skipped=0
        total=$(echo "$ids" | wc -l | tr -d ' ')
        i=0
        for id in $ids; do
            i=$((i + 1))
            echo "---"
            printf '[%d/%d] %s\n' "$i" "$total" "$id"
            block=$(read_entry "$id")
            # Print frontmatter + body (strip BEGIN/END markers)
            echo "$block" | sed '1d;$d'
            echo ""
            while true; do
                printf "Action? [p]romote-shared / [d]elete / [s]kip / [q]uit: "
                ans=$(read_key)
                echo ""
                case "$ans" in
                    p|P|"")
                        # Extract slug from frontmatter name
                        slug=$(echo "$block" | awk '/^name:/ {sub(/^name:[ \t]*/, ""); gsub(/[^a-zA-Z0-9]/, "_"); print tolower($0); exit}')
                        if [ -z "$slug" ]; then
                            slug="lesson_$(date +%s)"
                        fi
                        target="$SHARED_MEM/${slug}.md"
                        if [ -e "$target" ]; then
                            printf "  ⚠️  %s exists. [o]verwrite / [c]ancel: " "$target"
                            cans=$(read_key); echo ""
                            case "$cans" in
                                o|O) ;;
                                *) echo "  → cancelled (kept as candidate)"; break ;;
                            esac
                        fi
                        # Write frontmatter + body to file (strip BEGIN/END markers)
                        echo "$block" | sed '1d;$d' > "$target"
                        # Append index to shared MEMORY.md
                        name=$(awk '/^name:/ {sub(/^name:[ \t]*/, ""); print; exit}' "$target")
                        desc=$(awk '/^description:/ {sub(/^description:[ \t]*/, ""); print; exit}' "$target")
                        printf -- '- [%s](%s) — %s\n' "${name:-$slug}" "${slug}.md" "${desc:-}" >> "$SHARED_MEM/MEMORY.md"
                        remove_entry "$id"
                        echo "  → promoted: $target"
                        n_promoted=$((n_promoted + 1))
                        break
                        ;;
                    d|D)
                        printf "  Confirm delete? [y/N]: "
                        confirm=$(read_key); echo ""
                        case "$confirm" in
                            y|Y) remove_entry "$id"; echo "  → deleted"; n_deleted=$((n_deleted + 1)); break ;;
                            *) echo "  → cancelled" ;;
                        esac
                        ;;
                    s|S) echo "  → skipped"; n_skipped=$((n_skipped + 1)); break ;;
                    q|Q) echo "(quit)"; break 2 ;;
                    *) echo "  (invalid)" ;;
                esac
            done
        done
        echo ""
        echo "=== Summary ==="
        printf 'Promoted: %d  Deleted: %d  Skipped: %d\n' "$n_promoted" "$n_deleted" "$n_skipped"
        ;;
    *)
        echo "Unknown subcommand: $cmd" >&2
        echo "Run 'bash scripts/lessons.sh help' for usage." >&2
        exit 1
        ;;
esac
```

`chmod +x scripts/lessons.sh`（用 `git add` 後也維持 executable bit）。

### Step 3: 修 scripts/archive-prompts.sh — 加 detect + append_raw

讀現檔了解結構。在現檔的 archive 主迴圈**之前**插一個 detection 函式 + 在每個檔被 mv 之前呼叫一次。

加在 `set -euo pipefail` 後 / 主迴圈前：

```bash
STAGING="$HOME/.claude-work/_shared/lessons-staging.md"

# Detect lesson signals from an archive file. If detected, append raw entry to staging (idempotent by archive id).
detect_and_stage_lesson() {
    local archive_file="$1"
    local id
    id=$(basename "$archive_file" .md)

    # Skip if shared dir not yet bootstrapped (some early projects haven't run shared seed)
    [ -d "$(dirname "$STAGING")" ] || return 0

    # Idempotency: skip if already in staging
    if [ -f "$STAGING" ] && grep -q "^<!-- BEGIN entry id=$id " "$STAGING"; then
        return 0
    fi

    # Detect signals
    local has_blocked has_blockers has_fail has_keyword
    has_blocked=$(grep -m1 -E '^\*\*Status\*\*.*❌' "$archive_file" 2>/dev/null || true)
    has_blockers=$(grep -m1 -E '^\*\*Blockers\*\*:' "$archive_file" 2>/dev/null | grep -viE 'none|^\*\*Blockers\*\*: *$' || true)
    has_fail=$(grep -m1 -E '\bFAIL\b' "$archive_file" 2>/dev/null | grep -viE 'PASS|/ FAIL$' || true)
    has_keyword=$(grep -m1 -iE 'next time|should (have|do|run|abort)|lesson learned' "$archive_file" 2>/dev/null || true)

    if [ -z "$has_blocked" ] && [ -z "$has_blockers" ] && [ -z "$has_fail" ] && [ -z "$has_keyword" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$STAGING")"
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    {
        echo "<!-- BEGIN entry id=$id state=raw timestamp=$ts -->"
        echo "- archive: $archive_file"
        [ -n "$has_blocked" ] && echo "- status: ❌ blocked"
        echo "- signals:"
        [ -n "$has_blocked" ] && echo "  - \"$has_blocked\""
        [ -n "$has_blockers" ] && echo "  - \"$has_blockers\""
        [ -n "$has_fail" ] && echo "  - \"$has_fail\""
        [ -n "$has_keyword" ] && echo "  - \"$has_keyword\""
        echo "- excerpt: |"
        awk '/^## Result$/,0' "$archive_file" | head -25 | sed 's/^/    /'
        echo "<!-- END entry -->"
        echo ""
    } >> "$STAGING"

    echo "[archive] lesson signal detected → staged: $id"
}
```

然後在現檔 main 迴圈裡，**在 `git mv` 之前**對每個 archive 候選 file 呼叫 `detect_and_stage_lesson "$f"`：

讀現檔 main 迴圈（ls + for 那段），在 `target_dir="$ARCHIVE_ROOT/$yyyymm"` 那行**之前**或 mv 那行之前都行。建議放在 mv 動作前一行：

```bash
# 原: target="$target_dir/$base"
# 加 ↓
detect_and_stage_lesson "$f"

# 然後接原本的 if [ "$DRY_RUN" = 1 ]...
```

對 legacy phase-* 那個 for 迴圈**不加** detection（legacy 是歷史檔，不重新 extract）。

dry-run 模式（`DRY_RUN=1`）下**也不**呼叫 detection（避免 dry-run 也修改 staging）。在 detect_and_stage_lesson 開頭加 `[ "$DRY_RUN" = 1 ] && return 0`。

### Step 4: scripts/statusline.sh — 加 lessons segment

當前最後一行：
```bash
echo "$inbox · $last_commit · last: $result_emoji"
```

改成（在 echo 前算 lessons count，>0 才顯示）：

```bash
# Lessons pending (only if shared staging exists)
lessons_seg=""
STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
if [ -f "$STAGING" ]; then
    n_lessons=$(grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null || echo 0)
    if [ "$n_lessons" -gt 0 ]; then
        lessons_seg=" · 🎓 $n_lessons"
    fi
fi

echo "$inbox · $last_commit · last: $result_emoji$lessons_seg"
```

確保 statusline 仍然 <100ms（grep -c 一個檔很快，OK）。

### Step 5: scripts/session-briefing.sh — 加 lessons mention

當前 briefing 最後一段是 archive Result block。**在 Result block 之後**追加 lessons staging 段：

```bash
STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
if [ -f "$STAGING" ]; then
    n_total=$(grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null || echo 0)
    if [ "$n_total" -gt 0 ]; then
        n_raw=$(grep -c '^<!-- BEGIN entry .*state=raw' "$STAGING" 2>/dev/null || echo 0)
        n_cand=$(grep -c '^<!-- BEGIN entry .*state=candidate' "$STAGING" 2>/dev/null || echo 0)
        echo ''
        echo '=== lessons pending ==='
        echo "$n_total entries in staging: $n_raw raw, $n_cand candidate"
        echo "Run 'bash scripts/lessons.sh extract' (raw→candidate) then 'review' (candidate→shared)."
    fi
fi
```

### Step 6: bootstrap.sh — copy lessons.sh

讀 bootstrap.sh L552-556 那段 `cp ... scripts/...`。在 notify-blocked.sh 那行之後加：

```bash
cp "$HARNESS_DIR/scripts/lessons.sh" scripts/lessons.sh
```

### Step 7: 創建 docs/LESSONS.md（新檔）

用 Write tool 建 `docs/LESSONS.md`，內容：

```markdown
# Lessons loop

The lessons loop turns inbox rounds that hit problems into reusable feedback memories — automatically staging candidates, then user-reviewed promotion to the cross-project shared layer.

## How it works

1. **Auto-detect on archive.** Every time `scripts/archive-prompts.sh` runs (after `/inbox` completes), it scans the archived prompt's `## Result` block for signals:
   - `Status: ❌ blocked`
   - `Blockers: <non-empty>`
   - Any `FAIL` line in verification
   - Keyword hits: "next time", "should have/do/run/abort", "lesson learned"
2. **Stage raw signal.** If any signal hits, archive-prompts.sh appends a `state=raw` entry to `~/.claude-work/_shared/lessons-staging.md` (cross-project staging — same shared layer as `_shared/memory/`). Idempotent by archive basename.
3. **User refines.** When ready, run `bash scripts/lessons.sh extract`. This invokes `claude -p` headless to refine each raw signal into a structured `state=candidate` lesson with name + description + Why/How-to-apply body.
4. **User reviews.** Run `bash scripts/lessons.sh review`. Walks each candidate interactively: `[p]romote-shared / [d]elete / [s]kip / [q]uit`. Default = promote-shared (Enter). Promoted lessons land in `~/.claude-work/_shared/memory/<slug>.md` and the index `_shared/memory/MEMORY.md` gets a new row.

## Why automatic + user-reviewed

The vision is a self-improving AI partner — but Tandem's ethos is human-in-loop. Auto-detection ensures lessons aren't lost (you'd forget to run `/lessons` manually). User review ensures the shared memory layer doesn't get polluted with bad lessons.

## Discovery

You'll know there are pending lessons via:

- **Statusline**: `📥 inbox · <commit> · last: ✅ · 🎓 3` — the `🎓 N` segment shows total staging count.
- **SessionStart briefing**: includes a `=== lessons pending ===` block when staging is non-empty, with raw/candidate breakdown and the next command to run.

## Subcommands

| Command | What it does |
|---|---|
| `bash scripts/lessons.sh count` | print total + raw/candidate breakdown |
| `bash scripts/lessons.sh list` | list each entry with id + state |
| `bash scripts/lessons.sh extract` | refine all `state=raw` entries via headless claude |
| `bash scripts/lessons.sh review` | interactive promote/delete on `state=candidate` entries |

## Fallback when `claude` CLI unavailable

If `claude` is not in `$PATH`, `lessons.sh extract` prints raw entries to stdout with instructions to paste them into a planner session manually. Useful when working from a machine without Claude Code installed.

## Cross-project lessons

Staging lives at `~/.claude-work/_shared/lessons-staging.md` (user-level, not per-project). Lessons captured in project A become available to project B after promotion. This is the same architecture as `_shared/memory/` — cross-project by design.

## Related

- [SHARED_MEMORY.md](SHARED_MEMORY.md) — shared memory layer architecture
- [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) — feedback memory format + how memory loads at session start
- [MODEL_GUIDE.md](MODEL_GUIDE.md) — model + effort selection (`claude -p` headless invocation in extract uses your default model)
```

### Step 8: docs/REFERENCE.md — 加 lessons.sh + LESSONS.md 列

讀 REFERENCE.md，在 scripts table 加：
```markdown
| `bash scripts/lessons.sh count\|list\|extract\|review` | Auto-extracted lesson candidates from inbox archives. See `docs/LESSONS.md`. |
```

在 docs table 加：
```markdown
| `docs/LESSONS.md` | Lessons loop architecture: auto-stage on archive → extract via headless claude → review and promote to shared memory. |
```

格式對齊現有列。

### Step 9: docs/MEMORY_SYSTEM.md — cross-link

讀檔，在合適位置（feedback memory 段落附近）加一句：

```markdown
> **Auto-captured lessons**: feedback memories don't have to be hand-written. Inbox rounds that hit problems (blockers, FAIL lines, "next time" notes) auto-stage as candidate lessons; review and promote them via `scripts/lessons.sh`. See [LESSONS.md](LESSONS.md).
```

### Step 10: scripts/test-bootstrap.sh — 加 assertions

讀 test-bootstrap.sh，在 scripts existence 段加 lessons.sh，在 scripts runnable 段加 dry-run-equivalent test。改動具體：

(a) scripts existence assertions（找 `archive-prompts.sh exists` 那行附近）：
```bash
assert "scripts/lessons.sh exists" test -f "$BOOT_DIR/scripts/lessons.sh"
assert "scripts/lessons.sh executable" test -x "$BOOT_DIR/scripts/lessons.sh"
```

(b) scripts runnable 段（找 `memory.sh list runs` 那行附近）：
```bash
assert "lessons.sh count runs" bash -c "cd '$BOOT_DIR' && bash scripts/lessons.sh count >/dev/null"
assert "lessons.sh help runs" bash -c "cd '$BOOT_DIR' && bash scripts/lessons.sh help >/dev/null"
```

assertion 數量會從 32 → 36（4 條新增）。

### Step 11: 中段 verification

```bash
# 11a. 新檔
[ -f scripts/lessons.sh ] && [ -x scripts/lessons.sh ] && echo "PASS: lessons.sh exists + executable"
[ -f docs/LESSONS.md ] && echo "PASS: LESSONS.md exists"

# 11b. lessons.sh subcommands run
bash scripts/lessons.sh help >/dev/null && echo "PASS: lessons.sh help"
bash scripts/lessons.sh count >/dev/null && echo "PASS: lessons.sh count"
bash scripts/lessons.sh list >/dev/null && echo "PASS: lessons.sh list"

# 11c. archive-prompts.sh 有 detection
grep -q "detect_and_stage_lesson" scripts/archive-prompts.sh && echo "PASS: archive has detection func"

# 11d. statusline 有 lessons segment
grep -q "lessons_seg" scripts/statusline.sh && echo "PASS: statusline has lessons segment"

# 11e. briefing 有 lessons block
grep -q "lessons pending" scripts/session-briefing.sh && echo "PASS: briefing has lessons block"

# 11f. bootstrap 有 copy
grep -q "cp.*scripts/lessons.sh" bootstrap.sh && echo "PASS: bootstrap copies lessons.sh"

# 11g. cross-links
grep -q "MODEL_GUIDE\|LESSONS" docs/REFERENCE.md && echo "PASS: REFERENCE links"
grep -q "LESSONS.md\|Auto-captured lessons" docs/MEMORY_SYSTEM.md && echo "PASS: MEMORY_SYSTEM cross-links lessons"

# 11h. test-bootstrap 32→36
n_passed=$(bash scripts/test-bootstrap.sh 2>&1 | grep -oE 'PASS: [0-9]+/[0-9]+' | head -1)
echo "test-bootstrap: $n_passed"
echo "$n_passed" | grep -qE '36/36' && echo "PASS: test-bootstrap 36/36" || { echo "FAIL: expected 36/36"; bash scripts/test-bootstrap.sh 2>&1 | tail -10; exit 1; }

# 11i. bash syntax
bash -n bootstrap.sh && echo "PASS: bootstrap syntax"
bash -n scripts/lessons.sh && echo "PASS: lessons.sh syntax"
bash -n scripts/archive-prompts.sh && echo "PASS: archive syntax"
bash -n scripts/statusline.sh && echo "PASS: statusline syntax"
bash -n scripts/session-briefing.sh && echo "PASS: briefing syntax"
```

要全 PASS 才繼續。**特別注意 test-bootstrap 36/36** — 32→36 是這輪的 deliverable signal。

### Step 12: Commits（atomic, 5 commits）

```bash
# Commit 1: lessons.sh + bootstrap copy
git add scripts/lessons.sh bootstrap.sh
git commit -m "feat: scripts/lessons.sh — auto-extract lesson candidates from inbox archives

Subcommands: count / list / extract / review.

State machine in ~/.claude-work/_shared/lessons-staging.md:
- raw    (appended by archive-prompts.sh on lesson-signal detection)
- candidate (refined by 'extract' via 'claude -p' headless)
- promoted/deleted (final action by 'review', removes entry from staging)

Review UX mirrors memory.sh promote — interactive p/d/s/q with default = promote-shared.
Promoted lessons land in ~/.claude-work/_shared/memory/<slug>.md plus an index row.

bootstrap.sh now copies scripts/lessons.sh into new projects."

# Commit 2: archive-prompts.sh detection
git add scripts/archive-prompts.sh
git commit -m "feat: archive-prompts.sh detects lesson signals + stages raw entries

Trigger heuristic per Phase C decision #3:
- Status: ❌ blocked
- Blockers: <non-empty>
- FAIL line in verification
- Keyword hits: 'next time', 'should ...', 'lesson learned'

On hit, append a state=raw entry to ~/.claude-work/_shared/lessons-staging.md
with the archive path, the matched signals, and the Result block excerpt.
Idempotent (archive basename as id). Skipped under DRY_RUN=1.

Legacy phase-*.md archives are not scanned — they predate the lesson loop."

# Commit 3: discovery (statusline + briefing)
git add scripts/statusline.sh scripts/session-briefing.sh
git commit -m "feat: statusline + briefing surface pending lessons count

- statusline.sh: appends '· 🎓 N' segment when lessons-staging.md has entries
- session-briefing.sh: prints '=== lessons pending ===' block on session
  start with raw/candidate breakdown and the next command to run

Both gracefully skip when shared layer is uninitialized (early projects)."

# Commit 4: docs (LESSONS.md + cross-links)
git add docs/LESSONS.md docs/REFERENCE.md docs/MEMORY_SYSTEM.md
git commit -m "docs: LESSONS.md + REFERENCE/MEMORY_SYSTEM cross-links

LESSONS.md covers the architecture: signal detection → raw staging →
extract → review → promote-shared. Includes subcommand reference and
fallback behavior when claude CLI is unavailable.

REFERENCE.md lists lessons.sh subcommands and the new doc.
MEMORY_SYSTEM.md gets a one-line callout pointing at LESSONS.md."

# Commit 5: test-bootstrap assertions
git add scripts/test-bootstrap.sh
git commit -m "test: test-bootstrap.sh asserts lessons.sh present + runnable

4 new assertions (existence, executable, count subcommand, help subcommand).
Total: 32 → 36."
```

### Step 13: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

archive 會把本檔歸檔成 `docs/prompts/<date>-phase-c-lessons-loop.md` 並清空 inbox。

> **Note**: 本輪 archive 自身會經過新加的 detection — 如果本輪 Result block 含 ❌/Blocker/FAIL/keyword 就會自動 stage。**期望**是這輪全 PASS shipped → detection 不觸發 → staging 無新 entry。如果觸發代表本輪有踩坑，會是好的 dogfood signal。

## Hard rules

1. lessons.sh 邏輯**直接照 step 2 inline**寫入，不要自己改寫主流程（特別是 awk 處理 BEGIN/END marker 那段）
2. archive-prompts.sh 的 detect function 必須 idempotent（同 archive 重跑不重複 stage）
3. statusline 的 lessons 段**只在 staging 非空才顯示**（empty 不要印「🎓 0」）
4. headless `claude -p` 需要 `claude` 在 PATH — 沒有時 `extract` graceful fallback（已寫在 step 2 lessons.sh 內）
5. test-bootstrap 必須 36/36 才算過
6. 任何 step FAIL → STOP 印錯誤、不強跑
7. 5 commits 不合併（atomic）
8. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
9. **本輪 ship 完 STOP** — 下一步 v0.5.0 release，不 auto-queue

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 6 (incl. archive)
<sha> feat: scripts/lessons.sh + bootstrap copy
<sha> feat: archive-prompts.sh detects lesson signals
<sha> feat: statusline + briefing surface pending lessons
<sha> docs: LESSONS.md + REFERENCE/MEMORY_SYSTEM cross-links
<sha> test: test-bootstrap.sh asserts lessons.sh
<sha> chore: archive phase-c-lessons-loop inbox prompt + result

**Verification**:
- lessons.sh exists + executable: PASS / FAIL
- lessons.sh help / count / list run: PASS / FAIL
- archive-prompts.sh has detection func: PASS / FAIL
- statusline has lessons segment: PASS / FAIL
- briefing has lessons block: PASS / FAIL
- bootstrap copies lessons.sh: PASS / FAIL
- LESSONS.md created + cross-linked: PASS / FAIL
- test-bootstrap 36/36: PASS / FAIL
- bash syntax all 5 scripts: PASS / FAIL
- this round did NOT trigger lesson-detect on its own archive (i.e. clean ship): PASS / WARN(self-triggered, contents in staging)

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 6 (incl. archive)
9335889 feat: scripts/lessons.sh — auto-extract lesson candidates from inbox archives
09bc4c7 feat: archive-prompts.sh detects lesson signals + stages raw entries
3784063 feat: statusline + briefing surface pending lessons count
a915244 docs: LESSONS.md + REFERENCE/MEMORY_SYSTEM cross-links
4a63a16 test: test-bootstrap.sh asserts lessons.sh present + runnable
<archive-sha> chore: archive phase-c-lessons-loop inbox prompt + result

**Verification**:
- lessons.sh exists + executable: PASS
- lessons.sh help / count / list run: PASS
- archive-prompts.sh has detection func: PASS
- statusline has lessons segment: PASS
- briefing has lessons block: PASS
- bootstrap copies lessons.sh: PASS
- LESSONS.md created + cross-linked: PASS
- test-bootstrap 36/36: PASS
- bash syntax all 5 scripts: PASS
- this round did NOT trigger lesson-detect on its own archive (i.e. clean ship): WARN (self-detecting on this archive — expected dogfood signal)

**Push**: ✅ pushed to origin/main
**Blockers**: none
