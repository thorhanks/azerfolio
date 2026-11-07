# Azerfolio — Product Specification

**Version:** 0.3
**Target:** World of Warcraft: Forever (client flavor `wowf`, addon interface `16001`)
**Audience:** Personal use. Not published to CurseForge or other distribution sites.
**Development:** Built entirely by AI coding agents; a human runs the game client for in-game validation.
**Tagline:** Every adventure. Every achievement. Every step.

## 1. Vision

Azerfolio is a completionist dashboard and progression journal for WoW Forever. It answers three questions:

1. What have I completed?
2. What remains?
3. What should I do next?

It presents progress as attractive dashboards and actionable checklists, in a visual style that looks like Blizzard's own UI (Encounter Journal / Adventure Guide, parchment and gold).

## 2. Principles

These are hard rules. When a requirement elsewhere conflicts with one of these, the principle wins.

| # | Principle | Rule |
|---|---|---|
| P1 | Honest data | Never show a completion state, count, total, percentage, or timestamp that the game did not confirm. Unknown is displayed as unknown, never as 0% or 100%. |
| P2 | Completion first | Every screen leads with progress. Every statistic is clickable through to the objectives behind it, where a detail view exists. |
| P3 | Native look | Looks like an official WoW interface. No generic web-dashboard aesthetics. |
| P4 | Minimal dependencies | No required addons. Any dependency, including embedded libraries, needs explicit approval from the project owner before it is added. |
| P5 | Character-aware | Objectives a character can never complete (faction, class, exclusive choices) are excluded from that character's totals, so 100% is reachable. |
| P6 | One source of truth | Progress is calculated in one place. UI code only displays results; it never calculates progress. |
| P7 | Cheap at runtime | Event-driven updates and cached results. No polling loops, no per-frame scans, no full rescans when one zone changed. |
| P8 | Expandable | Adding a new category (class, professions, dungeons, collections, Legacy) means adding a provider, not redesigning. |

## 3. Release scope

### v1 — Overview + Zones (exploration)

- Main window with bottom tabs: **Overview** and **Zones**. Zone Detail is a subview of Zones.
- Character header.
- Overview dashboard: tracked completion, stat cards, zone highlights, suggestions, recent milestones.
- Zone catalogue: illustrated card view (default) and compact list view, filters, sorting, search.
- Zone Detail with an exploration checklist.
- Exploration tracking implemented by Azerfolio itself.
- Saved UI preferences.
- English only.

### v1.1 — Quests

- Quest tracking per zone, using QuestieDB as the quest catalogue (see §8.4).
- Quest stat card, quest section on Zone Detail, quest suggestions.

### Later (architecture must allow, do not build)

Class progression, professions, collections, dungeons and raids, rares and world bosses, Legacy progression, reputations, account-wide and cross-character views, custom goals, smarter recommendations, waypoint integration, localization.

### Out of scope

Public release and packaging, network or cloud features, sharing between players, route optimization, gear/talent advice, required third-party addons.

## 4. Main window

### 4.1 Look

- Ornate Warcraft-style outer frame with gold trim.
- Parchment, leather, and stone surfaces.
- Blizzard-style buttons, tooltips, progress bars, scrollbars.
- Readable, high-contrast text over every background.
- Clear visual difference between completed and unfinished content.
- Restrained decoration; content comes first.

**Art policy:** Azerfolio uses its own artwork, created in the style of native Blizzard art and bundled with the addon. Native client textures (frames, buttons, icons, fonts) may be used where they exist and fit. Zone illustrations are custom. Every zone without finished art shows one consistent fallback.

### 4.2 Behavior

- `/azerfolio` and `/azf` toggle the window.
- Launcher: a minimap button and/or the addon compartment. Left-click toggles; tooltip names the addon.
- Draggable; resizable between a minimum and maximum size.
- Remembers position, size, and last tab. First launch opens Overview.
- Escape closes it.
- Never performs protected actions; safe to open in combat.
- Recovers if saved position is off-screen after a resolution or UI-scale change.

