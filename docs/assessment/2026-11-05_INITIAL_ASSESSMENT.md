# Algol Financia — XAUUSD Quantitative Trading System
## Phase 1 Initial Assessment (Deliverables 1–9)

**Date:** 2026-11-05
**Scope:** XAUUSD only
**Prepared for:** Algol Financia management

### Evidence status legend (used throughout)

| Label | Meaning |
|---|---|
| **[TESTED]** | Implemented and tested, with evidence on file |
| **[UNTESTED]** | Implemented but not compiled or tested |
| **[PROPOSED]** | Proposed, not implemented |
| **[REJECTED]** | Tested and rejected |
| **[NEEDS DATA]** | Cannot be established without data or infrastructure we do not yet have |
| **[CODE-VERIFIED]** | Established by reading source code (and, where cited, official MQL5 documentation). This is *not* a performance claim. |

### What this assessment is based on — and what it is not

| Material | Status |
|---|---|
| `AlgoTraderGold_v3.0.mq5` (983 lines, supplied in conversation) | Read in full. Treated as the version behind the behaviour you observed. |
| `AlgoTraderGold_v3.1.mq5` (1,442 lines) | Written by Claude earlier in this session to fix defects in v3.0. **[UNTESTED]** — never compiled. |
| Algol Insights Master Business Plan (.docx, Parts 1–3) | Read §1, 2, 4.2, 4.9, 7, 8.2, 9.3, 11.3, 12.4, 18, 20, 21, 22, 23, 25 |
| Earlier EA versions (v1/v2), backtest reports, optimisation results, broker specifications, tick data, live/demo trade history | **Not available in this session.** |
| Private GitHub repo `Algol-Insights/Algol-Trader` (last push 2026-11-05) | Exists on your account; attaching it to this session was **blocked by a permission check**. It may contain earlier versions or results; it has *not* been inspected. |
| Compilation, Strategy Tester runs, any quantitative measurement | **None performed.** No MetaTrader 5 / MetaEditor is available in this environment (see Deliverable 9). |

**Consequence:** every statement below about profitability, edge, or the effect of a rule is a **hypothesis** until tested. Statements about what the code *does* are code-verified.

---

## DELIVERABLE 1 — Project and Business Understanding

### 1.1 Established in the business plan

| Topic | What the plan says | Ref |
|---|---|---|
| Algol Insights | Zimbabwe-headquartered technology and financial-services holding company, 100% founder-owned. One technical core (data science, cybersecurity, software) deployed across subsidiaries. | §1.1, §2.2 |
| Algol Financia | "Zimbabwe's first quantitative, technology-driven brokerage and fund management business". Products: online brokerage (ZSE/VFEX), research and advisory, **The Future Fund** ("proprietary and later third-party algorithmic hedge fund"), and the Diaspora Investment Platform. | §4.2 |
| Revenue model | Brokerage commissions and account fees; **~2% AUM management fee, ~20% performance fee** on the fund | §4.2, §11.3 |
| Fund clients | HNWIs and institutions | §4.2, §7 |
| Planned tech stack | Python (QuantConnect/Backtrader), MATLAB/Python risk libraries, KYC/AML software, encrypted client platform | §4.2 |
| Positioning | First mover in local quantitative fund management; SECZim compliance as a trust signal in a market scarred by unlicensed schemes | §4.2, §8.2 |
| Stated weaknesses | $500K asset-manager capital requirement; **"a track record must be built essentially from zero"** | §9.3 |
| Licensing | SECZim Securities Dealer's Licence (~$12–15K incl. $10K minimum net capital). SECZim Investment Management (Asset Manager) Licence (~$510–520K incl. $500K net-asset requirement). | §20.1 |
| Funding and timing | Seed round ~$600K (late 2026/2027), led by the dealer licence. Asset-manager licence pursued in **2030 (Year 5)**. Growth capital is case-by-case. | §21, §25 |
| Diaspora platform | VFEX equity access, property-backed and SME lending pools. Management/performance fees only once the pooled-fund layer is licensed. | §12.4 |
| Enterprise risk | SECZim licensing delay or denial rated Medium likelihood / High impact; fallback is an Introducing Broker partnership. Currency volatility rated High/High. | §22 |
| Technology governance | Git/GitHub, MFA, network segmentation, backups/DR | §18 |
| Financial figures | All labelled "illustrative planning assumptions", not audited | §20 preamble |

### 1.2 Not in the business plan — decisions this project is making

The business plan does **not** mention gold, XAUUSD, CFDs, forex, MetaTrader or MQL5. The Financia products it describes are oriented towards **ZSE/VFEX equities**. The following are therefore project decisions. They are logged in `docs/DECISIONS.md` so they have an owner and a rationale:

| ID | Decision | Implication to manage |
|---|---|---|
| D-001 | XAUUSD is the exclusive Phase 1 instrument | Single-instrument concentration. Gold is highly sensitive to US macro data and Fed events. |
| D-002 | MetaTrader 5 / MQL5 is the execution platform (the plan names QuantConnect/Backtrader) | The research layer stays in Python, consistent with the plan. Production execution is MQL5. |
| D-003 | Trading through an MT5 broker, where XAUUSD is normally an OTC contract (CFD or spot) with the broker as counterparty | Broker-specific prices and costs; counterparty risk. Likely an offshore account, which raises exchange-control and licensing questions (see Deliverable 6, Governance track). |

My reading of why gold first makes sense — **my inference, not stated in the plan**:
- Deep liquidity across ~23 hours a day, 5 days a week.
- USD-denominated, consistent with the plan's preference for hard-currency exposure.
- One instrument concentrates scarce research capacity.
- There is an existing code base.

Counterpoints:
- Pronounced event risk (CPI, NFP, FOMC).
- Regime shifts. The 2024–2025 sustained rally to successive record highs is very different from earlier range-bound years.
- Retail CFD costs.

### 1.3 How the system fits the business strategy

1. **The track record is the asset.** The plan identifies the lack of a track record as Financia's core weakness (§9.3). A backtest is not a track record. Phase 1 therefore has two outputs:
   - a strategy whose edge survives out-of-sample validation;
   - from the first live proprietary trade onward, an **auditable** record: broker statements reconciled to the EA's own trade journal, which a third party can verify.
2. **Proprietary capital only, for years.** Under the plan, third-party capital needs the Investment Management licence (targeted 2030). Until then the system trades Algol's own capital. It should be designed so that account-level mandates, segregation and investor reporting *can* be added — but they should not be built now.
3. **Fees raise the bar.** With 2/20 fees, for example, an investor netting 10% needs roughly 14.5% gross. This is illustrative: it assumes the performance fee is charged after the management fee, with no hurdle. The strategy's *net, risk-adjusted* return must clear that comfortably, after realistic costs.
4. **Reputation is asymmetric.** The plan's own positioning against unlicensed schemes means one badly governed drawdown would hurt the whole group. That justifies conservative risk defaults and an independent audit trail from day one.

---

## DELIVERABLE 2 — Existing System Audit (how the robot actually works)

### 2.1 Inventory and dependencies

