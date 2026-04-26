# Issues Batch Template

ship 前盤點所有 P1/P2/Future 問題，用 gh issue create 一次開好。讓未來自己 + 協作者有 audit trail。

## 何時用

- Phase 完工 → codex audit → 修完 P0 → 不修的 P1+ 開 issues
- ship 前 → 盤點所有 known caveat → 開 issues + README 連結
- user 回報 → 不立即修 → 開 issue

## Issue 結構模板

````
**Severity**: P[0-2] / Future / Project

[1 sentence summary]

[Reproduction steps if applicable]

**Fix proposal**:
[Concrete fix, code patch if simple, or direction if exploratory]

**Related context**:
- Codex audit DATE
- Commits ABC1234
- Past discussion link
````

## 嚴重度規範

| 標籤 | 定義 | ship 行為 |
|---|---|---|
| P0 | user 會受傷 / 數據損毀 | block ship，立刻修 |
| P1 | user 體驗壞但能察覺 | ship 前修，或 issue 追蹤 |
| P2 | cosmetic / 開發者體驗 | issue 追蹤，看心情修 |
| Future | 真要做但等需求驗證 | issue 追蹤，不排程 |
| Project | 跨技術的專案層風險 | issue 追蹤 |

## 批次 gh issue create

````bash
gh issue create --title "P[N]: <terse problem statement>" --body "**Severity**: P[N].

[Description]

**Repro**: [...]

**Fix**: [...]

**Related**: codex audit YYYY-MM-DD, commit ABC1234"
````

連續開 N 個 → 記錄 URL → 回填 README「已知問題」表格。

## ship 後

每個 issue 修掉 → close 並引用修補 commit。

## Anti-pattern

- 「明天再寫 issue」→ 不會寫了
- 一個 issue 放 5 個 unrelated bug → 拆開
- issue body 只寫一行「修這個」→ 未來看不懂
