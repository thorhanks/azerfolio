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

## Phase 4 — Main window and navigation: done (2026-11-07)

Built in steps the owner approves one at a time:
1. **Window shell** (done; in-game check passed 2026-11-07): `UI/Theme.lua` (design tokens from `mockups/style.css`), `UI/MainWindow.lua` (header with portrait, name, class line, XP, subzone, wordmark and close; parchment content; footer with tabs, info line and hint bar; drag by the header; resize grip; position saved as a centre offset; off-screen recovery; Escape via `UISpecialFrames`; tabs registered with one `UI.RegisterTab` call; compact header on Zones), `UI/Gamepad.lua` (addon-owned input frame: LB/RB switch tabs, B closes; on only while shown, gamepad UI on and out of combat), placeholder Overview and Zones pages, `/azf shots` (4 screenshots: each tab, at saved and minimum size). Account schema 2: window default 1160×740 (range 1000–1800 × 640–1100); an untouched 960×640 moves to the new default.
2. **Focus** (built, waiting for the in-game check): `UI/FocusGrid.lua` (pure: rows, sections, remembered column, focus by key, LT/RT section jumps or paging; 8 tests), `UI/Focus.lua` (one grid per tab, native chevron `gamepad-largecursor-white` bobbing ±4, native row highlight, scroll into view, info line follows focus), D-pad / A / LT / RT in `UI/Gamepad.lua`. First focus targets: the Zones tab lists the client's zones by continent (`Systems/Maps.lua`, `C_Map.GetMapInfo` scan; names and continents only, no progress). `/azf shots` takes 5 shots (adds Zones after an RT jump). Tests: 74 passed.
   - In game (shots `WoWScrnShot_110726_174704`–`174710`): the D-pad, LT/RT, scroll-into-view, chevron size and hints work; all four face-glyph atlases resolve (`gamepad-xbox1-button*-normal`) [verified-ingame]. Fixed after: the row-highlight atlas is plain white (it drew an opaque bar over the name), so it is now drawn at 0.32 alpha for focus and 0.18 for hover (measured from the Reputation frame); after an LT/RT jump the target row now scrolls to the top, under its section header. Both fixes verified (`WoWScrnShot_110726_174922`, `174924`): the focused row is a translucent grey bar with readable text, and RT puts Kalimdor's header at the top with Ashenvale focused under it. **Step 2 done.**
3. **Zone Detail navigation** (built, waiting for the in-game check): A (or a click) on a zone opens its detail: banner art (centre band of the 2:1 image), name, continent, then its Explore areas in two columns under "To discover" and "Discovered", with counts. Data from `Systems/Exploration.lua`: the zone's "Explore <zone>" achievement found by name in categories 14777/14778, criteria read live (`criteriaID`, name, done flag; a non-boolean flag stays unknown). Capitals, Zephras Isle and Riverglades-style misses say exploration isn't tracked; no achievement data yet says unavailable and retries. B (or the Zones button) returns to the list with the same zone focused; B on the list closes. Detail rows are pooled. `/azf shots` adds the current zone's detail (6 shots). Not yet: the zone map panel and live refresh on discovery (Phase 5 events). Tests: 80 passed.
   - In game (`WoWScrnShot_110726_175426`, Gideon in Northshire): Elwynn Forest shows 4 to discover + 8 discovered = the game's 12 criteria; banner, two columns, chevron, info line ("Not discovered yet") and "LT RT Section / B Back" hints correct. `ReadyCheck-Ready` loads but is green; now desaturated and tinted gold per the state language (not re-shot). **Step 3 done.**
