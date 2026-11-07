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

## Phase 2 — Addon foundation: done (in-game check passed 2026-11-07)

**Done (2026-11-07)**
- `Azerfolio/` addon, linked into AddOns. Core modules:
  - `Init`: namespace and print helpers.
  - `Config`: defaults, allowed values, ranges, limits.
  - `SavedVariables`: validate, clamp, migrate, trim.
  - `Debug`: error capture, `Try`.
  - `Events`: pcall-isolated dispatcher, internal messages, debounce.
  - `Character`: reads the player's details.
  - `Commands`: `/azerfolio`, `/azf`, help, refresh, status, debug, debug zone, shot.
  - `Lifecycle`: ADDON_LOADED → PLAYER_LOGIN → `AZF_READY`.
- Settings ownership: account-wide = window, tab, Zones view and filters, launcher, notifications, debug. Per character = exploration baseline, milestones, recent zones. Search text is session-only.
- `/azf shot` tests whether addons may call `Screenshot()` (needed for the visual preview loop).
- Tests: `luajit tests/run.lua`, 37 passed (settings, events, startup, commands, TOC).

**In game:** all steps passed. `Screenshot()` works for addons (3440×1440 JPG in `<game>\Screenshots\`). The owner plays with a gamepad and an ultrawide display; see the open question in the plan's decision log.

**Next:** Phase 3 visual design with HTML mockups (plan §4.3), and Phase 4 main window with `/azf shots`.

The `AzerfolioDiag` event sniffer is still on; turn it off with `/azfdiag sniff` when convenient.