| Item | v3.0 (supplied) | v3.1 (session fix) |
|---|---|---|
| Lines / functions | 983 / 32 | 1,442 / 60 |
| Inputs (numeric) | 52 (33) | 55 (37) |
| Event handlers | `OnInit`, `OnDeinit`, `OnTick` | Same (closed positions are detected by polling each tick) |
| External dependencies | MQL5 standard library: `Trade/Trade.mqh` (CTrade), `Trade/PositionInfo.mqh` (CPositionInfo) | Same |
| Indicators | EMA(9) and EMA(21) on M1; EMA(50) on M5; ATR(14) on M5; RSI(14) on M1 | Same |
| Persistence | None (all state in memory) | Terminal global variables |
| Files / DLL / web | None | None |
| Build status | Never compiled by us | **Never compiled** |

### 2.2 Architecture (v3.0)

v3.0 is a single procedural file with global state. On each tick, `OnTick` runs four steps in order:

1. `ResetDailyLossIfNeeded` — resets a daily loss counter. **The counter is never incremented anywhere.**
2. `ManageOpenPositions` — runs early exit, time exit, break-even, scaled take-profit and trailing for each tracked position.
3. `CheckForSignals` — applies the loss gates (inert), the one-position rule, the bar-close gate, the price-action filter, the MA cross with HTF filter, the spread/volatility/RSI filters, the loss cap, and then sends the order.
4. `UpdateInfoPanel` — draws the chart comment.

There is no separation between signal, risk, execution and reporting. The risk logic sits inside the signal function.

### 2.3 Entry logic — intended versus actual

**Intended**, from the names and comments: on each new M1 bar, **buy** when EMA9 crosses *above* EMA21 and Bid is above EMA50 on M5. Sell is the mirror. The filters are:
- signal-bar body at least 40% of its range;
- RSI(14, M1) in [45, 70] for buys and [30, 55] for sells;
- spread at most 40 points and at most 0.4 × ATR(14, M5);
- ATR at least 0.0005.

**Actual behaviour of v3.0 — [CODE-VERIFIED]:**
- `GetMAValues` (v3.0 lines 837–849) copies two values into a fixed-size array. The official MQL5 documentation states that copied data is "always physically placed in chronological order… element at index 0 will be the oldest" (MQL5 Book, *Overview of Copy functions*). So `f[0]` is the **closed** bar and `f[1]` is the **forming** bar.
- The code assigns `f[0]` to `fastCur` and `f[1]` to `fastPrev`. The crossover test at line 577 is therefore **evaluated in reverse time order**:
  - **"crossUp" fires when fast > slow on the closed bar and fast < slow on the forming bar — a *bearish* cross at the bar boundary.**
  - Combined with the HTF filter, **v3.0 buys at the moment short-term momentum turns *down* inside an up-trend**, and sells at the moment it turns *up* inside a down-trend.
- The test runs on the **first tick of the new bar** and uses the forming bar's values. The RSI filter does the same (line 812).

**Interpretation:** v3.0 is in practice an *unconfirmed counter-momentum pullback entry*. This is a direct code-level explanation for your observation that "trades enter too early, before sufficient confirmation". It is **not yet a measured explanation**; the Phase 1 baseline test is designed to confirm or reject it.

**Consequence for v3.1:** correcting the order turns v3.1 into a *different strategy* — trend continuation on a confirmed crossover of closed bars. **Neither variant has any evidence of an edge.** Any historical results from v3.0 say nothing about v3.1.

### 2.4 Exit logic (v3.0 actual, default inputs)

| Order | Rule | What actually happens |
|---|---|---|
| Broker | SL = entry ∓ 1.5 × ATR(14, M5); TP = entry ± 2R | Distances are measured from the **quoted** price, not the fill |
| 1 | Early exit | Within 5 min, close if R ≤ −0.5 |
| 2 | Time exit | After 20 min, close if R < +0.3 |
| 3 | Break-even | At R ≥ 0.8, SL moves to entry. The "+10 pip" lock can only run on the *same tick* (the function returns early once BE is set), and it is actually 10 *points*. |
| 4 | Scaled TP | At R ≥ 1.0, close 30% — **with 0.01 lot, 0.003 rounds *up* to the 0.01 minimum, so the whole position closes**. At R ≥ 2.0, close part of the remainder. |
| 5 | Trailing | Only after TP2, which the broker TP at 2R normally pre-empts. **Unreachable.** |

**Effective payoff profile with the defaults (0.01 lot):**
- maximum win **+1R** (TP1 closes everything);
- break-even scratches ≈ 0R minus costs;
- time exits anywhere in (−1R, +0.3R);
- early exits ≈ −0.5R plus slippage;
- full stops −1R.

With 0.02 lot or more, TP1 takes 30% at 1R and the broker TP closes the rest at 2R. TP2 and trailing still never act.

### 2.5 Position sizing

- **Default:** fixed 0.01 lot.
- **Risk mode:** lot = balance × RiskPerTrade% ÷ (SL distance × money per point per lot). The money per point comes from the broker's `SYMBOL_TRADE_TICK_VALUE` and `SYMBOL_TRADE_TICK_SIZE`. This is the **correct general approach — keep it**.
- The adaptive multiplier stays at 1.0 forever, because nothing updates it.

### 2.6 Risk management (as coded)

| Control | Status in v3.0 |
|---|---|
| Per-trade cap ($20) | Shrinks the **stop distance**, not the lot. In risk mode it is **circular**: the lot is recomputed from the shorter stop, so the money at risk is unchanged and the stop sits deeper in the noise. |
| Daily limit ($50) | **Inert** — `dailyLoss` is never incremented |
| Consecutive-loss pause | **Inert** — `consecutiveLosses` is never incremented |
| Adaptive sizing | **Inert** |
| One position per symbol | Works |
| Equity / weekly / drawdown limits, kill switch, margin check | **Absent** |

### 2.7 Execution

- `CTrade` market orders with the default deviation and the default filling mode, which is FOK. **Some brokers reject FOK on XAUUSD**; the EA would then silently never trade.
- Only the boolean return value is checked. There is no retcode analysis, no retry or backoff, and no stop-level or freeze-level validation.
- A failed SL modification is retried on every tick.
- The tracker records the quoted entry price and the order ticket.

### 2.8 Configuration

52 inputs, 33 of them numeric, none documented or derived. Several are denominated in **points**, so their meaning changes with the broker's quote digits: `MaxSpreadPips`, `SL_Points`, `TrailStartPoints`, `BE_LockProfit`. Comments such as "REDUCED from 2.0" and "TIGHTER from 0.5" imply earlier tuning whose evidence we do not have.

### 2.9 What v3.1 changed — **[UNTESTED]**

1. Corrected MA/RSI bar ordering, evaluated on closed bars.
2. Working loss accounting: each closed position's net P/L (including commission and swap) drives the daily limit, a loss-streak pause with cooldown, and adaptive sizing.
3. No array-out-of-range.
4. Partial closes never close the full position.
5. Broker TP moved beyond TP2 (`FinalTP_RR`).
6. Trackers keyed by position ID, using the fill price, persisted and re-adopted after a restart.
7. Profit lock expressed in R.
8. Loss cap reduces the lot, or skips the trade.
9. `MinBarsBetweenTrades` enforced.
10. Filling mode set by symbol.
11. Retcode checks.
12. Stop-level checks.

**It has never been compiled.** Its remaining gaps are listed in Deliverable 3, Table B.

---

## DELIVERABLE 3 — Weakness and Failure Analysis

