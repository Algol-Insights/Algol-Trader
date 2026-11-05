# Backtesting & Validation Protocol

Operational procedure: `.claude/skills/backtest-validation/SKILL.md`.
**A passing software test is not evidence of profitability. A profitable backtest is not evidence of an edge.**

## 1. Data
- **Primary:** the target broker's XAUUSD real ticks (MT5 "Every tick based on real ticks"). Bid and ask, broker timezone documented.
- **Independent check:** Dukascopy ticks (UTC). Compare statistics only; **never merge feeds**.
- Record per dataset: source, symbol name, date range, timezone/DST rule, tick count, gap report, checksum.

## 2. Splits (fixed before any research; dates finalised once broker tick availability is known)
| Set | Purpose | Rule |
|---|---|---|
| Development | Hypothesis exploration, parameter search | Free use |
| Validation | Model selection | Limited looks; every look logged |
| Holdout (unseen) | Final confirmation | **Single use.** If it fails, the candidate is rejected (no re-tuning). |
| Demo forward | Reality check | Live market, no parameter changes during the test |

Proposed default:
- Development: earliest available → 2022-12-31.
- Validation: 2023-01-01 → 2024-12-31.
- Holdout: 2025-01-01 → 2026-06-30.

Coverage must include the 2020 crash/recovery, the 2022 rate-hike cycle and the 2024–25 record-high rally.

## 3. Cost model (minimum)
- Real spreads from the tick data.
- Broker commission per lot.
- Swaps.
- Slippage: 0 in the base case; stress at +1 and +2 ticks per side.
- Latency stress: tester random delay mode.
- Spread stress: × 1.5 and × 2.

## 4. Required runs per candidate
1. Base backtest on dev (real ticks, real costs).
2. Validation-set run.
3. Walk-forward: rolling train/test (e.g. 12 months / 3 months), with parameters re-estimated only in train windows.
4. Parameter sensitivity: ±10/20% grid around the chosen values. Report the plateau, not the peak.
5. Monte Carlo: 10,000 trade-order reshuffles plus block bootstrap of returns → drawdown and terminal-wealth distributions.
6. Cost and latency stress (§3).
7. Regime breakdown: trend/range × volatility tercile; session; month/quarter/year; direction.
8. Overfitting statistics:
   - Deflated Sharpe Ratio, using the trial count from `STRATEGY_RESEARCH.md`;
   - PBO via CSCV;
   - purged/embargoed CV where labels overlap.
9. Holdout (once).

## 5. Metrics (report gross **and** net)
- Profit: net profit, gross profit, gross loss, profit factor, expected payoff/expectancy (money and R).
- Trade quality: win rate, average win/loss in R.
- Drawdown and return: max DD (money, %, duration), recovery factor, Sharpe, Sortino, Calmar, return volatility.
- Streaks and exposure: longest losing streak, exposure (% time in market, average open risk).
- Excursions: MFE/MAE distributions.
- Breakdowns: by month, quarter, year, session, regime, direction, strategy and timeframe.

## 6. Acceptance criteria [PROPOSED — to be ratified]
| Criterion | Threshold |
|---|---|
| OOS net expectancy | > 0, with bootstrap 95% CI lower bound > 0 |
| OOS trades | ≥ 200 (prefer ≥ 400) |
| OOS net profit factor | ≥ 1.25 |
| Walk-forward efficiency | ≥ 0.5; positive in ≥ 70% of windows |
| Deflated Sharpe probability | ≥ 0.95 |
| PBO | ≤ 0.20 |
| Cost stress (spread × 1.5 + 1 tick slippage per side) | PF ≥ 1.10, expectancy > 0 |
| ±20% parameter perturbation | PF ≥ 1.10 |
| Concentration | No month > 30% of net profit; top 5% of trades < 50% of net profit |
| MC 95th-percentile max DD | ≤ the profile's DD limit (`RISK_FRAMEWORK.md`) |
| Holdout | Pass on first and only use |

**Demo forward tolerance:**
- ≥ 3 months and ≥ 100 trades;
- slippage and spread within ±25% of the model;
- frequency within ±30%;
- expectancy within the backtest 95% CI;
- 0 duplicate orders;
- 0 limit breaches.

## 7. Reproducibility
Every result in `TEST_RESULTS.md` must include:
- git commit;
- EA build;
- config hash and `.set` file;
- tester `.ini`;
- data range and modelling mode;
- deposit/leverage;
- broker/server;
- the report file path.