4. **Launcher** (built, waiting for the in-game check): `UI/Launcher.lua`. Addon compartment entry (TOC `AddonCompartmentFunc*` → `Azerfolio_OnAddonCompartmentClick/Enter/Leave`), in-house minimap button (book icon, tracking-border ring, drag around the edge, angle saved in `launcher.minimapAngle`, `/azf minimap` hides/shows it, tooltip), key binding `Bindings.xml` → `Azerfolio_Toggle` (Key Bindings > AddOns > Azerfolio). Minimap border/background texture paths are [unverified]. Tests: 84 passed.
   - In game: the owner reports compartment, button, drag and key binding all work. Screenshot `WoWScrnShot_110726_181323`: the button renders cleanly (book icon in a single gold tracking ring) [verified-ingame], but at the 200° default it sat on top of another addon's minimap button (other buttons measured at about 206° and 228°). The saved angle was still 200 at 18:13:02, so a saved drag isn't confirmed from the file. Fixed: default 140° (top-left, free); account schema 3 moves an untouched 200 to 140. Tests: 85 passed. **Step 4 done.**
5. **Wide split view, banner offset, full shots** (built, waiting for the in-game check):
   - Wide window (width ≥ 1440, `Theme.layout.wideMinWidth`; resize the window to get it): Zones shows the list (560 wide) and Zone Detail side by side, with a divider. The detail follows the focused zone (`page:OnFocusChanged`, a new Focus hook) and its row keeps the highlight bar. A ("Checklist") moves focus into the areas, B returns to the zone; a click selects; a zone with no areas stays in the list with its message. Crossing 1440 while resizing switches layout live (`UI.Relayout` on `OnSizeChanged`). The narrow window works as before.
   - Banner offset: `Theme.bannerFocus` centres the thin banner crop on the landmark for Westfall, Silverpine, Teldrassil, Mount Hyjal, Deadwind Pass, Stonetalon and Zephras Isle (values picked by eye from the art; pure `Theme.BannerCrop` keeps the band inside the art).
   - `/azf shots` takes 9: each tab, Zones after an RT jump, each tab at minimum size, the current zone's detail, an untracked zone's detail, the wide split with focus in the list, then in the checklist. `/azf shots banners` shows the detail of each zone with a banner offset (7). Tests: 90 passed.
   - In game (shots `WoWScrnShot_110726_192946`–`192958`, banners `193026`–`193036`): the split view renders (list with divider and selected bar, detail with banner and message, "A Checklist · LT RT Continent · B Close" hints) [verified-ingame]; the gold check tint shows on discovered areas [verified-ingame]; SavedVariables show `minimapAngle = 140` (schema 3 migration ran) [verified-ingame]. Fixed after: the wide shots began on Ironforge, which was still focused from the untracked shot and has no areas, so both wide shots were the same; they now start on the player's zone. The A hint no longer shows in the split view for a zone with no areas (`item.canActivate`). Teldrassil's banner is good; Westfall's lantern touched the top edge, and Silverpine, Deadwind, Hyjal, Stonetalon and Zephras cut their landmark's top, so those offsets moved up.
   - Re-shot (`WoWScrnShot_110726_193304`–`193316`, banners `193327`–`193336`): the wide shots start on Elwynn Forest, the second shows focus in its checklist with Elwynn still marked in the list; all seven banners show their landmark whole [verified-ingame]. Tests: 90 passed. **Step 5 done. Phase 4 done.**

**Phase 4 result:** the native-look window with tabs, legend and gamepad focus; Zones list, Zone Detail with live Explore criteria, and the wide split view; launchers and key binding; `/azf shots` for review. Not checked in game separately: persistence across a relog, Escape and opening during combat (covered by tests). **Next: Phase 5** (exploration catalogue and progression engine).

