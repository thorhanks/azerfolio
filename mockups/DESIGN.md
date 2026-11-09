# Azerfolio design decisions (from the mockup)

The HTML mockup in this folder is the visual reference for the Lua UI. This file lists the decisions it embodies, so Phase 4+ can implement them without reverse-engineering the mockup. Mockup-only stand-ins are listed at the end.

Run it: start the `mockups` preview (http://localhost:8765). Use the dev bar to switch data scenarios, simulate a discovery, and toggle the wide window.

## Native look (2026-11-07)

The owner chose the **full native Forever look**: Azerfolio looks like the client's own Character / Reputation window. The Lua UI uses the client's templates and atlases (identified with `/azfdiag skin`; table in `docs/research/client-capabilities.md` § Native frame style). The mockup draws CSS approximations measured from the in-game screenshot `WoWScrnShot_110726_165420`.

| Part | Lua source | Mockup |
|---|---|---|
| Frame, portrait ring, title band, close | `PortraitFrameTemplate` (`SetTitle`, `PortraitContainer.portrait` + `SetPortraitTexture`) | `.window`, `.titlebar`, `.portrait`, `.close` |
| Controller-focus glow | `gamepad-uiframemetal-largeportrait-focus` (shown while the controller drives the window) | outer yellow glow on `.window` |
| Panes | `UI-Character-Info-General-BG` / `-Stat-BG`; `common-framedivider` between panes; `common-insideframe` for inset panels | dark warm-brown gradient; `.inset`-style panels |
| Tabs | `common-sidetab` (`-hover`, `-selected`) on the right edge, `Gamepad-Xbox1-Trigger-LB/RB-Normal` above and below | `.sidetabs` (icon-only; the name shows in the info line) |
| Group headers | `common-button-list-collapseExpand` + `common-button-list-minus`, gold text | `.group-h` (sticky) |
| Row highlight | `charactercreate-customize-dropdown-linemouseover-side/-middle` | highlight bar on focused rows, chips, buttons |
| Progress bars | `common-stat-bar-BG` + tinted `common-stat-bar-white` + `common-stat-bar-Mask` | `.bar`, `.xp` |
| Focus pointer | `gamepad-largecursor-white` tinted `GAMEPAD_SMARTNAV_CURSOR_COLOR`, bobbing ±4 | `.pointer` chevron |
| Legend | Our own box in the `GamepadPersistentInputLegend` style (`UI-Frame-DiamondMetal-*` edge): info line left, button hints right | `.legendbox` below the frame |
| Font | `Fonts\FRIZQT__.TTF`; names white, headings gold (1, 0.82, 0) | Marcellus stand-in |

## Design system

| Token | Values |
|---|---|
| Type scale | 12 / 14 / 16 / 20 / 26 / 32 px. Nothing below 12 (couch distance). One face (FRIZQT); gold for headings and labels, white for names, warm grey for secondary text |
| Spacing | 4 px grid: 4 / 8 / 12 / 16 / 24. 8 between related items, 16 between siblings, 24 between page sections and as page gutter |
| Radii | 4 controls, 6 cards and panels; the frame is the native template |
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

- **Frame:** the native portrait frame. Title band (24) reads "Azerfolio"; the player's portrait sits in the ring that overlaps the top-left corner; close at the right end of the title band.
- **Character strip (52; 34 compact on Zones):** right of the portrait ring: name, level, race, class, faction, the XP bar (native stat bar, 300 wide) and the current subzone and zone. Compact shows one line.
- **Tabs:** icon tabs on the right edge, outside the frame, with LB above and RB below. The active tab has a bright edge and glow.
- **Legend box (44), below the frame:** **info line** on the left, button hints on the right. The info line describes the focused control; it is how gamepad users get tooltip content. Floating tooltips appear only on mouse hover.

## Screens

**Overview: fits one screen** (no scrolling at 1160×740), two columns.
- Left: **Continue card** (art, pips, "n to go", big percentage on the right, A prompt), **Next goal** (the in-progress zone with the fewest left, excluding the Continue zone, with pips inline after the text), **Suggested next** (up to 3 zone groups, up to 6 area chips each, "+n more").
- Right: **Areas discovered** (count, %, bar), **Zones** (stacked bar plus legend), **Atlas thumbnail** (one focus stop; A opens the Atlas view). (An **Activity** panel was here until step 6 of Phase 9.)
- **Step 6 (Phase 9, approved by the owner 2026-11-08, built in Lua):** in game the Atlas thumbnail's place is still **Recent zones** (now up to 5, each with its category bars).
  - **Tracked completion** is one framed panel: the headline is the equal-weight average of the categories with data (spec §5.2). One compact row per category (icon, name, gilded bar, done / counted, %); a category without data says why ("Needs the QuestieDB addon", "Reading quests...", "Talk to a flight master") and is left out of the headline, never shown as 0%. A **Zones** row (stacked bar, complete / applicable, legend) closes the panel and replaces the separate Zones counter. The footer names the rule and the gaps ("98 quests can't be checked yet · Kalimdor: talk to a flight master there"). Each row is a focus stop that opens the Zones tab.
  - **Suggested next**: each zone group lists that zone's Next up picks (two areas, three ready quests nearest your level in their difficulty colour with "Lv n", one flight path), at most 6, each with its category icon; the group's line says what's left per category ("Current zone · 5 areas · 26 quests left"). A opens the zone's page focused on that item; B returns to the Overview.
  - Painted chrome: section headers are header plates (Suggested next, Atlas/Recent zones); every panel (Next goal, zone groups, Tracked completion, Atlas thumbnail) gets the frame kit.
  - **Activity removed** (owner, 2026-11-08: not interesting enough). The per-day strip and the latest discoveries are gone, and with them the milestone tracking behind them (spec §5.6). The Overview fits one screen with room to spare.
- Lua (Phase 7, approved by the owner 2026-11-07): the first panel is titled **Tracked completion** and names its category ("Includes Exploration: n of m areas discovered"), per spec §5.2. Until the Atlas view exists, **Recent zones** (the 3 latest visited zones other than the current one: thumbnail, name, pips, %) takes the Atlas thumbnail's place. B in a Zone Detail opened from the Overview returns to the Overview.

**Zones: three views, cycled with Y:** Cards, List, Atlas.
- Toolbar on one row: status segments (All / In progress / Untouched / Complete), Show / Level / Sort buttons that open a gamepad popup, zone count, search, and an icon-only view toggle.
- Recommended sort groups by level bracket under **sticky** headers ("n of m complete"); LT/RT jump between sections.
- **Cards (about 208 px tall, 7–8 visible):** 16:5 art; name + percentage on one line; pips; meta line (Lv range, faction, small "Your level" tag, n/m). Only the single best next zone gets a "Recommended next" ribbon.
- **List:** thumbnail, name and faction, level bar (zone range on 1–60 with your level marked, green when it fits), pips and n/m, percentage (✓ when complete).
- **Atlas:** both continents as a schematic grid on a dark map table; 34 px tiles with 14 px names that wrap to two lines; partial fill for in progress, ✓ for complete, ● for "you are here". Zones outside the current filters are dimmed, not hidden. Zones without a known position are listed under "Position not mapped yet". Opens focused on your current zone.

**Zone Detail:** a slim banner (124 px) with name, levels, faction, continent, "Next: <zone>", big percentage and pips. Left: "To discover" (inviting, dashed rings) above "Discovered" (quiet, gold checks); LT/RT jump between them. A fully explored zone has no "To discover" section (no empty "0 areas" header): the "Fully explored" note stands above "Discovered" (owner, 2026-11-07). Right: the **zone map** (the game's revealed pieces from `C_MapExplorationInfo.GetExploredMapTextures`, in 1002×668 map units, cutting through fog; fully revealed at 100%), a World map button (X), and the focused objective's state.

**Zone completion (v1.1, spec §7.7; proposed 2026-11-08, awaiting approval):** a zone's progress covers every category that applies to it (exploration ◎, quests !, flight paths ✈); the zone's % is the equal-weight average; a category that doesn't apply is left out, never 0%.
- **Zone Detail is a dashboard** (revised 2026-11-08, owner): the banner, then the **zone standard** (progress art, in the player's faction look) with the zone's % on the left, and one **category tile** per category on the right (icon, count, %, bar, a "Next:" line, "A Quests"). A on a tile opens that category's page (Exploration: list and map; Quests: Ready now and storylines; Flight paths: list), with a slim banner titled "Quests · Elwynn Forest"; B returns to the dashboard on the same tile, B again to the catalogue. A category that doesn't apply shows a quiet, non-opening tile saying why. Overview area chips open the Exploration page directly.
- **The war banner** (owner's choice 2026-11-08, over a crest and braziers; replaces the medallion rings): the player's faction banner, styled for the faction: **Alliance** regal (royal blue, stitched gold border, gold fringe and tassels, gilded crossbar, gold spearhead); **Horde** battle-worn (crimson, torn ragged edges, holes, a stitched leather patch, painted black sigil, timber crossbar lashed with rope, iron spike; no fringe, tassels or gold), planted over the zone's own art, darkened and vignetted. It is **hoisted up the pole as the zone fills** (0% at the ground, 100% at the finial), rising from the ground each time the dashboard opens (about 1.6 s, ease-out). Brass rings on the pole at 25 / 50 / 75% light up once passed. One **embroidered badge per category** on the cloth: gold thread runs round it as the category fills; solid gold when done. Stitched inner border, faction emblem, gold fringe and two swinging tassels; the cloth flutters gently. **Claimed** (Zone Complete): at the top of the pole, gold edge and glow, slow rays and twinkling sparks, "Westfall claimed for the Alliance". **Claim moment:** a full-window celebration with the banner rising to the top, "<Zone> claimed / for the Alliance: exploration, quests and flight paths complete", A to continue. Claimed zones get a small pennant on their catalogue card. Dev bar: "Look" (Alliance / Horde), "Preview claimed", "Simulate claim". SVG stand-in: the addon uses painted pieces from the art pipeline.
- **Category bars** replace the pips on catalogue cards, list rows and the Next goal: one thin bar per category in a fixed slot (◎ / ! / ✈), so columns line up; a slot stays empty when the category doesn't apply. Pips stay in the Exploration section.
- **Zone Detail sections**, each under a major heading with its icon, count and %: Exploration (To discover / Discovered), Quests, Flight paths (known ✓ / not discovered ✈).
- **Quests:** *Ready now* (chips with the quest level in the client's difficulty colour), *Storylines* (one track per chain: dots for done ✓ gold, ready orange, locked 🔒, unknown ?; branches stack in a column; nodes are focus stops, name below, details in the info line), *Single quests*, *Finished* (one gold row per finished storyline; A unfolds it). Footer: the coverage note and "Show n you can't do" (B-safe toggle, default hidden).

**Design round 2 (owner feedback 2026-11-08; approved and built the same day, checked in game 16:36).** Uses the owner's painted art (art/prompts.md, `tools/process-art.ps1`).
- **Zone Detail header** is taller (196 px) to show off the zone art; the right side carries the zone's score: a big % (gold "Claimed" when complete), one small line per category with its icon and n/m, and what can't be checked yet.
- **The war standard** (painted): the pole up the middle of a narrower panel (236 px) with the zone art cropped behind it; the banner's own crossbar is hoisted up the pole (the finial stays clear at 100%; travel is about 37% of the panel's height, so 58% looks partway). **No text under the banner.** No badges on the cloth: a **battle streamer** hangs from the crossbar's ends for each finished category (left, right, then outer left); the cloth sways gently.
- **Tiles**: framed with the painted card frame (nine-slice); category icons are the painted icons; the Exploration tile shows the gold pips, the others a gilded bar (the painted bar housing with the molten-gold fill, tinted amber while in progress).
- **Frame kit everywhere**: zone cards, dashboard tiles, the banner panel and the Continue card get the painted frame; card bars use the gold fill.
- **Tabs** use the painted icons (journal for Overview, map and compass for Zones).
- **Continue card** always shows your zone ("Continue · your zone", "Your zone · claimed"), the mini standard beside the zone's %.

**Design round 3 (owner feedback 2026-11-08; approved, with no A hints on the tiles or the Continue card: "already obvious"; the legend still shows A).**
- **Dashboard layout:** the standard centred in its panel; three **square tiles side by side**, then **"Next up in <zone>"** under them: a painted header plate and up to five items (the next two areas to discover, up to three ready quests nearest your level in their difficulty colours, a flight path not yet discovered), each a focus stop that opens its page on that item. A claimed zone says so there instead.
- **Streamers:** one per finished category, flight paths included (so a zone with no flight master can earn two). Each hangs with its tie on the crossbar's end, just beside the cloth; the positions are measured on the painted pieces per faction (`ZoneBanner.lua` `streamerX`).
- **Reading the standard's progress at a glance:** the zone art behind it comes alive with progress, grey and dim at 0% to full colour at 100%. (The pole glow and the 25/50/75% rings were built and removed: the owner didn't like how they looked in game.)
- **Motion:** the hoist on opening; the cloth and streamers stay still (in game a Rotation animation made the cloth vanish and a looping sideways drift left the streamer sliding away); motes drift up from the banner's foot, spread past its sides so they show, behind the cloth and in front of the pole (in game each mote is a small frame: a Translation on a texture only faded in place), more as the zone fills (2 at 0% to 11 at 100%); claimed: slow light rays and a glint on the finial.

**Wide window (ultrawide, about 1640 px):** Zones becomes a split view: compact list on the left, Zone Detail on the right, updating as focus moves. The Atlas view is available too; choosing a tile switches to the split view with that zone selected. A moves into the checklist; B returns to the list.

**Completion moment:** a toast, pip pop and row flash, then a full-window celebration (emblem, "<Zone> Explored", soft rays masked to the centre, A to continue), and a highlighted milestone.

## Gamepad

| Input | Action |
|---|---|
| D-pad | Move focus: the native yellow chevron points at the focused control. Rows, chips and buttons also get the native highlight bar; art cards and tiles get a thin yellow edge and scale 3%; large panels only get the edge |
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
- Fonts are web stand-ins for WoW's fonts. Frame, tabs, bars and glyphs are CSS approximations of the native atlases.
- Map base art is a stylized placeholder. Revealed pieces are real only for Gideon's Elwynn Forest; other zones use approximations.
- Atlas positions are a hand-made schematic; in game, positions must come from verified map data.
- Scenario data other than "Gideon today" is invented for design review.
