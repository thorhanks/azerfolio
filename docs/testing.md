# Testing

Automated: `luajit tests/run.lua` from the repo root. In-game cases below; "By" is who ran it.

## Phase 0 — Diagnostic dump

**Steps (owner)**
1. Start WoW Forever. On the character select screen, click **AddOns** and make sure **Azerfolio Diagnostics** is enabled.
2. Log in. Type `/azfdiag all`. Wait for the "done" line in chat.
3. Type `/azfdiag art`. A window with 8 images appears. Take a screenshot (Print Screen) and share it.
4. Type `/azfdiag sniff` (turns on event logging for Phase 1).
5. Type `/reload`.

**Expected:** chat shows "done: N maps, M explore achievements, E errors". `AzerfolioDiagDB.lua` appears in the account SavedVariables folder.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon, lvl 9 Human Paladin) | Pass. 0 errors, 60 maps, 46 explore achievements. Art test: TGA, PNG and all 5 native textures display. Findings in `docs/research/client-capabilities.md` |

## Phase 1 — Exploration discovery (Elwynn Forest)

Gideon has 7 undiscovered Elwynn areas: Stormwind City, Brackwell Pumpkin Patch, Tower of Azora, Eastvale Logging Camp, Ridgepoint Tower, Stone Cairn Lake, Forest's Edge.

**Steps (owner), on Gideon**
1. *(Optional; skipped 2026-11-07)* Open the Achievements window and screenshot Explore Elwynn Forest. Neither **Y** nor `/run AchievementFrame_LoadUI(); ToggleAchievementFrame()` opened it on Forever, so the Achievements window may be disabled there. Cross-check against discovery events instead.
2. In Elwynn Forest, type `/azfdiag zone`.
3. Walk into an undiscovered area. Stormwind City or Brackwell Pumpkin Patch are closest to Goldshire. Wait for the "Discovered …" message, then the chat line "exploration change recorded".
4. If convenient, discover a second area the same way.
5. Type `/azfdiag zone`, then `/reload`.

**Steps (owner), on Thragor** (tests whether exploration is per character)
6. On the character select screen, select Thragor, click **AddOns**, and make sure **Azerfolio Diagnostics** is ticked for this character. Log in.
7. Type `/azfdiag zone`, then `/azfdiag ach`, then `/reload`.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon) | Pass. Discovered Forest's Edge and Brackwell Pumpkin Patch; each flipped one criterion. Events: CRITERIA_UPDATE + UI_INFO_MESSAGE, then MAP_EXPLORATION_UPDATED about 0.4 s later. Correct after /reload |
| 2026-11-07 | Owner (Thragor) | First try not captured (addon disabled for the character) |
| 2026-11-07 | Owner (Thragor, Horde) | Pass. Elwynn 0/12 vs Gideon 7/12; Durotar 1/11 vs Gideon 0/11. Criteria are per character |

## Gamepad probe (before Phase 4)

**Steps (owner)**
1. At character select, open **AddOns** and tick **Azerfolio Diagnostics** again. Log in out of combat.
2. Type `/azfdiag pad`. A dark box appears near the top of the screen.
3. Press each controller button once: D-pad up/down/left/right, A, B, X, Y, LB, RB, LT, RT, Start, Back/Select, and click both sticks. Wiggle the right stick a little. The box shows the last button seen.
4. It stops by itself after 25 seconds; your controller works normally again. Then type `/reload`.
5. Untick Azerfolio Diagnostics again if you like.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon) | Pass. All buttons received by the addon frame (66 presses, 0 errors); names match the `GAMEPAD_*` constants. Stick events only from the left stick, so right-stick scrolling is still unconfirmed |

## BLP zone art

**Steps (owner):** with Azerfolio and Azerfolio Diagnostics enabled: `/azfdiag art`, then `/azf shot`, then `/azfdiag art` to close.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon) + agent | Pass. Elwynn and Tanaris BLP (DXT1, mipmaps) display with correct colours and detail; file IDs -20541 / -20558 |

