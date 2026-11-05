# Architecture

## Current (as of 2026-11-05)
- **v3.0** (`legacy/AlgoTraderGold_v3.0.mq5`, frozen):
  - single-file procedural EA; global state;
  - `OnInit` / `OnDeinit` / `OnTick` only;
  - no persistence;
  - signal, risk and execution are intermixed in `CheckForSignals`.
- **v3.1** (`legacy/AlgoTraderGold_v3.1.mq5`, frozen; working copy at `mql5/Experts/AlgolGold/AlgolGold.mq5`):
  - same structure, plus closed-position accounting by polling;
  - state persisted in terminal global variables;
  - positions re-adopted after a restart;
  - **[UNTESTED]**.

A full walkthrough is in `assessment/2026-11-05_INITIAL_ASSESSMENT.md`, Deliverable 2.

## Target [PROPOSED]
Two layers.
- **Research (Python, offline)** never places orders.
- **Production (MQL5 EA)** is deterministic and runs without any external process.

The diagram and component table are in the assessment, Deliverable 5.

### Production modules (planned `mql5/Include/AlgolGold/`)
| Module | Responsibility | Status |
|---|---|---|
| `Config.mqh` | Input validation, risk profiles, config hash = strategy version | PROPOSED |
| `SymbolSpec.mqh` | Broker spec capture and logging (contract, tick size/value, digits, volume, stop/freeze levels, sessions) | PROPOSED |
| `MarketData.mqh` | Bars, indicators (series-ordered), spread statistics, data-quality checks | PROPOSED |
| `Regime.mqh` | Trend/range × volatility classification, plus an "abnormal" state | PROPOSED |
| `Strategy*.mqh` | Strategy interface → `SignalCandidate` | PROPOSED |
| `RiskEngine.mqh` | Pre-trade veto: equity limits, open risk, streaks, cost/R, sessions/news, margin, kill switch | PROPOSED |
| `Sizing.mqh` | Fixed-fractional of equity, round down, caps | PROPOSED (math exists in v3.1) |
| `Execution.mqh` | Idempotent send, retcodes, bounded retries, slippage capture | PROPOSED (partial in v3.1) |
| `PositionManager.mqh` | Switchable exit modules | PROPOSED (logic exists in v3.1) |
| `StateStore.mqh` | Crash-safe file state; rebuild from deal history | PROPOSED (GV-based in v3.1) |
| `Journal.mqh` | Per-trade and per-decision CSV audit trail | PROPOSED (M-3) |
| `Monitor.mqh` | Panel, heartbeat file, alerts | PROPOSED |

### Invariants (must hold in every version)
1. The risk engine can reject any signal. Strategies cannot size trades.
2. Every position has a broker-side SL from the moment it opens.
3. A restart never creates a duplicate position and never resets risk limits.
4. Every order and every rejection is journaled with a reason.
5. No component outside the EA sends orders.
