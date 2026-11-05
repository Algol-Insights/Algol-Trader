---
name: release-audit
description: Use when preparing a new EA version, merging changes, tagging a release, or promoting the system between stages (research → demo → controlled live). Enforces versioning, regression testing, independent review, documentation and evidence-based promotion gates.
---

# Production Release and Independent Audit

## Versioning
- Semantic versions: `MAJOR.MINOR.PATCH`.
  - MAJOR = strategy logic change;
  - MINOR = new module or control;
  - PATCH = defect fix with no intended behaviour change.
- Every version has a **reason for existing** in `CHANGELOG.md` and a status label.
- Git: work on branches; PR into protected `main`; annotated tag per release (`v3.2.0`); frozen versions are never edited.
- The config hash (inputs + build) is recorded with every test and every deployment.

## Regression requirements (every PR touching the EA)
- [ ] Compile: 0 errors, 0 warnings (log attached). If not compiled, the PR is labelled `[UNTESTED]` and cannot be promoted.
- [ ] MQL5 unit scripts pass (volume, risk, R, sessions, state round-trip).
- [ ] Scenario runs pass (invariants: ≤ 1 position, SL always set, no limit breach, no duplicate orders, journal reconciles).
- [ ] For PATCH releases: trade list identical to the previous version on the fixed regression window (or every difference explained).
- [ ] Docs updated: `CHANGELOG`, `KNOWN_ISSUES`, `TEST_RESULTS`, `DECISIONS` where relevant.

## Independent review
- Use `/code-review` (correctness) and, from P4, the Security Guidance plugin on every PR.
- The reviewer must actively try to break the change: restart mid-trade, broker rejections, gaps, market closed.
- The author never approves their own promotion. AI-generated code is reviewed like any other contributor's.

## Promotion gates
| From → To | Required evidence | Approver |
|---|---|---|
| Research → Validation | Research acceptance (`xauusd-quant-research`) | Lead researcher |
| Validation → Demo | All `BACKTESTING_PROTOCOL.md` §6 criteria passed, incl. single-use holdout; risk-governance acceptance | Risk owner |
| Demo → Controlled live | Demo tolerance met over ≥ 3 months and ≥ 100 trades; 0 duplicates, 0 breaches; ops runbook and kill-switch drill done; counsel questions answered | Risk owner + management (written) |
| Any stage → Suspended | Any breach, unexplained deviation or audit gap | Anyone; restart needs the risk owner |

## Live operations audit (monthly once live)
- Reconcile the EA journal against broker statements (to the cent).
- Compare realised costs and slippage with the model.
- Re-run the Monte Carlo with live trades appended; check against the limits.
- Record findings in `TEST_RESULTS.md` and any actions in `DECISIONS.md`.
