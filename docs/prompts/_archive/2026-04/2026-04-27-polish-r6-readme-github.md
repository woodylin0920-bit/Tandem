# Polish-r6: README + GitHub metadata refresh (P0 public-facing)

## Goal

修兩個 user 直接踩到的 public-facing stale 問題：

1. **README.md 多處過時** — Roadmap 還寫 Phase 4 [ ] 但全 shipped、"What you get" 漏列 v0.4.1 一半招牌功能、CONTRIBUTING 沒被 link、沒 version badge
2. **GitHub repo metadata** — description 還寫「Extracted from omni-sense」（Phase 4c 已 purge）、`repositoryTopics` 是空的、訪客無法靠 GitHub search 找到

## Execution profile

- model: sonnet
- effort: small（純 docs + gh CLI 一次 call）
- 2 commits + 1 gh ops（README+CHANGELOG / gh repo edit / archive）

## Background context

User 看 README 發現 Roadmap 說 Phase 4 沒做，但 v0.4.1 早 ship + tag。`gh repo view --json description` 顯示 `"Solo developer framework ... Extracted from omni-sense."` — Phase 4c omni-sense purge commit `92ac500` 沒同步到 GitHub metadata。

User 已預先授權跑 `gh repo edit`（這個 round 的 GitHub metadata 改動）— 可以直接執行，不用再問。

---

## Commit 1: `docs: README + CHANGELOG — refresh roadmap, expand features, link CONTRIBUTING, version badge`

### A. README.md 改 4 處

#### A1. Badge 行（line 3）加一個 latest release badge

**Before**：
```markdown
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg) ![Bash + Markdown](https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue) ![Zero deps](https://img.shields.io/badge/deps-zero-brightgreen)
```

**After**：
```markdown
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg) ![Latest release](https://img.shields.io/github/v/release/woodylin0920-bit/woody-harness) ![Bash + Markdown](https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue) ![Zero deps](https://img.shields.io/badge/deps-zero-brightgreen)
```

#### A2. "What you get" 段擴充（找 `## What you get` 整段替換）

**Before**（5 條）：
```markdown
## What you get

- **Plan / Execute session split** — Opus terminal plans + writes prompts, Sonnet executes via `/inbox` slash command
- **Inbox handoff** — `docs/prompts/_inbox.md` is the cross-session mailbox
- **Memory system** — auto-loaded preferences, workflow rules, project state
- **Phase-based atomic commits** — every change ship-ready, revertable
- **Pre-flight checks** — every executor prompt starts with environment verification
```

**After**（10 條）：
```markdown
## What you get

- **Plan / Execute session split** — Opus terminal plans + writes prompts, Sonnet executes via `/inbox` slash command
- **Inbox handoff** — `docs/prompts/_inbox.md` is the cross-session mailbox; archived per round with `## Result` block convention
- **Memory system** — auto-loaded preferences, workflow rules, project state in `~/.claude-work/projects/<slug>/memory/`
- **Slash commands** — `/inbox`, `/sync`, `/brief`, `/codex-audit`, `/phase-gate` (see [docs/REFERENCE.md](docs/REFERENCE.md))
- **Status line** — terminal-bottom live indicator: `📥 inbox state · last commit · last result emoji`
- **Hooks** — `SessionStart` auto-briefing (RESUME + commits + latest archive Result), `Notification` alert when executor stalls (Funk + osascript banner)
- **Phase-based atomic commits** — every change ship-ready, revertable
- **Pre-flight checks** — every executor prompt starts with environment verification + final `## Result` block PASS/FAIL
- **Project lifecycle** — `bash bootstrap.sh --upgrade-existing <path>` syncs framework upgrades into older projects (dry-run by default); `--remove <path>` cleanly extracts the framework while preserving your work + memory (see [docs/UPGRADE.md](docs/UPGRADE.md), [docs/REMOVE.md](docs/REMOVE.md))
- **Memory portability** — `bash scripts/memory.sh export/import` to move memory dirs across machines
```

#### A3. Roadmap 段整段替換

**Before**：
```markdown
## Roadmap

