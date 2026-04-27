# Polish-r5: self-host gaps（RESUME + REFERENCE + session-briefing fallback）

## Goal

修三個剛踩到的 dogfooding 漏洞：
1. **session-briefing.sh** 沒 RESUME.md 就靜默 exit → 改成有 fallback 也印 commits + archive Result
2. **woody-harness 自己 root 沒 RESUME.md** → 補上，self-host 才完整
3. **沒有單一 reference cheatsheet** → 補 `docs/REFERENCE.md`，所有 bootstrap modes / slash commands / scripts / hooks / memory 一頁列完

## Execution profile

- model: sonnet
- effort: small-medium
- 4 commits（fallback / RESUME / REFERENCE / archive）

## Background context（Sonnet 你需要知道的）

woody-harness 是 self-use first 的 workflow harness。User 最近踩到三個漏洞：

- 開新 session 時 SessionStart hook 沒印任何東西 → 因為 `scripts/session-briefing.sh` 第一行 `test -f RESUME.md || exit 0`，woody-harness root 沒 RESUME.md 所以靜默 exit
- 問「我怎麼知道所有指令」時 user 找不到單一 reference → 散在 README + TUTORIAL + WORKFLOW + 各 .claude/commands/ + scripts/
- woody-harness 自己沒 RESUME.md（templates/RESUME.md 是給 bootstrap 複製出去的）→ self-host 漏網

S-1（bootstrap upgrade/remove）剛跑完，4 commits 已 push。test-bootstrap.sh 32/32 PASS。

---

## Commit 1: `fix: scripts/session-briefing.sh — print commits + archive Result even when RESUME.md missing`

修改 `scripts/session-briefing.sh`：

**Before**（現況）：
```bash
#!/usr/bin/env bash
set -e
test -f RESUME.md || exit 0    # ← 沒 RESUME 就靜默退出
echo '=== RESUME.md (head) ==='
head -30 RESUME.md
...
```

**After**（要改成）：
```bash
#!/usr/bin/env bash
set -e

if [ -f RESUME.md ]; then
    echo '=== RESUME.md (head) ==='
    head -30 RESUME.md
    echo ''
fi

echo '=== recent commits ==='
git log --oneline -5 2>/dev/null || true
echo ''

latest=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1 || true)
if [ -n "$latest" ]; then
    echo '=== latest archive Result ==='
    awk '/^## Result$/,0' "$latest" | head -15
fi
```

關鍵差異：
- RESUME.md 段改成 `if [ -f ]` 條件，沒有就跳過、不退出
- 不論 RESUME 在不在，commits + archive Result 都會印

驗證（commit 前自己跑）：
```bash
# 1. 從 woody-harness root 跑（沒 RESUME.md），預期看到 commits + archive Result（沒有 RESUME 那段）
cd /Users/woody/Desktop/repo/public/woody-harness
bash scripts/session-briefing.sh | tee /tmp/wh-r5-test1.txt
grep -q "recent commits" /tmp/wh-r5-test1.txt && echo "PASS: commits printed" || { echo "FAIL: no commits"; exit 1; }
grep -q "latest archive Result" /tmp/wh-r5-test1.txt && echo "PASS: archive Result printed" || { echo "FAIL: no archive"; exit 1; }
! grep -q "RESUME.md (head)" /tmp/wh-r5-test1.txt && echo "PASS: RESUME section skipped (correct)" || { echo "FAIL: RESUME section appeared without RESUME.md"; exit 1; }

# 2. 用 bootstrap 建一個 fresh target（會有 RESUME.md），跑 briefing，預期三段都印
TMP=$(mktemp -d)
cd "$TMP"
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh test-r5
cd test-r5
bash scripts/session-briefing.sh | tee /tmp/wh-r5-test2.txt
grep -q "RESUME.md (head)" /tmp/wh-r5-test2.txt && echo "PASS: RESUME section printed" || { echo "FAIL"; exit 1; }
grep -q "recent commits" /tmp/wh-r5-test2.txt && echo "PASS: commits printed" || { echo "FAIL"; exit 1; }

# 清理
SLUG=$(echo "$TMP/test-r5" | sed 's|/|-|g')
rm -rf "$TMP" "$HOME/.claude-work/projects/$SLUG"
```

要全 PASS 才 commit 1。

---