### 4.3 Gamepad

Azerfolio is **gamepad first**: the owner plays with a controller. Everything must be usable without a mouse, and the mouse must keep working too.

- **Open/close:** a key binding (bindable to a controller button combo) as well as `/azf`.
- **Focus:** the D-pad moves a clearly visible gold focus highlight between controls in a predictable order (rows and columns, not guesswork). Focus starts on a sensible element on each screen and is restored when returning to a screen.
- **Buttons:**

  | Input | Action |
  |---|---|
  | D-pad / left stick | Move focus |
  | A (bottom face) | Activate the focused control |
  | B (right face) | Back (Zone Detail → catalogue), otherwise close the window |
  | LB / RB | Previous / next main tab |
  | Right stick | Scroll the current list |
  | Y / X | Context actions (e.g. toggle card/list view, open filters), shown in a hint bar |

- **Hint bar:** the bottom of the window shows which buttons do what on the current screen.
- **No hover-only information:** anything a mouse user sees on hover (tooltips, percentage explanations) also appears when the control has gamepad focus.
- **Size:** focusable controls are large enough to read and to show a focus border clearly.
- **Text entry:** zone search must be usable from a controller (the client's on-screen keyboard if available), and every filter must be reachable without typing.
- **Combat:** custom gamepad input is released in combat so it never blocks gameplay.

### 4.4 Navigation

- Bottom tabs: Overview, Zones. No tabs for features that don't exist yet.
- Zone Detail has a back button to the catalogue.
- Returning to the catalogue restores search, filters, sort, display mode, and scroll position.

## 5. Overview tab

### 5.1 Character header

Name, race, class, faction, level, XP progress toward next level (when not max level), and portrait or class icon.

### 5.2 Tracked Completion

A prominent percentage of *supported, eligible* objectives completed. It is labeled as tracked completion, not "completion of WoW", and lists which categories it includes (v1: exploration only).

Calculation:
- Numerator: objectives the game confirms complete.
- Denominator: eligible objectives plus locked-but-achievable ones.
- Excluded: permanently unavailable objectives, unknown objectives, categories without a complete catalogue.
- Each objective counted once, even if it appears in several zones or categories.

If no meaningful percentage can be produced, show a labeled unavailable state.

### 5.3 Stat cards

| Card | Shows | Click opens |
|---|---|---|
| Zones | Fully completed zones / applicable tracked zones, % | Zones tab filtered to completed |
| Exploration | Discovered / total exploration objectives, % | Zones tab |
| Current Zone | Name, tracked %, remaining objectives | That Zone Detail |
| Quests (v1.1) | Confirmed completed / known eligible, coverage note | Zones tab |

A card without a meaningful value shows an explanatory empty state, never a bare `0%`.

### 5.4 Zone highlights

Current zone, recently visited zones, zones closest to completion, recently completed zones. Each entry shows name and a compact progress indicator, and opens Zone Detail.

### 5.5 Suggested next objectives

A few unfinished objectives chosen by fixed rules, in this order:
1. Unfinished objectives in the current zone.
2. Objectives in zones close to completion.
3. Other eligible unfinished exploration objectives.
4. (v1.1) Eligible unfinished quests.

Each suggestion shows objective name, zone, category, a short reason ("2 left in Westfall"), and opens its detail. Never suggest objectives that are unavailable or of unknown eligibility. Show an empty state if nothing qualifies.

### 5.6 Recent milestones

Recently detected accomplishments: a new area discovered, a zone's exploration completed, (v1.1) a quest completed, a zone fully completed.

- Stored in SavedVariables, history size capped.
- Progress that existed before the addon first saw the character is a baseline, not a milestone. No invented timestamps.
- Deduplicated across reloads.

## 6. Zones tab

### 6.1 Display modes

| Illustrated cards (default) | Compact list |
|---|---|
| Large zone art, consistent aspect ratio | Small art or icon |
| Name, level range, faction applicability | Name, % |
| Tracked %, progress bar, exploration progress | Compact progress bar, key metrics |
| Completion emblem when justified | Dense; easy to compare many zones |

Both modes use the same data, filters, and sort. The chosen mode is saved. The card grid adapts to window width without cards becoming unreadably small.

### 6.2 Filters

- **Faction relevance:** Relevant to my character (default) / All zones. Never hides contested or neutral zones from either faction.
- **Completion:** All / Incomplete / Completed. Zones with unknown status are not counted as "Incomplete".
- **Level:** All / Appropriate for my level.
- **Search:** case-insensitive name match.

### 6.3 Sorting

Recommended progression order (default, by level range then stable tie-break), alphabetical, highest completion, lowest completion, closest to completion. Zones without completion data sort separately from zones with a confirmed 0%.

### 6.4 Behavior

Scrollable; tooltips explain each percentage; helpful empty state when filters match nothing; state preserved across navigation.

Zone relevance (should this zone be listed for my character?) and objective eligibility (can I complete this objective?) are calculated separately.

## 7. Zone Detail

### 7.1 Header

Large zone illustration, name, level range, faction applicability, tracked %, progress bar, back button.

### 7.2 Exploration section

Total, completed, remaining, %, and a checklist. Each row: location name, completed/incomplete indicator, and extra info or map guidance where available. All completion comes from game data, never from tracking the player's movement.

### 7.3 Quest section (v1.1)

Total known eligible, completed, remaining, % when valid, checklist (name, level, status, eligibility, prerequisites and chain where known), and a coverage indicator. Repeatable quests never count toward totals. Mutually exclusive quests are handled. If quest data is incomplete, say so.

### 7.4 Objective states

Each objective has two independent properties:

| Completion | Meaning |
|---|---|
| Complete | Game confirms it is done |
| Incomplete | Game confirms it is not done |
| Unknown | Cannot be determined |

| Eligibility | Meaning |
|---|---|
| Eligible | Can be done now |
| Locked | Not yet, but will become possible (level, prerequisite) |
| Unavailable | Never possible for this character (faction, class, exclusive choice) |
| Unknown | Cannot be determined |

The UI derives what it shows from these two. Unknown never silently counts as complete or incomplete.

### 7.5 Completion claims

- **Tracked Objectives Complete:** every included, eligible, tracked objective in the zone is verified complete.
- **Zone Complete:** the above, *and* every category the zone should have has a complete catalogue.

Never show or celebrate Zone Complete when any category has unknown or partial coverage.

### 7.6 Map actions

Where supported: open the world map to this zone, show where an exploration objective is, tooltips on objectives.

## 8. Data architecture

### 8.1 Layers

1. **Game-state readers** — wrap client APIs; the only code that calls them.
2. **Static catalogues** — bundled Lua data (zones, exploration, later quests).
3. **Eligibility** — decides eligibility state per objective for this character.
4. **Completion** — decides completion state per objective.
5. **Aggregation** — one progression service computes all counts, percentages, coverage.
6. **Presentation** — UI pages and components; read-only consumers of aggregation results.

### 8.2 Objective model

Each objective has: stable ID, category, zone, display name, optional description, eligibility requirements, completion state, data source, coverage classification, optional map location, optional grouping/prerequisites. Providers fill only the fields relevant to them.

### 8.3 Exploration

Implemented by Azerfolio; no dependency on other addons. Prefer native completion signals (achievement/Legacy criteria) over inferring from revealed map textures. The approach is decided by the Phase 1 findings (see the implementation plan). If an objective can't be verified, its completion is unknown.

The bundled exploration catalogue uses game IDs (not names) as keys, is versioned, and is generated reproducibly where practical.

### 8.4 Quests (v1.1)

- Completion: client quest-completion APIs.
- Catalogue: QuestieDB (installed on this machine). Whether Azerfolio reads it at runtime as an optional dependency or extracts data from it at build time is decided at the start of v1.1. Note that QuestieDB is GPL-3.0 licensed; either approach is fine for personal use.
- Must handle faction, class, profession, prerequisites, exclusive choices, repeatables, breadcrumbs.
- A partial catalogue is never presented as exhaustive.

### 8.5 Aggregation output

For any scope (objective set, zone, category, overall): completed, eligible, locked, unavailable, unknown counts; percentage if valid; coverage (`complete` / `partial` / `unavailable`); categories included.

### 8.6 Events

Listen for zone changes, exploration changes, quest changes, and login. Invalidate only affected cached results. Provide `/azf refresh` for cases where events are missing.

### 8.7 Persistence (SavedVariables)

Window position/size, last tab, Zones display mode, filters and sort, milestone history, recently visited zones, preferences. Versioned schema with migrations. Completion state is read from the game, not stored.

## 9. Technical requirements

- Target the actual Forever client. Do not assume Retail or Classic APIs exist; check, and degrade gracefully when an API is missing or returns unexpected data.
- Modular Lua files; the plan defines the layout.
- Reuse frames; efficient scrolling; cache expensive calculations.
- Errors in one section must not stop the window from opening.
- Debug mode (off by default) reports map and zone IDs, exploration criteria, eligibility decisions, aggregate counts, missing data, API failures.
- English only. Strings shown to the player that the client provides (zone and area names) come from the client.

## 10. UX requirements

- Clear progress indicators, high-contrast text, consistent spacing, tooltips for non-obvious numbers.
- On completing a tracked objective: refresh affected indicators and summaries, record a milestone, optionally show a subtle notification (configurable).
- Satisfying completion visuals (gold accent, emblem, full bar) when justified; no celebration when coverage is incomplete.
- Distinct visible states for: no matching zones, no tracked objectives, loading, data unavailable, partial coverage, fully complete.

## 11. Privacy

Runs entirely in the game client. No accounts, network, cloud, companion apps, or uploads.

## 12. Acceptance criteria (v1)

### Window
- [ ] `/azerfolio` and `/azf` toggle the window; launcher button works; key binding works from a controller.
- [ ] Every screen and action is usable with the gamepad alone (spec §4.3), with a visible focus highlight and hint bar.
- [ ] Draggable, resizable; position and size persist.
- [ ] Overview and Zones tabs work; Escape closes.
- [ ] Cohesive native Warcraft style.

### Overview
- [ ] Accurate character info.
- [ ] Tracked completion with listed categories; unavailable data clearly marked.
- [ ] Current-zone progress with link to Zone Detail.
- [ ] Suggestions only from eligible, known objectives.
- [ ] Milestones recorded only for progress observed after baseline.

### Zones
- [ ] Applicable zones listed; illustrated cards by default; compact mode; mode persists.
- [ ] Faction and completion filters, search, sorting.
- [ ] Zone Detail opens; back restores catalogue state.

### Exploration
- [ ] Azerfolio's own tracking; no other addon required.
- [ ] Verified per-objective states; discovered vs. undiscovered correct.
- [ ] Refreshes when a new area is discovered.
- [ ] Missing data never produces a false completion claim.

### Quality
- [ ] No Lua errors in normal use.
- [ ] No noticeable performance impact during gameplay.
- [ ] SavedVariables survive reloads and restarts; invalid settings recover to defaults.
- [ ] Usable across supported window sizes and UI scales.
- [ ] Automated tests pass for pure-logic modules.

### v1.1 Quests
- [ ] Reads quest completion; shows known quests per zone.
- [ ] Eligibility rules applied; repeatables and unavailable quests excluded from totals.
- [ ] Incomplete coverage clearly labeled; no unverifiable total presented as complete.

## 13. Definition of v1 success

A player opens Azerfolio and immediately understands their progress through Azeroth. They browse illustrated zones, switch to the compact list, open a zone, see verified exploration progress, and find what's left. When they discover a new area, the numbers update correctly. It looks good, it's standalone, and its numbers can be trusted.