- [x] Phase 1: bootstrap + inbox + memory templates
- [x] Phase 2: codex audit + safety audit + smoke test templates
- ~~Phase 3: CI / hooks / push notifications~~ (deferred — see FUTURE.md)
- [ ] Phase 4: philosophy docs + example project + user research framework
```

**After**：
```markdown
## Roadmap

- [x] **Phase 1** — bootstrap + inbox + memory templates
- [x] **Phase 2** — codex audit + safety audit + smoke test templates
- [x] **Phase 4** — onboarding (TUTORIAL, HARNESS_ETHOS, TROUBLESHOOTING, MEMORY_SYSTEM, CONTRIBUTING) + `examples/hello-cli/` + feedback loop (statusline, /sync, /brief, notify-blocked) + lifecycle (bootstrap upgrade/remove via S-1)
- [x] **v0.4.1 release** — polish r2-r5 + S-1 (bootstrap modes) + retro
- [ ] **T-1a** — cross-project shared memory layer (next major; "Claude gets smarter as you work across projects")
- [ ] **4e** — model + effort recommendation system (`MODEL_GUIDE.md` + `/recommend`)
- ~~Phase 3: CI / hooks / push notifications~~ (deferred — see [docs/FUTURE.md](docs/FUTURE.md))
```

#### A4. 加 Contributing 段（在 `## License` 之前）

```markdown
## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines (issue templates, commit message conventions, how rounds get scoped).

## License

MIT (see LICENSE).
```

> 找原本的 `## License` 行，在它**之前**插入 Contributing 段。

### B. CHANGELOG.md `[Unreleased]` 加 entry

如果 `[Unreleased]` 段現在是空的（v0.4.1 release 後留的占位），填：

```markdown
## [Unreleased]

### Changed
- README refreshed: Roadmap reflects shipped state (Phase 4 + S-1 + v0.4.1 done; T-1a / 4e queued); "What you get" expanded with all v0.4.1 features (slash commands, statusline, hooks, lifecycle modes, memory portability); added latest-release badge; linked CONTRIBUTING.md.
- GitHub repo metadata refreshed: description (removed origin-project reference); repository topics added (claude-code, ai-agents, solo-dev, workflow, bash, developer-tools, prompt-engineering, claude-opus, claude-sonnet, bootstrap).
```

如果 `[Unreleased]` 已有內容（例如剛剛 dogfood 加過），就 **append** 上面這段到 `### Changed` 下（如已有 `### Changed` 副標就合併）。

### C. Verification

```bash
# Roadmap 已不寫 Phase 4 [ ]
! grep -q "^- \[ \] Phase 4" README.md && echo "PASS: Phase 4 not unchecked" || { echo "FAIL"; exit 1; }

# Roadmap 有 T-1a
grep -q "T-1a" README.md && echo "PASS: T-1a in roadmap" || { echo "FAIL"; exit 1; }

# What you get 提到 statusline + hooks + slash commands + upgrade/remove
grep -q "Status line" README.md && echo "PASS: statusline mentioned" || { echo "FAIL"; exit 1; }
grep -q "Hooks" README.md && echo "PASS: hooks mentioned" || { echo "FAIL"; exit 1; }
grep -q "Slash commands" README.md && echo "PASS: slash commands mentioned" || { echo "FAIL"; exit 1; }
grep -q "upgrade-existing" README.md && echo "PASS: upgrade mentioned" || { echo "FAIL"; exit 1; }
grep -q "Memory portability" README.md && echo "PASS: memory portability mentioned" || { echo "FAIL"; exit 1; }

# CONTRIBUTING link
grep -q "CONTRIBUTING.md" README.md && echo "PASS: CONTRIBUTING linked" || { echo "FAIL"; exit 1; }

# Latest release badge
grep -q "img.shields.io/github/v/release" README.md && echo "PASS: release badge" || { echo "FAIL"; exit 1; }

# CHANGELOG [Unreleased] 有 entry
awk '/^## \[Unreleased\]/,/^## \[/' CHANGELOG.md | grep -q "README refreshed" && echo "PASS: CHANGELOG entry" || { echo "FAIL"; exit 1; }
```

