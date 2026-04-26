# Smoke Testing

Mock-based unit test 不夠。Phase ship 前必跑 real-machine smoke。

## 為什麼

- Mock 證明邏輯正確，不證明硬體 / OS / 外部依賴行為正確
- 視障 / safety-critical 場景：silent fail 是 mock 看不到的
- pytest 綠 ≠ user 真機跑得起來

## Smoke vs unit test

| | unit test | smoke test |
|---|---|---|
| 跑在哪 | CI / pytest | 你的開發機 |
| 速度 | 秒級 | 分鐘級 |
| 自動化 | 100% | driver 自動，觀察手動 |
| 抓什麼 | 邏輯 bug | hardware / OS / dependency 行為 |
| 何時跑 | 每次 commit | phase ship 前 |

## 實作

每個專案有 scripts/smoke.sh（從 templates/scripts/smoke.sh 改）：

- driver 提示 user 在另一 terminal 跑某個命令
- 觀察 user-visible 行為（聽 / 看 / 感）
- user 回答 y / n
- 任一 ❌ → exit 1

## 實際案例：omni-sense 2026-04-27

4 個 smoke test：
- Test 1: announce_error 真的響（Funk.aiff + 中文 say）✅
- Test 2: q-key exit 乾淨無 traceback ✅
- Test 3: OCR injection guard（adversarial sign 真機驗）⏳
- Test 4: Ollama down → watchdog 出聲 ⏳

Test 3 是最關鍵 — 沒驗證之前不敢給視障者用。

## Anti-pattern

- 「mock test 都過了，smoke 一定也過」→ 不一定
- 「等 user 回報問題再修」→ user 不會再回來
- 「smoke 我心裡跑過了」→ 沒實機跑就是沒跑
