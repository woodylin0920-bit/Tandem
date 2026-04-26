# Phase Gating

每個 phase 必須過 gate 才能進下一 phase。否則累積 tech debt。

## 三個 gate

### Gate 1: Tests green

- pytest 全綠
- count 大於等於前 phase baseline（沒 regression）
- 新功能有 unit test cover

### Gate 2: SLO 達標

- 如果 phase 引入新延遲 / 吞吐 surface，要 benchmark
- 數字必須符合 README 宣傳值
- 沒達標 → 修或修改 README，不能默默 ship

### Gate 3: Commit clean push

- main 跟 origin 同步
- 沒 uncommitted changes
- 沒 untracked file 該 git add 的

## 工具

`/phase-gate` slash command 一次跑完三個。

## 例外

- Hotfix 緊急可跳 Gate 2，但 Gate 1+3 不能跳
- Doc-only commit 可跳 Gate 1+2，只跑 Gate 3

## Anti-pattern

- 「test 之後再寫」→ 之後不會寫
- 「SLO 數字差一點點，下個 phase 會解」→ 不會
- 「先 push 再說」→ 等等不會修
