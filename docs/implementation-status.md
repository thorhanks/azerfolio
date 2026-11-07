# Implementation status

## Phase 0 — Client capabilities: done (2026-11-07)

- Client facts: `wowf` 1.60.1.70862, interface 16001, Lua 5.1, modern API (272 `C_*` namespaces).
- `AzerfolioDiag` built, linked, and run in game. 0 errors.
- Quest APIs confirmed. PNG/TGA and native textures confirmed.
- Findings: `docs/research/client-capabilities.md`. Report tool: `luajit tools/diag-report.lua <section>`.

## Phase 1 — Exploration proof of concept: done (2026-11-07)

- Source: "Explore <zone>" achievement criteria. Objective ID = `criteriaID`. 43 zones covered; capitals and Zephras Isle untracked.
- Discovery test (Gideon): Forest's Edge and Brackwell Pumpkin Patch each flipped one criterion. Events: `CRITERIA_UPDATE` + `UI_INFO_MESSAGE`, then `MAP_EXPLORATION_UPDATED` about 0.4 s later.
- Per-character confirmed (Gideon vs Thragor).
- The game marks no criterion faction-ineligible; all count as eligible.
- Write-up: `docs/research/exploration-validation.md`.
- Tests: `luajit tests/run.lua`, 7 passed.

## Phase 2 — Addon foundation: not started

**Next:** `Azerfolio/` skeleton: TOC, init order, config, versioned SavedVariables, slash commands, event dispatcher, debug commands, first unit tests. Exploration catalogue generator (`tools/`) can follow in Phase 5.

The `AzerfolioDiag` event sniffer is still on; turn it off with `/azfdiag sniff` when convenient.
