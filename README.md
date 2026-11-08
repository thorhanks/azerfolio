# Azerfolio

A native-style completionist dashboard for **World of Warcraft: Forever** (interface 16001). It shows your character's exploration of Azeroth: every zone with its own illustration, what you've discovered, what's left, and what to do next. It's built for a gamepad and works with mouse and keyboard too.

Personal project, English only, not published. Everything runs inside the game client: no network, no accounts.

## Install

1. Clone this repository.
2. Link the addon folders into the game (directory junctions, no admin rights needed):

   ```powershell
   powershell -File tools/link-addons.ps1
   ```

   The default target is `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`; pass `-AddOns <path>` for another install, or `-Unlink` to remove the links.
3. Start the game and make sure **Azerfolio** is ticked in the AddOns list at character select. Edits in the repo apply after `/reload`.

**Azerfolio Diagnostics** (`AzerfolioDiag/`) is a development probe. Leave it unticked for normal play.

## Features (v1)

- **Window:** native Forever frame (portrait, gold chrome, side tabs, legend box with the info line and button hints). Drag, resize (1000×640 up to 1800×1100), position and size saved. Escape closes it. From 1440 wide the Zones tab splits into the list and Zone Detail side by side.
- **Opening:** `/azf` or `/azerfolio`, the minimap button (drag it around the edge; `/azf minimap` hides it), or the addon compartment. There's no key binding.
- **Gamepad:** LB/RB switch tabs, D-pad moves focus, A selects, B goes back or closes, LT/RT jump between sections, X searches (type with the keyboard: the client opens no on-screen keyboard) or opens the world map in Zone Detail, Y switches between cards and list.
- **Overview:** Continue card for the zone to work on, next goal, up to three groups of suggested areas, tracked completion, a Zones stat, recent zones, a 14-day activity strip and recent milestones.
- **Zones:** illustrated cards or a compact list; status (All / In progress / Untouched / Complete), Show (your faction's zones or all), Level and Sort filters; search; level-bracket sections.
- **Zone Detail:** banner with percentage and pips, the zone's areas under To discover / Discovered (and State unknown when the game doesn't say), notes for partial or uncertain data, and the world map on X.
- **Live updates:** discovering an area updates every screen and records a milestone with its time.

## Where the data comes from

- **Exploration:** the game's own "Explore <zone>" achievement criteria, per character, read live. `Azerfolio/Data/Exploration.lua` lists which criteria belong to which zone (generated from a client dump by `tools/gen-exploration.lua`; client 1.60.1.70862).
- **Coverage:** 43 zones, 549 areas. The capitals and Zephras Isle have no Explore achievement, so they're shown as "not tracked".
- **Level ranges and faction territory:** the client has neither. `Azerfolio/Data/Zones.lua` is a hand-curated, unofficial guide from the Warcraft Wiki (Classic pages) plus the owner's notes for the Forever-only zones. It's used for the Level and Show filters and the "for your level" picks, never for counts.
- **Honest numbers:** Azerfolio never shows a count, percentage or time the game didn't confirm. Unknown stays unknown: no percentage while data is missing, no celebration with incomplete coverage, "time not seen" for discoveries made while the addon was off.

## Known limitations

- Exploration is the only tracked category in v1. Quests are planned for v1.1.
- No Atlas view, sticky section headers, "Recommended next" ribbon, zone-map panel or completion celebration yet (they're in the design, not built).
- The level ranges and faction territory are a guide, not game data.
- Right-stick scrolling is untested (the probe only saw left-stick events).
- `RECEIVED_ACHIEVEMENT_LIST` doesn't fire on `/reload`; a read 3 s after login sets the baseline instead.

## Commands

| Command | What it does |
|---|---|
| `/azf` | Open or close the window |
| `/azf help` | List the commands |
| `/azf refresh` | Re-read progress from the game |
| `/azf status` | Version, schema, character, errors this session |
| `/azf minimap` | Show or hide the minimap button |
| `/azf debug` | Debug mode on/off (chat output, trace in `AzerfolioDB.trace`, performance counters) |
| `/azf debug zone` | Current map chain and zone text |
| `/azf debug exploration` | Current zone's exploration, the total, baseline and milestones |
| `/azf debug zones` | Zones catalogue counts and filters |
| `/azf debug overview` | What the Overview picks and counts |
| `/azf debug perf [reset]` | Event and callback counts and timings since debug mode was turned on, memory, stored list sizes |
| `/azf shot`, `/azf shots [banners]` | Development screenshots |

Debug output is off by default. The trace is capped at 100 entries and holds only addon state.

## Development

- Tests: `luajit tests/run.lua` from the repo root (Lua 5.1 semantics; mocks in `tests/mocks/wow.lua`).
- Design: `mockups/DESIGN.md` and the mockup (`tools/serve-mockups.ps1`, http://localhost:8765).
- Zone art: `art/style-guide.md`, then `powershell -File tools/process-art.ps1`.
- Docs: `project-spec.md`, `project-implementation-plan.md`, `docs/implementation-status.md`, `docs/testing.md`.

## Changelog

### 0.1.0 (in development)

- Phase 8: key binding removed (not needed), performance counters (`/azf debug perf`), cheaper re-read after a discovery outside the current zone (fully explored zones skipped), Overview no longer rebuilds on every XP gain, damaged milestone and recent-zone entries cleaned on load, this README.
- Phase 7: Overview dashboard (Continue card, suggestions, tracked completion, Zones stat, recent zones, activity, milestones).
- Phase 6: Zones catalogue (cards and list, filters, sort, search) and Zone Detail (banner, unknown areas, notes, world map).
- Phase 5: exploration catalogue, progression service, live tracker, per-character baseline and milestones.
- Phase 4: native-look window, gamepad focus, Zone Detail, wide split view, launchers and key binding.
- Phases 0–3: client probe, exploration proof of concept, addon foundation, design mockups and zone art.
