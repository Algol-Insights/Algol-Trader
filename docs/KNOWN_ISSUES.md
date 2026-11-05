# Known Issues

IDs match the tables in `assessment/2026-11-05_INITIAL_ASSESSMENT.md` (Deliverable 3), where evidence, root cause and validation method are recorded.
Close an issue only with a link to evidence in `TEST_RESULTS.md`.

## Open — v3.1 (current development version)
| ID | Issue | Severity | Status |
|---|---|---|---|
| B1 | Never compiled | Critical | Open — needs Windows MT5 |
| B2 | Point-denominated inputs (spread, fallback SL, trail start) depend on broker digits | High | Open |
| B3 | Absolute-currency limits ($20 per trade, $50 per day) | High | Open |
| B4 | Daily limit realized-only; no weekly, HWM-drawdown or open-risk limits | High | Open |
| B5 | No margin check | Medium | Open |
| B6 | No freeze-level, trade-mode or session checks; no daily-break or weekend handling | High | Open |
| B7 | No kill switch / close-all | High | Open |
| B8 | No structured audit journal; state in editable terminal global variables | High | Open |
| B9 | Positions closed while the EA is offline are not counted | Medium | Open |
| B10 | No slippage measurement or limit | Medium | Open |
| B11 | Interacting exit rules without evidence | High | Open — ablation planned |

## Hypotheses under test
| ID | Hypothesis | Status |
|---|---|---|
| C1 | M1 EMA cross has no net edge | NEEDS DATA |
| C2 | Spread gate admits up to 0.27R entry cost | Arithmetic confirmed; impact NEEDS DATA |
| C3 | Early exit mostly noise-triggered | NEEDS DATA |
| C4 | Exit stack truncates winners (likely cause of "wins wiped out") | NEEDS DATA |
| C5 | EMA50 (M5) too short for a regime filter | NEEDS DATA |
| C6 | Strong session/event dependence | NEEDS DATA |
| C7 | Overfitting risk from 33+ free parameters | Structural |
| C8 | Adaptive halving has no expected benefit | NEEDS DATA |

## v3.0 defects (baseline, frozen; fixed in v3.1 but UNTESTED)
A1 reversed MA ordering · A2 intrabar signals · A3 inert loss controls · A4 array out of range → EA halt · A5 TP1 closes 100% at min lot · A6 broker TP pre-empts TP2/trail · A7 profit lock only on BE tick · A8 circular loss cap shrinks SL · A9 no tracker persistence · A10 quote vs fill price · A11 dead inputs · A12 FOK/retcodes · A13 meaningless MinATR · A14 log spam
