---
name: backtest-validation
description: Use when planning, running, analysing or reporting any backtest, optimisation, walk-forward, Monte Carlo or robustness test of the XAUUSD system, or when judging whether a result is statistically credible. Enforces data splits, cost realism, overfitting controls and the project acceptance criteria.
---

# Backtesting Integrity and Statistical Validation

Full protocol: `docs/BACKTESTING_PROTOCOL.md`. This skill is the operational checklist.

## Before any run
- [ ] The hypothesis and expected direction of the effect are written down (`STRATEGY_RESEARCH.md`).
- [ ] The dataset is identified (source, range, timezone); the holdout is untouched.
- [ ] The run is logged in the multiple-testing table (count every configuration, including failed ones).
- [ ] Tester settings: "Every tick based on real ticks"; broker commission; real spreads; random delay for latency stress runs.
- [ ] Reproducibility fields prepared: commit, build, `.set`, `.ini`, deposit, leverage, server.

## Analysis steps
1. **Reconcile** the EA journal against the tester deal list (counts and P/L to the cent). Stop if they differ.
2. Compute gross and net metrics (`BACKTESTING_PROTOCOL.md` §5) in money **and** in R.
3. **Uncertainty:** bootstrap a 95% CI on expectancy (block bootstrap if returns are autocorrelated). A point estimate alone is never a conclusion.
4. **Attribution:** per exit reason, per session, per regime, per direction. Identify where the P/L actually comes from.
5. **Robustness:**
   - parameter grid ±10/20% (report the surface);
   - cost stress (spread × 1.5/2, +1/+2 ticks slippage);
   - Monte Carlo (10,000 reshuffles) → drawdown distribution.
6. **Overfitting:**
   - Deflated Sharpe, using the logged trial count;
   - PBO via CSCV when ≥ 10 configurations were compared;
   - purged k-fold with embargo when labels or holding periods overlap.
7. **Walk-forward:** rolling windows; parameters re-estimated in-sample only; report efficiency and the share of positive windows.
8. **Holdout:** only after every other criterion passes; run once; record the result whatever it is.

## Red flags (any one → investigate before reporting)
- PF > 3 or win rate > 75% on intraday gold (likely bug, leakage or unrealistic fills).
- The result collapses with +1 tick of slippage.
- A large share of profit comes from a handful of trades or a single month.
- In-sample is much better than out-of-sample (walk-forward efficiency < 0.3).
- Performance depends on bar-open/close modelling but not on real ticks.
- Trades at the daily break, the weekend open or exactly at news releases dominate P/L.

## Reporting rules
- Write to `docs/TEST_RESULTS.md` using the template; link from the decision.
- Report failures as prominently as successes; rejected strategies go in `STRATEGY_RESEARCH.md`.
- Never write "profitable" without "net of costs, OOS, with CI".

## Acceptance
Use the table in `BACKTESTING_PROTOCOL.md` §6. Any failed criterion means the candidate stays in research.