## Commit 2: `docs: RESUME.md — self-host woody-harness's own status`

新增 `RESUME.md`（root，不是 templates/）。內容如下（直接照抄；事實的部分自己核對 git log + version）：

```markdown
# woody-harness — RESUME

**What**: Self-use solo-dev workflow harness for Claude Code (planner/executor split via 2 terminals).
**Version**: 0.4.0 + S-1 (bootstrap --upgrade-existing / --remove modes shipped 2026-04-27)
**Repo**: https://github.com/woodylin0920-bit/woody-harness

## Current focus

Phase 4 polish + self-host gaps. Recent rounds: r1 (TROUBLESHOOTING), r2 (memory.sh + test-bootstrap), r3 (statusline + /sync), r4 (notify-blocked + empty inbox), r5 (RESUME + REFERENCE + briefing fallback).

## How to use this harness on itself

woody-harness self-hosts since 4a — its own inbox lives at `docs/prompts/_inbox.md`, runs through `/inbox` slash command, archives via `scripts/archive-prompts.sh`.

```bash
# Planner terminal (Opus):
claude
# discuss design, write prompt to docs/prompts/_inbox.md

# Executor terminal (Sonnet):
claude --model sonnet
/inbox    # runs the queued prompt, commits, archives, notifies
```

## Where to look

| Topic | File |
|---|---|
| Tutorial / first-time setup | `docs/TUTORIAL.md` |
| Flat command/script/hook reference | `docs/REFERENCE.md` |
| Workflow rationale (planner/executor split) | `docs/WORKFLOW.md` |
| Design principles | `docs/HARNESS_ETHOS.md` |
| Memory system | `docs/MEMORY_SYSTEM.md` |
| bootstrap upgrade mode | `docs/UPGRADE.md` |
| bootstrap remove mode | `docs/REMOVE.md` |
| Troubleshooting | `docs/TROUBLESHOOTING.md` |
| Deferred ideas | `docs/FUTURE.md` |
| Phase gates / smoke testing | `docs/PHASE_GATING.md`, `docs/SMOKE_TESTING.md` |
| Codex audit format | `docs/CODEX_AUDIT.md` |

## Memory dir

`~/.claude-work/projects/-Users-woody-Desktop-repo-public-woody-harness/memory/`

`MEMORY.md` is the index; individual memory files (user/feedback/project/reference) live alongside.

## Active inbox

See `docs/prompts/_inbox.md` for any currently queued task. Empty = no work in flight. Run `bash scripts/statusline.sh` for one-line state.

## Recent shipped phases

- **Phase 1 (2026-04-27)**: bootstrap + inbox + memory templates + WORKFLOW
- **Phase 2 (2026-04-27)**: codex/safety audit + smoke + phase-gate
- **Phase 4a (2026-04-28)**: legal/entry — LICENSE, CHANGELOG, README rewrite, ISSUE_TEMPLATE×3, self-host inbox
- **Phase 4b (2026-04-28)**: onboarding — TUTORIAL, HARNESS_ETHOS, TROUBLESHOOTING, CONTRIBUTING, MEMORY_SYSTEM, /resume slash, SessionStart hook
- **Phase 4c (2026-04-28)**: examples/hello-cli/ + omni-sense purge
- **Phase 4d (2026-04-28)**: /inbox feedback loop (Result block + osascript notify)
- **Phase 4-polish r1-r4 (2026-04-28)**: archive helper / memory.sh / test-bootstrap / statusline / /sync / notify-blocked / empty-inbox fix
- **S-1 (2026-04-27)**: bootstrap.sh --upgrade-existing + --remove modes
- **Polish r5 (this round)**: RESUME self-host + REFERENCE + session-briefing fallback
```

驗證（commit 前自己跑）：
```bash
test -f RESUME.md && echo "PASS: RESUME.md created" || { echo "FAIL"; exit 1; }
bash scripts/session-briefing.sh | grep -q "RESUME.md (head)" && echo "PASS: briefing now prints RESUME" || { echo "FAIL"; exit 1; }
```

要全 PASS 才 commit 2。

---

## Commit 3: `docs: REFERENCE.md cheatsheet + README link`

新增 `docs/REFERENCE.md`，內容如下（直接照抄；表格內事實對照 .claude/commands/ + scripts/ + bootstrap.sh + .claude/settings.json）：