要全 PASS 才 commit 1。

---

## After commit 1 — run `gh repo edit`（不是 commit，是 GitHub API call）

User 已預先授權。執行：

```bash
gh repo edit woodylin0920-bit/woody-harness \
  --description "Solo-developer workflow harness for Claude Code — planner Opus + executor Sonnet split, cross-session inbox, project memory, lifecycle modes (upgrade/remove)." \
  --add-topic claude-code \
  --add-topic ai-agents \
  --add-topic solo-dev \
  --add-topic workflow \
  --add-topic bash \
  --add-topic developer-tools \
  --add-topic prompt-engineering \
  --add-topic claude-opus \
  --add-topic claude-sonnet \
  --add-topic bootstrap 2>&1 | tee /tmp/wh-r6-gh.txt
```

Verify：
```bash
gh repo view woodylin0920-bit/woody-harness --json description,repositoryTopics 2>&1 | python3 -m json.tool

# Description 不能還有 omni-sense
! gh repo view woodylin0920-bit/woody-harness --json description -q .description | grep -qi "omni-sense" && echo "PASS: description clean" || { echo "FAIL: description still mentions omni-sense"; exit 1; }

# Topics 至少含 claude-code
gh repo view woodylin0920-bit/woody-harness --json repositoryTopics -q '.repositoryTopics[].name' | grep -q "claude-code" && echo "PASS: claude-code topic added" || { echo "FAIL"; exit 1; }
```

如 `gh repo edit` 失敗（auth / rate limit / topic conflict）：
- 不要 abort
- 把 commands 印在最後 Result block 「Manual fallback」段，叫 user 自己執行
- commit 1（README）已 ship 是有意義的，commit 2 archive 照常跑

---

## Commit 2 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-polish-r6-readme-github.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify files outside這些：`README.md`（commit 1）、`CHANGELOG.md`（commit 1）。
2. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
3. 任何 commit 1 verification step FAIL → STOP + 印錯誤 + 不 commit broken state。
4. `gh repo edit` 失敗 → 不 abort，印 fallback 命令，繼續 commit archive。
5. 不要動歷史 CHANGELOG entries（[0.4.1] / [0.4.0] / [0.2.0] / [0.1.0]）。
6. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
7. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "README + GitHub refreshed" with title "woody-harness"'`；commit 1 verification FAIL → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 2 (incl. archive)
<sha> docs: README + CHANGELOG — refresh roadmap, expand features, link CONTRIBUTING, version badge
<sha> chore: archive polish-r6-readme-github inbox prompt + result

**README verifications**:
- Phase 4 not unchecked: PASS / FAIL
- T-1a in roadmap: PASS / FAIL
- Statusline / Hooks / Slash commands / upgrade-existing / Memory portability mentioned: PASS / FAIL
- CONTRIBUTING linked: PASS / FAIL
- Latest release badge: PASS / FAIL
- CHANGELOG [Unreleased] entry: PASS / FAIL

**GitHub metadata**:
- gh repo edit succeeded: PASS / FAIL (manual fallback below)
- Description no longer mentions omni-sense: PASS / FAIL
- claude-code topic present: PASS / FAIL

**Manual fallback**（如 gh 失敗才填）:
\`\`\`
gh repo edit woodylin0920-bit/woody-harness --description "..." --add-topic claude-code ...
\`\`\`

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 2 (incl. archive)
e8e9b16 docs: README + CHANGELOG — refresh roadmap, expand features, link CONTRIBUTING, version badge
<archive-sha> chore: archive polish-r6-readme-github inbox prompt + result

**README verifications**:
- Phase 4 not unchecked: PASS
- T-1a in roadmap: PASS
- Statusline / Hooks / Slash commands / upgrade-existing / Memory portability mentioned: PASS
- CONTRIBUTING linked: PASS
- Latest release badge: PASS
- CHANGELOG [Unreleased] entry: PASS

**GitHub metadata**:
- gh repo edit succeeded: PASS
- Description no longer mentions omni-sense: PASS
- claude-code topic present: PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
