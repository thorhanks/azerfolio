# Azerfolio design decisions (from the mockup)

The HTML mockup in this folder is the visual reference for the Lua UI. This file lists the decisions it embodies, so Phase 4+ can implement them without reverse-engineering the mockup. Mockup-only stand-ins are listed at the end.

Run it: start the `mockups` preview (http://localhost:8765). Use the dev bar to switch data scenarios, simulate a discovery, and toggle the wide window.

## Design system

| Token | Values |
|---|---|
| Type scale | 12 / 14 / 16 / 20 / 26 / 32 px. Nothing below 12 (couch distance). Cinzel-style caps for headings and labels only; names in a mixed-case serif; body in a sans |
| Spacing | 4 px grid: 4 / 8 / 12 / 16 / 24. 8 between related items, 16 between siblings, 24 between page sections and as page gutter |
| Radii | 4 controls, 6 cards and panels, 10 window |
| Frames | One frame per element. No border-plus-outline, no panel inside a framed panel inside a section |

## State language (used everywhere)

| State | Meaning | Visual | Non-colour cue |
|---|---|---|---|
| Complete | Every objective verified done | Gold (`#ffcc33` → `#b8860b`), gold frame, shine, emblem | ✓ on tiles, percentages, legend |
| In progress | Some done | Warm orange (`#e08a3c` → `#9c4f17`), orange edge | Partial fill |
| Untouched | None done | Gray (`#5b5246`), desaturated, dimmed art | Empty |
| Not tracked | No catalogue (capitals, Zephras Isle) | Diagonal hatching, grayscale art | "not tracked" text; never 0% |

**Pips** (one dot per objective) are the primary progress glyph; discovered pips fill from the left; a new one pops. Stacked bars have 2 px gaps between segments.

## Window chrome

- **Header (76 px; 44 px compact on Zones):** portrait, name, race/class/faction, XP (16 px bar, 12 px text), current subzone, then the "AZERFOLIO" wordmark and close button. There is no separate title bar.
- **Footer (60 px):** tabs (with LB/RB glyphs) | **info line** | button hints. The info line describes the focused control. This is how gamepad users get tooltip content; floating tooltips appear only on mouse hover.

## Screens

**Overview: fits one screen** (no scrolling at 1160×740), two columns.
- Left: **Continue card** (art, pips, "n to go", big percentage on the right, A prompt), **Next goal** (the in-progress zone with the fewest left, excluding the Continue zone, with pips inline after the text), **Suggested next** (up to 3 zone groups, up to 6 area chips each, "+n more").
- Right: **Areas discovered** (count, %, bar), **Zones** (stacked bar plus legend), **Atlas thumbnail** (one focus stop; A opens the Atlas view), **Activity** (14-day strip and the 3 latest milestones).

**Zones: three views, cycled with Y:** Cards, List, Atlas.
- Toolbar on one row: status segments (All / In progress / Untouched / Complete), Show / Level / Sort buttons that open a gamepad popup, zone count, search, and an icon-only view toggle.
- Recommended sort groups by level bracket under **sticky** headers ("n of m complete"); LT/RT jump between sections.
- **Cards (about 208 px tall, 7–8 visible):** 16:5 art; name + percentage on one line; pips; meta line (Lv range, faction, small "Your level" tag, n/m). Only the single best next zone gets a "Recommended next" ribbon.
- **List:** thumbnail, name and faction, level bar (zone range on 1–60 with your level marked, green when it fits), pips and n/m, percentage (✓ when complete).
- **Atlas:** both continents as a sepia ink-on-parchment schematic grid; 34 px tiles with 14 px names that wrap to two lines; partial fill for in progress, ✓ for complete, ● for "you are here". Zones outside the current filters are dimmed, not hidden. Zones without a known position are listed under "Position not mapped yet". Opens focused on your current zone.

**Zone Detail:** a slim banner (124 px) with name, levels, faction, continent, "Next: <zone>", big percentage and pips. Left: "To discover" (inviting, dashed rings) above "Discovered" (quiet, gold checks); LT/RT jump between them. Right: the **zone map** (the game's revealed pieces from `C_MapExplorationInfo.GetExploredMapTextures`, in 1002×668 map units, cutting through fog; fully revealed at 100%), a World map button (X), and the focused objective's state.

**Wide window (ultrawide, about 1640 px):** Zones becomes a split view: compact list on the left, Zone Detail on the right, updating as focus moves. The Atlas view is available too; choosing a tile switches to the split view with that zone selected. A moves into the checklist; B returns to the list.

**Completion moment:** a toast, pip pop and row flash, then a full-window celebration (emblem, "<Zone> Explored", soft rays masked to the centre, A to continue), and a highlighted milestone.

## Gamepad

| Input | Action |
|---|---|
| D-pad | Move focus (yellow `#ffe600` outline and glow; small items such as cards and tiles also scale 3%; large panels don't) |
| A | Activate |
| B | Back, close a popup or celebration, otherwise close the window |
| LB / RB | Switch tabs |
| LT / RT | Previous / next section on every screen (Overview, catalogue, Zone Detail); page where a screen has no sections |
| Y | Cycle views (Zones) |
| X | Search (catalogue) or World map (Zone Detail) |

Focus is restored when returning to a screen. The addon uses explicit focus grids per screen; the mockup approximates them spatially.

## Mockup-only stand-ins (not decisions)

- Zone art is a generated landscape placeholder; the real art comes from the art pipeline.
- Level ranges and faction territory are typical classic values typed into the mockup. The addon needs a verified source before showing them.
- Fonts are web stand-ins for WoW's fonts.
- Map base art is a stylized placeholder. Revealed pieces are real only for Gideon's Elwynn Forest; other zones use approximations.
- Atlas positions are a hand-made schematic; in game, positions must come from verified map data.
- Scenario data other than "Gideon today" is invented for design review.