Severity scale:
- **Critical** — can cause large or unbounded loss, or invalidates all results.
- **High** — material loss or governance failure is likely.
- **Medium** — degrades results or reliability.
- **Low** — cosmetic or minor.

### Table A — Confirmed defects in v3.0 [CODE-VERIFIED]

| # | Identified issue | Evidence | Severity | Financial consequence | Root cause | Recommended solution | Validation method | v3.1 |
|---|---|---|---|---|---|---|---|---|
| A1 | MA crossover evaluated in reverse time order: the EA buys on bearish crosses in up-trends | Lines 837–849, 577; MQL5 Book on Copy-function ordering | Critical | Enters against short-term momentum without confirmation. Any v3.0 results describe a different strategy from the one intended. | Fixed-size arrays filled oldest-first, then indexed as newest-first | Series-ordered dynamic arrays; evaluate closed bars 1/2 | Indicator-reading unit script, plus a tester trace comparing cross times with chart EMAs | Fix [UNTESTED] |
| A2 | Signal and RSI use forming-bar values even when `RequireBarClose` is true | Lines 838–842, 812 | High | Intrabar signals; different results in tick versus OHLC testing | Start position 0 used in `CopyBuffer` | Shift 1 when bar-close mode is on | Same as A1 | Fix [UNTESTED] |
| A3 | Daily loss limit, consecutive-loss pause and adaptive sizing are inert | `dailyLoss` and `consecutiveLosses` are never incremented (only lines 262, 548) | Critical | The described capital protections do not exist; unlimited daily loss frequency | Missing closed-trade accounting | Account for closed positions from deal history | Scenario test: force N losses and assert the pause; reconcile against history | Fix [UNTESTED] |
| A4 | Tracker removed mid-loop, then indexed again: "array out of range", which stops the EA | Lines 340/379, followed by later uses of `trackerIndex` | High | After an early or time exit the EA halts. Open positions keep only the broker SL/TP, and no new risk controls run. | Index invalidated by removal | Never remove inside the management loop; prune in a separate pass | Tester run with frequent early exits; zero runtime errors | Fix [UNTESTED] |
| A5 | TP1 "partial" closes 100% at minimum lot | Lines 462–466 with `NormalizeVolume` (903) clamping up to the minimum | High | Wins capped at +1R. Payoff becomes symmetric or worse after costs. | Rounding up to the minimum volume | Round down; skip the partial if it cannot be split | Journal: volume closed at TP1 never equals the full volume | Fix [UNTESTED] |
| A6 | Broker TP at 2R pre-empts TP2 and the trailing stop | Lines 645/677; trailing gated on `tp2Hit` (504) | Medium | The runner logic never runs; the strategy's tail is truncated | Server TP equals the EA TP2 level | Server TP beyond TP2 (or none) when trailing | Journal shows TP2 and trail events | Fix [UNTESTED] |
| A7 | Profit lock only on the tick BE is set; denominated in points | Line 391 early return; line 425 | Low | The intended protection rarely applies | Control-flow bug; unit confusion | R-based lock, checked every tick | Journal SL-change events | Fix [UNTESTED] |
| A8 | Loss cap shrinks the SL; in risk mode it is circular | Lines 600–602; lot recomputed at 648/680 | High (risk mode) | Stop pushed into noise with the money at risk unchanged → more stop-outs. With the cap binding at a $10K balance, the SL shrinks to ~20% of the intended distance. | Cap applied to the wrong variable | Cap the lot; skip the trade if the minimum lot exceeds the cap | Unit test of the sizing function over a grid of balances and SLs | Fix [UNTESTED] |
| A9 | Trackers held in memory only, never pruned after SL/TP | `posTracker[]` with no persistence; removal only after EA closes | High | After a restart or recompile, positions are unmanaged: no early/time exit, BE or partials | No state recovery | Persist and re-adopt positions | Restart test in demo: kill the terminal mid-trade and verify management resumes | Fix [UNTESTED] |
| A10 | Entry price from the quote, not the fill; tracker keyed by order ticket | Lines 643/659 | Medium | R computed off by the slippage | Not reading the position after the fill | Read `POSITION_PRICE_OPEN`; use the position ID | Journal: slippage field; R recomputed from the fill | Fix [UNTESTED] |
| A11 | `MinBarsBetweenTrades` and `InpExecTF` unused | Grep: declared, never referenced | Medium | Immediate re-entry after a stop-out | Dead inputs | Enforce or remove | Journal: minimum inter-trade gap | Fix [UNTESTED] |
| A12 | Default FOK filling; only the boolean result checked | Lines 654/686 | Medium | Orders silently rejected at some brokers; errors invisible | CTrade defaults | Fill mode by symbol; check retcodes | Demo log of retcodes | Fix [UNTESTED] |
| A13 | `MinATRForEntry = 0.0005` meaningless for gold | Line 804 | Low | The volatility filter never filters | Units | Price units, or ATR-percentile based | Stats on how many signals are rejected | Partly fixed (price units) |
| A14 | Pause message would print every tick | Line 551 | Low | Log flooding | No state latch | Latch | Log inspection | Fix [UNTESTED] |

### Table B — Gaps that remain in v3.1 (self-audit) [CODE-VERIFIED]

| # | Identified issue | Evidence | Severity | Financial consequence | Root cause | Recommended solution | Validation method |
|---|---|---|---|---|---|---|---|
| B1 | v3.1 never compiled | No MetaEditor available | Critical | Unknown — it may not build or run | Environment | Compile on Windows MT5; fix errors | Clean compile log (0 errors, 0 warnings) |
| B2 | Point-denominated inputs: `MaxSpreadPips` (40), `SL_Points` (300), `TrailStartPoints` (150) | Inputs section | High | On a 2-digit quote, 40 points = $0.40; on a 3-digit quote = $0.04, which **blocks nearly every trade**. On other brokers the meaning silently changes. | Units tied to `_Digits` | Express as a fraction of ATR or R, or in price units; log the broker spec at start | Run on 2- and 3-digit symbols; compare filter rejection rates |
| B3 | Absolute-currency limits ($20 per trade, $50 per day) | Inputs | High | Meaningless at fund scale; too loose on small accounts | Fixed money values | % of equity, by risk profile | Monte Carlo of the limit versus the mandate |
| B4 | Daily limit is realized-only, using server midnight; no weekly limit, drawdown-from-high-water-mark breaker, or open-risk limit | `OnPositionClosed` | High | Floating losses and multi-day decline are uncontrolled | Partial risk model | Equity-based risk engine with veto authority | Stress scenarios in the tester; journal audit |
| B5 | No margin check | No `OrderCalcMargin` | Medium | Rejected orders or stop-outs on small accounts | Missing check | Pre-trade margin check | Tester run with a small deposit |
| B6 | No freeze-level, trade-mode or session check; no daily-break or weekend handling | Absent | High | Gap through the SL at the daily reopen or Monday open; spread spikes at rollover | Missing session model | Session calendar with blackouts and an optional flat-before-weekend rule | Event study of rollover spreads; tester across weekends |
| B7 | No kill switch or emergency close-all | Absent | High | No controlled shutdown during an incident | Missing governance control | Kill-switch input plus file flag; close-all procedure | Drill in demo |
| B8 | No structured audit journal; broker-side exits have no recorded exit reason; state kept in user-editable global variables | Print logs only | High | No defensible track record; reconciliation impossible | Missing audit layer | CSV/SQLite trade and decision journal with hashes | Reconcile journal to broker history to the cent |
| B9 | Positions closed while the EA is offline are missed in streak and daily P/L | Polling design | Medium | Loss controls under-count | In-session accounting | Rebuild from deal history at start | Restart test |
| B10 | No slippage measurement or limit | Absent | Medium | Cost drift undetected | Missing metric | Record requested vs filled; alert on drift | Demo slippage report |
| B11 | Several exit rules interact (early, time, BE, TP1, TP2, trail) with no evidence for any of them | Design | High (expectancy) | See C3/C4 | Untested design choices | Ablation study per module | Tester matrix |