## Phase 2 — Addon foundation

Automated: `luajit tests/run.lua` covers settings validation and migration, the event dispatcher, startup order, and all commands against mocks.

**Steps (owner), on Gideon**
1. At character select, click **AddOns** and make sure **Azerfolio** is ticked. Log in.
2. Type `/azf`. Expect: "The Azerfolio window isn't built yet…" (no Lua error).
3. Type `/azf status`. Expect: v0.1.0, schema 1/1, your character's name, level, race, class and faction, errors 0.
4. Type `/azf debug`, then `/azf debug zone`. Expect: "Debug output on", then the map chain (e.g. "Elwynn Forest (1429) < Eastern Kingdoms (1415) < Azeroth (947)").
5. Type `/azf shot`. Expect: "Screenshot requested." and the usual screenshot flash.
6. Type `/reload`, then `/azf status`. Expect: debug still on (settings persisted).
7. Type `/azf debug` to turn debug off again.

Agent checks afterwards: `AzerfolioDB` and `AzerfolioCharDB` files exist with schema 1; a new image in `<game>\Screenshots\`.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon) + agent | Pass. Chat output correct for every step (seen in the screenshot). `Screenshot()` works for addons: `Screenshots\WoWScrnShot_110726_121155.jpg`, 3440×1440 JPG. Account file at `WTF\Account\COMPUTERWISPERER\SavedVariables\Azerfolio.lua` (schema 1, debug persisted as true); character file at `WTF\Account\COMPUTERWISPERER\91\Gideon-Everhope\SavedVariables\Azerfolio.lua` (schema 1) |

## Phase 6 - Zones catalogue and Zone Detail (spec §12 "Zones" and "Exploration")

Automated: `luajit tests/run.lua` covers states, filters, sorts, sections, the catalogue page, popups, search, Zone Detail states and the world map round trip against mocks.

| Spec §12 criterion | How it's checked |
|---|---|
| Applicable zones listed; illustrated cards by default; compact mode; mode persists | Shots; `displayMode` in `AzerfolioDB` after a reload (steps 2-3) |
| Faction and completion filters, search, sorting | Steps 4-7; `/azf debug zones` trace on Gideon and Thragor (steps 9, 11) |
| Zone Detail opens; back restores catalogue state | Step 8 |
| Azerfolio's own tracking; no other addon required | TOC has no dependencies (agent, from files) |
| Verified per-objective states; discovered vs undiscovered correct | Step 8 against the game's Achievements window |
| Refreshes when a new area is discovered | Phase 5 (verified in game); cards redraw: automated test |
| Missing data never produces a false completion claim | Automated (unknown / partial / unavailable never complete) |

**Steps (owner)**, on Gideon:
1. `/reload`, then `/azf debug` (debug on).
2. Open Azerfolio, Zones tab. Cards show. Press **Y**: List view.
3. `/reload`, open Zones again: still List. Press **Y** back to Cards.
4. Status: choose **In progress**, then **All** again.
5. **Show**: choose **All zones** (Horde zones like Durotar appear), then **Relevant to me** again.
6. Press **X**, type `dun`, Enter: only Dun Morogh. Clear the text.
7. **Sort**: choose **Lowest %**, then **Recommended** again.
8. Open **Elwynn Forest**, then press **B**: back on Elwynn in the list. Open the game's Achievements window (Exploration > Eastern Kingdoms > Explore Elwynn Forest) and compare its count with Azerfolio's.
9. `/azf debug zones`, then `/azf shots` (wait about 20 seconds).

On Thragor:
10. Log in, open Azerfolio once.
11. `/azf debug zones`, then `/azf debug` (debug off) and `/reload`.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon, Thragor) + agent | Pass. Owner ran every step with the controller and reported them done. Trace (`AzerfolioDB.trace`, file written 21:33:16): **Gideon** (Alliance, 9): 50 listed, 43 shown with "Relevant to me", hidden = exactly the 7 Horde zones and capitals; Elwynn 10/12 progress, 42 untouched, 7 not tracked; view persisted as `list` after the step-3 reload. **Thragor** (Horde, 1): 38 shown, hidden = the 12 Alliance zones and capitals, contested zones (Ashenvale, Barrens, ...) kept; Durotar 2/11, Elwynn 0/12 (per character). Shots `WoWScrnShot_110726_213025`–`213041`: "Alliance" faction labels on cards, banner 83% readable on the dark band, shots start on the cards. TOC has no `Dependencies`/`RequiredDeps` (files). Found: at 1000 wide the toolbar overflowed (Sort ran into Cards, search hidden behind it); fixed with short labels and tighter padding when narrow (tests; not re-shot) |

## Phase 7 - Overview dashboard (spec §12 "Overview")

Automated: `luajit tests/run.lua` covers the Overview's picks (Continue, next goal, suggestion rules and limits, never unknown or unavailable objectives, stat counts, recent zones, activity, milestone times; `tests/overview_test.lua`) and the page (live catalogue, A on an area opens Zone Detail focused on it and B comes back, LT/RT and column focus, Zones panel filter, visits, redraw on discovery, pooling).

| Spec §12 criterion | How it's checked |
|---|---|
| Accurate character info | Window strip (Phase 4, verified in game); shots |
| Tracked completion with listed categories; unavailable data clearly marked | Shots; `/azf debug overview` trace vs `/azf debug exploration` total |
| Current-zone progress with link to Zone Detail | Steps 2-3: same % and n of m as the Zones card; A opens the detail, B returns |
| Suggestions only from eligible, known objectives | Automated; step 4 against the zone's checklist |
| Milestones recorded only for progress observed after baseline | Phase 5 (verified in game); step 5 shows a new one with today's time |
| Overview and Zones show identical numbers for the same zone | Step 3; both read the same `ns.Zones` entry (automated) |

**Steps (owner)**, on Gideon:
1. `/reload`, then `/azf debug` (debug on). Open Azerfolio on the Overview.
2. The Continue card shows your current zone. Note its % and "n of m".
3. Press **A** on it: Zone Detail of that zone with the same numbers. Press **B**: back on the Overview.
4. **D-pad down** to a suggested area, **A**: Zone Detail focused on that area (under "To discover"). **B** back.
5. Walk into an undiscovered area of the current zone: the card's % and pips update, the area leaves the suggestions, and Activity lists it with today's time.
6. Ride into another zone, open Azerfolio: the zone you left is under Recent zones.
7. `/azf debug overview`, then `/azf shots` (wait about 25 seconds), then `/reload`.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon) + agent | Partial. `/azf shots` and `/azf debug overview` run in Stormwind City (shots `WoWScrnShot_110726_221635`-`221652`, trace written 22:17:22): Overview renders at default and minimum size, numbers match the trace (11/549, Elwynn 11/12, 0 of 39 zones), chips focusable. Found: Elwynn's "Stormwind City" area discovered on the Stormwind map got no time (not seen live); fixed (tests). Steps 3-6 not reported yet |
| 2026-11-07 | Owner (Gideon) + agent | Pass. Files written 22:36:06: Ridgepoint Tower discovered live (timed area milestone + timed "Elwynn Forest fully explored" zone milestone, Elwynn 12/12); Jansen Stead in Westfall (timed); `recentZones` = 1429, 1436; `/azf debug overview` trace: Continue = Westfall (current, 13 left), suggestions Westfall / Loch Modan / Darkshore, zones 1 of 39 complete, 13/549, today 3, Recent zones = Elwynn. Owner ran the A/B steps. The full re-read after `MAP_EXPLORATION_UPDATED` also ran once on entering Westfall (no changes) |

## Phase 8 - v1 validation (spec §12, all v1 criteria)

Automated: `luajit tests/run.lua` (204 tests). Phase 8 adds: performance counters and `/azf debug perf`, the re-read after a discovery outside the current zone skipping fully explored zones (with its cost traced), no Overview rebuild on XP gains, damaged milestone and recent-zone entries cleaned on load, and a boot from a fully corrupted SavedVariables that opens both tabs and runs every command without errors.

Status of every criterion (updated 2026-11-08; details in the results table below):

| Spec §12 criterion | Evidence | Status |
|---|---|---|
| **Window:** `/azerfolio` and `/azf` toggle; launcher | Slash commands, minimap button and compartment (Phases 2/4, owner). The key binding was removed on 2026-11-08 (the controller test didn't work and the owner doesn't need it), so the criterion no longer asks for it | Met |
| Every screen usable with the gamepad alone, focus highlight and hint bar | Phase 4-7 shots; Phase 8 step 4 controller-only pass (owner). Typing a search needs the keyboard (no on-screen keyboard in this client; owner accepted) | Met |
| Draggable, resizable; position and size persist | `/reload` (Phases 2-7) and a full restart (Phase 8 step 7, owner) | Met |
| Overview and Zones tabs work; Escape closes | Tabs: Phases 4-8. Escape: in game (owner, 2026-11-07) and tests (`UISpecialFrames`) | Met |
| Cohesive native Warcraft style | Phase 4 native-look shots; Phase 8 visual review of every screen | Met |
| **Overview:** all five criteria | Phase 7 (Gideon) | Met |
| **Zones:** all three criteria | Phase 6 (Gideon and Thragor); Phase 8 Thragor Zone Detail | Met |
| **Exploration:** all four criteria | Phases 5-6 | Met |
| **Quality:** no Lua errors in normal use | Phase 8 play session with script errors shown: none (owner); trace 0 errors | Met |
| No noticeable performance impact | Phase 8 perf trace: about 10 ms of callbacks in 369 s, 0.0016 ms per frame on average | Met (the 39.5 ms peak frame is still to be attributed: open, page build or shots) |
| SavedVariables survive reloads and restarts; invalid settings recover | Reloads and a full restart (owner); invalid settings: tests incl. a fully corrupted boot | Met |
| Usable across window sizes and UI scales | 1000×640, 1160×740 and the wide split at UI scale 0.65; UI scale 0.8 (Phase 8 shots) | Met |
| Automated tests pass | 206 passed | Met |

**Performance review (code, 2026-11-07):**
- Per-frame work: none while idle. The only `OnUpdate` is the minimap button while it's dragged; the focus chevron is an animation.
- Events: `CRITERIA_UPDATE` and `MAP_EXPLORATION_UPDATED` are debounced (0.5 s) into one read of the current zone (about 12 criteria). `MAP_EXPLORATION_UPDATED` with no change there re-reads the zones read before, now **skipping fully explored ones**; the trace records `read`, `skipped` and `ms`. `PLAYER_XP_UPDATE` (every kill) is debounced 0.5 s and now only refreshes the header; the Overview rebuilds on a level change (`AZF_LEVEL_CHANGED`), not on XP. `ZONE_CHANGED*` refresh the header only while the window is shown. Pages that are hidden only mark themselves dirty.
- One-time work: the map scan (3000 `C_Map.GetMapInfo` calls) runs once per session on first open (trace `maps` with `ms`); the baseline read of all 43 zones runs once 3 s after login.
- Bounded storage: trace 100, milestones 100, recent zones 10, errors 50 (memory), baseline at most the catalogue's 549 areas, tracker cache at most the 50 listed zones (untracked ones are cached too; 50 seen in game), counters one entry per event or step name. Frames are pooled.

**Steps (owner)**, on Gideon, out of combat:
1. Type `/console scriptErrors 1` (shows Lua errors on screen), then `/reload`, then `/azf debug` (debug on; counters start now).
2. Visual review: `/azf shots` (wait about 25 seconds). Then resize the window to at least 1440 wide and `/azf shots` again.
3. Play for 10-15 minutes with the window closed: kill some mobs, ride into another zone, and discover an area if one is close. Then type `/azf debug perf`. Tell me if any Lua error appeared.
4. With the controller only: open Azerfolio, visit Overview, then Zones (cards, Y list, a filter popup, a zone's detail and back with B, X world map and back), then close with B.
5. Open it again and close it with **Escape**. (Until 2026-11-08 this step also opened it from a controller-bound key; the key binding is gone.)
6. Change the UI scale (System > Graphics or Interface, e.g. to 0.8), open Azerfolio, `/azf shots`. Set it back to 0.65.
7. Note the window's position, size, tab and Zones view. Exit the game completely (not just logout), start it again, log in on Gideon, open Azerfolio: same position, size, tab and view?
8. At character select, untick every addon except Azerfolio, log in, `/azf status` and `/azf shots`, then tick the others again.
9. On Thragor: open Azerfolio once, `/azf debug zones`, then open a contested zone (The Barrens) and a Horde zone (Durotar) in Zone Detail.
10. `/azf debug` (off), `/reload`.

| Date | By | Result |
|---|---|---|
| 2026-11-07 | Owner (Gideon, Thragor) + agent | Partial. Owner ran steps 1-10. **Shots** (`WoWScrnShot_110726_224819`-`224836` wide window, `224911`-`224929` wide, `225628`-`225646` UI scale 0.8, `225919`-`225936` after the restart with Azerfolio alone): every screen renders at both scales, no clipping, overlapping or missing text; cards, list, wide split, Sort popup, Zone Detail (in progress, fully explored), Overview with live numbers (Westfall 2 of 14 = 14%, tracked 14 of 549, activity 4 today) [verified-ingame]. **Perf** (trace `perf`, 369 s of play with debug on): 0 errors; busiest callback the Overview redraw (2 calls, 4.7 ms total, 2.4 ms max); 15 `CRITERIA_UPDATE` gave 5 debounced reads (1.08 ms total); 3 XP updates cost 0.03 ms and no Overview rebuild; memory 2410 KB; client profiler: session average 0.0016 ms per frame, 31 frames over 1 ms, 3 over 10 ms, peak 39.5 ms (not attributed: opening the window, page builds and `/azf shots` weren't counted yet; now they are). Map scan 1.2-1.4 ms once per session (trace `maps`). `RECEIVED_ACHIEVEMENT_LIST` fired after the full restart and the relog, as expected. **Thragor** (`/azf debug zones`): Horde, "Relevant to me" hides the 12 Alliance zones and capitals, contested kept; Durotar 2/11 (per character); with "For my level" 4 zones (Tirisfal, Durotar, Mulgore, Zephras Isle). Found: in the wide split view the "other view" shot repeated the previous one (now left out when wide); a fully explored zone shows an empty "To discover · 0 areas" header (design question, not changed). Waiting on the owner for: Lua errors seen (step 3), the controller key binding and Escape (step 5), whether position, size, tab and view were the same after the restart (step 7), and the Thragor Zone Detail check (step 9) |
| 2026-11-07 | Owner (Gideon, Thragor) | Owner's answers for the run above: **no Lua errors** during play (step 3); window position, size, tab and view **kept after the full restart** (step 7); Thragor's Zone Detail for The Barrens and Durotar **correct** (step 9). Step 5: no controller button is bound to Azerfolio yet, so opening from the controller is **deferred** (owner asked to be reminded); Escape not reported |
| 2026-11-07 | Owner | Escape closes the window [verified-ingame, owner]. Owner approved hiding the empty "To discover" section on a fully explored zone: mockup updated and checked in the preview, then Lua (tests). Owner checked Elwynn Forest's Zone Detail in game after `/reload`: looks right [verified-ingame, owner] |
| 2026-11-08 | Owner | Opening from a controller-bound key **didn't work**. The owner doesn't need a key binding, so it was removed (`Bindings.xml`, `Azerfolio_Toggle`, the binding labels and the help line) and the spec §12 Window criterion no longer asks for it. Not looked into why the controller binding failed. Every v1 criterion is now met |
