# Azerfolio — Implementation Plan

**Version:** 2.0
**Spec:** [project-spec.md](project-spec.md) v0.3
**Developers:** AI coding agents. A human (the project owner) runs the game client.
**Status tracking:** [docs/implementation-status.md](docs/implementation-status.md)

This plan is written for agents. Each phase lists what to do, what to produce, and how to know it's done. Read [CLAUDE.md](CLAUDE.md) first for environment facts and conventions.

---

## 1. Environment

| Item | Value |
|---|---|
| Game install | `C:\Program Files (x86)\World of Warcraft\_forever_` |
| Client | flavor `wowf`, version 1.60.1, build 70862 (from `.build.info`, Nov 2026) |
| Addon interface | `## Interface: 16001` (used by every Forever addon installed) |
| AddOns folder | `<install>\Interface\AddOns` |
| SavedVariables | `<install>\WTF\Account\<ACCOUNT>\SavedVariables\<Addon>.lua` (account-wide), `<install>\WTF\Account\<ACCOUNT>\<realm>\<character>\SavedVariables\<Addon>.lua` (per character) |
| Reference addons installed | ForeverJournal (MIT), ForeverDungeonJournal, Questie, QuestieDB (GPL-3.0), QuestieTrace, ItemTree, NodeSight, GatherLite (GPL-3.0) |

Facts here are verified by inspecting files. Facts about runtime API behavior live in [docs/research/client-capabilities.md](docs/research/client-capabilities.md) with an evidence level for each.

## 2. How agents work on this project

### 2.1 The in-game feedback loop

Agents cannot run the game. The loop is:

1. Agent writes or changes addon code in the repo.
2. The addon folders are linked into the game's AddOns folder (`tools/link-addons.ps1`), so no copying is needed.
3. Agent tells the owner exactly what to do in game: which commands to type, where to go, what to look at, and when to `/reload`.
4. Owner does it and reports back (a short message, a screenshot, or "done").
5. Agent reads results directly from the SavedVariables files on disk. `/reload` or logout writes them.

Rules:
- Prefer writing diagnostic output to SavedVariables over printing to chat. Chat output is for short confirmations only.
- Give the owner the fewest steps possible, numbered, with the exact commands.
- Never ask the owner to do something the agent could check from files.

### 2.2 Evidence levels

Every claim about client behavior in research docs is tagged:

- **[verified-ingame]** — observed in the running Forever client (cite the SavedVariables dump or owner report).
- **[verified-files]** — confirmed by reading installed client or addon files.
- **[external]** — from outside documentation only (wiki, other WoW versions).
- **[unverified]** — assumption.

Code may rely only on `verified-*` facts. Anything else must be guarded (check the API exists, `pcall` it, handle bad returns).

### 2.3 Dependencies

No dependency is added without the owner's explicit approval: no required or optional addon, no embedded library (including LibStub, LibDBIcon, Ace3), no external dev tool. To request one, state what it is, why it's needed, and what the no-dependency alternative costs.

Approved:
- Reading QuestieDB as a quest data source, in v1.1 (approach decided then).
- LuaJIT (`DEVCOM.LuaJIT` via winget, installed 2026-11-07) to run tests on the dev machine. Lua 5.1 semantics, matching the client. Dev-only; not shipped.

### 2.4 Per-phase routine

For each phase:
1. Read relevant code, research docs, and status.
2. Build the smallest working slice.
3. Run automated tests.
4. Write the owner's in-game validation steps.
5. After the owner validates, record results in `docs/implementation-status.md`: status, what changed, tests run, in-game validation done, known issues, next step.
6. Record any decision in §9 (Decision log).

### 2.5 Simplicity rules

- No custom UI framework, plugin system, or speculative abstraction. Create modules when they're needed, not before.
- No empty future modules or nonfunctional tabs.
- Use native Blizzard templates and mixins where they exist in this client.
- English only; no localization layer.

## 3. Repository layout