### Table C — Potential weaknesses requiring testing (hypotheses) [NEEDS DATA]

| # | Hypothesis | Basis | Severity if true | Test |
|---|---|---|---|---|
| C1 | An M1 EMA(9/21) cross has **no positive net expectancy** on XAUUSD after costs | Lagging, widely used signal on the noisiest timeframe; costs large relative to M1 moves | Critical | Baseline on real ticks with real costs; bootstrap CI on expectancy |
| C2 | The spread filter admits trades where **entry cost reaches 0.27R** | Arithmetic: spread allowed up to 0.4×ATR while R = 1.5×ATR, so 0.4/1.5 = 0.267R | High | Distribution of spread/R at entry from the journal |
| C3 | Early exit at −0.5R within 5 min is triggered mostly by **noise plus spread** (with entry cost up to 0.27R, only ~0.23R of adverse price move is needed) | Arithmetic plus M1 noise | High | Ablation on/off; MFE of early-exited trades had they been held |
| C4 | The overlapping exits (BE at 0.8R *before* TP1 at 1R; the 20-min time exit) **truncate winners while losers run to −1R**. This is the most likely mechanism behind "several wins wiped out by one loss". | Payoff analysis in §2.4 | High | MFE/MAE analysis; payoff distribution; ablation |
| C5 | Price versus EMA50 on M5 (~4 hours) is too short to define a trend regime and flips constantly in ranges | Design | Medium | Signal outcomes by regime label |
| C6 | Performance differs strongly by session (Asian vs London vs New York) and around US data releases | Known stylized behaviour of gold, unverified for our broker | Medium | Statistics by hour and event window |
| C7 | 33 numeric parameters with no derivation → high overfitting risk in any optimisation | Count | High | Parameter-stability maps; PBO |
| C8 | "Halve the lot after a loss, reset after one win" has no expected benefit for a strategy without serial loss dependence | Statistical reasoning | Low/Medium | Runs test on trade outcomes; Monte Carlo with and without |

### Table D — Assumptions in the code without supporting evidence

| Assumption (from code or comments) | Status |
|---|---|
| "Smaller losses, better protection, same frequency" (EA description) | No evidence; the protections were inert (A3) |
| 1.5×ATR is better than 2.0×ATR ("REDUCED from 2.0") | No evidence on file |
| Spread ≤ 0.4×ATR ("TIGHTER from 0.5") is adequate | Contradicted arithmetically by C2 |
| BE at 0.8R, early exit at −0.5R/5 min, time exit at 20 min/0.3R improve results | No evidence |
| EMA 9/21/50 and RSI 45/70/30 are suitable for gold M1 | Generic retail defaults; no derivation |
| A body/range ratio ≥ 0.4 marks a quality bar | No evidence |

### Table E — Financial risks that could cause significant losses (ranked)

1. **Deploying any version without evidence of an edge.** A negative-expectancy M1 system loses steadily, and high trade frequency makes the loss compound faster.
2. **v3.0 in risk-based sizing mode.** The circular loss cap (A8) means larger lots with tighter stops. On fast markets, slippage on tight stops pushes losses beyond the intended amount.
3. **Unmanaged positions after a crash or restart** (v3.0: A4, A9). The protections the operators believe are active are not.
4. **Gap risk** at the daily trading break, weekends and high-impact releases, with no controls (B6).
5. **Counterparty and regulatory exposure** of an offshore CFD account. This is outside the code but material (Deliverable 6, Governance track).
6. **No auditable record** (B8). Even a profitable period could not be demonstrated credibly to investors.
7. **Overfitting during optimisation** (C7), which produces false confidence and the capital allocation that follows from it.

### 3.1 Keep, improve, replace

**Worth preserving:**
- ATR-scaled stops (volatility normalisation).
- Sizing from the broker's tick value and tick size.
- The one-position-per-symbol rule.
- The spread-filter *concept*, re-denominated as cost/R.
- The exit concepts — but as independently switchable, testable modules.
- v3.1's position re-adoption and persistence approach.
- The input grouping and on-chart panel.

**Requiring redesign:**
- The signal engine (no evidence).
- The risk engine (must be equity-based with veto authority).
- The exit stack (fewer, evidence-based rules).
- State and audit (file journal).
- The execution layer (margin, levels, sessions, retries, slippage).

---

## DELIVERABLE 4 — Quantitative Strategy Assessment

### 4.1 The existing strategy

The EMA(9/21) crossover on M1 with an EMA(50, M5) direction filter, RSI band, bar-body filter and spread/volatility filters **implicitly assumes** that *short-term momentum on 1-minute gold bars persists long enough, in the direction of the ~4-hour trend, to cover costs and pay more than the stop*.

| Strengths | Weaknesses |
|---|---|
| Simple and deterministic; few moving parts in the signal itself | Crossovers lag; on M1 they are dominated by microstructure noise |
| Volatility-normalised stops | No regime model: whipsaws in ranges are unavoidable |
| Liquid instrument with continuous pricing | Costs (spread plus commission) are a large fraction of typical M1 moves |
| Broker-aware sizing (risk mode) | No session or event awareness |
| | The exit stack truncates the right tail (C4) |
| | Many free parameters; no documented derivation |

**Why an edge *might* exist (hypothesis):**
- Time-series momentum in commodities is documented at **monthly** horizons (Moskowitz, Ooi & Pedersen, 2012, *Journal of Financial Economics*).
- Intraday, gold volatility clusters around the London and New York opens and US data releases, when directional moves can persist.
- **Neither result establishes momentum at a 1-minute horizon.**

**Why it might disappear or never have existed:**
- M1 crossover signals are among the most widely used retail signals.
- Their information content at this horizon is low compared with costs.
- Parameter values tuned on one price level or regime do not transfer. Gold's price level and volatility changed substantially over 2024–2026.

**Assessment:** the evidence is **insufficient to keep the current signal as the core strategy**. It should be measured (Phase 1) and is more likely than not to be **rejected or demoted** to a component — for example, M1 entry timing beneath a higher-timeframe setup. This is a forecast to be tested, not a verdict.

### 4.2 Strategy families worth investigating — all [PROPOSED], none tested

The order reflects a judgement about prior plausibility for gold, cost-robustness, and implementation complexity.

