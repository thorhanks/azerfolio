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
│   │                       ExplorationTracker, Recommendations
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
| 10 | Celebrations and the Atlas (v1.2) | H |
| 11 | Zone reputation (v1.3) | I |
| 12 | Reputation tab (v1.4) | J |

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
4. Launcher: addon compartment entry (needs no library) and a lightweight minimap button written in-house. Persist button position. (A key binding via `Bindings.xml` was built here and removed on 2026-11-08.)
5. Escape-to-close (register in `UISpecialFrames`), position persistence, off-screen recovery.
6. **Gamepad input layer** (`UI/Gamepad.lua`), addon-owned, following spec §4.3:
   - An input frame on the window with `EnableGamePadButton`/`EnableGamePadStick`, active only while the window is shown, the gamepad UI is on, and the player is out of combat.
   - **Do not use Blizzard's `SmartNavigation`.** Its registration (`HandlePanelOpen`) and setters require secure callers, and other Forever addons report that touching it taints protected action-bar code (see `docs/research/client-capabilities.md` § Gamepad).
   - Each page declares its focus targets as an explicit grid (rows × columns). The layer moves focus within that grid, draws the gold focus border, shows the focused control's tooltip, and scrolls lists to keep focus visible.
   - Hint bar component at the bottom of the window.
   - Pure focus-grid logic (`UI/FocusGrid.lua`) unit-tested without WoW.
7. `/azf shots`: open the window and screenshot each tab and state for agent review (plan §4.3).

**Done when:**
- [x] Opens from both commands, the launcher and the key binding; tabs switch with mouse and LB/RB. (Owner, in game.)
- [x] D-pad focus, A, B and the hint bar work on every screen; input is released in combat. (Shots in game; combat release covered by tests.)
- [ ] Drag, resize, and persistence work across reload and relog. (Reload verified in game; relog not checked separately.)
- [ ] Escape closes; no errors opening during combat. (Covered by tests; not tried in game.)
- [x] Repeated open/close and navigation cause no frame leaks. (Tests count frames.)

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
- [x] Elwynn Forest works end to end: correct states, correct %, updates on discovery, survives reload. (In game.)
- [x] No milestones generated for pre-existing progress. (In game.)
- [x] Unknown never counted as complete or incomplete. (Tests; the game returned no unknown areas.)

### Phase 6 — Zones catalogue and Zone Detail

**Tasks**
1. Zone metadata (`Data/Zones.lua`): map ID, name (from client), faction applicability, level range (only where reliable), progression order, art key, categories, coverage. Don't guess level ranges or faction.
2. Catalogue page: scrollable, illustrated cards (default) and compact list, mode toggle, filters, sort, search, empty state. Reuse frames while scrolling.
3. Zone Detail: header, exploration section with checklist, map action where supported, back navigation.
4. Empty states: no matches, no objectives, unsupported zone, partial coverage, fully complete, unavailable.

**Tests:** filtering, sorting (including unknown handling and stable ties).

**Done when:** Spec §12 "Zones" and "Exploration" criteria pass in game. *(Met 2026-11-07, Gideon and Thragor; see `docs/testing.md`.)*

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

**Done when:** All spec §12 v1 criteria are checked off with evidence in `docs/testing.md`. *(Met 2026-11-08; v1 = version 1.0.0.)*

### Phase 9 — Quests (v1.1)