```text
azerfolio/                  (repo root)
├── CLAUDE.md               agent instructions
├── project-spec.md
├── project-implementation-plan.md
├── Azerfolio/              the addon (linked into AddOns)
│   ├── Azerfolio.toc
│   ├── Core/               Init, Events, Config, SavedVariables, Debug, Character
│   ├── Data/               Zones.lua, Exploration.lua (generated), later Quests
│   ├── Systems/            ObjectiveModel, Eligibility, Progression,
│   │                       ExplorationTracker, Milestones, Recommendations
│   ├── UI/                 Theme, MainWindow, Navigation, Launcher
│   │   ├── Components/     ProgressBar, StatCard, ZoneCard, ObjectiveRow, ...
│   │   └── Pages/          Overview, Zones, ZoneDetail
│   └── Media/              bundled art (final, game-ready files only)
├── AzerfolioDiag/          diagnostic addon (dev only, linked into AddOns)
├── tests/                  pure-Lua unit tests + WoW API mocks
├── tools/                  dev scripts: linking, data generation, art processing
├── art/                    art sources and prompts (not shipped)
└── docs/
    ├── research/           client-capabilities.md, exploration-validation.md
    ├── architecture.md
    ├── testing.md
    └── implementation-status.md
```

The addon lives in a subfolder so the game only ever sees game files.

## 4. Testing

### 4.1 Automated (pure Lua)

- Runner: `tests/run.lua`, a minimal test runner with no third-party framework. Run from the repo root with a Lua 5.1 interpreter: `luajit tests/run.lua`. New test files are added to the `FILES` list in `tests/run.lua`.
- Mocks: `tests/mocks/wow.lua` provides the subset of the WoW API and globals the tested modules use, with fixture data taken from real SavedVariables dumps.
- What gets tested: eligibility, aggregation, percentages, coverage classification, duplicate handling, unknown-state handling, sorting and filtering, SavedVariables migration, milestone baseline and dedup, recommendation ranking.
- Modules under test must not touch WoW globals at load time, so they can be loaded outside the game.
- Every phase that adds pure logic adds tests. Tests must pass before handing work to the owner.

### 4.2 In game

API behavior, events, rendering, interaction, combat safety, SavedVariables behavior. Each test case in `docs/testing.md` records steps, expected result, actual result, date, and whether it was run by the owner.

### 4.3 Visual preview

Agents can't see the game, so two tools close the gap:

- **HTML mockups** (Phase 3 onward): each screen is built as a static HTML page in `mockups/`, using real data shapes from the diagnostic dump, and shown in the desktop app's browser pane. Use them to iterate on layout and style with the owner before writing Lua. Once a design is approved, the mockup is the visual reference for the Lua implementation. Mockups are design tools, not the product; never treat a mockup as proof that the addon works.
- **In-game screenshots** (Phase 4 onward): a dev command (`/azf shots`) opens the window, steps through each tab and state, and calls `Screenshot()` for each. The agent reads the images from `<game>\Screenshots\`. The owner's part is `/reload` then `/azf shots`.

## 5. Art pipeline

Decision: Azerfolio uses custom artwork in the style of native Blizzard art.

### 5.1 Asset kinds

| Kind | Examples | How it's made |
|---|---|---|
| Native textures | Frame borders, buttons, scrollbars, icons, fonts | Referenced from the client by path or file ID, where verified to exist |
| UI chrome | Parchment panels, gold dividers, completion emblems, badges | Agent-generated (vector/procedural, then rasterized) or native if suitable |
| Zone illustrations | One per zone, fixed aspect ratio | Painted-style images. Agents cannot paint; the agent writes generation prompts in `art/prompts/` with a consistent style guide, the owner generates images with an image model, and the agent processes them |
| Fallback | Generic zone card art | Same pipeline as zone illustrations, made first |

### 5.2 Processing

`tools/` scripts (PowerShell, no extra installs unless approved) crop to the card aspect ratio, resize to power-of-two dimensions, and write the game format. Sources stay in `art/source/`; only processed files go in `Azerfolio/Media/`.

Verified in Phase 0: the client loads `.png` and `.tga` from addon folders. Ship PNG, and always include the extension in texture paths.

### 5.3 Style guide

`art/style-guide.md` defines: palette, lighting, painterly level, framing, aspect ratio, and a reference description per zone. Every generation prompt is derived from it so all illustrations look like one set.

## 6. Phases

| Phase | Deliverable | Checkpoint |
|---|---|---|
| 0 | Client capabilities research + diagnostic addon | A |
| 1 | Exploration proof of concept (Elwynn Forest) | A |
| 2 | Addon foundation + test harness | B |
| 3 | Visual design system + first art | B |
| 4 | Main window and navigation | B |
| 5 | Exploration catalogue + progression engine | C |
| 6 | Zones catalogue and Zone Detail | D |
| 7 | Overview dashboard | E |
| 8 | Polish and v1 validation | F (v1 done) |
| 9 | Quest tracking (v1.1) | G |

Phases 3 and 4 can overlap with 5. Do not finalize the exploration catalogue format until Phase 1 is accepted.

---

### Phase 0 — Client capabilities

**Goal:** Know what the Forever client actually offers before designing anything that depends on it.

**Tasks**
1. Record client facts from files: version, interface number, install paths. *(Done; see §1.)*
2. Survey installed Forever addons for APIs they rely on (MIT/GPL code may be read to learn API usage; do not copy code).
3. Build `AzerfolioDiag`, a dev-only addon that dumps to its SavedVariables:
   - Environment: build info, interface version, project ID, list of every `C_*` namespace and its functions, presence of key legacy globals.
   - The full map tree (IDs, names, types, parents).
   - All achievement categories, and every "Explore …" achievement with full criteria data.
   - Explored map textures for every zone map.
   - Quest completion API availability and counts.
   - A log of exploration-related events with before/after criteria diffs.
   - An image-format test (does the client display bundled `.tga` and `.png`?).
4. Owner runs it once; agent reads the dump and writes the findings.

**Deliverable:** `docs/research/client-capabilities.md` covering APIs, return shapes, events, image formats, limitations, open questions. Every finding tagged with an evidence level.

**Done when:** Every question in §7 "Phase 0 questions" has an answer or is explicitly listed as open.

### Phase 1 — Exploration proof of concept

**Goal:** Prove Azerfolio can compute trustworthy exploration progress for one zone.

**Phase 0 result** [verified-ingame]: all 43 questing zones have an "Explore <zone>" achievement. Its criteria (type 43) are the zone's named areas, each with a unique `criteriaID` and a done flag. Explored map textures are unreliable. So approach A is the working plan, with `criteriaID` as the objective ID. Capitals and Zephras Isle have no achievement. Details are in `docs/research/client-capabilities.md`.

**Tasks**
1. *(Done)* List Elwynn Forest's exploration criteria with every field.
2. Owner discovers one or two new areas, then `/reload`s (steps in `docs/testing.md`). Agent reads the event log and diffs to confirm:
   - which events fired, in what order;
   - that the criterion flipped to complete promptly;
   - which event is the earliest reliable trigger for a refresh.
3. Confirm per-character behavior: the second character's criteria must differ from the first's.
4. Cross-check Elwynn's count with the in-game Achievements window.
5. Decide how zones without an achievement are shown (capitals, Zephras Isle). Likely: listed, with exploration "not tracked".
6. Choose the catalogue format: probably generated from the dump (zone mapID → achievementID → criteriaIDs), with names read live from the client.

**Approaches, in order of preference**
- **A. Achievement/Legacy criteria** — native list and completion. Preferred.
- **B. Map overlays + bundled mapping** — only if A is missing for many zones.
- **C. Hybrid** — A where it exists, B elsewhere, with coverage marked accordingly.

**Deliverable:** `docs/research/exploration-validation.md`: APIs tested, sample outputs, events, chosen IDs, catalogue format, zone coverage table, edge cases, recommendation.

**Done when:**
- [ ] Discovering a new area is detected in game.
- [ ] Elwynn Forest's total objective count is confirmed independently (e.g. against the in-game achievement UI).
- [ ] Computed completed count matches the game.
- [ ] `/reload` keeps results correct.
- [ ] Strategy for all other zones is documented.

**Decision gate:** If objective-level tracking can't be made reliable, stop and revise the plan with the owner. Do not proceed to percentages built on guesses.

### Phase 2 — Foundation and test harness

**Tasks**
1. `Azerfolio.toc` (`## Interface: 16001`, `SavedVariables: AzerfolioDB`, `SavedVariablesPerCharacter: AzerfolioCharDB`).
2. Init order: load files → defaults → load SavedVariables → validate/migrate → init data providers → register events → build UI lazily on first open → refresh character state.
3. `Config`: defaults, debug flag, UI preferences, notification preferences, data versions.
4. `SavedVariables`: versioned schema and migration. Account-wide: window layout, display mode, filters/sort, preferences. Per-character: milestones, exploration baseline, recently visited zones.
5. Slash commands: `/azerfolio`, `/azf` toggle; `/azf debug [zone|exploration|progress]`; `/azf refresh`.
6. Test harness: `tests/run.lua`, `tests/mocks/wow.lua`, first tests (config defaults, migration).
7. Event dispatcher: one frame, `pcall`-guarded registration (unknown event names must not break loading).

