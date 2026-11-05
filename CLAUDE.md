# Algol Financia — XAUUSD Quantitative Trading System (Project Rules)

This repository holds Algol Financia's proprietary XAUUSD trading research and the MQL5 Expert Advisor.
Read `docs/PROJECT_OVERVIEW.md` first, then the doc relevant to the task.

## Non-negotiable rules
1. **XAUUSD only** in Phase 1. No multi-instrument features. Keep modules symbol-agnostic, but do not build for other symbols.
2. **Never fabricate.** No invented backtest results, metrics, compile results or test outcomes. If something was not run, say so.
3. **Label every claim** with one of: `[TESTED]`, `[UNTESTED]`, `[PROPOSED]`, `[REJECTED]`, `[NEEDS DATA]`, `[CODE-VERIFIED]`.
4. **Method for every change** (brief §15): problem → cause → measurable hypothesis → smallest change → compile → regression → controlled backtest → compare → document → accept or reject.
5. **Risk engine has veto authority.** A strategy never sizes its own trades. No martingale, grid, averaging down or loss-recovery multipliers.
6. **No order-sending outside the EA.** No connector, script or agent may call `order_send` on any live account. Research terminals use investor (read-only) passwords.
7. **No secrets** in code, configs, logs or commits.
8. **Units:** never hard-code pip, point, tick or contract assumptions. Use the broker's symbol spec; express distances in ATR, R or price units.
9. **Preserve known-good versions.** Never silently remove working functionality. Frozen versions live in `legacy/` (or git tags).
10. **Compile and test happen on Windows MT5.** This cloud container cannot compile MQL5. Say so explicitly when handing code over.

## Where things live
- `docs/assessment/` — dated assessments (the initial audit is 2026-11-05)
- `docs/DECISIONS.md` — decisions with date, reason, evidence (append-only)
- `docs/KNOWN_ISSUES.md` — open defects and weaknesses (IDs match the audit tables)
- `docs/TEST_RESULTS.md` — only real, reproducible results, with config hash and data range
- `.claude/skills/` — project skills: research, MQL5 engineering, validation, risk governance, release/audit

## Current state (update when it changes)
- Active EA: `mql5/Experts/AlgolGold/AlgolGold.mq5` (= v3.1, **[UNTESTED] — never compiled**).
- Frozen: `legacy/AlgoTraderGold_v3.0.mq5` (supplied baseline), `legacy/AlgoTraderGold_v3.1.mq5`.
- Plan M-1 → M-6 approved 2026-11-05 (DECISIONS D-008). M-1 done; next is M-2 (compile on Windows MT5).
- No backtests have been run in this project yet.