- Tests: 57 passed.
- **First in-game shots** (`WoWScrnShot_110726_163711`–`163715`, Gideon): no errors. Verified [verified-ingame]: `Fonts\MORPHEUS.TTF` title face, the circular portrait mask, class colour, XP (1543 / 6500), subzone, the compact header on Zones, footer tabs, LB/RB glyphs, info line and B hint, the resize grip, and both 1160×740 and minimum 1000×640 layouts.
- **Fixed:** the native parchment at full strength was dark and blotchy and hid ink text; content is now the flat design colour with the texture as 30% grain. Verified readable (`WoWScrnShot_110726_164052`).
- Owner's UI scale is 0.65 (`Config.wtf`), so UIParent is about 2822×1182 units: the 1160×740 window covers about 1414×902 physical pixels (41% × 63% of the screen), and 14-unit body text is about 17 px tall. The owner confirmed this size is fine.
- Owner confirmed: LB/RB/B work; drag, resize and position persist across `/reload` (SavedVariables: schema 2, x −450, y 228, 1000×640).
- Not verified yet: right-stick events.
- **Next:** the owner chose the **full native look** (dark panes instead of parchment, glowing gold frame, round portrait, native tabs and prompts; reference: the Reputation frame). `/azfdiag skin` (built; tests 58 passed) records what draws the live CharacterFrame and gamepad overlays, checks candidate atlases and shows a template test. Report: `luajit tools/diag-report.lua skin [tree [filter]]`. Then the mockup, then Lua; Phase 4 step 2 waits for this.
- **Probe result (2026-11-07):** every native piece is identified (table in `docs/research/client-capabilities.md` § Native frame style). `PortraitFrameTemplate` gives the gold chrome; panes, side tabs, list headers, row highlight, progress bars, shoulder glyphs, legend box and the focus chevron all have atlas names. Still unknown: the face-button (A/B/X/Y) glyph atlases.
- **Mockup reworked to the native look (2026-11-07, approved by the owner):** portrait frame with title band and focus glow, character strip, dark panes, right-side icon tabs with LB/RB, legend box below the frame (info line + hints), native group headers, highlight bars, stat bars and the yellow chevron pointer. Every screen checked in the preview (Overview, Cards, List, Atlas, Zone Detail, wide split, celebration); no console errors. `mockups/DESIGN.md` updated with the Lua source for each part.
- **Lua restyle (in-game check passed 2026-11-07, shots `WoWScrnShot_110726_171831`–`171835`):** frame, portrait ring, title, glow, strip, XP bar, side tabs, LB/RB glyphs and the diamond-metal legend all render natively. The first face-glyph name guesses failed (drawn square fallback); now using the source's `gamepad-xbox1-button*-normal` names and a round fallback — needs one more look.
- Restyle details: the window is `PortraitFrameTemplate` (title, portrait ring, close, `FrameGlow` shown while the controller drives it); character strip with the native stat-bar XP; content on `UI-Character-Info-General-BG`; side tabs (`common-sidetab` + masked icon, `-selected`, `-hover`) with LB/RB glyph atlases; legend box below the frame (diamond-metal nine-slice over file 131071) with the info line and hints. Off-screen recovery now keeps the tabs and legend on screen. Face-button glyph atlas names are guesses with a drawn fallback; `/azf status` prints which were found. Tests: 62 passed.

## Phase 6 — Zones catalogue and Zone Detail: in progress (2026-11-07)