**Done when:**
- [ ] Loads with no Lua errors; commands registered.
- [ ] SavedVariables persist across `/reload` and relog; corrupt values fall back to defaults.
- [ ] Debug commands work; debug is off by default.
- [ ] `lua tests/run.lua` passes.

### Phase 3 — Visual design system

**Tasks**
1. Inventory native textures usable in this client (from Phase 0) and decide what's native vs. custom.
2. Write `art/style-guide.md`; produce the fallback zone art and UI chrome first.
3. `UI/Theme.lua`: colors, fonts, spacing, sizes, border sizes, card aspect ratio. No style constants anywhere else.
4. Shared components: progress bar, completion badge, stat card, zone card, objective row, section header, empty/unavailable/loading states. Components display data they're given; they never compute progress.
5. Readability check at several UI scales, including text over illustrations.

**Deliverable:** A styled sample window using the components; asset choices documented in `docs/architecture.md`.

**Done when:** Owner approves the look from in-game screenshots.

### Phase 4 — Main window and navigation

**Tasks**
1. Main frame: title, character header, close button, drag, resize with min/max, clipping, content region.
2. Bottom tabs (Overview, Zones) built so adding a tab is one registration call.
3. Zones subview navigation (catalogue ↔ detail) with preserved state.
4. Launcher: addon compartment entry (needs no library) and a lightweight minimap button written in-house. Persist button position. Key binding via `Bindings.xml`.
5. Escape-to-close (register in `UISpecialFrames`), position persistence, off-screen recovery.
6. **Gamepad input layer** (`UI/Gamepad.lua`), addon-owned, following spec §4.3:
   - An input frame on the window with `EnableGamePadButton`/`EnableGamePadStick`, active only while the window is shown, the gamepad UI is on, and the player is out of combat.
   - **Do not use Blizzard's `SmartNavigation`.** Its registration (`HandlePanelOpen`) and setters require secure callers, and other Forever addons report that touching it taints protected action-bar code (see `docs/research/client-capabilities.md` § Gamepad).
   - Each page declares its focus targets as an explicit grid (rows × columns). The layer moves focus within that grid, draws the gold focus border, shows the focused control's tooltip, and scrolls lists to keep focus visible.
   - Hint bar component at the bottom of the window.
   - Pure focus-grid logic (`UI/FocusGrid.lua`) unit-tested without WoW.
7. `/azf shots`: open the window and screenshot each tab and state for agent review (plan §4.3).

**Done when:**
- [ ] Opens from both commands, the launcher and the key binding; tabs switch with mouse and LB/RB.
- [ ] D-pad focus, A, B and the hint bar work on every screen; input is released in combat.
- [ ] Drag, resize, and persistence work across reload and relog.
- [ ] Escape closes; no errors opening during combat.
- [ ] Repeated open/close and navigation cause no frame leaks.

### Phase 5 — Exploration catalogue and progression engine

