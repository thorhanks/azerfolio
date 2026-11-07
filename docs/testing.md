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
