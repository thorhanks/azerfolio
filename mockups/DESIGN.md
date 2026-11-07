# Azerfolio design decisions (from the mockup)

The HTML mockup in this folder is the visual reference for the Lua UI. This file lists the decisions it embodies, so Phase 4+ can implement them without reverse-engineering the mockup. Mockup-only stand-ins are listed at the end.

Run it: start the `mockups` preview (http://localhost:8765). Use the dev bar to switch data scenarios, simulate a discovery, and toggle the wide window.

## State language (used everywhere)

| State | Meaning | Visual |
|---|---|---|
| Complete | Every objective verified done | Gold (`#ffcc33` → `#b8860b`): gold pips, gold bar, gold card frame with a shine, emblem |
| In progress | Some done | Warm orange (`#e08a3c` → `#9c4f17`): orange bar, orange card edge, full-colour art |
| Untouched | None done | Gray (`#5b5246`): gray pips, desaturated and dimmed art |
| Not tracked | No catalogue (capitals, Zephras Isle) | Diagonal hatching, grayscale art, "Exploration not tracked", never 0% |

**Pips** (one dot per objective) are the primary progress glyph on cards, rows, the Continue card and Zone Detail. Discovered pips fill from the left. A newly discovered pip pops. The thin bar is secondary.

## Screens

**Header:** full (portrait, name, race/class, faction, XP) on Overview. A single compact line on Zones, to give the catalogue more height. The current zone appears in the header only on Zones; on Overview it lives in the Continue card.

**Overview, top to bottom:**
1. **Continue card** (largest element): the current zone if unfinished, otherwise the best in-progress zone, otherwise the next zone for your level. Art, pips, "7 of 12 · 5 to go", A to open.
2. **Counters:** areas discovered (bar), and zones as a stacked bar (complete / in progress / untouched) with a legend.
3. **Next goal** row: the in-progress zone with the fewest areas left, other than the Continue zone. Hidden if there is none.
4. **Atlas:** both continents as a schematic grid of zone tiles, coloured by state, with a partial fill for in-progress zones and a "you are here" marker. Zones without a known position are listed as "not placed". (In game this can use the real continent map art; positions must be verified, not guessed.)
5. **Suggested next**, grouped by zone: current zone, closest to complete, next for your level. Undiscovered areas are shown as chips.
6. **Activity:** areas discovered per day for 14 days, then the five latest milestones. Zone completions are highlighted.

**Zones catalogue:**
- Toolbar: status segmented control (All / In progress / Untouched / Complete), then Show / Level / Sort buttons that open a **gamepad popup** (D-pad to choose, A to apply, B to cancel), zone count, search, and the cards/list toggle.
- Sorted by "Recommended": grouped under **level-bracket headers** with "n of m complete". LT/RT jump between sections. Other sorts are ungrouped.
- Cards: 16:8 art, a "For your level" ribbon, name in a mixed-case serif, levels and faction, pips, "n / m areas" and the percentage.
- List: thumbnail, name and faction, levels with a **level bar** (the zone's range on 1–60, your level marked, green when it fits your level), pips and the percentage.
- Tooltips only add information the control doesn't show (last discovery, "discovered before Azerfolio was installed", why a zone isn't tracked). No tooltip if there's nothing to add.

**Zone Detail:**
- Slim banner: name, levels, faction, continent, "Next: <zone>", big percentage, pips.
- Left: "To discover" (inviting, dashed rings) above "Discovered" (quiet, gold checks).
- Right: **zone map**: the zone's map art with the game's revealed-area pieces (`C_MapExplorationInfo.GetExploredMapTextures`, offsets in 1002×668 map units) cutting through fog. Fully revealed at 100%. Below it: a World map button (X) and the focused objective's details.
- Marking each listed area on the map needs extra data (criteria → map overlay). Planned, not in v1.

**Wide window (ultrawide):** at about 1600 px wide, Zones becomes a split view, with a compact list (pips and level bar) on the left and Zone Detail on the right. Moving focus in the list updates the detail immediately. A moves focus into the checklist; B returns to the list.

**Completion moment:** when the last area of a zone is discovered: a toast, the pip pop and the row flash, then a full-window celebration (emblem, "<Zone> Explored", soft rays, A to continue) and a highlighted milestone.

## Gamepad

| Input | Action |
|---|---|
| D-pad | Move focus (yellow `#ffe600` outline; cards scale up 3%) |
| A | Activate |
| B | Back, close a popup or celebration, otherwise close the window |
| LB / RB | Switch tabs |
| LT / RT | Jump between sections in grouped lists, otherwise page |
| Y | Cards / list |
| X | Search (catalogue) or World map (detail) |

A hint bar always shows the current screen's buttons. Focus is restored when returning to a screen. The addon uses explicit focus grids per screen; the mockup approximates them spatially.

## Mockup-only stand-ins (not decisions)

- Zone art is a generated landscape placeholder; the real art comes from the art pipeline.
- Level ranges and faction territory are typical classic values typed into the mockup. The addon needs a verified source before showing them.
- Fonts are web stand-ins for WoW's fonts.
- Map base art is a stylized placeholder. Revealed pieces are real only for Gideon's Elwynn Forest; other zones use approximations.
- Atlas positions are a hand-made schematic.
- Scenario data other than "Gideon today" is invented for design review.