**Tasks**
1. Objective model: completion state (complete/incomplete/unknown) and eligibility state (eligible/locked/unavailable/unknown) as separate fields.
2. Exploration catalogue: generated by a `tools/` script from Phase 0/1 dumps (reproducible; output committed as `Azerfolio/Data/Exploration.lua`; includes data version and client build). Keys are game IDs.
3. `ExplorationTracker`: objectives for a zone, completion for an objective, zone summary, refresh, cache invalidation.
4. `Progression`: the single aggregation service. Counts per state, valid percentage or nil, coverage, categories included. Deduplicates by objective ID.
5. Event handling: on an exploration event, find affected zones, invalidate only those, recompute, notify open UI, record milestones.
6. Baseline: on a character's first load, record current state as baseline; only later transitions become milestones.

**Tests:** aggregation math, unknown handling, coverage, dedup, baseline/milestone logic.

**Done when:**
- [ ] Elwynn Forest works end to end: correct states, correct %, updates on discovery, survives reload.
- [ ] No milestones generated for pre-existing progress.
- [ ] Unknown never counted as complete or incomplete.

### Phase 6 — Zones catalogue and Zone Detail

**Tasks**
1. Zone metadata (`Data/Zones.lua`): map ID, name (from client), faction applicability, level range (only where reliable), progression order, art key, categories, coverage. Don't guess level ranges or faction.
2. Catalogue page: scrollable, illustrated cards (default) and compact list, mode toggle, filters, sort, search, empty state. Reuse frames while scrolling.
3. Zone Detail: header, exploration section with checklist, map action where supported, back navigation.
4. Empty states: no matches, no objectives, unsupported zone, partial coverage, fully complete, unavailable.

**Tests:** filtering, sorting (including unknown handling and stable ties).

**Done when:** Spec §12 "Zones" and "Exploration" criteria pass in game.

### Phase 7 — Overview dashboard

**Tasks**
1. Character header (name, race, class, faction, level, XP, portrait/class icon).
2. Tracked Completion with category list and tooltip explaining scope.
3. Stat cards with drill-down.
4. Zone highlights (current, recently visited, closest to completion, recently completed).
5. Suggestions (fixed rules from spec §5.5, each with a reason).
6. Recent milestones (capped, deduplicated).
7. Looks complete with exploration as the only category; no disabled placeholder cards.

**Tests:** recommendation ranking, milestone dedup and cap.

**Done when:** Spec §12 "Overview" criteria pass; Overview and Zones show identical numbers for the same zone.

### Phase 8 — Polish and v1 validation

**Tasks**
1. Visual review of every screen (layout, clipping, tooltips, completion and empty states).
2. Interaction review (all controls, resize, scroll, reload persistence, launcher).
3. Performance review: no repeated scans, per-frame work, unbounded caches, or SavedVariables growth. Check event callback counts with debug mode.
4. Data validation across unexplored, partly explored, and fully explored zones; Alliance and Horde characters if available; contested zones.
5. Compatibility: reload, restart, combat, UI scale, resolution, with and without other installed addons, corrupt settings.
6. Update `README.md`: install (link script), features, known limitations, coverage, debug commands, changelog.

**Done when:** All spec §12 v1 criteria are checked off with evidence in `docs/testing.md`.

### Phase 9 — Quests (v1.1)

**Tasks**
1. Decide QuestieDB integration: runtime optional dependency vs. build-time extraction. Inspect its data format and load cost first. Record the decision.
2. Quest completion reader (`C_QuestLog.IsQuestFlaggedCompleted`; completed-quest list API if present). Events for turn-in.
3. Quest catalogue per zone: ID, name, zone, faction, class, profession, prerequisites, type, repeatable, exclusive groups.
4. Eligibility: completed / available / locked / unavailable / unknown. Never infer "unavailable" just because a quest isn't in the log.
5. Counts exclude repeatables and unavailable alternatives; unknown eligibility lowers coverage.
6. Zone Detail quest section, quest stat card, quest suggestions.

**Done when:** Spec §12 "v1.1 Quests" criteria pass. If full coverage risks stability, ship a clearly labeled subset.

## 7. Phase 0 questions

