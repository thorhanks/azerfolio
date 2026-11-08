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