| # | Family | Hypothesis (why an edge might exist) | Should work when | Should fail when | Cost sensitivity | Complexity |
|---|---|---|---|---|---|---|
| S1 | **Session range breakout** (Asian range → London/NY expansion, confirmed on a closed bar) | Participation and liquidity jump at the London and NY opens; overnight ranges concentrate resting orders | Trending or expansion days; scheduled catalysts | Range days, false breaks, post-news reversals | Medium (fewer, larger trades) | Low–Medium |
| S2 | **Trend-pullback continuation on M15/H1** with an H4/D1 regime filter; entry after the pullback shows resumption | Gold trends persist at multi-hour/day horizons; buying confirmed pullbacks improves entry price | Established trends | Trend exhaustion, regime turns | Low–Medium | Medium |
| S3 | **Volatility-regime mean reversion** to the session VWAP or mean in a low-volatility, range regime | Inventory and liquidity provision pull price back to fair value in quiet regimes | Low-volatility, range-bound sessions | Trend days; news | High (smaller targets) | Medium |
| S4 | **Volatility compression → expansion** (NR-n bars, Bollinger bandwidth percentile) | Volatility mean-reverts; compressions precede expansions | Ahead of catalysts | Persistent low volatility | Medium | Low |
| S5 | **Market-structure sweeps** (swing high/low taken, then a close back inside) with algorithmic pivot definitions | Stop-runs beyond obvious levels exhaust order flow | Liquid sessions | Strong trends through levels | Medium | Medium–High (definitions must be objective) |
| S6 | **Event conditioning** (CPI, NFP, FOMC): a filter or overlay, not a strategy | Execution quality degrades around releases; post-release drift may exist | — | — | — | Low (MT5 calendar export) |
| S7 | **Meta-labelling ML filter** on top of a base strategy that is already positive (López de Prado, 2018) | A model can learn *when* a base signal works | Only after S1–S5 show positive expectancy | Small samples; non-stationarity | — | High |

For each candidate, `STRATEGY_RESEARCH.md` requires before it is accepted:
- the hypothesis;
- regime conditions;
- failure conditions;
- entry and exit rules;
- risk needs;
- expected frequency;
- cost sensitivity;
- in-sample, out-of-sample and walk-forward evidence;
- complexity.

**Timeframe hypothesis to test early:** moving signal generation from M1 to M5/M15 (keeping M1 for entry timing only) lowers cost per unit of R. Both cost/ATR and noise/ATR fall as the timeframe rises. This is cheap to measure from tick data and could change the whole project's direction.

**v3.0's accidental logic deserves one formal test.** It is a crude version of S2: a pullback entry inside a trend. It should be reproduced deliberately as a named variant, so we learn whether the inverted logic was better or worse than the intended one.

---

## DELIVERABLE 5 — Proposed Target Architecture [PROPOSED]

