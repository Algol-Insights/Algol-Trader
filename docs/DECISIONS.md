# Decision Log (append-only)

Format: ID — date — decision — reason — evidence — status. Rejected options are recorded too.

| ID | Date | Decision | Reason | Evidence | Status |
|---|---|---|---|---|---|
| D-001 | 2026-11-05 | XAUUSD is the exclusive Phase 1 instrument | Owner directive (Phase 1 brief §2); concentrates research capacity | Brief; not in the business plan | Adopted |
| D-002 | 2026-11-05 | MT5/MQL5 is the production execution platform; Python is the research layer | Existing code base; broker connectivity. The business plan (§4.2) named QuantConnect/Backtrader, so this is a deviation. | Existing EA | Adopted — review at P4 |
| D-003 | 2026-11-05 | Trade XAUUSD via an MT5 broker (OTC contract) | Implied by D-002 | — | Adopted pending counsel review (assessment, Deliverable 6, Governance track) |
| D-004 | 2026-11-05 | Freeze v3.0 as the baseline; v3.1 holds the defect fixes; no further strategy changes until the baseline is measured | Avoid confounding; §15 methodology | Assessment, Deliverable 8 | Adopted |
| D-005 | 2026-11-05 | Run the risk engine (M-6) after the baseline measurement (M-5) | Baseline must measure the strategy, not a new veto layer. Nothing trades live in the meantime. | Assessment, Deliverable 8 | Proposed — awaiting owner approval |
| D-006 | 2026-11-05 | No third-party "MetaTrader MCP" servers that can place orders | Least privilege (brief §19.7) | Context7 index lists servers advertising order execution | Adopted |
| D-007 | 2026-11-05 | Economic-calendar research uses MT5 calendar exports before any paid API | Free and broker-integrated. Calendar functions are unavailable in the tester (MQL5 Book), so an export is needed regardless. | MQL5 Book, *Economic calendar* | Proposed |
