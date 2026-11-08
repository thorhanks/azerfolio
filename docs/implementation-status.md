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

## Phase 4 — Main window and navigation: in progress (2026-11-07)

Built in steps the owner approves one at a time:
1. **Window shell** (done; in-game check passed 2026-11-07): `UI/Theme.lua` (design tokens from `mockups/style.css`), `UI/MainWindow.lua` (header with portrait, name, class line, XP, subzone, wordmark and close; parchment content; footer with tabs, info line and hint bar; drag by the header; resize grip; position saved as a centre offset; off-screen recovery; Escape via `UISpecialFrames`; tabs registered with one `UI.RegisterTab` call; compact header on Zones), `UI/Gamepad.lua` (addon-owned input frame: LB/RB switch tabs, B closes; on only while shown, gamepad UI on and out of combat), placeholder Overview and Zones pages, `/azf shots` (4 screenshots: each tab, at saved and minimum size). Account schema 2: window default 1160×740 (range 1000–1800 × 640–1100); an untouched 960×640 moves to the new default.
2. **Focus** (built, waiting for the in-game check): `UI/FocusGrid.lua` (pure: rows, sections, remembered column, focus by key, LT/RT section jumps or paging; 8 tests), `UI/Focus.lua` (one grid per tab, native chevron `gamepad-largecursor-white` bobbing ±4, native row highlight, scroll into view, info line follows focus), D-pad / A / LT / RT in `UI/Gamepad.lua`. First focus targets: the Zones tab lists the client's zones by continent (`Systems/Maps.lua`, `C_Map.GetMapInfo` scan; names and continents only, no progress). `/azf shots` takes 5 shots (adds Zones after an RT jump). Tests: 74 passed.
   - In game (shots `WoWScrnShot_110726_174704`–`174710`): the D-pad, LT/RT, scroll-into-view, chevron size and hints work; all four face-glyph atlases resolve (`gamepad-xbox1-button*-normal`) [verified-ingame]. Fixed after: the row-highlight atlas is plain white (it drew an opaque bar over the name), so it is now drawn at 0.32 alpha for focus and 0.18 for hover (measured from the Reputation frame); after an LT/RT jump the target row now scrolls to the top, under its section header. Both fixes verified (`WoWScrnShot_110726_174922`, `174924`): the focused row is a translucent grey bar with readable text, and RT puts Kalimdor's header at the top with Ashenvale focused under it. **Step 2 done.**
3. Zones catalogue ↔ detail navigation with preserved state (zone names from the client, no progress yet).
4. Launcher: addon compartment, in-house minimap button, key binding (`Bindings.xml`).
5. Wide split view, the per-zone banner offset, `/azf shots` for every state.

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