**Tasks**
1. Decide QuestieDB integration: runtime optional dependency vs. build-time extraction. Inspect its data format and load cost first. Record the decision. *(Done 2026-11-08: runtime optional dependency.)*
2. Quest completion reader (`C_QuestLog.IsQuestFlaggedCompleted`; completed-quest list API if present). Events for turn-in.
3. Quest catalogue per zone: ID, name, zone, faction, class, profession, prerequisites, type, repeatable, exclusive groups.
4. Eligibility: completed / available / locked / unavailable / unknown. Never infer "unavailable" just because a quest isn't in the log.
5. Counts exclude repeatables and unavailable alternatives; unknown eligibility lowers coverage.
6. Zone Detail quest section, quest stat card, quest suggestions. *(Done 2026-11-08: Zone Detail in steps 4-5; the Overview's Tracked completion rows and Next up suggestions in step 6.)*
7. Zone completion across categories (spec §7.7): zone medallion, per-category bars in the catalogue, combined state for filters and sorts. *(Added 2026-11-08.)*
8. Flight paths per zone (spec §8.5), after a probe shows the client can confirm them. *(Added 2026-11-08.)*

**Done when:** Spec §12 "v1.1 Quests" criteria pass. If full coverage risks stability, ship a clearly labeled subset.

### Phase 10 — Celebrations and the Atlas (v1.2)

Owner request 2026-11-08, after v1.1.

**Tasks**
1. Celebrations (spec §7.7, DESIGN.md "Celebrations"): a category of a zone completing (the streamer it earns) or the zone being claimed, seen while you play; full-window overlay with the window open, an on-screen alert with it closed. *(Done 2026-11-08.)*
2. Atlas view (DESIGN.md "Zones: Atlas"): mockup review, positions from verified map data, then Lua. *(Done 2026-11-08.)*

**Done when:** both checked in game and approved by the owner. *(Done 2026-11-08: closed as 1.2.0.)*

### Phase 11 — Zone reputation (v1.3)

Owner's choice 2026-11-08. Spec §7.8, §8.9; research `docs/research/reputation.md`.

**Tasks**
1. Research and probe: zone factions from quest rewards (`qdb.lua reps rule`), `C_Reputation` on Forever (`/azfdiag reps`). Decisions recorded: derived zone factions, not a completion category, hidden where there's none. *(Done 2026-11-08.)*
2. Mockup: the reputation section on the zone dashboard (reaction, bar, Not met yet, at war, gamepad focus), sample data from the survey. Owner review before Lua. *(Done 2026-11-08: ledger, reaction ladder, rivals, faction page.)*
3. Systems: a pure zone-faction rule (tested on fixtures) and `Systems/Reputation` (index from `Quests`' zone data, standing reader guarded with `pcall`, `UPDATE_FACTION` debounced, met list read without changing the player's headers).
4. UI: the section on Zone Detail, following the approved mockup; `/azf debug reputation` trace.
5. In-game check on Gideon and Thragor: standing matches the game's Reputation window, updates after a quest turn-in, the other side's factions hidden. Settle the open questions (faction 471; Zandalar, Hydraxian Waterlords and Brood of Nozdormu with no data).

**Done when:** the section shows correct, game-confirmed standing for every zone faction on both characters, never touches the combined %, and the owner approves.

### Phase 12 — Reputation tab (v1.4)

Owner's choice 2026-11-09, after Phase 11 task 5. Spec §7.9, §8.10; design `mockups/DESIGN.md` "Reputation tab" and "Gold beyond completion"; mockup code `mockups/app.js` ("Reputation tab (Phase 12 proposal)": `allFactions`, `renderReputation`, `renderFactionInto`, `repDist`, `toggleWatch`) and `mockups/style.css`; research `docs/research/reputation.md`. Phase 11's open checks R1 and R2 stay open and are checked where Phase 11 asks; they don't block this phase.

**Tasks**
1. Design analysis, mockup and art: every faction the game returns data for, grouped by where their quests are, the standing strip, the faction page with the reach, the rival seesaw, where to raise it, X to watch. Art: `icon-reputation`, `frame-plaque`, `plaque-fill-cloth`, eight `rep-<reaction>` emblems (iron to gold). *(Done 2026-11-09: mockup approved by the owner; art processed and committed.)*
2. Plan and spec: this phase, spec §7.9 and §8.10, decision log. *(Done 2026-11-09.)*
3. Systems: extend the pure `Systems/ReputationRules` (group by where most raising quests are; reach = standing + the base amounts of one-time quests not done and eligible, capped at Exalted; repeatables counted separately, never in the reach; class-only sources flagged "not for you"; sorts By group, Closest to next with met first, A–Z) and `Systems/Reputation` (`All()`: every faction `C_Reputation.GetFactionDataByID` returns, the other side's battleground factions 510 / 729 / 2798 and the Alliance / Horde headers left out by side; sources per zone, dungeon, raid, battleground, profession, class and event from QuestieDB `reputationReward`; gains seen this session from `UPDATE_FACTION` snapshots, in memory only; watched from `isWatched`). Tests on fixtures; pure modules load without WoW globals. *(Done 2026-11-09; checked in game with task 5.)*
4. UI: `UI/Pages/Reputation.lua` as the third tab (painted `Media\Icons\icon-reputation.blp`): toolbar (All / Met / Not met yet, Sort, Y cycles it), the standing strip (`frame-plaque` nine-slice around `plaque-fill-cloth` tinted in the reaction colour, `rep-<reaction>` emblems, "Met n of m · Exalted n of m"), grouped rows with sticky headers (LT/RT), zone-art thumbnails, tags (Not met yet, At war, Rival of, "+n today", Watched), the faction page (banner, bar with the reach ghost and its dashed end mark, the reach sentence, the game's description, the rival seesaw, Where to raise it), X to watch (`C_Reputation.SetWatchedFactionByID`, guarded; open check until seen in game), the wide split view, focus and legend as designed. Exalted becomes gold everywhere, the zone ledger included (`Theme` reaction colours, `Widgets.RepBar`). The tab joins `/azf shots`. *(Built 2026-11-09; checked in game with task 5.)*
5. In-game check on Gideon (`/azf shots reputation`): the list matches the game's Reputation window for met factions, filters and sorts, the strip's counts, the faction page, watching from X, both window widths. Checks that need real play (a session gain, a rank-up) go to `docs/open-checks.md`. *(Done 2026-11-09 on Gideon: two shot rounds, Watch confirmed by the owner; T2 and T3 wait on play.)*

**Done when:** the tab lists every faction the game returns data for on this side with game-confirmed standing, the reach and sources come from QuestieDB and are marked approximate, X watching works in game (or is shown as unavailable), nothing touches combined zone completion, and the owner approves.

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
| 2026-11-07 | Zone art: one 1024×512 image per zone, cropped in the UI with texture coordinates; style and safe area in `art/style-guide.md` | One file serves all four layouts; small addon footprint |
| 2026-11-07 | Ship zone art as BLP2 DXT1 with mipmaps (in-house encoder `tools/Blp.cs`); commit only the BLPs | 17 MB instead of 67 MB PNG; native format; no new dependency; verified in game |
| 2026-11-07 | UI design follows `mockups/DESIGN.md`: state language, pips, Continue card, Atlas, zone map, wide split view, completion celebration | Owner approved the full UX review |
| 2026-11-07 | **Full native look**: match the Forever UI (gold glowing frame, round portrait, dark brown panes instead of parchment, native tabs, prompts and focus pointer). Probe the live frames first (`/azfdiag skin`), then update the mockup, then Lua | Owner's request; native look fits the gamepad UI. Supersedes the parchment and custom chrome in `mockups/DESIGN.md` once the new mockup is approved |
| 2026-11-07 | Native-look mockup approved: portrait frame, character strip, dark panes, right-side tabs with LB/RB, legend box below the frame, chevron focus pointer. `mockups/DESIGN.md` maps each part to its native template or atlas | Owner approval; next is the Lua restyle of the window shell, then Phase 4 step 2 |
| 2026-11-07 | Window default 1160×740 (account schema 2); footer tabs are custom buttons, not `PanelTabButtonTemplate` | The design lays out at 1160×740 and puts tabs inside the footer with LB/RB glyphs; the template hangs tabs below the frame |
| 2026-11-07 | Wide split view is automatic: Zones splits (list 560 + detail) when the window is at least 1440 wide; no setting | The owner's ultrawide fits it; resizing is the switch, and the narrow layout stays unchanged |
| 2026-11-07 | Banner crop offsets live in `Theme.bannerFocus` (fraction of art height), tuned from in-game shots (`/azf shots banners`) | `Data/Art.lua` is generated; offsets are a UI concern; 7 zones need one |
| 2026-11-07 | Phase 4 accepted (all 5 steps verified with in-game shots) | Relog persistence and Escape/combat opening rest on tests, not a separate in-game check |
| 2026-11-07 | Exploration catalogue: `Data/Exploration.lua` generated by `tools/gen-exploration.lua`, keyed by mapID, IDs only (names live from the client); zones with no entry are "not tracked" | Reproducible from the dump; lets the tracker detect patch changes to a zone's criteria |
| 2026-11-07 | Progression rules: denominator = eligible + locked objectives with known completion, from categories whose coverage is complete; a category with any partial set is left out of the percentage; duplicates count once (by category + ID) and conflicting duplicates become unknown; percentages round down | Spec §5.2 and §7.5; rounding up could show 100% before it's true |
| 2026-11-07 | Tracker finds zones by mapID in the catalogue; live criteria that differ from it are trusted and flagged `uncertain` (counts unchanged); a criterion without an ID makes the zone `partial` | Plan §8: trust the game, don't silently change totals, mark uncertain |
| 2026-11-07 | Milestones only for a confirmed not-discovered → discovered change against a per-zone baseline of confirmed states; every zone is read once after login to set it; only changes seen live get a time | Spec: no milestones for pre-existing progress, no timestamps the game didn't confirm |
| 2026-11-07 | Phase 5 accepted; the separate step 5 check wasn't run | Steps 3 and 4 met every done-when item in game; the owner closed the phase on that evidence |
| 2026-11-07 | Debug mode writes a capped trace to `AzerfolioDB.trace` (100 entries, addon state only) | In-game results are read from files (plan §2.1) |
| 2026-11-07 | Zones catalogue logic lives in `Systems/Zones.lua`; no `Data/Zones.lua` until a verified level or faction source exists (probe `/azfdiag zones` first) | Everything else in the planned metadata (name, continent, art, categories, coverage) already comes from the client, the catalogue and `Data/Art.lua`; don't guess levels or faction |
| 2026-11-07 | No level ranges or faction territory from the client (`GetMapLevels` all zeros, no `GetZonePVPInfo`); they stay unknown and their filters aren't offered unless the owner approves a hand-curated source | Probe `/azfdiag zones`; honest-data rule |
| 2026-11-07 | Level ranges: hand-curated `Data/Zones.lua` from the Warcraft Wiki "Zones by level (Classic)" page, provenance in the file; the four Forever-only zones from the owner; capitals stay unknown; shown as a guide, not game data | Owner approved an unofficial guide ("doesn't have to be perfect"); the client has none |
| 2026-11-07 | Phase 6 accepted: catalogue, Zone Detail and the world map verified in game on both characters | Step 4 check; the narrow-toolbar fix rests on tests |
| 2026-11-07 | Faction territory: hand-curated `Data/Zones.lua` `faction` from each zone's Warcraft Wiki (Classic) page; zones both factions quest in stay Contested even where the wiki's Affiliation names one; no entry = shown to both | Owner approved an unofficial source; a wrong "faction" value would hide a zone, a wrong "Contested" hides nothing |
| 2026-11-07 | Overview picks live in pure `Systems/Overview.lua` over `ns.Zones` entries; suggestions only from areas confirmed not discovered and eligible, other faction's territory left out except the current zone; "applicable zones" = tracked and not the other faction's territory | Spec §5.3-5.5; one source of numbers for Overview and Zones; unknown never suggested |
| 2026-11-07 | Recent zones replace the design's Atlas thumbnail on the Overview until the Atlas view exists; visits are recorded per character (tracked zones, newest 10) | The thumbnail's only action is opening the Atlas, which isn't built; spec §5.4 asks for recently visited zones. Owner approved |
| 2026-11-07 | On `MAP_EXPLORATION_UPDATED` with no change in the current zone, re-read every zone read before | An area can belong to another zone than the map it's discovered on (Elwynn's "Stormwind City") [verified-ingame]; the event is rare (discoveries, and once on entering a zone [verified-ingame]) |
| 2026-11-07 | Phase 7 accepted: spec §12 "Overview" verified in game on Gideon | Discoveries, zone completion, visits and the Overview's numbers checked from SavedVariables and shots |
| 2026-11-07 | Zone Detail opened from the Overview returns to the Overview on B | Focus is restored when returning to a screen (DESIGN.md); the owner came from the Overview |
| 2026-11-07 | Completion filter = the design's status segments (All / In progress / Untouched / Complete), account schema 4; unknown and untracked zones show only under All; a filter whose data is unknown everywhere isn't offered | Approved design; spec §6.2 (unknown is never "incomplete"); a filter that can't filter is noise |
| 2026-11-07 | Performance counters only in debug mode, via the event dispatcher (`/azf debug perf`); client memory and profiler metrics read only where the client has them | Plan Phase 8 task 3 asks for callback counts in debug mode; no cost when debug is off; the profiler's metric names aren't verified, so every enum value is read |
| 2026-11-07 | The re-read after `MAP_EXPLORATION_UPDATED` skips fully explored zones | A discovery can't be undone, so they can't change; cuts the Phase 7 known cost as zones complete |
| 2026-11-07 | Level-dependent pages listen to `AZF_LEVEL_CHANGED`, not `AZF_CHARACTER_UPDATED` | XP updates fire on every kill; only the header shows XP |
| 2026-11-07 | Zone Detail of a fully explored zone has no "To discover" section; the "Fully explored" note replaces it | Owner's request after the Phase 8 visual review: an empty "0 areas" header looked unfinished |
| 2026-11-07 | Malformed milestone and recent-zone entries are dropped on load | A damaged file must not break the Overview; a bad time is removed, never replaced (honest data) |
| 2026-11-08 | Key binding removed (`Bindings.xml`, `Azerfolio_Toggle`); spec §4.3 and the §12 Window criterion no longer ask for one | Opening from a controller-bound key didn't work in game, and the owner doesn't need a key binding; `/azf`, the minimap button and the compartment open it |
| 2026-11-08 | Quest catalogue: read QuestieDB **at runtime** as an optional dependency (`## OptionalDeps: QuestieDB`, `LibQuestieDB.RequireContract(4)`, `QuestDB` field readers), not build-time extraction. Without it, or on a contract mismatch, quests are "unavailable" with the reason; exploration never depends on it | Probe (`docs/research/quest-data.md`): only the runtime view has the Forever corrections (43 quests change zone); a full scalar read costs 36 ms once and under 1 MB; nothing added to the repo; follows QuestieDB updates. Owner approved |
| 2026-11-08 | Quest model: (1) dungeon quests QuestieDB maps onto an outdoor zone (Gnomeregan, Zul'Farrak, Uldaman, Razorfen Kraul) are left out of that zone's count, with a coverage note; (2) capitals get a quest section; (3) unmapped areas: a small hand-curated, unofficial area → zone table, owner-approved, only for clear subzones (Excavation Site: Wetlands → Wetlands); the rest left out with a note; (4) class, profession and holiday quests (negative sorts) left out of zone counts, with a note; (5) Darkspear Islands (uiMap 2524, map type 6) added as a quest-only zone without exploration | Azerfolio has no dungeon pages and dungeon quests aren't done in the open zone; capitals have many quests (Stormwind 131); a few areas are plainly parts of a zone; sort quests have no zone; Darkspear Islands has 18 quests. Every exclusion is counted, so the note stays honest. Owner approved the proposed defaults |
| 2026-11-08 | Dungeon and raid quests are kept per instance in the quest index (not in zone counts) for a Dungeons tracking tab the owner plans later. Areas → zones come from our own curated `Data/QuestAreas.lua`, not QuestieDB's private `ZoneDB` tables | Owner's note: dungeon quest tracking belongs on a future Dungeons tab. QuestieDB's zone tables sit under `private` (not in the contract); a static table from the probe's 100 areas is checked, testable and survives QuestieDB changes; new areas show up as "unmapped" in `/azf debug quests` |
| 2026-11-08 | Quest eligibility rules (`Systems/QuestRules.lua`): race/class masks, level, exclusive choices, chains, breadcrumbs, parent quests and recursive prerequisites decide eligible / locked / unavailable; profession, reputation and spell requirements, races past 9 (Skyborne) and missing data are unknown and left out of totals. A zone's quest set counts as complete coverage when every quest was read without error: QuestieDB is the catalogue, and the coverage note names it and lists what's left out | Field meanings from QuestieDB's own type docs; unknown is never guessed (spec §7.4). Known gap: QuestieDB has no list of quests that can't be obtained on Forever, so such quests would show as remaining; to be found in game and handled with a curated list if needed |
| 2026-11-08 | Darkspear Islands is left out like the other battlegrounds (reverses quest-model point 5): not in the zone list, its quests counted under "battleground" | It's a PvP battleground (map type 6 like Warsong Gulch); its 18 quests are level-bracket PvP quests, one set per faction (offline decode of QuestieDB). Owner approved |
| 2026-11-08 | Zone completion is holistic (spec §7.7): exploration, quests and flight paths are categories; a zone's % is the equal-weight average of the categories that apply to it; a category that doesn't apply is left out (never 0%); gold "Zone Complete" only when every applying category is 100% with complete coverage. Shown as a zone medallion (one ring per category) on Zone Detail and the Overview, thin per-category bars in the catalogue | Owner: exploration alone shouldn't be the headline. Weighting by objective count would let 68 Elwynn quests drown 12 areas; equal weight keeps every category visible. Design review in session, owner approved the direction |
| 2026-11-08 | Quest section redesigned before Lua (spec §7.3): "Ready now" with the client's difficulty colours, then storylines built from QuestieDB chain links, finished chains folded, can't-do quests behind a toggle, coverage as a footer. Replaces the status-bucket checklist mocked up first | Design review: the bucket list split chains across sections and gave most space to done quests; players think in storylines and "what next". Owner approved the direction |
| 2026-11-08 | Zone Detail becomes a dashboard (war banner plus one tile per category; A opens each category's full page, B steps back). Zone progress is shown as the player's faction war banner hoisted up its pole, claimed at the top; replaces the medallion | Owner: the rings weren't convincing and the detail should summarise first, then drill in. The banner was picked over a crest and braziers in the mockup |
| 2026-11-08 | Flight paths count toward the zone's % like the other categories. The flight path catalogue comes from the client itself (`C_TaxiMap.GetTaxiNodesForMap`: every node on the continent with name, zone suffix and faction; 71 real nodes, `zzOLD…` leftovers ignored), not a wiki | Owner. The client's list is exact for Forever (it includes Riverglades and Mount Hyjal, which classic wikis lack) and needs no maintenance; zone assignment from the name suffix and position, with a small curated override table where needed |
| 2026-11-08 | Banner art is faction-specific: Alliance regal (gold border, fringe, tassels), Horde battle-worn (torn, patched, painted sigil, no fringe or gold) | Owner |
| 2026-11-08 | Flight path knowledge comes from the flight master's list (`TaxiNodeGetType` while the map is open: CURRENT/REACHABLE = known), remembered per character; a continent not yet seen at a flight master has unknown flight paths | Probe: `C_TaxiMap.GetTaxiNodesForMap` lists the whole continent and its `isUndiscovered` is false everywhere, so it can't tell what the character knows (`docs/research/client-capabilities.md` § Flight paths) |
| 2026-11-08 | Flight paths per zone added to v1.1 (spec §8.5), pending a probe (`/azfdiag taxi`) | Owner request. The client must confirm which nodes the character knows; otherwise the category is unavailable |
| 2026-11-08 | Phase 8 accepted; v1 closed as version 1.0.0 | Every spec §12 v1 criterion met in game (`docs/testing.md` § Phase 8); the unattributed 39.5 ms peak frame is left as a known item, not a blocker (session average 0.0016 ms per frame). Owner approved |
| 2026-11-08 | Overview (Phase 9 step 6): Tracked completion is one panel with a row per category plus Zones; the headline is `Progression.Combine` over the providers' overall results (`Exploration.Overall`, `Quests.Overall`, new `FlightPaths.Overall`); suggestions list each zone's `Zones.NextUp` picks; Next goal and the closest-zone picks use the combined counts | Spec §5.2 (v1.1 equal-weight headline), §5.3, §5.5; one source of picks for Zone Detail and the Overview. Mockup approved by the owner |
| 2026-11-08 | Activity panel and milestone tracking removed (`Systems/Milestones.lua`, the baseline, `AZF_MILESTONE`); character schema 2 deletes the saved history | Owner: not interesting enough; frees the Overview's room (spec §5.6) |
| 2026-11-08 | Focus grid: left/right from a row with nothing on that side goes to the nearest row with an item of the column on that side | The Overview's columns now differ in length; left from Zones did nothing |
| 2026-11-08 | Without QuestieDB, quests are pending ("questiedb") in every zone with another category, so none can be claimed | In game, Elwynn showed "Claimed" on exploration alone with QuestieDB off: an unverifiable complete (spec §7.7, honest data) |
| 2026-11-08 | Phase 9 accepted; v1.1 closed as version 1.1.0 | Every spec §12 "v1.1 Quests" criterion met in game on Gideon and Thragor (`docs/testing.md` § Phase 9). Owner approved |
| 2026-11-08 | "Welcome!" quests (5805, 5841-5844, 5847) left out as "excluded" (`Data/QuestAreas.lua` `excludedQuests`) | Started by the old gift voucher; the owner found none in game |
| 2026-11-08 | Celebrations come from in-memory snapshots of the Zones entries: a category known open and now complete, or a claim together with such a change; nothing saved, nothing at login; the alert waits for the window | Spec §7.7; honest data (no celebration for data that only arrived late) without bringing back the removed milestone history |
| 2026-11-08 | Atlas places: the client's zone rectangles (`GetMapRectOnMap`) read live, laid out as equal tiles at each true centre and pushed apart until none overlap; zones with no rectangle anywhere go in the sea as "Uncharted waters"; cities are full cards; Kalimdor left | Spec: positions from verified map data; the real rectangles overlap too much to draw as they are. Owner approved the mockup |
| 2026-11-08 | Celebrations round 2: painted seals in a laurel, a title ribbon and claim seals; no streamer, no light burst (tried, dropped, art deleted) | Owner's review of the in-game screens |
| 2026-11-08 | Phase 10 accepted; v1.2 closed as version 1.2.0 | Celebrations and the Atlas checked in game on Gideon. Owner approved |
| 2026-11-08 | Not tracked per zone: rares, treasures, fishing, quest storylines, bounties. Recipes wait for a Professions tab; a dungeon tile in the zone detail (art + quest progress, opens the Dungeons tab) waits for the Dungeons tab | Owner's review of the offline surveys (`qdb.lua rares/objects/recipes`): gaps in the data, no kill or loot history, little reward |
| 2026-11-08 | Reputation next. A zone's factions are derived from the reputation rewards of its quests (QuestieDB), not a hand-curated table | Owner's choice; the survey shows clear zone factions ([research/reputation.md](docs/research/reputation.md)) |
| 2026-11-08 | Reputation stays out of combined zone completion; shown as progress beside it | No "done" state below Exalted. Owner approved |
| 2026-11-08 | The reputation section is hidden in zones with no zone faction (no home-faction fallback) | A home-faction bar would repeat in every leveling zone. Owner's choice |
| 2026-11-08 | Phase 11 (zone reputation, v1.3) planned; task 1 (research) done | Spec §7.8, §8.9 |
| 2026-11-08 | Phase 11 task 2: reputation mockup approved. A ledger under Next up (one line per faction, a painted eight-step reaction ladder, Not met yet / At war / Rival tags); A opens a faction page with the zone's quests that raise it. Rivals derived from QuestieDB's negative rewards | `mockups/DESIGN.md` Zone reputation |
| 2026-11-09 | Phase 12 (Reputation tab, v1.4) planned. Mockup approved: a third tab with every faction the game returns data for, grouped by where most of its raising quests are (Home, Zones, Dungeons & raids, Battlegrounds, Professions, Class and events, No known quests), All / Met / Not met yet and three sorts, a standing strip of painted plaques and emblems, and a faction page with the reach, the rival seesaw and where to raise it | Owner approved `mockups/DESIGN.md` "Reputation tab"; the probe reads 38 IDs for Gideon, so a full view has real data |
| 2026-11-09 | The reach counts only one-time quests not done and eligible, at QuestieDB's base amounts, capped at Exalted, always shown as approximate ("about", "~"); repeatables are named but not counted; kill reputation isn't known to the addon | Honest data: base amounts leave out racial and other bonuses, and repeatables have no end |
| 2026-11-09 | X sets the watched faction (`C_Reputation.SetWatchedFactionByID`) on the player's request; Azerfolio still never changes reputation UI state by itself. Gains "today" are kept in memory for the session only | Watching is a player action the design asks for (spec §8.9 amended); a saved gain history would bring back the removed milestone store |
| 2026-11-09 | Gold isn't reserved for completion: important non-completable states may use it. Exalted is gold (label, bar, standing strip); completion keeps ✓, %, pennants and celebrations as its own cues | Owner, during the Reputation tab art review (`mockups/DESIGN.md` "Gold beyond completion") |

## 10. Definition of done (v1)

The owner can: install by running the link script; open a polished native-style window; see character info and trustworthy progress; switch between Overview and Zones; browse illustrated cards or the compact list; search, sort, filter; open a zone and see its exploration checklist; discover an area and watch progress update; go back without losing their place; reload or restart without losing preferences; and tell at a glance when data is incomplete or unavailable — all without noticeable performance cost.
