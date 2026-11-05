# Risk Framework  [PROPOSED — numbers require ratification by Algol Financia's risk owner]

These values are **starting proposals**, not evidence-derived targets. Before live use they must be checked with Monte Carlo against the chosen mandate (`BACKTESTING_PROTOCOL.md` §6).

## 1. Principles
1. Capital preservation ranks equal to profitability.
2. The deterministic risk engine in the EA has **veto authority** over every signal.
3. All limits are in **% of equity** (incl. floating P/L), never in fixed currency.
4. Limits persist across restarts. On start, they are rebuilt from broker deal history.
5. **Banned:** martingale, grid without hard caps, averaging down, loss-recovery multipliers, removing or widening a stop after entry.
6. Aggressive mode never bypasses the hard ceilings in §3.

## 2. Risk profiles (measurable differences)
| Parameter | Conservative | Moderate | Aggressive |
|---|---|---|---|
| Risk per trade (% equity at SL) | 0.25 | 0.50 | 1.00 |
| Max open risk, all positions (% equity) | 0.50 | 1.00 | 2.00 |
| Daily loss limit (% of start-of-day equity, incl. floating) | 1.0 | 2.0 | 3.0 |
| Weekly loss limit (% of start-of-week equity) | 2.0 | 4.0 | 6.0 |
| Drawdown from equity high-water mark → suspend and review | 6 | 10 | 15 |
| Consecutive losses → pause (then reduced size) | 3 | 4 | 5 |
| Size after drawdown > ½ of the DD limit | × 0.5 | × 0.5 | × 0.5 |
| Max entry cost (spread + commission) as fraction of R | 0.10 | 0.12 | 0.15 |

What these imply, by plain arithmetic:
- 20 consecutive full losses at 1% risk give 1 − 0.99²⁰ ≈ 18.2% drawdown.
- At 0.5% they give ≈ 9.5%.
- At 0.25% they give ≈ 4.9%.

## 3. Hard ceilings (all profiles; cannot be overridden by inputs)
- Risk per trade ≤ 1.0% of equity.
- Daily loss ≤ 3%.
- Drawdown from high-water mark ≤ 20% → **full stop, human review required to restart**.
- Every position carries a broker-side SL from entry.
- Max simultaneous positions on XAUUSD: 1 (Phase 1).
- If the minimum lot would exceed the per-trade risk limit → **skip the trade**. Never shrink the stop to fit.

## 4. Circuit breakers and suspensions
| Trigger | Action |
|---|---|
| Daily limit hit | No new entries until the next session day; manage open positions only |
| Weekly limit hit | No new entries until the next week; risk owner notified |
| DD from HWM ≥ profile limit | Suspend; human review; restart requires a logged decision |
| Kill switch (input or file flag) | Block entries; optional close-all; logged |
| Abnormal market (spread > p99 of trailing 30 days, ATR > p99, price gap > k·ATR) | Block entries until normal for N minutes |
| Data problem (stale ticks > X s, indicator copy failure) | Block entries |
| Rollover / daily break window, weekend close | Block entries; optional flat-before-weekend |
| High-impact event window (once validated by research) | Block entries in the validated window only |

## 5. Position sizing
- lot = (equity × risk%) ÷ (SL distance × money-per-price-unit-per-lot).
  - Money per price unit = `SYMBOL_TRADE_TICK_VALUE_LOSS` (fallback `TICK_VALUE`) ÷ `SYMBOL_TRADE_TICK_SIZE`.
- Round **down** to `VOLUME_STEP`. Reject the trade if the result is below `VOLUME_MIN` (do not round up).
- Check margin with `OrderCalcMargin` before sending; skip if free margin after the trade < a configured buffer.

## 6. Protection mechanisms — status
| Mechanism | Status | Evidence required before adoption |
|---|---|---|
| Equity daily/weekly/HWM limits | PROPOSED | Scenario tests (correctness) + Monte Carlo (calibration) |
| Loss-streak pause | UNTESTED (v3.1, $-based) | Runs test on outcomes; Monte Carlo with vs without |
| Adaptive size reduction after losses | UNTESTED (v3.1) | Must improve MC DD distribution without materially cutting expectancy |
| Break-even move | UNTESTED | Ablation: expectancy and payoff distribution |
| Early exit / time exit | UNTESTED | Ablation plus MFE analysis |
| Profit lock / trailing | UNTESTED | Ablation |

## 7. Governance
- Any limit change needs a `DECISIONS.md` entry with a Monte Carlo justification and risk-owner approval.
- Live and demo deployments record the config hash, EA build and git commit.