All answered 2026-11-07 except #5. Answers are in `docs/research/client-capabilities.md`.

1. Client version and Lua: 1.60.1.70862, interface 16001, Lua 5.1, modern API. ✔
2. Exploration APIs: `C_MapExplorationInfo` (2 functions; textures unreliable) plus achievement criteria. ✔
3. Explore achievements: one for every questing zone. Criteria have a unique `criteriaID`; `assetID` is not an area ID. ✔
4. Forever/Legacy API namespace: none exposed. ✔
5. Events on discovery: **open**, Phase 1.
6. Quest APIs: `C_QuestLog.IsQuestFlaggedCompleted` and `GetAllCompletedQuestIDs` work; `GetQuestsCompleted` doesn't exist. ✔
7. UI templates and native textures: ScrollBox views, `ButtonFrameTemplate`, `PanelTabButtonTemplate`, parchment, gold border and EJ art all present. ✔
8. Image formats: PNG and TGA both load. ✔

## 8. Data integrity

- Never invent counts, states, totals, percentages, timestamps, coordinates, or criteria. Use unknown/unavailable.
- Record provenance for every catalogue: native API, client-derived generated data, or curated by hand.
- Version generated data separately from code, with the client build it came from.
- When game state and catalogue disagree: trust the game's completion state, don't silently change totals, log in debug mode, mark the result uncertain.

## 9. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-07 | Quests deferred to v1.1 | Eligibility catalogue is a large data problem; exploration first |
| 2026-11-07 | QuestieDB approved as quest data source | Already installed; maintained Forever data |
| 2026-11-07 | Custom artwork in native style | Native zone illustrations likely unavailable |
| 2026-11-07 | Every dependency needs owner approval | Keep addon standalone |
| 2026-11-07 | English only; no public release | Personal project |
| 2026-11-07 | Addon in `Azerfolio/` subfolder, linked into AddOns | Keeps docs/tests/tools out of the game folder |
| 2026-11-07 | Diagnostics write to SavedVariables; agent reads files | Agents can read game output without the owner copying text |
| 2026-11-07 | LuaJIT approved for running tests | Lua 5.1 semantics match the client |
| 2026-11-07 | Exploration source: "Explore <zone>" achievement criteria; objective ID = `criteriaID` | Native, complete per zone, verified in game; map textures are unreliable |
| 2026-11-07 | Ship art as PNG | Verified to load in this client |
| 2026-11-07 | Phase 1 accepted; exploration is per character | Discovery and two-character tests passed (`docs/research/exploration-validation.md`) |
| 2026-11-07 | All exploration criteria count as eligible | The game marks none ineligible, even cross-faction; inventing exclusions would break the honest-data rule |
| 2026-11-07 | Refresh on `CRITERIA_UPDATE` + `MAP_EXPLORATION_UPDATED`, debounced; re-read current zone only | Observed event order on discovery |
| 2026-11-07 | Visual preview: HTML mockups for design, addon-taken screenshots for verification | A full out-of-game WoW UI emulator would cost weeks and still be approximate |
| 2026-11-07 | `Screenshot()` verified for addons | Phase 2 in-game check |
| 2026-11-07 | Gamepad first (spec §4.3), with an addon-owned input layer; never use Blizzard `SmartNavigation` | Owner plays with a controller; SmartNavigation needs secure callers and risks taint |
| 2026-11-07 | Zone art: one 1024×512 PNG per zone, cropped in the UI with texture coordinates; style and safe area in `art/style-guide.md` | One file serves all four layouts; small addon footprint |
| 2026-11-07 | UI design follows `mockups/DESIGN.md`: state language, pips, Continue card, Atlas, zone map, wide split view, completion celebration | Owner approved the full UX review |

## 10. Definition of done (v1)

The owner can: install by running the link script; open a polished native-style window; see character info and trustworthy progress; switch between Overview and Zones; browse illustrated cards or the compact list; search, sort, filter; open a zone and see its exploration checklist; discover an area and watch progress update; go back without losing their place; reload or restart without losing preferences; and tell at a glance when data is incomplete or unavailable — all without noticeable performance cost.
