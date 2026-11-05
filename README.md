# Algol-Trader

Proprietary XAUUSD quantitative trading system for **Algol Financia**: The Future Fund, Phase 1 (gold only).

> **Status (2026-11-05):** Research and engineering phase. **No strategy has been validated.** The current EA has **never been compiled or backtested**. Do not run it on a live account.

## Repository layout
| Path | Contents |
|---|---|
| `mql5/Experts/AlgolGold/AlgolGold.mq5` | Active development EA (currently identical to v3.1, `[UNTESTED]`) |
| `legacy/` | Frozen versions: `AlgoTraderGold_v3.0.mq5` (supplied baseline), `AlgoTraderGold_v3.1.mq5` (defect fixes) |
| `docs/assessment/` | Dated assessments. Start with `2026-11-05_INITIAL_ASSESSMENT.md` (Deliverables 1–9). |
| `docs/` | Living project documents: overview, architecture, strategy register, risk framework, backtesting protocol, changelog, known issues, test results, decisions |
| `.claude/skills/` | Project skills: quant research, MQL5 engineering, backtest validation, risk governance, release/audit |
| `CLAUDE.md` | Project rules for AI-assisted development sessions |

## Using the EA in MetaTrader 5 (testing only)
1. Copy `mql5/Experts/AlgolGold/AlgolGold.mq5` into your terminal's `MQL5/Experts/AlgolGold/` folder (MetaEditor: File → Open Data Folder).
2. Compile in MetaEditor (F7). Report any errors or warnings; see `docs/KNOWN_ISSUES.md` B1.
3. Run only in the Strategy Tester ("Every tick based on real ticks") or on a **demo** account.

## Working rules
- Branch from `main`; changes arrive through pull requests.
- Every change follows the method in `CLAUDE.md`, and every claim carries an evidence label.
- No credentials, API keys or account passwords in this repository.
