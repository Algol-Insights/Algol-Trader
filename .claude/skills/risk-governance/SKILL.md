---
name: risk-governance
description: Use when designing, changing or reviewing anything that affects capital at risk in the XAUUSD system — position sizing, stop placement, loss limits, drawdown controls, circuit breakers, risk profiles, exposure, or any proposal involving recovery, averaging or grid techniques. Requires stress evidence and risk-owner sign-off.
---

# Institutional Capital and Risk Governance

Limits and profiles: `docs/RISK_FRAMEWORK.md`. This skill is the review procedure.

## Automatic rejections (no analysis needed)
Reject outright and record in `DECISIONS.md`:
- martingale or any size increase after a loss;
- averaging down;
- grids without a hard total-exposure cap;
- removing or widening a stop after entry;
- trading without a broker-side SL;
- any input that lets a profile exceed the hard ceilings.

## Review procedure for any risk-affecting change
1. **State the risk question.** What loss path does this change open or close?
2. **Worst-case arithmetic.** Compute max loss per trade (including a gap of k·ATR through the stop), per day and per week, at each profile.
3. **Stress scenarios** (tester or simulation), with expected behaviour written *before* running:
   - [ ] N consecutive full losses (N = 10, 20)
   - [ ] Gap through the SL at the weekend open (2, 5, 10 × ATR)
   - [ ] Spread spike to p99.9 during an open position
   - [ ] Restart mid-trade; restart after a limit breach
   - [ ] Broker rejects modifications (stop/freeze level)
   - [ ] Margin call proximity on a small account
   - [ ] Kill switch activated with an open position
4. **Monte Carlo calibration.** Simulate equity paths from the validated trade distribution. Report the 95th/99th percentile drawdown and time-to-recovery for each profile. A limit is justified only if it improves the risk distribution without destroying expectancy.
5. **Veto authority check.** Confirm the risk engine, not the strategy, makes the final size and allow/deny decision. Confirm every veto is journaled.
6. **Sign-off.** Write a `DECISIONS.md` entry with the evidence link. Changes to live limits need explicit risk-owner approval.

## Checklist for the risk engine (P4)
- [ ] All limits in % of equity incl. floating P/L; persisted; rebuilt from history at start
- [ ] Daily, weekly, HWM-drawdown, open-risk, consecutive-loss controls
- [ ] Cost/R gate; abnormal-market gate; session/rollover/weekend gate; validated news gate
- [ ] Margin pre-check; min-lot-exceeds-risk → skip
- [ ] Kill switch (input + file flag) and close-all procedure
- [ ] Profiles differ in measurable parameters; hard ceilings enforced in code
- [ ] Each control has a scenario test with a recorded expected vs actual result

## Acceptance
- Zero limit breaches across all stress scenarios.
- Monte Carlo 95th-percentile DD ≤ the profile limit.
- Every control traceable to a test in `TEST_RESULTS.md`.
