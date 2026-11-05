# Strategy Research Register

Every strategy idea gets a dossier here **before** any code. Record rejected ideas too, with the evidence.
Procedure: `.claude/skills/xauusd-quant-research/SKILL.md`.

## Dossier template
```
### <ID> <Name>                         Status: PROPOSED | IN TEST | ACCEPTED | REJECTED
Hypothesis (why an edge might exist):
Market conditions where it should work:
Conditions where it should fail:
Entry / exit logic (objective, closed-bar):
Risk requirements:
Expected frequency (trades/week):
Cost sensitivity (cost as % of R at median spread):
Historical evidence (dev set):              [link to TEST_RESULTS entry]
Out-of-sample evidence (validation set):    [link]
Walk-forward / holdout:                     [link]
Implementation complexity:
Trials run so far (for DSR / multiple testing):
Decision + date + reason:
```

## Register

### S0 — EMA(9/21) M1 crossover with EMA(50) M5 filter (existing)        Status: IN TEST (baseline pending)
- **Variant S0-a (v3.0 actual):** reversed-order evaluation. In practice: buy when fast crosses *below* slow in an up-trend, on intrabar data. [CODE-VERIFIED]
- **Variant S0-b (v3.1):** confirmed crossover on closed bars. [UNTESTED]
- **Hypothesis:** short-term momentum persists in the direction of the ~4h trend for long enough to cover costs.
- **Prior concerns:** lag; M1 noise; costs up to 0.27R at entry under the current spread gate; no regime or session model.
- **Evidence:** none yet.
- **Next:** P1 baseline (assessment, Deliverable 8, M-5).

### S1 — Session range breakout (Asian range → London/NY)       Status: PROPOSED
### S2 — Trend-pullback continuation, M15/H1 with H4/D1 regime  Status: PROPOSED
### S3 — Low-volatility mean reversion to session VWAP/mean      Status: PROPOSED
### S4 — Volatility compression → expansion                      Status: PROPOSED
### S5 — Market-structure liquidity sweep (objective pivots)     Status: PROPOSED
### S6 — Event conditioning (CPI/NFP/FOMC) as filter/overlay     Status: PROPOSED
### S7 — Meta-labelling ML filter (only on a positive base)      Status: PROPOSED (deferred)

Hypotheses and failure modes for S1–S7 are in the assessment, Deliverable 4.2.

## Open research questions
- Q1: How do cost/ATR and noise/ATR change from M1 to M5 to M15 to H1 for our broker? This could redirect the project.
- Q2: How do spread and volatility profiles vary by hour (server time and UTC), including the daily break and rollover?
- Q3: How does behaviour differ around high-impact US releases (pre/post windows)?
- Q4: Does the regime label (trend/range × volatility) separate outcomes for S0?

## Multiple-testing log
Record every backtest configuration evaluated (ID, date, dataset, parameters). The count feeds the Deflated Sharpe Ratio.
| Trial ID | Date | Strategy/variant | Dataset | Params hash | Result link |
|---|---|---|---|---|---|
| — | — | — | — | — | — |
