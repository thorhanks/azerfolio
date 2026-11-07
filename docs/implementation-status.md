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

## Phase 3 — Art pipeline ready; waiting for zone art (2026-11-07)

- `art/style-guide.md`: look and feel, camera, safe area (core = middle 40% × 40–62% band, checked against all four crops), palette by region type, image spec, workflow, review checklist. UI chrome uses native textures, so only 51 images are needed (43 zones, 7 untracked places, 1 fallback).
- `art/prompts.md`: a shared style block, a negative prompt, and a subject line for all 51 images. Riverglades, Shen'dralas and Zephras Isle are inferred or unknown; the owner should confirm them.
- `tools/process-art.ps1`: crop to 2:1 around an optional focal point (`art/focal.json`), resize to 1024×512 PNG, write `Azerfolio/Media/Zones/`, generate `Azerfolio/Data/Art.lua` (in the TOC) and `mockups/zone-art/index.js`. Tested with a synthetic image: the landmark survives every crop in the mockup.
- Tests: 39 passed.

**Human step:** generate images and save them to `art/source/`.

## Phase 3 — Visual design: mockup iterations (2026-11-07)

The owner approved every UX improvement. The mockup now implements:
- A state language (complete / in progress / untouched / not tracked) and pips everywhere.
- Overview: Continue card, stacked zone bar, next goal, Atlas, grouped suggestions, activity strip.
- Catalogue: level-bracket sections, gamepad filter popups, status segments, level bars, "For your level" ribbons.
- Zone Detail: zone map from real revealed-map data.
- Wide split view for ultrawide screens.
- A completion celebration.
- Dev scenarios and a discovery simulation.

Decisions are recorded in `mockups/DESIGN.md`.

### First iteration

- `mockups/`: an interactive HTML mockup of the window, served at http://localhost:8765 (`mockups` preview).
  - Screens: Overview, Zones (cards and list), Zone Detail.
  - Real zone and criteria data from the client; Gideon's real exploration state.
  - Simulated controller with a focus highlight, hint bar and tooltips on focus.
- Not yet: approved design, `art/style-guide.md`, real zone art (placeholders are generated landscapes), `UI/Theme.lua`.

**Next:** owner reviews the mockup; iterate; then the style guide and art prompts, then Phase 4.

The `AzerfolioDiag` event sniffer is still on; turn it off with `/azfdiag sniff` when convenient.