```markdown
# woody-harness reference

Flat list of every CLI mode, slash command, script, hook, and memory location. For *why* and *how to use*, see TUTORIAL / WORKFLOW / individual docs.

## bootstrap.sh modes

| Mode | Command | Detail |
|---|---|---|
| New project | `bash bootstrap.sh <name>` | Creates `<name>/` from templates, git init, copies framework files |
| Upgrade existing | `bash bootstrap.sh --upgrade-existing <path>` | Dry-run by default — see `docs/UPGRADE.md` |
| Upgrade apply | `bash bootstrap.sh --upgrade-existing <path> --apply` | Actually writes |
| Remove | `bash bootstrap.sh --remove <path>` | Dry-run by default — see `docs/REMOVE.md` |
| Remove apply | `bash bootstrap.sh --remove <path> --apply` | Actually deletes (memory preserved) |

## Slash commands (`.claude/commands/`)

| Command | Purpose |
|---|---|
| `/inbox` | Run `docs/prompts/_inbox.md`, append Result block, archive, notify (Glass on success, Mei-Jia "卡住了" on fail) |
| `/resume` | Print RESUME.md head + recent commits + handoff memory |
| `/sync` | Print git log + inbox state + latest archive Result block |
| `/codex-audit` | Run codex review per `docs/CODEX_AUDIT.md` template |
| `/phase-gate` | Run pytest + benchmark + emit verdict |

## Scripts (`scripts/`)

| Script | Usage | Purpose |
|---|---|---|
| `statusline.sh` | (auto via `.claude/settings.json` `statusLine`) | One-line status: 📥 inbox state · last commit · last result |
| `session-briefing.sh` | (auto via SessionStart hook) | Print RESUME head + commits + latest archive Result on session open |
| `notify-blocked.sh` | (auto via Notification hook) | Funk sound + osascript banner when executor blocked |
| `archive-prompts.sh` | `bash scripts/archive-prompts.sh` | Move _inbox.md content to `docs/prompts/<phase>.md`, append Result, clear inbox |
| `memory.sh` | `bash scripts/memory.sh export <out.tar.gz>` | Tar memory dir for transport |
| | `bash scripts/memory.sh import <in.tar.gz>` | Untar to memory dir |
| | `bash scripts/memory.sh list` | List memory files |
| `test-bootstrap.sh` | `bash scripts/test-bootstrap.sh` | 32-check regression test on bootstrap output |
| `smoke.sh` | `bash scripts/smoke.sh` | Real-machine smoke test runner (per docs/SMOKE_TESTING.md) |

## Hooks (`.claude/settings.json`)

| Event | Command | Effect |
|---|---|---|
| `SessionStart` | `bash scripts/session-briefing.sh` | Auto-prints briefing on session open |
| `Notification` | `bash scripts/notify-blocked.sh` | Auto-fires when executor stalled (permission prompt / idle) |

## Status line

Set in `.claude/settings.json` `statusLine.command = "bash scripts/statusline.sh"`. Renders at terminal bottom.

## Memory dir

`~/.claude-work/projects/<slug>/memory/`

- `<slug>` = absolute target path with `/` replaced by `-`
- `MEMORY.md` = index (always loaded into context)
- Individual memory files: `<type>_<topic>.md` (types: user / feedback / project / reference)

## Conventions

- **Inbox**: one slot at `docs/prompts/_inbox.md` — frozen once shipped to executor
- **Result block**: appended after `## Result` heading by `/inbox` on completion
- **Archive**: `docs/prompts/<date>-<phase>.md` after completion (via archive-prompts.sh)
- **Auto-queue**: sequence-bounded — executor must STOP after declared rounds, no auto-chain unless user pre-approves

## Source layout

