---
name: mql5-engineering
description: Use when writing, modifying or reviewing MQL5 Expert Advisor code for the XAUUSD system — order execution, position sizing, broker symbol specs, indicator reads, state persistence, error handling, logging. Provides the project's coding standards and a pre-handoff checklist.
---

# Professional MQL5 Engineering (Algol Financia standard)

## Before writing code
1. Confirm the change has an approved entry in the implementation plan or `DECISIONS.md`.
2. Look up any API you are not certain of in Context7 (`/websites/mql5_en_book`). Do not rely on memory for array ordering, CTrade behaviour, the trade-transaction sequence or tester limits.
3. Make the **smallest** change that addresses the problem. No drive-by refactors in the same commit.

## Mandatory standards
**Units and broker spec**
- Never hard-code pip size, contract size or tick value. Read `SYMBOL_TRADE_CONTRACT_SIZE`, `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_TRADE_TICK_VALUE(_LOSS)`, `SYMBOL_VOLUME_MIN/MAX/STEP`, `SYMBOL_TRADE_STOPS_LEVEL`, `SYMBOL_TRADE_FREEZE_LEVEL`, `SYMBOL_TRADE_MODE` and `SYMBOL_DIGITS`. Log them all in `OnInit`.
- Express distances in ATR, R or price units. Point-denominated risk inputs are not allowed.
- Normalise prices to the tick size; normalise volume **down** to the step.

**Indicator reads**
- Dynamic arrays with `ArraySetAsSeries(arr, true)` before `CopyBuffer`/`CopyRates`. Check the copied count equals the requested count.
- Signals use closed bars (shift ≥ 1) unless intrabar logic is explicitly specified and tested.

**Orders**
- Set `SetTypeFillingBySymbol`, the deviation, and the magic number per strategy version.
- After every trade call, check `ResultRetcode()` ∈ {DONE, DONE_PARTIAL, PLACED}. Log the retcode description otherwise.
- Bounded retries only for transient retcodes (REQUOTE, PRICE_CHANGED, PRICE_OFF, TIMEOUT, CONNECTION). Never retry on NO_MONEY, INVALID_STOPS or MARKET_CLOSED.
- **Idempotency:** before sending, re-check positions and pending requests for this magic and symbol. Never send if a position exists or a request is in flight.
- Read the fill (`POSITION_PRICE_OPEN`, position ID from the deal) and store R from the fill.
- Pre-trade checks: `OrderCalcMargin`/free margin, stop and freeze levels, `SYMBOL_TRADE_MODE`, session open.

**Position management**
- Never remove or reindex tracking state inside the loop that uses it. Prune in a separate pass.
- Partial close: round down; never leave less than the minimum volume; skip if unsplittable.
- SL modifications only in the protective direction, respecting stop/freeze levels and a minimum step.

**State and recovery**
- On `OnInit`: rebuild state from broker positions plus deal history; re-adopt our positions; restore risk counters.
- A restart must never duplicate a position or reset a risk limit.

**Logging and audit**
- Journal every decision (entered / rejected + reason) and every trade lifecycle event to CSV.
- Never log credentials or account passwords.

## Pre-handoff checklist (copy into the PR description)
- [ ] Compiles with 0 errors and 0 warnings (state if **not** compiled because no MetaEditor was available)
- [ ] No hard-coded symbol constants; no point-denominated risk inputs
- [ ] Series ordering verified on every `CopyBuffer`/`CopyRates`
- [ ] Every trade call checks the retcode; transient-only retries
- [ ] Idempotency guard on entries
- [ ] Restart test described or performed
- [ ] Journal fields updated if behaviour changed
- [ ] `CHANGELOG.md` and `KNOWN_ISSUES.md` updated; status label applied
- [ ] Unit/scenario scripts added or updated for the changed logic
