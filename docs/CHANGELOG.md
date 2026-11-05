# Changelog

Format: version — date — status — reason for existence — summary. Status uses the project labels.

## [Unreleased]
- 2026-11-05 — Documentation, project skills and local git repository created. No EA code changed after v3.1.

## v3.1 — 2026-11-05 — [UNTESTED: never compiled]
**Reason:** fix defects found when reviewing v3.0. These are listed in `assessment/2026-11-05_INITIAL_ASSESSMENT.md`, Table A.

Changes:
- MA and RSI read on correctly ordered closed bars.
- Closed-trade accounting drives the daily limit, a loss-streak pause with cooldown, and adaptive sizing.
- No array-out-of-range after exits.
- Partial closes round down; skipped when the position cannot be split.
- Broker TP moved to `FinalTP_RR`.
- Position ID and fill price used; state persisted; positions re-adopted after a restart.
- R-based profit lock.
- Loss cap reduces the lot or skips the trade.
- `MinBarsBetweenTrades` enforced; `InpExecTF` removed.
- Filling mode set by symbol; retcode checks; stop-level checks.

**Note:** this changes the effective entry strategy versus v3.0 (see assessment §2.3).

## v3.0 — supplied 2026-11-05 — baseline (frozen)
"Loss Control Edition", as supplied. Behaviour documented in the assessment, Deliverable 2.