```
woody-harness/
├── bootstrap.sh                  # entrypoint (new / upgrade / remove)
├── RESUME.md                     # self-host status (this harness on itself)
├── README.md                     # GitHub landing
├── CHANGELOG.md                  # version history
├── .claude/
│   ├── settings.json             # statusLine + hooks + permissions
│   └── commands/                 # slash commands
├── scripts/                      # all bash scripts (also copied to bootstrapped projects)
├── templates/                    # what bootstrap copies into new projects
│   ├── CLAUDE.md, RESUME.md, .gitignore
│   ├── prompts/                  # _inbox + framework templates (CODEX_AUDIT, SAFETY_AUDIT, ISSUES, README)
│   └── memory/                   # seed memory files
├── docs/                         # this docs/ tree
│   ├── REFERENCE.md              # this file
│   ├── TUTORIAL.md, WORKFLOW.md, HARNESS_ETHOS.md, ...
│   └── prompts/
│       ├── _inbox.md             # active inbox (this self-hosting harness)
│       └── <date>-<phase>.md     # archived rounds
└── examples/hello-cli/           # demo bootstrap output
```
```

然後修改 `README.md`：在「Bootstrap」段附近加 link「**Quick reference**: see `docs/REFERENCE.md` for every command, script, and hook.」。具體位置：找 `bash bootstrap.sh` 範例附近，加在那段下面或 Quickstart 結尾。如果有「Documentation」/「Docs」段就加進去。

修改 `CHANGELOG.md`：在 `[Unreleased]` 下加（如沒 [Unreleased] 段就建一個）：
```markdown
### Added
- `RESUME.md` self-hosting woody-harness's own status (was missing — SessionStart hook silent before)
- `docs/REFERENCE.md` — flat cheatsheet of every bootstrap mode / slash command / script / hook
- `scripts/session-briefing.sh` falls back gracefully when `RESUME.md` absent (prints commits + archive Result anyway)
```

驗證：
```bash
test -f docs/REFERENCE.md && echo "PASS: REFERENCE.md created" || { echo "FAIL"; exit 1; }
grep -q "REFERENCE.md" README.md && echo "PASS: README links REFERENCE" || { echo "FAIL"; exit 1; }
grep -q "RESUME.md self-hosting\|REFERENCE.md\|session-briefing" CHANGELOG.md && echo "PASS: CHANGELOG updated" || { echo "FAIL"; exit 1; }
```

要全 PASS 才 commit 3。

---

## Commit 4 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-polish-r5-resume-reference-briefing-fallback.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify files outside這些：`scripts/session-briefing.sh`（commit 1）、`RESUME.md`（新, root, commit 2）、`docs/REFERENCE.md`（新, commit 3）、`README.md`（commit 3）、`CHANGELOG.md`（commit 3）。
2. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
3. 任何驗證 step 失敗 → STOP + 印錯誤 + 不要 commit broken code。
4. session-briefing.sh 改完務必兩個情境都驗（無 RESUME / 有 RESUME），不能只驗一邊。
5. **不要修 templates/RESUME.md**（那是給 bootstrap 用的 template，跟 root RESUME.md 是兩個不同檔案，commit 2 只動 root）。
6. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
7. 通知：3 個 commit 都成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "polish-r5 done" with title "woody-harness"'`；任何 commit 驗證失敗 → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。
8. 最後跑 `bash scripts/test-bootstrap.sh` 確認沒 break（應 PASS 32/32 — 沒新增 check 但要確認既有 check 沒被改壞）。

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

**Verification**:
- session-briefing 從 woody-harness root（無 RESUME）印 commits + archive: PASS / FAIL
- session-briefing 從 fresh bootstrap target（有 RESUME）印三段全部: PASS / FAIL
- RESUME.md exists at root: PASS / FAIL
- docs/REFERENCE.md exists: PASS / FAIL
- README.md links to REFERENCE.md: PASS / FAIL
- CHANGELOG.md [Unreleased] updated: PASS / FAIL
- test-bootstrap.sh: PASS 32/32 / FAIL <n>/32

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 4 (incl. archive)
cee736f fix: scripts/session-briefing.sh — print commits + archive Result even when RESUME.md missing
451f8a8 docs: RESUME.md — self-host woody-harness's own status
edcf023 docs: REFERENCE.md cheatsheet + README link
<this commit> chore: archive polish-r5-resume-reference-briefing-fallback inbox prompt + result

**Verification**:
- session-briefing 從 woody-harness root（無 RESUME）印 commits + archive: PASS
- session-briefing 從 fresh bootstrap target（有 RESUME）印三段全部: PASS
- RESUME.md exists at root: PASS
- docs/REFERENCE.md exists: PASS
- README.md links to REFERENCE.md: PASS
- CHANGELOG.md [Unreleased] updated: PASS
- test-bootstrap.sh: PASS 32/32

**Push**: ⏸ pending (will push after archive commit)
**Blockers**: none
