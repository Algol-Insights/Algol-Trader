---
name: xauusd-quant-research
description: Use when investigating XAUUSD market behaviour, proposing or evaluating a trading strategy idea, comparing strategy families, or analysing gold data (sessions, volatility, regimes, events). Enforces hypothesis-first research with cost models and failure conditions before any EA code is written.
---

# XAUUSD Quantitative Research

## When to use
- A new strategy idea, filter or indicator is proposed.
- Analysing gold data: distributions, sessions, regimes, spreads, events.
- Deciding whether an observed pattern is worth testing.

## Procedure
1. **Check the register first.** Read `docs/STRATEGY_RESEARCH.md` and `docs/DECISIONS.md`. If the question was already answered or the idea already rejected, stop and cite it.
2. **Write the dossier** (template in `STRATEGY_RESEARCH.md`) *before* touching data:
   - Mechanism: *who* is on the other side and *why* the inefficiency persists. "It worked on the chart" is not a mechanism.
   - Where it should work and where it should fail (regime, session, event).
   - Objective, closed-bar rules. No discretionary terms ("strong", "clear") without a numeric definition.
3. **Cost model first.** Using broker data, compute median and p90 of spread plus commission as a fraction of the proposed R, by session. If the median cost exceeds 15% of R, redesign (higher timeframe or larger R) before testing.
4. **Stylized-fact checks** (do once per dataset; store in `STRATEGY_RESEARCH.md`):
   - [ ] Return distribution by timeframe (M1, M5, M15, H1, H4): fat tails, autocorrelation of returns and of |returns|.
   - [ ] Volatility and spread by hour (state server time **and** UTC; note the DST rule).
   - [ ] Daily-break and rollover behaviour; weekend gaps (size distribution in ATR).
   - [ ] Event windows (CPI, NFP, FOMC): volatility and spread from −30 to +60 min.
   - [ ] Trend persistence (variance ratio, Hurst-type estimate) per timeframe and regime.
   - [ ] Regime label stability (how often trend/range × volatility labels flip).
5. **Prototype on the development set only.** Vectorised (Python) with costs included from the first run. Log every trial in the multiple-testing table.
6. **Kill criteria.** Stop investigating when any of these hold:
   - net expectancy ≤ 0 on dev after costs;
   - the edge exists only in one year or one regime;
   - the result depends on one parameter value (no plateau);
   - fewer than 100 dev trades and no path to more.
7. **Promote** to `backtest-validation` only if the dossier is complete and the dev results pass step 6.

## Rules
- Do not adopt indicators because they are popular. Every component must carry its own hypothesis and ablation evidence.
- No look-ahead: features use only information available at the decision time (closed bars; the calendar *as published* at that time).
- Never merge broker and Dukascopy data. Compare statistics only.
- Label conclusions: `[TESTED]`, `[NEEDS DATA]`, or hypothesis.

## Acceptance (for leaving research)
- [ ] Dossier complete, including failure conditions and expected frequency
- [ ] Cost/R at median and p90 documented
- [ ] Dev expectancy > 0 after costs, on ≥ 100 trades, positive in ≥ 2 distinct regimes
- [ ] Parameter plateau shown (not a single best point)
- [ ] Trials logged