```
┌──────────────────────── RESEARCH LAYER (Python, offline; never places orders) ─────────────────────────┐
│ Data ingestion ─► Data QA ─► Parquet store + DuckDB (read-only to agents)                               │
│   • Broker MT5 history (Python MetaTrader5 pkg on a Windows terminal logged in with INVESTOR password)  │
│   • Dukascopy (independent cross-check)  • MT5 economic-calendar export                                 │
│ Research lib: stylized facts, event studies, vectorised prototypes WITH costs                           │
│ Validation lib: walk-forward, Monte Carlo, bootstrap CIs, PBO (CSCV), Deflated Sharpe, purged CV         │
│ Reporting: ingests MT5 tester reports + EA journal ─► standard performance pack (Deliverable 6 metrics)  │
└───────────────────────────────▲─────────────────────────────────────────────┬──────────────────────────┘
          approved, versioned   │ parameter sets / model files                │ journals, tester outputs
                                │                                             ▼
┌──────────────────────── PRODUCTION LAYER (MQL5 EA, deterministic, self-sufficient) ────────────────────┐
│ Config & Profiles ─ validated inputs, Conservative/Moderate/Aggressive, config hash = strategy version │
│ SymbolSpec ─ contract size, tick size/value, digits, volume min/max/step, stop/freeze levels, sessions │
│ MarketData ─ bars, indicators, spread statistics, data-quality checks                                  │
│ Regime ─ trend/range × volatility state (+ "abnormal" state)                                           │
│ Strategies (interface) ─ produce SignalCandidate{dir, entry, stop, target, quality, strategyId}        │
│        │                                                                                                │
│        ▼                                                                                                │
│ RISK ENGINE (veto authority) ─ equity daily/weekly/HWM-drawdown limits, open-risk cap, loss streaks,   │
│   cost/R gate, session/rollover/news blackouts, margin check, kill switch ─► APPROVE(size) | REJECT(why)│
│        │                                                                                                │
│        ▼                                                                                                │
│ Sizing ─ fixed-fractional of equity, round DOWN to step, never above caps                              │
│ Execution ─ idempotent send, retcode handling, bounded retries, slippage capture, fill verification    │
│ Position Manager ─ exit modules (SL, TP, BE, partials, trail, time, invalidation), each switchable     │
│ State Store ─ crash-safe file state; rebuild from broker deal history on start                         │
│ Journal/Audit ─ per-decision + per-trade CSV (incl. rejections, costs, MFE/MAE, exit reason)           │
│ Monitor ─ panel, heartbeat file, push alerts │ Emergency ─ kill switch, close-all, suspend on anomalies│
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Design rules:**
1. The EA must be able to trade and enforce risk **with no external process running**. No live LLM call sits in the trading path.
2. The risk engine can reject any strategy signal. A strategy cannot size its own trades.
3. Python is research and reporting only. **No component outside the EA can send orders.**
4. Every live behaviour is traceable to a versioned config hash and a git commit.
5. Restart must be idempotent: positions are re-adopted, there are no duplicate entries, and limits are rebuilt from history.

**Component disposition:**

| Component | Disposition |
|---|---|
| Broker-aware sizing math, ATR stops, one-position rule | **Retain** |
| v3.1 persistence and position adoption, R tracking, exit modules | **Improve** (move into modules; make each switchable) |
| Signal logic (EMA cross) | **Replace or demote** pending baseline evidence |
| Risk management (absolute $ caps) | **Replace** with an equity-based risk engine |
| Spread filter in points | **Replace** with a cost/R gate |
| Journal, SymbolSpec, Regime, Session/Calendar, Kill switch, Python research and validation stack | **New** |

**Planned repository layout** (to be adopted in M-1, Deliverable 8):

```
mql5/Experts/AlgolGold/AlgolGold.mq5        mql5/Include/AlgolGold/*.mqh      mql5/Scripts/Tests/*.mq5
research/ (python package, notebooks)      tests/ (python validators)       configs/ (tester .ini, .set)
docs/ (living docs, assessments)           .claude/skills/                  legacy/ (v3.0, v3.1 frozen)
```

---

## DELIVERABLE 6 — Research and Testing Roadmap

The detailed protocol is in `docs/BACKTESTING_PROTOCOL.md`. Risk thresholds are in `docs/RISK_FRAMEWORK.md`. **All numeric thresholds are proposed defaults that require ratification by Algol Financia's risk owner. They are not targets derived from evidence.**

| Phase | Goal | Key deliverables | Required data / infra | Pass condition (objective) | Fail → |
|---|---|---|---|---|---|
| **P0 Foundations** | Make work verifiable and durable | GitHub repo attached and used; Windows MT5 + MetaEditor; broker spec sheet; v3.0 and v3.1 compiled | Windows machine/VPS with MT5; broker demo; GitHub access | v3.1 compiles with 0 errors and 0 warnings; spec sheet captured; smoke run with 0 runtime errors | Fix; nothing else proceeds |
| **P1 Instrument and baseline** | Learn whether **anything** in the current logic has an edge | Trade/decision journal; baseline matrix: v3.0-as-is, v3.0 logic as an explicit variant, v3.1, each exit module ablated | Broker real ticks for the development period only | A decision memo per variant: gross and net expectancy with 95% bootstrap CI, exit-module attribution, cost/R distribution | — (results inform P3; rejection is a valid outcome) |
| **P2 Data and research stack** | Reliable data and stylized facts | Python env; Parquet/DuckDB; data-QA report; spread/vol/session profiles; calendar export | Broker ticks (primary); Dukascopy (comparison) | QA: no unexplained gaps > threshold; timestamps aligned (timezone documented); bid/ask sanity | Fix data before research |
| **P3 Hypothesis research** | Find candidate edges | Pre-registered hypotheses S1–S6; prototypes with costs; candidate shortlist | Development + validation sets (holdout locked) | ≤ 3 candidates with positive net expectancy on dev **and** validation; parameter plateaus, not peaks; trades ≥ 200 per candidate | Reject; record in DECISIONS.md |
| **P4 Production engine** | Modular EA with risk engine | Modules per Deliverable 5; risk profiles; kill switch; journal; MQL5 test scripts | Windows MT5 | All unit and scenario tests pass; zero risk-limit violations in stress scenarios; restart test passes | Fix |
| **P5 Full validation** | Defensible evidence | Real-tick backtests, walk-forward, Monte Carlo, cost stress, PBO/DSR, **single-use holdout** | Full dataset | All criteria in the table below | Back to P3 or reject |
| **P6 Demo forward** | Reality check | ≥ 3 months and ≥ 100 trades (whichever is later), weekly reports | Broker demo, VPS | Live-vs-model deviations within tolerance (below); zero duplicate orders or risk violations | Investigate; back to P5 |
| **P7 Controlled proprietary live** | Auditable track record | Separately approved small capital, hard limits, independent statement verification | Approved capital; counsel sign-off | Signed off by risk owner; ongoing monitoring within limits | Suspend |

**Governance track (parallel, no engineering dependency) — questions for qualified Zimbabwean counsel and SECZim. These are open questions, not answers:**
1. Does a Zimbabwean company holding a proprietary trading account with an offshore MT5/CFD broker need Reserve Bank of Zimbabwe exchange-control approval?
2. Are OTC commodity CFDs within SECZim's remit for dealer or asset-manager licensing, or regulated elsewhere?
3. What may be disclosed or marketed about (a) backtested or hypothetical performance and (b) a proprietary live track record, before the Investment Management licence is held?
4. What are the requirements on performance fees (hurdle, high-water mark), custody and segregation if third-party money is ever traded through an offshore broker?
5. How are offshore CFD gains and losses treated for tax (ZIMRA)?
6. What CDPA obligations apply to investor data in future reporting systems?
7. How should IP be assigned for the algorithm (staff, contractors, AI-assisted code) — see business plan §23.7?

**Proposed acceptance criteria for P5 (provisional; to be ratified):**

| Criterion | Proposed threshold | Rationale |
|---|---|---|
| Net expectancy (after spread, commission, swap, slippage model) | > 0 with the **95% bootstrap CI lower bound > 0** on out-of-sample data | Profitability must be statistically distinguishable from zero |
| Out-of-sample trade count | ≥ 200 (prefer ≥ 400) | For a per-trade σ ≈ 1R and edge ≈ 0.1R, n ≈ (2σ/edge)² = 400 for t ≈ 2 |
| Net profit factor (OOS) | ≥ 1.25 | Margin for live cost drift |
| Walk-forward efficiency (OOS annualised ÷ IS annualised) | ≥ 0.5, and positive in ≥ 70% of windows | Stability across regimes |
| Deflated Sharpe Ratio (Bailey & López de Prado, 2014) | Probability ≥ 0.95 | Corrects for the number of trials |
| Probability of Backtest Overfitting (CSCV) | ≤ 0.20 | Overfitting control |
| Cost stress: spread × 1.5, plus slippage of 1 tick per side | PF ≥ 1.10 and expectancy > 0 | Cost robustness |
| Parameter stability: ±20% on each key parameter | PF stays ≥ 1.10 | No knife-edge optima |
| Concentration | No month > 30% of net profit; top 5% of trades < 50% of net profit | No dependence on a few trades |
| Monte Carlo (10,000 reshuffles/bootstraps) 95th-percentile max drawdown | ≤ the profile's DD limit (`RISK_FRAMEWORK.md`) | Drawdown within mandate |
| Regime coverage | Positive or flat net in each major regime bucket; no single regime carries the result | Survivability |
| Holdout | Used **once**; if it fails, the candidate is rejected (no re-tuning) | Prevents leakage |

**Demo tolerance (P6):**
- median slippage and spread within ±25% of the model;
- trade frequency within ±30% of the backtest;
- expectancy inside the backtest's 95% CI;
- zero duplicate orders;
- zero limit breaches.

---

## DELIVERABLE 7 — Immediate Priorities (ranked)

| Rank | Priority | Why first |
|---|---|---|
| **1** | **Verification infrastructure.** Windows MT5 + MetaEditor (compile and Strategy Tester), and a GitHub remote for this repo. | Nothing can be verified today: v3.1 has never compiled, and this container is ephemeral, so **uncommitted, unpushed work is lost when it is reclaimed.** Every other priority depends on this. |
| **2** | **Measure whether the current logic has any edge** (P1 baseline with journal), including the v3.0-inverted variant and exit ablation | Prevents months of engineering on a signal that may be noise. Directly tests your four observed symptoms (early entries, distant TPs, wins wiped out, inconsistent R). Biggest impact on profitability decisions. |
| **3** | **Equity-based risk engine with veto and kill switch**: daily, weekly and drawdown-from-high-water-mark limits in % of equity; open-risk cap; margin check; session, rollover and weekend controls | Protects capital whatever the strategy. B3, B4, B6 and B7 are the largest remaining loss channels. Biggest impact on capital preservation. |
| **4** | **Exit-stack payoff analysis** (MFE/MAE, per-module attribution) | C3 and C4 are the most likely mechanism behind "profits wiped out". The fix must be evidence-based (keep, retune or drop each module), not another round of rule-adding. |
| **5** | **Unit normalisation and broker specification**: replace point inputs with ATR, R or price units; capture and log the full symbol spec; cost/R entry gate | B2 can silently disable or distort the EA across brokers. C2 shows the current spread gate allows uneconomic trades. Reliability and cost control. |

---

## DELIVERABLE 8 — First Implementation Plan [PROPOSED — no production code changed yet]

Each item follows the methodology in your brief, §15:

> problem → cause → hypothesis → smallest change → compile → regression → controlled backtest → compare → document → accept or reject.

| ID | Change | Files / components | Problem addressed | Approach | Side effects | Required tests | Expected measurable outcome |
|---|---|---|---|---|---|---|---|
| **M-1** | Repository structure and remote | Repo layout (Deliverable 5); move v3.0/v3.1 to `legacy/`; README | Durability, traceability | `git mv`; push to `Algol-Insights/Algol-Trader` (or a new private repo) | None to behaviour | `git log` shows history; CI placeholder | 100% of work recoverable from GitHub |
| **M-2** | Compile v3.0 and v3.1; fix v3.1 build errors only | `AlgoTraderGold_v3.1.mq5` | B1 | MetaEditor compile; fix errors without behaviour changes | None intended | Compile log; 1-month real-tick smoke run; check for runtime errors | 0 errors, 0 warnings, 0 runtime errors |
| **M-3** | Trade and decision journal | New `Include/AlgolGold/Journal.mqh`; hooks in v3.1 | B8; enables P1 | CSV per trade: IDs, times, direction, signal snapshot (EMAs, RSI, ATR, spread, HTF), requested vs filled price, SL/TP, lot, risk (money and % equity), commission, swap, MFE/MAE in R, exit reason, result in R and money. CSV per rejected signal with reason. | File I/O (negligible) | Reconcile journal totals against MT5 history | Journal = broker history to the cent |
| **M-4** | Strategy-variant and exit-module switches (for measurement, not for shipping) | v3.1 inputs: `EntryLogic {CONFIRMED_CROSS, LEGACY_V30_REPLICA}`; existing exit toggles | Enables controlled A/B | Re-create v3.0's ordering behind a switch | More inputs (test-only) | **Regression:** the replica reproduces v3.0's trade list over a fixed window | Identical entry timestamps versus v3.0 |
| **M-5** | Baseline experiment (no code) | `configs/`, `docs/TEST_RESULTS.md` | C1, C3, C4 | Matrix: 3 entry variants × exit ablations, on the development period only, real ticks, broker costs | — | Journals → Python analysis | A per-variant decision memo with CIs |
| **M-6** | Risk engine, increment 1 | New `RiskEngine.mqh`, `SymbolSpec.mqh`, `Session.mqh` | B2–B7 | Equity % limits (daily/weekly/HWM DD), open-risk cap, margin check, freeze/stop levels, rollover and weekend blackout, kill switch (input + file flag), cost/R gate; state in a file and rebuilt from history | Fewer trades (by design) | Scenario scripts: forced loss streaks, equity drops, closed sessions, kill switch; assert vetoes | Zero limit breaches in stress tests; every veto journaled with a reason |

**Sequencing rule:** M-1 → M-2 → M-3 → M-4 → M-5 → M-6.

The risk engine (M-6) comes **after** the baseline measurement. This is so the baseline measures the strategy, not a new veto layer: changing both at once would confound the results. During M-5 nothing trades live, so delaying M-6 carries no capital risk.

---

## DELIVERABLE 9 — Algol Financia R&D Environment

### 9.1 Inventory — confirmed by commands run in this session (2026-11-05)

| Capability | Status |
|---|---|
| Surface | Claude Code, cloud session in an **ephemeral** Linux container (Ubuntu 24.04, 4 vCPU, 15 GB RAM, ~31 GB free disk) |
| Project filesystem | `/home/user/AlgoTraderGold` (2 EA files plus the docs created today). Business plan available as an upload. |
| Terminal | Yes |
| Git | git 2.43 — **local repo initialised today** (2 commits); **no remote** |
| GitHub | `gh` 2.89 installed, but **token invalid** (`gh auth status` fails). No repo attached to the session. A repo `Algol-Insights/Algol-Trader` exists on your account; attaching it was blocked by a permission check. |
| MetaTrader 5 / MetaEditor | **Not available.** No Windows, no Wine. **Cannot compile MQL5 or run the Strategy Tester here.** |
| Python | 3.13.18 with numpy 2.5.3, pandas 3.0.5, python-docx, openpyxl. **Missing:** scipy, statsmodels, scikit-learn, matplotlib, plotly, duckdb, pyarrow. The `MetaTrader5` package is Windows-only. |
| Other | Docker 29, Node 22, pandoc |
| Network | Limited: package registries (pip/npm) allowed; **no other hosts** (broker, Dukascopy and Trading Economics are unreachable unless allow-listed) |
| Skills available in this session | Superpowers workflow skills (`superpowers:*`: TDD, systematic debugging, planning, code-review requests, verification-before-completion); `code-review`; built-in `/code-review`, `/security-review`, `/simplify`; docx/xlsx/pdf; dataviz |
| MCP connectors in this session | **Context7** (working — the MQL5 Book and docs are indexed and were used today to verify A1 and the calendar limitation); Gmail, Google Calendar, Microsoft 365, Claude Docs (not relevant to trading) |
| Plugins enabled on your claude.ai account | **None** (`ListPlugins` returned an empty list). The session-level skills above come from this environment, not your account. |

### 9.2 Recommended Claude plugins

| Plugin | Availability (verified today) | Precise value | Permissions | Cost / limits | Recommendation |
|---|---|---|---|---|---|
| **Superpowers** (obra; Anthropic Directory, partner tier) | Skills present in this session; **not enabled on your account** | TDD, systematic debugging, written plans, verification before claiming completion — enforces brief §15 | Installs skills plus a SessionStart hook (privileged reach) | No fee listed in the directory | **Essential now.** Enable at account level so every session has it. |
| **Context7** (Upstash; Directory) | MCP tools present in this session; **not enabled on your account** | Current MQL5 and Python library docs; avoids API mistakes like A1 | Remote MCP; queries leave Algol (send library questions only, never proprietary code) | Free tier; may require Context7 auth | **Essential now.** |
| **GitHub** (official MCP; Directory) | Not enabled | Issues, PRs, protected branches, reviews | Repo read/write via your GitHub account | Free for private repos; Actions minutes are billed | **Essential now** — but the first step is fixing session GitHub access (see 9.10). |
| **code-review** (Anthropic; Directory) | Not enabled. A built-in `/code-review` is already available. | Multi-agent PR review | Repo/PR read | — | **Next phase**, once PRs exist |
| **Security Guidance** (Anthropic; Directory) | Not enabled | Hook-based checks for secrets, injection and similar on edits and commits | Hooks on every edit and commit (privileged) | — | **Next phase**, when monitoring, database or API code starts. The MQL5 EA has a small attack surface; the main risk now is secrets in configs, handled by policy and `.gitignore`. |

**Installation:**
- **claude.ai plugins** (Superpowers, Context7, GitHub, Security Guidance): a person enables them from the plugin directory. Search the name and choose Add/Enable.
- **Local Claude Code CLI:** `/plugin` lets you browse and install from the Anthropic marketplace.

I have **not** installed or enabled anything.

**Do not use** third-party "MetaTrader MCP servers". Several appear in Context7's index, some advertising "natural language trading… order execution". They would expose `order_send` to an AI agent, which directly violates brief §19.7.

### 9.3 The five project skills (created today under `.claude/skills/`)

| Skill | Purpose | Key acceptance gate |
|---|---|---|
| `xauusd-quant-research` | Hypothesis-first research procedure, gold stylized-fact checklist, strategy dossier template | No strategy proceeds without a written hypothesis, failure conditions and a cost model |
| `mql5-engineering` | Coding standards: broker-spec usage, sizing, order/retcode handling, state recovery, logging, units | Compile clean; checklist complete; unit scripts pass |
| `backtest-validation` | Data splits, real-tick testing, walk-forward, Monte Carlo, PBO/DSR, cost stress, reporting | Acceptance table (Deliverable 6) |
| `risk-governance` | Risk profiles, limits, circuit breakers, stress tests, banned techniques | Any change to a limit needs a Monte Carlo justification and risk-owner sign-off |
| `release-audit` | Versioning, regression, independent review, promotion gates research → demo → live | Promotion only with a signed checklist and evidence links |

### 9.4 Recommended MCP connectors

| Connector | Category | Purpose | Cost | Permissions | Priority |
|---|---|---|---|---|---|
| GitHub (official) | Engineering | Version control and review | Free (private repos) | Repo-scoped | **Essential now** |
| Context7 | Docs | Current API docs | Free tier | Outbound queries only | **Essential now** (already working in-session) |
| DuckDB read-only (local) | Research | Query research database | Open source | **Read-only** file handle | **Next phase** (P2) |
| MT5 data bridge | Data | — | — | — | **Not as an MCP.** Export data with a script on a Windows terminal logged in with the **investor (read-only) password**, then commit Parquet outside git. No live connector. |
| Trading Economics | Macro calendar | Event studies | Paid tiers — **pricing not verified** | API key (secret) | **Optional.** First use MT5's built-in economic calendar exported to file (free). The calendar cannot be read inside the Strategy Tester, so an export is required either way. |

### 9.5 Market-data architecture [PROPOSED]

1. **Primary: the broker's own MT5 data.** Ticks via `copy_ticks_range`, bars, and the `symbol_info` spec. Captured on a Windows research terminal using the **investor password**, which cannot place trades. Record:
   - the exact symbol name and suffix;
   - contract size;
   - tick size and tick value;
   - digits;
   - volume min/max/step;
   - stop and freeze levels;
   - trade and quote sessions;
   - **server timezone and DST rule**;
   - commission schedule.
2. **Independent: Dukascopy** (bid/ask ticks).
   - Compare only after aligning timezone (Dukascopy timestamps are UTC), price definition (bid versus mid) and contract.
   - **Never merge feeds.**
   - Review licence terms before any commercial use or redistribution.
3. **Calendar:** periodic export of the MT5 economic calendar to CSV, used by the EA in the tester and by Python.
4. **Storage:**
   - Parquet partitioned by source/symbol/year/month;
   - DuckDB catalog;
   - raw data immutable, with a checksum manifest;
   - data stays out of git; a manifest is in git.

### 9.6 Python research environment [PROPOSED]

- **Project:** a `pyproject.toml` with a lock file (uv or pip-tools); Python 3.12/3.13.
- **Core libraries:** numpy, pandas, pyarrow, duckdb, scipy, statsmodels, scikit-learn, matplotlib, plotly, pytest.
- **Optional:** numba (speed), arch (GARCH volatility forecasting).
- **Validation library (own code):**
  - walk-forward splitter;
  - purged k-fold with embargo;
  - block bootstrap;
  - Monte Carlo trade resampling;
  - CSCV-PBO;
  - Deflated Sharpe;
  - multiple-testing log (every trial recorded).
- **QuantConnect LEAN** (open-source engine): optional second engine only. Its gold data and fill model differ from our broker, so it is useful for logic cross-checks, not for performance claims.

### 9.7 Automated testing architecture [PROPOSED]

| Level | What | Where |
|---|---|---|
| L0 | Static checks (Python): no hard-coded symbol constants, every input documented, no point-denominated risk inputs | Any CI (Linux) |
| L1 | Compile with `metaeditor64.exe /compile:<file> /log`; fail on any error or warning | **Self-hosted Windows runner** (hosted Windows runners do not ship MT5) |
| L2 | MQL5 unit scripts for pure functions: volume rounding, risk math, R math, session logic, state round-trip | Windows runner |
| L3 | Strategy Tester scenario runs via `terminal64.exe /config:tester.ini` → report + journal → Python invariant checks: max one position, SL always set, risk ≤ cap, limits never breached, no duplicate orders | Windows runner |
| L4 | Research validation (walk-forward, Monte Carlo, PBO/DSR) on tester outputs | Linux or Windows |

Passing L0–L3 demonstrates **software correctness, not profitability.**

### 9.8 Security and access control (mandatory)

- **Broker credentials** never enter the repo, environment variables, logs or this AI environment.
  - Live trading terminals are operated by humans on a separate machine.
  - Research terminals use **investor (read-only) passwords**.
- **No connector exposes order placement.** The EA is the only order-sending component, and live deployment is a human action with a release checklist.
- **Secrets** (API keys): environment secret storage only; `.gitignore` already excludes `.env` and credential files.
- **Research database:** read-only to agents (`duckdb.connect(..., read_only=True)`).
- **Repo:**
  - private;
  - protected `main`;
  - PR review required;
  - signed tags for releases.
- **Proprietary code exposure:**
  - send only generic library questions to documentation services;
  - management should set an explicit policy on processing proprietary code with AI vendors, including this one.
- **Kill switch and limits** live in the EA and do not depend on any external service.

### 9.9 Costs (verifiable today)

| Item | Cost |
|---|---|
| MT5, MetaEditor, Python stack, DuckDB, LEAN engine | Free / open source |
| GitHub private repos | Free (Actions minutes billed beyond the free allowance) |
| Plugins listed above | No fee shown in the directory |
| Windows VPS or PC for MT5 testing | **Not verified** — obtain quotes |
| Trading Economics API | **Not verified** — obtain pricing only if the MT5 calendar proves insufficient |
| Dukascopy data | Free to download; **commercial-use terms to be reviewed** |

**No purchases are recommended at this stage.**

### 9.10 Phased installation plan

1. **Now — requires your action:**
   - **(a) GitHub:** reconnect GitHub at https://claude.ai/connect-github, make sure the Claude GitHub App is installed on `Algol-Insights/Algol-Trader` (or a new repo), and start a session with that repo selected, or approve attaching it here.
   - **(b) Windows MT5:** provide a Windows machine or VPS with MT5 + MetaEditor and a **demo** account at the intended broker.
   - **(c) Plugins:** enable Superpowers and Context7 on your claude.ai account.
2. **P1:** journal (M-3); compile/test loop on Windows. I write code here, and you (or a self-hosted runner) compile and run, returning the logs.
3. **P2:** Python environment (pip packages are allowed by the current network policy); Parquet/DuckDB; data export script for the investor-password terminal; Dukascopy only after its hosts are approved on the network allow-list.
4. **P4/P5:** self-hosted Windows CI runner (L1–L3); Security Guidance plugin.
5. **Optional later:** Trading Economics, LEAN cross-checks, an ML stack.

---

## References used (for verifiable claims)

- MQL5 Book, *Overview of Copy functions for obtaining arrays of quotes* — chronological placement in receiving arrays (supports A1).
- MQL5 Book, *Economic calendar* — calendar functions return `FUNCTION_NOT_ALLOWED` (4014) in the tester (supports 9.4).
- Moskowitz, T., Ooi, Y. H., Pedersen, L. H. (2012). *Time series momentum.* Journal of Financial Economics.
- Bailey, D. H., López de Prado, M. (2014). *The Deflated Sharpe Ratio.* Journal of Portfolio Management.
- Bailey, D. H., Borwein, J., López de Prado, M., Zhu, Q. J. (2017). *The Probability of Backtest Overfitting.* Journal of Computational Finance.
- López de Prado, M. (2018). *Advances in Financial Machine Learning.* Wiley — purging, embargo, meta-labelling.
- Algol Insights Master Business Plan (Parts 1–3), sections as cited.