Planned steps (owner approves each):
1. **Catalogue model and zone metadata probe** (done 2026-11-07). Probe result (Gideon, 51 zone maps, 0 errors): `GetMapLevels` returns 0,0,0,0 for every zone and `GetZonePVPInfo` doesn't exist, so the client gives **no level ranges and no faction territory** [verified-ingame]; the Show (faction) filter isn't offered. **Level ranges (owner-approved, unofficial):** `Data/Zones.lua`, curated by hand from the Warcraft Wiki "Zones by level (Classic)" page (edited 24 September 2026; same as the pre-Cataclysm page except Hillsbrad 20–35), 40 classic zones; the four Forever-only zones from the owner (Zephras Isle 1–12, the Skyborn starting zone; Riverglades and Shen'dralas 35–45; Mount Hyjal 60, under its own "Level 60" section); only the six capitals stay unknown. `Zones.LevelsFor` ignores any entry that isn't a sane 1–60 range. So the Level filter is offered and Recommended groups by level bracket, with unknown-level zones after by continent. Tests: 157 passed. `GetMapRectOnMap` gives real positions on the continent map for all 50 continent zones [verified-ingame] (details in `docs/research/client-capabilities.md` § Zone metadata).
   - `Systems/Zones.lua` (pure except `Zones.All()`): one entry per zone the client lists (mapID, name, continent and its rank, tracked, state, Progression result, percent, uncertain flag; `minLevel`/`maxLevel`/`faction` nil = unknown). States: `complete` (Progression `trackedComplete`), `progress` (some confirmed), `untouched` (all confirmed not discovered), `unknown` (tracked but unreadable, or nothing confirmed with some areas unknown, or partial coverage), `untracked`.
   - Filters: status segments (All / In progress / Untouched / Complete; unknown and untracked zones appear only under All), faction relevance (hides only the other faction's known territory; contested, neutral and unknown stay), "For my level" (needs a known range; from 3 levels below the minimum to the maximum), plain-text case-insensitive search. `Zones.Available` says which filters have data, so the UI can leave out a filter that would do nothing.
   - Sorts: recommended (known level ranges low to high, then unknown by continent), A–Z, highest %, lowest %, closest (fewest left; complete after). Zones without a percentage always sort after those with one, so "no data" never mixes with a confirmed 0%. Every order ends on name then mapID (stable). Sections: level bracket, or continent when the range is unknown, under recommended; one untitled list otherwise; each with "n of m complete" counts.
   - Account schema 4: `zones.completion` is now `all`/`progress`/`untouched`/`complete` (old `completed` → `complete`, `incomplete` → `all`).
   - Probe `/azfdiag zones` (AzerfolioDiag): records, for every zone map, the raw returns of `C_Map.GetMapLevels` and `C_Map.GetMapRectOnMap(zone, parent)`, plus the player's level, faction and `GetZonePVPInfo`. Report: `luajit tools/diag-report.lua zones`. Level ranges and faction have no verified source until this runs.
   - Tests: 155 passed (14 catalogue tests in `tests/zones_test.lua`, a live `Zones.All` test, the schema 4 migration, two probe tests).
2. **Catalogue page** (done 2026-11-07):
   - `UI/Pages/ZonesCatalogue.lua` draws what `ns.Zones.Query` returns; `UI/Widgets.lua` holds the shared pieces (scroll, header, focus row, toolbar control, edge, pips, level bar); `UI/Pages/Zones.lua` keeps the page, Zone Detail, popup and split view.
   - Toolbar: status segments (All / In progress / Untouched / Complete), Level and Sort controls that open a popup (A picks, B closes; current choice ticked), "n of m zones" count, search box, Cards / List toggle. The Show (faction) control isn't drawn: no data. On a narrow window the count hides first, then search shrinks.
   - Cards (default): as many 240+ columns as fit (4 at 1160), 16:5 art crop (honours `bannerFocus`), name + percentage, pips (done gold, not done grey, unknown faint), "Lv a-b", green "Your level", "n/m" / "not tracked" / "no data"; gold edge and check emblem when complete, orange edge in progress, desaturated art when untouched or untracked; focus = 2 px yellow edge. Unknown shows "?", untracked "-": never 0%.
   - List: thumbnail, name, pips with n/m, level bar (1-60 scale, green when it fits, your level marked), percentage with a check when complete. The wide split view always uses the list.
   - Sections: level brackets under Recommended ("n of m complete"), none otherwise; LT/RT jump; the toolbar is the row above the first section. Empty state: "No zones match" with a hint.
   - Gamepad: Y cycles Cards/List, X focuses search (B leaves the box), new hints "Y View · X Search". Face buttons X = PAD3, Y = PAD4 [verified-ingame, pad probe].
   - Saved: status, level, sort and view (account); search is session-only. Discoveries redraw the cards' numbers; level-ups redraw on next show. Cards, rows and headers are pooled (frame count stays flat across filter and view changes).
   - Info line: continent, "Levels a-b (zone guide)", "n of m areas discovered" (plus unknown count and catalogue-mismatch note). Zone Detail's banner line adds the level range.
   - `/azf shots` takes 11: adds the other view and the Sort popup (view and popup restored after).
   - Not yet: sticky section headers, the "Recommended next" ribbon (Phase 7 suggestions), the Atlas view (positions now known from `GetMapRectOnMap`), typing with a controller only (depends on whether the client opens an on-screen keyboard for an edit box) [unverified].
   - Tests: 165 passed (8 new catalogue tests: cards layout and text, Y view, status filters, Sort popup with the controller, level filter, search and empty state, pooling, live redraw).
   - In game (shots `WoWScrnShot_110726_204306`–`204321`, Gideon, window 1000×640): no errors. Verified [verified-ingame]: toolbar fits at the minimum width; cards (3 columns at 1000 wide) with art crop, greyed untouched/untracked art, gold pips, "Your level", n/m, "-" and "not tracked" for Zephras Isle; level-bracket sections with "n of m complete"; RT to "Levels 10-20"; List view; the Sort popup (tick on the current choice, "A Choose / B Close"); Y View / X Search hints with the face glyphs; Zone Detail; the wide split ("50 zones", detail follows focus, A into the checklist).
   - Fixed after: list rows put "Lv a-b" above the bar at the row's top edge (looked like the row above's) — now text and bar on one line, and the split view's narrow list drops the bar; scrolling up keeps the section header in view; toolbar info no longer repeats the control's name, A says Choose / Show / Type / Switch; the zone info line is shorter (it was cut off behind five hints); the Zone Detail banner reads levels from the guide whatever opened it; the wide shots keep the window on screen (`UI.FitSize`; the 1640 window ran off the right edge). Tests: 168 passed.
   - Re-shot (`WoWScrnShot_110726_205008`–`205023`): level text and bar on one line, the section header stays in view after switching views, the wide window is on screen, the split list drops the bar [verified-ingame]. "Lv 10-20" still wrapped in its 60-wide column: now 76 wide, no wrap (not re-shot). The owner confirmed everything works with the controller. **X focuses the search box but the client opens no on-screen keyboard** [verified-ingame]; the owner types with the keyboard and is fine with that. **Step 2 done.**
3. **Zone Detail completion**: header with %, pips and progress, areas with unknown state listed, states for partial coverage, catalogue mismatch, fully complete and unavailable; World map action (X) if `OpenWorldMap` works.
4. **In-game check** of spec §12 "Zones" and "Exploration".

## Phase 5 — Exploration catalogue and progression engine: done (2026-11-07)

**Phase 5 result:** a generated catalogue (43 zones, 549 areas), the objective model, the single Progression service, the exploration tracker with live refresh, and the per-character baseline and milestones. Done-when, all met:
- Elwynn Forest end to end: correct states and catalogue match, 8 → 9 → 10 of 12 on discovery with the open detail redrawing, and the result survives `/reload` [verified-ingame].
- No milestones for existing progress: the baseline of all 43 zones produced none; one discovery produced one [verified-ingame].
- Unknown never counted as complete or incomplete: covered by tests (the game returned no unknown areas in game).

Step 5 (a separate Elwynn end-to-end check) wasn't run: steps 3 and 4 covered it in game, and the owner closed the phase on that evidence. Tests: 137 passed. Known gap for Phase 6: Zone Detail doesn't list areas with unknown state. **Next: Phase 6** (Zones catalogue and Zone Detail).

Planned steps (owner approves each):
1. **Catalogue** (done 2026-11-07): `tools/gen-exploration.lua` reads the AzerfolioDiag dump and writes `Azerfolio/Data/Exploration.lua` (`ns.ExplorationCatalogue`: data version 1, client 1.60.1.70862, zones keyed by mapID → achievementID and criteriaIDs in the game's order; names as comments only). It refuses to write if a zone matches more than one map, a criterion isn't type 43, or a criteriaID repeats. Result: 43 zones, 549 criteria, no duplicates; running it twice gives the same file. In the TOC after `Data\Art.lua`. Tests: 94 passed.
2. **Objective model and `Progression`** (done 2026-11-07; not yet checked in game):
   - `Systems/Objectives.lua` (pure): an objective has id, category, zone, name, completion (`complete`/`incomplete`/`unknown`) and eligibility (`eligible`/`locked`/`unavailable`/`unknown`) as separate fields; bad values become `unknown`; only a real boolean done flag counts as confirmed.
   - `Systems/Progression.lua` (pure), the only aggregation: takes sets `{ category, coverage, objectives }` and returns counts per state, `completed`/`remaining`/`denominator` (eligible or locked, completion known, from complete-coverage categories; spec §5.2), `uncounted`, `conflicts`, `percent` (nil without a denominator), `coverage` (`complete`/`partial`/`unavailable`), included and excluded categories, and `trackedComplete`. Each objective is counted once by category + ID; a duplicate with different states becomes unknown. `PercentText` rounds down, so "100%" appears only when everything counted is confirmed.
   - `Exploration.ForZone` now returns `objectives` and `progress` (from Progression) instead of its own summary; the Zone Detail counts read `progress`. A criterion the game returns without an ID makes the zone's coverage `partial`.
   - Not yet: objectives with unknown completion aren't listed in Zone Detail (no design for it yet; Phase 6).
   - Tests: 110 passed (16 new Progression/model tests, plus an unknown-flag test through the reader).
3. **Exploration tracker** (built 2026-11-07, waiting for the in-game check). `Systems/Exploration.lua` is now the tracker (kept as `ns.Exploration`):
   - Zones come from the catalogue by mapID (no more name matching). Not in the catalogue = "not tracked"; in it but no readable criteria = "unavailable" (not cached, retried).
   - Live criteria are compared with the catalogue. A difference keeps the game's list and counts and sets `uncertain` (plan §8); a criterion without an ID makes coverage `partial`.
   - Per-zone cache; `Invalidate`, `InvalidateAll`, `RefreshZone`; `ZoneForMap` walks up from a micro map to its zone; `Overall()` aggregates every zone (no percentage while any zone is unreadable).
   - Events: `CRITERIA_UPDATE` and `MAP_EXPLORATION_UPDATED`, debounced 0.5 s, re-read only the player's current zone and send `AZF_EXPLORATION_UPDATED({ mapID })` only if a criterion changed. `RECEIVED_ACHIEVEMENT_LIST` and `/azf refresh` clear the cache and send it for all zones.
   - Zones page: redraws the shown detail on an update for its zone, keeping focus on the same area.
   - `/azf debug exploration`: the current zone's counts, %, coverage and catalogue check, plus the total. Debug mode writes a capped trace (`AzerfolioDB.trace`, 100 entries; addon state only) so in-game results can be read from the file.
   - Tests: 122 passed (12 new: catalogue match, cache, micro map, one update per discovery with the detail and focus following, unrelated events ignored, login/refresh, totals, trace, debug report).
   - In game (Gideon, Elwynn Forest; trace in `AzerfolioDB.trace`, file written 19:54:23): first report 8/12, catalogue matches, coverage complete, and **all 43 zones readable: 8/549, coverage complete** [verified-ingame]. One discovery gave exactly one refresh (GetTime 42722.532, `changed = true`, 8 → 9/12); no other refresh in the ~6 minutes traced, so unrelated `CRITERIA_UPDATE`s didn't trigger extra work. Second report 9/12 and 9/549 [verified-ingame]. The owner confirmed the open detail redrew on screen (the area moved to "Discovered", focus stayed on it). **Step 3 done.** Not in the trace: `RECEIVED_ACHIEVEMENT_LIST` isn't in the trace because debug was turned on after login.
4. **Baseline and milestones** (built 2026-11-07, waiting for the in-game check). `Systems/Milestones.lua`:
   - Per character and per zone, the baseline (`AzerfolioCharDB.baseline.exploration[mapID]`) keeps each area's last confirmed state (`true`/`false`; unknown isn't stored) and whether the zone was tracked-complete.
   - A milestone is recorded only for a confirmed change from not discovered to discovered. The first read of a zone is its baseline; an area that was unknown at baseline, or new to it after a patch, is recorded without a milestone; a later "not done" or unknown never erases a discovery. A zone milestone follows when a zone that was confirmed not complete becomes tracked-complete.
   - Every fresh tracker read updates the baseline. Every zone is read once 3 s after login and 1 s after `RECEIVED_ACHIEVEMENT_LIST` / `/azf refresh`, so each zone has a baseline before a discovery in it.
   - Milestone `{ kind = "area"|"zone", category, mapID, id, name, time }`. Only a change seen live (from a discovery event) gets `time`; one found on a later read (explored with the addon off) has none. Deduplicated by kind + category + ID, capped at the newest 100. Sends `AZF_MILESTONE`.
   - `/azf debug exploration` also prints the baseline zone count, milestone count and the newest 3; debug trace records `baseline` and `milestone` entries.
   - Tests: 137 passed (9 pure rule tests in `tests/milestones_test.lua`, 6 end to end: login baseline, live milestone once across reload and refresh, untimed offline progress, zone completion, damaged baseline, cap).
   - In game (Gideon, files written 20:02:47): after `/reload` the login read took the baseline of **all 43 zones, 549 areas, 0 unreadable** (trace GetTime 43164.618), with Gideon's 9 discovered Elwynn areas and **no milestones** [verified-ingame]. Discovering Stone Cairn Lake (criteria 1157) gave exactly **one milestone**, `live = true`, time 2026-11-07 20:02:24, and the same refresh moved Elwynn to 10/12; the baseline now has 1157 = true [verified-ingame]. The milestone was still there after the final `/reload`. Finding: **`RECEIVED_ACHIEVEMENT_LIST` did not fire on `/reload`** (debug was on, and no "all" refresh is in the trace), so after a reload the 3 s fallback read is what sets the baseline; it worked [verified-ingame]. **Step 4 done.**
5. In-game end to end on Elwynn Forest: covered by the checks in steps 3 and 4; not run separately.

## Phase 3 — Art pipeline ready; waiting for zone art (2026-11-07)

- `art/style-guide.md`: look and feel, camera, safe area (core = middle 40% × 40–62% band, checked against all four crops), palette by region type, image spec, workflow, review checklist. UI chrome uses native textures, so only 51 images are needed (43 zones, 7 untracked places, 1 fallback).
- `art/prompts.md`: a shared style block, a negative prompt, and a subject line for all 51 images. Riverglades, Shen'dralas and Zephras Isle are inferred or unknown; the owner should confirm them.
- `tools/process-art.ps1`: crop to 2:1 around an optional focal point (`art/focal.json`), resize to 1024×512 PNG, write `Azerfolio/Media/Zones/`, generate `Azerfolio/Data/Art.lua` (in the TOC) and `mockups/zone-art/index.js`. Tested with a synthetic image: the landmark survives every crop in the mockup.
- Tests: 39 passed.

**Art review (2026-11-07):** all 51 images were generated (1672×941) and processed. Reviewed with contact sheets (`tools/art-contact-sheet.ps1`) and in the mockup.
- The style, camera and light are consistent across the set. No people, creatures, text or frames (busy scenes checked at full size).
- **Regenerate (wrong architecture):** 1433 Redridge Mountains (East Asian pagoda village; should be a human timber-framed lakeside town), 1446 Tanaris (horned orc fortress; should be a ramshackle goblin town), 1452 Winterspring (horned pagoda lodge; should be a small goblin town).
- **Minor:** 1420 Tirisfal Glades' capital is faint and hard to read small. 1442 Stonetalon's spire and some tall landmarks (Westfall, Silverpine, Teldrassil, Mount Hyjal, Deadwind Pass) sit above the thin banner band. 1411 Durotar and 1454 Orgrimmar look alike. 2652 Shen'dralas doesn't show the bones valley.
- **Round 2:** Redridge, Tanaris, Winterspring, Tirisfal, Durotar regenerated with corrected prompts; Shen'dralas and Zephras Isle regenerated from the owner's in-game references. All pass review.
- **BLP:** all 51 converted to BLP2 DXT1 with mipmaps (17.1 MB; PSNR 33–35 dB). Verified displaying in game (`/azfdiag art`, screenshot `WoWScrnShot_110726_154339.jpg`). Only BLPs are committed; originals and mockup PNGs are git-ignored.
- **Open idea for Phase 4:** a per-zone banner offset, so tall landmarks (Westfall, Silverpine, Teldrassil, Mount Hyjal, Deadwind Pass, Stonetalon, Zephras Isle) show in the thin banner crop.

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
