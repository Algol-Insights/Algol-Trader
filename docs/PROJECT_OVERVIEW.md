# Project Overview — The Future Fund, Phase 1: XAUUSD

**Owner:** Algol Financia (subsidiary of Algol Insights)
**Phase:** 1 — XAUUSD strategy research, engineering, optimisation and validation
**Status (2026-11-05):** Audit complete. No strategy validated. No backtests run yet.

## Mission
Build a proprietary XAUUSD quantitative trading engine. The aim is measurable, repeatable and defensible net returns, with exceptional risk discipline. The system must earn its place in The Future Fund through evidence.

## Business context
From the Algol Insights Master Business Plan:
- §4.2 Algol Financia: brokerage (ZSE/VFEX), research and advisory, The Future Fund (proprietary, later third-party algorithmic fund), Diaspora Investment Platform.
- Fees: ~2% management fee and ~20% performance fee (§4.2, §11.3).
- SECZim Securities Dealer's Licence and Investment Management Licence ($500K net-asset requirement); the asset-manager licence is targeted for 2030 (§20.1, §25).
- Core weakness: the track record must be built from zero (§9.3).

Project decisions **not** in the business plan are recorded in `DECISIONS.md`: XAUUSD focus, MT5/MQL5 execution, offshore MT5 broker.

## Phase 1 success definition
1. A strategy that passes the acceptance criteria in `BACKTESTING_PROTOCOL.md`, out of sample, after realistic costs.
2. A risk engine that enforces `RISK_FRAMEWORK.md` limits independently of strategy logic.
3. Demo forward results consistent with the model.
4. Only then: controlled proprietary live trading, with an auditable, independently verifiable record.

## Phases (detail in the 2026-11-05 assessment, Deliverable 6)
| Phase | Name | Status |
|---|---|---|
| P0 | Foundations (GitHub, Windows MT5, compile) | **In progress** — GitHub done (M-1, 2026-11-05); **Windows MT5 + MetaEditor still needed** for M-2 |
| P1 | Instrumentation and baseline measurement | Not started |
| P2 | Data and research stack | Not started |
| P3 | Hypothesis research | Not started |
| P4 | Production engine (modular EA, risk engine) | Not started |
| P5 | Full validation | Not started |
| P6 | Demo forward test | Not started |
| P7 | Controlled proprietary live | Not started |

## Documents
`ARCHITECTURE.md` · `STRATEGY_RESEARCH.md` · `RISK_FRAMEWORK.md` · `BACKTESTING_PROTOCOL.md` · `CHANGELOG.md` · `KNOWN_ISSUES.md` · `TEST_RESULTS.md` · `DECISIONS.md` · `assessment/`
